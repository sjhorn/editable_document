/// Tests for [RenderDocumentBlock] — the abstract base for all block types.
///
/// Because [RenderDocumentBlock] is abstract, these tests use
/// [RenderHorizontalRuleBlock] as a minimal concrete stand-in to verify the
/// contract exposed by the base class.
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RenderDocumentBlock contract', () {
    late RenderHorizontalRuleBlock block;

    setUp(() {
      block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
    });

    test('nodeId is readable and writable', () {
      expect(block.nodeId, 'hr-1');
      block.nodeId = 'hr-2';
      expect(block.nodeId, 'hr-2');
    });

    test('nodeSelection defaults to null', () {
      expect(block.nodeSelection, isNull);
    });

    test('nodeSelection can be set and cleared', () {
      const sel = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'hr-1',
          nodePosition: BinaryNodePosition.upstream(),
        ),
      );
      block.nodeSelection = sel;
      expect(block.nodeSelection, equals(sel));

      block.nodeSelection = null;
      expect(block.nodeSelection, isNull);
    });

    test('is a RenderBox', () {
      expect(block, isA<RenderBox>());
    });

    test('getLocalRectForPosition returns a Rect', () {
      block.layout(const BoxConstraints(maxWidth: 300), parentUsesSize: true);
      final rect = block.getLocalRectForPosition(const BinaryNodePosition.upstream());
      expect(rect, isA<Rect>());
    });

    test('getPositionAtOffset returns a NodePosition', () {
      block.layout(const BoxConstraints(maxWidth: 300), parentUsesSize: true);
      final pos = block.getPositionAtOffset(const Offset(10, 10));
      expect(pos, isA<NodePosition>());
    });

    test('getEndpointsForSelection returns a list of Rects', () {
      block.layout(const BoxConstraints(maxWidth: 300), parentUsesSize: true);
      final rects = block.getEndpointsForSelection(
        const BinaryNodePosition.upstream(),
        const BinaryNodePosition.downstream(),
      );
      expect(rects, isA<List<Rect>>());
      expect(rects, isNotEmpty);
    });
  });
}
