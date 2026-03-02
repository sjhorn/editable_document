/// Tests for [RenderImageBlock].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RenderImageBlock layout', () {
    test('fills available width by default', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.size.width, 400.0);
    });

    test('height is positive when no explicit dimensions given', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.size.height, greaterThan(0));
    });

    test('respects explicit width and height', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        imageWidth: 200,
        imageHeight: 100,
      );
      block.layout(
        const BoxConstraints(maxWidth: 400, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      // Width is clamped to constraints, height preserves aspect ratio or uses given value.
      expect(block.size.width, 200.0);
      expect(block.size.height, 100.0);
    });

    test('scales to fit when explicit width exceeds constraints', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        imageWidth: 800,
        imageHeight: 400,
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.size.width, 400.0);
      // Aspect ratio should be maintained: 400 * (400/800) = 200.
      expect(block.size.height, closeTo(200.0, 1.0));
    });
  });

  group('RenderImageBlock hit testing', () {
    late RenderImageBlock block;

    setUp(() {
      block = RenderImageBlock(nodeId: 'img-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
    });

    test('tap on left half returns upstream BinaryNodePosition', () {
      final pos = block.getPositionAtOffset(const Offset(50, 10));
      expect(pos, isA<BinaryNodePosition>());
      expect((pos as BinaryNodePosition).type, BinaryNodePositionType.upstream);
    });

    test('tap on right half returns downstream BinaryNodePosition', () {
      final pos = block.getPositionAtOffset(Offset(block.size.width - 50, 10));
      expect(pos, isA<BinaryNodePosition>());
      expect((pos as BinaryNodePosition).type, BinaryNodePositionType.downstream);
    });

    test('tap exactly at center returns upstream or downstream', () {
      final pos = block.getPositionAtOffset(Offset(block.size.width / 2, 10));
      expect(pos, isA<BinaryNodePosition>());
    });
  });

  group('RenderImageBlock position queries', () {
    late RenderImageBlock block;

    setUp(() {
      block = RenderImageBlock(nodeId: 'img-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
    });

    test('getLocalRectForPosition upstream returns left-edge full-height rect', () {
      final rect = block.getLocalRectForPosition(const BinaryNodePosition.upstream());
      expect(rect.left, 0.0);
      expect(rect.top, 0.0);
      expect(rect.height, block.size.height);
    });

    test('getLocalRectForPosition downstream returns right-edge full-height rect', () {
      final rect = block.getLocalRectForPosition(const BinaryNodePosition.downstream());
      // Inset by 2px from the right edge so the caret stays in bounds.
      expect(rect.left, block.size.width - 2.0);
      expect(rect.top, 0.0);
      expect(rect.height, block.size.height);
    });

    test('getEndpointsForSelection returns full block rect', () {
      final rects = block.getEndpointsForSelection(
        const BinaryNodePosition.upstream(),
        const BinaryNodePosition.downstream(),
      );
      expect(rects, hasLength(1));
      expect(rects.first.width, block.size.width);
    });
  });

  group('RenderImageBlock properties', () {
    test('nodeId is readable and writable', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      expect(block.nodeId, 'img-1');
      block.nodeId = 'img-2';
      expect(block.nodeId, 'img-2');
    });

    test('placeholderColor can be set', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        placeholderColor: const Color(0xFFCCCCCC),
      );
      expect(block.placeholderColor, const Color(0xFFCCCCCC));
    });
  });
}
