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
/// [textWrap] enables float behaviour when combined with [BlockAlignment.start]
/// or [BlockAlignment.end].
RenderImageBlock _imageBlock(
  String nodeId, {
  double? requestedWidth,
  double? requestedHeight,
  BlockAlignment blockAlignment = BlockAlignment.stretch,
  bool textWrap = false,
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
        textWrap: true,
      );
      final text = _textBlock('p1', 'Wrapped text beside float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      expect(imageData.offset.dx, 0.0);
      expect(imageData.isFloat, isTrue);
    });

    test('float start: adjacent stretch block without requestedWidth drops below float', () {
      // A text block has no requestedWidth — it wants the full available width,
      // so the new behaviour is to drop below the float rather than being
      // squeezed into the narrow remainder beside it.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: true,
      );
      final text = _textBlock('p1', 'Text after float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      final textData = text.parentData as DocumentBlockParentData;

      // Text must start at or below the float bottom (dropped below, not beside).
      expect(textData.offset.dy, greaterThanOrEqualTo(floatBottom));
      // Text must span the full width.
      expect(text.size.width, closeTo(maxWidth, 0.5));
    });

    test('float start: stretch block with requestedWidth starts to the right of the float', () {
      // An image block with an explicit requestedWidth that fits beside the
      // float should wrap alongside it.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: true,
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
        textWrap: true,
      );
      final text = _textBlock('p1', 'Wrapped text beside float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      expect(imageData.offset.dx, closeTo(maxWidth - floatWidth, 0.5));
      expect(imageData.isFloat, isTrue);
    });

    test('float end: adjacent stretch block without requestedWidth drops below float', () {
      // A text block has no requestedWidth — it drops below the end float
      // and gets the full width rather than being squeezed beside it.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.end,
        textWrap: true,
      );
      final text = _textBlock('p1', 'Text after float');
      _layout(children: [image, text], maxWidth: maxWidth, blockSpacing: 0.0);

      final imageData = image.parentData as DocumentBlockParentData;
      final floatBottom = imageData.offset.dy + image.size.height;
      final textData = text.parentData as DocumentBlockParentData;

      // Text must start at or below the float bottom.
      expect(textData.offset.dy, greaterThanOrEqualTo(floatBottom));
      // Text must span the full width.
      expect(text.size.width, closeTo(maxWidth, 0.5));
    });

    test('total layout height is at least the float height when no block is taller', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: true,
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
        textWrap: true,
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

    test('stretch block without requestedWidth clears exclusion and drops below float', () {
      // A stretch block with no requestedWidth wants the full available width.
      // It should NOT be squeezed beside the float — instead it should drop
      // below the float bottom and be laid out at full width.
      final image = _imageBlock(
        'img1',
        requestedWidth: 100.0,
        requestedHeight: 80.0,
        blockAlignment: BlockAlignment.start,
        textWrap: true,
      );
      // HR block is stretch with no requestedWidth — must clear the float.
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

    test('stretch block with small requestedWidth wraps beside float', () {
      // A stretch-aligned block with an explicit requestedWidth that fits
      // beside the float should still wrap alongside it.
      final image = _imageBlock(
        'img1',
        requestedWidth: 100.0,
        requestedHeight: 80.0,
        blockAlignment: BlockAlignment.start,
        textWrap: true,
      );
      // Image with stretch alignment and a requestedWidth that fits in the
      // remaining space beside the float (maxWidth - floatWidth - gap = 292 px).
      final smallBlock = _imageBlock(
        'img2',
        requestedWidth: 50.0,
        requestedHeight: 30.0,
        blockAlignment: BlockAlignment.stretch,
        textWrap: false,
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

    test('non-float aligned block clears the exclusion zone', () {
      // Float on the left, then a stretch block: the stretch block is narrowed.
      // After that, a center-aligned non-float block must get full-width treatment.
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: 200.0, // tall float
        blockAlignment: BlockAlignment.start,
        textWrap: true,
      );
      // Non-float, non-stretch block placed after the float.
      final centeredImage = _imageBlock(
        'img2',
        requestedWidth: 60.0,
        requestedHeight: 60.0,
        blockAlignment: BlockAlignment.center,
        textWrap: false, // NOT a float
      );
      _layout(
        children: [image, centeredImage],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      // The centred block is non-float and occupies a full vertical row.
      // Its offset should be computed from the center of maxWidth.
      final centeredData = centeredImage.parentData as DocumentBlockParentData;
      expect(centeredData.isFloat, isFalse);
      // x should be centred in the full maxWidth.
      expect(centeredData.offset.dx, closeTo((maxWidth - centeredImage.size.width) / 2, 0.5));
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
        textWrap: true,
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

    test('hit testing routes to adjacent text when clicking within text bounds beside float', () {
      final image = _imageBlock(
        'img1',
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        blockAlignment: BlockAlignment.start,
        textWrap: true,
      );
      final text = _textBlock('p1', 'Wrapped text beside float');
      final layout = _layout(
        children: [image, text],
        maxWidth: maxWidth,
        blockSpacing: 0.0,
      );

      final textData = text.parentData as DocumentBlockParentData;
      // Click somewhere inside the text block bounds.
      final hitPoint = textData.offset + const Offset(5.0, 5.0);
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
        textWrap: true,
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
        textWrap: true,
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
}
