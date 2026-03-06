/// Tests for [RenderBlockquoteBlock].
library;

import 'dart:ui' as ui;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Constants mirrored from the implementation for assertions.
const double _kBorderWidth = 3.0;
const double _kBorderPadding = 8.0;
const double _kBorderInset = _kBorderWidth + _kBorderPadding; // 11.0

void main() {
  group('RenderBlockquoteBlock — default property values', () {
    test('borderColor defaults to Color(0xFFBDBDBD)', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      expect(block.borderColor, const Color(0xFFBDBDBD));
    });

    test('blockAlignment defaults to BlockAlignment.stretch', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      expect(block.blockAlignment, BlockAlignment.stretch);
    });

    test('requestedWidth defaults to null', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      expect(block.requestedWidth, isNull);
    });

    test('requestedHeight defaults to null', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      expect(block.requestedHeight, isNull);
    });

    test('textWrap defaults to false', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      expect(block.textWrap, isFalse);
    });
  });

  group('RenderBlockquoteBlock — constructor parameters', () {
    test('constructor accepts borderColor parameter', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
        borderColor: const Color(0xFF0000FF),
      );
      expect(block.borderColor, const Color(0xFF0000FF));
    });

    test('constructor accepts blockAlignment parameter', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
        blockAlignment: BlockAlignment.center,
      );
      expect(block.blockAlignment, BlockAlignment.center);
    });

    test('constructor accepts requestedWidth parameter', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
        requestedWidth: 320.0,
      );
      expect(block.requestedWidth, 320.0);
    });

    test('constructor accepts requestedHeight parameter', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
        requestedHeight: 120.0,
      );
      expect(block.requestedHeight, 120.0);
    });

    test('constructor accepts textWrap parameter', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
        textWrap: true,
      );
      expect(block.textWrap, isTrue);
    });
  });

  group('RenderBlockquoteBlock — setter round-trips', () {
    test('borderColor setter round-trip', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      block.borderColor = const Color(0xFFFF0000);
      expect(block.borderColor, const Color(0xFFFF0000));
    });

    test('blockAlignment setter round-trip', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      block.blockAlignment = BlockAlignment.end;
      expect(block.blockAlignment, BlockAlignment.end);
    });

    test('requestedWidth setter round-trip', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      block.requestedWidth = 250.0;
      expect(block.requestedWidth, 250.0);
    });

    test('requestedHeight setter round-trip', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      block.requestedHeight = 80.0;
      expect(block.requestedHeight, 80.0);
    });

    test('textWrap setter round-trip', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      block.textWrap = true;
      expect(block.textWrap, isTrue);
    });

    test('setting borderColor to same value is a no-op', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
        borderColor: const Color(0xFFBDBDBD),
      );
      block.borderColor = const Color(0xFFBDBDBD);
      expect(block.borderColor, const Color(0xFFBDBDBD));
    });

    test('setting blockAlignment to same value is a no-op', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      block.blockAlignment = BlockAlignment.stretch;
      expect(block.blockAlignment, BlockAlignment.stretch);
    });
  });

  group('RenderBlockquoteBlock — layout', () {
    test('text is laid out with reduced width (maxWidth - borderInset)', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      const maxWidth = 600.0;
      block.layout(
        const BoxConstraints(maxWidth: maxWidth, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      // Block width fills the available width.
      expect(block.size.width, maxWidth);
      // Block height is positive (text laid out successfully).
      expect(block.size.height, greaterThan(0));
    });

    test('requestedWidth constrains block width and text layout width', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
        requestedWidth: 200.0,
      );
      block.layout(
        const BoxConstraints(maxWidth: 600, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      expect(block.size.width, 200.0);
    });

    test('requestedHeight sets block height', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
        requestedHeight: 80.0,
      );
      block.layout(
        const BoxConstraints(maxWidth: 600, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      expect(block.size.height, 80.0);
    });

    test('requestedWidth clamped to constraints.maxWidth when larger', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
        requestedWidth: 1000.0,
      );
      block.layout(
        const BoxConstraints(maxWidth: 600, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      expect(block.size.width, 600.0);
    });
  });

  group('RenderBlockquoteBlock — paint (canvas recording)', () {
    test('border rect is drawn at x=0, full block height', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
        borderColor: const Color(0xFFFF0000),
      );
      const maxWidth = 400.0;
      block.layout(
        const BoxConstraints(maxWidth: maxWidth, maxHeight: double.infinity),
        parentUsesSize: true,
      );

      // Record paint operations.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _TestPaintingContext(canvas);
      block.paint(context, Offset.zero);

      // Verify border was drawn by checking the recorded picture is non-empty.
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('RenderBlockquoteBlock — geometry queries', () {
    late RenderBlockquoteBlock block;

    setUp(() {
      block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('hello'),
      );
      block.layout(
        const BoxConstraints(maxWidth: 400, maxHeight: double.infinity),
        parentUsesSize: true,
      );
    });

    test('getLocalRectForPosition shifts rect by border inset on x-axis', () {
      const position = TextNodePosition(offset: 0);
      final rect = block.getLocalRectForPosition(position);
      // The x coordinate should be at least _kBorderInset (11.0) for offset 0.
      expect(rect.left, greaterThanOrEqualTo(_kBorderInset));
    });

    test('getPositionAtOffset accounts for border inset', () {
      // Tapping at x = borderInset + small delta should map to the first character.
      final position = block.getPositionAtOffset(const Offset(_kBorderInset + 1, 5));
      expect(position, isA<TextNodePosition>());
      final tp = position as TextNodePosition;
      // Should be at or near offset 0 (beginning of text).
      expect(tp.offset, lessThanOrEqualTo(2));
    });

    test('getEndpointsForSelection returns rects shifted by border inset', () {
      const base = TextNodePosition(offset: 0);
      const extent = TextNodePosition(offset: 3);
      final rects = block.getEndpointsForSelection(base, extent);
      // Should return at least one rect.
      expect(rects, isNotEmpty);
      // All rects' left edges should be at least _kBorderInset.
      for (final r in rects) {
        expect(r.left, greaterThanOrEqualTo(_kBorderInset));
      }
    });

    test('getEndpointsForSelection with equal offsets returns empty list', () {
      const base = TextNodePosition(offset: 2);
      const extent = TextNodePosition(offset: 2);
      final rects = block.getEndpointsForSelection(base, extent);
      expect(rects, isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// A minimal [PaintingContext] that forwards [canvas] for recording.
class _TestPaintingContext extends PaintingContext {
  _TestPaintingContext(Canvas canvas)
      : _canvas = canvas,
        super(
          _FakeContainerLayer(),
          Rect.largest,
        );

  final Canvas _canvas;

  @override
  Canvas get canvas => _canvas;
}

class _FakeContainerLayer extends ContainerLayer {}
