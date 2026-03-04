/// TextPainter-based render object for attributed text document blocks.
///
/// This file provides [RenderTextBlock], the concrete [RenderDocumentBlock]
/// implementation used for paragraph, list-item, and code-block nodes.
library;

import 'dart:ui' as ui show BoxHeightStyle;

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
/// | Attribution                   | Applied [TextStyle] property              |
/// |-------------------------------|-------------------------------------------|
/// | [NamedAttribution.bold]       | `fontWeight: FontWeight.bold`             |
/// | [NamedAttribution.italics]    | `fontStyle: FontStyle.italic`             |
/// | [NamedAttribution.underline]  | `decoration: TextDecoration.underline`    |
/// | [NamedAttribution.strikethrough] | `decoration: TextDecoration.lineThrough` |
/// | [NamedAttribution.code]       | `fontFamily: 'monospace'`                 |
/// | [FontFamilyAttribution]       | `fontFamily: attribution.fontFamily`      |
/// | [FontSizeAttribution]         | `fontSize: attribution.fontSize`          |
/// | [TextColorAttribution]        | `color: Color(attribution.colorValue)`    |
/// | [BackgroundColorAttribution]  | `backgroundColor: Color(attribution.colorValue)` |
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
  // Semantics state
  // ---------------------------------------------------------------------------

  bool _isFocused = false;
  bool _isReadOnly = false;
  MoveCursorHandler? _onSemanticsMoveCursorForwardByCharacter;
  MoveCursorHandler? _onSemanticsMoveCursorBackwardByCharacter;
  MoveCursorHandler? _onSemanticsMoveCursorForwardByWord;
  MoveCursorHandler? _onSemanticsMoveCursorBackwardByWord;
  SetTextHandler? _onSemanticsSetText;
  SetSelectionHandler? _onSemanticsSetSelection;

  /// Whether this block currently holds the input focus.
  ///
  /// When `true` and [isReadOnly] is `false`, the semantics node is
  /// annotated as a focused, editable text field.  When `true` and
  /// [isReadOnly] is also `true`, only [SemanticsConfiguration.isFocused] is
  /// set.  Changing this value calls [markNeedsSemanticsUpdate].
  // ignore: diagnostic_describe_all_properties
  bool get isFocused => _isFocused;

  /// Sets [isFocused] and schedules a semantics update.
  set isFocused(bool value) {
    if (_isFocused == value) return;
    _isFocused = value;
    markNeedsSemanticsUpdate();
  }

  /// Whether this block should be treated as read-only by the accessibility
  /// system.
  ///
  /// When `true`, [SemanticsConfiguration.isReadOnly] is set and the block is
  /// not announced as an editable text field.  Changing this value calls
  /// [markNeedsSemanticsUpdate].
  // ignore: diagnostic_describe_all_properties
  bool get isReadOnly => _isReadOnly;

  /// Sets [isReadOnly] and schedules a semantics update.
  set isReadOnly(bool value) {
    if (_isReadOnly == value) return;
    _isReadOnly = value;
    markNeedsSemanticsUpdate();
  }

  /// Handler invoked by the accessibility system to move the cursor forward by
  /// one character.
  ///
  /// When non-null, [SemanticsConfiguration.onMoveCursorForwardByCharacter] is
  /// set to this handler.  Changing this value calls
  /// [markNeedsSemanticsUpdate].
  // ignore: diagnostic_describe_all_properties
  MoveCursorHandler? get onSemanticsMoveCursorForwardByCharacter =>
      _onSemanticsMoveCursorForwardByCharacter;

  /// Sets [onSemanticsMoveCursorForwardByCharacter] and schedules a semantics
  /// update.
  set onSemanticsMoveCursorForwardByCharacter(MoveCursorHandler? value) {
    if (_onSemanticsMoveCursorForwardByCharacter == value) return;
    _onSemanticsMoveCursorForwardByCharacter = value;
    markNeedsSemanticsUpdate();
  }

  /// Handler invoked by the accessibility system to move the cursor backward by
  /// one character.
  ///
  /// When non-null, [SemanticsConfiguration.onMoveCursorBackwardByCharacter]
  /// is set to this handler.  Changing this value calls
  /// [markNeedsSemanticsUpdate].
  // ignore: diagnostic_describe_all_properties
  MoveCursorHandler? get onSemanticsMoveCursorBackwardByCharacter =>
      _onSemanticsMoveCursorBackwardByCharacter;

  /// Sets [onSemanticsMoveCursorBackwardByCharacter] and schedules a semantics
  /// update.
  set onSemanticsMoveCursorBackwardByCharacter(MoveCursorHandler? value) {
    if (_onSemanticsMoveCursorBackwardByCharacter == value) return;
    _onSemanticsMoveCursorBackwardByCharacter = value;
    markNeedsSemanticsUpdate();
  }

  /// Handler invoked by the accessibility system to move the cursor forward by
  /// one word.
  ///
  /// When non-null, [SemanticsConfiguration.onMoveCursorForwardByWord] is set
  /// to this handler.  Changing this value calls [markNeedsSemanticsUpdate].
  // ignore: diagnostic_describe_all_properties
  MoveCursorHandler? get onSemanticsMoveCursorForwardByWord => _onSemanticsMoveCursorForwardByWord;

  /// Sets [onSemanticsMoveCursorForwardByWord] and schedules a semantics
  /// update.
  set onSemanticsMoveCursorForwardByWord(MoveCursorHandler? value) {
    if (_onSemanticsMoveCursorForwardByWord == value) return;
    _onSemanticsMoveCursorForwardByWord = value;
    markNeedsSemanticsUpdate();
  }

  /// Handler invoked by the accessibility system to move the cursor backward by
  /// one word.
  ///
  /// When non-null, [SemanticsConfiguration.onMoveCursorBackwardByWord] is set
  /// to this handler.  Changing this value calls [markNeedsSemanticsUpdate].
  // ignore: diagnostic_describe_all_properties
  MoveCursorHandler? get onSemanticsMoveCursorBackwardByWord =>
      _onSemanticsMoveCursorBackwardByWord;

  /// Sets [onSemanticsMoveCursorBackwardByWord] and schedules a semantics
  /// update.
  set onSemanticsMoveCursorBackwardByWord(MoveCursorHandler? value) {
    if (_onSemanticsMoveCursorBackwardByWord == value) return;
    _onSemanticsMoveCursorBackwardByWord = value;
    markNeedsSemanticsUpdate();
  }

  /// Handler invoked by the accessibility system to replace the text content.
  ///
  /// When non-null, [SemanticsConfiguration.onSetText] is set to this handler.
  /// Changing this value calls [markNeedsSemanticsUpdate].
  // ignore: diagnostic_describe_all_properties
  SetTextHandler? get onSemanticsSetText => _onSemanticsSetText;

  /// Sets [onSemanticsSetText] and schedules a semantics update.
  set onSemanticsSetText(SetTextHandler? value) {
    if (_onSemanticsSetText == value) return;
    _onSemanticsSetText = value;
    markNeedsSemanticsUpdate();
  }

  /// Handler invoked by the accessibility system to replace the text selection.
  ///
  /// When non-null, [SemanticsConfiguration.onSetSelection] is set to this
  /// handler.  Changing this value calls [markNeedsSemanticsUpdate].
  // ignore: diagnostic_describe_all_properties
  SetSelectionHandler? get onSemanticsSetSelection => _onSemanticsSetSelection;

  /// Sets [onSemanticsSetSelection] and schedules a semantics update.
  set onSemanticsSetSelection(SetSelectionHandler? value) {
    if (_onSemanticsSetSelection == value) return;
    _onSemanticsSetSelection = value;
    markNeedsSemanticsUpdate();
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
  /// Lays out the [TextPainter] at `constraints.maxWidth` without mutating
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
    final span = _buildTextSpan();
    // TextSpan.== doesn't compare children, so TextPainter.text setter may
    // skip the update when only child spans changed (e.g. a new font
    // attribution). Clear first to guarantee the painter accepts the new span.
    _textPainter.text = null;
    _textPainter.text = span;
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

    // Use a 1-char selection with BoxHeightStyle.max to get the actual line
    // height, which accounts for mixed fonts on the same line.
    final textLength = _text.text.length;
    if (textLength > 0) {
      final start = tp.offset >= textLength ? textLength - 1 : tp.offset;
      final end = start + 1;
      final boxes = _textPainter.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      if (boxes.isNotEmpty) {
        final box = boxes.first.toRect();
        return Rect.fromLTWH(caretOffset.dx, box.top, 0, box.height);
      }
    }

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
      boxHeightStyle: ui.BoxHeightStyle.max,
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
      } else if (attribution is FontFamilyAttribution) {
        // Explicit font family overrides the code monospace, so this branch
        // is placed after the code check.
        style = style.copyWith(fontFamily: attribution.fontFamily);
      } else if (attribution is FontSizeAttribution) {
        style = style.copyWith(fontSize: attribution.fontSize);
      } else if (attribution is TextColorAttribution) {
        style = style.copyWith(color: Color(attribution.colorValue));
      } else if (attribution is BackgroundColorAttribution) {
        style = style.copyWith(backgroundColor: Color(attribution.colorValue));
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
  // Semantics
  // ---------------------------------------------------------------------------

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    config.isSemanticBoundary = true;
    config.attributedValue = AttributedString(_text.text);
    config.textDirection = _textDirection;
    config.isMultiline = true;

    if (_isFocused) {
      config.isFocused = true;
    }

    if (_isReadOnly) {
      config.isReadOnly = true;
    }

    if (_isFocused && !_isReadOnly) {
      config.isTextField = true;
      // Marking isFocused as non-null (true) signals focusability to the
      // semantics system (the deprecated isFocusable setter is not used).
    }

    if (_onSemanticsSetText != null) {
      config.onSetText = _onSemanticsSetText;
    }
    if (_onSemanticsSetSelection != null) {
      config.onSetSelection = _onSemanticsSetSelection;
    }
    if (_onSemanticsMoveCursorForwardByCharacter != null) {
      config.onMoveCursorForwardByCharacter = _onSemanticsMoveCursorForwardByCharacter;
    }
    if (_onSemanticsMoveCursorBackwardByCharacter != null) {
      config.onMoveCursorBackwardByCharacter = _onSemanticsMoveCursorBackwardByCharacter;
    }
    if (_onSemanticsMoveCursorForwardByWord != null) {
      config.onMoveCursorForwardByWord = _onSemanticsMoveCursorForwardByWord;
    }
    if (_onSemanticsMoveCursorBackwardByWord != null) {
      config.onMoveCursorBackwardByWord = _onSemanticsMoveCursorBackwardByWord;
    }
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
