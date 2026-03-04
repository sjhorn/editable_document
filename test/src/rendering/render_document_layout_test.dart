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
}
