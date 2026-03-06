/// Tests for [RenderHorizontalRuleBlock].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RenderHorizontalRuleBlock layout', () {
    test('fills available width', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);
      expect(block.size.width, 500.0);
    });

    test('height equals thickness + 2 * verticalPadding', () {
      const thickness = 2.0;
      const verticalPadding = 8.0;
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        thickness: thickness,
        verticalPadding: verticalPadding,
      );
      block.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);
      expect(block.size.height, closeTo(thickness + 2 * verticalPadding, 0.01));
    });

    test('default thickness and verticalPadding produce positive height', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);
      expect(block.size.height, greaterThan(0));
    });

    test('custom thickness changes layout height', () {
      final thin = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        thickness: 1.0,
        verticalPadding: 8.0,
      );
      thin.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);

      final thick = RenderHorizontalRuleBlock(
        nodeId: 'hr-2',
        thickness: 4.0,
        verticalPadding: 8.0,
      );
      thick.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);

      expect(thick.size.height, greaterThan(thin.size.height));
    });
  });

  group('RenderHorizontalRuleBlock hit testing', () {
    late RenderHorizontalRuleBlock block;

    setUp(() {
      block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
    });

    test('tap on left half returns upstream', () {
      final pos = block.getPositionAtOffset(const Offset(50, 5));
      expect(pos, isA<BinaryNodePosition>());
      expect((pos as BinaryNodePosition).type, BinaryNodePositionType.upstream);
    });

    test('tap on right half returns downstream', () {
      final pos = block.getPositionAtOffset(Offset(block.size.width - 50, 5));
      expect(pos, isA<BinaryNodePosition>());
      expect((pos as BinaryNodePosition).type, BinaryNodePositionType.downstream);
    });
  });

  group('RenderHorizontalRuleBlock position queries', () {
    late RenderHorizontalRuleBlock block;

    setUp(() {
      block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
    });

    test('getLocalRectForPosition upstream covers block', () {
      final rect = block.getLocalRectForPosition(const BinaryNodePosition.upstream());
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
    });

    test('getLocalRectForPosition downstream covers block', () {
      final rect = block.getLocalRectForPosition(const BinaryNodePosition.downstream());
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
    });

    test('getEndpointsForSelection returns one rect for the full block', () {
      final rects = block.getEndpointsForSelection(
        const BinaryNodePosition.upstream(),
        const BinaryNodePosition.downstream(),
      );
      expect(rects, hasLength(1));
      expect(rects.first, equals(Offset.zero & block.size));
    });
  });

  group('RenderHorizontalRuleBlock properties', () {
    test('nodeId is readable and writable', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.nodeId, 'hr-1');
      block.nodeId = 'hr-2';
      expect(block.nodeId, 'hr-2');
    });

    test('color can be set', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        color: const Color(0xFF888888),
      );
      expect(block.color, const Color(0xFF888888));
    });

    test('setting thickness triggers layout', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        thickness: 1.0,
        verticalPadding: 8.0,
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      final before = block.size.height;

      block.thickness = 6.0;
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.size.height, greaterThan(before));
    });
  });

  group('RenderHorizontalRuleBlock layout property defaults and setter', () {
    test('blockAlignment defaults to BlockAlignment.stretch', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.blockAlignment, BlockAlignment.stretch);
    });

    test('requestedWidth defaults to null (base class default)', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.requestedWidth, isNull);
    });

    test('requestedHeight defaults to null (base class default)', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.requestedHeight, isNull);
    });

    test('textWrap defaults to false (base class default)', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.textWrap, isFalse);
    });

    test('blockAlignment setter roundtrip', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.blockAlignment = BlockAlignment.center;
      expect(block.blockAlignment, BlockAlignment.center);
    });

    test('setting blockAlignment to same value is a no-op', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.blockAlignment = BlockAlignment.stretch;
      expect(block.blockAlignment, BlockAlignment.stretch);
    });

    test('constructor accepts blockAlignment parameter', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        blockAlignment: BlockAlignment.end,
      );
      expect(block.blockAlignment, BlockAlignment.end);
    });

    test('setting blockAlignment triggers layout', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      // Change to a different value — should not throw.
      block.blockAlignment = BlockAlignment.center;
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.blockAlignment, BlockAlignment.center);
    });
  });
}
