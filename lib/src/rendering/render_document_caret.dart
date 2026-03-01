/// Render object that computes and paints a document caret at paint time.
///
/// [RenderDocumentCaret] queries [RenderDocumentLayout] during [paint] to
/// obtain the caret rect for the current [selection], so no pre-computed
/// geometry is required by the widget layer.
library;

import 'package:flutter/rendering.dart';

import '../model/document_selection.dart';
import 'render_document_layout.dart';

// ---------------------------------------------------------------------------
// RenderDocumentCaret
// ---------------------------------------------------------------------------

/// A [RenderBox] that paints a blinking text cursor by querying
/// [RenderDocumentLayout] at paint time.
///
/// Place this render object as an overlay that covers the same area as the
/// [RenderDocumentLayout] it references.  During [paint] it resolves the
/// caret [Rect] from [documentLayout] and draws a rounded rectangle using
/// the configured [color], [width], and [cornerRadius].
///
/// ## Blink
///
/// Blink is controlled entirely via the [visible] property.  Set [visible]
/// to `false` on an animation tick to hide the cursor; set it back to `true`
/// to show it.  Each change calls [markNeedsPaint] — never [markNeedsLayout].
///
/// ## When nothing is drawn
///
/// [paint] is a no-op when any of the following conditions hold:
/// - [selection] is `null`
/// - [selection] is not collapsed (range selection)
/// - [visible] is `false`
/// - [documentLayout] is `null`
/// - [documentLayout] returns `null` for the extent position (node not found)
///
/// ## Hit testing
///
/// [hitTestSelf] always returns `false`; the caret is invisible to pointer
/// events.
///
/// Example:
/// ```dart
/// final caretRender = RenderDocumentCaret(
///   documentLayout: myLayout,
///   selection: DocumentSelection.collapsed(
///     position: DocumentPosition(
///       nodeId: 'p1',
///       nodePosition: TextNodePosition(offset: 3),
///     ),
///   ),
///   color: const Color(0xFF1A73E8),
/// );
/// ```
class RenderDocumentCaret extends RenderBox {
  /// Creates a [RenderDocumentCaret] with optional initial values.
  ///
  /// All parameters are optional and default to sensible values:
  /// [color] → opaque black (`0xFF000000`), [width] → `2.0`,
  /// [cornerRadius] → `1.0`, [visible] → `true`.
  RenderDocumentCaret({
    RenderDocumentLayout? documentLayout,
    DocumentSelection? selection,
    Color color = const Color(0xFF000000),
    double width = 2.0,
    double cornerRadius = 1.0,
    bool visible = true,
  })  : _documentLayout = documentLayout,
        _selection = selection,
        _color = color,
        _width = width,
        _cornerRadius = cornerRadius,
        _visible = visible;

  // ---------------------------------------------------------------------------
  // documentLayout
  // ---------------------------------------------------------------------------

  RenderDocumentLayout? _documentLayout;

  /// The [RenderDocumentLayout] to query for caret geometry.
  ///
  /// When `null`, [paint] is a no-op.
  // ignore: diagnostic_describe_all_properties
  RenderDocumentLayout? get documentLayout => _documentLayout;

  /// Sets [documentLayout] and schedules a repaint when the value changes.
  set documentLayout(RenderDocumentLayout? value) {
    if (_documentLayout == value) return;
    _documentLayout = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // selection
  // ---------------------------------------------------------------------------

  DocumentSelection? _selection;

  /// The current document selection.
  ///
  /// Only a collapsed selection (caret) triggers painting.  When `null` or
  /// expanded, [paint] is a no-op.
  // ignore: diagnostic_describe_all_properties
  DocumentSelection? get selection => _selection;

  /// Sets [selection] and schedules a repaint when the value changes.
  set selection(DocumentSelection? value) {
    if (_selection == value) return;
    _selection = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // color
  // ---------------------------------------------------------------------------

  Color _color;

  /// The fill colour used to draw the caret rectangle.
  // ignore: diagnostic_describe_all_properties
  Color get color => _color;

  /// Sets [color] and schedules a repaint when the value changes.
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // width
  // ---------------------------------------------------------------------------

  double _width;

  /// The painted width of the caret in logical pixels.
  ///
  /// The width component of the rect returned by [RenderDocumentLayout] is
  /// ignored; this value is used instead so the cursor always has a
  /// consistent visual weight.
  // ignore: diagnostic_describe_all_properties
  double get width => _width;

  /// Sets [width] and schedules a repaint when the value changes.
  set width(double value) {
    if (_width == value) return;
    _width = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // cornerRadius
  // ---------------------------------------------------------------------------

  double _cornerRadius;

  /// The corner radius applied to all four corners of the painted [RRect].
  // ignore: diagnostic_describe_all_properties
  double get cornerRadius => _cornerRadius;

  /// Sets [cornerRadius] and schedules a repaint when the value changes.
  set cornerRadius(double value) {
    if (_cornerRadius == value) return;
    _cornerRadius = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // visible
  // ---------------------------------------------------------------------------

  bool _visible;

  /// Whether the caret is currently visible.
  ///
  /// Toggle this property on each blink interval to implement blinking
  /// without triggering a layout pass.  When `false`, [paint] is a no-op.
  // ignore: diagnostic_describe_all_properties
  bool get visible => _visible;

  /// Sets [visible] and schedules a repaint when the value changes.
  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
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
  // Hit testing
  // ---------------------------------------------------------------------------

  @override
  bool hitTestSelf(Offset position) => false;

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final sel = _selection;
    final layout = _documentLayout;

    // Bail out when there is nothing to draw.
    if (sel == null || !sel.isCollapsed || !_visible || layout == null) return;

    final rect = layout.getRectForDocumentPosition(sel.extent);
    if (rect == null) return;

    final paintedRect = Rect.fromLTWH(
      offset.dx + rect.left,
      offset.dy + rect.top,
      _width,
      rect.height,
    );
    final rrect = RRect.fromRectAndRadius(paintedRect, Radius.circular(_cornerRadius));
    context.canvas.drawRRect(rrect, Paint()..color = _color);
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<RenderDocumentLayout?>(
      'documentLayout',
      _documentLayout,
      defaultValue: null,
    ));
    properties.add(DiagnosticsProperty<DocumentSelection?>(
      'selection',
      _selection,
      defaultValue: null,
    ));
    properties.add(ColorProperty('color', _color));
    properties.add(DoubleProperty('width', _width));
    properties.add(DoubleProperty('cornerRadius', _cornerRadius));
    properties.add(DiagnosticsProperty<bool>('visible', _visible));
  }
}
