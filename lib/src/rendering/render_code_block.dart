/// Code block render object for the editable_document rendering layer.
///
/// Provides [RenderCodeBlock], which extends [RenderTextBlock] with a
/// monospace font and a filled background rectangle.
library;

import 'package:flutter/rendering.dart';

import '../model/node_position.dart';
import 'render_text_block.dart';

/// Internal padding applied on all sides of a [RenderCodeBlock].
const double _kCodeBlockPadding = 16.0;

/// A [RenderTextBlock] with a monospace font and a filled background.
///
/// The background [backgroundColor] is drawn before the text, and [padding]
/// is applied on all four sides so the text does not touch the edges.
///
/// The [textStyle] is always overridden to use `'monospace'` as the font
/// family.  Callers may supply a [baseTextStyle] to control size and color.
class RenderCodeBlock extends RenderTextBlock {
  /// Creates a [RenderCodeBlock].
  ///
  /// [baseTextStyle] is the base style; its [TextStyle.fontFamily] is ignored
  /// and replaced with `'monospace'`.
  /// [backgroundColor] defaults to a light grey.
  /// [padding] defaults to [_kCodeBlockPadding] (16 dp) on all sides.
  RenderCodeBlock({
    required super.nodeId,
    required super.text,
    TextStyle? baseTextStyle,
    Color backgroundColor = const Color(0xFFF5F5F5),
    double padding = _kCodeBlockPadding,
    super.textDirection,
    super.textAlign,
    super.selectionColor,
  })  : _backgroundColor = backgroundColor,
        _padding = padding {
    // Override the text style to force monospace.
    final base = baseTextStyle ?? const TextStyle();
    super.textStyle = base.copyWith(fontFamily: 'monospace');
  }

  // ---------------------------------------------------------------------------
  // Private state
  // ---------------------------------------------------------------------------

  Color _backgroundColor;
  double _padding;

  // ---------------------------------------------------------------------------
  // Public properties — described in debugFillProperties below.
  // ---------------------------------------------------------------------------

  /// The background fill color of this code block.
  // ignore: diagnostic_describe_all_properties
  Color get backgroundColor => _backgroundColor;

  /// Sets the background color and schedules a repaint.
  set backgroundColor(Color value) {
    if (_backgroundColor == value) return;
    _backgroundColor = value;
    markNeedsPaint();
  }

  /// Internal padding applied on all sides of the code block.
  // ignore: diagnostic_describe_all_properties
  double get padding => _padding;

  /// Sets the padding and schedules a layout pass.
  set padding(double value) {
    if (_padding == value) return;
    _padding = value;
    markNeedsLayout();
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    final textMaxWidth = (constraints.maxWidth - _padding * 2).clamp(0.0, double.infinity);
    layoutText(textMaxWidth);
    size = Size(constraints.maxWidth, layoutTextHeight + _padding * 2);
  }

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    // Draw background first.
    final bgPaint = Paint()..color = _backgroundColor;
    context.canvas.drawRect(offset & size, bgPaint);
    // Draw text content with padding offset.
    super.paint(context, offset.translate(_padding, _padding));
  }

  // ---------------------------------------------------------------------------
  // Geometry queries — adjust for padding
  // ---------------------------------------------------------------------------

  @override
  Rect getLocalRectForPosition(NodePosition position) {
    final inner = super.getLocalRectForPosition(position);
    return inner.translate(_padding, _padding);
  }

  @override
  NodePosition getPositionAtOffset(Offset localOffset) {
    // Remove padding before delegating to the text painter.
    final adjusted = localOffset.translate(-_padding, -_padding);
    return super.getPositionAtOffset(adjusted);
  }

  @override
  List<Rect> getEndpointsForSelection(NodePosition base, NodePosition extent) {
    return super
        .getEndpointsForSelection(base, extent)
        .map((r) => r.translate(_padding, _padding))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', _backgroundColor));
    properties.add(DoubleProperty('padding', _padding));
  }
}
