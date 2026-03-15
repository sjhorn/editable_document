/// Tests for [Editor], [EditReaction], and [EditListener].
library;

import 'dart:ui' show TextAlign;

import 'package:editable_document/editable_document.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MutableDocument _twoParaDoc() => MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText('Hello world')),
      ParagraphNode(id: 'p2', text: AttributedText('Second paragraph')),
    ]);

EditContext _ctx(MutableDocument doc) => EditContext(
      document: doc,
      controller: DocumentEditingController(document: doc),
    );

/// A [EditListener] that collects every event batch it receives.
class _CapturingListener implements EditListener {
  final List<List<DocumentChangeEvent>> batches = [];

  @override
  void onEdit(List<DocumentChangeEvent> changes) => batches.add(List.unmodifiable(changes));
}

/// A [EditReaction] that records calls and returns no additional requests.
class _NoOpReaction implements EditReaction {
  int callCount = 0;
  List<DocumentChangeEvent>? lastEvents;

  @override
  List<EditRequest> react(
    EditContext context,
    List<EditRequest> requests,
    List<DocumentChangeEvent> changes,
  ) {
    callCount++;
    lastEvents = changes;
    return const [];
  }
}

/// A [EditReaction] that fires one additional [InsertTextRequest] if the
/// change list contains a [TextChanged] for node 'p1'.
class _ChainingReaction implements EditReaction {
  bool fired = false;

  @override
  List<EditRequest> react(
    EditContext context,
    List<EditRequest> requests,
    List<DocumentChangeEvent> changes,
  ) {
    if (!fired && changes.any((e) => e is TextChanged && e.nodeId == 'p1')) {
      fired = true;
      return [InsertTextRequest(nodeId: 'p2', offset: 0, text: AttributedText('>>'))];
    }
    return const [];
  }
}

void main() {
  // =========================================================================
  // EditContext
  // =========================================================================

  group('EditContext', () {
    test('1. exposes document and controller', () {
      final doc = _twoParaDoc();
      final ctrl = DocumentEditingController(document: doc);
      final ctx = EditContext(document: doc, controller: ctrl);

      expect(ctx.document, same(doc));
      expect(ctx.controller, same(ctrl));
    });
  });

  // =========================================================================
  // Editor — basic submit
  // =========================================================================

  group('Editor.submit — basic', () {
    test('1. InsertTextRequest mutates document', () {
      final doc = _twoParaDoc();
      final editor = Editor(editContext: _ctx(doc));

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 5, text: AttributedText('!')));

      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello! world');
      editor.dispose();
    });

    test('2. SplitParagraphRequest splits document', () {
      final doc = _twoParaDoc();
      final editor = Editor(editContext: _ctx(doc));

      editor.submit(const SplitParagraphRequest(nodeId: 'p1', splitOffset: 5));

      expect(doc.nodeCount, 3);
      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello');
      editor.dispose();
    });

    test('3. MergeNodeRequest merges two nodes', () {
      final doc = _twoParaDoc();
      final editor = Editor(editContext: _ctx(doc));

      editor.submit(const MergeNodeRequest(firstNodeId: 'p1', secondNodeId: 'p2'));

      expect(doc.nodeCount, 1);
      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello worldSecond paragraph');
      editor.dispose();
    });

    test('4. MoveNodeRequest reorders nodes', () {
      final doc = _twoParaDoc();
      final editor = Editor(editContext: _ctx(doc));

      editor.submit(const MoveNodeRequest(nodeId: 'p2', newIndex: 0));

      expect(doc.nodeAt(0).id, 'p2');
      editor.dispose();
    });

    test('5. ChangeBlockTypeRequest changes block type', () {
      final doc = _twoParaDoc();
      final editor = Editor(editContext: _ctx(doc));

      editor.submit(
          const ChangeBlockTypeRequest(nodeId: 'p1', newBlockType: ParagraphBlockType.header1));

      expect((doc.nodeById('p1') as ParagraphNode).blockType, ParagraphBlockType.header1);
      editor.dispose();
    });

    test('6. ApplyAttributionRequest applies attribution', () {
      final doc = _twoParaDoc();
      final editor = Editor(editContext: _ctx(doc));
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 4)),
      );

      editor.submit(ApplyAttributionRequest(selection: sel, attribution: NamedAttribution.bold));

      final node = doc.nodeById('p1') as TextNode;
      expect(node.text.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      editor.dispose();
    });

    test('7. RemoveAttributionRequest removes attribution', () {
      final boldText = AttributedText('Hello world').applyAttribution(NamedAttribution.bold, 0, 10);
      final doc = MutableDocument([ParagraphNode(id: 'p1', text: boldText)]);
      final editor = Editor(editContext: _ctx(doc));
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 4)),
      );

      editor.submit(RemoveAttributionRequest(selection: sel, attribution: NamedAttribution.bold));

      final node = doc.nodeById('p1') as TextNode;
      expect(node.text.hasAttributionAt(0, NamedAttribution.bold), isFalse);
      editor.dispose();
    });

    test('8. ReplaceNodeRequest replaces node', () {
      final doc = _twoParaDoc();
      final editor = Editor(editContext: _ctx(doc));
      final newNode = ParagraphNode(id: 'p1', text: AttributedText('Replaced'));

      editor.submit(ReplaceNodeRequest(nodeId: 'p1', newNode: newNode));

      expect((doc.nodeById('p1') as TextNode).text.text, 'Replaced');
      editor.dispose();
    });

    test('9. DeleteContentRequest deletes content', () {
      final doc = _twoParaDoc();
      final editor = Editor(editContext: _ctx(doc));
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );

      editor.submit(DeleteContentRequest(selection: sel));

      expect((doc.nodeById('p1') as TextNode).text.text, ' world');
      editor.dispose();
    });

    test('10. IndentListItemRequest increments list item indent', () {
      final doc = MutableDocument([
        ListItemNode(id: 'li1', text: AttributedText('Item'), indent: 0),
      ]);
      final editor = Editor(editContext: _ctx(doc));

      editor.submit(const IndentListItemRequest(nodeId: 'li1'));

      expect((doc.nodeById('li1') as ListItemNode).indent, 1);
      editor.dispose();
    });

    test('11. UnindentListItemRequest decrements list item indent', () {
      final doc = MutableDocument([
        ListItemNode(id: 'li1', text: AttributedText('Item'), indent: 2),
      ]);
      final editor = Editor(editContext: _ctx(doc));

      editor.submit(const UnindentListItemRequest(nodeId: 'li1'));

      expect((doc.nodeById('li1') as ListItemNode).indent, 1);
      editor.dispose();
    });

    test('12. UnindentListItemRequest clamps indent to 0', () {
      final doc = MutableDocument([
        ListItemNode(id: 'li1', text: AttributedText('Item'), indent: 0),
      ]);
      final editor = Editor(editContext: _ctx(doc));

      editor.submit(const UnindentListItemRequest(nodeId: 'li1'));

      expect((doc.nodeById('li1') as ListItemNode).indent, 0);
      editor.dispose();
    });

    test('13. ChangeTextAlignRequest changes textAlign on ParagraphNode', () {
      final doc = _twoParaDoc();
      final editor = Editor(editContext: _ctx(doc));

      editor.submit(
        const ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.center),
      );

      expect((doc.nodeById('p1') as ParagraphNode).textAlign, TextAlign.center);
      editor.dispose();
    });

    test('14. ChangeTextAlignRequest changes textAlign on ListItemNode', () {
      final doc = MutableDocument([
        ListItemNode(id: 'li1', text: AttributedText('Item'), type: ListItemType.unordered),
      ]);
      final editor = Editor(editContext: _ctx(doc));

      editor.submit(
        const ChangeTextAlignRequest(nodeId: 'li1', newTextAlign: TextAlign.end),
      );

      expect((doc.nodeById('li1') as ListItemNode).textAlign, TextAlign.end);
      editor.dispose();
    });

    test('15. ChangeTextAlignRequest changes textAlign on BlockquoteNode', () {
      final doc = MutableDocument([
        BlockquoteNode(id: 'bq1', text: AttributedText('A quote')),
      ]);
      final editor = Editor(editContext: _ctx(doc));

      editor.submit(
        const ChangeTextAlignRequest(nodeId: 'bq1', newTextAlign: TextAlign.justify),
      );

      expect((doc.nodeById('bq1') as BlockquoteNode).textAlign, TextAlign.justify);
      editor.dispose();
    });
  });

  // =========================================================================
  // Editor — listener notifications
  // =========================================================================

  group('Editor — listeners', () {
    test('1. listener is notified after submit', () {
      final doc = _twoParaDoc();
      final listener = _CapturingListener();
      final editor = Editor(editContext: _ctx(doc), listeners: [listener]);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));

      expect(listener.batches, hasLength(1));
      expect(listener.batches.first, contains(isA<TextChanged>()));
      editor.dispose();
    });

    test('2. addListener registers a listener', () {
      final doc = _twoParaDoc();
      final listener = _CapturingListener();
      final editor = Editor(editContext: _ctx(doc));
      editor.addListener(listener);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));

      expect(listener.batches, hasLength(1));
      editor.dispose();
    });

    test('3. removeListener stops notifications', () {
      final doc = _twoParaDoc();
      final listener = _CapturingListener();
      final editor = Editor(editContext: _ctx(doc), listeners: [listener]);

      editor.removeListener(listener);
      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));

      expect(listener.batches, isEmpty);
      editor.dispose();
    });

    test('4. multiple listeners all receive events', () {
      final doc = _twoParaDoc();
      final l1 = _CapturingListener();
      final l2 = _CapturingListener();
      final editor = Editor(editContext: _ctx(doc), listeners: [l1, l2]);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));

      expect(l1.batches, hasLength(1));
      expect(l2.batches, hasLength(1));
      editor.dispose();
    });
  });

  // =========================================================================
  // Editor — reactions
  // =========================================================================

  group('Editor — reactions', () {
    test('1. reaction is called after submit', () {
      final doc = _twoParaDoc();
      final reaction = _NoOpReaction();
      final editor = Editor(editContext: _ctx(doc), reactions: [reaction]);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));

      expect(reaction.callCount, 1);
      expect(reaction.lastEvents, isNotEmpty);
      editor.dispose();
    });

    test('2. addReaction registers a reaction', () {
      final doc = _twoParaDoc();
      final reaction = _NoOpReaction();
      final editor = Editor(editContext: _ctx(doc));
      editor.addReaction(reaction);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));

      expect(reaction.callCount, 1);
      editor.dispose();
    });

    test('3. removeReaction stops it from being called', () {
      final doc = _twoParaDoc();
      final reaction = _NoOpReaction();
      final editor = Editor(editContext: _ctx(doc), reactions: [reaction]);
      editor.removeReaction(reaction);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));

      expect(reaction.callCount, 0);
      editor.dispose();
    });

    test('4. chaining reaction fires additional request', () {
      final doc = _twoParaDoc();
      final reaction = _ChainingReaction();
      final listener = _CapturingListener();
      final editor = Editor(editContext: _ctx(doc), reactions: [reaction], listeners: [listener]);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));

      // The chaining reaction added >>  to p2.
      expect((doc.nodeById('p2') as TextNode).text.text, '>>Second paragraph');
      // Listener should have received events for both operations.
      expect(listener.batches.first.whereType<TextChanged>().length, greaterThanOrEqualTo(1));
      editor.dispose();
    });

    test('5. cycle guard prevents infinite reaction chains', () {
      // A reaction that always returns a new request — must terminate.
      var count = 0;
      final infiniteReaction = _TestInfiniteReaction(onFire: () => count++);
      final doc = _twoParaDoc();
      final editor = Editor(editContext: _ctx(doc), reactions: [infiniteReaction]);

      // Should NOT hang — the Editor must stop after a max-depth limit.
      expect(
        () => editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X'))),
        returnsNormally,
      );
      // Reaction ran at least once but fewer than an arbitrary large number.
      expect(count, lessThan(100));
      editor.dispose();
    });
  });

  // =========================================================================
  // Editor — dispose
  // =========================================================================

  group('Editor.dispose', () {
    test('1. dispose does not throw', () {
      final doc = _twoParaDoc();
      final editor = Editor(editContext: _ctx(doc));
      expect(() => editor.dispose(), returnsNormally);
    });
  });
}

/// Reaction that always produces a new request (for cycle-limit testing).
class _TestInfiniteReaction implements EditReaction {
  _TestInfiniteReaction({required this.onFire});
  final void Function() onFire;

  @override
  List<EditRequest> react(
    EditContext context,
    List<EditRequest> requests,
    List<DocumentChangeEvent> changes,
  ) {
    onFire();
    return [InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('x'))];
  }
}
