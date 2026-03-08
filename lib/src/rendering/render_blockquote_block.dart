/// Blockquote render object for the editable_document rendering layer.
///
/// Provides [RenderBlockquoteBlock], which extends [RenderTextBlock] with a
/// left-side accent border that visually identifies quoted content.
library;

import 'package:flutter/rendering.dart';

import '../model/block_alignment.dart';
import '../model/node_position.dart';
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
/// | [textWrap]        | `false`               | Whether adjacent blocks wrap around this.|
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
class RenderBlockquoteBlock extends RenderTextBlock {
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
  /// [textWrap] controls whether adjacent blocks may wrap around this block;
  ///   defaults to `false`.
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
    bool textWrap = false,
  })  : _borderColor = borderColor,
        _blockAlignment = blockAlignment,
        _requestedWidth = requestedWidth,
        _requestedHeight = requestedHeight,
        _textWrap = textWrap;

  // ---------------------------------------------------------------------------
  // Private state
  // ---------------------------------------------------------------------------

  Color _borderColor;
  BlockAlignment _blockAlignment;
  double? _requestedWidth;
  double? _requestedHeight;
  bool _textWrap;

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

  /// The horizontal alignment of this block within the layout.
  ///
  /// Defaults to [BlockAlignment.stretch].  Changing this value schedules a
  /// layout pass so the parent can reposition the block.
  // ignore: diagnostic_describe_all_properties
  @override
  BlockAlignment get blockAlignment => _blockAlignment;

  /// Sets the block alignment and schedules a layout pass.
  set blockAlignment(BlockAlignment value) {
    if (_blockAlignment == value) return;
    _blockAlignment = value;
    markNeedsLayout();
  }

  /// The requested width of this block in logical pixels, or `null`.
  ///
  /// When non-null, [performLayout] uses this as the block width (clamped to
  /// the available constraints) and derives the text max-width as
  /// `requestedWidth - _kBorderInset`.  When `null`, the full
  /// `constraints.maxWidth` is used.
  // ignore: diagnostic_describe_all_properties
  @override
  double? get requestedWidth => _requestedWidth;

  /// Sets the requested width and schedules a layout pass.
  set requestedWidth(double? value) {
    if (_requestedWidth == value) return;
    _requestedWidth = value;
    markNeedsLayout();
  }

  /// The requested height of this block in logical pixels, or `null`.
  ///
  /// When non-null, [performLayout] uses this value as the block height
  /// instead of the intrinsic text height.  When `null`, the height is
  /// determined by the laid-out text.
  // ignore: diagnostic_describe_all_properties
  @override
  double? get requestedHeight => _requestedHeight;

  /// Sets the requested height and schedules a layout pass.
  set requestedHeight(double? value) {
    if (_requestedHeight == value) return;
    _requestedHeight = value;
    markNeedsLayout();
  }

  /// Whether subsequent blocks should wrap around this block.
  ///
  /// When `true` and [blockAlignment] is [BlockAlignment.start] or
  /// [BlockAlignment.end], the document layout creates an exclusion zone so
  /// adjacent blocks receive reduced-width constraints.
  // ignore: diagnostic_describe_all_properties
  @override
  bool get textWrap => _textWrap;

  /// Sets the text-wrap flag and schedules a layout pass.
  set textWrap(bool value) {
    if (_textWrap == value) return;
    _textWrap = value;
    markNeedsLayout();
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    final availableWidth = _requestedWidth != null
        ? _requestedWidth!.clamp(0.0, constraints.maxWidth)
        : constraints.maxWidth;
    final textMaxWidth = (availableWidth - _kBorderInset).clamp(0.0, double.infinity);
    final excl = exclusionRectForLayout(horizontalInset: _kBorderInset);
    layoutText(textMaxWidth, exclusionRect: excl);
    final blockWidth = _requestedWidth != null ? availableWidth : constraints.maxWidth;
    final blockHeight = _requestedHeight ?? layoutTextHeight;
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
    properties.add(EnumProperty<BlockAlignment>(
      'blockAlignment',
      _blockAlignment,
      defaultValue: BlockAlignment.stretch,
    ));
    properties.add(DoubleProperty('requestedWidth', _requestedWidth, defaultValue: null));
    properties.add(DoubleProperty('requestedHeight', _requestedHeight, defaultValue: null));
    properties.add(FlagProperty('textWrap', value: _textWrap, ifTrue: 'textWrap'));
  }
}
