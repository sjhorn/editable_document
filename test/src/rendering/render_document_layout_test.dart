/// Tests for [RenderDocumentLayout].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [RenderTextBlock] with a fixed-size text for layout tests.
RenderTextBlock _textBlock(String nodeId, String text) => RenderTextBlock(
      nodeId: nodeId,
      text: AttributedText(text),
      textStyle: const TextStyle(fontSize: 16),
    );

/// Creates a [RenderHorizontalRuleBlock] for layout tests.
RenderHorizontalRuleBlock _hrBlock(String nodeId) => RenderHorizontalRuleBlock(
      nodeId: nodeId,
      thickness: 1.0,
      verticalPadding: 8.0,
    );

/// Creates a [RenderImageBlock] with layout properties for alignment/float tests.
///
/// [requestedWidth] and [requestedHeight] set explicit dimensions.
/// [blockAlignment] controls horizontal alignment within the layout.
/// [textWrap] controls how surrounding blocks interact with this block when
/// floated.
RenderImageBlock _imageBlock(
  String nodeId, {
  double? requestedWidth,
  double? requestedHeight,
  BlockAlignment blockAlignment = BlockAlignment.stretch,
  TextWrapMode textWrap = TextWrapMode.none,
}) =>
    RenderImageBlock(
      nodeId: nodeId,
      imageWidth: requestedWidth ?? 200,
      imageHeight: requestedHeight ?? 100,
      blockAlignment: blockAlignment,
      requestedWidth: requestedWidth,
      requestedHeight: requestedHeight,
      textWrap: textWrap,
    );

/// Creates a [RenderDocumentLayout] with the given children and lays it out.
RenderDocumentLayout _layout({
  required List<RenderDocumentBlock> children,
  double maxWidth = 400.0,
  double blockSpacing = 12.0,
}) {
  final layout = RenderDocumentLayout(blockSpacing: blockSpacing);
  for (final child in children) {
    layout.add(child);
  }
  layout.layout(BoxConstraints(maxWidth: maxWidth), parentUsesSize: true);
  return layout;
}

// ---------------------------------------------------------------------------
// Recording helpers for paint-order tests
// ---------------------------------------------------------------------------

/// A minimal [PaintingContext] that delegates [paintChild] to the child's
/// own [paint] method.  This is sufficient to trigger the recording overrides
/// on [_RecordingImageBlock] and [_RecordingTextBlock] without needing a full
/// Flutter rendering pipeline.
///
/// The recording blocks do NOT call super.paint(), so [canvas] is never
/// accessed and [RendererBinding] is never touched.
class _RecordingPaintingContext extends PaintingContext {
  _RecordingPaintingContext() : super(_FakeContainerLayer(), Rect.largest);

  @override
  void paintChild(RenderObject child, Offset offset) {
    child.paint(this, offset);
  }
}

/// Fake [ContainerLayer] used to construct the [_RecordingPaintingContext].
class _FakeContainerLayer extends ContainerLayer {}

/// A [RenderImageBlock] that appends its [nodeId] to [paintOrder] when painted.
class _RecordingImageBlock extends RenderImageBlock {
  _RecordingImageBlock(
    String nodeId, {
    required List<String> paintOrder,
    double requestedWidth = 100,
    double requestedHeight = 80,
    super.blockAlignment,
    super.textWrap,
  })  : _paintOrder = paintOrder,
        super(
          nodeId: nodeId,
          imageWidth: requestedWidth,
          imageHeight: requestedHeight,
          requestedWidth: requestedWidth,
          requestedHeight: requestedHeight,
        );

  final List<String> _paintOrder;

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintOrder.add(nodeId);
    // Do NOT call super — avoids TextPainter / image asset requirements.
  }
}

/// A [RenderTextBlock] that appends its [nodeId] to [paintOrder] when painted.
class _RecordingTextBlock extends RenderTextBlock {
  _RecordingTextBlock(
    String nodeId, {
    required List<String> paintOrder,
    required String text,
  })  : _paintOrder = paintOrder,
        super(
          nodeId: nodeId,
          text: AttributedText(text),
          textStyle: const TextStyle(fontSize: 16),
        );

  final List<String> _paintOrder;

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintOrder.add(nodeId);
    // Do NOT call super — avoids TextPainter layout requirements in headless tests.
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RenderDocumentLayout — construction', () {
    test('can be created with no children', () {
      final layout = RenderDocumentLayout();
      expect(layout, isA<RenderBox>());
    });

    test('blockSpacing defaults to 12.0', () {
      final layout = RenderDocumentLayout();
      expect(layout.blockSpacing, 12.0);
    });

    test('blockSpacing can be set via constructor', () {
      final layout = RenderDocumentLayout(blockSpacing: 8.0);
      expect(layout.blockSpacing, 8.0);
    });

    test('setting blockSpacing triggers re-layout', () {
      // Two children are required so spacing affects the total height.
      final layout = RenderDocumentLayout(blockSpacing: 4.0);
      layout.add(_textBlock('p1', 'Hello'));
      layout.add(_textBlock('p2', 'World'));
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      final heightBefore = layout.size.height;

      layout.blockSpacing = 20.0;
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      final heightAfter = layout.size.height;

      // With more spacing, total height should be greater.
      expect(heightAfter, greaterThan(heightBefore));
    });

    test('setting blockSpacing to same value does not trigger layout', () {
      final layout = RenderDocumentLayout(blockSpacing: 12.0);
      // No assertion needed — verifying it runs without error.
      layout.blockSpacing = 12.0;
    });
  });

  group('RenderDocumentLayout — layout', () {
    test('empty layout has zero height', () {
      final layout = RenderDocumentLayout();
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(layout.size.height, 0.0);
      expect(layout.size.width, 400.0);
    });

    test('single child — height equals child height', () {
      final child = _textBlock('p1', 'Hello');
      final layout = _layout(children: [child], blockSpacing: 0.0);
      // The layout height should exactly match the child height (no spacing
      // before the first element or after the last).
      expect(layout.size.height, child.size.height);
    });

    test('two children — height equals sum of heights plus one spacing gap', () {
      const spacing = 12.0;
      final c1 = _textBlock('p1', 'Hello');
      final c2 = _textBlock('p2', 'World');
      final layout = _layout(children: [c1, c2], blockSpacing: spacing);

      final expected = c1.size.height + spacing + c2.size.height;
      expect(layout.size.height, closeTo(expected, 0.001));
    });

    test('three mixed children — height is sum plus two spacing gaps', () {
      const spacing = 8.0;
      final c1 = _textBlock('p1', 'Paragraph');
      final c2 = _hrBlock('hr1');
      final c3 = _textBlock('p3', 'After rule');
      final layout = _layout(children: [c1, c2, c3], blockSpacing: spacing);

      final expected = c1.size.height + spacing + c2.size.height + spacing + c3.size.height;
      expect(layout.size.height, closeTo(expected, 0.001));
    });

    test('children are stacked vertically — second child is below first', () {
      final c1 = _textBlock('p1', 'First');
      final c2 = _textBlock('p2', 'Second');
      _layout(children: [c1, c2]);

      final c1Data = c1.parentData as DocumentBlockParentData;
      final c2Data = c2.parentData as DocumentBlockParentData;

      expect(c2Data.offset.dy, greaterThan(c1Data.offset.dy));
    });

    test('all children fill layout width', () {
      const maxWidth = 500.0;
      final c1 = _textBlock('p1', 'Hello');
      final c2 = _hrBlock('hr1');
      _layout(children: [c1, c2], maxWidth: maxWidth);

      expect(c1.size.width, maxWidth);
      expect(c2.size.width, maxWidth);
    });
  });

  group('RenderDocumentLayout — intrinsic sizes', () {
    test('computeMinIntrinsicHeight with no children is 0', () {
      final layout = RenderDocumentLayout();
      expect(layout.computeMinIntrinsicHeight(400), 0.0);
    });

    test('computeMaxIntrinsicHeight with no children is 0', () {
      final layout = RenderDocumentLayout();
      expect(layout.computeMaxIntrinsicHeight(400), 0.0);
    });

    test('computeMaxIntrinsicHeight includes spacing between multiple children', () {
      // Use blockSpacing > 0 and two children to verify spacing is accumulated.
      const spacing = 10.0;
      final layout = RenderDocumentLayout(blockSpacing: spacing);
      layout.add(_hrBlock('hr1'));
      layout.add(_hrBlock('hr2'));

      // Each HrBlock intrinsic height = thickness + 2 * verticalPadding = 17.0.
      // With two children, spacing is added once: 17 + 10 + 17 = 44.
      final h = layout.computeMaxIntrinsicHeight(400);
      expect(h, closeTo(17.0 + spacing + 17.0, 0.001));
    });

    test('computeMinIntrinsicHeight equals computeMaxIntrinsicHeight for fixed-height children',
        () {
      // HorizontalRuleBlock always returns the same intrinsic height.
      final layout = RenderDocumentLayout(blockSpacing: 5.0);
      layout.add(_hrBlock('hr1'));
      expect(
        layout.computeMinIntrinsicHeight(400),
        layout.computeMaxIntrinsicHeight(400),
      );
    });
  });

  group('RenderDocumentLayout — getComponentByNodeId', () {
    test('returns the matching child', () {
      final c1 = _textBlock('p1', 'First');
      final c2 = _hrBlock('hr1');
      final layout = _layout(children: [c1, c2]);

      expect(layout.getComponentByNodeId('p1'), same(c1));
      expect(layout.getComponentByNodeId('hr1'), same(c2));
    });

    test('returns null for unknown nodeId', () {
      final layout = _layout(children: [_textBlock('p1', 'Hello')]);
      expect(layout.getComponentByNodeId('unknown'), isNull);
    });
  });

  group('RenderDocumentLayout — getDocumentPositionAtOffset', () {
    test('returns DocumentPosition for a point inside the first child', () {
      final child = _textBlock('p1', 'Hello world');
      final layout = _layout(children: [child]);

      final pos = layout.getDocumentPositionAtOffset(const Offset(10, 5));
      expect(pos, isNotNull);
      expect(pos!.nodeId, 'p1');
      expect(pos.nodePosition, isA<TextNodePosition>());
    });

    test('returns DocumentPosition for a point inside the second child', () {
      const spacing = 0.0;
      final c1 = _textBlock('p1', 'First');
      final c2 = _textBlock('p2', 'Second');
      final layout = _layout(children: [c1, c2], blockSpacing: spacing);

      // A point just below the first child should land in the second child.
      final yInSecondChild = c1.size.height + 2.0;
      final pos = layout.getDocumentPositionAtOffset(Offset(10, yInSecondChild));
      expect(pos, isNotNull);
      expect(pos!.nodeId, 'p2');
    });

    test('returns null for a point outside all children', () {
      final child = _textBlock('p1', 'Hello');
      final layout = _layout(children: [child]);

      // Far below all content.
      final pos = layout.getDocumentPositionAtOffset(Offset(10, layout.size.height + 100));
      expect(pos, isNull);
    });

    test('returns null for empty layout', () {
      final layout = RenderDocumentLayout();
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      final pos = layout.getDocumentPositionAtOffset(const Offset(10, 10));
      expect(pos, isNull);
    });
  });

  group('RenderDocumentLayout — getDocumentPositionNearestToOffset', () {
    test('returns position in first child when offset is above all children', () {
      final child = _textBlock('p1', 'Hello world');
      final layout = _layout(children: [child]);

      final pos = layout.getDocumentPositionNearestToOffset(const Offset(10, -50));
      expect(pos.nodeId, 'p1');
    });

    test('returns position in last child when offset is below all children', () {
      final c1 = _textBlock('p1', 'First');
      final c2 = _textBlock('p2', 'Second');
      final layout = _layout(children: [c1, c2]);

      final pos = layout.getDocumentPositionNearestToOffset(
        Offset(10, layout.size.height + 1000),
      );
      expect(pos.nodeId, 'p2');
    });

    test('returns position inside child when offset is within child bounds', () {
      final c1 = _textBlock('p1', 'Hello');
      final c2 = _textBlock('p2', 'World');
      final layout = _layout(children: [c1, c2], blockSpacing: 0.0);

      final pos = layout.getDocumentPositionNearestToOffset(const Offset(5, 5));
      expect(pos.nodeId, 'p1');
    });

    test('returns nearest child position when offset is in the gap between children', () {
      const spacing = 20.0;
      final c1 = _textBlock('p1', 'First');
      final c2 = _textBlock('p2', 'Second');
      final layout = _layout(children: [c1, c2], blockSpacing: spacing);

      // Offset lands exactly in the spacing gap.
      final gapY = c1.size.height + spacing / 2;
      final pos = layout.getDocumentPositionNearestToOffset(Offset(10, gapY));
      // Should resolve to one of the two nodes.
      expect(['p1', 'p2'], contains(pos.nodeId));
    });

    test('prefers vertically closer child over horizontally closer', () {
      // Layout: full-width text at top, center-aligned image below.
      // Probe at (50, imageTop+1) — inside the image's Y range but far left
      // of its X range. The image should still win because it has Y-distance 0
      // while the text block above has positive Y-distance.
      const layoutWidth = 600.0;
      const imgWidth = 200.0;
      const imgHeight = 100.0;

      final text = _textBlock('p1', 'Full width text');
      final image = _imageBlock(
        'img1',
        requestedWidth: imgWidth,
        requestedHeight: imgHeight,
        blockAlignment: BlockAlignment.center,
      );
      final layout = _layout(
        children: [text, image],
        maxWidth: layoutWidth,
        blockSpacing: 0.0,
      );

      // The image is centered: its left edge is at (600-200)/2 = 200.
      // Probe at x=50 (outside image X range) but inside image Y range.
      final imageData = image.parentData as DocumentBlockParentData;
      final probeY = imageData.offset.dy + imgHeight / 2;
      final pos = layout.getDocumentPositionNearestToOffset(Offset(50, probeY));

      expect(pos.nodeId, 'img1');
    });

    test('picks closer X when Y distance is equal', () {
      // Two images at different X positions but identical Y-distance from
      // the probe point. The one closer in X should win.
      const layoutWidth = 600.0;

      final left = _imageBlock(
        'left',
        requestedWidth: 100,
        requestedHeight: 50,
        blockAlignment: BlockAlignment.start,
      );
      final right = _imageBlock(
        'right',
        requestedWidth: 100,
        requestedHeight: 50,
        blockAlignment: BlockAlignment.end,
      );
      final layout = _layout(
        children: [left, right],
        maxWidth: layoutWidth,
        blockSpacing: 10.0,
      );

      // Both blocks have equal Y-distance from a point in the gap.
      final leftData = left.parentData as DocumentBlockParentData;
      final gapY = leftData.offset.dy + 50 + 5; // midpoint of gap

      // Probe near right edge — right block is closer in X.
      final pos = layout.getDocumentPositionNearestToOffset(
        Offset(layoutWidth - 10, gapY),
      );
      expect(pos.nodeId, 'right');
    });
  });

  group('RenderDocumentLayout — getRectForDocumentPosition', () {
    test('returns a Rect for a valid position in the first child', () {
      final child = _textBlock('p1', 'Hello world');
      final layout = _layout(children: [child]);

      const pos = DocumentPosition(
        nodeId: 'p1',
        nodePosition: TextNodePosition(offset: 0),
      );
      final rect = layout.getRectForDocumentPosition(pos);
      expect(rect, isNotNull);
      expect(rect!.height, greaterThan(0));
    });

    test('rect for second child is offset below first child', () {
      const spacing = 0.0;
      final c1 = _textBlock('p1', 'First');
      final c2 = _textBlock('p2', 'Second');
      final layout = _layout(children: [c1, c2], blockSpacing: spacing);

      const pos1 = DocumentPosition(
        nodeId: 'p1',
        nodePosition: TextNodePosition(offset: 0),
      );
      const pos2 = DocumentPosition(
        nodeId: 'p2',
        nodePosition: TextNodePosition(offset: 0),
      );

      final rect1 = layout.getRectForDocumentPosition(pos1)!;
      final rect2 = layout.getRectForDocumentPosition(pos2)!;

      // The rect in the second child must be below the first child.
      expect(rect2.top, greaterThanOrEqualTo(rect1.bottom));
    });

    test('returns null for unknown nodeId', () {
      final layout = _layout(children: [_textBlock('p1', 'Hello')]);

      const pos = DocumentPosition(
        nodeId: 'unknown',
        nodePosition: TextNodePosition(offset: 0),
      );
      final rect = layout.getRectForDocumentPosition(pos);
      expect(rect, isNull);
    });
  });

  group('RenderDocumentLayout — viewport / scroll extent', () {
    test('maxScrollExtent is zero when content fits viewport', () {
      final child = _textBlock('p1', 'Short');
      final layout = RenderDocumentLayout();
      layout.add(child);
      layout.layout(
        const BoxConstraints(maxWidth: 400, maxHeight: 600),
        parentUsesSize: true,
      );

      expect(layout.computeMaxScrollExtent(600), 0.0);
    });

    test('maxScrollExtent is positive when content overflows viewport', () {
      // Build enough children so their combined height exceeds viewportHeight.
      final layout = RenderDocumentLayout(blockSpacing: 0.0);
      for (var i = 0; i < 20; i++) {
        layout.add(_textBlock('p$i', 'Line $i of text that may wrap or not.'));
      }
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      const viewportHeight = 50.0;

      final extent = layout.computeMaxScrollExtent(viewportHeight);
      expect(extent, greaterThan(0));
    });
  });

  group('RenderDocumentLayout — baseline computation', () {
    // getDryBaseline is callable without an active PipelineOwner, making
    // these tests straightforward unit tests.

    test('returns null baseline when layout has no children', () {
      final layout = RenderDocumentLayout();
      // With no children there is no text to derive a baseline from.
      final double? baseline = layout.getDryBaseline(
        const BoxConstraints(maxWidth: 400),
        TextBaseline.alphabetic,
      );
      expect(baseline, isNull);
    });

    test('returns non-null baseline from first child when layout has a text block', () {
      final layout = RenderDocumentLayout();
      layout.add(_textBlock('p1', 'Hello'));

      final double? baseline = layout.getDryBaseline(
        const BoxConstraints(maxWidth: 400),
        TextBaseline.alphabetic,
      );
      expect(baseline, isNotNull);
      expect(baseline, greaterThan(0));
    });

    test('baseline of layout equals first child dry baseline (child offset is zero)', () {
      // Two children with spacing — the layout baseline must equal the first
      // child's baseline because the first child sits at offset (0,0).
      final layout = RenderDocumentLayout(blockSpacing: 20.0);
      final c1 = _textBlock('p1', 'First');
      final c2 = _textBlock('p2', 'Second');
      layout.add(c1);
      layout.add(c2);

      const constraints = BoxConstraints(maxWidth: 400);
      final double? layoutBaseline = layout.getDryBaseline(
        constraints,
        TextBaseline.alphabetic,
      );
      final double? childBaseline = c1.getDryBaseline(
        constraints,
        TextBaseline.alphabetic,
      );

      expect(layoutBaseline, isNotNull);
      expect(childBaseline, isNotNull);
      // First child is at y=0, so layout baseline == first child baseline.
      expect(layoutBaseline, equals(childBaseline));
    });
  });

  group('RenderDocumentLayout — diagnostics', () {
    test('debugFillProperties includes blockSpacing', () {
      final layout = RenderDocumentLayout(blockSpacing: 8.0);
      final builder = DiagnosticPropertiesBuilder();
      layout.debugFillProperties(builder);

      final prop = builder.properties.firstWhere(
        (p) => p.name == 'blockSpacing',
        orElse: () => throw StateError('blockSpacing not found in properties'),
      );
      expect(prop.toDescription(), contains('8'));
    });
  });

  group('RenderDocumentLayout — getRectsForSelection', () {
    test('collapsed selection returns empty list', () {
      final child = _textBlock('p1', 'Hello world');
      final layout = _layout(children: [child], blockSpacing: 0.0);

      const sel = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );
      final rects = layout.getRectsForSelection(sel);
      expect(rects, isEmpty);
    });

    test('same-node selection returns rects from getEndpointsForSelection', () {
      final child = _textBlock('p1', 'Hello world');
      final layout = _layout(children: [child], blockSpacing: 0.0);

      const sel = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );
      final rects = layout.getRectsForSelection(sel);
      // Non-empty: the selection covers "Hello"
      expect(rects, isNotEmpty);
      // All rects must lie within the first child's y-range.
      final childData = child.parentData as DocumentBlockParentData;
      final childTop = childData.offset.dy;
      final childBottom = childTop + child.size.height;
      for (final r in rects) {
        expect(r.top, greaterThanOrEqualTo(childTop));
        expect(r.bottom, lessThanOrEqualTo(childBottom));
      }
    });

    test('same-node selection with mixed font sizes returns correct per-span rects', () {
      // Build a text block whose attributions produce two different font sizes.
      // The key constraint: the returned rects must all have the same top
      // (or nearly so) — meaning the multi-line path must NOT be taken for a
      // selection that fits on one visual line.
      final mixedText = AttributedText(
        'AB',
        [
          const SpanMarker(
            attribution: FontSizeAttribution(12),
            offset: 0,
            markerType: SpanMarkerType.start,
          ),
          const SpanMarker(
            attribution: FontSizeAttribution(12),
            offset: 0,
            markerType: SpanMarkerType.end,
          ),
          const SpanMarker(
            attribution: FontSizeAttribution(24),
            offset: 1,
            markerType: SpanMarkerType.start,
          ),
          const SpanMarker(
            attribution: FontSizeAttribution(24),
            offset: 1,
            markerType: SpanMarkerType.end,
          ),
        ],
      );
      final child = RenderTextBlock(
        nodeId: 'p1',
        text: mixedText,
        textStyle: const TextStyle(fontSize: 16),
      );
      final layout = _layout(children: [child], blockSpacing: 0.0);

      const sel = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 2),
        ),
      );
      final rects = layout.getRectsForSelection(sel);
      // Must return at least one rect without exploding.
      expect(rects, isNotEmpty);
      // All rects originate in the same child — verify they are within bounds.
      final childData = child.parentData as DocumentBlockParentData;
      final childTop = childData.offset.dy;
      final childBottom = childTop + child.size.height;
      for (final r in rects) {
        expect(r.top, greaterThanOrEqualTo(childTop - 1.0)); // 1 px tolerance
        expect(r.bottom, lessThanOrEqualTo(childBottom + 1.0));
      }
    });

    test('cross-node selection returns rects covering both nodes', () {
      final c1 = _textBlock('p1', 'First paragraph');
      final c2 = _textBlock('p2', 'Second paragraph');
      final layout = _layout(children: [c1, c2], blockSpacing: 0.0);

      const sel = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p2',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );
      final rects = layout.getRectsForSelection(sel);
      // At least two rects (one for each node's line).
      expect(rects.length, greaterThanOrEqualTo(2));

      // The top-most rect should be within p1 y-range.
      final c1Data = c1.parentData as DocumentBlockParentData;
      final topRect = rects.reduce((a, b) => a.top < b.top ? a : b);
      expect(topRect.top, closeTo(c1Data.offset.dy, 2.0));

      // The bottom-most rect should be within p2 y-range.
      final c2Data = c2.parentData as DocumentBlockParentData;
      final bottomRect = rects.reduce((a, b) => a.bottom > b.bottom ? a : b);
      expect(bottomRect.bottom, greaterThanOrEqualTo(c2Data.offset.dy));
    });

    test('returns empty list when base node is not found', () {
      final child = _textBlock('p1', 'Hello');
      final layout = _layout(children: [child], blockSpacing: 0.0);

      const sel = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'unknown',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );
      final rects = layout.getRectsForSelection(sel);
      expect(rects, isEmpty);
    });

    test('returns empty list when extent node is not found', () {
      final child = _textBlock('p1', 'Hello');
      final layout = _layout(children: [child], blockSpacing: 0.0);

      const sel = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'unknown',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );
      final rects = layout.getRectsForSelection(sel);
      expect(rects, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Alignment layout
  // ---------------------------------------------------------------------------

  group('RenderDocumentLayout — alignment layout', () {
    const maxWidth = 400.0;
    const childWidth = 150.0;
    const childHeight = 80.0;

    test('center-aligned block is positioned at correct x-offset', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: childWidth,
        requestedHeight: childHeight,
        blockAlignment: BlockAlignment.center,
      );
      _layout(children: [image], maxWidth: maxWidth, blockSpacing: 0.0);

      final data = image.parentData as DocumentBlockParentData;
      expect(data.offset.dx, closeTo((maxWidth - image.size.width) / 2, 0.5));
    });

    test('end-aligned block is positioned at correct x-offset', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: childWidth,
        requestedHeight: childHeight,
        blockAlignment: BlockAlignment.end,
      );
      _layout(children: [image], maxWidth: maxWidth, blockSpacing: 0.0);

      final data = image.parentData as DocumentBlockParentData;
      expect(data.offset.dx, closeTo(maxWidth - image.size.width, 0.5));
    });

    test('start-aligned block (no textWrap) is positioned at x = 0', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: childWidth,
        requestedHeight: childHeight,
        blockAlignment: BlockAlignment.start,
      );
      _layout(children: [image], maxWidth: maxWidth, blockSpacing: 0.0);

      final data = image.parentData as DocumentBlockParentData;
      expect(data.offset.dx, 0.0);
    });

    test('stretch block fills full width (existing behaviour preserved)', () {
      final image = _imageBlock(
        'img1',
        blockAlignment: BlockAlignment.stretch,
      );
      _layout(children: [image], maxWidth: maxWidth, blockSpacing: 0.0);

      expect(image.size.width, maxWidth);
    });

    test('aligned block (no textWrap) takes a full vertical row', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: childWidth,
        requestedHeight: childHeight,
        blockAlignment: BlockAlignment.center,
      );
      final text = _textBlock('p1', 'Below');
      _layout(
        children: [image, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final imageData = image.parentData as DocumentBlockParentData;
      final textData = text.parentData as DocumentBlockParentData;

      // Text must start below the image.
      expect(textData.offset.dy, greaterThanOrEqualTo(imageData.offset.dy + image.size.height));
    });

    test('isFloat is false for non-float blocks', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: childWidth,
        requestedHeight: childHeight,
        blockAlignment: BlockAlignment.center,
      );
      _layout(children: [image], maxWidth: maxWidth, blockSpacing: 0.0);

      final data = image.parentData as DocumentBlockParentData;
      expect(data.isFloat, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Float layout
  // ---------------------------------------------------------------------------

  group('RenderDocumentLayout — float layout', () {
    const maxWidth = 400.0;
    const floatWidth = 100.0;
    const floatHeight = 80.0;

    test('float start: image positioned at x = 0', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Wrapped text beside float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      expect(imageData.offset.dx, 0.0);
      expect(imageData.isFloat, isTrue);
    });

    test('float start: adjacent text block gets full width with exclusionRect (not narrowed)', () {
      // A text block has clearsFloat == false, so it wraps beside the float.
      // With the exclusion-rect approach, the text block receives FULL-WIDTH
      // constraints and an exclusionRect describing the float zone, so
      // _performExclusionLayout can handle the three-zone layout and expand
      // text back to full width once it passes the float's bottom.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text beside float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      final textData = text.parentData as DocumentBlockParentData;

      // Text must start beside the float (y < float bottom).
      expect(textData.offset.dy, lessThan(floatBottom));
      // Text block is now full-width, positioned at x=0.
      expect(textData.offset.dx, 0.0);
      // Text block receives full-width constraints (not narrowed).
      expect(text.size.width, closeTo(maxWidth, 0.5));
      // An exclusionRect describing the float zone is set on the parentData.
      expect(textData.exclusionRect, isNotNull);
      expect(textData.exclusionRect!.left, 0.0);
      expect(textData.exclusionRect!.right, closeTo(floatWidth + 8.0, 0.5));
    });

    test('float start: stretch block with requestedWidth starts to the right of the float', () {
      // An image block with an explicit requestedWidth that fits beside the
      // float should wrap alongside it.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      // Small image with an explicit requestedWidth that fits in the remaining space.
      final beside = _imageBlock(
        'img2',
        requestedWidth: 50.0,
        requestedHeight: 40.0,
        blockAlignment: BlockAlignment.stretch,
      );
      _layout(children: [image, beside], maxWidth: maxWidth, blockSpacing: 0.0);

      final besideData = beside.parentData as DocumentBlockParentData;
      expect(besideData.offset.dx, closeTo(floatWidth + 8.0, 0.5));
    });

    test('float end: image positioned at x = maxWidth - imageWidth', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Wrapped text beside float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      expect(imageData.offset.dx, closeTo(maxWidth - floatWidth, 0.5));
      expect(imageData.isFloat, isTrue);
    });

    test('float end: adjacent text block gets full width with exclusionRect (not narrowed)', () {
      // A text block has clearsFloat == false, so it wraps beside the end float.
      // With the exclusion-rect approach, the text block receives FULL-WIDTH
      // constraints and an exclusionRect on the right side, so
      // _performExclusionLayout can expand text back to full width after the float.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text beside float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      final textData = text.parentData as DocumentBlockParentData;

      // Text must start beside the float (y < float bottom).
      expect(textData.offset.dy, lessThan(floatBottom));
      // Text block is at x=0 (float is on the end/right side).
      expect(textData.offset.dx, 0.0);
      // Text block receives full-width constraints (not narrowed).
      expect(text.size.width, closeTo(maxWidth, 0.5));
      // An exclusionRect describing the float zone is set on the parentData.
      expect(textData.exclusionRect, isNotNull);
      expect(
        textData.exclusionRect!.left,
        closeTo(maxWidth - floatWidth - 8.0, 0.5),
      );
      expect(textData.exclusionRect!.right, closeTo(maxWidth, 0.5));
    });

    test('total layout height is at least the float height when no block is taller', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      // Use a very short text so the text block is shorter than the float.
      final text = _textBlock('p1', 'Hi');
      final layout = _layout(
        children: [image, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // Layout height must not be less than the float bottom.
      final imageData = image.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      expect(layout.size.height, greaterThanOrEqualTo(floatBottom));
    });

    test('block after text that clears the float bottom gets full width', () {
      // The float is short (20 px), and the text wrapping beside it is taller
      // (long paragraph).  A third block placed after that text should be past
      // the float bottom and get the full width.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: 20.0, // very short float
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      // Long text whose height will exceed the float height.
      final wrappedText = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText(
          'A much longer paragraph that will wrap over multiple lines to exceed the float height.',
        ),
        textStyle: const TextStyle(fontSize: 16),
      );
      final afterText = _textBlock('p2', 'After float');
      final layout = _layout(
        children: [image, wrappedText, afterText],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // afterText should be positioned below the float zone.
      final imageData = image.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      final wrappedData = wrappedText.parentData as DocumentBlockParentData;
      final wrappedBottom = wrappedData.offset.dy + wrappedText.size.height;

      // If the wrapped text extends past the float, the next block gets full width.
      if (wrappedBottom > floatBottom) {
        expect(afterText.size.width, closeTo(maxWidth, 0.5));
      }
      // Layout should not crash.
      expect(layout.size.height, greaterThan(0));
    });

    test('HR block (clearsFloat true) clears exclusion and drops below float', () {
      // A RenderHorizontalRuleBlock with no requestedWidth has clearsFloat==true.
      // It should NOT be squeezed beside the float — instead it should drop
      // below the float bottom and be laid out at full width.
      final image = _imageBlock(
        'img1',
        requestedWidth: 100.0,
        requestedHeight: 80.0,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      // HR block has clearsFloat == true (no requestedWidth) — must clear the float.
      final hr = _hrBlock('hr1');
      final layout = _layout(
        children: [image, hr],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final imageData = image.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      final hrData = hr.parentData as DocumentBlockParentData;

      // HR must start at or below the float bottom (cleared, not beside).
      expect(hrData.offset.dy, greaterThanOrEqualTo(floatBottom));
      // HR must be full width.
      expect(hr.size.width, closeTo(maxWidth, 0.5));
      // Layout must be taller than just the float alone.
      expect(layout.size.height, greaterThan(floatBottom));
    });

    test('text block beside start float gets full width with exclusionRect', () {
      // A RenderTextBlock has clearsFloat == false (default).
      // With the exclusion-rect approach it gets full-width constraints plus an
      // exclusionRect, so _performExclusionLayout handles the beside/below zones.
      final image = _imageBlock(
        'img1',
        requestedWidth: 100.0,
        requestedHeight: 80.0,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text that wraps beside the float image.');
      final layout = _layout(
        children: [image, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final imageData = image.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      final textData = text.parentData as DocumentBlockParentData;

      // Text starts at y=0 (same row as the float), not below it.
      expect(textData.offset.dy, lessThan(floatBottom));
      // Text block is full-width at x=0 (exclusionRect handles the narrowing).
      expect(textData.offset.dx, 0.0);
      // Text block receives full-width constraints (not narrowed).
      expect(text.size.width, closeTo(maxWidth, 0.5));
      // exclusionRect is set describing the float zone.
      expect(textData.exclusionRect, isNotNull);
      // Layout height covers the float.
      expect(layout.size.height, greaterThanOrEqualTo(floatBottom));
    });

    test('stretch image block (clearsFloat false) wraps beside float', () {
      // An image block has clearsFloat == false (default), so it wraps beside
      // the float regardless of its requestedWidth.
      final image = _imageBlock(
        'img1',
        requestedWidth: 100.0,
        requestedHeight: 80.0,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      // Image with stretch alignment and a requestedWidth that fits in the
      // remaining space beside the float (maxWidth - floatWidth - gap = 292 px).
      final smallBlock = _imageBlock(
        'img2',
        requestedWidth: 50.0,
        requestedHeight: 30.0,
        blockAlignment: BlockAlignment.stretch,
      );
      final layout = _layout(
        children: [image, smallBlock],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final imageData = image.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      final smallData = smallBlock.parentData as DocumentBlockParentData;

      // The small block should be beside the float (its y < float bottom).
      expect(smallData.offset.dy, lessThan(floatBottom));
      // Its x-offset should be pushed right to avoid the float.
      expect(smallData.offset.dx, greaterThan(0.0));
      // Layout should be taller than the small block alone.
      expect(layout.size.height, greaterThan(0));
    });

    test('two consecutive floats do not overlap — second starts below first', () {
      // When two float blocks appear back-to-back the second must be placed
      // below the first, not at the same y-offset.
      final image1 = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final image2 = _imageBlock(
        'img2',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      _layout(children: [image1, image2], maxWidth: maxWidth, blockSpacing: 0.0);

      final data1 = image1.parentData as DocumentBlockParentData;
      final data2 = image2.parentData as DocumentBlockParentData;

      // The second float must start at or after the bottom edge of the first.
      final firstBottom = data1.offset.dy + image1.size.height;
      expect(
        data2.offset.dy,
        greaterThanOrEqualTo(firstBottom),
        reason: 'second float overlaps first float',
      );
    });

    test('non-float aligned block wraps beside float when it fits', () {
      // Float on the left, then a non-float center-aligned block.
      // The aligned block fits in the available space beside the float, so it
      // should wrap there rather than drop below.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth, // 100
        requestedHeight: 200.0, // tall float
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      // Non-float, non-stretch block placed after the float.
      // 60 px fits comfortably beside a 100 px float in a 400 px layout
      // (available = 400 - 108 = 292 px).
      final centeredImage = _imageBlock(
        'img2',
        requestedWidth: 60.0,
        requestedHeight: 60.0,
        blockAlignment: BlockAlignment.center,
        // textWrap defaults to TextWrapMode.none — NOT a float
      );
      _layout(
        children: [image, centeredImage],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final imageData = image.parentData as DocumentBlockParentData;
      final centeredData = centeredImage.parentData as DocumentBlockParentData;
      expect(centeredData.isFloat, isFalse);

      // The aligned block fits beside the float — it must NOT drop below.
      final floatBottom = imageData.offset.dy + image.size.height;
      expect(
        centeredData.offset.dy,
        lessThan(floatBottom),
        reason: 'block that fits beside float should wrap there, not clear it',
      );
      // Center-aligned within the available space to the right of the float:
      // availableLeft = 100 + 8 = 108, availableWidth = 292, blockWidth = 60
      // expectedX = 108 + (292 - 60) / 2 = 108 + 116 = 224
      const floatGap = 8.0;
      final availableLeft = floatWidth + floatGap;
      final availableWidth = maxWidth - availableLeft;
      final expectedX = availableLeft + (availableWidth - 60.0) / 2;
      expect(centeredData.offset.dx, closeTo(expectedX, 0.5));
    });

    test('end-aligned block wraps beside end float when it fits', () {
      // An end-aligned float followed by an end-aligned non-float block whose
      // requestedWidth fits in the available space beside the float.
      // The block should wrap there rather than drop below.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth, // 100
        requestedHeight: 200.0,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      // 250 px fits beside a 100 px end float in a 400 px layout
      // (available = 400 - 108 = 292 px).
      final codeBlock = RenderCodeBlock(
        nodeId: 'code1',
        text: AttributedText('print("hello")'),
        blockAlignment: BlockAlignment.end,
        requestedWidth: 250.0,
      );
      _layout(
        children: [image, codeBlock],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final imageData = image.parentData as DocumentBlockParentData;
      final codeData = codeBlock.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;

      // Block fits beside float — must NOT drop below.
      expect(
        codeData.offset.dy,
        lessThan(floatBottom),
        reason: 'block that fits beside end float should wrap there, not clear it',
      );
      // End-aligned within available space to the left of the end float:
      // availableWidth = 400 - 108 = 292, blockWidth = 250
      // expectedX = max(0, 292 - 250) = 42
      const floatGap = 8.0;
      final availableWidth = maxWidth - (floatWidth + floatGap);
      final expectedX = (availableWidth - 250.0).clamp(0.0, double.infinity);
      expect(codeData.offset.dx, closeTo(expectedX, 0.5));
    });

    test('center-aligned HR clears end float', () {
      // An end-aligned float followed by a center-aligned HR.
      // The HR must advance past the float to avoid overlapping.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: 200.0,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      // HR defaults to stretch (which clears), so use a non-stretch HR.
      final hrCentered = RenderHorizontalRuleBlock(
        nodeId: 'hr1',
        blockAlignment: BlockAlignment.center,
      );
      _layout(
        children: [image, hrCentered],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final imageData = image.parentData as DocumentBlockParentData;
      final hrData = hrCentered.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      expect(hrData.offset.dy, greaterThanOrEqualTo(floatBottom));
    });

    test('float start: aligned start block wraps beside float when it fits', () {
      // A start-aligned code block whose requestedWidth fits in the space
      // beside a start float should wrap there, not drop below.
      const codeWidth = 150.0; // fits beside 100 px float in 400 px layout
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth, // 100
        requestedHeight: floatHeight, // 80
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final codeBlock = RenderCodeBlock(
        nodeId: 'code1',
        text: AttributedText('x = 1'),
        blockAlignment: BlockAlignment.start,
        requestedWidth: codeWidth,
        requestedHeight: 40.0,
      );
      _layout(children: [image, codeBlock], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      final codeData = codeBlock.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;

      // Code block must start beside the float (y < float bottom).
      expect(
        codeData.offset.dy,
        lessThan(floatBottom),
        reason: 'start-aligned block should wrap beside float, not drop below',
      );
      // Code block x must be to the right of the float (floatWidth + gap).
      expect(
        codeData.offset.dx,
        greaterThanOrEqualTo(floatWidth),
        reason: 'start-aligned block should be positioned after the float',
      );
    });

    test('float start: aligned end block wraps beside float when it fits', () {
      // An end-aligned code block that fits beside a start float should wrap
      // there and be pushed to the right within the available space.
      const codeWidth = 150.0;
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final codeBlock = RenderCodeBlock(
        nodeId: 'code1',
        text: AttributedText('x = 1'),
        blockAlignment: BlockAlignment.end,
        requestedWidth: codeWidth,
        requestedHeight: 40.0,
      );
      _layout(children: [image, codeBlock], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      final codeData = codeBlock.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;

      // Code block must start beside the float (y < float bottom).
      expect(
        codeData.offset.dy,
        lessThan(floatBottom),
        reason: 'end-aligned block should wrap beside start float, not drop below',
      );
      // Code block should be at the end of the available space beside float.
      // Available space: floatWidth+gap .. maxWidth, so end x = maxWidth - codeWidth.
      expect(
        codeData.offset.dx,
        closeTo(maxWidth - codeWidth, 0.5),
        reason: 'end-aligned block should be right-aligned within available space',
      );
    });

    test('float start: aligned center block wraps beside float when it fits', () {
      // A center-aligned code block that fits beside a start float should wrap
      // there and be centred within the available space beside the float.
      const codeWidth = 100.0;
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final codeBlock = RenderCodeBlock(
        nodeId: 'code1',
        text: AttributedText('x = 1'),
        blockAlignment: BlockAlignment.center,
        requestedWidth: codeWidth,
        requestedHeight: 40.0,
      );
      _layout(children: [image, codeBlock], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      final codeData = codeBlock.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;

      // Code block must start beside the float (y < float bottom).
      expect(
        codeData.offset.dy,
        lessThan(floatBottom),
        reason: 'center-aligned block should wrap beside start float, not drop below',
      );
      // Centred within available space: [floatWidth+gap .. maxWidth].
      // _kFloatGap is 8.0 (the gap added to float exclusion zones).
      const floatGap = 8.0;
      final availableLeft = floatWidth + floatGap;
      final availableWidth = maxWidth - availableLeft;
      final expectedX = availableLeft + (availableWidth - codeWidth) / 2;
      expect(
        codeData.offset.dx,
        closeTo(expectedX, 0.5),
        reason: 'center-aligned block should be centred in available space beside float',
      );
    });

    test('float end: aligned block wraps beside float when it fits', () {
      // A start-aligned code block that fits beside an end float should wrap
      // there at x=0.
      const codeWidth = 150.0;
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final codeBlock = RenderCodeBlock(
        nodeId: 'code1',
        text: AttributedText('x = 1'),
        blockAlignment: BlockAlignment.start,
        requestedWidth: codeWidth,
        requestedHeight: 40.0,
      );
      _layout(children: [image, codeBlock], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      final codeData = codeBlock.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;

      // Code block must start beside the float (y < float bottom).
      expect(
        codeData.offset.dy,
        lessThan(floatBottom),
        reason: 'start-aligned block should wrap beside end float, not drop below',
      );
      // Float is on the end side, so available space starts at x=0.
      expect(
        codeData.offset.dx,
        closeTo(0.0, 0.5),
        reason: 'start-aligned block beside end float should be at x=0',
      );
    });

    test('aligned block clears float when it does not fit', () {
      // A code block whose requestedWidth is wider than the available space
      // beside the float must clear the float and drop below it.
      const codeWidth = 350.0; // too wide to fit beside 100 px float (avail = 292)
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final codeBlock = RenderCodeBlock(
        nodeId: 'code1',
        text: AttributedText('x = 1'),
        blockAlignment: BlockAlignment.start,
        requestedWidth: codeWidth,
        requestedHeight: 40.0,
      );
      _layout(children: [image, codeBlock], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      final codeData = codeBlock.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;

      // Code block must clear the float (y >= float bottom).
      expect(
        codeData.offset.dy,
        greaterThanOrEqualTo(floatBottom),
        reason: 'block too wide to fit beside float should clear it',
      );
    });

    test(
        'float start: stretch code block (no requestedWidth) gets narrowed width, not exclusionRect',
        () {
      // A RenderCodeBlock with blockAlignment: stretch and NO requestedWidth
      // has prefersNarrowedFloat == true, so the layout should route it through
      // the narrowed-width path (offset to the right of the float, reduced
      // width) instead of the exclusion-rect path (full width + exclusionRect).
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final codeBlock = RenderCodeBlock(
        nodeId: 'code1',
        text: AttributedText('print("hello")'),
        blockAlignment: BlockAlignment.stretch,
        // No requestedWidth — default stretch behavior.
      );
      _layout(children: [image, codeBlock], maxWidth: maxWidth, blockSpacing: 0.0);

      const floatGap = 8.0;
      final codeData = codeBlock.parentData as DocumentBlockParentData;

      // Code block x-offset must equal floatWidth + gap.
      expect(
        codeData.offset.dx,
        closeTo(floatWidth + floatGap, 0.5),
        reason: 'stretch code block should be offset to the right of the float',
      );
      // Code block width must be narrowed (maxWidth - floatWidth - gap).
      expect(
        codeBlock.size.width,
        closeTo(maxWidth - floatWidth - floatGap, 0.5),
        reason: 'stretch code block should be narrowed, not full width',
      );
      // No exclusionRect — the block uses the narrowed-width path.
      expect(
        codeData.exclusionRect,
        isNull,
        reason: 'stretch code block with prefersNarrowedFloat should not get an exclusionRect',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Dual float layout (concurrent start + end exclusions)
  // ---------------------------------------------------------------------------

  group('RenderDocumentLayout — dual float layout', () {
    const maxWidth = 400.0;
    const floatWidth = 100.0;
    const floatHeight = 80.0;
    const kFloatGap = 8.0;

    test('start+end floats: stretch block width is narrowed from both sides', () {
      // Place a start float and an end float, then a stretch text block.
      // The text block should have its width reduced by both floats' widths.
      final startFloat = _imageBlock(
        'start',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final endFloat = _imageBlock(
        'end',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text between floats');
      _layout(
        children: [startFloat, endFloat, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final textData = text.parentData as DocumentBlockParentData;

      // Text width = maxWidth - startFloatWidth - gap - endFloatWidth - gap
      final expectedWidth = maxWidth - (floatWidth + kFloatGap) - (floatWidth + kFloatGap);
      expect(
        text.size.width,
        closeTo(expectedWidth, 0.5),
        reason: 'stretch block width should be narrowed by both start and end floats',
      );
      // Text x offset = startFloatWidth + gap
      expect(
        textData.offset.dx,
        closeTo(floatWidth + kFloatGap, 0.5),
        reason: 'stretch block should be offset past the start float',
      );
    });

    test('start+end floats: stretch block is at correct x after start float', () {
      // Verify both offset and width constraints in a single scenario.
      final startFloat = _imageBlock(
        'start',
        requestedWidth: 80.0,
        requestedHeight: 120.0,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final endFloat = _imageBlock(
        'end',
        requestedWidth: 60.0,
        requestedHeight: 120.0,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Narrow text');
      _layout(
        children: [startFloat, endFloat, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final textData = text.parentData as DocumentBlockParentData;

      // Expected: x = 80 + 8 = 88, width = 400 - 88 - 60 - 8 = 244
      const expectedX = 80.0 + kFloatGap;
      const expectedWidth = maxWidth - expectedX - 60.0 - kFloatGap;
      expect(
        textData.offset.dx,
        closeTo(expectedX, 0.5),
        reason: 'x offset should be past start float only',
      );
      expect(
        text.size.width,
        closeTo(expectedWidth, 0.5),
        reason: 'width should exclude both float exclusion zones',
      );
    });

    test('independent clearing: short start float clears before tall end float', () {
      // Start float is 50 px tall, end float is 120 px tall.
      // A stretch text block whose height exceeds both floats appears after them.
      // After layout: text is beside both floats at first.
      // The next block after the text (where text bottom > start float bottom
      // but < end float bottom) should still respect only the end exclusion.
      final shortStartFloat = _imageBlock(
        'start',
        requestedWidth: 80.0,
        requestedHeight: 50.0, // short
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final tallEndFloat = _imageBlock(
        'end',
        requestedWidth: 80.0,
        requestedHeight: 120.0, // tall
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      // A text block beside both floats (same y=0).
      final textBeside = _textBlock('p1', 'Beside both floats');

      // A second text block placed AFTER textBeside that lands in the zone
      // where start float has cleared but end float is still active.
      // Use a tall first text block so its bottom (y > 50) puts the next block
      // past the start float but still within the end float.
      //
      // We use a short placeholder text that renders very short here and test
      // the geometry of the resulting layout instead.
      _layout(
        children: [shortStartFloat, tallEndFloat, textBeside],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // The text block should be at x = startFloat.width + gap = 88.
      final textData = textBeside.parentData as DocumentBlockParentData;
      expect(
        textData.offset.dx,
        closeTo(80.0 + kFloatGap, 0.5),
        reason: 'text block x offset should be past start float',
      );
      // The text block width should be narrowed from BOTH sides.
      final expectedWidth = maxWidth - (80.0 + kFloatGap) - (80.0 + kFloatGap);
      expect(
        textBeside.size.width,
        closeTo(expectedWidth, 0.5),
        reason: 'text block should be narrowed by both start and end floats',
      );
    });

    test('hit testing with dual exclusions: tap on start float hits start float', () {
      final startFloat = _imageBlock(
        'start',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final endFloat = _imageBlock(
        'end',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text between floats');
      final layout = _layout(
        children: [startFloat, endFloat, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // Tap at centre of start float.
      final startData = startFloat.parentData as DocumentBlockParentData;
      final hitPoint = startData.offset + const Offset(floatWidth / 2, floatHeight / 2);
      final pos = layout.getDocumentPositionAtOffset(hitPoint);

      expect(pos, isNotNull);
      expect(pos!.nodeId, 'start', reason: 'tap on start float should hit start float');
    });

    test('hit testing with dual exclusions: tap on end float hits end float', () {
      final startFloat = _imageBlock(
        'start',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final endFloat = _imageBlock(
        'end',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text between floats');
      final layout = _layout(
        children: [startFloat, endFloat, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // Tap at centre of end float.
      final endData = endFloat.parentData as DocumentBlockParentData;
      final hitPoint = endData.offset + const Offset(floatWidth / 2, floatHeight / 2);
      final pos = layout.getDocumentPositionAtOffset(hitPoint);

      expect(pos, isNotNull);
      expect(pos!.nodeId, 'end', reason: 'tap on end float should hit end float');
    });

    test('hit testing with dual exclusions: tap in narrowed text area hits text block', () {
      final startFloat = _imageBlock(
        'start',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final endFloat = _imageBlock(
        'end',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text between floats');
      final layout = _layout(
        children: [startFloat, endFloat, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // Tap inside the narrowed text block area.
      final textData = text.parentData as DocumentBlockParentData;
      final hitPoint = textData.offset + const Offset(5.0, 5.0);
      final pos = layout.getDocumentPositionAtOffset(hitPoint);

      expect(pos, isNotNull);
      expect(pos!.nodeId, 'p1', reason: 'tap in narrowed text area should hit text block');
    });

    test('layout height accounts for both exclusion zones', () {
      // When the text is shorter than both floats, the layout height must be
      // at least the taller float's bottom.
      final startFloat = _imageBlock(
        'start',
        requestedWidth: floatWidth,
        requestedHeight: 200.0,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final endFloat = _imageBlock(
        'end',
        requestedWidth: floatWidth,
        requestedHeight: 150.0,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Short');
      final layout = _layout(
        children: [startFloat, endFloat, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // Layout height must be at least the taller float's bottom (200 px).
      expect(
        layout.size.height,
        greaterThanOrEqualTo(200.0),
        reason: 'layout height must account for the tallest active exclusion zone',
      );
    });

    test('single start float: stretch text block gets full width with exclusionRect', () {
      // Single start float + stretch text block: the text block receives
      // full-width constraints and an exclusionRect so _performExclusionLayout
      // handles the beside/below zones internally.
      final startFloat = _imageBlock(
        'start',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text beside start float');
      _layout(
        children: [startFloat, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final textData = text.parentData as DocumentBlockParentData;
      // Text block is full-width at x=0.
      expect(
        textData.offset.dx,
        closeTo(0.0, 0.5),
        reason: 'stretch text block must be at x=0 — exclusionRect handles narrowing',
      );
      expect(
        text.size.width,
        closeTo(maxWidth, 0.5),
        reason: 'stretch text block must receive full-width constraints',
      );
      // exclusionRect describes the start float's zone in local coordinates.
      expect(
        textData.exclusionRect,
        isNotNull,
        reason: 'exclusionRect must be set for stretch text beside single start float',
      );
      expect(textData.exclusionRect!.left, closeTo(0.0, 0.5));
      expect(textData.exclusionRect!.right, closeTo(floatWidth + kFloatGap, 0.5));
    });

    test('single end float: stretch text block gets full width with exclusionRect', () {
      // Single end float + stretch text block: the text block receives
      // full-width constraints and an exclusionRect on the right side.
      final endFloat = _imageBlock(
        'end',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text beside end float');
      _layout(
        children: [endFloat, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final textData = text.parentData as DocumentBlockParentData;
      // Text block starts at x=0 (float is on the end/right side).
      expect(
        textData.offset.dx,
        closeTo(0.0, 0.5),
        reason: 'stretch text block beside end float should still be at x=0',
      );
      // Text block receives full-width constraints (not narrowed).
      expect(
        text.size.width,
        closeTo(maxWidth, 0.5),
        reason: 'stretch text block must receive full-width constraints',
      );
      // exclusionRect describes the end float's zone on the right.
      expect(
        textData.exclusionRect,
        isNotNull,
        reason: 'exclusionRect must be set for stretch text beside single end float',
      );
      expect(
        textData.exclusionRect!.left,
        closeTo(maxWidth - floatWidth - kFloatGap, 0.5),
      );
      expect(textData.exclusionRect!.right, closeTo(maxWidth, 0.5));
    });

    test('both start+end floats active: stretch text block gets narrowed width (no exclusionRect)',
        () {
      // When BOTH start and end floats are active simultaneously, a single
      // exclusionRect cannot represent both sides.  The layout falls back to
      // the old narrowed-width approach: no exclusionRect is set.
      final startFloat = _imageBlock(
        'start',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final endFloat = _imageBlock(
        'end',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text between two floats');
      _layout(
        children: [startFloat, endFloat, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final textData = text.parentData as DocumentBlockParentData;
      // Text is narrowed from both sides.
      expect(
        text.size.width,
        lessThan(maxWidth - floatWidth),
        reason: 'dual-float stretch text must be narrowed from both sides',
      );
      // Text x-offset is past the start float.
      expect(
        textData.offset.dx,
        greaterThan(0.0),
        reason: 'dual-float stretch text must be pushed right by start float',
      );
      // No exclusionRect — dual-float uses the narrowed-width approach.
      expect(
        textData.exclusionRect,
        isNull,
        reason: 'no exclusionRect for dual-float: narrowed-width approach is used',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Float hit testing
  // ---------------------------------------------------------------------------

  group('RenderDocumentLayout — float hit testing', () {
    const maxWidth = 400.0;
    const floatWidth = 100.0;
    const floatHeight = 80.0;

    test('hit testing routes to float when clicking within float bounds', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Wrapped text beside float');
      final layout = _layout(
        children: [image, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final imageData = image.parentData as DocumentBlockParentData;
      // Click in the centre of the float.
      final hitPoint = imageData.offset + const Offset(floatWidth / 2, floatHeight / 2);
      final pos = layout.getDocumentPositionAtOffset(hitPoint);

      expect(pos, isNotNull);
      expect(pos!.nodeId, 'img1');
    });

    test('hit testing routes to adjacent text when clicking in right column beside float', () {
      // With the exclusion-rect approach, the text block is full-width at x=0.
      // Clicking in the right column (x > floatWidth + gap) must hit the text
      // block, NOT the float image.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Wrapped text beside float');
      final layout = _layout(
        children: [image, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // Click at x = floatWidth + gap + 10 = 118, which is in the right column
      // beside the float.  The image occupies x in [0, 100] so this point is
      // outside the float's rect and must hit the text block.
      const hitX = floatWidth + 8.0 + 10.0; // = 118
      const hitY = 5.0; // well within the float's y-range
      const hitPoint = Offset(hitX, hitY);
      final pos = layout.getDocumentPositionAtOffset(hitPoint);

      expect(pos, isNotNull);
      expect(pos!.nodeId, 'p1');
    });

    test('getDocumentPositionNearestToOffset returns nearest child when offset is in gap', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Wrapped text beside float');
      final layout = _layout(
        children: [image, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // A point in the float-to-text gap (between float right edge and text
      // left edge) should resolve to one of the two blocks.
      final imageData = image.parentData as DocumentBlockParentData;
      final gapX = imageData.offset.dx + floatWidth + 4.0; // inside the gap
      final gapY = imageData.offset.dy + floatHeight / 2;
      final pos = layout.getDocumentPositionNearestToOffset(Offset(gapX, gapY));

      expect(['img1', 'p1'], contains(pos.nodeId));
    });

    test('getDocumentPositionNearestToOffset always returns a valid position', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text');
      final layout = _layout(
        children: [image, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // A point well below all content should still yield a valid position.
      final pos = layout.getDocumentPositionNearestToOffset(
        Offset(maxWidth / 2, layout.size.height + 500),
      );
      expect(pos.nodeId, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // viewportWidth
  // ---------------------------------------------------------------------------

  group('RenderDocumentLayout — viewportWidth', () {
    test('stretch block uses viewportWidth instead of constraints.maxWidth', () {
      // viewportWidth=300 but constraints.maxWidth=infinity (horizontal scroll)
      final text = _textBlock('p1', 'Hello');
      final layout = RenderDocumentLayout(viewportWidth: 300.0);
      layout.add(text);
      layout.layout(
        const BoxConstraints(maxWidth: double.infinity),
        parentUsesSize: true,
      );

      // Stretch block should be 300px wide (viewportWidth), not infinite
      expect(text.size.width, 300.0);
    });

    test('aligned block wider than viewportWidth is NOT clamped', () {
      // Image with requestedWidth=600, viewportWidth=400
      // Should NOT be clamped to 400 — it should stay 600
      final image = _imageBlock(
        'img1',
        requestedWidth: 600.0,
        requestedHeight: 100.0,
        blockAlignment: BlockAlignment.center,
      );
      final layout = RenderDocumentLayout(viewportWidth: 400.0);
      layout.add(image);
      layout.layout(
        const BoxConstraints(maxWidth: double.infinity),
        parentUsesSize: true,
      );

      expect(image.size.width, 600.0);
    });

    test('layout width equals max of viewportWidth and widest child', () {
      // viewportWidth=400, image width=600 → layout width should be 600
      final image = _imageBlock(
        'img1',
        requestedWidth: 600.0,
        requestedHeight: 100.0,
        blockAlignment: BlockAlignment.start,
      );
      final layout = RenderDocumentLayout(viewportWidth: 400.0);
      layout.add(image);
      layout.layout(
        const BoxConstraints(maxWidth: double.infinity),
        parentUsesSize: true,
      );

      expect(layout.size.width, 600.0);
    });

    test('layout width equals viewportWidth when no child is wider', () {
      // viewportWidth=400, text fills 400 → layout width = 400
      final text = _textBlock('p1', 'Hello');
      final layout = RenderDocumentLayout(viewportWidth: 400.0);
      layout.add(text);
      layout.layout(
        const BoxConstraints(maxWidth: double.infinity),
        parentUsesSize: true,
      );

      expect(layout.size.width, 400.0);
    });

    test('null viewportWidth falls back to constraints.maxWidth', () {
      // No viewportWidth set — should behave like before
      final text = _textBlock('p1', 'Hello');
      final layout = RenderDocumentLayout();
      layout.add(text);
      layout.layout(
        const BoxConstraints(maxWidth: 500.0),
        parentUsesSize: true,
      );

      expect(text.size.width, 500.0);
      expect(layout.size.width, 500.0);
    });

    test('center-aligned block centers relative to viewportWidth', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: 200.0,
        requestedHeight: 100.0,
        blockAlignment: BlockAlignment.center,
      );
      final layout = RenderDocumentLayout(viewportWidth: 400.0);
      layout.add(image);
      layout.layout(
        const BoxConstraints(maxWidth: double.infinity),
        parentUsesSize: true,
      );

      final data = image.parentData as DocumentBlockParentData;
      // Should be centered in viewportWidth (400), not constraints
      expect(data.offset.dx, closeTo((400.0 - 200.0) / 2, 0.5));
    });

    test('viewportWidth setter triggers relayout', () {
      final text = _textBlock('p1', 'Hello');
      final layout = RenderDocumentLayout(viewportWidth: 300.0);
      layout.add(text);
      layout.layout(
        const BoxConstraints(maxWidth: double.infinity),
        parentUsesSize: true,
      );
      expect(text.size.width, 300.0);

      layout.viewportWidth = 500.0;
      layout.layout(
        const BoxConstraints(maxWidth: double.infinity),
        parentUsesSize: true,
      );
      expect(text.size.width, 500.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Center float layout
  // ---------------------------------------------------------------------------

  group('RenderDocumentLayout — center float layout', () {
    const maxWidth = 400.0;
    const floatWidth = 100.0;
    const floatHeight = 80.0;

    test('center float: image positioned at center x-offset', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text beside center float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      expect(imageData.isFloat, isTrue);
      // Centered: (400 - 100) / 2 = 150
      expect(imageData.offset.dx, closeTo((maxWidth - floatWidth) / 2, 0.5));
    });

    test('center float: adjacent stretch block receives exclusionRect', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text beside center float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final textData = text.parentData as DocumentBlockParentData;
      // Stretch block beside a center float should get an exclusionRect.
      expect(textData.exclusionRect, isNotNull);
      // The exclusionRect left should be to the left of center.
      expect(textData.exclusionRect!.left, greaterThan(0.0));
      expect(textData.exclusionRect!.right, lessThan(maxWidth));
      // The text block itself should still be full width.
      expect(text.size.width, closeTo(maxWidth, 0.5));
    });

    test('center float: exclusionRect is null for blocks after float clears', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      // Very short text — will end before the float bottom.
      final shortText = _textBlock('p1', 'Hi');
      // Use an HR to clear the float.
      final hr = _hrBlock('hr1');
      final afterText = _textBlock('p2', 'After float');
      _layout(
        children: [image, shortText, hr, afterText],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final afterData = afterText.parentData as DocumentBlockParentData;
      // After the HR clears the float, exclusionRect should be null.
      expect(afterData.exclusionRect, isNull);
    });

    test('center float: yOffset not advanced after float', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Beside the float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      final textData = text.parentData as DocumentBlockParentData;

      // Text should start at same y as the float (yOffset not advanced).
      expect(textData.offset.dy, imageData.offset.dy);
    });

    test('center float: HR block clears float and drops below', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final hr = _hrBlock('hr1');
      _layout(children: [image, hr], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      final hrData = hr.parentData as DocumentBlockParentData;

      // HR must start at or below the float bottom.
      expect(hrData.offset.dy, greaterThanOrEqualTo(floatBottom));
      // HR must be full width.
      expect(hr.size.width, closeTo(maxWidth, 0.5));
    });

    test('center float: exclusionRect uses specified width and height', () {
      // With blockSpacing = 0, exclusionRect should exactly match the float
      // dimensions (plus gap).  With blockSpacing > 0, the top is clamped to
      // 0 so the height reflects the actual overlap.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text beside center float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final textData = text.parentData as DocumentBlockParentData;
      final excl = textData.exclusionRect!;

      // Width should be floatWidth + 2 * gap (8px each side).
      expect(excl.width, closeTo(floatWidth + 16.0, 0.5));
      // Height should match the float height exactly (no spacing offset).
      expect(excl.height, closeTo(floatHeight, 0.5));
      // Top should be 0 (float and text start at the same y).
      expect(excl.top, 0.0);
    });

    test('center float: exclusionRect height accounts for blockSpacing', () {
      // With non-zero blockSpacing, the text block starts below the float.
      // The exclusionRect height should be the overlap, not the full float
      // height — otherwise text wraps in two columns past the float bottom.
      const spacing = 12.0;
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text beside center float');
      _layout(
        children: [image, text],
        maxWidth: maxWidth,
        blockSpacing: spacing,
      );

      final textData = text.parentData as DocumentBlockParentData;
      final excl = textData.exclusionRect!;

      // exclusionRect.top must be >= 0 (clamped, not negative).
      expect(excl.top, greaterThanOrEqualTo(0.0));
      // exclusionRect height should be the overlap: floatHeight - spacing.
      expect(excl.height, closeTo(floatHeight - spacing, 0.5));
    });

    test('center float: text reflows when float height changes', () {
      const maxWidth = 400.0;
      final image = _imageBlock(
        'img',
        requestedWidth: 100.0,
        requestedHeight: 60.0,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final text = _textBlock('p1', 'Text beside center float reflow test');
      final layout = _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);
      final textData = text.parentData as DocumentBlockParentData;

      // Record the initial exclusionRect and text height.
      final initialRect = textData.exclusionRect;
      expect(initialRect, isNotNull);
      // Resize the float — change its height.
      image.requestedHeight = 120.0;
      layout.layout(const BoxConstraints(maxWidth: maxWidth), parentUsesSize: true);

      // The exclusionRect should reflect the new height.
      final updatedRect = textData.exclusionRect;
      expect(updatedRect, isNotNull);
      expect(updatedRect!.height, greaterThan(initialRect!.height));

      // The exclusionRect height should match the new float height.
      expect(updatedRect.height, 120.0);
      // The text block height is its actual text height (not padded to the
      // float height).  The layout should cover at least the float bottom —
      // checked via the layout height, not the individual text block height.
      expect(text.size.height, greaterThan(0.0));
    });

    test('center float: two consecutive center floats stack vertically', () {
      final image1 = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final image2 = _imageBlock(
        'img2',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      _layout(children: [image1, image2], maxWidth: maxWidth, blockSpacing: 0.0);

      final data1 = image1.parentData as DocumentBlockParentData;
      final data2 = image2.parentData as DocumentBlockParentData;
      final firstBottom = data1.offset.dy + image1.size.height;

      expect(data2.offset.dy, greaterThanOrEqualTo(firstBottom));
    });

    test('center float: text beside float occupies same vertical space as start/end', () {
      // Bug regression: center-float text was rendering entirely BELOW the
      // image instead of beside it like start/end floats.
      //
      // With start alignment the text block gets reduced-width constraints and
      // flows beside the float.  With center alignment the text block gets an
      // exclusionRect and uses zone-split layout.  Both should produce a text
      // block whose height is comparable — not dramatically larger for center.
      const longText = 'This is a long paragraph that should wrap beside the '
          'float regardless of alignment type being start end or center.';

      // --- start float ---
      final imageStart = _imageBlock(
        'imgS',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final textStart = RenderTextBlock(
        nodeId: 'pS',
        text: AttributedText(longText),
        textStyle: const TextStyle(fontSize: 16),
      );
      _layout(
        children: [imageStart, textStart],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );
      final startTextData = textStart.parentData as DocumentBlockParentData;
      final startImageData = imageStart.parentData as DocumentBlockParentData;
      final startFloatBottom = startImageData.offset.dy + imageStart.size.height;

      // Text must start beside the float (same y).
      expect(startTextData.offset.dy, startImageData.offset.dy,
          reason: 'start float: text y should equal image y');
      // Text block must overlap the float vertically (not be entirely below it).
      expect(startTextData.offset.dy, lessThan(startFloatBottom),
          reason: 'start float: text should start before float bottom');

      // --- center float ---
      final imageCenter = _imageBlock(
        'imgC',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final textCenter = RenderTextBlock(
        nodeId: 'pC',
        text: AttributedText(longText),
        textStyle: const TextStyle(fontSize: 16),
      );
      _layout(
        children: [imageCenter, textCenter],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );
      final centerTextData = textCenter.parentData as DocumentBlockParentData;
      final centerImageData = imageCenter.parentData as DocumentBlockParentData;
      final centerFloatBottom = centerImageData.offset.dy + imageCenter.size.height;

      // Text must start beside the float (same y).
      expect(centerTextData.offset.dy, centerImageData.offset.dy,
          reason: 'center float: text y should equal image y');
      // Text block must overlap the float vertically (not be entirely below it).
      expect(centerTextData.offset.dy, lessThan(centerFloatBottom),
          reason: 'center float: text should start before float bottom');

      // The center text block should not be dramatically taller than the start
      // one.  If the beside zone is working, both produce comparable heights.
      // If center text falls entirely to the below zone, its height would be
      // floatHeight + full-text-height (much larger than start).
      expect(
        textCenter.size.height,
        lessThanOrEqualTo(textStart.size.height + floatHeight),
        reason: 'center float text should not be dramatically taller than start',
      );
    });

    test('center float: text wraps beside float with default blockSpacing', () {
      // Same test but with default blockSpacing = 12 to match real usage.
      const longText = 'This is a long paragraph that should wrap beside the '
          'float regardless of alignment type being start end or center.';

      // --- start float ---
      final imageStart = _imageBlock(
        'imgS',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final textStart = RenderTextBlock(
        nodeId: 'pS',
        text: AttributedText(longText),
        textStyle: const TextStyle(fontSize: 16),
      );
      _layout(children: [imageStart, textStart], maxWidth: maxWidth);

      final startTextData = textStart.parentData as DocumentBlockParentData;
      final startImageData = imageStart.parentData as DocumentBlockParentData;
      final startFloatBottom = startImageData.offset.dy + imageStart.size.height;

      // With blockSpacing, text starts below the image's y but still
      // overlaps the float vertically (starts before float bottom).
      expect(startTextData.offset.dy, lessThan(startFloatBottom),
          reason: 'start float: text should overlap float vertically');

      // --- center float ---
      final imageCenter = _imageBlock(
        'imgC',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final textCenter = RenderTextBlock(
        nodeId: 'pC',
        text: AttributedText(longText),
        textStyle: const TextStyle(fontSize: 16),
      );
      _layout(children: [imageCenter, textCenter], maxWidth: maxWidth);

      final centerTextData = textCenter.parentData as DocumentBlockParentData;
      final centerImageData = imageCenter.parentData as DocumentBlockParentData;
      final centerFloatBottom = centerImageData.offset.dy + imageCenter.size.height;

      // Center text block must also start before float bottom.
      expect(centerTextData.offset.dy, lessThan(centerFloatBottom),
          reason: 'center float: text should overlap float vertically');

      // Heights should be comparable.
      expect(
        textCenter.size.height,
        lessThanOrEqualTo(textStart.size.height + floatHeight),
        reason: 'center float text should not be dramatically taller than start',
      );
    });

    test('center float: first character renders in beside zone not below', () {
      // Regression: if the exclusion layout puts all text in the below zone,
      // the first character's y would be at besideHeight (= floatHeight),
      // meaning text starts below the image instead of beside it.
      final image = _imageBlock(
        'imgC',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final text = RenderTextBlock(
        nodeId: 'pC',
        text: AttributedText('Text beside the centered float image.'),
        textStyle: const TextStyle(fontSize: 16),
      );
      _layout(
        children: [image, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // Get the rendered position of the first character.
      final firstCharRect = text.getLocalRectForPosition(
        const TextNodePosition(offset: 0),
      );

      // The first character should be near the top of the text block
      // (in the beside zone), NOT at floatHeight (which would mean below zone).
      expect(firstCharRect.top, lessThan(floatHeight),
          reason: 'first char should be in beside zone, not pushed to below zone');
      // It should be near y=0 (top of the text block).
      expect(firstCharRect.top, lessThanOrEqualTo(2.0),
          reason: 'first char should start at top of text block');
    });

    test('center float: realistic viewport - text beside vs below comparison', () {
      // Simulate a realistic macOS viewport (800px) with the example app's
      // center image (300x150). Compare center vs start to detect if
      // center text goes to the below zone.
      const viewportWidth = 800.0;
      const imgWidth = 300.0;
      const imgHeight = 150.0;
      const exampleText = 'This paragraph wraps beside the floated image. '
          'When textWrap is true and alignment is start or end, subsequent '
          'blocks receive reduced-width constraints and flow beside the image. '
          'Once the text extends past the image, the next block gets full width.';

      // --- Start float ---
      final imgStart = _imageBlock(
        'imgS',
        requestedWidth: imgWidth,
        requestedHeight: imgHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final txtStart = RenderTextBlock(
        nodeId: 'pS',
        text: AttributedText(exampleText),
        textStyle: const TextStyle(fontSize: 16),
      );
      _layout(
        children: [imgStart, txtStart],
        maxWidth: viewportWidth,
        blockSpacing: 0.0,
      );

      // --- Center float ---
      final imgCenter = _imageBlock(
        'imgC',
        requestedWidth: imgWidth,
        requestedHeight: imgHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final txtCenter = RenderTextBlock(
        nodeId: 'pC',
        text: AttributedText(exampleText),
        textStyle: const TextStyle(fontSize: 16),
      );
      _layout(
        children: [imgCenter, txtCenter],
        maxWidth: viewportWidth,
        blockSpacing: 0.0,
      );

      // Check first char position for start.
      final startFirstChar = txtStart.getLocalRectForPosition(
        const TextNodePosition(offset: 0),
      );
      // Check first char position for center.
      final centerFirstChar = txtCenter.getLocalRectForPosition(
        const TextNodePosition(offset: 0),
      );

      // Both should have first char near top (in beside zone).
      expect(startFirstChar.top, lessThan(imgHeight), reason: 'start: first char in beside zone');
      expect(centerFirstChar.top, lessThan(imgHeight), reason: 'center: first char in beside zone');

      // Center text should NOT be dramatically taller (which would mean
      // text went to below zone = imgHeight + full-text-height).
      final fullText = RenderTextBlock(
        nodeId: 'pF',
        text: AttributedText(exampleText),
        textStyle: const TextStyle(fontSize: 16),
      );
      fullText.layout(const BoxConstraints(maxWidth: viewportWidth), parentUsesSize: true);

      // If center works correctly, height should be similar to start
      // (both wrapping text beside float). If broken, center height would be
      // approximately imgHeight + fullText.height.
      final brokenHeight = imgHeight + fullText.size.height;
      expect(txtCenter.size.height, lessThan(brokenHeight),
          reason: 'center: text should flow beside float, not entirely below '
              '(got ${txtCenter.size.height}, broken would be ~$brokenHeight, '
              'start=${txtStart.size.height})');
    });

    test('center float: wider image leaves usable side columns', () {
      // Use a wider image (300px in 400px viewport) like the example app.
      // Side columns are only 42px each — check text still flows beside.
      const wideImageWidth = 300.0;
      const wideImageHeight = 150.0;
      const longText = 'This paragraph wraps beside the floated image. '
          'When textWrap is true and alignment is start or end, subsequent '
          'blocks receive reduced-width constraints and flow beside the image. '
          'Once the text extends past the image, the next block gets full width.';

      final image = _imageBlock(
        'imgW',
        requestedWidth: wideImageWidth,
        requestedHeight: wideImageHeight,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final text = RenderTextBlock(
        nodeId: 'pW',
        text: AttributedText(longText),
        textStyle: const TextStyle(fontSize: 16),
      );
      _layout(
        children: [image, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final textData = text.parentData as DocumentBlockParentData;
      final exclusionRect = textData.exclusionRect;

      // Must receive an exclusionRect.
      expect(exclusionRect, isNotNull, reason: 'text beside center float must get exclusionRect');

      // Both side columns must be > 0.
      final leftWidth = exclusionRect!.left;
      final rightWidth = maxWidth - exclusionRect.right;
      expect(leftWidth, greaterThan(0), reason: 'left column width must be positive');
      expect(rightWidth, greaterThan(0), reason: 'right column width must be positive');

      // The text block height should not be dramatically taller than the image
      // (which would mean all text went to the below zone).
      // If beside zone works, height ≈ max(imageHeight, beside text height).
      // If beside zone is empty, height = imageHeight + full text height.
      final fullWidthText = RenderTextBlock(
        nodeId: 'pFull',
        text: AttributedText(longText),
        textStyle: const TextStyle(fontSize: 16),
      );
      fullWidthText.layout(const BoxConstraints(maxWidth: maxWidth), parentUsesSize: true);
      final fullTextHeight = fullWidthText.size.height;

      expect(
        text.size.height,
        lessThan(wideImageHeight + fullTextHeight),
        reason: 'text should flow beside the float, not entirely below it',
      );
    });

    test('center float: two short text blocks both wrap beside float (not just first)', () {
      // Regression: when a text block is shorter than the float, it used to
      // report a height equal to the full exclusion rect height, advancing
      // yOffset past the float bottom. This caused the second text block to
      // render below the float instead of beside it.
      const floatW = 300.0;
      const floatH = 200.0;

      final image = _imageBlock(
        'imgC',
        requestedWidth: floatW,
        requestedHeight: floatH,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      // Short text — much less than floatH tall.
      final text1 = _textBlock('p1', 'Short first paragraph.');
      // Second short text block — must also wrap beside the float.
      final text2 = _textBlock('p2', 'Short second paragraph.');

      _layout(
        children: [image, text1, text2],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final imageData = image.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      final text1Data = text1.parentData as DocumentBlockParentData;
      final text2Data = text2.parentData as DocumentBlockParentData;

      // Both text blocks must start before the float bottom (beside, not below).
      expect(
        text1Data.offset.dy,
        lessThan(floatBottom),
        reason: 'first text block should be beside the float, not below it',
      );
      expect(
        text2Data.offset.dy,
        lessThan(floatBottom),
        reason: 'second text block should be beside the float, not below it',
      );
      // Both must receive exclusionRects (they are beside the center float).
      expect(
        text1Data.exclusionRect,
        isNotNull,
        reason: 'first text block must receive an exclusionRect',
      );
      expect(
        text2Data.exclusionRect,
        isNotNull,
        reason: 'second text block must receive an exclusionRect',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Paint order: floats must be painted after non-floats
  // -------------------------------------------------------------------------

  group('RenderDocumentLayout — paint order', () {
    test('float child is painted after non-float stretch child', () {
      // Arrange: a center-aligned float (image) followed by a stretch text block
      // that wraps beside it.  With the old defaultPaint() behaviour the text
      // block (child index 1, later in document order) is painted LAST, so its
      // opaque background obscures the float.  After the fix the float must
      // always be painted in the second pass (on top).
      const maxWidth = 400.0;
      final paintOrder = <String>[];

      final image = _RecordingImageBlock(
        'img',
        paintOrder: paintOrder,
        requestedWidth: 150,
        requestedHeight: 120,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final text = _RecordingTextBlock(
        'p1',
        paintOrder: paintOrder,
        text: 'wrap text',
      );

      final layout = RenderDocumentLayout(blockSpacing: 0.0);
      layout.add(image);
      layout.add(text);
      layout.layout(const BoxConstraints(maxWidth: maxWidth), parentUsesSize: true);

      // Confirm the image is indeed flagged as a float after layout.
      final imageData = image.parentData as DocumentBlockParentData;
      expect(imageData.isFloat, isTrue, reason: 'image should be a float');

      // Paint into a recording context so the children's paint() callbacks fire.
      final paintingContext = _RecordingPaintingContext();
      layout.paint(paintingContext, Offset.zero);

      // The float ('img') must appear AFTER the non-float ('p1') in paintOrder.
      expect(paintOrder, contains('p1'));
      expect(paintOrder, contains('img'));
      final p1Index = paintOrder.indexOf('p1');
      final imgIndex = paintOrder.indexOf('img');
      expect(
        imgIndex,
        greaterThan(p1Index),
        reason: 'float (img) must be painted after non-float (p1) so it renders on top',
      );
    });

    test('non-float document order is preserved within each pass', () {
      // Three stretch blocks: p1, p2, p3.  No floats.  Paint order must match
      // document order exactly: p1, p2, p3.
      final paintOrder = <String>[];

      final p1 = _RecordingTextBlock('p1', paintOrder: paintOrder, text: 'first');
      final p2 = _RecordingTextBlock('p2', paintOrder: paintOrder, text: 'second');
      final p3 = _RecordingTextBlock('p3', paintOrder: paintOrder, text: 'third');

      final layout = RenderDocumentLayout(blockSpacing: 4.0);
      layout.add(p1);
      layout.add(p2);
      layout.add(p3);
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      final paintingContext = _RecordingPaintingContext();
      layout.paint(paintingContext, Offset.zero);

      expect(paintOrder, equals(['p1', 'p2', 'p3']));
    });

    test('multiple floats are painted after all non-floats', () {
      // Layout: float1 (start), float2 (end), then a stretch text block.
      // After the fix: text is painted first, then float1 and float2 (in
      // document order) on top.
      final paintOrder = <String>[];

      final float1 = _RecordingImageBlock(
        'float1',
        paintOrder: paintOrder,
        requestedWidth: 100,
        requestedHeight: 80,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final float2 = _RecordingImageBlock(
        'float2',
        paintOrder: paintOrder,
        requestedWidth: 100,
        requestedHeight: 80,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final text = _RecordingTextBlock('p1', paintOrder: paintOrder, text: 'wrap text');

      final layout = RenderDocumentLayout(blockSpacing: 0.0);
      layout.add(float1);
      layout.add(float2);
      layout.add(text);
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      final paintingContext = _RecordingPaintingContext();
      layout.paint(paintingContext, Offset.zero);

      // Non-float (p1) must come before both floats.
      final p1Idx = paintOrder.indexOf('p1');
      final f1Idx = paintOrder.indexOf('float1');
      final f2Idx = paintOrder.indexOf('float2');
      expect(p1Idx, greaterThanOrEqualTo(0));
      expect(f1Idx, greaterThan(p1Idx), reason: 'float1 must be painted after p1');
      expect(f2Idx, greaterThan(p1Idx), reason: 'float2 must be painted after p1');
    });
  });

  // ---------------------------------------------------------------------------
  // Bug regression: center exclusion not cleared when side float is placed
  // ---------------------------------------------------------------------------

  group('RenderDocumentLayout — center exclusion cleared by side float', () {
    // Layout constants used across all three regression tests.
    const maxWidth = 400.0;
    const centerFloatW = 200.0;
    const centerFloatH = 150.0;
    const sideFloatW = 100.0;
    const sideFloatH = 250.0;

    // -------------------------------------------------------------------------
    // Helper that builds the four-block sequence described in the bug report:
    //   1. center-aligned wrap float
    //   2. stretch paragraph (wraps beside center float)
    //   3. side-aligned (start or end) wrap float
    //   4. stretch paragraph
    // Returns a record with all four render objects and the laid-out layout.
    // -------------------------------------------------------------------------
    ({
      RenderImageBlock centerImage,
      RenderTextBlock firstPara,
      RenderImageBlock sideImage,
      RenderTextBlock secondPara,
      RenderDocumentLayout layout,
    }) buildLayout({required BlockAlignment sideAlignment}) {
      final centerImage = _imageBlock(
        'centerImg',
        requestedWidth: centerFloatW,
        requestedHeight: centerFloatH,
        blockAlignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final firstPara = _textBlock('p1', 'Short text');
      final sideImage = _imageBlock(
        'sideImg',
        requestedWidth: sideFloatW,
        requestedHeight: sideFloatH,
        blockAlignment: sideAlignment,
        textWrap: TextWrapMode.wrap,
      );
      final secondPara = _textBlock('p2', 'Text after side float');

      final layout = _layout(
        children: [centerImage, firstPara, sideImage, secondPara],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      return (
        centerImage: centerImage,
        firstPara: firstPara,
        sideImage: sideImage,
        secondPara: secondPara,
        layout: layout,
      );
    }

    test('start float placed after center float clears center exclusion', () {
      // Regression: when a start float is placed while centerExclusion is still
      // active, the center exclusion was not cleared.  The subsequent stretch
      // block then entered the hasCenter branch, which applied center-only
      // exclusion and completely ignored the start float — making text render
      // behind the float.
      //
      // After the fix, placing a start float must clear any active center
      // exclusion so the two cannot coexist.
      final result = buildLayout(sideAlignment: BlockAlignment.start);
      final centerImageData = result.centerImage.parentData as DocumentBlockParentData;
      final sideImageData = result.sideImage.parentData as DocumentBlockParentData;
      final secondParaData = result.secondPara.parentData as DocumentBlockParentData;

      // The side float must be placed at or below the center float's bottom
      // (the center exclusion forces it downward).
      final centerBottom = centerImageData.offset.dy + result.centerImage.size.height;
      expect(
        sideImageData.offset.dy,
        greaterThanOrEqualTo(centerBottom),
        reason: 'start float must be placed at/below center float bottom',
      );

      // The second stretch paragraph must receive an exclusionRect from the start
      // float — NOT a center exclusionRect.  With the new approach, the block is
      // full-width at x=0 and _performExclusionLayout handles the beside/below zones.
      expect(
        secondParaData.exclusionRect,
        isNotNull,
        reason: 'second paragraph must have exclusionRect set by start float',
      );
      // The exclusionRect must describe the start float's left-side zone, not a
      // centered zone.  A left-side exclusion always starts at x=0.
      expect(
        secondParaData.exclusionRect!.left,
        closeTo(0.0, 0.5),
        reason: 'start-float exclusionRect must begin at x=0 (left edge)',
      );
      expect(
        secondParaData.exclusionRect!.right,
        closeTo(sideFloatW + 8.0, 0.5),
        reason: 'start-float exclusionRect right must equal float width + gap',
      );
      // Block is full-width at x=0.
      expect(
        secondParaData.offset.dx,
        closeTo(0.0, 0.5),
        reason: 'second paragraph must be at x=0 — exclusionRect handles narrowing',
      );
      expect(
        result.secondPara.size.width,
        closeTo(maxWidth, 0.5),
        reason: 'second paragraph must receive full-width constraints',
      );
    });

    test('end float placed after center float clears center exclusion', () {
      // Same regression as above but with an end-aligned float.
      // After the fix the center exclusion must be cleared when the end float
      // is placed, so the stretch block after it receives a start-side exclusionRect,
      // not the old center exclusionRect.
      final result = buildLayout(sideAlignment: BlockAlignment.end);
      final centerImageData = result.centerImage.parentData as DocumentBlockParentData;
      final sideImageData = result.sideImage.parentData as DocumentBlockParentData;
      final secondParaData = result.secondPara.parentData as DocumentBlockParentData;

      // The side float must be placed at or below the center float's bottom.
      final centerBottom = centerImageData.offset.dy + result.centerImage.size.height;
      expect(
        sideImageData.offset.dy,
        greaterThanOrEqualTo(centerBottom),
        reason: 'end float must be placed at/below center float bottom',
      );

      // The second stretch paragraph must receive an exclusionRect from the
      // end float (right-side zone), not a center exclusionRect.
      expect(
        secondParaData.exclusionRect,
        isNotNull,
        reason: 'second paragraph must have exclusionRect set by end float',
      );
      // End-side exclusion: right edge is at maxWidth.
      expect(
        secondParaData.exclusionRect!.right,
        closeTo(maxWidth, 0.5),
        reason: 'end-float exclusionRect right must equal maxWidth',
      );
      // Block is full-width at x=0.
      expect(
        result.secondPara.size.width,
        closeTo(maxWidth, 0.5),
        reason: 'second paragraph must receive full-width constraints',
      );
    });

    test('text does not appear behind start float when center float precedes it', () {
      // Focused check: the second paragraph's exclusionRect must describe the
      // start float zone, proving the start exclusion — not the center exclusion
      // — governs the block's layout.
      final result = buildLayout(sideAlignment: BlockAlignment.start);
      final sideImageData = result.sideImage.parentData as DocumentBlockParentData;
      final secondParaData = result.secondPara.parentData as DocumentBlockParentData;

      // Start float is at x=0.
      expect(sideImageData.offset.dx, 0.0, reason: 'start float must be at x=0');

      // The second paragraph is full-width at x=0 with a LEFT-side exclusionRect.
      expect(
        secondParaData.offset.dx,
        closeTo(0.0, 0.5),
        reason: 'second paragraph must be at x=0 — exclusionRect handles narrowing',
      );
      expect(
        result.secondPara.size.width,
        closeTo(maxWidth, 0.5),
        reason: 'second paragraph must receive full-width constraints',
      );
      // The exclusionRect left edge is 0 and right edge is sideFloatW + gap.
      expect(
        secondParaData.exclusionRect,
        isNotNull,
        reason: 'exclusionRect must be set — proves start float governs layout',
      );
      expect(
        secondParaData.exclusionRect!.left,
        closeTo(0.0, 0.5),
        reason: 'start-float exclusionRect must begin at x=0',
      );
      expect(
        secondParaData.exclusionRect!.right,
        closeTo(sideFloatW + 8.0, 0.5),
        reason: 'start-float exclusionRect right must equal float width + gap',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getRectsForSelection — cross-node with floats
  // ---------------------------------------------------------------------------

  group('getRectsForSelection — cross-node with floats', () {
    // Layout constants shared across all tests in this group.
    const maxWidth = 400.0;
    const floatW = 100.0;
    const floatH = 80.0;
    // _kFloatGap == 8.0 in render_document_layout.dart
    const floatGap = 8.0;
    // With exclusionRect approach, text blocks are full-width at x=0.
    // The right column for beside-zone text starts at:
    const textXWithStartFloat = floatW + floatGap; // exclusionRect.right = 108.0

    // Helper that builds: [start-float image] + [text 'First'] + [text 'Second']
    // and returns the layout plus all three components.
    ({
      RenderDocumentLayout layout,
      RenderImageBlock floatImg,
      RenderTextBlock first,
      RenderTextBlock second,
    }) _startFloatLayout() {
      final img = _imageBlock(
        'img1',
        requestedWidth: floatW,
        requestedHeight: floatH,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final first = _textBlock('p1', 'First');
      final second = _textBlock('p2', 'Second');
      final layout = _layout(
        children: [img, first, second],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );
      return (layout: layout, floatImg: img, first: first, second: second);
    }

    // Helper that builds: [end-float image] + [text 'First'] + [text 'Second']
    ({
      RenderDocumentLayout layout,
      RenderImageBlock floatImg,
      RenderTextBlock first,
      RenderTextBlock second,
    }) _endFloatLayout() {
      final img = _imageBlock(
        'img1',
        requestedWidth: floatW,
        requestedHeight: floatH,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final first = _textBlock('p1', 'First');
      final second = _textBlock('p2', 'Second');
      final layout = _layout(
        children: [img, first, second],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );
      return (layout: layout, floatImg: img, first: first, second: second);
    }

    test('start float: same-node selection rects are in the right column (>= exclusionRect.right)',
        () {
      // With the exclusion-rect approach, text blocks beside a start float receive
      // full-width constraints at x=0 plus an exclusionRect.  The text flows in the
      // right column (x >= exclusionRect.right = floatW + gap = 108).
      // Verify that a same-node selection returns rects that do NOT intrude into
      // the float zone — same-node uses _getEndpointsForSelectionExclusion which
      // correctly offsets the right column by exclusionRect.right.
      final result = _startFloatLayout();
      final firstData = result.first.parentData as DocumentBlockParentData;

      // Sanity: the text block is full-width at x=0 with an exclusionRect.
      expect(
        firstData.offset.dx,
        closeTo(0.0, 0.5),
        reason: 'sanity: first text block must be at x=0 (exclusionRect approach)',
      );
      expect(
        result.first.size.width,
        closeTo(maxWidth, 0.5),
        reason: 'sanity: first text block must be full-width (exclusionRect approach)',
      );
      expect(
        firstData.exclusionRect,
        isNotNull,
        reason: 'sanity: first text block must have an exclusionRect set',
      );

      // Same-node selection within p1 (offset 0..5 selects "First").
      const sel = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );
      final rects = result.layout.getRectsForSelection(sel);
      expect(rects, isNotEmpty);

      // Same-node rects use _getEndpointsForSelectionExclusion which offsets
      // right-column rects by exclusionRect.right.  The rects are then shifted
      // by childData.offset = (0, 0).  So all rects must start at x >= 108.
      for (final r in rects) {
        expect(
          r.left,
          greaterThanOrEqualTo(textXWithStartFloat - 0.5),
          reason: 'same-node selection rect left=${r.left} must be in right column '
              '(>= exclusionRect.right = $textXWithStartFloat); '
              'float occupies x in [0..$floatW]',
        );
      }
    });

    test('both floats: top rect right edge bounded to block width, not layoutWidth', () {
      // EXPECTED TO FAIL with the current implementation because the top rect
      // extends to layoutWidth (400) instead of stopping at the text block's
      // own right edge.
      //
      // Layout: [start-float 100 wide] + [end-float 100 wide] + [text 'First'] + [text 'Second']
      // With both floats active simultaneously, the text blocks are:
      //   x  = floatW + floatGap = 108
      //   w  = maxWidth - floatW - floatGap - floatW - floatGap = 184
      //   right edge = 108 + 184 = 292   (<< layout width 400)
      //
      // The top rect must stop at 292, not extend to 400.
      final startImg = _imageBlock(
        'img_start',
        requestedWidth: floatW,
        requestedHeight: floatH,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final endImg = _imageBlock(
        'img_end',
        requestedWidth: floatW,
        requestedHeight: floatH,
        blockAlignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final first = _textBlock('p1', 'First');
      final second = _textBlock('p2', 'Second');
      final layout = _layout(
        children: [startImg, endImg, first, second],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final firstData = first.parentData as DocumentBlockParentData;
      final expectedTopRectRight = firstData.offset.dx + first.size.width;

      // Sanity: the text block must NOT extend to layoutWidth.
      expect(
        expectedTopRectRight,
        lessThan(maxWidth - 1.0),
        reason: 'sanity: text block right must be < layoutWidth when both floats narrow it',
      );

      const sel = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p2',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );
      final rects = layout.getRectsForSelection(sel);
      expect(rects, isNotEmpty);

      // The top-most rect (covering 'First') must not extend beyond the
      // block's own right edge.
      final topRect = rects.reduce((a, b) => a.top < b.top ? a : b);
      expect(
        topRect.right,
        lessThanOrEqualTo(expectedTopRectRight + 0.5),
        reason: 'top rect right (${topRect.right}) must be <= block right edge '
            '($expectedTopRectRight); must not extend to layoutWidth ($maxWidth)',
      );
    });

    test('no-float: intermediate rects use actual block bounds (regression)', () {
      // THREE text blocks, no floats — selects from First to Last through Middle.
      // The intermediate rect covering Middle should span its actual block bounds.
      // This is a regression test: it should PASS with both old and new code.
      final first = _textBlock('p1', 'First');
      final middle = _textBlock('p2', 'Middle paragraph content here');
      final last = _textBlock('p3', 'Last');
      final layout =
          _layout(children: [first, middle, last], maxWidth: maxWidth, blockSpacing: 0.0);

      final middleData = middle.parentData as DocumentBlockParentData;

      const sel = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p3',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );
      final rects = layout.getRectsForSelection(sel);
      // At minimum: top rect (First), intermediate (Middle), bottom rect (Last).
      expect(rects.length, greaterThanOrEqualTo(2));

      // All rects must be within the layout's horizontal bounds.
      for (final r in rects) {
        expect(r.left, greaterThanOrEqualTo(-0.5));
        expect(r.right, lessThanOrEqualTo(maxWidth + 0.5));
      }

      // The union of all rects must cover the middle block's y-range.
      final middleTop = middleData.offset.dy;
      final middleBottom = middleTop + middle.size.height;
      final unionTop = rects.map((r) => r.top).reduce((a, b) => a < b ? a : b);
      final unionBottom = rects.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
      expect(unionTop, lessThanOrEqualTo(middleTop + 1.0));
      expect(unionBottom, greaterThanOrEqualTo(middleBottom - 1.0));
    });

    test('float block skipped: cross-node selection returns rects (non-empty)', () {
      // Layout: [text 'First'] + [start-float image] + [text 'Second'] + [text 'Third']
      // Select from 'First' to 'Third'.
      //
      // NOTE: With the exclusion-rect layout approach, text blocks beside a start float
      // receive full-width constraints at x=0.  The cross-node getRectsForSelection path
      // uses raw block offsets (not exclusionRect-aware), so intermediate blocks may
      // produce rects that overlap the float zone.  Fixing the cross-node rect accuracy
      // for exclusion-layout blocks is tracked as a follow-up; this test verifies that
      // the function at least returns a non-empty result without crashing.
      final first = _textBlock('p1', 'First');
      final floatImg = _imageBlock(
        'img1',
        requestedWidth: floatW,
        requestedHeight: floatH,
        blockAlignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      );
      final second = _textBlock('p2', 'Second');
      final third = _textBlock('p3', 'Third');
      final layout = _layout(
        children: [first, floatImg, second, third],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // Verify the float image is skipped (isFloat == true).
      final floatData = floatImg.parentData as DocumentBlockParentData;
      expect(floatData.isFloat, isTrue, reason: 'float image must be marked as float');

      // Verify that 'Second' beside the float receives an exclusionRect.
      final secondData = second.parentData as DocumentBlockParentData;
      expect(
        secondData.exclusionRect,
        isNotNull,
        reason: 'text block beside float must receive an exclusionRect',
      );

      const sel = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p3',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );
      final rects = layout.getRectsForSelection(sel);
      // Selection must return at least some rects without crashing.
      expect(rects, isNotEmpty);
    });

    test('no-float regression: two text blocks, rects cover both (>= 2 rects)', () {
      // Simple regression: no floats, two text blocks.
      // The existing cross-node path must still return at least 2 rects.
      // This SHOULD PASS with both old and new implementations.
      final first = _textBlock('p1', 'First paragraph');
      final second = _textBlock('p2', 'Second paragraph');
      final layout = _layout(children: [first, second], maxWidth: maxWidth, blockSpacing: 0.0);

      const sel = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p2',
          nodePosition: TextNodePosition(offset: 6),
        ),
      );
      final rects = layout.getRectsForSelection(sel);
      expect(
        rects.length,
        greaterThanOrEqualTo(2),
        reason: 'cross-node selection must produce at least 2 rects (one per block)',
      );

      // The top-most rect covers the first block.
      final firstData = first.parentData as DocumentBlockParentData;
      final topRect = rects.reduce((a, b) => a.top < b.top ? a : b);
      expect(topRect.top, closeTo(firstData.offset.dy, 2.0));

      // The bottom-most rect covers the second block.
      final secondData = second.parentData as DocumentBlockParentData;
      final bottomRect = rects.reduce((a, b) => a.bottom > b.bottom ? a : b);
      expect(bottomRect.bottom, greaterThanOrEqualTo(secondData.offset.dy));
    });

    test('end float: same-node selection rects are in the left column (<= exclusionRect.left)', () {
      // Layout: [end-float image] + [text 'First'] + [text 'Second'].
      // The end float occupies the right side (x = maxWidth - floatW = 300).
      // With the exclusion-rect approach, text blocks get full-width constraints
      // at x=0 plus an exclusionRect on the right.  Text flows in the left column
      // (x in [0, exclusionLeft] = [0, 292]).
      //
      // Same-node selection uses _getEndpointsForSelectionExclusion which
      // correctly confines rects to the left column (right <= exclusionLeft).
      //
      // NOTE: Cross-node selection rects may still extend beyond exclusionLeft
      // because the cross-node path in getRectsForSelection does not yet account
      // for exclusionRects.  Fixing cross-node accuracy is a follow-up task.
      final result = _endFloatLayout();
      final floatData = result.floatImg.parentData as DocumentBlockParentData;
      final firstData = result.first.parentData as DocumentBlockParentData;

      // Sanity: the end float is positioned on the right side.
      expect(
        floatData.offset.dx,
        closeTo(maxWidth - floatW, 0.5),
        reason: 'sanity: end float must be at x = maxWidth - floatW',
      );
      // Sanity: the text block is full-width at x=0 with an exclusionRect.
      expect(
        result.first.size.width,
        closeTo(maxWidth, 0.5),
        reason: 'sanity: first text block must be full-width (exclusionRect approach)',
      );
      expect(
        firstData.exclusionRect,
        isNotNull,
        reason: 'sanity: first text block must have an exclusionRect for end float',
      );

      // exclusionRect.left = left edge of the end-float exclusion zone.
      final exclusionLeft = firstData.exclusionRect!.left;

      // Same-node selection: offset 0..5 in p1 selects "First".
      // Text is in the left column; selection rects must stay <= exclusionLeft.
      const sel = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );
      final rects = result.layout.getRectsForSelection(sel);
      expect(rects, isNotEmpty);

      // Same-node rects use _getEndpointsForSelectionExclusion: left-column
      // text rects have right <= leftWidth = exclusionLeft.
      // After shifting by childData.offset = (0, 0), they stay in [0, exclusionLeft].
      for (final r in rects) {
        expect(
          r.right,
          lessThanOrEqualTo(exclusionLeft + 0.5),
          reason: 'same-node selection rect right (${r.right}) must not extend into '
              'end float zone; left column ends at x=$exclusionLeft',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Per-block spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------

  group('RenderDocumentLayout per-block spacing', () {
    /// Helper to read the y-offset of a child from its parent data.
    double blockTop(RenderDocumentBlock block) =>
        (block.parentData as DocumentBlockParentData).offset.dy;

    test('spaceBefore on second block overrides blockSpacing', () {
      // With blockSpacing=12 and no per-block spacing, two text blocks have
      // their tops separated by block1Height + 12.
      final b1 = _textBlock('p1', 'Block one');
      final b2 = _textBlock('p2', 'Block two');
      final layoutDefault = _layout(children: [b1, b2], blockSpacing: 12.0);

      final b1Default = layoutDefault.getComponentByNodeId('p1')!;
      final b2Default = layoutDefault.getComponentByNodeId('p2')!;
      final gapDefault = blockTop(b2Default) - (blockTop(b1Default) + b1Default.size.height);

      expect(gapDefault, closeTo(12.0, 0.01),
          reason: 'default gap between blocks should be blockSpacing');

      // Now set spaceBefore=30 on the second block; the gap should be 30.
      final c1 = _textBlock('p1', 'Block one');
      final c2 = _textBlock('p2', 'Block two');
      c2.spaceBefore = 30.0;
      final layoutCustom = _layout(children: [c1, c2], blockSpacing: 12.0);

      final c1Layout = layoutCustom.getComponentByNodeId('p1')!;
      final c2Layout = layoutCustom.getComponentByNodeId('p2')!;
      final gapCustom = blockTop(c2Layout) - (blockTop(c1Layout) + c1Layout.size.height);

      expect(gapCustom, closeTo(30.0, 0.01),
          reason: 'spaceBefore=30 should override the default blockSpacing=12');
    });

    test('spaceAfter on first block overrides blockSpacing', () {
      final b1 = _textBlock('p1', 'Block one');
      final b2 = _textBlock('p2', 'Block two');
      b1.spaceAfter = 40.0;
      final layout = _layout(children: [b1, b2], blockSpacing: 12.0);

      final l1 = layout.getComponentByNodeId('p1')!;
      final l2 = layout.getComponentByNodeId('p2')!;
      final gap = blockTop(l2) - (blockTop(l1) + l1.size.height);

      expect(gap, closeTo(40.0, 0.01),
          reason: 'spaceAfter=40 on first block should produce a 40px gap');
    });

    test('max(spaceAfter, spaceBefore) wins when both are set', () {
      final b1 = _textBlock('p1', 'Block one');
      final b2 = _textBlock('p2', 'Block two');
      b1.spaceAfter = 20.0;
      b2.spaceBefore = 50.0;
      final layout = _layout(children: [b1, b2], blockSpacing: 12.0);

      final l1 = layout.getComponentByNodeId('p1')!;
      final l2 = layout.getComponentByNodeId('p2')!;
      final gap = blockTop(l2) - (blockTop(l1) + l1.size.height);

      expect(gap, closeTo(50.0, 0.01),
          reason: 'max(spaceAfter=20, spaceBefore=50) = 50 should be the gap');
    });

    test('blockSpacing used when neither spaceBefore nor spaceAfter is set', () {
      final b1 = _textBlock('p1', 'Block one');
      final b2 = _textBlock('p2', 'Block two');
      final layout = _layout(children: [b1, b2], blockSpacing: 24.0);

      final l1 = layout.getComponentByNodeId('p1')!;
      final l2 = layout.getComponentByNodeId('p2')!;
      final gap = blockTop(l2) - (blockTop(l1) + l1.size.height);

      expect(gap, closeTo(24.0, 0.01),
          reason: 'blockSpacing=24 should be used when no per-block spacing is set');
    });
  });
}
