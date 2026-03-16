/// Horizontal rule render object for the editable_document rendering layer.
///
/// Provides [RenderHorizontalRuleBlock], a [RenderDocumentBlock] that draws a
/// simple horizontal divider line.
library;

import 'package:flutter/rendering.dart';

import '../model/block_alignment.dart';
import '../model/document_selection.dart';
import '../model/node_position.dart';
import '../model/text_wrap_mode.dart';
import 'block_layout_mixin.dart';
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
class RenderHorizontalRuleBlock extends RenderDocumentBlock with BlockLayoutMixin {
  /// Creates a [RenderHorizontalRuleBlock].
  ///
  /// [color] defaults to a mid-grey.
  /// [thickness] defaults to `1.0`.
  /// [verticalPadding] defaults to `8.0`.
  /// [blockAlignment] controls horizontal positioning within the available
  /// layout width; defaults to [BlockAlignment.stretch].
  /// [requestedWidth] overrides the layout width when non-null.
  /// [requestedHeight] overrides the layout height when non-null.
  /// [textWrap] controls how surrounding text interacts with this block;
  /// defaults to [TextWrapMode.none].
  RenderHorizontalRuleBlock({
    required String nodeId,
    Color color = const Color(0xFFCCCCCC),
    double thickness = 1.0,
    double verticalPadding = 8.0,
    BlockAlignment blockAlignment = BlockAlignment.stretch,
    double? requestedWidth,
    double? requestedHeight,
    TextWrapMode textWrap = TextWrapMode.none,
  })  : _nodeId = nodeId,
        _color = color,
        _thickness = thickness,
        _verticalPadding = verticalPadding {
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

  String _nodeId;
  Color _color;
  double _thickness;
  double _verticalPadding;
  DocumentSelection? _nodeSelection;
  double? _spaceBefore;
  double? _spaceAfter;

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

  /// Returns `true` when no explicit [requestedWidth] is set, indicating
  /// this rule wants to fill the full available width and should clear any
  /// active float exclusion zone.
  @override
  bool get clearsFloat => requestedWidth == null;

  /// Extra space before this block in logical pixels, or `null` for default.
  ///
  /// When non-null, [RenderDocumentLayout] uses this value instead of
  /// [RenderDocumentLayout.blockSpacing] for the gap above this block.
  @override
  // ignore: diagnostic_describe_all_properties
  double? get spaceBefore => _spaceBefore;

  /// Sets [spaceBefore] and notifies the parent layout when the value changes.
  set spaceBefore(double? value) {
    if (_spaceBefore == value) return;
    _spaceBefore = value;
    if (parent is RenderObject) (parent!).markNeedsLayout();
  }

  /// Extra space after this block in logical pixels, or `null` for default.
  ///
  /// When non-null, [RenderDocumentLayout] uses this value instead of
  /// [RenderDocumentLayout.blockSpacing] for the gap below this block.
  @override
  // ignore: diagnostic_describe_all_properties
  double? get spaceAfter => _spaceAfter;

  /// Sets [spaceAfter] and notifies the parent layout when the value changes.
  set spaceAfter(double? value) {
    if (_spaceAfter == value) return;
    _spaceAfter = value;
    if (parent is RenderObject) (parent!).markNeedsLayout();
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
    final w = requestedWidth ?? constraints.maxWidth;
    final h = requestedHeight ?? (_thickness + 2 * _verticalPadding);
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
    properties.add(DoubleProperty('spaceBefore', _spaceBefore, defaultValue: null));
    properties.add(DoubleProperty('spaceAfter', _spaceAfter, defaultValue: null));
    debugFillBlockLayoutProperties(properties);
  }
}
