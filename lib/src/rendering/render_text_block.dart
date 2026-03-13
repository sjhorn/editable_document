/// TextPainter-based render object for attributed text document blocks.
///
/// This file provides [RenderTextBlock], the concrete [RenderDocumentBlock]
/// implementation used for paragraph, list-item, and code-block nodes.
library;

import 'dart:math' show max;
import 'dart:ui' as ui show BoxHeightStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../model/attributed_text.dart';
import '../model/attribution.dart';
import '../model/document_selection.dart';
import '../model/node_position.dart';
import 'render_document_block.dart';
import 'render_document_layout.dart' show DocumentBlockConstraints;

/// Signature for a callback that builds a [TextSpan] from [AttributedText]
/// and a base [TextStyle].
///
/// Used by [RenderTextBlock.textSpanBuilder] to let callers override the
/// default attribution-based span building — for example to inject
/// syntax-highlighted spans from an external package.
typedef TextSpanBuilder = TextSpan Function(AttributedText text, TextStyle baseStyle);

// ---------------------------------------------------------------------------
// _ExclusionLayout — result of multi-segment exclusion-zone text layout
// ---------------------------------------------------------------------------

/// Holds the results of laying out text around a center-float exclusion zone.
///
/// Text is split into three zones:
/// - **above**: the text before the exclusion rectangle's top edge.
/// - **beside**: Z-pattern dual-column text alongside the exclusion rect.
/// - **below**: the remaining text after the exclusion rectangle's bottom.
class _ExclusionLayout {
  /// Creates an [_ExclusionLayout] with all computed zones.
  _ExclusionLayout({
    required this.abovePainter,
    required this.aboveEndIndex,
    required this.lines,
    required this.besideEndIndex,
    required this.belowPainter,
    required this.aboveHeight,
    required this.besideHeight,
    required this.belowHeight,
    required this.exclusionRect,
    required this.leftWidth,
    required this.rightWidth,
  });

  /// [TextPainter] for text above the exclusion zone, or `null` if none.
  final TextPainter? abovePainter;

  /// The character index where the above zone ends (exclusive).
  final int aboveEndIndex;

  /// The line pairs for the beside zone (left and right columns per line).
  final List<_LinePair> lines;

  /// The character index where the beside zone ends (exclusive).
  final int besideEndIndex;

  /// [TextPainter] for text below the exclusion zone, or `null` if none.
  final TextPainter? belowPainter;

  /// Total height of the above zone.
  final double aboveHeight;

  /// Total height of the beside zone (may be padded to match exclusion height).
  final double besideHeight;

  /// Total height of the below zone.
  final double belowHeight;

  /// The exclusion rectangle in child-local coordinates.
  final Rect exclusionRect;

  /// Width available for the left column beside the float.
  final double leftWidth;

  /// Width available for the right column beside the float.
  final double rightWidth;

  /// Total height of this block.
  double get totalHeight => aboveHeight + besideHeight + belowHeight;

  /// Releases all [TextPainter] resources.
  void dispose() {
    abovePainter?.dispose();
    for (final line in lines) {
      line.leftPainter.dispose();
      line.rightPainter.dispose();
    }
    belowPainter?.dispose();
  }
}

/// A pair of [TextPainter]s representing one visual line in the beside zone.
///
/// Each beside-zone line consists of a left column segment and a right column
/// segment, laid out at [leftWidth] and [rightWidth] respectively.
class _LinePair {
  /// Creates a [_LinePair] describing one row of the Z-pattern beside zone.
  _LinePair({
    required this.leftPainter,
    required this.rightPainter,
    required this.leftStartIndex,
    required this.leftEndIndex,
    required this.rightStartIndex,
    required this.rightEndIndex,
    required this.lineHeight,
    required this.yOffset,
  });

  /// [TextPainter] for the left column segment of this line.
  final TextPainter leftPainter;

  /// [TextPainter] for the right column segment of this line.
  final TextPainter rightPainter;

  /// Character start index (into original text) of the left segment.
  final int leftStartIndex;

  /// Character end index (exclusive, into original text) of the left segment.
  final int leftEndIndex;

  /// Character start index (into original text) of the right segment.
  final int rightStartIndex;

  /// Character end index (exclusive, into original text) of the right segment.
  final int rightEndIndex;

  /// Height of this line pair.
  final double lineHeight;

  /// Y offset from the top of the beside zone.
  final double yOffset;
}

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
    TextSpanBuilder? textSpanBuilder,
  })  : _nodeId = nodeId,
        _text = text,
        _textStyle = textStyle ?? const TextStyle(),
        _textDirection = textDirection,
        _textAlign = textAlign,
        _selectionColor = selectionColor,
        _textSpanBuilder = textSpanBuilder,
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
  TextSpanBuilder? _textSpanBuilder;
  DocumentSelection? _nodeSelection;

  final TextPainter _textPainter;

  /// Cached result of the most recent exclusion-zone layout pass, or `null`
  /// when no exclusion rect is active.
  _ExclusionLayout? _exclusionLayout;

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

  /// Optional callback to build a custom [TextSpan] from the attributed text.
  ///
  /// When non-null, this callback replaces the default attribution-based
  /// span building in [_buildTextSpan] and [_buildTextSpanForRange].
  /// This allows external packages (e.g. syntax highlighters) to provide
  /// pre-styled [TextSpan] trees without round-tripping through
  /// [AttributedText] attributions.
  // ignore: diagnostic_describe_all_properties
  TextSpanBuilder? get textSpanBuilder => _textSpanBuilder;

  /// Sets the text span builder and schedules a layout pass.
  set textSpanBuilder(TextSpanBuilder? value) {
    if (_textSpanBuilder == value) return;
    _textSpanBuilder = value;
    markNeedsLayout();
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
    final excl = exclusionRectForLayout();
    layoutText(constraints.maxWidth, exclusionRect: excl);
    size = Size(constraints.maxWidth, layoutTextHeight);
  }

  /// Performs multi-segment layout when [exclusionRect] is set.
  ///
  /// Splits the text into above/beside/below zones and computes a
  /// [_ExclusionLayout] used for painting and hit testing.
  void _performExclusionLayout(double maxWidth, Rect exclusionRect) {
    _exclusionLayout?.dispose();
    _exclusionLayout = null;

    final rawText = _text.text;
    final textLength = rawText.length;

    // Left and right column widths beside the float.
    final leftWidth = max(0.0, exclusionRect.left);
    final rightWidth = max(0.0, maxWidth - exclusionRect.right);

    // -------------------------------------------------------------------------
    // Zone 1: Above — text before the exclusion top.
    // -------------------------------------------------------------------------
    TextPainter? abovePainter;
    int aboveEndIndex = 0;
    double aboveHeight = 0.0;

    if (exclusionRect.top > 0 && textLength > 0) {
      // Lay out all text at full width to find the line boundary at exclusionRect.top.
      final tempFull = TextPainter(
        text: _buildTextSpan(),
        textDirection: _textDirection,
        textAlign: _textAlign,
      )..layout(maxWidth: maxWidth);

      // Find the character at exactly the exclusion top.
      final posAtTop = tempFull.getPositionForOffset(Offset(0, exclusionRect.top));
      // Get the line boundary to snap to a full line.
      final lineBound = tempFull.getLineBoundary(posAtTop);

      // aboveEndIndex is where the line starts at or just after exclusion top.
      // If exclusionRect.top is inside a line, we take the line's start
      // so that entire line goes into the above zone.
      aboveEndIndex = lineBound.start;

      // If the hit position is on the first line, use the end of that line
      // as the above boundary so we don't leave a zero-height above zone.
      if (aboveEndIndex == 0 && lineBound.end > 0) {
        // The exclusion starts in the middle of the first line — treat
        // aboveEndIndex as 0 (no above zone), and let beside start from 0.
        aboveEndIndex = 0;
      }

      tempFull.dispose();

      if (aboveEndIndex > 0) {
        abovePainter = TextPainter(
          text: _buildTextSpanForRange(0, aboveEndIndex),
          textDirection: _textDirection,
          textAlign: _textAlign,
        )..layout(maxWidth: maxWidth);
        aboveHeight = abovePainter.height;
      }
    }

    // -------------------------------------------------------------------------
    // Zone 2: Beside — Z-pattern dual-column layout.
    // -------------------------------------------------------------------------
    final lines = <_LinePair>[];
    int currentIndex = aboveEndIndex;
    double besideAccumHeight = 0.0;

    while (currentIndex < textLength) {
      // Stop if we've filled the beside zone height.
      if (besideAccumHeight >= exclusionRect.height) break;

      // Build left column line.
      final leftStartIndex = currentIndex;
      int leftEndIndex = currentIndex;
      double lineHeight = 0.0;

      if (leftWidth > 0 && currentIndex < textLength) {
        final tempLeft = TextPainter(
          text: _buildTextSpanForRange(currentIndex, textLength),
          textDirection: _textDirection,
          textAlign: _textAlign,
        )..layout(maxWidth: leftWidth);

        final leftBound = tempLeft.getLineBoundary(const TextPosition(offset: 0));
        final leftLineMetrics = tempLeft.computeLineMetrics();
        final leftLineHeight = leftLineMetrics.isNotEmpty
            ? leftLineMetrics.first.height
            : tempLeft.preferredLineHeight;

        leftEndIndex = currentIndex + leftBound.end;
        lineHeight = leftLineHeight;
        tempLeft.dispose();
      }

      // Build right column line (starting from where left ended).
      final rightStartIndex = leftEndIndex;
      int rightEndIndex = leftEndIndex;

      if (rightWidth > 0 && rightStartIndex < textLength) {
        final tempRight = TextPainter(
          text: _buildTextSpanForRange(rightStartIndex, textLength),
          textDirection: _textDirection,
          textAlign: _textAlign,
        )..layout(maxWidth: rightWidth);

        final rightBound = tempRight.getLineBoundary(const TextPosition(offset: 0));
        final rightLineMetrics = tempRight.computeLineMetrics();
        final rightLineHeight = rightLineMetrics.isNotEmpty
            ? rightLineMetrics.first.height
            : tempRight.preferredLineHeight;

        rightEndIndex = rightStartIndex + rightBound.end;
        if (rightLineHeight > lineHeight) {
          lineHeight = rightLineHeight;
        }
        tempRight.dispose();
      }

      if (lineHeight == 0.0) {
        // Fall back to a small positive height.
        lineHeight = 16.0;
      }

      // Build the painting painters for this line pair.
      final leftPainter = TextPainter(
        text: _buildTextSpanForRange(leftStartIndex, leftEndIndex),
        textDirection: _textDirection,
        textAlign: _textAlign,
      )..layout(maxWidth: leftWidth > 0 ? leftWidth : maxWidth);

      final rightPainter = TextPainter(
        text: _buildTextSpanForRange(rightStartIndex, rightEndIndex),
        textDirection: _textDirection,
        textAlign: _textAlign,
      )..layout(maxWidth: rightWidth > 0 ? rightWidth : maxWidth);

      lines.add(
        _LinePair(
          leftPainter: leftPainter,
          rightPainter: rightPainter,
          leftStartIndex: leftStartIndex,
          leftEndIndex: leftEndIndex,
          rightStartIndex: rightStartIndex,
          rightEndIndex: rightEndIndex,
          lineHeight: lineHeight,
          yOffset: besideAccumHeight,
        ),
      );

      besideAccumHeight += lineHeight;

      // Advance past all text consumed in this line pair.
      final nextIndex = max(leftEndIndex, rightEndIndex);
      if (nextIndex <= currentIndex) {
        // No progress — avoid infinite loop.
        break;
      }
      currentIndex = nextIndex;
    }

    // Beside zone height is the accumulated text height only.  Do NOT pad it
    // up to exclusionRect.height: doing so would cause the parent layout to
    // advance yOffset past the float bottom for short text blocks, which
    // clears the active exclusion and prevents subsequent blocks from wrapping
    // beside the same float.
    final besideHeight = besideAccumHeight;
    final besideEndIndex = currentIndex;

    // -------------------------------------------------------------------------
    // Zone 3: Below — remaining text at full width.
    // -------------------------------------------------------------------------
    TextPainter? belowPainter;
    double belowHeight = 0.0;

    if (besideEndIndex < textLength) {
      belowPainter = TextPainter(
        text: _buildTextSpanForRange(besideEndIndex, textLength),
        textDirection: _textDirection,
        textAlign: _textAlign,
      )..layout(maxWidth: maxWidth);
      belowHeight = belowPainter.height;
    }

    _exclusionLayout = _ExclusionLayout(
      abovePainter: abovePainter,
      aboveEndIndex: aboveEndIndex,
      lines: lines,
      besideEndIndex: besideEndIndex,
      belowPainter: belowPainter,
      aboveHeight: aboveHeight,
      besideHeight: besideHeight,
      belowHeight: belowHeight,
      exclusionRect: exclusionRect,
      leftWidth: leftWidth,
      rightWidth: rightWidth,
    );

    // Also lay out the primary painter so baseline queries and subclass helpers
    // remain valid.
    _layoutText(maxWidth);
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

  /// Returns the [exclusionRect] from [DocumentBlockConstraints], adjusted
  /// by [horizontalInset] and [verticalInset] for subclasses that indent
  /// their text content (e.g. blockquote border, code-block padding, list
  /// marker gutter).
  ///
  /// Returns `null` when the constraints carry no exclusion rect.
  @protected
  Rect? exclusionRectForLayout({
    double horizontalInset = 0.0,
    double verticalInset = 0.0,
  }) {
    if (constraints is! DocumentBlockConstraints) return null;
    final raw = (constraints as DocumentBlockConstraints).exclusionRect;
    if (raw == null) return null;
    if (horizontalInset == 0.0 && verticalInset == 0.0) return raw;
    return raw.translate(-horizontalInset, -verticalInset);
  }

  /// Lays out the internal [TextPainter] with [textMaxWidth] as the maximum
  /// line width.
  ///
  /// When [exclusionRect] is provided, the text is split into above/beside/
  /// below zones around the exclusion (center-float dual-column wrapping).
  ///
  /// Subclasses that override [performLayout] to apply inset constraints
  /// (such as [RenderListItemBlock] and [RenderCodeBlock]) call this method
  /// to perform text layout without replicating the span-building logic.
  /// After calling this, [layoutTextHeight] is valid.
  @protected
  void layoutText(double textMaxWidth, {Rect? exclusionRect}) {
    if (exclusionRect != null) {
      _performExclusionLayout(textMaxWidth, exclusionRect);
    } else {
      _exclusionLayout?.dispose();
      _exclusionLayout = null;
      _layoutText(textMaxWidth);
    }
  }

  /// The height of the text content after the most recent [layoutText] or
  /// [performLayout] call.
  ///
  /// When exclusion-zone layout is active, returns the total height of the
  /// above + beside + below zones. Otherwise returns the single-painter
  /// text height.
  ///
  /// Only valid after layout. Subclasses use this to compute [size].
  @protected
  // ignore: diagnostic_describe_all_properties
  double get layoutTextHeight => _exclusionLayout?.totalHeight ?? _textPainter.height;

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
    final excl = _exclusionLayout;
    if (excl != null) {
      // Paint selection highlights behind the text.
      if (_nodeSelection != null) {
        _paintSelectionHighlight(context.canvas, offset);
      }
      // Above zone.
      if (excl.abovePainter != null) {
        excl.abovePainter!.paint(context.canvas, offset);
      }
      // Beside zone — Z-pattern lines.
      for (final line in excl.lines) {
        final lineOffset = Offset(0, excl.aboveHeight + line.yOffset);
        if (excl.leftWidth > 0) {
          line.leftPainter.paint(context.canvas, offset + lineOffset);
        }
        if (excl.rightWidth > 0) {
          final rightOffset = Offset(excl.exclusionRect.right, excl.aboveHeight + line.yOffset);
          line.rightPainter.paint(context.canvas, offset + rightOffset);
        }
      }
      // Below zone.
      if (excl.belowPainter != null) {
        final belowOffset = Offset(0, excl.aboveHeight + excl.besideHeight);
        excl.belowPainter!.paint(context.canvas, offset + belowOffset);
      }
      return;
    }

    // Standard single-painter path.
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
  // Tab-expansion offset conversion helpers
  // ---------------------------------------------------------------------------

  /// Number of extra characters added by tab expansion in model range [from, to).
  ///
  /// Each `\t` character is rendered as 4 spaces, so it contributes 3 extra
  /// visual characters compared to its 1 model character.
  int _tabExtra(int from, int to) {
    int extra = 0;
    final text = _text.text;
    final end = to.clamp(0, text.length);
    for (int i = from.clamp(0, text.length); i < end; i++) {
      if (text.codeUnitAt(i) == 0x09) extra += 3; // tab → 4 spaces = 3 extra
    }
    return extra;
  }

  /// Model offset → visual offset (for full-text [TextPainter]).
  int _m2v(int modelOffset) => modelOffset + _tabExtra(0, modelOffset);

  /// Visual offset → model offset (for full-text [TextPainter]).
  int _v2m(int visualOffset) {
    final text = _text.text;
    int model = 0, visual = 0;
    while (visual < visualOffset && model < text.length) {
      visual += text.codeUnitAt(model) == 0x09 ? 4 : 1;
      model++;
    }
    return model;
  }

  /// Model-local offset → visual-local offset within a zone starting at [rangeStart].
  int _m2vLocal(int localOffset, int rangeStart) =>
      localOffset + _tabExtra(rangeStart, rangeStart + localOffset);

  /// Visual-local offset → model-local offset within a zone starting at [rangeStart].
  int _v2mLocal(int visualLocal, int rangeStart) {
    final text = _text.text;
    int model = 0, visual = 0;
    while (visual < visualLocal && (rangeStart + model) < text.length) {
      visual += text.codeUnitAt(rangeStart + model) == 0x09 ? 4 : 1;
      model++;
    }
    return model;
  }

  // ---------------------------------------------------------------------------
  // RenderDocumentBlock — geometry queries
  // ---------------------------------------------------------------------------

  @override
  Rect getLocalRectForPosition(NodePosition position) {
    assert(position is TextNodePosition, 'RenderTextBlock expects TextNodePosition');
    final tp = position as TextNodePosition;

    final excl = _exclusionLayout;
    if (excl != null) {
      return _getLocalRectForPositionExclusion(tp, excl);
    }

    final visualOffset = _m2v(tp.offset);
    final textPosition = TextPosition(offset: visualOffset, affinity: tp.affinity);
    final caretOffset = _textPainter.getOffsetForCaret(textPosition, Rect.zero);

    // Use a 1-char selection with BoxHeightStyle.max to get the actual line
    // height, which accounts for mixed fonts on the same line.
    final textLength = _text.text.length;
    if (textLength > 0) {
      // When the cursor is at the end of text that ends with '\n', TextPainter
      // places the caret on the empty trailing line (caretOffset.dy reflects
      // this correctly).  Querying getBoxesForSelection for the '\n' character
      // (textLength - 1) would return the box for the line CONTAINING '\n',
      // not the trailing empty line — producing a mismatch between caretOffset
      // and box.top.  Use caretOffset + preferredLineHeight directly instead.
      if (tp.offset >= textLength && _text.text.endsWith('\n')) {
        return Rect.fromLTWH(caretOffset.dx, caretOffset.dy, 0, _textPainter.preferredLineHeight);
      }
      final start = tp.offset >= textLength ? textLength - 1 : tp.offset;
      final end = (start + 1).clamp(0, textLength);
      final visualStart = _m2v(start);
      final visualEnd = _m2v(end);
      final boxes = _textPainter.getBoxesForSelection(
        TextSelection(baseOffset: visualStart, extentOffset: visualEnd),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      if (boxes.isNotEmpty) {
        final box = boxes.first.toRect();
        return Rect.fromLTWH(caretOffset.dx, box.top, 0, box.height);
      }
    }

    return Rect.fromLTWH(caretOffset.dx, caretOffset.dy, 0, _textPainter.preferredLineHeight);
  }

  /// Returns the caret rect for [position] when [_exclusionLayout] is active.
  Rect _getLocalRectForPositionExclusion(TextNodePosition position, _ExclusionLayout excl) {
    final charIndex = position.offset;

    // Above zone.
    if (charIndex < excl.aboveEndIndex) {
      final painter = excl.abovePainter;
      if (painter == null) {
        return Rect.fromLTWH(0, 0, 0, _textPainter.preferredLineHeight);
      }
      // Above painter covers [0, aboveEndIndex) — model offsets = global offsets.
      final visualCharIndex = _m2v(charIndex);
      final textPos = TextPosition(offset: visualCharIndex, affinity: position.affinity);
      final caretOffset = painter.getOffsetForCaret(textPos, Rect.zero);
      final textLength = excl.aboveEndIndex;
      if (textLength > 0) {
        final start = charIndex >= textLength ? textLength - 1 : charIndex;
        final visualStart = _m2v(start);
        final visualEnd = _m2v(start + 1).clamp(0, _m2v(textLength));
        final boxes = painter.getBoxesForSelection(
          TextSelection(baseOffset: visualStart, extentOffset: visualEnd),
          boxHeightStyle: ui.BoxHeightStyle.max,
        );
        if (boxes.isNotEmpty) {
          final box = boxes.first.toRect();
          return Rect.fromLTWH(caretOffset.dx, box.top, 0, box.height);
        }
      }
      return Rect.fromLTWH(caretOffset.dx, caretOffset.dy, 0, painter.preferredLineHeight);
    }

    // Below zone.
    if (charIndex >= excl.besideEndIndex && excl.belowPainter != null) {
      final painter = excl.belowPainter!;
      final baseY = excl.aboveHeight + excl.besideHeight;
      final localIndex = charIndex - excl.besideEndIndex;
      // Below painter covers [besideEndIndex, textLength) — local offsets need
      // to be converted using rangeStart = besideEndIndex.
      final visualLocalIndex = _m2vLocal(localIndex, excl.besideEndIndex);
      final textPos = TextPosition(offset: visualLocalIndex, affinity: position.affinity);
      final caretOffset = painter.getOffsetForCaret(textPos, Rect.zero);
      final belowLength = _text.text.length - excl.besideEndIndex;
      if (belowLength > 0) {
        // Same trailing-newline guard as the non-exclusion path: when the
        // cursor is at the end of text ending with '\n', use caretOffset
        // directly rather than querying the box for the '\n' character.
        if (localIndex >= belowLength && _text.text.endsWith('\n')) {
          return Rect.fromLTWH(
              caretOffset.dx, baseY + caretOffset.dy, 0, painter.preferredLineHeight);
        }
        final start = localIndex >= belowLength ? belowLength - 1 : localIndex;
        final visualStart = _m2vLocal(start, excl.besideEndIndex);
        final visualEnd = _m2vLocal(start + 1, excl.besideEndIndex);
        final boxes = painter.getBoxesForSelection(
          TextSelection(baseOffset: visualStart, extentOffset: visualEnd),
          boxHeightStyle: ui.BoxHeightStyle.max,
        );
        if (boxes.isNotEmpty) {
          final box = boxes.first.toRect();
          return Rect.fromLTWH(caretOffset.dx, baseY + box.top, 0, box.height);
        }
      }
      return Rect.fromLTWH(caretOffset.dx, baseY + caretOffset.dy, 0, painter.preferredLineHeight);
    }

    // Beside zone — find which line pair contains this index.
    // Also handles end-of-text when there is no below zone, since
    // charIndex == besideEndIndex == lastLine.rightEndIndex (or leftEndIndex).
    for (final line in excl.lines) {
      final baseY = excl.aboveHeight + line.yOffset;

      // Check left column.
      if (charIndex >= line.leftStartIndex && charIndex <= line.leftEndIndex) {
        final localIndex = charIndex - line.leftStartIndex;
        final painter = line.leftPainter;
        final visualLocalIndex = _m2vLocal(localIndex, line.leftStartIndex);
        final textPos = TextPosition(offset: visualLocalIndex, affinity: position.affinity);
        final caretOffset = painter.getOffsetForCaret(textPos, Rect.zero);
        final lineLen = line.leftEndIndex - line.leftStartIndex;
        if (lineLen > 0) {
          final start = localIndex >= lineLen ? lineLen - 1 : localIndex;
          final visualStart = _m2vLocal(start, line.leftStartIndex);
          final visualEnd = _m2vLocal(start + 1, line.leftStartIndex);
          final boxes = painter.getBoxesForSelection(
            TextSelection(baseOffset: visualStart, extentOffset: visualEnd),
            boxHeightStyle: ui.BoxHeightStyle.max,
          );
          if (boxes.isNotEmpty) {
            final box = boxes.first.toRect();
            return Rect.fromLTWH(caretOffset.dx, baseY + box.top, 0, box.height);
          }
        }
        return Rect.fromLTWH(
            caretOffset.dx, baseY + caretOffset.dy, 0, painter.preferredLineHeight);
      }

      // Check right column.
      if (charIndex >= line.rightStartIndex && charIndex <= line.rightEndIndex) {
        final localIndex = charIndex - line.rightStartIndex;
        final painter = line.rightPainter;
        final rightBaseX = excl.exclusionRect.right;
        final visualLocalIndex = _m2vLocal(localIndex, line.rightStartIndex);
        final textPos = TextPosition(offset: visualLocalIndex, affinity: position.affinity);
        final caretOffset = painter.getOffsetForCaret(textPos, Rect.zero);
        final lineLen = line.rightEndIndex - line.rightStartIndex;
        if (lineLen > 0) {
          final start = localIndex >= lineLen ? lineLen - 1 : localIndex;
          final visualStart = _m2vLocal(start, line.rightStartIndex);
          final visualEnd = _m2vLocal(start + 1, line.rightStartIndex);
          final boxes = painter.getBoxesForSelection(
            TextSelection(baseOffset: visualStart, extentOffset: visualEnd),
            boxHeightStyle: ui.BoxHeightStyle.max,
          );
          if (boxes.isNotEmpty) {
            final box = boxes.first.toRect();
            return Rect.fromLTWH(rightBaseX + caretOffset.dx, baseY + box.top, 0, box.height);
          }
        }
        return Rect.fromLTWH(
          rightBaseX + caretOffset.dx,
          baseY + caretOffset.dy,
          0,
          painter.preferredLineHeight,
        );
      }
    }

    // Fallback — return a rect at the beginning of the block.
    return Rect.fromLTWH(0, 0, 0, _textPainter.preferredLineHeight);
  }

  @override
  NodePosition getPositionAtOffset(Offset localOffset) {
    final excl = _exclusionLayout;
    if (excl != null) {
      final y = localOffset.dy;
      final x = localOffset.dx;

      // Above zone.
      if (y < excl.aboveHeight) {
        if (excl.abovePainter != null) {
          final tp = excl.abovePainter!.getPositionForOffset(localOffset);
          // Above painter uses visual offsets; convert to model offsets.
          return TextNodePosition(
            offset: _v2m(tp.offset).clamp(0, excl.aboveEndIndex),
            affinity: tp.affinity,
          );
        }
        return const TextNodePosition(offset: 0);
      }

      // Below zone.
      if (y >= excl.aboveHeight + excl.besideHeight) {
        if (excl.belowPainter != null) {
          final belowOffset = Offset(x, y - excl.aboveHeight - excl.besideHeight);
          final tp = excl.belowPainter!.getPositionForOffset(belowOffset);
          // Below painter uses local visual offsets; convert to model offsets.
          final modelLocal = _v2mLocal(tp.offset, excl.besideEndIndex);
          return TextNodePosition(
            offset: (excl.besideEndIndex + modelLocal).clamp(0, _text.text.length),
            affinity: tp.affinity,
          );
        }
        return TextNodePosition(offset: _text.text.length);
      }

      // Beside zone — find which line pair contains y.
      final besideY = y - excl.aboveHeight;
      _LinePair? hitLine;
      for (final line in excl.lines) {
        if (besideY >= line.yOffset && besideY < line.yOffset + line.lineHeight) {
          hitLine = line;
          break;
        }
      }
      hitLine ??= excl.lines.isNotEmpty ? excl.lines.last : null;

      if (hitLine == null) {
        return TextNodePosition(offset: excl.aboveEndIndex);
      }

      final lineLocalY = besideY - hitLine.yOffset;

      // Determine which column based on x.
      if (x < excl.exclusionRect.left) {
        // Left column.
        if (excl.leftWidth > 0) {
          final tp = hitLine.leftPainter.getPositionForOffset(Offset(x, lineLocalY));
          // Left painter uses local visual offsets; convert to model offsets.
          final modelLocal = _v2mLocal(tp.offset, hitLine.leftStartIndex);
          final idx = (hitLine.leftStartIndex + modelLocal).clamp(
            hitLine.leftStartIndex,
            hitLine.leftEndIndex,
          );
          return TextNodePosition(offset: idx, affinity: tp.affinity);
        }
        return TextNodePosition(offset: hitLine.leftStartIndex);
      } else if (x >= excl.exclusionRect.right) {
        // Right column.
        if (excl.rightWidth > 0) {
          final rightX = x - excl.exclusionRect.right;
          final tp = hitLine.rightPainter.getPositionForOffset(Offset(rightX, lineLocalY));
          // Right painter uses local visual offsets; convert to model offsets.
          final modelLocal = _v2mLocal(tp.offset, hitLine.rightStartIndex);
          final idx = (hitLine.rightStartIndex + modelLocal).clamp(
            hitLine.rightStartIndex,
            hitLine.rightEndIndex,
          );
          return TextNodePosition(offset: idx, affinity: tp.affinity);
        }
        return TextNodePosition(offset: hitLine.rightEndIndex);
      } else {
        // Inside the exclusion rect — snap to nearest column edge.
        final distToLeft = x - excl.exclusionRect.left;
        final distToRight = excl.exclusionRect.right - x;
        if (distToLeft <= distToRight && excl.leftWidth > 0) {
          return TextNodePosition(offset: hitLine.leftEndIndex);
        } else if (excl.rightWidth > 0) {
          return TextNodePosition(offset: hitLine.rightStartIndex);
        }
        return TextNodePosition(offset: hitLine.leftStartIndex);
      }
    }

    final tp = _textPainter.getPositionForOffset(localOffset);
    return TextNodePosition(offset: _v2m(tp.offset), affinity: tp.affinity);
  }

  /// Returns the [TextRange] spanning the visual line that contains [position].
  ///
  /// When an exclusion zone is active, the text is laid out in three zones
  /// (above, beside, below).  Each zone uses its own [TextPainter] with a
  /// different width, so the visual line boundaries differ from those of the
  /// full-width [_textPainter].  This method consults the active
  /// [_ExclusionLayout] to return the correct visual boundary for the zone
  /// that contains [position.offset]:
  ///
  /// - **Above zone** — delegates to `abovePainter.getLineBoundary` with a
  ///   local offset, then shifts the result to global indices.
  /// - **Beside zone** — returns the column's start/end index range directly
  ///   from the [_LinePair] (no painter query needed because each column
  ///   already stores its exact character range).
  /// - **Below zone** — delegates to `belowPainter.getLineBoundary` with a
  ///   local offset, then shifts the result to global indices.
  ///
  /// Falls back to `_textPainter.getLineBoundary` when no exclusion zone is
  /// active or when the offset does not fall into any known zone.
  TextRange getLineBoundary(TextNodePosition position) {
    final offset = position.offset;
    final excl = _exclusionLayout;

    if (excl != null) {
      // ------------------------------------------------------------------
      // Above zone: [0, aboveEndIndex)
      // ------------------------------------------------------------------
      if (excl.abovePainter != null && offset < excl.aboveEndIndex) {
        final visualOffset = _m2v(offset);
        final localPos = TextPosition(offset: visualOffset, affinity: position.affinity);
        final localRange = excl.abovePainter!.getLineBoundary(localPos);
        // Convert visual range back to model range.
        return TextRange(start: _v2m(localRange.start), end: _v2m(localRange.end));
      }

      // ------------------------------------------------------------------
      // Beside zone: check each _LinePair
      // ------------------------------------------------------------------
      for (final line in excl.lines) {
        // Left column: [leftStartIndex, leftEndIndex)
        if (line.leftStartIndex < line.leftEndIndex &&
            offset >= line.leftStartIndex &&
            offset < line.leftEndIndex) {
          return TextRange(start: line.leftStartIndex, end: line.leftEndIndex);
        }
        // Right column: [rightStartIndex, rightEndIndex)
        if (line.rightStartIndex < line.rightEndIndex &&
            offset >= line.rightStartIndex &&
            offset < line.rightEndIndex) {
          return TextRange(start: line.rightStartIndex, end: line.rightEndIndex);
        }
      }

      // ------------------------------------------------------------------
      // Below zone: [besideEndIndex, textLength)
      // ------------------------------------------------------------------
      if (excl.belowPainter != null && offset >= excl.besideEndIndex) {
        final localOffset = offset - excl.besideEndIndex;
        final visualLocalOffset = _m2vLocal(localOffset, excl.besideEndIndex);
        final localPos = TextPosition(offset: visualLocalOffset, affinity: position.affinity);
        final localRange = excl.belowPainter!.getLineBoundary(localPos);
        // Convert visual local range back to model global indices.
        return TextRange(
          start: excl.besideEndIndex + _v2mLocal(localRange.start, excl.besideEndIndex),
          end: excl.besideEndIndex + _v2mLocal(localRange.end, excl.besideEndIndex),
        );
      }
    }

    // Fallback: no exclusion zone, or offset didn't match any zone.
    final tp = TextPosition(offset: _m2v(offset), affinity: position.affinity);
    final range = _textPainter.getLineBoundary(tp);
    return TextRange(start: _v2m(range.start), end: _v2m(range.end));
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

    final selStart = b.offset < e.offset ? b.offset : e.offset;
    final selEnd = b.offset < e.offset ? e.offset : b.offset;

    final excl = _exclusionLayout;
    if (excl != null) {
      return _getEndpointsForSelectionExclusion(selStart, selEnd, excl);
    }

    final boxes = _textPainter.getBoxesForSelection(
      TextSelection(baseOffset: _m2v(selStart), extentOffset: _m2v(selEnd)),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    return boxes.map((box) => box.toRect()).toList();
  }

  /// Collects selection rects across all zones when [_exclusionLayout] is active.
  List<Rect> _getEndpointsForSelectionExclusion(
    int selStart,
    int selEnd,
    _ExclusionLayout excl,
  ) {
    final rects = <Rect>[];

    // Above zone.
    if (excl.abovePainter != null && selStart < excl.aboveEndIndex) {
      final zoneStart = selStart.clamp(0, excl.aboveEndIndex);
      final zoneEnd = selEnd.clamp(0, excl.aboveEndIndex);
      if (zoneStart < zoneEnd) {
        final boxes = excl.abovePainter!.getBoxesForSelection(
          TextSelection(baseOffset: _m2v(zoneStart), extentOffset: _m2v(zoneEnd)),
          boxHeightStyle: ui.BoxHeightStyle.max,
        );
        rects.addAll(boxes.map((box) => box.toRect()));
      }
    }

    // Beside zone.
    for (final line in excl.lines) {
      final baseY = excl.aboveHeight + line.yOffset;

      // Left column.
      if (excl.leftWidth > 0 && selStart < line.leftEndIndex && selEnd > line.leftStartIndex) {
        final zoneStart =
            (selStart - line.leftStartIndex).clamp(0, line.leftEndIndex - line.leftStartIndex);
        final zoneEnd =
            (selEnd - line.leftStartIndex).clamp(0, line.leftEndIndex - line.leftStartIndex);
        if (zoneStart < zoneEnd) {
          final boxes = line.leftPainter.getBoxesForSelection(
            TextSelection(
              baseOffset: _m2vLocal(zoneStart, line.leftStartIndex),
              extentOffset: _m2vLocal(zoneEnd, line.leftStartIndex),
            ),
            boxHeightStyle: ui.BoxHeightStyle.max,
          );
          rects.addAll(boxes.map((box) => box.toRect().shift(Offset(0, baseY))));
        }
      }

      // Right column.
      if (excl.rightWidth > 0 && selStart < line.rightEndIndex && selEnd > line.rightStartIndex) {
        final zoneStart =
            (selStart - line.rightStartIndex).clamp(0, line.rightEndIndex - line.rightStartIndex);
        final zoneEnd =
            (selEnd - line.rightStartIndex).clamp(0, line.rightEndIndex - line.rightStartIndex);
        if (zoneStart < zoneEnd) {
          final boxes = line.rightPainter.getBoxesForSelection(
            TextSelection(
              baseOffset: _m2vLocal(zoneStart, line.rightStartIndex),
              extentOffset: _m2vLocal(zoneEnd, line.rightStartIndex),
            ),
            boxHeightStyle: ui.BoxHeightStyle.max,
          );
          rects.addAll(
            boxes.map((box) => box.toRect().shift(Offset(excl.exclusionRect.right, baseY))),
          );
        }
      }
    }

    // Below zone.
    if (excl.belowPainter != null && selEnd > excl.besideEndIndex) {
      final baseY = excl.aboveHeight + excl.besideHeight;
      final zoneStart = (selStart - excl.besideEndIndex).clamp(
        0,
        _text.text.length - excl.besideEndIndex,
      );
      final zoneEnd = (selEnd - excl.besideEndIndex).clamp(
        0,
        _text.text.length - excl.besideEndIndex,
      );
      if (zoneStart < zoneEnd) {
        final boxes = excl.belowPainter!.getBoxesForSelection(
          TextSelection(
            baseOffset: _m2vLocal(zoneStart, excl.besideEndIndex),
            extentOffset: _m2vLocal(zoneEnd, excl.besideEndIndex),
          ),
          boxHeightStyle: ui.BoxHeightStyle.max,
        );
        rects.addAll(boxes.map((box) => box.toRect().shift(Offset(0, baseY))));
      }
    }

    return rects;
  }

  // ---------------------------------------------------------------------------
  // Attribution → TextSpan
  // ---------------------------------------------------------------------------

  /// Builds a [TextSpan] for the character range [start]..[end) (exclusive),
  /// preserving any attributions that overlap the range.
  ///
  /// Used by the exclusion-zone layout to create per-zone painters.
  TextSpan _buildTextSpanForRange(int start, int end) {
    if (_textSpanBuilder != null) {
      return _textSpanBuilder!(_text.copyText(start, end), _textStyle);
    }
    final rawText = _text.text;
    if (start >= end || start >= rawText.length) {
      return TextSpan(text: '', style: _textStyle);
    }
    final clampedEnd = end.clamp(0, rawText.length);
    if (clampedEnd <= start) {
      return TextSpan(text: '', style: _textStyle);
    }
    final substring = rawText.substring(start, clampedEnd);

    final spans = _text.getAttributionSpansInRange(start, clampedEnd - 1).toList();
    if (spans.isEmpty) {
      return TextSpan(text: substring.replaceAll('\t', '    '), style: _textStyle);
    }

    // Collect all boundary offsets relative to the substring.
    final boundaries = <int>{0, substring.length};
    for (final span in spans) {
      final relStart = (span.start - start).clamp(0, substring.length);
      final relEnd = (span.end + 1 - start).clamp(0, substring.length);
      boundaries.add(relStart);
      boundaries.add(relEnd);
    }
    final sortedBoundaries = boundaries.toList()..sort();

    final children = <InlineSpan>[];
    for (var i = 0; i < sortedBoundaries.length - 1; i++) {
      final s = sortedBoundaries[i];
      final e = sortedBoundaries[i + 1];
      if (s >= substring.length) break;
      final activeAttributions = _text.getAttributionsAt(s + start);
      final style = _buildStyleForAttributions(activeAttributions);
      children
          .add(TextSpan(text: substring.substring(s, e).replaceAll('\t', '    '), style: style));
    }

    return TextSpan(style: _textStyle, children: children);
  }

  /// Converts [_text] and its attributions into an [InlineSpan] tree suitable
  /// for [TextPainter].
  ///
  /// When no attributions are present a single [TextSpan] is returned.
  /// Otherwise the text is split into runs at attribution boundaries and each
  /// run receives a merged [TextStyle].
  TextSpan _buildTextSpan() {
    if (_textSpanBuilder != null) return _textSpanBuilder!(_text, _textStyle);
    final rawText = _text.text;
    if (rawText.isEmpty) {
      return TextSpan(text: '', style: _textStyle);
    }

    final spans = _text.getAttributionSpansInRange(0, rawText.length - 1).toList();
    if (spans.isEmpty) {
      return TextSpan(text: rawText.replaceAll('\t', '    '), style: _textStyle);
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
      children.add(
          TextSpan(text: rawText.substring(start, end).replaceAll('\t', '    '), style: style));
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
    properties.add(ObjectFlagProperty<TextSpanBuilder?>.has('textSpanBuilder', _textSpanBuilder));
  }
}
