/// Tests for [EditCommand] concrete implementations.
///
/// Each test follows the pattern:
///   1. Build an [EditContext] with a small [MutableDocument].
///   2. Execute the command under test.
///   3. Assert the document state and the returned [DocumentChangeEvent]s.
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a two-paragraph document.
MutableDocument _twoParaDoc() => MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText('Hello world')),
      ParagraphNode(id: 'p2', text: AttributedText('Second paragraph')),
    ]);

/// Builds an [EditContext] wrapping [doc].
EditContext _ctx(MutableDocument doc) => EditContext(
      document: doc,
      controller: DocumentEditingController(document: doc),
    );

void main() {
  // =========================================================================
  // InsertTextCommand
  // =========================================================================

  group('InsertTextCommand', () {
    test('1. inserts text at offset, returns TextChanged event', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = InsertTextCommand(
        nodeId: 'p1',
        offset: 5,
        text: AttributedText(', dear'),
      );

      final events = cmd.execute(ctx);

      final node = doc.nodeById('p1') as TextNode;
      expect(node.text.text, 'Hello, dear world');
      expect(events, [const TextChanged(nodeId: 'p1')]);
    });

    test('2. inserts at offset 0', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = InsertTextCommand(nodeId: 'p1', offset: 0, text: AttributedText('A'));

      cmd.execute(ctx);

      final node = doc.nodeById('p1') as TextNode;
      expect(node.text.text, 'AHello world');
    });

    test('3. inserts at end of text', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = InsertTextCommand(nodeId: 'p1', offset: 11, text: AttributedText('!'));

      cmd.execute(ctx);

      final node = doc.nodeById('p1') as TextNode;
      expect(node.text.text, 'Hello world!');
    });

    test('4. preserves attributions in inserted text', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final boldText = AttributedText('X').applyAttribution(NamedAttribution.bold, 0, 0);
      final cmd = InsertTextCommand(nodeId: 'p1', offset: 0, text: boldText);

      cmd.execute(ctx);

      final node = doc.nodeById('p1') as TextNode;
      expect(node.text.hasAttributionAt(0, NamedAttribution.bold), isTrue);
    });

    test('5. throws StateError for unknown nodeId', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = InsertTextCommand(nodeId: 'nope', offset: 0, text: AttributedText('x'));
      expect(() => cmd.execute(ctx), throwsStateError);
    });

    test('6. throws StateError for non-text node', () {
      final doc = MutableDocument([ImageNode(id: 'img', imageUrl: 'https://x.com/img.png')]);
      final ctx = _ctx(doc);
      final cmd = InsertTextCommand(nodeId: 'img', offset: 0, text: AttributedText('x'));
      expect(() => cmd.execute(ctx), throwsStateError);
    });

    test('7. updates controller selection to after inserted text', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = InsertTextCommand(nodeId: 'p1', offset: 5, text: AttributedText('XX'));

      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      expect(sel, isNotNull);
      expect(sel!.isCollapsed, isTrue);
      expect(sel.extent.nodeId, 'p1');
      expect((sel.extent.nodePosition as TextNodePosition).offset, 7);
    });
  });

  // =========================================================================
  // DeleteContentCommand
  // =========================================================================

  group('DeleteContentCommand', () {
    test('1. no-op on collapsed selection', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final sel = const DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 3)),
      );
      final cmd = DeleteContentCommand(selection: sel);

      final events = cmd.execute(ctx);

      expect(events, isEmpty);
      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello world');
    });

    test('2. deletes within single text node', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );
      final cmd = DeleteContentCommand(selection: sel);

      final events = cmd.execute(ctx);

      expect((doc.nodeById('p1') as TextNode).text.text, ' world');
      expect(events, contains(isA<TextChanged>()));
    });

    test('3. collapses selection to deletion start after delete', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );
      final cmd = DeleteContentCommand(selection: sel);

      cmd.execute(ctx);

      final newSel = ctx.controller.selection;
      expect(newSel, isNotNull);
      expect(newSel!.isCollapsed, isTrue);
      expect((newSel.extent.nodePosition as TextNodePosition).offset, 0);
    });

    test('4. upstream selection is normalized before delete', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      // extent before base — upstream selection
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
      );
      final cmd = DeleteContentCommand(selection: sel);

      cmd.execute(ctx);

      expect((doc.nodeById('p1') as TextNode).text.text, ' world');
    });

    test('5. deletes across two nodes: tail of first, head of second, merges', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      // Delete from offset 6 in p1 to offset 6 in p2.
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 6)),
        extent: DocumentPosition(nodeId: 'p2', nodePosition: TextNodePosition(offset: 6)),
      );
      final cmd = DeleteContentCommand(selection: sel);

      final events = cmd.execute(ctx);

      // p1 keeps "Hello " and p2's " paragraph" tail (from cursor offset 6) is merged in.
      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello  paragraph');
      // p2 should be deleted.
      expect(doc.nodeById('p2'), isNull);
      expect(events.any((e) => e is NodeDeleted), isTrue);
    });

    test('6. deletes across three nodes: removes middle node', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('AAAA')),
        ParagraphNode(id: 'p2', text: AttributedText('BBBB')),
        ParagraphNode(id: 'p3', text: AttributedText('CCCC')),
      ]);
      final ctx = _ctx(doc);
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 2)),
        extent: DocumentPosition(nodeId: 'p3', nodePosition: TextNodePosition(offset: 2)),
      );
      final cmd = DeleteContentCommand(selection: sel);

      final events = cmd.execute(ctx);

      expect((doc.nodeById('p1') as TextNode).text.text, 'AACC');
      expect(doc.nodeById('p2'), isNull);
      expect(doc.nodeById('p3'), isNull);
      expect(events.whereType<NodeDeleted>().length, 2);
    });

    // -----------------------------------------------------------------------
    // Single-node deletion of binary (non-text) nodes
    // -----------------------------------------------------------------------

    test(
        '7. deletes HorizontalRuleNode — upstream to downstream — and moves selection '
        'to end of preceding TextNode', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
        HorizontalRuleNode(id: 'hr1'),
        ParagraphNode(id: 'p2', text: AttributedText('World')),
      ]);
      final ctx = _ctx(doc);
      // Simulate "delete the horizontal rule" selection: entire binary node selected.
      final sel = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'hr1',
          nodePosition: BinaryNodePosition.upstream(),
        ),
        extent: DocumentPosition(
          nodeId: 'hr1',
          nodePosition: BinaryNodePosition.downstream(),
        ),
      );
      final cmd = DeleteContentCommand(selection: sel);

      final events = cmd.execute(ctx);

      // The horizontal rule must be gone.
      expect(doc.nodeById('hr1'), isNull);
      expect(doc.nodeCount, 2);

      // NodeDeleted event must be emitted.
      expect(events.any((e) => e is NodeDeleted), isTrue);
      final deleted = events.whereType<NodeDeleted>().first;
      expect(deleted.nodeId, 'hr1');

      // Selection collapses to end of the preceding TextNode ('Hello' = 5 chars).
      final sel2 = ctx.controller.selection;
      expect(sel2, isNotNull);
      expect(sel2!.isCollapsed, isTrue);
      expect(sel2.extent.nodeId, 'p1');
      expect((sel2.extent.nodePosition as TextNodePosition).offset, 5);
    });

    test(
        '8. deletes HorizontalRuleNode with no preceding node — selection moves '
        'to start of next node', () {
      final doc = MutableDocument([
        HorizontalRuleNode(id: 'hr1'),
        ParagraphNode(id: 'p1', text: AttributedText('After')),
      ]);
      final ctx = _ctx(doc);
      final sel = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'hr1',
          nodePosition: BinaryNodePosition.upstream(),
        ),
        extent: DocumentPosition(
          nodeId: 'hr1',
          nodePosition: BinaryNodePosition.downstream(),
        ),
      );
      final cmd = DeleteContentCommand(selection: sel);

      final events = cmd.execute(ctx);

      expect(doc.nodeById('hr1'), isNull);
      expect(doc.nodeCount, 1);
      expect(events.any((e) => e is NodeDeleted), isTrue);

      // Selection moves to offset 0 of the next node.
      final sel2 = ctx.controller.selection;
      expect(sel2, isNotNull);
      expect(sel2!.isCollapsed, isTrue);
      expect(sel2.extent.nodeId, 'p1');
      expect((sel2.extent.nodePosition as TextNodePosition).offset, 0);
    });

    test('9. deletes the only node in the document — selection is cleared to null', () {
      final doc = MutableDocument([
        HorizontalRuleNode(id: 'hr1'),
      ]);
      final ctx = _ctx(doc);
      final sel = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'hr1',
          nodePosition: BinaryNodePosition.upstream(),
        ),
        extent: DocumentPosition(
          nodeId: 'hr1',
          nodePosition: BinaryNodePosition.downstream(),
        ),
      );
      final cmd = DeleteContentCommand(selection: sel);

      final events = cmd.execute(ctx);

      expect(doc.nodeById('hr1'), isNull);
      expect(doc.nodeCount, 0);
      expect(events.any((e) => e is NodeDeleted), isTrue);

      // Document is empty — selection is cleared.
      expect(ctx.controller.selection, isNull);
    });

    test(
        '10. deletes ImageNode — upstream to downstream — and moves selection '
        'to end of preceding TextNode', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Caption')),
        ImageNode(id: 'img1', imageUrl: 'https://example.com/img.png'),
      ]);
      final ctx = _ctx(doc);
      final sel = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'img1',
          nodePosition: BinaryNodePosition.upstream(),
        ),
        extent: DocumentPosition(
          nodeId: 'img1',
          nodePosition: BinaryNodePosition.downstream(),
        ),
      );
      final cmd = DeleteContentCommand(selection: sel);

      final events = cmd.execute(ctx);

      expect(doc.nodeById('img1'), isNull);
      expect(doc.nodeCount, 1);
      expect(events.any((e) => e is NodeDeleted), isTrue);

      // Selection collapses to end of 'Caption' (7 chars).
      final sel2 = ctx.controller.selection;
      expect(sel2, isNotNull);
      expect(sel2!.isCollapsed, isTrue);
      expect(sel2.extent.nodeId, 'p1');
      expect((sel2.extent.nodePosition as TextNodePosition).offset, 7);
    });
  });

  // =========================================================================
  // ReplaceNodeCommand
  // =========================================================================

  group('ReplaceNodeCommand', () {
    test('1. replaces node and returns NodeReplaced event', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final newNode = ParagraphNode(id: 'p1', text: AttributedText('Replaced'));
      final cmd = ReplaceNodeCommand(nodeId: 'p1', newNode: newNode);

      final events = cmd.execute(ctx);

      expect((doc.nodeById('p1') as TextNode).text.text, 'Replaced');
      expect(events, [const NodeReplaced(oldNodeId: 'p1', newNodeId: 'p1')]);
    });

    test('2. throws StateError for unknown node', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = ReplaceNodeCommand(
        nodeId: 'nope',
        newNode: ParagraphNode(id: 'nope', text: AttributedText('')),
      );
      expect(() => cmd.execute(ctx), throwsStateError);
    });
  });

  // =========================================================================
  // SplitParagraphCommand
  // =========================================================================

  group('SplitParagraphCommand', () {
    test('1. splits paragraph into two nodes', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = const SplitParagraphCommand(nodeId: 'p1', splitOffset: 5);

      final events = cmd.execute(ctx);

      expect(doc.nodeCount, 3);
      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello');
      final newNode = doc.nodeAt(1) as TextNode;
      expect(newNode.text.text, ' world');
      expect(events.any((e) => e is TextChanged), isTrue);
      expect(events.any((e) => e is NodeInserted), isTrue);
    });

    test('2. new node has fresh id different from original', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = const SplitParagraphCommand(nodeId: 'p1', splitOffset: 5);

      cmd.execute(ctx);

      final newNode = doc.nodeAt(1);
      expect(newNode.id, isNot('p1'));
    });

    test('3. selection moves to start of new node', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = const SplitParagraphCommand(nodeId: 'p1', splitOffset: 5);

      cmd.execute(ctx);

      final newNodeId = doc.nodeAt(1).id;
      final sel = ctx.controller.selection;
      expect(sel, isNotNull);
      expect(sel!.isCollapsed, isTrue);
      expect(sel.extent.nodeId, newNodeId);
      expect((sel.extent.nodePosition as TextNodePosition).offset, 0);
    });

    test('4. split at 0 leaves original empty', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = const SplitParagraphCommand(nodeId: 'p1', splitOffset: 0);

      cmd.execute(ctx);

      expect((doc.nodeById('p1') as TextNode).text.text, '');
      expect((doc.nodeAt(1) as TextNode).text.text, 'Hello world');
    });

    test('5. throws StateError for non-text node', () {
      final doc = MutableDocument([ImageNode(id: 'img', imageUrl: 'https://x.com/img.png')]);
      final ctx = _ctx(doc);
      expect(() => const SplitParagraphCommand(nodeId: 'img', splitOffset: 0).execute(ctx),
          throwsStateError);
    });

    test('6. preserves blockType of original paragraph', () {
      final doc = MutableDocument([
        ParagraphNode(
          id: 'h1',
          text: AttributedText('Heading'),
          blockType: ParagraphBlockType.header1,
        ),
      ]);
      final ctx = _ctx(doc);
      final cmd = const SplitParagraphCommand(nodeId: 'h1', splitOffset: 4);

      cmd.execute(ctx);

      final original = doc.nodeById('h1') as ParagraphNode;
      expect(original.blockType, ParagraphBlockType.header1);
    });
  });

  // =========================================================================
  // MergeNodeCommand
  // =========================================================================

  group('MergeNodeCommand', () {
    test('1. appends second node text to first, deletes second', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = const MergeNodeCommand(firstNodeId: 'p1', secondNodeId: 'p2');

      final events = cmd.execute(ctx);

      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello worldSecond paragraph');
      expect(doc.nodeById('p2'), isNull);
      expect(events.any((e) => e is TextChanged), isTrue);
      expect(events.any((e) => e is NodeDeleted), isTrue);
    });

    test('2. throws StateError when first node not found', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      expect(
        () => const MergeNodeCommand(firstNodeId: 'nope', secondNodeId: 'p2').execute(ctx),
        throwsStateError,
      );
    });

    test('3. throws StateError when second node not text', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
        ImageNode(id: 'img', imageUrl: 'https://x.com/img.png'),
      ]);
      final ctx = _ctx(doc);
      expect(
        () => const MergeNodeCommand(firstNodeId: 'p1', secondNodeId: 'img').execute(ctx),
        throwsStateError,
      );
    });

    test('4. selection is moved to join point after merge', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = const MergeNodeCommand(firstNodeId: 'p1', secondNodeId: 'p2');

      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      expect(sel, isNotNull);
      expect(sel!.isCollapsed, isTrue);
      expect(sel.extent.nodeId, 'p1');
      // Join point = end of original first node text ("Hello world" = 11 chars)
      expect((sel.extent.nodePosition as TextNodePosition).offset, 11);
    });
  });

  // =========================================================================
  // MoveNodeCommand
  // =========================================================================

  group('MoveNodeCommand', () {
    test('1. moves node to new index, returns NodeMoved event', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd = const MoveNodeCommand(nodeId: 'p2', newIndex: 0);

      final events = cmd.execute(ctx);

      expect(doc.nodeAt(0).id, 'p2');
      expect(doc.nodeAt(1).id, 'p1');
      expect(events, contains(isA<NodeMoved>()));
    });

    test('2. throws StateError for unknown node', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      expect(
          () => const MoveNodeCommand(nodeId: 'nope', newIndex: 0).execute(ctx), throwsStateError);
    });
  });

  // =========================================================================
  // ChangeBlockTypeCommand
  // =========================================================================

  group('ChangeBlockTypeCommand', () {
    test('1. changes block type and returns NodeReplaced event', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final cmd =
          const ChangeBlockTypeCommand(nodeId: 'p1', newBlockType: ParagraphBlockType.header1);

      final events = cmd.execute(ctx);

      final node = doc.nodeById('p1') as ParagraphNode;
      expect(node.blockType, ParagraphBlockType.header1);
      expect(events, contains(isA<NodeReplaced>()));
    });

    test('2. throws StateError for non-paragraph node', () {
      final doc = MutableDocument([ImageNode(id: 'img', imageUrl: 'https://x.com/img.png')]);
      final ctx = _ctx(doc);
      expect(
        () => const ChangeBlockTypeCommand(
          nodeId: 'img',
          newBlockType: ParagraphBlockType.paragraph,
        ).execute(ctx),
        throwsStateError,
      );
    });
  });

  // =========================================================================
  // ApplyAttributionCommand
  // =========================================================================

  group('ApplyAttributionCommand', () {
    test('1. applies attribution to single-node selection', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 4)),
      );
      final cmd = ApplyAttributionCommand(selection: sel, attribution: NamedAttribution.bold);

      final events = cmd.execute(ctx);

      final node = doc.nodeById('p1') as TextNode;
      // Extent offset 4 is exclusive — attribution covers offsets 0-3.
      expect(node.text.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      expect(node.text.hasAttributionAt(3, NamedAttribution.bold), isTrue);
      expect(node.text.hasAttributionAt(4, NamedAttribution.bold), isFalse);
      expect(events, contains(isA<TextChanged>()));
    });

    test('2. applies attribution across two nodes', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      // Selection covers p1[6..10] and p2[0..4] (extent offset is exclusive).
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 6)),
        extent: DocumentPosition(nodeId: 'p2', nodePosition: TextNodePosition(offset: 5)),
      );
      final cmd = ApplyAttributionCommand(selection: sel, attribution: NamedAttribution.bold);

      final events = cmd.execute(ctx);

      final p1 = doc.nodeById('p1') as TextNode;
      final p2 = doc.nodeById('p2') as TextNode;
      // p1: chars 6..10 (end of "Hello world") should be bold
      expect(p1.text.hasAttributionAt(6, NamedAttribution.bold), isTrue);
      expect(p1.text.hasAttributionAt(10, NamedAttribution.bold), isTrue);
      // p2: chars 0..4 should be bold (extent at 5 is exclusive)
      expect(p2.text.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      expect(p2.text.hasAttributionAt(4, NamedAttribution.bold), isTrue);
      expect(p2.text.hasAttributionAt(5, NamedAttribution.bold), isFalse);
      expect(events.whereType<TextChanged>().length, 2);
    });

    test('3. no-op on collapsed selection', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final sel = const DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 3)),
      );
      final cmd = ApplyAttributionCommand(selection: sel, attribution: NamedAttribution.bold);

      final events = cmd.execute(ctx);

      expect(events, isEmpty);
    });
  });

  // =========================================================================
  // RemoveAttributionCommand
  // =========================================================================

  group('RemoveAttributionCommand', () {
    test('1. removes attribution from single-node selection', () {
      final boldText = AttributedText('Hello world').applyAttribution(NamedAttribution.bold, 0, 10);
      final doc = MutableDocument([ParagraphNode(id: 'p1', text: boldText)]);
      final ctx = _ctx(doc);
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 4)),
      );
      final cmd = RemoveAttributionCommand(selection: sel, attribution: NamedAttribution.bold);

      final events = cmd.execute(ctx);

      final node = doc.nodeById('p1') as TextNode;
      expect(node.text.hasAttributionAt(0, NamedAttribution.bold), isFalse);
      expect(node.text.hasAttributionAt(5, NamedAttribution.bold), isTrue);
      expect(events, contains(isA<TextChanged>()));
    });

    test('2. no-op on collapsed selection', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final sel = const DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 3)),
      );
      final events =
          RemoveAttributionCommand(selection: sel, attribution: NamedAttribution.bold).execute(ctx);
      expect(events, isEmpty);
    });
  });

  // =========================================================================
  // ConvertListItemToParagraphCommand
  // =========================================================================

  group('ConvertListItemToParagraphCommand', () {
    test('1. converts unordered ListItemNode to ParagraphNode', () {
      final doc = MutableDocument([
        ListItemNode(
          id: 'li1',
          text: AttributedText('Item text'),
          type: ListItemType.unordered,
          metadata: {'key': 'value'},
        ),
      ]);
      final ctx = _ctx(doc);
      final cmd = const ConvertListItemToParagraphCommand(nodeId: 'li1');

      final events = cmd.execute(ctx);

      final node = doc.nodeById('li1');
      expect(node, isA<ParagraphNode>());
      expect((node as ParagraphNode).text.text, 'Item text');
      expect(node.metadata, {'key': 'value'});
      expect(events, [const NodeReplaced(oldNodeId: 'li1', newNodeId: 'li1')]);
    });

    test('2. converts ordered ListItemNode to ParagraphNode', () {
      final doc = MutableDocument([
        ListItemNode(
          id: 'li1',
          text: AttributedText('Ordered item'),
          type: ListItemType.ordered,
        ),
      ]);
      final ctx = _ctx(doc);
      final cmd = const ConvertListItemToParagraphCommand(nodeId: 'li1');

      final events = cmd.execute(ctx);

      final node = doc.nodeById('li1');
      expect(node, isA<ParagraphNode>());
      expect((node as ParagraphNode).text.text, 'Ordered item');
      expect(events, [const NodeReplaced(oldNodeId: 'li1', newNodeId: 'li1')]);
    });

    test('3. collapses selection to offset 0', () {
      final doc = MutableDocument([
        ListItemNode(id: 'li1', text: AttributedText('')),
      ]);
      final ctx = _ctx(doc);
      final cmd = const ConvertListItemToParagraphCommand(nodeId: 'li1');

      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      expect(sel, isNotNull);
      expect(sel!.isCollapsed, isTrue);
      expect(sel.extent.nodeId, 'li1');
      expect((sel.extent.nodePosition as TextNodePosition).offset, 0);
    });

    test('4. throws StateError for non-ListItemNode', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      expect(
        () => const ConvertListItemToParagraphCommand(nodeId: 'p1').execute(ctx),
        throwsStateError,
      );
    });

    test('5. throws StateError for missing node', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      expect(
        () => const ConvertListItemToParagraphCommand(nodeId: 'nope').execute(ctx),
        throwsStateError,
      );
    });
  });

  // =========================================================================
  // ExitCodeBlockCommand
  // =========================================================================

  group('ExitCodeBlockCommand', () {
    test('1. empty code block converts to ParagraphNode in place', () {
      final doc = MutableDocument([
        CodeBlockNode(id: 'cb1', text: AttributedText(''), language: 'dart'),
      ]);
      final ctx = _ctx(doc);
      final cmd = const ExitCodeBlockCommand(nodeId: 'cb1', splitOffset: 0);

      final events = cmd.execute(ctx);

      final node = doc.nodeById('cb1');
      expect(node, isA<ParagraphNode>());
      expect(node, isNot(isA<CodeBlockNode>()));
      expect((node as ParagraphNode).text.text, '');
      expect(events, [const NodeReplaced(oldNodeId: 'cb1', newNodeId: 'cb1')]);
    });

    test('2. double-enter exit strips trailing newline, creates empty paragraph', () {
      final doc = MutableDocument([
        CodeBlockNode(id: 'cb1', text: AttributedText('line1\n'), language: 'dart'),
      ]);
      final ctx = _ctx(doc);
      // Cursor at offset 6 (after '\n'), with removeTrailingNewline=true.
      final cmd = const ExitCodeBlockCommand(
        nodeId: 'cb1',
        splitOffset: 6,
        removeTrailingNewline: true,
      );

      final events = cmd.execute(ctx);

      final codeNode = doc.nodeById('cb1') as CodeBlockNode;
      expect(codeNode.text.text, 'line1');
      expect(codeNode.language, 'dart');
      expect(doc.nodeCount, 2);
      final paragraph = doc.nodeAt(1) as ParagraphNode;
      expect(paragraph.text.text, '');
      expect(events.any((e) => e is TextChanged), isTrue);
      expect(events.any((e) => e is NodeInserted), isTrue);
    });

    test('3. shift+enter mid-split: code keeps before-text, paragraph gets after-text', () {
      final doc = MutableDocument([
        CodeBlockNode(id: 'cb1', text: AttributedText('abc\ndef')),
      ]);
      final ctx = _ctx(doc);
      final cmd = const ExitCodeBlockCommand(nodeId: 'cb1', splitOffset: 4);

      final events = cmd.execute(ctx);

      final codeNode = doc.nodeById('cb1') as CodeBlockNode;
      expect(codeNode.text.text, 'abc\n');
      expect(doc.nodeCount, 2);
      final paragraph = doc.nodeAt(1) as ParagraphNode;
      expect(paragraph.text.text, 'def');
      expect(events.any((e) => e is TextChanged), isTrue);
      expect(events.any((e) => e is NodeInserted), isTrue);
    });

    test('4. shift+enter at end: code unchanged, empty paragraph inserted', () {
      final doc = MutableDocument([
        CodeBlockNode(id: 'cb1', text: AttributedText('code')),
      ]);
      final ctx = _ctx(doc);
      final cmd = const ExitCodeBlockCommand(nodeId: 'cb1', splitOffset: 4);

      final events = cmd.execute(ctx);

      final codeNode = doc.nodeById('cb1') as CodeBlockNode;
      expect(codeNode.text.text, 'code');
      expect(doc.nodeCount, 2);
      final paragraph = doc.nodeAt(1) as ParagraphNode;
      expect(paragraph.text.text, '');
      expect(events.any((e) => e is NodeInserted), isTrue);
    });

    test('5. shift+enter at offset 0: code empty converts to paragraph with full text', () {
      final doc = MutableDocument([
        CodeBlockNode(id: 'cb1', text: AttributedText('all text')),
      ]);
      final ctx = _ctx(doc);
      final cmd = const ExitCodeBlockCommand(nodeId: 'cb1', splitOffset: 0);

      final events = cmd.execute(ctx);

      final node = doc.nodeById('cb1');
      expect(node, isA<ParagraphNode>());
      expect(node, isNot(isA<CodeBlockNode>()));
      expect((node as ParagraphNode).text.text, 'all text');
      expect(events, [const NodeReplaced(oldNodeId: 'cb1', newNodeId: 'cb1')]);
    });

    test('6. removeTrailingNewline=true when last char is not newline: normal split', () {
      final doc = MutableDocument([
        CodeBlockNode(id: 'cb1', text: AttributedText('abcd')),
      ]);
      final ctx = _ctx(doc);
      // splitOffset=4, last char is 'd' not '\n' — no adjustment.
      final cmd = const ExitCodeBlockCommand(
        nodeId: 'cb1',
        splitOffset: 4,
        removeTrailingNewline: true,
      );

      final events = cmd.execute(ctx);

      final codeNode = doc.nodeById('cb1') as CodeBlockNode;
      expect(codeNode.text.text, 'abcd');
      expect(doc.nodeCount, 2);
      final paragraph = doc.nodeAt(1) as ParagraphNode;
      expect(paragraph.text.text, '');
      expect(events.any((e) => e is NodeInserted), isTrue);
    });

    test('7. preserves code block language after split', () {
      final doc = MutableDocument([
        CodeBlockNode(id: 'cb1', text: AttributedText('line1\nline2'), language: 'python'),
      ]);
      final ctx = _ctx(doc);
      final cmd = const ExitCodeBlockCommand(nodeId: 'cb1', splitOffset: 6);

      cmd.execute(ctx);

      final codeNode = doc.nodeById('cb1') as CodeBlockNode;
      expect(codeNode.language, 'python');
    });

    test('8. throws StateError for non-CodeBlockNode', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final ctx = _ctx(doc);
      expect(
        () => const ExitCodeBlockCommand(nodeId: 'p1', splitOffset: 0).execute(ctx),
        throwsStateError,
      );
    });

    test('9. throws StateError for missing node', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final ctx = _ctx(doc);
      expect(
        () => const ExitCodeBlockCommand(nodeId: 'nope', splitOffset: 0).execute(ctx),
        throwsStateError,
      );
    });

    test('10. selection moves to offset 0 of new paragraph after split', () {
      final doc = MutableDocument([
        CodeBlockNode(id: 'cb1', text: AttributedText('abc\ndef')),
      ]);
      final ctx = _ctx(doc);
      final cmd = const ExitCodeBlockCommand(nodeId: 'cb1', splitOffset: 4);

      cmd.execute(ctx);

      final newNodeId = doc.nodeAt(1).id;
      final sel = ctx.controller.selection;
      expect(sel, isNotNull);
      expect(sel!.isCollapsed, isTrue);
      expect(sel.extent.nodeId, newNodeId);
      expect((sel.extent.nodePosition as TextNodePosition).offset, 0);
    });

    test('11. selection moves to offset 0 of converted paragraph', () {
      final doc = MutableDocument([
        CodeBlockNode(id: 'cb1', text: AttributedText('')),
      ]);
      final ctx = _ctx(doc);
      final cmd = const ExitCodeBlockCommand(nodeId: 'cb1', splitOffset: 0);

      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      expect(sel, isNotNull);
      expect(sel!.isCollapsed, isTrue);
      expect(sel.extent.nodeId, 'cb1');
      expect((sel.extent.nodePosition as TextNodePosition).offset, 0);
    });

    test('12. preserves metadata when converting empty code block in place', () {
      final doc = MutableDocument([
        CodeBlockNode(id: 'cb1', text: AttributedText(''), metadata: {'key': 'value'}),
      ]);
      final ctx = _ctx(doc);
      final cmd = const ExitCodeBlockCommand(nodeId: 'cb1', splitOffset: 0);

      cmd.execute(ctx);

      final node = doc.nodeById('cb1') as ParagraphNode;
      expect(node.metadata, {'key': 'value'});
    });
  });
}
