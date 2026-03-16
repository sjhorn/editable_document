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
      const req = ExitBlockquoteRequest(
        nodeId: 'bq1',
        splitOffset: 5,
        removeTrailingNewline: true,
      );
      expect(req.nodeId, 'bq1');
      expect(req.splitOffset, 5);
      expect(req.removeTrailingNewline, isTrue);
    });

    test('2. removeTrailingNewline defaults to false', () {
      const req = ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 3);
      expect(req.removeTrailingNewline, isFalse);
    });

    test('3. equality: same fields are equal', () {
      const a = ExitBlockquoteRequest(
        nodeId: 'bq1',
        splitOffset: 5,
        removeTrailingNewline: true,
      );
      const b = ExitBlockquoteRequest(
        nodeId: 'bq1',
        splitOffset: 5,
        removeTrailingNewline: true,
      );
      expect(a, equals(b));
    });

    test('4. equality: different splitOffset not equal', () {
      const a = ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 5);
      const b = ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 6);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different removeTrailingNewline not equal', () {
      const a = ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 5, removeTrailingNewline: true);
      const b = ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 5, removeTrailingNewline: false);
      expect(a, isNot(equals(b)));
    });

    test('6. hashCode is consistent with equality', () {
      const a = ExitBlockquoteRequest(
        nodeId: 'bq1',
        splitOffset: 5,
        removeTrailingNewline: true,
      );
      const b = ExitBlockquoteRequest(
        nodeId: 'bq1',
        splitOffset: 5,
        removeTrailingNewline: true,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('7. toString includes class name and key fields', () {
      const req = ExitBlockquoteRequest(nodeId: 'bq1', splitOffset: 3);
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
      const req = ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.center);
      expect(req.nodeId, 'p1');
      expect(req.newTextAlign, TextAlign.center);
    });

    test('2. equality: same fields are equal', () {
      const a = ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.center);
      const b = ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.center);
      expect(a, equals(b));
    });

    test('3. equality: different nodeId not equal', () {
      const a = ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.center);
      const b = ChangeTextAlignRequest(nodeId: 'p2', newTextAlign: TextAlign.center);
      expect(a, isNot(equals(b)));
    });

    test('4. equality: different newTextAlign not equal', () {
      const a = ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.start);
      const b = ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.center);
      expect(a, isNot(equals(b)));
    });

    test('5. hashCode is consistent with equality', () {
      const a = ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.end);
      const b = ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.end);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('6. toString includes class name and key fields', () {
      const req = ChangeTextAlignRequest(nodeId: 'p1', newTextAlign: TextAlign.justify);
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
      const req = ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
      expect(req.nodeId, 'p1');
      expect(req.newLineHeight, 1.5);
    });

    test('2. stores null newLineHeight', () {
      const req = ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: null);
      expect(req.nodeId, 'p1');
      expect(req.newLineHeight, isNull);
    });

    test('3. equality: same fields are equal', () {
      const a = ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
      const b = ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
      expect(a, equals(b));
    });

    test('4. equality: different nodeId not equal', () {
      const a = ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
      const b = ChangeLineHeightRequest(nodeId: 'p2', newLineHeight: 1.5);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different newLineHeight not equal', () {
      const a = ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.0);
      const b = ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
      expect(a, isNot(equals(b)));
    });

    test('6. hashCode is consistent with equality', () {
      const a = ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 2.0);
      const b = ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 2.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('7. toString includes class name and key fields', () {
      const req = ChangeLineHeightRequest(nodeId: 'p1', newLineHeight: 1.5);
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
      const req = ChangeIndentRequest(
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
      const req = ChangeIndentRequest(nodeId: 'p1');
      expect(req.newIndentLeft, isNull);
      expect(req.newIndentRight, isNull);
      expect(req.newFirstLineIndent, isNull);
    });

    test('3. equality: same fields are equal', () {
      const a = ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0, newIndentRight: 8.0);
      const b = ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0, newIndentRight: 8.0);
      expect(a, equals(b));
    });

    test('4. equality: different nodeId not equal', () {
      const a = ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0);
      const b = ChangeIndentRequest(nodeId: 'p2', newIndentLeft: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different newIndentLeft not equal', () {
      const a = ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 8.0);
      const b = ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('6. equality: different newIndentRight not equal', () {
      const a = ChangeIndentRequest(nodeId: 'p1', newIndentRight: 4.0);
      const b = ChangeIndentRequest(nodeId: 'p1', newIndentRight: 8.0);
      expect(a, isNot(equals(b)));
    });

    test('7. equality: different newFirstLineIndent not equal', () {
      const a = ChangeIndentRequest(nodeId: 'p1', newFirstLineIndent: 16.0);
      const b = ChangeIndentRequest(nodeId: 'p1', newFirstLineIndent: 24.0);
      expect(a, isNot(equals(b)));
    });

    test('8. hashCode is consistent with equality', () {
      const a = ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0, newIndentRight: 8.0);
      const b = ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0, newIndentRight: 8.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('9. toString includes class name and key fields', () {
      const req = ChangeIndentRequest(nodeId: 'p1', newIndentLeft: 16.0, newIndentRight: 8.0);
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
      const req = ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
      expect(req.nodeId, 'p1');
      expect(req.newSpaceBefore, 8.0);
      expect(req.newSpaceAfter, 16.0);
    });

    test('2. accepts null spacing values', () {
      const req = ChangeSpacingRequest(nodeId: 'p1');
      expect(req.newSpaceBefore, isNull);
      expect(req.newSpaceAfter, isNull);
    });

    test('3. equality: same fields are equal', () {
      const a = ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
      const b = ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
      expect(a, equals(b));
    });

    test('4. equality: different nodeId not equal', () {
      const a = ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0);
      const b = ChangeSpacingRequest(nodeId: 'p2', newSpaceBefore: 8.0);
      expect(a, isNot(equals(b)));
    });

    test('5. equality: different newSpaceBefore not equal', () {
      const a = ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 4.0);
      const b = ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0);
      expect(a, isNot(equals(b)));
    });

    test('6. equality: different newSpaceAfter not equal', () {
      const a = ChangeSpacingRequest(nodeId: 'p1', newSpaceAfter: 4.0);
      const b = ChangeSpacingRequest(nodeId: 'p1', newSpaceAfter: 8.0);
      expect(a, isNot(equals(b)));
    });

    test('7. hashCode is consistent with equality', () {
      const a = ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
      const b = ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('8. toString includes class name and key fields', () {
      const req = ChangeSpacingRequest(nodeId: 'p1', newSpaceBefore: 8.0, newSpaceAfter: 16.0);
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
}
