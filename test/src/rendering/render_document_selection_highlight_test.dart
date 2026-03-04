/// Tests for [RenderDocumentSelectionHighlight].
library;

import 'dart:ui';

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a minimal [RenderDocumentLayout] laid out at [maxWidth].
RenderDocumentLayout _buildLayout({double maxWidth = 400.0}) {
  final layout = RenderDocumentLayout(blockSpacing: 0.0);
  layout.add(
    RenderTextBlock(
      nodeId: 'p1',
      text: AttributedText('Hello world'),
      textStyle: const TextStyle(fontSize: 16),
    ),
  );
  layout.add(
    RenderTextBlock(
      nodeId: 'p2',
      text: AttributedText('Second paragraph'),
      textStyle: const TextStyle(fontSize: 16),
    ),
  );
  layout.layout(BoxConstraints(maxWidth: maxWidth), parentUsesSize: true);
  return layout;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RenderDocumentSelectionHighlight — construction', () {
    test('can be created with default values', () {
      final highlight = RenderDocumentSelectionHighlight();
      expect(highlight, isA<RenderBox>());
    });

    test('documentLayout defaults to null', () {
      final highlight = RenderDocumentSelectionHighlight();
      expect(highlight.documentLayout, isNull);
    });

    test('selection defaults to null', () {
      final highlight = RenderDocumentSelectionHighlight();
      expect(highlight.selection, isNull);
    });

    test('selectionColor defaults to semi-transparent blue', () {
      final highlight = RenderDocumentSelectionHighlight();
      expect(highlight.selectionColor, const Color(0x663399FF));
    });
  });

  group('RenderDocumentSelectionHighlight — property setters', () {
    test('documentLayout setter stores the value', () {
      final highlight = RenderDocumentSelectionHighlight();
      final layout = _buildLayout();
      highlight.documentLayout = layout;
      expect(highlight.documentLayout, same(layout));
    });

    test('selection setter stores the value', () {
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
      final highlight = RenderDocumentSelectionHighlight();
      highlight.selection = sel;
      expect(highlight.selection, equals(sel));
    });

    test('selection setter accepts null', () {
      final highlight = RenderDocumentSelectionHighlight();
      highlight.selection = null;
      expect(highlight.selection, isNull);
    });

    test('selectionColor setter stores the value', () {
      final highlight = RenderDocumentSelectionHighlight();
      highlight.selectionColor = const Color(0xFFFF0000);
      expect(highlight.selectionColor, const Color(0xFFFF0000));
    });

    test('documentLayout setter does not trigger layout', () {
      // Setting documentLayout should call markNeedsPaint, not markNeedsLayout.
      // We verify this indirectly: after setting documentLayout, layout size
      // must remain valid (no layout invalidation occurred between layout calls).
      final highlight = RenderDocumentSelectionHighlight();
      highlight.layout(const BoxConstraints.tightFor(width: 400, height: 200));
      final sizeBefore = highlight.size;

      final layout = _buildLayout();
      highlight.documentLayout = layout;

      // Size is unchanged — no layout was triggered.
      expect(highlight.size, equals(sizeBefore));
    });

    test('selection setter does not trigger layout', () {
      final highlight = RenderDocumentSelectionHighlight();
      highlight.layout(const BoxConstraints.tightFor(width: 400, height: 200));
      final sizeBefore = highlight.size;

      const sel = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
      );
      highlight.selection = sel;
      expect(highlight.size, equals(sizeBefore));
    });

    test('selectionColor setter does not trigger layout', () {
      final highlight = RenderDocumentSelectionHighlight();
      highlight.layout(const BoxConstraints.tightFor(width: 400, height: 200));
      final sizeBefore = highlight.size;

      highlight.selectionColor = const Color(0xFFFF0000);
      expect(highlight.size, equals(sizeBefore));
    });

    test('setting documentLayout to same value is a no-op', () {
      final highlight = RenderDocumentSelectionHighlight();
      final layout = _buildLayout();
      highlight.documentLayout = layout;
      // Setting it again to the same instance must not throw.
      highlight.documentLayout = layout;
      expect(highlight.documentLayout, same(layout));
    });

    test('setting selection to same value is a no-op', () {
      const sel = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 2),
        ),
      );
      final highlight = RenderDocumentSelectionHighlight();
      highlight.selection = sel;
      // Setting again to same value must not throw.
      highlight.selection = sel;
      expect(highlight.selection, equals(sel));
    });

    test('setting selectionColor to same value is a no-op', () {
      final highlight = RenderDocumentSelectionHighlight();
      highlight.selectionColor = const Color(0x663399FF);
      highlight.selectionColor = const Color(0x663399FF);
      expect(highlight.selectionColor, const Color(0x663399FF));
    });
  });

  group('RenderDocumentSelectionHighlight — layout', () {
    test('performLayout sizes to constraints.biggest', () {
      final highlight = RenderDocumentSelectionHighlight();
      highlight.layout(
        const BoxConstraints.tightFor(width: 300, height: 150),
        parentUsesSize: true,
      );
      expect(highlight.size, const Size(300, 150));
    });

    test('loose constraints — sizes to maximum available', () {
      final highlight = RenderDocumentSelectionHighlight();
      highlight.layout(
        const BoxConstraints(maxWidth: 500, maxHeight: 400),
        parentUsesSize: true,
      );
      expect(highlight.size, const Size(500, 400));
    });
  });

  group('RenderDocumentSelectionHighlight — hitTestSelf', () {
    test('returns false (transparent to hit testing)', () {
      final highlight = RenderDocumentSelectionHighlight();
      highlight.layout(const BoxConstraints.tightFor(width: 400, height: 200));
      expect(highlight.hitTestSelf(const Offset(10, 10)), isFalse);
    });
  });

  group('RenderDocumentSelectionHighlight — paint', () {
    test('paints without error when selection is null', () {
      final highlight = RenderDocumentSelectionHighlight();
      highlight.layout(const BoxConstraints.tightFor(width: 400, height: 200));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _MockPaintingContext(canvas);

      expect(
        () => highlight.paint(context, Offset.zero),
        returnsNormally,
      );
    });

    test('paints without error when documentLayout is null', () {
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
      final highlight = RenderDocumentSelectionHighlight()..selection = sel;
      highlight.layout(const BoxConstraints.tightFor(width: 400, height: 200));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _MockPaintingContext(canvas);

      expect(
        () => highlight.paint(context, Offset.zero),
        returnsNormally,
      );
    });

    test('paints without error when selection is collapsed', () {
      final layout = _buildLayout();
      const sel = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );
      final highlight = RenderDocumentSelectionHighlight()
        ..documentLayout = layout
        ..selection = sel;
      highlight.layout(const BoxConstraints.tightFor(width: 400, height: 200));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _MockPaintingContext(canvas);

      expect(
        () => highlight.paint(context, Offset.zero),
        returnsNormally,
      );
    });

    test('paints without error for an expanded selection', () {
      final layout = _buildLayout();
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
      final highlight = RenderDocumentSelectionHighlight()
        ..documentLayout = layout
        ..selection = sel;
      highlight.layout(const BoxConstraints.tightFor(width: 400, height: 200));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _MockPaintingContext(canvas);

      expect(
        () => highlight.paint(context, Offset.zero),
        returnsNormally,
      );
    });

    test('paints without error for a cross-paragraph selection', () {
      final layout = _buildLayout();
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
      final highlight = RenderDocumentSelectionHighlight()
        ..documentLayout = layout
        ..selection = sel;
      highlight.layout(const BoxConstraints.tightFor(width: 400, height: 200));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _MockPaintingContext(canvas);

      expect(
        () => highlight.paint(context, Offset.zero),
        returnsNormally,
      );
    });
  });

  group('RenderDocumentSelectionHighlight — mixed-font same-node selection', () {
    // Regression test: with mixed font sizes on the same visual line,
    // `getOffsetForCaret` can return different y-values, which previously
    // caused the multi-line path to fire and paint full-width highlight rects.
    // After the fix, same-node selections always delegate to
    // `getEndpointsForSelection` (TextPainter.getBoxesForSelection), which
    // correctly handles mixed fonts.

    test('same-node selection uses getEndpointsForSelection (not full-line rects)', () {
      // Two characters with very different font sizes on the same line.
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
      final layout = RenderDocumentLayout(blockSpacing: 0.0);
      layout.add(
        RenderTextBlock(
          nodeId: 'p1',
          text: mixedText,
          textStyle: const TextStyle(fontSize: 16),
        ),
      );
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

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

      // Obtain the rects via the layout — no full-width rects.
      final rects = layout.getRectsForSelection(sel);
      expect(rects, isNotEmpty);

      // None of the rects should span the full layout width (which would
      // indicate the broken multi-line path was taken).
      for (final r in rects) {
        expect(r.width, lessThan(layout.size.width),
            reason: 'Full-width rect detected — multi-line path was incorrectly taken');
      }
    });

    test('cross-node selection still paints without error', () {
      final layout = _buildLayout();
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
      final highlight = RenderDocumentSelectionHighlight()
        ..documentLayout = layout
        ..selection = sel;
      highlight.layout(const BoxConstraints.tightFor(width: 400, height: 200));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _MockPaintingContext(canvas);

      expect(
        () => highlight.paint(context, Offset.zero),
        returnsNormally,
      );
    });
  });

  group('RenderDocumentSelectionHighlight — diagnostics', () {
    test('debugFillProperties includes all properties', () {
      final layout = _buildLayout();
      const sel = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
      );
      final highlight = RenderDocumentSelectionHighlight()
        ..documentLayout = layout
        ..selection = sel
        ..selectionColor = const Color(0x663399FF);

      final builder = DiagnosticPropertiesBuilder();
      highlight.debugFillProperties(builder);

      final names = builder.properties.map((p) => p.name).toList();
      expect(names, contains('documentLayout'));
      expect(names, contains('selection'));
      expect(names, contains('selectionColor'));
    });
  });
}

// ---------------------------------------------------------------------------
// Mock PaintingContext
// ---------------------------------------------------------------------------

/// A minimal [PaintingContext] that delegates painting to a real [Canvas].
///
/// Used in unit tests where a full widget pump is not required.
class _MockPaintingContext extends PaintingContext {
  _MockPaintingContext(this._canvas) : super(ContainerLayer(), Rect.zero);

  final Canvas _canvas;

  @override
  Canvas get canvas => _canvas;
}
