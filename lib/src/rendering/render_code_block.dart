/// Code block render object for the editable_document rendering layer.
///
/// Provides [RenderCodeBlock], which extends [RenderTextBlock] with a
/// monospace font and a filled background rectangle.
library;

import 'package:flutter/rendering.dart';

import '../model/block_alignment.dart';
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
  /// [blockAlignment] controls horizontal positioning within the available
  /// layout width; defaults to [BlockAlignment.stretch].
  /// [requestedWidth] overrides the layout width when non-null; the text is
  /// laid out within `requestedWidth - 2 * padding`.
  /// [requestedHeight] overrides the block height when non-null.
  /// [textWrap] controls whether subsequent blocks may wrap around this block;
  /// defaults to `false`.
  RenderCodeBlock({
    required super.nodeId,
    required super.text,
    TextStyle? baseTextStyle,
    Color backgroundColor = const Color(0xFFF5F5F5),
    double padding = _kCodeBlockPadding,
    super.textDirection,
    super.textAlign,
    super.selectionColor,
    BlockAlignment blockAlignment = BlockAlignment.stretch,
    double? requestedWidth,
    double? requestedHeight,
    bool textWrap = false,
  })  : _backgroundColor = backgroundColor,
        _padding = padding,
        _blockAlignment = blockAlignment,
        _requestedWidth = requestedWidth,
        _requestedHeight = requestedHeight,
        _textWrap = textWrap {
    // Override the text style to force monospace.
    final base = baseTextStyle ?? const TextStyle();
    super.textStyle = base.copyWith(fontFamily: 'monospace');
  }

  // ---------------------------------------------------------------------------
  // Private state
  // ---------------------------------------------------------------------------

  Color _backgroundColor;
  double _padding;
  BlockAlignment _blockAlignment;
  double? _requestedWidth;
  double? _requestedHeight;
  bool _textWrap;

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
  /// When non-null, [performLayout] uses this as the block width and derives
  /// the text max-width as `requestedWidth - 2 * padding`.  The value is
  /// clamped to the available constraints.  When `null`, the full
  /// `constraints.maxWidth` is used as usual.
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
  /// instead of the intrinsic text height plus padding.  When `null`, the
  /// height is determined by the laid-out text.
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
    // When requestedWidth is set, use it as the block width (clamped to
    // constraints).  Otherwise fill the available width.
    final blockW = _requestedWidth != null
        ? _requestedWidth!.clamp(0.0, constraints.maxWidth)
        : constraints.maxWidth;

    final textMaxWidth = (blockW - _padding * 2).clamp(0.0, double.infinity);
    final excl = exclusionRectForLayout(
      horizontalInset: _padding,
      verticalInset: _padding,
    );
    layoutText(textMaxWidth, exclusionRect: excl);

    // When requestedHeight is set, use it as the block height.  Otherwise
    // derive the height from the laid-out text plus padding.
    final blockH = _requestedHeight ?? (layoutTextHeight + _padding * 2);

    size = Size(blockW, blockH);
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
