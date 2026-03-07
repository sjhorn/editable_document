/// Horizontal rule render object for the editable_document rendering layer.
///
/// Provides [RenderHorizontalRuleBlock], a [RenderDocumentBlock] that draws a
/// simple horizontal divider line.
library;

import 'package:flutter/rendering.dart';

import '../model/block_alignment.dart';
import '../model/document_selection.dart';
import '../model/node_position.dart';
import 'render_document_block.dart';

/// A [RenderDocumentBlock] that renders a horizontal rule (thematic break).
///
/// The block occupies the full available width and has a height of
/// [thickness] + 2 × [verticalPadding].  The rule line itself is centered
/// vertically within the block.
///
/// Hit testing uses [BinaryNodePosition]: taps in the left half return
/// [BinaryNodePosition.upstream]; taps in the right half return
/// [BinaryNodePosition.downstream].
class RenderHorizontalRuleBlock extends RenderDocumentBlock {
  /// Creates a [RenderHorizontalRuleBlock].
  ///
  /// [color] defaults to a mid-grey.
  /// [thickness] defaults to `1.0`.
  /// [verticalPadding] defaults to `8.0`.
  /// [blockAlignment] controls horizontal positioning within the available
  /// layout width; defaults to [BlockAlignment.stretch].
  /// [requestedWidth] overrides the layout width when non-null.
  /// [requestedHeight] overrides the layout height when non-null.
  /// [textWrap] controls whether subsequent blocks may wrap around this block;
  /// defaults to `false`.
  RenderHorizontalRuleBlock({
    required String nodeId,
    Color color = const Color(0xFFCCCCCC),
    double thickness = 1.0,
    double verticalPadding = 8.0,
    BlockAlignment blockAlignment = BlockAlignment.stretch,
    double? requestedWidth,
    double? requestedHeight,
    bool textWrap = false,
  })  : _nodeId = nodeId,
        _color = color,
        _thickness = thickness,
        _verticalPadding = verticalPadding,
        _blockAlignment = blockAlignment,
        _requestedWidth = requestedWidth,
        _requestedHeight = requestedHeight,
        _textWrap = textWrap;

  // ---------------------------------------------------------------------------
  // Private state
  // ---------------------------------------------------------------------------

  String _nodeId;
  Color _color;
  double _thickness;
  double _verticalPadding;
  DocumentSelection? _nodeSelection;
  BlockAlignment _blockAlignment;
  double? _requestedWidth;
  double? _requestedHeight;
  bool _textWrap;

  // ---------------------------------------------------------------------------
  // RenderDocumentBlock — nodeId
  // ---------------------------------------------------------------------------

  @override
  String get nodeId => _nodeId;

  @override
  set nodeId(String value) {
    if (_nodeId == value) return;
    _nodeId = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // RenderDocumentBlock — nodeSelection
  // ---------------------------------------------------------------------------

  @override
  DocumentSelection? get nodeSelection => _nodeSelection;

  @override
  set nodeSelection(DocumentSelection? value) {
    if (_nodeSelection == value) return;
    _nodeSelection = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // Public properties — described in debugFillProperties below.
  // ---------------------------------------------------------------------------

  /// The color of the horizontal rule line.
  // ignore: diagnostic_describe_all_properties
  Color get color => _color;

  /// Sets the color and schedules a repaint.
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  /// The stroke thickness of the rule in logical pixels.
  // ignore: diagnostic_describe_all_properties
  double get thickness => _thickness;

  /// Sets the thickness and schedules a layout pass.
  set thickness(double value) {
    if (_thickness == value) return;
    _thickness = value;
    markNeedsLayout();
  }

  /// Space added above and below the rule line.
  // ignore: diagnostic_describe_all_properties
  double get verticalPadding => _verticalPadding;

  /// Sets the vertical padding and schedules a layout pass.
  set verticalPadding(double value) {
    if (_verticalPadding == value) return;
    _verticalPadding = value;
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
  /// When non-null, [performLayout] uses this value as the block width instead
  /// of [constraints.maxWidth].  When `null`, the block fills the available
  /// width.
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
  /// When non-null, [performLayout] uses this value as the block height instead
  /// of [thickness] + 2 × [verticalPadding].  When `null`, the default height
  /// formula applies.
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
  // Intrinsic sizes
  // ---------------------------------------------------------------------------

  @override
  double computeMinIntrinsicHeight(double width) => _thickness + 2 * _verticalPadding;

  @override
  double computeMaxIntrinsicHeight(double width) => _thickness + 2 * _verticalPadding;

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    final w = _requestedWidth ?? constraints.maxWidth;
    final h = _requestedHeight ?? (_thickness + 2 * _verticalPadding);
    size = Size(w, h);
  }

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    // Paint selection highlight if active.
    if (_nodeSelection != null) {
      final selPaint = Paint()..color = const Color(0x663399FF);
      canvas.drawRect(offset & size, selPaint);
    }

    // Paint the horizontal rule line centered vertically.
    final lineY = offset.dy + _verticalPadding + _thickness / 2;
    final linePaint = Paint()
      ..color = _color
      ..strokeWidth = _thickness
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(offset.dx, lineY),
      Offset(offset.dx + size.width, lineY),
      linePaint,
    );
  }

  // ---------------------------------------------------------------------------
  // RenderDocumentBlock — geometry queries
  // ---------------------------------------------------------------------------

  @override
  Rect getLocalRectForPosition(NodePosition position) {
    // Both upstream and downstream map to the full block rect for this node type.
    return Offset.zero & size;
  }

  @override
  NodePosition getPositionAtOffset(Offset localOffset) {
    if (localOffset.dx < size.width / 2) {
      return const BinaryNodePosition.upstream();
    } else {
      return const BinaryNodePosition.downstream();
    }
  }

  @override
  List<Rect> getEndpointsForSelection(NodePosition base, NodePosition extent) {
    return [Offset.zero & size];
  }

  // ---------------------------------------------------------------------------
  // Semantics
  // ---------------------------------------------------------------------------

  /// Configures this block as a semantics boundary labelled `'Horizontal rule'`.
  ///
  /// Setting [SemanticsConfiguration.isSemanticBoundary] to `true` ensures
  /// that assistive technologies treat the rule as a self-contained element
  /// rather than merging it with surrounding content.
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.label = 'Horizontal rule';
    config.textDirection = TextDirection.ltr;
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('color', _color));
    properties.add(DoubleProperty('thickness', _thickness));
    properties.add(DoubleProperty('verticalPadding', _verticalPadding));
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
