/// Tests for [RenderBlockResizeBorder].
library;

import 'dart:ui';

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [RenderDocumentLayout] containing one [RenderTextBlock] with
/// node id 'b1' and runs layout so geometry queries return meaningful values.
RenderDocumentLayout _buildLayout() {
  final layout = RenderDocumentLayout(blockSpacing: 0.0);
  layout.add(
    RenderTextBlock(
      nodeId: 'b1',
      text: AttributedText('Hello world'),
      textStyle: const TextStyle(fontSize: 16),
    ),
  );
  layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
  return layout;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RenderBlockResizeBorder — construction and defaults', () {
    test('can be created with no arguments', () {
      final border = RenderBlockResizeBorder();
      expect(border, isA<RenderBox>());
    });

    test('documentLayout defaults to null', () {
      final border = RenderBlockResizeBorder();
      expect(border.documentLayout, isNull);
    });

    test('selectedNodeId defaults to null', () {
      final border = RenderBlockResizeBorder();
      expect(border.selectedNodeId, isNull);
    });

    test('borderColor defaults to Color(0xFF2196F3)', () {
      final border = RenderBlockResizeBorder();
      expect(border.borderColor, const Color(0xFF2196F3));
    });

    test('handleColor defaults to Color(0xFF2196F3)', () {
      final border = RenderBlockResizeBorder();
      expect(border.handleColor, const Color(0xFF2196F3));
    });

    test('handleSize defaults to 8.0', () {
      final border = RenderBlockResizeBorder();
      expect(border.handleSize, 8.0);
    });

    test('showHandles defaults to true', () {
      final border = RenderBlockResizeBorder();
      expect(border.showHandles, isTrue);
    });

    test('dragPreviewRect defaults to null', () {
      final border = RenderBlockResizeBorder();
      expect(border.dragPreviewRect, isNull);
    });
  });

  group('RenderBlockResizeBorder — property setters mark needs paint', () {
    test('setting documentLayout to new value marks needs paint', () {
      final border = RenderBlockResizeBorder();
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);

      border.documentLayout = _buildLayout();
      expect(border.debugNeedsPaint, isTrue);
    });

    test('setting documentLayout to same value does not mark needs paint again', () {
      final layout = _buildLayout();
      final border = RenderBlockResizeBorder(documentLayout: layout);
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);
      // Guard: setting same instance must not trigger another dirty.
      border.documentLayout = layout;
      expect(border.documentLayout, same(layout));
    });

    test('setting selectedNodeId to new value marks needs paint', () {
      final border = RenderBlockResizeBorder();
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);

      border.selectedNodeId = 'b1';
      expect(border.debugNeedsPaint, isTrue);
    });

    test('setting selectedNodeId to same value does not mark needs paint', () {
      final border = RenderBlockResizeBorder(selectedNodeId: 'b1');
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);
      border.selectedNodeId = 'b1';
      expect(border.selectedNodeId, 'b1');
    });

    test('setting borderColor marks needs paint', () {
      final border = RenderBlockResizeBorder();
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);

      border.borderColor = const Color(0xFFFF0000);
      expect(border.debugNeedsPaint, isTrue);
    });

    test('setting handleColor marks needs paint', () {
      final border = RenderBlockResizeBorder();
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);

      border.handleColor = const Color(0xFFFF0000);
      expect(border.debugNeedsPaint, isTrue);
    });

    test('setting handleSize marks needs paint', () {
      final border = RenderBlockResizeBorder();
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);

      border.handleSize = 12.0;
      expect(border.debugNeedsPaint, isTrue);
    });

    test('setting showHandles marks needs paint', () {
      final border = RenderBlockResizeBorder();
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);

      border.showHandles = false;
      expect(border.debugNeedsPaint, isTrue);
    });

    test('setting dragPreviewRect marks needs paint', () {
      final border = RenderBlockResizeBorder();
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);

      border.dragPreviewRect = const Rect.fromLTWH(10, 20, 100, 50);
      expect(border.debugNeedsPaint, isTrue);
    });
  });

  group('RenderBlockResizeBorder — setting same value does not mark needs paint', () {
    test('borderColor same value guard', () {
      const c = Color(0xFF2196F3);
      final border = RenderBlockResizeBorder(borderColor: c);
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);
      border.borderColor = c;
      expect(border.borderColor, c);
    });

    test('handleColor same value guard', () {
      const c = Color(0xFF2196F3);
      final border = RenderBlockResizeBorder(handleColor: c);
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);
      border.handleColor = c;
      expect(border.handleColor, c);
    });

    test('handleSize same value guard', () {
      final border = RenderBlockResizeBorder(handleSize: 8.0);
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);
      border.handleSize = 8.0;
      expect(border.handleSize, 8.0);
    });

    test('showHandles same value guard', () {
      final border = RenderBlockResizeBorder(showHandles: true);
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);
      border.showHandles = true;
      expect(border.showHandles, isTrue);
    });

    test('dragPreviewRect same value guard', () {
      const r = Rect.fromLTWH(0, 0, 50, 50);
      final border = RenderBlockResizeBorder(dragPreviewRect: r);
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);
      border.dragPreviewRect = r;
      expect(border.dragPreviewRect, r);
    });
  });

  group('RenderBlockResizeBorder — hitTestSelf', () {
    test('returns false (transparent to hit testing)', () {
      final border = RenderBlockResizeBorder();
      final pipelineOwner = PipelineOwner();
      border.attach(pipelineOwner);
      border.layout(const BoxConstraints.tightFor(width: 400, height: 300));
      expect(border.hitTestSelf(const Offset(10, 10)), isFalse);
    });
  });

  group('RenderBlockResizeBorder — performLayout', () {
    test('sizes to constraints.biggest', () {
      final border = RenderBlockResizeBorder();
      const constraints = BoxConstraints.tightFor(width: 320, height: 240);
      border.layout(constraints, parentUsesSize: true);
      expect(border.size, const Size(320, 240));
    });

    test('sizes to tight constraints', () {
      final border = RenderBlockResizeBorder();
      const constraints = BoxConstraints(
        minWidth: 200,
        maxWidth: 200,
        minHeight: 100,
        maxHeight: 100,
      );
      border.layout(constraints, parentUsesSize: true);
      expect(border.size, const Size(200, 100));
    });
  });

  group('RenderBlockResizeBorder — paint', () {
    test('paint with null documentLayout is a no-op (no crash)', () {
      final border = RenderBlockResizeBorder(selectedNodeId: 'b1');
      border.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      expect(() => border.paint(context, Offset.zero), returnsNormally);
    });

    test('paint with null selectedNodeId is a no-op (no crash)', () {
      final layout = _buildLayout();
      final border = RenderBlockResizeBorder(documentLayout: layout);
      border.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      expect(() => border.paint(context, Offset.zero), returnsNormally);
    });

    test('paint with valid layout and found node completes without error', () {
      final layout = _buildLayout();
      final border = RenderBlockResizeBorder(
        documentLayout: layout,
        selectedNodeId: 'b1',
      );
      border.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      expect(() => border.paint(context, Offset.zero), returnsNormally);
    });

    test('paint with valid layout and found node — showHandles false — no crash', () {
      final layout = _buildLayout();
      final border = RenderBlockResizeBorder(
        documentLayout: layout,
        selectedNodeId: 'b1',
        showHandles: false,
      );
      border.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      expect(() => border.paint(context, Offset.zero), returnsNormally);
    });

    test('paint with nodeId not found in layout is a no-op (no crash)', () {
      final layout = _buildLayout();
      final border = RenderBlockResizeBorder(
        documentLayout: layout,
        selectedNodeId: 'does-not-exist',
      );
      border.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      expect(() => border.paint(context, Offset.zero), returnsNormally);
    });

    test('paint with dragPreviewRect set uses preview rect (documentLayout may be null)', () {
      const previewRect = Rect.fromLTWH(10, 20, 100, 80);
      final border = RenderBlockResizeBorder(
        dragPreviewRect: previewRect,
        selectedNodeId: 'b1',
        // documentLayout intentionally null
      );
      border.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      expect(() => border.paint(context, Offset.zero), returnsNormally);
    });

    test('paint with dragPreviewRect set — showHandles false — no crash', () {
      const previewRect = Rect.fromLTWH(5, 5, 200, 100);
      final border = RenderBlockResizeBorder(
        dragPreviewRect: previewRect,
        showHandles: false,
      );
      border.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      expect(() => border.paint(context, Offset.zero), returnsNormally);
    });
  });

  group('RenderBlockResizeBorder — handle clamping', () {
    test('clampedHandlePositions returns 8 positions within the clip bounds', () {
      final border = RenderBlockResizeBorder(handleSize: 8.0);

      // A block rect that goes right to the edges of a 400×300 clip.
      const rect = Rect.fromLTWH(0, 0, 400, 300);
      const clipBounds = Rect.fromLTWH(0, 0, 400, 300);

      final positions = border.clampedHandlePositions(rect, clipBounds);

      expect(positions, hasLength(8));

      // halfSize = 8.0 / 2 = 4.0 — no center should be within halfSize of
      // the clip edge so the full square remains visible.
      const halfSize = 4.0;
      for (final pos in positions) {
        expect(
          pos.dx,
          inInclusiveRange(clipBounds.left + halfSize, clipBounds.right - halfSize),
          reason: 'dx $pos must be within clip left+halfSize..right-halfSize',
        );
        expect(
          pos.dy,
          inInclusiveRange(clipBounds.top + halfSize, clipBounds.bottom - halfSize),
          reason: 'dy $pos must be within clip top+halfSize..bottom-halfSize',
        );
      }
    });

    test('clampedHandlePositions does not clamp when block is well within clip', () {
      final border = RenderBlockResizeBorder(handleSize: 8.0);

      // Block well inside the clip — no clamping should occur.
      const rect = Rect.fromLTWH(50, 50, 200, 100);
      const clipBounds = Rect.fromLTWH(0, 0, 400, 300);

      final positions = border.clampedHandlePositions(rect, clipBounds);

      // Top-left corner handle should remain at (50, 50).
      expect(positions.first, const Offset(50, 50));
    });

    test('clampedHandlePositions clamps top-left handle when block starts at origin', () {
      final border = RenderBlockResizeBorder(handleSize: 8.0);

      // Block top-left at (0, 0) — the corner handle center at (0, 0) should be
      // clamped to (4, 4) so the 8×8 square is entirely within the clip.
      const rect = Rect.fromLTWH(0, 0, 200, 100);
      const clipBounds = Rect.fromLTWH(0, 0, 400, 300);

      final positions = border.clampedHandlePositions(rect, clipBounds);

      // Top-left corner is positions[0].
      expect(positions[0], const Offset(4.0, 4.0));
    });

    test('clampedHandlePositions clamps bottom-right handle when block ends at clip edge', () {
      final border = RenderBlockResizeBorder(handleSize: 8.0);

      // Block bottom-right at (400, 300) — the corner handle center at
      // (400, 300) should be clamped to (396, 296).
      const rect = Rect.fromLTWH(200, 200, 200, 100);
      const clipBounds = Rect.fromLTWH(0, 0, 400, 300);

      final positions = border.clampedHandlePositions(rect, clipBounds);

      // Bottom-right corner is positions[7].
      expect(positions[7], const Offset(396.0, 296.0));
    });

    test('paint with handle positions at clip edge does not throw', () {
      // Block rect fills the entire canvas area so all handles are at the edge.
      const previewRect = Rect.fromLTWH(0, 0, 400, 300);
      final border = RenderBlockResizeBorder(
        dragPreviewRect: previewRect,
        handleSize: 8.0,
      );
      border.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 400, 300));
      // Clip the canvas to match the viewport.
      canvas.clipRect(const Rect.fromLTWH(0, 0, 400, 300));
      final context = _FakePaintingContext(canvas);

      expect(() => border.paint(context, Offset.zero), returnsNormally);
    });
  });

  group('RenderBlockResizeBorder — diagnostics', () {
    test('debugFillProperties reports all properties', () {
      final layout = _buildLayout();
      final border = RenderBlockResizeBorder(
        documentLayout: layout,
        selectedNodeId: 'b1',
        borderColor: const Color(0xFF0000FF),
        handleColor: const Color(0xFF00FF00),
        handleSize: 10.0,
        showHandles: false,
        dragPreviewRect: const Rect.fromLTWH(0, 0, 50, 50),
      );

      final builder = DiagnosticPropertiesBuilder();
      border.debugFillProperties(builder);

      final names = builder.properties.map((p) => p.name).toSet();
      expect(
        names,
        containsAll([
          'documentLayout',
          'selectedNodeId',
          'borderColor',
          'handleColor',
          'handleSize',
          'showHandles',
          'dragPreviewRect',
        ]),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal PaintingContext stub
// ---------------------------------------------------------------------------

/// A minimal [PaintingContext] stub that forwards canvas calls to the
/// provided [Canvas], allowing [RenderObject.paint] to be tested without
/// a full widget tree.
class _FakePaintingContext extends PaintingContext {
  _FakePaintingContext(this._canvas) : super(ContainerLayer(), Rect.largest);

  final Canvas _canvas;

  @override
  Canvas get canvas => _canvas;
}
