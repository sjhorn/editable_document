/// Selection highlight render object for the editable_document rendering layer.
///
/// [RenderDocumentSelectionHighlight] is a [RenderBox] that computes and paints
/// cross-block selection highlight rectangles at paint time by querying a
/// [RenderDocumentLayout] directly.  It is intended to be placed as an overlay
/// on top of the document content inside a render-layer [Stack].
library;

import 'package:flutter/rendering.dart';

import '../model/document_selection.dart';
import 'render_document_layout.dart';

// ---------------------------------------------------------------------------
// RenderDocumentSelectionHighlight
// ---------------------------------------------------------------------------

/// A [RenderBox] that paints selection-highlight rectangles by querying
/// [documentLayout] at paint time.
///
/// Properties that affect painting — [documentLayout], [selection], and
/// [selectionColor] — all call `markNeedsPaint` when changed.  Layout is
/// never invalidated by these setters.
///
/// ## Layout
///
/// [performLayout] sizes the render object to `constraints.biggest`, filling
/// whatever overlay area the parent provides.
///
/// ## Paint algorithm
///
/// When [selection] is `null`, collapsed, or [documentLayout] is `null`, the
/// painter is a no-op.  Otherwise the following rects are produced:
///
/// - **Single-line**: one rect spanning the horizontal range of the two
///   endpoint rects.
/// - **Multi-line top**: from the upstream endpoint's left edge to the full
///   layout width.
/// - **Multi-line intermediate** (when there is a gap between the top and
///   bottom lines): a full-width rect.
/// - **Multi-line bottom**: from the left edge to the downstream endpoint's
///   right edge.
///
/// Each rect is filled with [selectionColor].
///
/// ## Hit testing
///
/// [hitTestSelf] always returns `false` so that pointer events pass through
/// to the document content underneath.
///
/// ## Example
///
/// ```dart
/// final highlight = RenderDocumentSelectionHighlight()
///   ..documentLayout = myRenderDocumentLayout
///   ..selection = mySelection
///   ..selectionColor = const Color(0x663399FF);
/// ```
class RenderDocumentSelectionHighlight extends RenderBox {
  /// Creates a [RenderDocumentSelectionHighlight] with optional initial values.
  ///
  /// All parameters are optional; defaults are `null` for [documentLayout] and
  /// [selection], and `Color(0x663399FF)` (semi-transparent blue) for
  /// [selectionColor].
  RenderDocumentSelectionHighlight({
    RenderDocumentLayout? documentLayout,
    DocumentSelection? selection,
    Color selectionColor = const Color(0x663399FF),
  })  : _documentLayout = documentLayout,
        _selection = selection,
        _selectionColor = selectionColor;

  // ---------------------------------------------------------------------------
  // documentLayout
  // ---------------------------------------------------------------------------

  RenderDocumentLayout? _documentLayout;

  /// The [RenderDocumentLayout] to query for position geometry.
  ///
  /// When `null`, [paint] is a no-op.  Setting this property schedules a
  /// repaint but never a layout pass.
  // ignore: diagnostic_describe_all_properties
  RenderDocumentLayout? get documentLayout => _documentLayout;

  /// Sets [documentLayout] and schedules a repaint when the value changes.
  set documentLayout(RenderDocumentLayout? value) {
    if (identical(_documentLayout, value)) return;
    _documentLayout = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // selection
  // ---------------------------------------------------------------------------

  DocumentSelection? _selection;

  /// The current document selection to highlight.
  ///
  /// When `null` or collapsed, [paint] is a no-op.  Setting this property
  /// schedules a repaint but never a layout pass.
  // ignore: diagnostic_describe_all_properties
  DocumentSelection? get selection => _selection;

  /// Sets [selection] and schedules a repaint when the value changes.
  set selection(DocumentSelection? value) {
    if (_selection == value) return;
    _selection = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // selectionColor
  // ---------------------------------------------------------------------------

  Color _selectionColor;

  /// The fill colour applied to each selection-highlight rectangle.
  ///
  /// Defaults to `Color(0x663399FF)` (semi-transparent blue).  Setting this
  /// property schedules a repaint but never a layout pass.
  // ignore: diagnostic_describe_all_properties
  Color get selectionColor => _selectionColor;

  /// Sets [selectionColor] and schedules a repaint when the value changes.
  set selectionColor(Color value) {
    if (_selectionColor == value) return;
    _selectionColor = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    size = constraints.biggest;
  }

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final sel = _selection;
    final layout = _documentLayout;

    if (sel == null || sel.isCollapsed || layout == null) return;

    final rects = _computeSelectionRects(sel, layout);
    if (rects.isEmpty) return;

    final paint = Paint()..color = _selectionColor;
    for (final rect in rects) {
      context.canvas.drawRect(rect.shift(offset), paint);
    }
  }

  /// Computes the selection-highlight rectangles for [selection] by delegating
  /// to [RenderDocumentLayout.getRectsForSelection].
  ///
  /// Same-node selections use [RenderDocumentBlock.getEndpointsForSelection]
  /// (backed by [TextPainter.getBoxesForSelection]) so that mixed-font lines
  /// produce correct per-character rects rather than full-line rects.
  ///
  /// Cross-node selections use caret endpoint geometry with the top-line,
  /// optional-intermediate, bottom-line approach.
  ///
  /// Returns an empty list when either endpoint cannot be resolved.
  List<Rect> _computeSelectionRects(
    DocumentSelection selection,
    RenderDocumentLayout layout,
  ) {
    return layout.getRectsForSelection(selection);
  }

  // ---------------------------------------------------------------------------
  // Hit testing
  // ---------------------------------------------------------------------------

  @override
  bool hitTestSelf(Offset position) => false;

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<RenderDocumentLayout?>(
        'documentLayout',
        _documentLayout,
        defaultValue: null,
      ),
    );
    properties.add(
      DiagnosticsProperty<DocumentSelection?>(
        'selection',
        _selection,
        defaultValue: null,
      ),
    );
    properties.add(ColorProperty('selectionColor', _selectionColor));
  }
}
