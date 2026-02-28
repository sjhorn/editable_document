/// Paragraph render object for the editable_document rendering layer.
///
/// Provides [RenderParagraphBlock], which extends [RenderTextBlock] with
/// heading-level scaling and blockquote styling.
library;

import 'package:flutter/rendering.dart';

import '../model/paragraph_node.dart';
import 'render_text_block.dart';

/// A [RenderTextBlock] for paragraph nodes with heading-level styling.
///
/// The [blockType] controls the effective font size relative to the
/// [baseTextStyle]:
///
/// | Block type   | Font scale      |
/// |--------------|-----------------|
/// | `paragraph`  | 1.0×            |
/// | `header1`    | 2.0× bold       |
/// | `header2`    | 1.5× bold       |
/// | `header3`    | 1.17× bold      |
/// | `header4`    | 1.0× bold       |
/// | `header5`    | 0.83× bold      |
/// | `header6`    | 0.67× bold      |
/// | `blockquote` | 1.0× italic     |
/// | `codeBlock`  | 1.0× monospace  |
///
/// Changing [blockType] calls [markNeedsLayout] automatically.
class RenderParagraphBlock extends RenderTextBlock {
  /// Creates a [RenderParagraphBlock].
  ///
  /// [blockType] defaults to [ParagraphBlockType.paragraph].
  /// [baseTextStyle] is the base style before heading scaling is applied.
  /// All other parameters are forwarded to [RenderTextBlock].
  RenderParagraphBlock({
    required super.nodeId,
    required super.text,
    ParagraphBlockType blockType = ParagraphBlockType.paragraph,
    TextStyle? baseTextStyle,
    super.textDirection,
    super.textAlign,
    super.selectionColor,
  })  : _blockType = blockType,
        _baseTextStyle = baseTextStyle ?? const TextStyle() {
    // Apply the initial computed style.
    super.textStyle = _computeTextStyle();
  }

  // ---------------------------------------------------------------------------
  // Private state
  // ---------------------------------------------------------------------------

  ParagraphBlockType _blockType;
  TextStyle _baseTextStyle;

  // ---------------------------------------------------------------------------
  // Public properties — described in debugFillProperties below.
  // ---------------------------------------------------------------------------

  /// The semantic block type of this paragraph.
  // ignore: diagnostic_describe_all_properties
  ParagraphBlockType get blockType => _blockType;

  /// Sets the block type and schedules a layout pass.
  set blockType(ParagraphBlockType value) {
    if (_blockType == value) return;
    _blockType = value;
    super.textStyle = _computeTextStyle();
    // markNeedsLayout is called by the super setter above.
  }

  /// The base [TextStyle] before heading-level scaling.
  // ignore: diagnostic_describe_all_properties
  TextStyle get baseTextStyle => _baseTextStyle;

  /// Sets the base style and recomputes the effective text style.
  set baseTextStyle(TextStyle value) {
    if (_baseTextStyle == value) return;
    _baseTextStyle = value;
    super.textStyle = _computeTextStyle();
  }

  // ---------------------------------------------------------------------------
  // Computed style
  // ---------------------------------------------------------------------------

  /// Returns the [TextStyle] for the current [blockType].
  TextStyle _computeTextStyle() {
    final base = _baseTextStyle;
    final baseFontSize = base.fontSize ?? 16.0;

    switch (_blockType) {
      case ParagraphBlockType.header1:
        return base.copyWith(fontSize: baseFontSize * 2.0, fontWeight: FontWeight.bold);
      case ParagraphBlockType.header2:
        return base.copyWith(fontSize: baseFontSize * 1.5, fontWeight: FontWeight.bold);
      case ParagraphBlockType.header3:
        return base.copyWith(fontSize: baseFontSize * 1.17, fontWeight: FontWeight.bold);
      case ParagraphBlockType.header4:
        return base.copyWith(fontSize: baseFontSize * 1.0, fontWeight: FontWeight.bold);
      case ParagraphBlockType.header5:
        return base.copyWith(fontSize: baseFontSize * 0.83, fontWeight: FontWeight.bold);
      case ParagraphBlockType.header6:
        return base.copyWith(fontSize: baseFontSize * 0.67, fontWeight: FontWeight.bold);
      case ParagraphBlockType.blockquote:
        return base.copyWith(fontStyle: FontStyle.italic);
      case ParagraphBlockType.codeBlock:
        return base.copyWith(fontFamily: 'monospace');
      case ParagraphBlockType.paragraph:
        return base;
    }
  }

  // ---------------------------------------------------------------------------
  // Paint — blockquote border
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_blockType == ParagraphBlockType.blockquote) {
      _paintBlockquoteBorder(context.canvas, offset);
    }
    super.paint(context, offset);
  }

  void _paintBlockquoteBorder(Canvas canvas, Offset offset) {
    const borderWidth = 3.0;
    final paint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(offset.dx, offset.dy, borderWidth, size.height),
      paint,
    );
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty('blockType', _blockType));
    properties.add(DiagnosticsProperty('baseTextStyle', _baseTextStyle));
  }
}
