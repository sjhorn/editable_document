/// Blockquote render object for the editable_document rendering layer.
///
/// Provides [RenderBlockquoteBlock], which extends [RenderTextBlock] with a
/// left-side accent border that visually identifies quoted content.
library;

import 'package:flutter/rendering.dart';

import '../model/block_alignment.dart';
import '../model/node_position.dart';
import '../model/text_wrap_mode.dart';
import 'block_layout_mixin.dart';
import 'render_text_block.dart';

/// Width of the left accent border in logical pixels.
const double _kBorderWidth = 3.0;

/// Gap between the accent border and the text in logical pixels.
const double _kBorderPadding = 8.0;

/// Total horizontal inset applied to the text area: border + gap.
const double _kBorderInset = _kBorderWidth + _kBorderPadding;

/// A [RenderTextBlock] with a left accent border that indicates quoted content.
///
/// The border is a filled rectangle, [_kBorderWidth] (3 dp) wide, drawn at
/// `x = 0` and spanning the full block height.  Text is offset to the right
/// by [_kBorderInset] (11 dp) so it never overlaps the border.
///
/// ## Layout properties
///
/// | Property          | Default               | Effect                                   |
/// |-------------------|-----------------------|------------------------------------------|
/// | [blockAlignment]  | [BlockAlignment.stretch] | Horizontal alignment within the layout. |
/// | [requestedWidth]  | `null`                | Overrides block width when non-null.     |
/// | [requestedHeight] | `null`                | Overrides block height when non-null.    |
/// | [textWrap]        | [TextWrapMode.none]   | How surrounding text interacts with this.|
///
/// Example:
///
/// ```dart
/// final block = RenderBlockquoteBlock(
///   nodeId: 'bq-1',
///   text: AttributedText('To be or not to be'),
///   borderColor: const Color(0xFF2196F3),
/// );
/// ```
class RenderBlockquoteBlock extends RenderTextBlock with BlockLayoutMixin {
  /// Creates a [RenderBlockquoteBlock].
  ///
  /// [nodeId] must match the corresponding [DocumentNode.id].
  /// [text] is the attributed text content to render.
  /// [textStyle] is the base text style applied before attributions.
  /// [textDirection] defaults to [TextDirection.ltr].
  /// [textAlign] defaults to [TextAlign.start].
  /// [selectionColor] is the highlight color behind selected text.
  /// [borderColor] is the fill color of the left accent border; defaults to
  ///   `Color(0xFFBDBDBD)` (medium grey).
  /// [blockAlignment] controls horizontal positioning; defaults to
  ///   [BlockAlignment.stretch].
  /// [requestedWidth] overrides the block width when non-null.
  /// [requestedHeight] overrides the block height when non-null.
  /// [textWrap] controls how surrounding text interacts with this block;
  ///   defaults to [TextWrapMode.none].
  RenderBlockquoteBlock({
    required super.nodeId,
    required super.text,
    super.textStyle,
    super.textDirection,
    super.textAlign,
    super.selectionColor,
    Color borderColor = const Color(0xFFBDBDBD),
    BlockAlignment blockAlignment = BlockAlignment.stretch,
    double? requestedWidth,
    double? requestedHeight,
    TextWrapMode textWrap = TextWrapMode.none,
  }) : _borderColor = borderColor {
    initBlockLayout(
      blockAlignment: blockAlignment,
      requestedWidth: requestedWidth,
      requestedHeight: requestedHeight,
      textWrap: textWrap,
    );
  }

  // ---------------------------------------------------------------------------
  // Private state
  // ---------------------------------------------------------------------------

  Color _borderColor;

  // ---------------------------------------------------------------------------
  // Public properties — described in debugFillProperties below.
  // ---------------------------------------------------------------------------

  /// The fill color of the left accent border.
  ///
  /// Defaults to `Color(0xFFBDBDBD)` (medium grey).  Changing this value
  /// schedules a repaint.
  // ignore: diagnostic_describe_all_properties
  Color get borderColor => _borderColor;

  /// Sets the border color and schedules a repaint.
  set borderColor(Color value) {
    if (_borderColor == value) return;
    _borderColor = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    final availableWidth = requestedWidth != null
        ? requestedWidth!.clamp(0.0, constraints.maxWidth)
        : constraints.maxWidth;
    final textMaxWidth = (availableWidth - _kBorderInset).clamp(0.0, double.infinity);
    final excl = exclusionRectForLayout(horizontalInset: _kBorderInset);
    layoutText(textMaxWidth, exclusionRect: excl);
    final blockWidth = requestedWidth != null ? availableWidth : constraints.maxWidth;
    final blockHeight = requestedHeight ?? layoutTextHeight;
    size = Size(blockWidth, blockHeight);
  }

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    // Draw the left accent border.
    final borderPaint = Paint()
      ..color = _borderColor
      ..style = PaintingStyle.fill;
    final borderRect = Rect.fromLTWH(offset.dx, offset.dy, _kBorderWidth, size.height);
    context.canvas.drawRect(borderRect, borderPaint);

    // Draw the text content, inset by the border width + padding.
    super.paint(context, offset.translate(_kBorderInset, 0));
  }

  // ---------------------------------------------------------------------------
  // Geometry queries — adjust for border inset
  // ---------------------------------------------------------------------------

  @override
  Rect getLocalRectForPosition(NodePosition position) {
    final inner = super.getLocalRectForPosition(position);
    return inner.translate(_kBorderInset, 0);
  }

  @override
  NodePosition getPositionAtOffset(Offset localOffset) {
    // Remove the border inset before delegating to the text painter.
    final adjusted = localOffset.translate(-_kBorderInset, 0);
    return super.getPositionAtOffset(adjusted);
  }

  @override
  List<Rect> getEndpointsForSelection(NodePosition base, NodePosition extent) {
    return super
        .getEndpointsForSelection(base, extent)
        .map((r) => r.translate(_kBorderInset, 0))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Semantics
  // ---------------------------------------------------------------------------

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.hint = 'Blockquote';
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('borderColor', _borderColor));
    debugFillBlockLayoutProperties(properties);
  }
}
