/// TextPainter-based render object for attributed text document blocks.
///
/// This file provides [RenderTextBlock], the concrete [RenderDocumentBlock]
/// implementation used for paragraph, list-item, and code-block nodes.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../model/attributed_text.dart';
import '../model/attribution.dart';
import '../model/document_selection.dart';
import '../model/node_position.dart';
import 'render_document_block.dart';

/// A [RenderDocumentBlock] that renders [AttributedText] using a [TextPainter].
///
/// Handles text layout, selection-highlight rectangles, and cursor
/// positioning.  This is the base for [RenderParagraphBlock],
/// [RenderListItemBlock], and [RenderCodeBlock].
///
/// ## Attribution → TextStyle mapping
///
/// | [NamedAttribution] | Applied [TextStyle] property              |
/// |--------------------|-------------------------------------------|
/// | `bold`             | `fontWeight: FontWeight.bold`             |
/// | `italics`          | `fontStyle: FontStyle.italic`             |
/// | `underline`        | `decoration: TextDecoration.underline`    |
/// | `strikethrough`    | `decoration: TextDecoration.lineThrough`  |
/// | `code`             | `fontFamily: 'monospace'`                 |
///
/// [LinkAttribution] is currently rendered unstyled (future: add color/underline).
class RenderTextBlock extends RenderDocumentBlock {
  /// Creates a [RenderTextBlock].
  ///
  /// [nodeId] must match the corresponding [DocumentNode.id].
  /// [text] is the attributed text to render.
  /// [textStyle] is the base style applied before attributions.
  /// [textDirection] defaults to [TextDirection.ltr].
  /// [textAlign] defaults to [TextAlign.start].
  /// [selectionColor] is the highlight color drawn behind selected text;
  ///   defaults to a semi-transparent blue.
  RenderTextBlock({
    required String nodeId,
    required AttributedText text,
    TextStyle? textStyle,
    TextDirection textDirection = TextDirection.ltr,
    TextAlign textAlign = TextAlign.start,
    Color selectionColor = const Color(0x663399FF),
  })  : _nodeId = nodeId,
        _text = text,
        _textStyle = textStyle ?? const TextStyle(),
        _textDirection = textDirection,
        _textAlign = textAlign,
        _selectionColor = selectionColor,
        _textPainter = TextPainter(
          textDirection: textDirection,
          textAlign: textAlign,
        );

  // ---------------------------------------------------------------------------
  // Private state
  // ---------------------------------------------------------------------------

  String _nodeId;
  AttributedText _text;
  TextStyle _textStyle;
  TextDirection _textDirection;
  TextAlign _textAlign;
  Color _selectionColor;
  DocumentSelection? _nodeSelection;

  final TextPainter _textPainter;

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

  /// The attributed text displayed by this block.
  // ignore: diagnostic_describe_all_properties
  AttributedText get text => _text;

  /// Sets the text and schedules a layout pass.
  set text(AttributedText value) {
    if (_text == value) return;
    _text = value;
    markNeedsLayout();
  }

  /// The base [TextStyle] applied to the entire text before attributions.
  // ignore: diagnostic_describe_all_properties
  TextStyle get textStyle => _textStyle;

  /// Sets the base style and schedules a layout pass.
  set textStyle(TextStyle value) {
    if (_textStyle == value) return;
    _textStyle = value;
    markNeedsLayout();
  }

  /// The reading direction of this block.
  // ignore: diagnostic_describe_all_properties
  TextDirection get textDirection => _textDirection;

  /// Sets the text direction and schedules a layout pass.
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _textPainter.textDirection = value;
    markNeedsLayout();
  }

  /// The horizontal alignment of text within this block.
  // ignore: diagnostic_describe_all_properties
  TextAlign get textAlign => _textAlign;

  /// Sets the text alignment and schedules a layout pass.
  set textAlign(TextAlign value) {
    if (_textAlign == value) return;
    _textAlign = value;
    _textPainter.textAlign = value;
    markNeedsLayout();
  }

  /// The background color painted behind selected text.
  // ignore: diagnostic_describe_all_properties
  Color get selectionColor => _selectionColor;

  /// Sets the selection highlight color and schedules a repaint.
  set selectionColor(Color value) {
    if (_selectionColor == value) return;
    _selectionColor = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    _layoutText(constraints.maxWidth);
    size = Size(constraints.maxWidth, _textPainter.height);
  }

  /// Returns the distance from the top of this block to the text baseline.
  ///
  /// Mirrors [RenderEditable.computeDistanceToActualBaseline]: it lays out the
  /// [TextPainter] if needed (safe to call before [performLayout] completes)
  /// and then delegates to [TextPainter.computeDistanceToActualBaseline].
  ///
  /// This allows [InputDecorator] and other baseline-aware ancestors to align
  /// hint text with the first line of the document content.
  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    _layoutText(constraints.maxWidth);
    return _textPainter.computeDistanceToActualBaseline(baseline);
  }

  /// Returns the speculative baseline distance for the given [constraints].
  ///
  /// Lays out the [TextPainter] at [constraints.maxWidth] without mutating
  /// this render object's current [size], satisfying the "dry" contract.
  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    // Create a temporary painter with the same span and configuration to
    // compute the baseline without touching this render object's live state.
    final painter = TextPainter(
      text: _buildTextSpan(),
      textDirection: _textDirection,
      textAlign: _textAlign,
    )..layout(maxWidth: constraints.maxWidth);
    return painter.computeDistanceToActualBaseline(baseline);
  }

  // ---------------------------------------------------------------------------
  // Protected helpers for subclasses
  // ---------------------------------------------------------------------------

  /// Lays out the internal [TextPainter] with [textMaxWidth] as the maximum
  /// line width.
  ///
  /// Subclasses that override [performLayout] to apply inset constraints
  /// (such as [RenderListItemBlock] and [RenderCodeBlock]) call this method
  /// to perform text layout without replicating the span-building logic.
  /// After calling this, [layoutTextHeight] is valid.
  @protected
  void layoutText(double textMaxWidth) => _layoutText(textMaxWidth);

  /// The height of the text content after the most recent [layoutText] or
  /// [performLayout] call.
  ///
  /// Only valid after layout. Subclasses use this to compute [size].
  @protected
  // ignore: diagnostic_describe_all_properties
  double get layoutTextHeight => _textPainter.height;

  void _layoutText(double maxWidth) {
    _textPainter.text = _buildTextSpan();
    _textPainter.layout(maxWidth: maxWidth);
  }

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    // Paint selection highlights behind the text.
    if (_nodeSelection != null) {
      _paintSelectionHighlight(context.canvas, offset);
    }
    _textPainter.paint(context.canvas, offset);
  }

  void _paintSelectionHighlight(Canvas canvas, Offset offset) {
    final sel = _nodeSelection;
    if (sel == null) return;

    final basePos = sel.base.nodePosition;
    final extentPos = sel.extent.nodePosition;
    if (basePos is! TextNodePosition || extentPos is! TextNodePosition) return;

    final rects = getEndpointsForSelection(basePos, extentPos);
    final paint = Paint()..color = _selectionColor;
    for (final r in rects) {
      canvas.drawRect(r.shift(offset), paint);
    }
  }

  // ---------------------------------------------------------------------------
  // RenderDocumentBlock — geometry queries
  // ---------------------------------------------------------------------------

  @override
  Rect getLocalRectForPosition(NodePosition position) {
    assert(position is TextNodePosition, 'RenderTextBlock expects TextNodePosition');
    final tp = position as TextNodePosition;
    final textPosition = TextPosition(offset: tp.offset, affinity: tp.affinity);
    final caretOffset = _textPainter.getOffsetForCaret(textPosition, Rect.zero);
    return Rect.fromLTWH(caretOffset.dx, caretOffset.dy, 0, _textPainter.preferredLineHeight);
  }

  @override
  NodePosition getPositionAtOffset(Offset localOffset) {
    final tp = _textPainter.getPositionForOffset(localOffset);
    return TextNodePosition(offset: tp.offset, affinity: tp.affinity);
  }

  /// Returns the [TextRange] spanning the visual line that contains [position].
  ///
  /// Delegates to [TextPainter.getLineBoundary] which uses the laid-out text
  /// metrics, so this render object must be laid out before calling this
  /// method.
  TextRange getLineBoundary(TextNodePosition position) {
    final tp = TextPosition(offset: position.offset, affinity: position.affinity);
    return _textPainter.getLineBoundary(tp);
  }

  @override
  List<Rect> getEndpointsForSelection(NodePosition base, NodePosition extent) {
    assert(
      base is TextNodePosition && extent is TextNodePosition,
      'RenderTextBlock expects TextNodePosition for both base and extent',
    );
    final b = base as TextNodePosition;
    final e = extent as TextNodePosition;

    if (b.offset == e.offset) return const [];

    final start = b.offset < e.offset ? b.offset : e.offset;
    final end = b.offset < e.offset ? e.offset : b.offset;

    final boxes = _textPainter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    return boxes.map((box) => box.toRect()).toList();
  }

  // ---------------------------------------------------------------------------
  // Attribution → TextSpan
  // ---------------------------------------------------------------------------

  /// Converts [_text] and its attributions into an [InlineSpan] tree suitable
  /// for [TextPainter].
  ///
  /// When no attributions are present a single [TextSpan] is returned.
  /// Otherwise the text is split into runs at attribution boundaries and each
  /// run receives a merged [TextStyle].
  TextSpan _buildTextSpan() {
    final rawText = _text.text;
    if (rawText.isEmpty) {
      return TextSpan(text: '', style: _textStyle);
    }

    final spans = _text.getAttributionSpansInRange(0, rawText.length - 1).toList();
    if (spans.isEmpty) {
      return TextSpan(text: rawText, style: _textStyle);
    }

    // Collect all boundary offsets.
    final boundaries = <int>{0, rawText.length};
    for (final span in spans) {
      boundaries.add(span.start);
      boundaries.add(span.end + 1);
    }
    final sortedBoundaries = boundaries.toList()..sort();

    final children = <InlineSpan>[];
    for (var i = 0; i < sortedBoundaries.length - 1; i++) {
      final start = sortedBoundaries[i];
      final end = sortedBoundaries[i + 1];
      if (start >= rawText.length) break;

      final activeAttributions = _text.getAttributionsAt(start);
      final style = _buildStyleForAttributions(activeAttributions);
      children.add(TextSpan(text: rawText.substring(start, end), style: style));
    }

    return TextSpan(style: _textStyle, children: children);
  }

  /// Merges a set of [Attribution]s into a single [TextStyle].
  TextStyle _buildStyleForAttributions(Set<Attribution> attributions) {
    var style = const TextStyle();
    final decorations = <TextDecoration>[];

    for (final attribution in attributions) {
      if (attribution == NamedAttribution.bold) {
        style = style.copyWith(fontWeight: FontWeight.bold);
      } else if (attribution == NamedAttribution.italics) {
        style = style.copyWith(fontStyle: FontStyle.italic);
      } else if (attribution == NamedAttribution.underline) {
        decorations.add(TextDecoration.underline);
      } else if (attribution == NamedAttribution.strikethrough) {
        decorations.add(TextDecoration.lineThrough);
      } else if (attribution == NamedAttribution.code) {
        style = style.copyWith(fontFamily: 'monospace');
      }
      // LinkAttribution is intentionally not styled here — the widget layer
      // is responsible for tappable link rendering.
    }

    if (decorations.isNotEmpty) {
      style = style.copyWith(
        decoration: TextDecoration.combine(decorations),
      );
    }

    return style;
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('nodeId', _nodeId));
    properties.add(DiagnosticsProperty('text', _text));
    properties.add(DiagnosticsProperty('textStyle', _textStyle));
    properties.add(EnumProperty('textDirection', _textDirection));
    properties.add(EnumProperty('textAlign', _textAlign));
    properties.add(ColorProperty('selectionColor', _selectionColor));
  }
}
