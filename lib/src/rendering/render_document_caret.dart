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
/// the configured [color], `width`, and [cornerRadius].
///
/// ## Blink
///
/// Blink is controlled entirely via the [visible] property.  Set [visible]
/// to `false` on an animation tick to hide the cursor; set it back to `true`
/// to show it.  Each change calls `markNeedsPaint` — never `markNeedsLayout`.
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
  /// [color] → opaque black (`0xFF000000`), `width` → `2.0`,
  /// [cornerRadius] → `1.0`, [visible] → `true`.
  RenderDocumentCaret({
    RenderDocumentLayout? documentLayout,
    DocumentSelection? selection,
    Color color = const Color(0xFF000000),
    double width = 2.0,
    double cornerRadius = 1.0,
    bool visible = true,
    double devicePixelRatio = 1.0,
  })  : _documentLayout = documentLayout,
        _selection = selection,
        _color = color,
        _width = width,
        _cornerRadius = cornerRadius,
        _visible = visible,
        _devicePixelRatio = devicePixelRatio;

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

  /// Sets `width` and schedules a repaint when the value changes.
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
  // devicePixelRatio
  // ---------------------------------------------------------------------------

  double _devicePixelRatio;

  /// The pixel ratio of the current device.
  ///
  /// Used to snap the caret to physical pixel boundaries so it renders at a
  /// consistent width regardless of text position.  Obtain this value from
  /// `MediaQuery.devicePixelRatioOf(context)`.
  // ignore: diagnostic_describe_all_properties
  double get devicePixelRatio => _devicePixelRatio;

  /// Sets [devicePixelRatio] and schedules a repaint when the value changes.
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
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

    // Snap the caret origin to physical pixels so it never straddles a pixel
    // boundary (which would make it appear thinner at certain positions).
    // This mirrors RenderEditable._snapToPhysicalPixel in the Flutter
    // framework.
    final rawOrigin = Offset(offset.dx + rect.left, offset.dy + rect.top);
    final snapped = _snapToPhysicalPixel(rawOrigin);

    final paintedRect = Rect.fromLTWH(
      snapped.dx,
      snapped.dy,
      _width,
      rect.height,
    );
    final rrect = RRect.fromRectAndRadius(paintedRect, Radius.circular(_cornerRadius));
    context.canvas.drawRRect(rrect, Paint()..color = _color);
  }

  /// Snaps [sourceOffset] to the nearest physical pixel boundary.
  ///
  /// Converts the local offset to global coordinates, rounds each component
  /// to the nearest device pixel, and returns the snapped local offset.
  /// This prevents the caret from straddling pixel boundaries, which causes
  /// it to appear thinner at some text positions (e.g. after a space).
  ///
  /// Falls back to [sourceOffset] unmodified when the render object is not
  /// attached to a render tree (e.g. during unit tests).
  Offset _snapToPhysicalPixel(Offset sourceOffset) {
    if (!attached) return sourceOffset;

    final globalOffset = localToGlobal(sourceOffset);
    final pixelMultiple = 1.0 / _devicePixelRatio;
    return Offset(
      globalOffset.dx.isFinite
          ? (globalOffset.dx / pixelMultiple).round() * pixelMultiple -
              globalOffset.dx +
              sourceOffset.dx
          : sourceOffset.dx,
      globalOffset.dy.isFinite
          ? (globalOffset.dy / pixelMultiple).round() * pixelMultiple -
              globalOffset.dy +
              sourceOffset.dy
          : sourceOffset.dy,
    );
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
    properties.add(DoubleProperty('devicePixelRatio', _devicePixelRatio));
  }
}
