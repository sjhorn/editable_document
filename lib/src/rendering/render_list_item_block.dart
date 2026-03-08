/// List-item render object for the editable_document rendering layer.
///
/// Provides [RenderListItemBlock], which extends [RenderTextBlock] with
/// bullet or ordinal-number markers and indentation.
library;

import 'package:flutter/rendering.dart';

import '../model/list_item_node.dart';
import '../model/node_position.dart';
import 'render_text_block.dart';

/// Width reserved for the list marker (bullet or number) at each indent level.
const double _kMarkerWidth = 24.0;

/// A [RenderTextBlock] that renders a list item with a bullet or ordinal number.
///
/// The text content is offset to the right by [_kMarkerWidth] × ([indent] + 1)
/// to make room for the marker.  The marker itself is painted before the text
/// during [paint].
///
/// ## Marker rendering
///
/// | [ListItemType]  | Marker                                    |
/// |-----------------|-------------------------------------------|
/// | `unordered`     | `'•'` (U+2022 BULLET)                     |
/// | `ordered`       | `'<ordinalIndex>.'` (e.g. `'1.'`, `'2.'`) |
class RenderListItemBlock extends RenderTextBlock {
  /// Creates a [RenderListItemBlock].
  ///
  /// [type] controls whether a bullet or number is drawn.
  /// [indent] is the nesting depth (0 = top level).
  /// [ordinalIndex] is the 1-based position in an ordered list.
  RenderListItemBlock({
    required super.nodeId,
    required super.text,
    ListItemType type = ListItemType.unordered,
    int indent = 0,
    int ordinalIndex = 1,
    super.textStyle,
    super.textDirection,
    super.textAlign,
    super.selectionColor,
  })  : _type = type,
        _indent = indent,
        _ordinalIndex = ordinalIndex;

  // ---------------------------------------------------------------------------
  // Private state
  // ---------------------------------------------------------------------------

  ListItemType _type;
  int _indent;
  int _ordinalIndex;

  // ---------------------------------------------------------------------------
  // Public properties — described in debugFillProperties below.
  // ---------------------------------------------------------------------------

  /// Whether this is an ordered or unordered list item.
  // ignore: diagnostic_describe_all_properties
  ListItemType get type => _type;

  /// Sets the list type and schedules a repaint.
  set type(ListItemType value) {
    if (_type == value) return;
    _type = value;
    markNeedsPaint();
  }

  /// The nesting depth of this list item (0 = top level).
  // ignore: diagnostic_describe_all_properties
  int get indent => _indent;

  /// Sets the indent level and schedules a layout pass.
  set indent(int value) {
    if (_indent == value) return;
    _indent = value;
    markNeedsLayout();
  }

  /// The 1-based position of this item in an ordered list.
  ///
  /// Ignored for [ListItemType.unordered] items.
  // ignore: diagnostic_describe_all_properties
  int get ordinalIndex => _ordinalIndex;

  /// Sets the ordinal index and schedules a repaint.
  set ordinalIndex(int value) {
    if (_ordinalIndex == value) return;
    _ordinalIndex = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Horizontal offset at which the text content starts.
  double get _textIndentOffset => _kMarkerWidth * (_indent + 1);

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    // Layout the text in the remaining width after the marker area.
    final textMaxWidth = (constraints.maxWidth - _textIndentOffset).clamp(0.0, double.infinity);
    final excl = exclusionRectForLayout(horizontalInset: _textIndentOffset);
    layoutText(textMaxWidth, exclusionRect: excl);
    size = Size(constraints.maxWidth, layoutTextHeight);
  }

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    // Paint the bullet/number marker.
    _paintMarker(context.canvas, offset);
    // Paint selection highlights and text at the indented position.
    super.paint(context, offset.translate(_textIndentOffset, 0));
  }

  void _paintMarker(Canvas canvas, Offset blockOffset) {
    final markerText = _type == ListItemType.unordered ? '\u2022' : '$_ordinalIndex.';
    final markerPainter = TextPainter(
      text: TextSpan(text: markerText, style: textStyle),
      textDirection: textDirection,
    )..layout();

    final markerX = _textIndentOffset - markerPainter.width - 4.0;
    final markerY = (size.height - markerPainter.height) / 2;
    markerPainter.paint(canvas, blockOffset.translate(markerX, markerY));
  }

  // ---------------------------------------------------------------------------
  // Geometry queries — adjust for text indent
  // ---------------------------------------------------------------------------

  @override
  Rect getLocalRectForPosition(NodePosition position) {
    return super.getLocalRectForPosition(position).translate(_textIndentOffset, 0);
  }

  @override
  NodePosition getPositionAtOffset(Offset localOffset) {
    // Remove the indent before delegating to the text painter so that the
    // returned position refers to the correct character rather than a position
    // shifted by the marker gutter.
    return super.getPositionAtOffset(localOffset.translate(-_textIndentOffset, 0));
  }

  @override
  List<Rect> getEndpointsForSelection(NodePosition base, NodePosition extent) {
    return super
        .getEndpointsForSelection(base, extent)
        .map((r) => r.translate(_textIndentOffset, 0))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty('type', _type));
    properties.add(IntProperty('indent', _indent));
    properties.add(IntProperty('ordinalIndex', _ordinalIndex));
  }
}
