/// Tests for [RenderImageBlock].
library;

import 'dart:ui' as ui;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helper: create a tiny solid-color ui.Image for use in unit tests.
// ---------------------------------------------------------------------------

Future<ui.Image> _createTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFFFF0000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

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

    test('layout uses image intrinsic size when no explicit dimensions', () async {
      final img = await _createTestImage(320, 180);
      addTearDown(img.dispose);

      final block = RenderImageBlock(nodeId: 'img-1', image: img);
      block.layout(
        const BoxConstraints(maxWidth: 800, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      // Image fits within 800px max-width, so exact image dimensions are used.
      expect(block.size.width, 320.0);
      expect(block.size.height, 180.0);
    });

    test('explicit dimensions override image intrinsic size', () async {
      final img = await _createTestImage(320, 180);
      addTearDown(img.dispose);

      final block = RenderImageBlock(
        nodeId: 'img-1',
        image: img,
        imageWidth: 200,
        imageHeight: 100,
      );
      block.layout(
        const BoxConstraints(maxWidth: 800, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      // Explicit dimensions take priority over the image's intrinsic size.
      expect(block.size.width, 200.0);
      expect(block.size.height, 100.0);
    });

    test('image scales down when wider than constraints', () async {
      final img = await _createTestImage(800, 400);
      addTearDown(img.dispose);

      final block = RenderImageBlock(nodeId: 'img-1', image: img);
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      // Image (800×400) scaled to fit 400px max-width → 400×200.
      expect(block.size.width, 400.0);
      expect(block.size.height, closeTo(200.0, 1.0));
    });

    test('placeholder is used when image is null', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      // Without image or explicit dimensions, falls back to 16:9 placeholder.
      expect(block.size.width, 400.0);
      expect(block.size.height, closeTo(400.0 * 9.0 / 16.0, 1.0));
    });

    test('only requestedWidth + image loaded → height uses image aspect ratio', () async {
      // Image is 300×200, aspect ratio height/width = 200/300 ≈ 0.6667.
      final img = await _createTestImage(300, 200);
      addTearDown(img.dispose);

      final block = RenderImageBlock(
        nodeId: 'img-1',
        image: img,
        requestedWidth: 150,
      );
      block.layout(
        const BoxConstraints(maxWidth: 600, maxHeight: double.infinity),
        parentUsesSize: true,
      );

      expect(block.size.width, 150.0);
      // Expected height: 150 * (200 / 300) = 100.
      expect(block.size.height, closeTo(100.0, 0.1));
    });

    test('only requestedHeight + image loaded → width uses image aspect ratio', () async {
      // Image is 400×200, aspect ratio width/height = 400/200 = 2.0.
      final img = await _createTestImage(400, 200);
      addTearDown(img.dispose);

      final block = RenderImageBlock(
        nodeId: 'img-1',
        image: img,
        requestedHeight: 100,
      );
      block.layout(
        const BoxConstraints(maxWidth: 800, maxHeight: double.infinity),
        parentUsesSize: true,
      );

      // Expected width: 100 * (400 / 200) = 200, well within 800px constraint.
      expect(block.size.width, closeTo(200.0, 0.1));
      expect(block.size.height, 100.0);
    });

    test('only imageWidth + image loaded → height uses image aspect ratio', () async {
      // Image is 300×200. Setting imageWidth=150, height should be 100.
      final img = await _createTestImage(300, 200);
      addTearDown(img.dispose);

      final block = RenderImageBlock(
        nodeId: 'img-1',
        image: img,
        imageWidth: 150,
      );
      block.layout(
        const BoxConstraints(maxWidth: 600, maxHeight: double.infinity),
        parentUsesSize: true,
      );

      expect(block.size.width, 150.0);
      expect(block.size.height, closeTo(100.0, 0.1));
    });

    test('only imageHeight + image loaded → width uses image aspect ratio', () async {
      // Image is 400×200. Setting imageHeight=100, width should be 200.
      final img = await _createTestImage(400, 200);
      addTearDown(img.dispose);

      final block = RenderImageBlock(
        nodeId: 'img-1',
        image: img,
        imageHeight: 100,
      );
      block.layout(
        const BoxConstraints(maxWidth: 800, maxHeight: double.infinity),
        parentUsesSize: true,
      );

      expect(block.size.width, closeTo(200.0, 0.1));
      expect(block.size.height, 100.0);
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

    test('image getter returns null by default', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      expect(block.image, isNull);
    });

    test('image getter/setter roundtrip', () async {
      final img = await _createTestImage(100, 50);
      addTearDown(img.dispose);

      final block = RenderImageBlock(nodeId: 'img-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      block.image = img;
      expect(block.image, same(img));
    });

    test('setting image to same value is a no-op', () async {
      final img = await _createTestImage(100, 50);
      addTearDown(img.dispose);

      final block = RenderImageBlock(nodeId: 'img-1', image: img);
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      // Assign same instance — should not throw or trigger any extra work.
      block.image = img;
      expect(block.image, same(img));
    });

    test('setting image to null clears it', () async {
      final img = await _createTestImage(100, 50);
      addTearDown(img.dispose);

      final block = RenderImageBlock(nodeId: 'img-1', image: img);
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      block.image = null;
      expect(block.image, isNull);
    });

    test('image constructor parameter is stored', () async {
      final img = await _createTestImage(200, 100);
      addTearDown(img.dispose);

      final block = RenderImageBlock(nodeId: 'img-1', image: img);
      expect(block.image, same(img));
    });
  });

  group('RenderImageBlock intrinsicContentSize', () {
    test('returns null when no image is loaded', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      expect(block.intrinsicContentSize, isNull);
    });

    test('returns the decoded image pixel dimensions when image is set', () async {
      final img = await _createTestImage(320, 180);
      addTearDown(img.dispose);

      final block = RenderImageBlock(nodeId: 'img-1', image: img);
      final size = block.intrinsicContentSize;
      expect(size, isNotNull);
      expect(size!.width, 320.0);
      expect(size.height, 180.0);
    });

    test('returns null after image is cleared', () async {
      final img = await _createTestImage(100, 50);
      addTearDown(img.dispose);

      final block = RenderImageBlock(nodeId: 'img-1', image: img);
      expect(block.intrinsicContentSize, isNotNull);

      block.image = null;
      expect(block.intrinsicContentSize, isNull);
    });

    test('reflects new dimensions after image is replaced', () async {
      final img1 = await _createTestImage(100, 50);
      final img2 = await _createTestImage(640, 480);
      addTearDown(img1.dispose);
      addTearDown(img2.dispose);

      final block = RenderImageBlock(nodeId: 'img-1', image: img1);
      expect(block.intrinsicContentSize, equals(const Size(100, 50)));

      block.image = img2;
      expect(block.intrinsicContentSize, equals(const Size(640, 480)));
    });
  });

  group('RenderImageBlock layout property defaults and setters', () {
    test('blockAlignment defaults to BlockAlignment.stretch', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      expect(block.blockAlignment, BlockAlignment.stretch);
    });

    test('requestedWidth defaults to null', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      expect(block.requestedWidth, isNull);
    });

    test('requestedHeight defaults to null', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      expect(block.requestedHeight, isNull);
    });

    test('textWrap defaults to TextWrapMode.none', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      expect(block.textWrap, TextWrapMode.none);
    });

    test('blockAlignment setter roundtrip', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      block.blockAlignment = BlockAlignment.center;
      expect(block.blockAlignment, BlockAlignment.center);
    });

    test('requestedWidth setter roundtrip', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      block.requestedWidth = 200.0;
      expect(block.requestedWidth, 200.0);
    });

    test('requestedHeight setter roundtrip', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      block.requestedHeight = 150.0;
      expect(block.requestedHeight, 150.0);
    });

    test('textWrap setter roundtrip', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      block.textWrap = TextWrapMode.wrap;
      expect(block.textWrap, TextWrapMode.wrap);
    });

    test('setting blockAlignment to same value is a no-op', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      block.blockAlignment = BlockAlignment.stretch;
      // Should not throw.
      expect(block.blockAlignment, BlockAlignment.stretch);
    });

    test('requestedWidth overrides layout width', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        imageWidth: 400,
        imageHeight: 200,
        requestedWidth: 100,
      );
      block.layout(
        const BoxConstraints(maxWidth: 600, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      expect(block.size.width, 100.0);
    });

    test('requestedHeight overrides layout height', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        imageWidth: 200,
        imageHeight: 100,
        requestedHeight: 50,
      );
      block.layout(
        const BoxConstraints(maxWidth: 600, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      expect(block.size.height, 50.0);
    });

    test('constructor accepts blockAlignment parameter', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        blockAlignment: BlockAlignment.center,
      );
      expect(block.blockAlignment, BlockAlignment.center);
    });

    test('constructor accepts requestedWidth parameter', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        requestedWidth: 300.0,
      );
      expect(block.requestedWidth, 300.0);
    });

    test('constructor accepts requestedHeight parameter', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        requestedHeight: 150.0,
      );
      expect(block.requestedHeight, 150.0);
    });

    test('constructor accepts textWrap parameter', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        textWrap: TextWrapMode.wrap,
      );
      expect(block.textWrap, TextWrapMode.wrap);
    });
  });

  group('RenderImageBlock border property', () {
    test('border is null by default', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      expect(block.border, isNull);
    });

    test('border returns value set via setter', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      const border = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      block.border = border;
      expect(block.border, equals(border));
    });

    test('setting border to same value is a no-op', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      const border = BlockBorder(style: BlockBorderStyle.dashed, width: 1.0);
      block.border = border;
      block.border = border;
      expect(block.border, equals(border));
    });

    test('setting border to null clears the value', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      block.border = const BlockBorder();
      block.border = null;
      expect(block.border, isNull);
    });
  });
}
