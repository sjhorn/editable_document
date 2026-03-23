/// Tests for [EditRequest] and all concrete request subtypes.
library;

import 'dart:ui' show TextAlign;

import 'package:editable_document/editable_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // =========================================================================
  // InsertTextRequest
  // =========================================================================

  group('InsertTextRequest', () {
    test('1. stores nodeId, offset, and text', () {
      final text = AttributedText('hello');
      final req = InsertTextRequest(nodeId: 'p1', offset: 3, text: text);

      expect(req.nodeId, 'p1');
      expect(req.offset, 3);
      expect(req.text, same(text));
    });

    test('2. equality: same fields are equal', () {
      final text = AttributedText('hello');
      final a = InsertTextRequest(nodeId: 'p1', offset: 3, text: text);
      final b = InsertTextRequest(nodeId: 'p1', offset: 3, text: text);
      expect(a, equals(b));
    });

    test('3. equality: different nodeId not equal', () {
      final text = AttributedText('hello');
      final a = InsertTextRequest(nodeId: 'p1', offset: 3, text: text);
      final b = InsertTextRequest(nodeId: 'p2', offset: 3, text: text);
      expect(a, isNot(equals(b)));
    });

    test('4. toString includes class name and key fields', () {
      final req = InsertTextRequest(nodeId: 'p1', offset: 3, text: AttributedText('x'));
      expect(req.toString(), contains('InsertTextRequest'));
      expect(req.toString(), contains('p1'));
    });
  });

  // =========================================================================
  // DeleteContentRequest
  // =========================================================================

  group('DeleteContentRequest', () {
    test('1. stores selection', () {
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );
      final req = DeleteContentRequest(selection: sel);
      expect(req.selection, equals(sel));
    });

    test('2. equality: same selection equal', () {
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );
      expect(DeleteContentRequest(selection: sel), equals(DeleteContentRequest(selection: sel)));
    });

    test('3. toString includes class name', () {
      final sel = const DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
      );
      expect(DeleteContentRequest(selection: sel).toString(), contains('DeleteContentRequest'));
    });
  });

  // =========================================================================
  // ReplaceNodeRequest
  // =========================================================================

  group('ReplaceNodeRequest', () {
    test('1. stores nodeId and newNode', () {
      final newNode = ParagraphNode(id: 'p1', text: AttributedText('New'));
      final req = ReplaceNodeRequest(nodeId: 'p1', newNode: newNode);
      expect(req.nodeId, 'p1');
      expect(req.newNode, same(newNode));
    });

    test('2. equality: same fields equal', () {
      final newNode = ParagraphNode(id: 'p1', text: AttributedText('New'));
      final a = ReplaceNodeRequest(nodeId: 'p1', newNode: newNode);
      final b = ReplaceNodeRequest(nodeId: 'p1', newNode: newNode);
      expect(a, equals(b));
    });

    test('3. toString includes class name', () {
      final req = ReplaceNodeRequest(
        nodeId: 'p1',
        newNode: ParagraphNode(id: 'p1', text: AttributedText('')),
      );
      expect(req.toString(), contains('ReplaceNodeRequest'));
    });
  });

  // =========================================================================
  // SplitParagraphRequest
  // =========================================================================

  group('SplitParagraphRequest', () {
    test('1. stores nodeId and splitOffset', () {
      final req = const SplitParagraphRequest(nodeId: 'p1', splitOffset: 5);
      expect(req.nodeId, 'p1');
      expect(req.splitOffset, 5);
    });

    test('2. equality: same fields equal', () {
      final a = const SplitParagraphRequest(nodeId: 'p1', splitOffset: 5);
      final b = const SplitParagraphRequest(nodeId: 'p1', splitOffset: 5);
      expect(a, equals(b));
    });

    test('3. equality: different offset not equal', () {
      final a = const SplitParagraphRequest(nodeId: 'p1', splitOffset: 5);
      final b = const SplitParagraphRequest(nodeId: 'p1', splitOffset: 6);
      expect(a, isNot(equals(b)));
    });

    test('4. toString includes class name', () {
      expect(
        const SplitParagraphRequest(nodeId: 'p1', splitOffset: 5).toString(),
        contains('SplitParagraphRequest'),
      );
    });
  });

  // =========================================================================
  // MergeNodeRequest
  // =========================================================================

  group('MergeNodeRequest', () {
    test('1. stores firstNodeId and secondNodeId', () {
      final req = const MergeNodeRequest(firstNodeId: 'p1', secondNodeId: 'p2');
      expect(req.firstNodeId, 'p1');
      expect(req.secondNodeId, 'p2');
    });

    test('2. equality', () {
      final a = const MergeNodeRequest(firstNodeId: 'p1', secondNodeId: 'p2');
      final b = const MergeNodeRequest(firstNodeId: 'p1', secondNodeId: 'p2');
      expect(a, equals(b));
    });

    test('3. toString includes class name', () {
      expect(
        const MergeNodeRequest(firstNodeId: 'p1', secondNodeId: 'p2').toString(),
        contains('MergeNodeRequest'),
      );
    });
  });

  // =========================================================================
  // MoveNodeRequest
  // =========================================================================

  group('MoveNodeRequest', () {
    test('1. stores nodeId and newIndex', () {
      final req = const MoveNodeRequest(nodeId: 'p1', newIndex: 2);
      expect(req.nodeId, 'p1');
      expect(req.newIndex, 2);
    });

    test('2. equality', () {
      expect(
        const MoveNodeRequest(nodeId: 'p1', newIndex: 2),
        equals(const MoveNodeRequest(nodeId: 'p1', newIndex: 2)),
      );
    });

    test('3. toString includes class name', () {
      expect(
        const MoveNodeRequest(nodeId: 'p1', newIndex: 2).toString(),
        contains('MoveNodeRequest'),
      );
    });
  });

  // =========================================================================
  // ChangeBlockTypeRequest
  // =========================================================================

  group('ChangeBlockTypeRequest', () {
    test('1. stores nodeId and newBlockType', () {
      final req = const ChangeBlockTypeRequest(
        nodeId: 'p1',
        newBlockType: ParagraphBlockType.header1,
      );
      expect(req.nodeId, 'p1');
      expect(req.newBlockType, ParagraphBlockType.header1);
    });

    test('2. equality', () {
      final a =
          const ChangeBlockTypeRequest(nodeId: 'p1', newBlockType: ParagraphBlockType.header2);
      final b =
          const ChangeBlockTypeRequest(nodeId: 'p1', newBlockType: ParagraphBlockType.header2);
      expect(a, equals(b));
    });

    test('3. toString includes class name', () {
      expect(
        const ChangeBlockTypeRequest(nodeId: 'p1', newBlockType: ParagraphBlockType.paragraph)
            .toString(),
        contains('ChangeBlockTypeRequest'),
      );
    });
  });

  // =========================================================================
  // ApplyAttributionRequest
  // =========================================================================

  group('ApplyAttributionRequest', () {
    test('1. stores selection and attribution', () {
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );
      final req = ApplyAttributionRequest(
        selection: sel,
        attribution: NamedAttribution.bold,
      );
      expect(req.selection, equals(sel));
      expect(req.attribution, equals(NamedAttribution.bold));
    });

    test('2. equality', () {
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );
      final a = ApplyAttributionRequest(selection: sel, attribution: NamedAttribution.bold);
      final b = ApplyAttributionRequest(selection: sel, attribution: NamedAttribution.bold);
      expect(a, equals(b));
    });

    test('3. toString includes class name', () {
      final sel = const DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
      );
      expect(
        ApplyAttributionRequest(selection: sel, attribution: NamedAttribution.bold).toString(),
        contains('ApplyAttributionRequest'),
      );
    });
  });

  // =========================================================================
  // RemoveAttributionRequest
  // =========================================================================

  group('RemoveAttributionRequest', () {
    test('1. stores selection and attribution', () {
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );
      final req = RemoveAttributionRequest(
        selection: sel,
        attribution: NamedAttribution.bold,
      );
      expect(req.selection, equals(sel));
      expect(req.attribution, equals(NamedAttribution.bold));
    });

    test('2. equality', () {
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );
      final a = RemoveAttributionRequest(selection: sel, attribution: NamedAttribution.bold);
      final b = RemoveAttributionRequest(selection: sel, attribution: NamedAttribution.bold);
      expect(a, equals(b));
    });

    test('3. toString includes class name', () {
      final sel = const DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
      );
      expect(
        RemoveAttributionRequest(selection: sel, attribution: NamedAttribution.bold).toString(),
        contains('RemoveAttributionRequest'),
      );
    });
  });

  // =========================================================================
  // ExitBlockquoteRequest
  // =========================================================================

  group('ExitBlockquoteRequest', () {
    test('1. stores nodeId, splitOffset, and removeTrailingNewline', () {
      final req = const ExitBlockquoteRequest(
        nodeId: 'bq1',
        splitOffset: 5,
        removeTrailingNewline: true,
      );
      expect(req.nodeId, 'bq1');
      expect(req.splitOffset, 5);
      expect(req.removeTrailingNewline, isTrue);
    });

    test('2. removeTrailingNewline defaults to false', () {
      final req = const ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 3);
      expect(req.removeTrailingNewline, isFalse);
    });

    test('3. equality: same fields are equal', () {
      final a = const ExitBlockquoteRequest(
        nodeId: 'bq1',
        splitOffset: 5,
        removeTrailingNewline: true,
      );
      final b = const ExitBlockquoteRequest(
        nodeId: 'bq1',
        splitOffset: 5,
        removeTrailingNewline: true,
      );
      expect(a, equals(b));
    });

    test('4. equality: different splitOffset not equal', () {
      final a = const ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 5);
      final b = const ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 6);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different removeTrailingNewline not equal', () {
      final a =
          const ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 5, removeTrailingNewline: true);
      final b =
          const ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 5, removeTrailingNewline: false);
      expect(a, isNot(equals(b)));
    });

    test('6. hashCode is consistent with equality', () {
      final a = const ExitBlockquoteRequest(
        nodeId: 'bq1',
        splitOffset: 5,
        removeTrailingNewline: true,
      );
      final b = const ExitBlockquoteRequest(
        nodeId: 'bq1',
        splitOffset: 5,
        removeTrailingNewline: true,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('7. toString includes class name and key fields', () {
      final req = const ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 3);
      expect(req.toString(), contains('ExitBlockquoteRequest'));
      expect(req.toString(), contains('bq1'));
      expect(req.toString(), contains('3'));
    });
  });

  // =========================================================================
  // ChangeTextAlignRequest
  // =========================================================================

  group('ChangeTextAlignRequest', () {
    test('1. stores nodeId and newTextAlign', () {
      final req = const ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.center);
      expect(req.nodeId, 'p1');
      expect(req.newTextAlign, TextAlign.center);
    });

    test('2. equality: same fields are equal', () {
      final a = const ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.center);
      final b = const ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.center);
      expect(a, equals(b));
    });

    test('3. equality: different nodeId not equal', () {
      final a = const ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.center);
      final b = const ChangeTextAlignRequest(nodeId: 'p2', newTextAlign: TextAlign.center);
      expect(a, isNot(equals(b)));
    });

    test('4. equality: different newTextAlign not equal', () {
      final a = const ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.start);
      final b = const ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.center);
      expect(a, isNot(equals(b)));
    });

    test('5. hashCode is consistent with equality', () {
      final a = const ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.end);
      final b = const ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.end);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('6. toString includes class name and key fields', () {
      final req = const ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.justify);
      expect(req.toString(), contains('ChangeTextAlignRequest'));
      expect(req.toString(), contains('p1'));
      expect(req.toString(), contains('justify'));
    });
  });

  // =========================================================================
  // ChangeLineHeightRequest
  // =========================================================================

  group('ChangeLineHeightRequest', () {
    test('1. stores nodeId and newLineHeight', () {
      final req = const ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
      expect(req.nodeId, 'p1');
      expect(req.newLineHeight, 1.5);
    });

    test('2. stores null newLineHeight', () {
      final req = const ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: null);
      expect(req.nodeId, 'p1');
      expect(req.newLineHeight, isNull);
    });

    test('3. equality: same fields are equal', () {
      final a = const ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
      final b = const ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
      expect(a, equals(b));
    });

    test('4. equality: different nodeId not equal', () {
      final a = const ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
      final b = const ChangeLineHeightRequest(nodeId: 'p2', newLineHeight: 1.5);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different newLineHeight not equal', () {
      final a = const ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.0);
      final b = const ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
      expect(a, isNot(equals(b)));
    });

    test('6. hashCode is consistent with equality', () {
      final a = const ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 2.0);
      final b = const ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 2.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('7. toString includes class name and key fields', () {
      final req = const ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
      expect(req.toString(), contains('ChangeLineHeightRequest'));
      expect(req.toString(), contains('p1'));
      expect(req.toString(), contains('1.5'));
    });
  });

  // =========================================================================
  // ChangeIndentRequest
  // =========================================================================

  group('ChangeIndentRequest', () {
    test('1. stores nodeId and indent values', () {
      final req = const ChangeIndentRequest(
        nodeId: 'p1',
        newIndentLeft: 16.0,
        newIndentRight: 8.0,
        newFirstLineIndent: 24.0,
      );
      expect(req.nodeId, 'p1');
      expect(req.newIndentLeft, 16.0);
      expect(req.newIndentRight, 8.0);
      expect(req.newFirstLineIndent, 24.0);
    });

    test('2. accepts all null indent values', () {
      final req = const ChangeIndentRequest(nodeId: 'p1');
      expect(req.newIndentLeft, isNull);
      expect(req.newIndentRight, isNull);
      expect(req.newFirstLineIndent, isNull);
    });

    test('3. equality: same fields are equal', () {
      final a = const ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0, newIndentRight: 8.0);
      final b = const ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0, newIndentRight: 8.0);
      expect(a, equals(b));
    });

    test('4. equality: different nodeId not equal', () {
      final a = const ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0);
      final b = const ChangeIndentRequest(nodeId: 'p2', newIndentLeft: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different newIndentLeft not equal', () {
      final a = const ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 8.0);
      final b = const ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('6. equality: different newIndentRight not equal', () {
      final a = const ChangeIndentRequest(nodeId: 'p1', newIndentRight: 4.0);
      final b = const ChangeIndentRequest(nodeId: 'p1', newIndentRight: 8.0);
      expect(a, isNot(equals(b)));
    });

    test('7. equality: different newFirstLineIndent not equal', () {
      final a = const ChangeIndentRequest(nodeId: 'p1', newFirstLineIndent: 16.0);
      final b = const ChangeIndentRequest(nodeId: 'p1', newFirstLineIndent: 24.0);
      expect(a, isNot(equals(b)));
    });

    test('8. hashCode is consistent with equality', () {
      final a = const ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0, newIndentRight: 8.0);
      final b = const ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0, newIndentRight: 8.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('9. toString includes class name and key fields', () {
      final req = const ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0, newIndentRight: 8.0);
      expect(req.toString(), contains('ChangeIndentRequest'));
      expect(req.toString(), contains('p1'));
      expect(req.toString(), contains('16.0'));
      expect(req.toString(), contains('8.0'));
    });
  });

  // =========================================================================
  // ChangeSpacingRequest
  // =========================================================================

  group('ChangeSpacingRequest', () {
    test('1. stores nodeId and spacing values', () {
      final req =
          const ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
      expect(req.nodeId, 'p1');
      expect(req.newSpaceBefore, 8.0);
      expect(req.newSpaceAfter, 16.0);
    });

    test('2. accepts null spacing values', () {
      final req = const ChangeSpacingRequest(nodeId: 'p1');
      expect(req.newSpaceBefore, isNull);
      expect(req.newSpaceAfter, isNull);
    });

    test('3. equality: same fields are equal', () {
      final a = const ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
      final b = const ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
      expect(a, equals(b));
    });

    test('4. equality: different nodeId not equal', () {
      final a = const ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0);
      final b = const ChangeSpacingRequest(nodeId: 'p2', newSpaceBefore: 8.0);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different newSpaceBefore not equal', () {
      final a = const ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 4.0);
      final b = const ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0);
      expect(a, isNot(equals(b)));
    });

    test('6. equality: different newSpaceAfter not equal', () {
      final a = const ChangeSpacingRequest(nodeId: 'p1', newSpaceAfter: 4.0);
      final b = const ChangeSpacingRequest(nodeId: 'p1', newSpaceAfter: 8.0);
      expect(a, isNot(equals(b)));
    });

    test('7. hashCode is consistent with equality', () {
      final a = const ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
      final b = const ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('8. toString includes class name and key fields', () {
      final req =
          const ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
      expect(req.toString(), contains('ChangeSpacingRequest'));
      expect(req.toString(), contains('p1'));
      expect(req.toString(), contains('8.0'));
      expect(req.toString(), contains('16.0'));
    });
  });

  // =========================================================================
  // InsertNodeAtPositionRequest
  // =========================================================================

  group('InsertNodeAtPositionRequest', () {
    test('1. toString includes class name and key fields', () {
      final node = HorizontalRuleNode(id: 'hr1');
      final req = InsertNodeAtPositionRequest(
        node: node,
        position: const DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );
      expect(req.toString(), contains('InsertNodeAtPositionRequest'));
      expect(req.toString(), contains('hr1'));
    });

    test('2. equality: same fields are equal', () {
      final node = HorizontalRuleNode(id: 'hr1');
      final pos = const DocumentPosition(
        nodeId: 'p1',
        nodePosition: TextNodePosition(offset: 3),
      );
      final a = InsertNodeAtPositionRequest(node: node, position: pos);
      final b = InsertNodeAtPositionRequest(node: node, position: pos);
      expect(a, equals(b));
    });

    test('3. equality: different node not equal', () {
      final pos = const DocumentPosition(
        nodeId: 'p1',
        nodePosition: TextNodePosition(offset: 3),
      );
      final a = InsertNodeAtPositionRequest(
        node: HorizontalRuleNode(id: 'hr1'),
        position: pos,
      );
      final b = InsertNodeAtPositionRequest(
        node: HorizontalRuleNode(id: 'hr2'),
        position: pos,
      );
      expect(a, isNot(equals(b)));
    });

    test('4. equality: different position not equal', () {
      final node = HorizontalRuleNode(id: 'hr1');
      final a = InsertNodeAtPositionRequest(
        node: node,
        position: const DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
      );
      final b = InsertNodeAtPositionRequest(
        node: node,
        position: const DocumentPosition(
          nodeId: 'p2',
          nodePosition: TextNodePosition(offset: 0),
        ),
      );
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different followOnNode not equal', () {
      final node = HorizontalRuleNode(id: 'hr1');
      final a = InsertNodeAtPositionRequest(node: node);
      final b = InsertNodeAtPositionRequest(
        node: node,
        followOnNode: ParagraphNode(id: 'follow', text: AttributedText('')),
      );
      expect(a, isNot(equals(b)));
    });

    test('6. hashCode is consistent with equality', () {
      final node = HorizontalRuleNode(id: 'hr1');
      final pos = const DocumentPosition(
        nodeId: 'p1',
        nodePosition: TextNodePosition(offset: 3),
      );
      final a = InsertNodeAtPositionRequest(node: node, position: pos);
      final b = InsertNodeAtPositionRequest(node: node, position: pos);
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // =========================================================================
  // IndentListItemRequest
  // =========================================================================

  group('IndentListItemRequest', () {
    test('1. stores nodeId', () {
      final req = const IndentListItemRequest(nodeId: 'li1');
      expect(req.nodeId, 'li1');
    });

    test('2. equality: same nodeId equal', () {
      final a = const IndentListItemRequest(nodeId: 'li1');
      final b = const IndentListItemRequest(nodeId: 'li1');
      expect(a, equals(b));
    });

    test('3. equality: different nodeId not equal', () {
      final a = const IndentListItemRequest(nodeId: 'li1');
      final b = const IndentListItemRequest(nodeId: 'li2');
      expect(a, isNot(equals(b)));
    });

    test('4. hashCode is consistent with equality', () {
      final a = const IndentListItemRequest(nodeId: 'li1');
      final b = const IndentListItemRequest(nodeId: 'li1');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('5. toString includes class name and nodeId', () {
      final req = const IndentListItemRequest(nodeId: 'li1');
      expect(req.toString(), contains('IndentListItemRequest'));
      expect(req.toString(), contains('li1'));
    });
  });

  // =========================================================================
  // UnindentListItemRequest
  // =========================================================================

  group('UnindentListItemRequest', () {
    test('1. stores nodeId', () {
      final req = const UnindentListItemRequest(nodeId: 'li1');
      expect(req.nodeId, 'li1');
    });

    test('2. equality: same nodeId equal', () {
      final a = const UnindentListItemRequest(nodeId: 'li1');
      final b = const UnindentListItemRequest(nodeId: 'li1');
      expect(a, equals(b));
    });

    test('3. equality: different nodeId not equal', () {
      final a = const UnindentListItemRequest(nodeId: 'li1');
      final b = const UnindentListItemRequest(nodeId: 'li2');
      expect(a, isNot(equals(b)));
    });

    test('4. hashCode is consistent with equality', () {
      final a = const UnindentListItemRequest(nodeId: 'li1');
      final b = const UnindentListItemRequest(nodeId: 'li1');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('5. toString includes class name and nodeId', () {
      final req = const UnindentListItemRequest(nodeId: 'li1');
      expect(req.toString(), contains('UnindentListItemRequest'));
      expect(req.toString(), contains('li1'));
    });
  });

  // =========================================================================
  // ConvertListItemToParagraphRequest
  // =========================================================================

  group('ConvertListItemToParagraphRequest', () {
    test('1. stores nodeId', () {
      final req = const ConvertListItemToParagraphRequest(nodeId: 'li1');
      expect(req.nodeId, 'li1');
    });

    test('2. equality: same nodeId equal', () {
      final a = const ConvertListItemToParagraphRequest(nodeId: 'li1');
      final b = const ConvertListItemToParagraphRequest(nodeId: 'li1');
      expect(a, equals(b));
    });

    test('3. equality: different nodeId not equal', () {
      final a = const ConvertListItemToParagraphRequest(nodeId: 'li1');
      final b = const ConvertListItemToParagraphRequest(nodeId: 'li2');
      expect(a, isNot(equals(b)));
    });

    test('4. hashCode is consistent with equality', () {
      final a = const ConvertListItemToParagraphRequest(nodeId: 'li1');
      final b = const ConvertListItemToParagraphRequest(nodeId: 'li1');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('5. toString includes class name and nodeId', () {
      final req = const ConvertListItemToParagraphRequest(nodeId: 'li1');
      expect(req.toString(), contains('ConvertListItemToParagraphRequest'));
      expect(req.toString(), contains('li1'));
    });
  });

  // =========================================================================
  // ExitCodeBlockRequest
  // =========================================================================

  group('ExitCodeBlockRequest', () {
    test('1. stores nodeId, splitOffset, and removeTrailingNewline', () {
      final req = const ExitCodeBlockRequest(
        nodeId: 'cb1',
        splitOffset: 4,
        removeTrailingNewline: true,
      );
      expect(req.nodeId, 'cb1');
      expect(req.splitOffset, 4);
      expect(req.removeTrailingNewline, isTrue);
    });

    test('2. removeTrailingNewline defaults to false', () {
      final req = const ExitCodeBlockRequest(nodeId: 'cb1', splitOffset: 0);
      expect(req.removeTrailingNewline, isFalse);
    });

    test('3. equality: same fields equal', () {
      final a =
          const ExitCodeBlockRequest(nodeId: 'cb1', splitOffset: 4, removeTrailingNewline: true);
      final b =
          const ExitCodeBlockRequest(nodeId: 'cb1', splitOffset: 4, removeTrailingNewline: true);
      expect(a, equals(b));
    });

    test('4. equality: different splitOffset not equal', () {
      final a = const ExitCodeBlockRequest(nodeId: 'cb1', splitOffset: 4);
      final b = const ExitCodeBlockRequest(nodeId: 'cb1', splitOffset: 5);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different removeTrailingNewline not equal', () {
      final a =
          const ExitCodeBlockRequest(nodeId: 'cb1', splitOffset: 4, removeTrailingNewline: true);
      final b =
          const ExitCodeBlockRequest(nodeId: 'cb1', splitOffset: 4, removeTrailingNewline: false);
      expect(a, isNot(equals(b)));
    });

    test('6. hashCode is consistent with equality', () {
      final a =
          const ExitCodeBlockRequest(nodeId: 'cb1', splitOffset: 4, removeTrailingNewline: true);
      final b =
          const ExitCodeBlockRequest(nodeId: 'cb1', splitOffset: 4, removeTrailingNewline: true);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('7. toString includes class name and key fields', () {
      final req = const ExitCodeBlockRequest(nodeId: 'cb1', splitOffset: 4);
      expect(req.toString(), contains('ExitCodeBlockRequest'));
      expect(req.toString(), contains('cb1'));
      expect(req.toString(), contains('4'));
    });
  });

  // =========================================================================
  // InsertTextAtBinaryNodeRequest
  // =========================================================================

  group('InsertTextAtBinaryNodeRequest', () {
    test('1. stores nodeId, nodePosition, and text', () {
      final text = AttributedText('hi');
      final req = InsertTextAtBinaryNodeRequest(
        nodeId: 'hr1',
        nodePosition: BinaryNodePositionType.downstream,
        text: text,
      );
      expect(req.nodeId, 'hr1');
      expect(req.nodePosition, BinaryNodePositionType.downstream);
      expect(req.text, equals(text));
    });

    test('2. equality: same fields equal', () {
      final text = AttributedText('x');
      final a = InsertTextAtBinaryNodeRequest(
        nodeId: 'hr1',
        nodePosition: BinaryNodePositionType.upstream,
        text: text,
      );
      final b = InsertTextAtBinaryNodeRequest(
        nodeId: 'hr1',
        nodePosition: BinaryNodePositionType.upstream,
        text: text,
      );
      expect(a, equals(b));
    });

    test('3. equality: different nodePosition not equal', () {
      final text = AttributedText('x');
      final a = InsertTextAtBinaryNodeRequest(
        nodeId: 'hr1',
        nodePosition: BinaryNodePositionType.upstream,
        text: text,
      );
      final b = InsertTextAtBinaryNodeRequest(
        nodeId: 'hr1',
        nodePosition: BinaryNodePositionType.downstream,
        text: text,
      );
      expect(a, isNot(equals(b)));
    });

    test('4. hashCode is consistent with equality', () {
      final text = AttributedText('x');
      final a = InsertTextAtBinaryNodeRequest(
        nodeId: 'hr1',
        nodePosition: BinaryNodePositionType.downstream,
        text: text,
      );
      final b = InsertTextAtBinaryNodeRequest(
        nodeId: 'hr1',
        nodePosition: BinaryNodePositionType.downstream,
        text: text,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('5. toString includes class name and key fields', () {
      final req = InsertTextAtBinaryNodeRequest(
        nodeId: 'hr1',
        nodePosition: BinaryNodePositionType.downstream,
        text: AttributedText('x'),
      );
      expect(req.toString(), contains('InsertTextAtBinaryNodeRequest'));
      expect(req.toString(), contains('hr1'));
    });
  });

  // =========================================================================
  // InsertTableRequest
  // =========================================================================

  group('InsertTableRequest', () {
    test('1. stores nodeId, rowCount, columnCount, and insertIndex', () {
      final req = const InsertTableRequest(
        nodeId: 't1',
        rowCount: 3,
        columnCount: 4,
        insertIndex: 2,
      );
      expect(req.nodeId, 't1');
      expect(req.rowCount, 3);
      expect(req.columnCount, 4);
      expect(req.insertIndex, 2);
    });

    test('2. insertIndex defaults to null', () {
      final req = const InsertTableRequest(nodeId: 't1', rowCount: 2, columnCount: 2);
      expect(req.insertIndex, isNull);
    });

    test('3. equality: same fields equal', () {
      final a = const InsertTableRequest(nodeId: 't1', rowCount: 2, columnCount: 3, insertIndex: 1);
      final b = const InsertTableRequest(nodeId: 't1', rowCount: 2, columnCount: 3, insertIndex: 1);
      expect(a, equals(b));
    });

    test('4. equality: different columnCount not equal', () {
      final a = const InsertTableRequest(nodeId: 't1', rowCount: 2, columnCount: 3);
      final b = const InsertTableRequest(nodeId: 't1', rowCount: 2, columnCount: 4);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different insertIndex not equal', () {
      final a = const InsertTableRequest(nodeId: 't1', rowCount: 2, columnCount: 2, insertIndex: 0);
      final b = const InsertTableRequest(nodeId: 't1', rowCount: 2, columnCount: 2, insertIndex: 1);
      expect(a, isNot(equals(b)));
    });

    test('6. hashCode is consistent with equality', () {
      final a = const InsertTableRequest(nodeId: 't1', rowCount: 2, columnCount: 2);
      final b = const InsertTableRequest(nodeId: 't1', rowCount: 2, columnCount: 2);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('7. toString includes class name and key fields', () {
      final req = const InsertTableRequest(nodeId: 't1', rowCount: 3, columnCount: 4);
      expect(req.toString(), contains('InsertTableRequest'));
      expect(req.toString(), contains('t1'));
      expect(req.toString(), contains('3'));
      expect(req.toString(), contains('4'));
    });
  });

  // =========================================================================
  // UpdateTableCellRequest
  // =========================================================================

  group('UpdateTableCellRequest', () {
    test('1. stores all fields', () {
      final text = AttributedText('cell');
      final req = UpdateTableCellRequest(
        nodeId: 't1',
        row: 1,
        col: 2,
        newText: text,
        newCursorOffset: 3,
      );
      expect(req.nodeId, 't1');
      expect(req.row, 1);
      expect(req.col, 2);
      expect(req.newText, equals(text));
      expect(req.newCursorOffset, 3);
    });

    test('2. newCursorOffset defaults to null', () {
      final req = UpdateTableCellRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        newText: AttributedText(''),
      );
      expect(req.newCursorOffset, isNull);
    });

    test('3. equality: same fields equal', () {
      final text = AttributedText('x');
      final a = UpdateTableCellRequest(
        nodeId: 't1',
        row: 0,
        col: 1,
        newText: text,
        newCursorOffset: 1,
      );
      final b = UpdateTableCellRequest(
        nodeId: 't1',
        row: 0,
        col: 1,
        newText: text,
        newCursorOffset: 1,
      );
      expect(a, equals(b));
    });

    test('4. equality: different col not equal', () {
      final text = AttributedText('');
      final a = UpdateTableCellRequest(nodeId: 't1', row: 0, col: 0, newText: text);
      final b = UpdateTableCellRequest(nodeId: 't1', row: 0, col: 1, newText: text);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different newCursorOffset not equal', () {
      final text = AttributedText('x');
      final a = UpdateTableCellRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        newText: text,
        newCursorOffset: 0,
      );
      final b = UpdateTableCellRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        newText: text,
        newCursorOffset: 1,
      );
      expect(a, isNot(equals(b)));
    });

    test('6. hashCode is consistent with equality', () {
      final text = AttributedText('v');
      final a = UpdateTableCellRequest(nodeId: 't1', row: 1, col: 2, newText: text);
      final b = UpdateTableCellRequest(nodeId: 't1', row: 1, col: 2, newText: text);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('7. toString includes class name and key fields', () {
      final req = UpdateTableCellRequest(
        nodeId: 't1',
        row: 1,
        col: 2,
        newText: AttributedText('v'),
      );
      expect(req.toString(), contains('UpdateTableCellRequest'));
      expect(req.toString(), contains('t1'));
      expect(req.toString(), contains('1'));
      expect(req.toString(), contains('2'));
    });
  });

  // =========================================================================
  // DeleteTableRequest
  // =========================================================================

  group('DeleteTableRequest', () {
    test('1. stores nodeId', () {
      final req = const DeleteTableRequest(nodeId: 't1');
      expect(req.nodeId, 't1');
    });

    test('2. equality: same nodeId equal', () {
      final a = const DeleteTableRequest(nodeId: 't1');
      final b = const DeleteTableRequest(nodeId: 't1');
      expect(a, equals(b));
    });

    test('3. equality: different nodeId not equal', () {
      final a = const DeleteTableRequest(nodeId: 't1');
      final b = const DeleteTableRequest(nodeId: 't2');
      expect(a, isNot(equals(b)));
    });

    test('4. hashCode is consistent with equality', () {
      final a = const DeleteTableRequest(nodeId: 't1');
      final b = const DeleteTableRequest(nodeId: 't1');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('5. toString includes class name and nodeId', () {
      final req = const DeleteTableRequest(nodeId: 't1');
      expect(req.toString(), contains('DeleteTableRequest'));
      expect(req.toString(), contains('t1'));
    });
  });

  // =========================================================================
  // MoveNodeToPositionRequest
  // =========================================================================

  group('MoveNodeToPositionRequest', () {
    test('1. stores nodeId and position', () {
      const pos = DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0));
      final req = const MoveNodeToPositionRequest(nodeId: 'hr1', position: pos);
      expect(req.nodeId, 'hr1');
      expect(req.position, equals(pos));
    });

    test('2. equality: same fields equal', () {
      const pos = DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0));
      final a = const MoveNodeToPositionRequest(nodeId: 'hr1', position: pos);
      final b = const MoveNodeToPositionRequest(nodeId: 'hr1', position: pos);
      expect(a, equals(b));
    });

    test('3. equality: different nodeId not equal', () {
      const pos = DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0));
      final a = const MoveNodeToPositionRequest(nodeId: 'hr1', position: pos);
      final b = const MoveNodeToPositionRequest(nodeId: 'hr2', position: pos);
      expect(a, isNot(equals(b)));
    });

    test('4. equality: different position not equal', () {
      final a = const MoveNodeToPositionRequest(
        nodeId: 'hr1',
        position: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
      );
      final b = const MoveNodeToPositionRequest(
        nodeId: 'hr1',
        position: DocumentPosition(nodeId: 'p2', nodePosition: TextNodePosition(offset: 0)),
      );
      expect(a, isNot(equals(b)));
    });

    test('5. hashCode is consistent with equality', () {
      const pos = DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0));
      final a = const MoveNodeToPositionRequest(nodeId: 'hr1', position: pos);
      final b = const MoveNodeToPositionRequest(nodeId: 'hr1', position: pos);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('6. toString includes class name and key fields', () {
      final req = const MoveNodeToPositionRequest(
        nodeId: 'hr1',
        position: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
      );
      expect(req.toString(), contains('MoveNodeToPositionRequest'));
      expect(req.toString(), contains('hr1'));
    });
  });

  // =========================================================================
  // InsertTableRowRequest
  // =========================================================================

  group('InsertTableRowRequest', () {
    test('1. stores nodeId, rowIndex, and insertBefore', () {
      final req = const InsertTableRowRequest(nodeId: 't1', rowIndex: 2, insertBefore: false);
      expect(req.nodeId, 't1');
      expect(req.rowIndex, 2);
      expect(req.insertBefore, isFalse);
    });

    test('2. insertBefore defaults to true', () {
      final req = const InsertTableRowRequest(nodeId: 't1', rowIndex: 0);
      expect(req.insertBefore, isTrue);
    });

    test('3. equality: same fields equal', () {
      final a = const InsertTableRowRequest(nodeId: 't1', rowIndex: 1, insertBefore: false);
      final b = const InsertTableRowRequest(nodeId: 't1', rowIndex: 1, insertBefore: false);
      expect(a, equals(b));
    });

    test('4. equality: different insertBefore not equal', () {
      final a = const InsertTableRowRequest(nodeId: 't1', rowIndex: 1, insertBefore: true);
      final b = const InsertTableRowRequest(nodeId: 't1', rowIndex: 1, insertBefore: false);
      expect(a, isNot(equals(b)));
    });

    test('5. hashCode is consistent with equality', () {
      final a = const InsertTableRowRequest(nodeId: 't1', rowIndex: 1);
      final b = const InsertTableRowRequest(nodeId: 't1', rowIndex: 1);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('6. toString includes class name and key fields', () {
      final req = const InsertTableRowRequest(nodeId: 't1', rowIndex: 2);
      expect(req.toString(), contains('InsertTableRowRequest'));
      expect(req.toString(), contains('t1'));
      expect(req.toString(), contains('2'));
    });
  });

  // =========================================================================
  // InsertTableColumnRequest
  // =========================================================================

  group('InsertTableColumnRequest', () {
    test('1. stores nodeId, colIndex, and insertBefore', () {
      final req = const InsertTableColumnRequest(nodeId: 't1', colIndex: 1, insertBefore: false);
      expect(req.nodeId, 't1');
      expect(req.colIndex, 1);
      expect(req.insertBefore, isFalse);
    });

    test('2. insertBefore defaults to true', () {
      final req = const InsertTableColumnRequest(nodeId: 't1', colIndex: 0);
      expect(req.insertBefore, isTrue);
    });

    test('3. equality: same fields equal', () {
      final a = const InsertTableColumnRequest(nodeId: 't1', colIndex: 2, insertBefore: true);
      final b = const InsertTableColumnRequest(nodeId: 't1', colIndex: 2, insertBefore: true);
      expect(a, equals(b));
    });

    test('4. equality: different colIndex not equal', () {
      final a = const InsertTableColumnRequest(nodeId: 't1', colIndex: 1);
      final b = const InsertTableColumnRequest(nodeId: 't1', colIndex: 2);
      expect(a, isNot(equals(b)));
    });

    test('5. hashCode is consistent with equality', () {
      final a = const InsertTableColumnRequest(nodeId: 't1', colIndex: 1);
      final b = const InsertTableColumnRequest(nodeId: 't1', colIndex: 1);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('6. toString includes class name and key fields', () {
      final req = const InsertTableColumnRequest(nodeId: 't1', colIndex: 1);
      expect(req.toString(), contains('InsertTableColumnRequest'));
      expect(req.toString(), contains('t1'));
      expect(req.toString(), contains('1'));
    });
  });

  // =========================================================================
  // DeleteTableRowRequest
  // =========================================================================

  group('DeleteTableRowRequest', () {
    test('1. stores nodeId and rowIndex', () {
      final req = const DeleteTableRowRequest(nodeId: 't1', rowIndex: 2);
      expect(req.nodeId, 't1');
      expect(req.rowIndex, 2);
    });

    test('2. equality: same fields equal', () {
      final a = const DeleteTableRowRequest(nodeId: 't1', rowIndex: 2);
      final b = const DeleteTableRowRequest(nodeId: 't1', rowIndex: 2);
      expect(a, equals(b));
    });

    test('3. equality: different rowIndex not equal', () {
      final a = const DeleteTableRowRequest(nodeId: 't1', rowIndex: 1);
      final b = const DeleteTableRowRequest(nodeId: 't1', rowIndex: 2);
      expect(a, isNot(equals(b)));
    });

    test('4. hashCode is consistent with equality', () {
      final a = const DeleteTableRowRequest(nodeId: 't1', rowIndex: 0);
      final b = const DeleteTableRowRequest(nodeId: 't1', rowIndex: 0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('5. toString includes class name and key fields', () {
      final req = const DeleteTableRowRequest(nodeId: 't1', rowIndex: 1);
      expect(req.toString(), contains('DeleteTableRowRequest'));
      expect(req.toString(), contains('t1'));
      expect(req.toString(), contains('1'));
    });
  });

  // =========================================================================
  // DeleteTableColumnRequest
  // =========================================================================

  group('DeleteTableColumnRequest', () {
    test('1. stores nodeId and colIndex', () {
      final req = const DeleteTableColumnRequest(nodeId: 't1', colIndex: 3);
      expect(req.nodeId, 't1');
      expect(req.colIndex, 3);
    });

    test('2. equality: same fields equal', () {
      final a = const DeleteTableColumnRequest(nodeId: 't1', colIndex: 3);
      final b = const DeleteTableColumnRequest(nodeId: 't1', colIndex: 3);
      expect(a, equals(b));
    });

    test('3. equality: different colIndex not equal', () {
      final a = const DeleteTableColumnRequest(nodeId: 't1', colIndex: 2);
      final b = const DeleteTableColumnRequest(nodeId: 't1', colIndex: 3);
      expect(a, isNot(equals(b)));
    });

    test('4. hashCode is consistent with equality', () {
      final a = const DeleteTableColumnRequest(nodeId: 't1', colIndex: 2);
      final b = const DeleteTableColumnRequest(nodeId: 't1', colIndex: 2);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('5. toString includes class name and key fields', () {
      final req = const DeleteTableColumnRequest(nodeId: 't1', colIndex: 2);
      expect(req.toString(), contains('DeleteTableColumnRequest'));
      expect(req.toString(), contains('t1'));
      expect(req.toString(), contains('2'));
    });
  });

  // =========================================================================
  // ResizeTableRequest
  // =========================================================================

  group('ResizeTableRequest', () {
    test('1. stores nodeId, newRowCount, and newColumnCount', () {
      final req = const ResizeTableRequest(nodeId: 't1', newRowCount: 5, newColumnCount: 6);
      expect(req.nodeId, 't1');
      expect(req.newRowCount, 5);
      expect(req.newColumnCount, 6);
    });

    test('2. equality: same fields equal', () {
      final a = const ResizeTableRequest(nodeId: 't1', newRowCount: 3, newColumnCount: 4);
      final b = const ResizeTableRequest(nodeId: 't1', newRowCount: 3, newColumnCount: 4);
      expect(a, equals(b));
    });

    test('3. equality: different newRowCount not equal', () {
      final a = const ResizeTableRequest(nodeId: 't1', newRowCount: 2, newColumnCount: 4);
      final b = const ResizeTableRequest(nodeId: 't1', newRowCount: 3, newColumnCount: 4);
      expect(a, isNot(equals(b)));
    });

    test('4. equality: different newColumnCount not equal', () {
      final a = const ResizeTableRequest(nodeId: 't1', newRowCount: 3, newColumnCount: 3);
      final b = const ResizeTableRequest(nodeId: 't1', newRowCount: 3, newColumnCount: 4);
      expect(a, isNot(equals(b)));
    });

    test('5. hashCode is consistent with equality', () {
      final a = const ResizeTableRequest(nodeId: 't1', newRowCount: 3, newColumnCount: 4);
      final b = const ResizeTableRequest(nodeId: 't1', newRowCount: 3, newColumnCount: 4);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('6. toString includes class name and key fields', () {
      final req = const ResizeTableRequest(nodeId: 't1', newRowCount: 3, newColumnCount: 4);
      expect(req.toString(), contains('ResizeTableRequest'));
      expect(req.toString(), contains('t1'));
      expect(req.toString(), contains('3'));
      expect(req.toString(), contains('4'));
    });
  });

  // =========================================================================
  // ChangeTableCellAlignRequest
  // =========================================================================

  group('ChangeTableCellAlignRequest', () {
    test('1. stores nodeId, row, col, and textAlign', () {
      final req = const ChangeTableCellAlignRequest(
        nodeId: 't1',
        row: 1,
        col: 2,
        textAlign: TextAlign.center,
      );
      expect(req.nodeId, 't1');
      expect(req.row, 1);
      expect(req.col, 2);
      expect(req.textAlign, TextAlign.center);
    });

    test('2. equality: same fields equal', () {
      final a = const ChangeTableCellAlignRequest(
        nodeId: 't1',
        row: 0,
        col: 1,
        textAlign: TextAlign.end,
      );
      final b = const ChangeTableCellAlignRequest(
        nodeId: 't1',
        row: 0,
        col: 1,
        textAlign: TextAlign.end,
      );
      expect(a, equals(b));
    });

    test('3. equality: different textAlign not equal', () {
      final a = const ChangeTableCellAlignRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        textAlign: TextAlign.start,
      );
      final b = const ChangeTableCellAlignRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        textAlign: TextAlign.center,
      );
      expect(a, isNot(equals(b)));
    });

    test('4. hashCode is consistent with equality', () {
      final a = const ChangeTableCellAlignRequest(
        nodeId: 't1',
        row: 1,
        col: 1,
        textAlign: TextAlign.justify,
      );
      final b = const ChangeTableCellAlignRequest(
        nodeId: 't1',
        row: 1,
        col: 1,
        textAlign: TextAlign.justify,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('5. toString includes class name and key fields', () {
      final req = const ChangeTableCellAlignRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        textAlign: TextAlign.center,
      );
      expect(req.toString(), contains('ChangeTableCellAlignRequest'));
      expect(req.toString(), contains('t1'));
      expect(req.toString(), contains('center'));
    });
  });

  // =========================================================================
  // ChangeTableCellVerticalAlignRequest
  // =========================================================================

  group('ChangeTableCellVerticalAlignRequest', () {
    test('1. stores nodeId, row, col, and verticalAlign', () {
      final req = const ChangeTableCellVerticalAlignRequest(
        nodeId: 't1',
        row: 0,
        col: 1,
        verticalAlign: TableVerticalAlignment.middle,
      );
      expect(req.nodeId, 't1');
      expect(req.row, 0);
      expect(req.col, 1);
      expect(req.verticalAlign, TableVerticalAlignment.middle);
    });

    test('2. equality: same fields equal', () {
      final a = const ChangeTableCellVerticalAlignRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        verticalAlign: TableVerticalAlignment.bottom,
      );
      final b = const ChangeTableCellVerticalAlignRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        verticalAlign: TableVerticalAlignment.bottom,
      );
      expect(a, equals(b));
    });

    test('3. equality: different verticalAlign not equal', () {
      final a = const ChangeTableCellVerticalAlignRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        verticalAlign: TableVerticalAlignment.top,
      );
      final b = const ChangeTableCellVerticalAlignRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        verticalAlign: TableVerticalAlignment.bottom,
      );
      expect(a, isNot(equals(b)));
    });

    test('4. hashCode is consistent with equality', () {
      final a = const ChangeTableCellVerticalAlignRequest(
        nodeId: 't1',
        row: 1,
        col: 2,
        verticalAlign: TableVerticalAlignment.middle,
      );
      final b = const ChangeTableCellVerticalAlignRequest(
        nodeId: 't1',
        row: 1,
        col: 2,
        verticalAlign: TableVerticalAlignment.middle,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('5. toString includes class name and key fields', () {
      final req = const ChangeTableCellVerticalAlignRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        verticalAlign: TableVerticalAlignment.top,
      );
      expect(req.toString(), contains('ChangeTableCellVerticalAlignRequest'));
      expect(req.toString(), contains('t1'));
      expect(req.toString(), contains('top'));
    });
  });

  // =========================================================================
  // ChangeTableColumnWidthRequest
  // =========================================================================

  group('ChangeTableColumnWidthRequest', () {
    test('1. stores nodeId, colIndex, and newWidth', () {
      final req = const ChangeTableColumnWidthRequest(nodeId: 't1', colIndex: 2, newWidth: 120.0);
      expect(req.nodeId, 't1');
      expect(req.colIndex, 2);
      expect(req.newWidth, 120.0);
    });

    test('2. accepts null newWidth (auto-size)', () {
      final req = const ChangeTableColumnWidthRequest(nodeId: 't1', colIndex: 0, newWidth: null);
      expect(req.newWidth, isNull);
    });

    test('3. equality: same fields equal', () {
      final a = const ChangeTableColumnWidthRequest(nodeId: 't1', colIndex: 1, newWidth: 80.0);
      final b = const ChangeTableColumnWidthRequest(nodeId: 't1', colIndex: 1, newWidth: 80.0);
      expect(a, equals(b));
    });

    test('4. equality: different newWidth not equal', () {
      final a = const ChangeTableColumnWidthRequest(nodeId: 't1', colIndex: 1, newWidth: 80.0);
      final b = const ChangeTableColumnWidthRequest(nodeId: 't1', colIndex: 1, newWidth: 100.0);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: null vs non-null newWidth not equal', () {
      final a = const ChangeTableColumnWidthRequest(nodeId: 't1', colIndex: 1, newWidth: null);
      final b = const ChangeTableColumnWidthRequest(nodeId: 't1', colIndex: 1, newWidth: 80.0);
      expect(a, isNot(equals(b)));
    });

    test('6. hashCode is consistent with equality', () {
      final a = const ChangeTableColumnWidthRequest(nodeId: 't1', colIndex: 2, newWidth: 120.0);
      final b = const ChangeTableColumnWidthRequest(nodeId: 't1', colIndex: 2, newWidth: 120.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('7. toString includes class name and key fields', () {
      final req = const ChangeTableColumnWidthRequest(nodeId: 't1', colIndex: 2, newWidth: 120.0);
      expect(req.toString(), contains('ChangeTableColumnWidthRequest'));
      expect(req.toString(), contains('t1'));
      expect(req.toString(), contains('120.0'));
    });
  });

  // =========================================================================
  // ChangeTableRowHeightRequest
  // =========================================================================

  group('ChangeTableRowHeightRequest', () {
    test('1. stores nodeId, rowIndex, and newHeight', () {
      final req = const ChangeTableRowHeightRequest(nodeId: 't1', rowIndex: 1, newHeight: 48.0);
      expect(req.nodeId, 't1');
      expect(req.rowIndex, 1);
      expect(req.newHeight, 48.0);
    });

    test('2. accepts null newHeight (auto-size)', () {
      final req = const ChangeTableRowHeightRequest(nodeId: 't1', rowIndex: 0, newHeight: null);
      expect(req.newHeight, isNull);
    });

    test('3. equality: same fields equal', () {
      final a = const ChangeTableRowHeightRequest(nodeId: 't1', rowIndex: 0, newHeight: 32.0);
      final b = const ChangeTableRowHeightRequest(nodeId: 't1', rowIndex: 0, newHeight: 32.0);
      expect(a, equals(b));
    });

    test('4. equality: different newHeight not equal', () {
      final a = const ChangeTableRowHeightRequest(nodeId: 't1', rowIndex: 0, newHeight: 32.0);
      final b = const ChangeTableRowHeightRequest(nodeId: 't1', rowIndex: 0, newHeight: 48.0);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: null vs non-null newHeight not equal', () {
      final a = const ChangeTableRowHeightRequest(nodeId: 't1', rowIndex: 0, newHeight: null);
      final b = const ChangeTableRowHeightRequest(nodeId: 't1', rowIndex: 0, newHeight: 32.0);
      expect(a, isNot(equals(b)));
    });

    test('6. hashCode is consistent with equality', () {
      final a = const ChangeTableRowHeightRequest(nodeId: 't1', rowIndex: 1, newHeight: 48.0);
      final b = const ChangeTableRowHeightRequest(nodeId: 't1', rowIndex: 1, newHeight: 48.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('7. toString includes class name and key fields', () {
      final req = const ChangeTableRowHeightRequest(nodeId: 't1', rowIndex: 1, newHeight: 48.0);
      expect(req.toString(), contains('ChangeTableRowHeightRequest'));
      expect(req.toString(), contains('t1'));
      expect(req.toString(), contains('48.0'));
    });
  });
}
