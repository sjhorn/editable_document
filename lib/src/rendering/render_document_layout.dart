/// Container render object that lays out document blocks vertically.
///
/// This file provides [RenderDocumentLayout], a [RenderBox] that manages a
/// vertical stack of [RenderDocumentBlock] children and exposes geometry
/// queries used by the selection and caret systems.
library;

import 'dart:math';

import 'package:flutter/rendering.dart';

import '../model/block_alignment.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/node_position.dart';
import '../model/text_wrap_mode.dart';
import 'render_document_block.dart';

// ---------------------------------------------------------------------------
// DocumentBlockParentData
// ---------------------------------------------------------------------------

/// [ParentData] for children of [RenderDocumentLayout].
///
/// Stores the paint offset assigned to each [RenderDocumentBlock] child
/// during [RenderDocumentLayout.performLayout], and whether the block is
/// positioned as a float.
class DocumentBlockParentData extends ContainerBoxParentData<RenderDocumentBlock> {
  /// Whether this block is positioned as a float.
  ///
  /// When `true`, the block occupies an exclusion zone and adjacent blocks
  /// may wrap beside it.  Set by [RenderDocumentLayout.performLayout].
  bool isFloat = false;

  /// The [TextWrapMode] of this block.
  ///
  /// Mirrors [RenderDocumentBlock.textWrap] as recorded during
  /// [RenderDocumentLayout.performLayout].  Used by the paint method to
  /// determine in which pass this block should be rendered.
  TextWrapMode wrapMode = TextWrapMode.none;

  /// The interior exclusion rectangle for center-float wrapping, or `null`.
  ///
  /// When a stretch block wraps beside a center-aligned float, this rect
  /// describes the float's bounds (with gap) in the child's local coordinates.
  /// The child can use this to flow text around both sides of the float.
  /// Set by [RenderDocumentLayout.performLayout].
  Rect? exclusionRect;

  /// Exclusion rectangles for dual side-float wrapping, or `null`.
  ///
  /// When both a start (left) and an end (right) float are simultaneously
  /// active, this list contains exactly two rects — one per side — in the
  /// child's local coordinates.  [exclusionRect] is `null` in this case.
  /// Set by [RenderDocumentLayout.performLayout].
  List<Rect>? exclusionRects;
}

// ---------------------------------------------------------------------------
// DocumentBlockConstraints
// ---------------------------------------------------------------------------

/// [BoxConstraints] extended with optional interior exclusion rectangles.
///
/// When a stretch block wraps beside a float, [RenderDocumentLayout] passes
/// the float's bounds (with gap) as [exclusionRect] (single float) or
/// [exclusionRects] (dual side floats).  The child's [RenderBox.performLayout]
/// can read these from `constraints` (via a type check) to flow text around
/// the float(s).
///
/// Using a custom constraints subclass ensures that Flutter automatically
/// re-runs `performLayout` on the child whenever the exclusion rects change,
/// because [operator ==] includes [exclusionRect] and [exclusionRects] in its
/// comparison.
class DocumentBlockConstraints extends BoxConstraints {
  /// Creates document-block constraints with optional exclusion rect(s).
  const DocumentBlockConstraints({
    super.minWidth = 0.0,
    super.maxWidth = double.infinity,
    super.minHeight = 0.0,
    super.maxHeight = double.infinity,
    this.exclusionRect,
    this.exclusionRects,
  });

  /// The interior exclusion rectangle for single-float wrapping, or `null`.
  ///
  /// Describes the float's bounds (with gap) in the child's local coordinates.
  /// When both start and end floats are simultaneously active,
  /// [exclusionRects] is used instead.
  final Rect? exclusionRect;

  /// Exclusion rectangles for dual side-float wrapping, or `null`.
  ///
  /// When both a start (left) and an end (right) float are simultaneously
  /// active, this list contains exactly two rects — one per side — in the
  /// child's local coordinates.  [exclusionRect] is `null` in this case.
  final List<Rect>? exclusionRects;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! DocumentBlockConstraints) return false;
    if (super != other) return false;
    if (exclusionRect != other.exclusionRect) return false;
    final a = exclusionRects;
    final b = other.exclusionRects;
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        super.hashCode,
        exclusionRect,
        Object.hashAll(exclusionRects ?? const []),
      );

  @override
  String toString() {
    final base = super.toString();
    if (exclusionRect != null) return '$base; exclusionRect=$exclusionRect';
    if (exclusionRects != null) return '$base; exclusionRects=$exclusionRects';
    return base;
  }
}

// ---------------------------------------------------------------------------
// _ExclusionZone
// ---------------------------------------------------------------------------

/// Tracks a floated block's position so subsequent blocks can wrap around it.
class _ExclusionZone {
  /// Creates an [_ExclusionZone] describing a floated block's occupied area.
  _ExclusionZone({
    required this.side,
    required this.width,
    required this.top,
    required this.bottom,
    this.floatLeft = 0.0,
  });

  /// Which side the float is on.
  final BlockAlignment side;

  /// Width consumed by the float (including gap for start/end, raw for center).
  final double width;

  /// Top of the exclusion zone in layout coordinates.
  final double top;

  /// Bottom of the exclusion zone in layout coordinates.
  final double bottom;

  /// X offset of the float block in layout coordinates.
  final double floatLeft;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Horizontal gap between a floated block and adjacent content.
const double _kFloatGap = 8.0;

// ---------------------------------------------------------------------------
// LineNumberAlignment
// ---------------------------------------------------------------------------

/// Vertical alignment of line numbers relative to their document block.
enum LineNumberAlignment {
  /// Align line numbers to the top of each block.
  top,

  /// Align line numbers to the vertical center of each block.
  middle,

  /// Align line numbers to the bottom of each block.
  bottom,
}

// ---------------------------------------------------------------------------
// RenderDocumentLayout
// ---------------------------------------------------------------------------

/// A [RenderBox] that arranges [RenderDocumentBlock] children in a vertical
/// stack, separated by [blockSpacing] pixels.
///
/// This render object is the visual counterpart of a `Document` — each child
/// corresponds to one `DocumentNode`.  It exposes geometry queries that the
/// selection and caret painting systems use to translate between document
/// coordinates and pixel coordinates.
///
/// ## Alignment and Float Layout
///
/// By default every child is laid out with [BlockAlignment.stretch], filling
/// the full available width.  When a child overrides [RenderDocumentBlock.blockAlignment]
/// the layout adapts:
///
/// - [BlockAlignment.center] — the block takes its natural/requested width and
///   is centred horizontally.
/// - [BlockAlignment.start] / [BlockAlignment.end] (with [RenderDocumentBlock.textWrap]
///   [TextWrapMode.none]) — the block is aligned to the corresponding edge but
///   occupies a full vertical row (no wrapping of adjacent content).
/// - [BlockAlignment.start] / [BlockAlignment.end] (with [RenderDocumentBlock.textWrap]
///   [TextWrapMode.wrap]) — the block becomes a *float*: it is pinned to the
///   edge, and subsequent blocks are narrowed to wrap beside it until the
///   float's bottom is cleared.
///
/// ## Geometry queries
///
/// | Method | Description |
/// |--------|-------------|
/// | [getComponentByNodeId] | Returns the child whose [RenderDocumentBlock.nodeId] matches. |
/// | [getDocumentPositionAtOffset] | Hit-tests a local offset and returns the nearest [DocumentPosition], or `null` if the offset misses all children. |
/// | [getDocumentPositionNearestToOffset] | Like [getDocumentPositionAtOffset] but always returns a position by clamping to the nearest child. |
/// | [getRectForDocumentPosition] | Converts a [DocumentPosition] to a [Rect] in the layout's local coordinates. |
/// | [computeMaxScrollExtent] | Returns the maximum scroll offset for a given viewport height. |
///
/// ## Layout
///
/// Children are laid out with `BoxConstraints(maxWidth: constraints.maxWidth)`
/// unless alignment or float layout applies.  Their paint offsets are stored
/// in [DocumentBlockParentData.offset].  No [blockSpacing] is added before the
/// first child or after the last child.  [documentPadding] (when non-zero) adds
/// inset space around the entire content area.
///
/// ## Line Numbers
///
/// When [showLineNumbers] is `true`, a vertical gutter column is inserted
/// between [documentPadding.left] and the content area.  The gutter width is
/// either [lineNumberWidth] (explicit) or auto-computed from the child count
/// and [lineNumberTextStyle].  Float blocks are skipped — they do not receive
/// a line-number label.
///
/// ## Example
///
/// ```dart
/// final layout = RenderDocumentLayout(blockSpacing: 12.0);
/// layout.add(myTextBlock);
/// layout.add(myHrBlock);
/// layout.layout(const BoxConstraints(maxWidth: 600), parentUsesSize: true);
/// ```
class RenderDocumentLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderDocumentBlock, DocumentBlockParentData>,
        RenderBoxContainerDefaultsMixin<RenderDocumentBlock, DocumentBlockParentData> {
  /// Creates a [RenderDocumentLayout] with optional [blockSpacing],
  /// [viewportWidth], [documentPadding], and line-number properties.
  ///
  /// [blockSpacing] is the vertical gap in logical pixels inserted between
  /// consecutive children.  Defaults to `12.0`.
  ///
  /// [viewportWidth] overrides the constraint width used to lay out and size
  /// each block.  When `null` (the default), the layout uses
  /// `constraints.maxWidth`.  Supply a fixed value (e.g. the viewport pixel
  /// width) when the layout is inside an infinite-width scroll view so that
  /// blocks size to the visible area rather than to infinity.
  ///
  /// [documentPadding] is the inset applied around the content area.  The top
  /// and bottom insets add space above the first child and below the last child
  /// respectively.  The left and right insets shift all children inward and
  /// reduce each child's available width by the horizontal total.  Defaults to
  /// [EdgeInsets.zero].
  ///
  /// [showLineNumbers] controls whether a line-number gutter is rendered on the
  /// left side of the content area.  Defaults to `false`.
  ///
  /// [lineNumberWidth] sets an explicit gutter width in logical pixels.  When
  /// `0.0` (the default), the width is auto-computed from the child count and
  /// [lineNumberTextStyle].
  ///
  /// [lineNumberTextStyle] is the [TextStyle] used to render the line number
  /// labels.  Defaults to `null`, which uses a built-in fallback style.
  ///
  /// [lineNumberBackgroundColor] is the fill [Color] painted behind the gutter
  /// column.  Defaults to `null` (transparent — no background is painted).
  ///
  /// [lineNumberAlignment] controls the vertical alignment of each line-number
  /// label relative to its document block.  Defaults to [LineNumberAlignment.top].
  RenderDocumentLayout({
    double blockSpacing = 12.0,
    double? viewportWidth,
    EdgeInsets documentPadding = EdgeInsets.zero,
    bool showLineNumbers = false,
    double lineNumberWidth = 0.0,
    TextStyle? lineNumberTextStyle,
    Color? lineNumberBackgroundColor,
    LineNumberAlignment lineNumberAlignment = LineNumberAlignment.top,
  })  : _blockSpacing = blockSpacing,
        _viewportWidth = viewportWidth,
        _documentPadding = documentPadding,
        _showLineNumbers = showLineNumbers,
        _lineNumberWidth = lineNumberWidth,
        _lineNumberTextStyle = lineNumberTextStyle,
        _lineNumberBackgroundColor = lineNumberBackgroundColor,
        _lineNumberAlignment = lineNumberAlignment;

  // ---------------------------------------------------------------------------
  // blockSpacing
  // ---------------------------------------------------------------------------

  double _blockSpacing;

  // ---------------------------------------------------------------------------
  // viewportWidth
  // ---------------------------------------------------------------------------

  double? _viewportWidth;

  // ---------------------------------------------------------------------------
  // documentPadding
  // ---------------------------------------------------------------------------

  EdgeInsets _documentPadding;

  // ---------------------------------------------------------------------------
  // Line-number fields
  // ---------------------------------------------------------------------------

  bool _showLineNumbers;
  double _lineNumberWidth;
  TextStyle? _lineNumberTextStyle;
  Color? _lineNumberBackgroundColor;
  LineNumberAlignment _lineNumberAlignment;

  /// Resolved gutter width computed during [performLayout].
  ///
  /// This is either [_lineNumberWidth] (when non-zero) or the auto-computed
  /// value based on the child count.  It is `0.0` when [_showLineNumbers] is
  /// `false`.
  double _resolvedGutterWidth = 0.0;

  /// The vertical gap in logical pixels between consecutive block children.
  ///
  /// No spacing is added before the first child or after the last child.
  double get blockSpacing => _blockSpacing;

  /// Sets [blockSpacing] and schedules a layout pass when the value changes.
  set blockSpacing(double value) {
    if (_blockSpacing == value) return;
    _blockSpacing = value;
    markNeedsLayout();
  }

  /// The explicit viewport width used for block layout, or `null` to derive
  /// the width from `constraints.maxWidth`.
  ///
  /// Set this to the physical viewport width when the document is placed inside
  /// a horizontal scroll view that passes an unbounded `maxWidth` constraint.
  /// Blocks will be laid out at this width instead of infinity, and the
  /// layout's own width will be `max(viewportWidth, widestChildRight)`.
  double? get viewportWidth => _viewportWidth;

  /// Sets [viewportWidth] and schedules a layout pass when the value changes.
  set viewportWidth(double? value) {
    if (_viewportWidth == value) return;
    _viewportWidth = value;
    markNeedsLayout();
  }

  /// The padding inset applied around the document's content area.
  ///
  /// The [EdgeInsets.top] and [EdgeInsets.bottom] values add whitespace above
  /// the first child and below the last child respectively.  The
  /// [EdgeInsets.left] and [EdgeInsets.right] values shift all children inward
  /// and reduce each child's available width by the horizontal total
  /// ([EdgeInsets.horizontal]).
  ///
  /// Defaults to [EdgeInsets.zero].
  EdgeInsets get documentPadding => _documentPadding;

  /// Sets [documentPadding] and schedules a layout pass when the value changes.
  set documentPadding(EdgeInsets value) {
    if (_documentPadding == value) return;
    _documentPadding = value;
    markNeedsLayout();
  }

  // ---------------------------------------------------------------------------
  // showLineNumbers
  // ---------------------------------------------------------------------------

  /// Whether to render a line-number gutter on the left side of the content
  /// area.
  ///
  /// When `true`, a vertical gutter column of width [_resolvedGutterWidth] is
  /// inserted between [documentPadding.left] and the first content pixel.
  /// Non-float blocks are numbered sequentially from `1`; float blocks are
  /// skipped (they share the line number of the block they float beside).
  ///
  /// Defaults to `false`.
  bool get showLineNumbers => _showLineNumbers;

  /// Sets [showLineNumbers] and schedules a layout pass when the value changes.
  set showLineNumbers(bool value) {
    if (_showLineNumbers == value) return;
    _showLineNumbers = value;
    markNeedsLayout();
  }

  // ---------------------------------------------------------------------------
  // lineNumberWidth
  // ---------------------------------------------------------------------------

  /// The explicit gutter width in logical pixels.
  ///
  /// When `0.0` (the default), the width is auto-computed from the child count
  /// and [lineNumberTextStyle] during [performLayout].  Supply a positive value
  /// to pin the gutter to a fixed width regardless of child count.
  double get lineNumberWidth => _lineNumberWidth;

  /// Sets [lineNumberWidth] and schedules a layout pass when the value changes.
  set lineNumberWidth(double value) {
    if (_lineNumberWidth == value) return;
    _lineNumberWidth = value;
    markNeedsLayout();
  }

  // ---------------------------------------------------------------------------
  // lineNumberTextStyle
  // ---------------------------------------------------------------------------

  /// The [TextStyle] used to render the line-number labels in the gutter.
  ///
  /// When `null` a default style of `TextStyle(fontSize: 12)` is used.
  /// Changing this property only triggers a repaint, not a full re-layout,
  /// because the gutter width is fixed once [performLayout] runs.
  TextStyle? get lineNumberTextStyle => _lineNumberTextStyle;

  /// Sets [lineNumberTextStyle] and schedules a repaint when the value changes.
  set lineNumberTextStyle(TextStyle? value) {
    if (_lineNumberTextStyle == value) return;
    _lineNumberTextStyle = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // lineNumberBackgroundColor
  // ---------------------------------------------------------------------------

  /// The fill [Color] painted behind the entire gutter column.
  ///
  /// When `null` (the default) no background is drawn.  Changing this property
  /// only triggers a repaint, not a full re-layout.
  Color? get lineNumberBackgroundColor => _lineNumberBackgroundColor;

  /// Sets [lineNumberBackgroundColor] and schedules a repaint when the value
  /// changes.
  set lineNumberBackgroundColor(Color? value) {
    if (_lineNumberBackgroundColor == value) return;
    _lineNumberBackgroundColor = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // lineNumberAlignment
  // ---------------------------------------------------------------------------

  /// The vertical alignment of each line-number label relative to its block.
  ///
  /// - [LineNumberAlignment.top] — label is aligned with the block's top edge.
  /// - [LineNumberAlignment.middle] — label is centred vertically within the block.
  /// - [LineNumberAlignment.bottom] — label is aligned with the block's bottom edge.
  ///
  /// Changing this property only triggers a repaint, not a full re-layout.
  /// Defaults to [LineNumberAlignment.top].
  LineNumberAlignment get lineNumberAlignment => _lineNumberAlignment;

  /// Sets [lineNumberAlignment] and schedules a repaint when the value changes.
  set lineNumberAlignment(LineNumberAlignment value) {
    if (_lineNumberAlignment == value) return;
    _lineNumberAlignment = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // ParentData
  // ---------------------------------------------------------------------------

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! DocumentBlockParentData) {
      child.parentData = DocumentBlockParentData();
    }
  }

  // ---------------------------------------------------------------------------
  // Intrinsic sizes
  // ---------------------------------------------------------------------------

  /// Computes the minimum intrinsic height for the given [width].
  ///
  /// Returns the sum of each child's minimum intrinsic height plus the total
  /// spacing between them.
  @override
  double computeMinIntrinsicHeight(double width) {
    return _computeIntrinsicHeight(width, min: true);
  }

  /// Computes the maximum intrinsic height for the given [width].
  ///
  /// Returns the sum of each child's maximum intrinsic height plus the total
  /// spacing between them.
  @override
  double computeMaxIntrinsicHeight(double width) {
    return _computeIntrinsicHeight(width, min: false);
  }

  double _computeIntrinsicHeight(double width, {required bool min}) {
    var total = 0.0;
    var count = 0;
    RenderDocumentBlock? child = firstChild;
    while (child != null) {
      total += min ? child.getMinIntrinsicHeight(width) : child.getMaxIntrinsicHeight(width);
      count++;
      child = childAfter(child);
    }
    if (count > 1) {
      total += _blockSpacing * (count - 1);
    }
    total += _documentPadding.vertical;
    return total;
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    final maxW = constraints.maxWidth;

    // -------------------------------------------------------------------
    // Resolve gutter width for line numbers.
    // -------------------------------------------------------------------
    if (_showLineNumbers) {
      if (_lineNumberWidth > 0.0) {
        _resolvedGutterWidth = _lineNumberWidth;
      } else {
        // Auto-compute from the string representation of the child count
        // (e.g. "5" for 5 children, "15" for 15 children) plus 16 dp padding.
        final labelStyle = _lineNumberTextStyle ?? const TextStyle(fontSize: 12);
        final label = '$childCount';
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        _resolvedGutterWidth = tp.width + 16.0;
      }
    } else {
      _resolvedGutterWidth = 0.0;
    }

    // Reduce the available content width by horizontal padding.
    final contentLeft = _documentPadding.left + _resolvedGutterWidth;
    final preferredWidth =
        (_viewportWidth ?? maxW) - _documentPadding.horizontal - _resolvedGutterWidth;
    // Start placing children below the top padding.
    var yOffset = _documentPadding.top;
    var childIndex = 0;
    var widestChild = 0.0;

    // Independent exclusion zones for start (left) and end (right) floats.
    // A center float reuses [_centerExclusion] for interior-exclusion wrapping.
    _ExclusionZone? startExclusion;
    _ExclusionZone? endExclusion;
    _ExclusionZone? centerExclusion;

    RenderDocumentBlock? child = firstChild;

    while (child != null) {
      final parentData = child.parentData as DocumentBlockParentData;
      final alignment = child.blockAlignment;
      final wrapMode = child.textWrap;
      final isFloat = wrapMode != TextWrapMode.none &&
          (alignment == BlockAlignment.start ||
              alignment == BlockAlignment.end ||
              alignment == BlockAlignment.center);
      parentData.isFloat = isFloat;
      parentData.wrapMode = wrapMode;
      parentData.exclusionRect = null;
      parentData.exclusionRects = null;

      if (childIndex > 0) {
        // Per-block spacing: use max(prevSpaceAfter, curSpaceBefore).
        // When both are null, fall back to _blockSpacing.
        final prevChild = childBefore(child);
        final prevSpaceAfter = prevChild?.spaceAfter;
        final curSpaceBefore = child.spaceBefore;
        if (prevSpaceAfter != null || curSpaceBefore != null) {
          yOffset += max(prevSpaceAfter ?? 0, curSpaceBefore ?? 0);
        } else {
          yOffset += _blockSpacing;
        }
      }

      // Clear each exclusion zone independently when yOffset passes its bottom.
      if (startExclusion != null && yOffset >= startExclusion.bottom) {
        startExclusion = null;
      }
      if (endExclusion != null && yOffset >= endExclusion.bottom) {
        endExclusion = null;
      }
      if (centerExclusion != null && yOffset >= centerExclusion.bottom) {
        centerExclusion = null;
      }

      // Determine whether any exclusion is active at the current yOffset.
      final hasStart = startExclusion != null && yOffset < startExclusion.bottom;
      final hasEnd = endExclusion != null && yOffset < endExclusion.bottom;
      final hasCenter = centerExclusion != null && yOffset < centerExclusion.bottom;

      if (alignment == BlockAlignment.stretch) {
        // Case 1: Stretch — fill width, but account for active exclusion zones.
        double childMaxWidth = preferredWidth;
        double xOffset = 0.0;

        if (child.clearsFloat && (hasStart || hasEnd || hasCenter)) {
          // Block wants full width — advance past all active floats.
          final clearBottom = _maxExclusionBottom(startExclusion, endExclusion, centerExclusion);
          yOffset = clearBottom;
          startExclusion = null;
          endExclusion = null;
          centerExclusion = null;
        } else if (hasCenter) {
          // Full width, but pass the interior exclusion to the child.
          final ce = centerExclusion; // non-null: hasCenter guarantees this
          childMaxWidth = preferredWidth;
          xOffset = 0.0;
          parentData.exclusionRect = Rect.fromLTRB(
            ce.floatLeft - _kFloatGap,
            max(0.0, ce.top - yOffset),
            ce.floatLeft + ce.width + _kFloatGap,
            ce.bottom - yOffset,
          );
        } else if (hasStart && !hasEnd) {
          if (child.requestedWidth == null && !child.prefersNarrowedFloat) {
            // Text-like stretch block beside a single start float: pass full-width
            // constraints plus an exclusionRect so [RenderTextBlock] can split
            // the text into above/beside/below zones and return to full width once
            // the text content passes the float's bottom edge.
            childMaxWidth = preferredWidth;
            xOffset = 0.0;
            parentData.exclusionRect = Rect.fromLTRB(
              0,
              max(0.0, startExclusion.top - yOffset),
              startExclusion.width,
              startExclusion.bottom - yOffset,
            );
          } else {
            // Sized block (image, code, etc.) with an explicit requestedWidth,
            // or a block that prefers narrowed-width constraints (e.g. a code
            // block with an opaque background).  Narrow the available width to
            // fit beside the float; the block clamps its width to the reduced
            // constraint.
            childMaxWidth = max(0.0, preferredWidth - startExclusion.width);
            xOffset = startExclusion.width;
          }
        } else if (hasEnd && !hasStart) {
          if (child.requestedWidth == null && !child.prefersNarrowedFloat) {
            // Text-like stretch block beside a single end float: same treatment —
            // full-width constraints plus a right-side exclusionRect.
            childMaxWidth = preferredWidth;
            xOffset = 0.0;
            parentData.exclusionRect = Rect.fromLTRB(
              preferredWidth - endExclusion.width,
              max(0.0, endExclusion.top - yOffset),
              preferredWidth,
              endExclusion.bottom - yOffset,
            );
          } else {
            // Sized block — narrow from the right.
            childMaxWidth = max(0.0, preferredWidth - endExclusion.width);
            xOffset = 0.0;
          }
        } else if (hasStart && hasEnd) {
          if (child.requestedWidth == null && !child.prefersNarrowedFloat) {
            // Text-like stretch block beside both a start and end float: pass
            // full-width constraints with dual exclusion rects so [RenderTextBlock]
            // can split text into above/beside/below zones and expand to full
            // width once the text content passes both floats' bottoms.
            childMaxWidth = preferredWidth;
            xOffset = 0.0;
            parentData.exclusionRects = [
              Rect.fromLTRB(
                0,
                max(0.0, startExclusion.top - yOffset),
                startExclusion.width,
                startExclusion.bottom - yOffset,
              ),
              Rect.fromLTRB(
                preferredWidth - endExclusion.width,
                max(0.0, endExclusion.top - yOffset),
                preferredWidth,
                endExclusion.bottom - yOffset,
              ),
            ];
          } else {
            // Sized block (image, code, etc.) with an explicit requestedWidth,
            // or a block that prefers narrowed-width constraints.  Fall back to
            // the narrowed-width approach: no exclusion rects.
            final startWidth = startExclusion.width;
            final endWidth = endExclusion.width;
            childMaxWidth = max(0.0, preferredWidth - startWidth - endWidth);
            xOffset = startWidth;
          }
        }

        child.layout(
          DocumentBlockConstraints(
            minWidth: childMaxWidth,
            maxWidth: childMaxWidth,
            exclusionRect: parentData.exclusionRect,
            exclusionRects: parentData.exclusionRects,
          ),
          parentUsesSize: true,
        );
        parentData.offset = Offset(contentLeft + xOffset, yOffset);
        widestChild = max(widestChild, parentData.offset.dx + child.size.width);
        yOffset += child.size.height;
      } else if (isFloat) {
        // Case 3: Float — aligned block with text wrap enabled.

        // If the same side's exclusion is still active, advance past it so
        // consecutive same-side floats stack vertically rather than overlapping.
        // For opposite-side floats, allow concurrent placement.
        //
        // Also clear any active center exclusion when placing a side float.
        // A center exclusion and a start/end exclusion cannot coexist — the
        // side float must be placed below the center float's bottom so that
        // subsequent stretch blocks only see one kind of exclusion at a time.
        if (alignment == BlockAlignment.start) {
          if (hasStart) {
            yOffset = startExclusion.bottom; // non-null: hasStart guarantees this
            startExclusion = null;
          }
          if (hasCenter) {
            yOffset = max(yOffset, centerExclusion.bottom); // non-null: hasCenter guarantees this
            centerExclusion = null;
          }
        } else if (alignment == BlockAlignment.end) {
          if (hasEnd) {
            yOffset = endExclusion.bottom; // non-null: hasEnd guarantees this
            endExclusion = null;
          }
          if (hasCenter) {
            yOffset = max(yOffset, centerExclusion.bottom); // non-null: hasCenter guarantees this
            centerExclusion = null;
          }
        } else if (alignment == BlockAlignment.center && (hasStart || hasEnd || hasCenter)) {
          // Center floats clear all active exclusions.
          final clearBottom = _maxExclusionBottom(startExclusion, endExclusion, centerExclusion);
          yOffset = clearBottom;
          startExclusion = null;
          endExclusion = null;
          centerExclusion = null;
        }

        final childWidth = child.requestedWidth ?? preferredWidth;
        final childConstraints = BoxConstraints(maxWidth: childWidth);
        child.layout(childConstraints, parentUsesSize: true);

        final double xOffset;
        if (alignment == BlockAlignment.center) {
          xOffset = max(0.0, (preferredWidth - child.size.width) / 2);
        } else if (alignment == BlockAlignment.start) {
          xOffset = 0.0;
        } else {
          // BlockAlignment.end — clamp to 0 so oversized blocks start at the
          // left edge and expand the layout rightward.
          xOffset = max(0.0, preferredWidth - child.size.width);
        }

        parentData.offset = Offset(contentLeft + xOffset, yOffset);
        widestChild = max(widestChild, parentData.offset.dx + child.size.width);

        // Create exclusion zone ONLY for TextWrapMode.wrap.
        // behindText and inFrontOfText position like floats but don't create
        // exclusions, so subsequent blocks overlay/underlay with no wrapping.
        if (wrapMode == TextWrapMode.wrap) {
          final zone = _ExclusionZone(
            side: alignment,
            width: alignment == BlockAlignment.center
                ? child.size.width
                : child.size.width + _kFloatGap,
            top: yOffset,
            bottom: yOffset + child.size.height,
            floatLeft: xOffset,
          );
          if (alignment == BlockAlignment.start) {
            startExclusion = zone;
          } else if (alignment == BlockAlignment.end) {
            endExclusion = zone;
          } else {
            centerExclusion = zone;
          }
        }

        // Do not advance yOffset — next block wraps beside the float.
      } else {
        // Case 2: Aligned, no text wrap — block takes a full vertical row.
        // When there is an active start/end exclusion zone, check whether
        // the block fits beside the float.  If it fits, position it there
        // respecting its alignment within the available space.  If it doesn't
        // fit, advance past the float as before.
        if ((hasStart || hasEnd) && !hasCenter) {
          // Use the single active exclusion for "fits beside float" logic.
          // When both are active, defer to full-clearing behaviour below.
          final singleExclusion =
              hasStart && !hasEnd ? startExclusion : (!hasStart && hasEnd ? endExclusion : null);

          if (singleExclusion != null) {
            final availableWidth = preferredWidth - singleExclusion.width;
            final childWidth = child.requestedWidth ?? preferredWidth;

            if (childWidth <= availableWidth) {
              // Block fits beside the float — lay it out and position it within
              // the available space, respecting the block's alignment.
              child.layout(BoxConstraints(maxWidth: childWidth), parentUsesSize: true);

              final double xOffset;
              if (singleExclusion.side == BlockAlignment.start) {
                // Float is on the start (left) side; available space is to the right.
                final availableLeft = singleExclusion.width;
                xOffset = switch (alignment) {
                  BlockAlignment.start => availableLeft,
                  BlockAlignment.center =>
                    availableLeft + max(0.0, (availableWidth - child.size.width) / 2),
                  BlockAlignment.end =>
                    max(availableLeft, availableLeft + availableWidth - child.size.width),
                  BlockAlignment.stretch => availableLeft,
                };
              } else {
                // Float is on the end (right) side; available space is to the left.
                xOffset = switch (alignment) {
                  BlockAlignment.start => 0.0,
                  BlockAlignment.center => max(0.0, (availableWidth - child.size.width) / 2),
                  BlockAlignment.end => max(0.0, availableWidth - child.size.width),
                  BlockAlignment.stretch => 0.0,
                };
              }

              parentData.offset = Offset(contentLeft + max(0.0, xOffset), yOffset);
              widestChild = max(widestChild, parentData.offset.dx + child.size.width);
              yOffset += child.size.height;
            } else {
              // Block is too wide to fit beside the float — clear it.
              yOffset = singleExclusion.bottom;
              if (singleExclusion.side == BlockAlignment.start) {
                startExclusion = null;
              } else {
                endExclusion = null;
              }

              final childConstraints = BoxConstraints(maxWidth: childWidth);
              child.layout(childConstraints, parentUsesSize: true);

              final double xOffset;
              switch (alignment) {
                case BlockAlignment.start:
                  xOffset = 0.0;
                case BlockAlignment.center:
                  xOffset = max(0.0, (preferredWidth - child.size.width) / 2);
                case BlockAlignment.end:
                  xOffset = max(0.0, preferredWidth - child.size.width);
                case BlockAlignment.stretch:
                  xOffset = 0.0;
              }

              parentData.offset = Offset(contentLeft + xOffset, yOffset);
              widestChild = max(widestChild, parentData.offset.dx + child.size.width);
              yOffset += child.size.height;
            }
          } else {
            // Both start and end are active — clear all exclusions.
            final clearBottom = _maxExclusionBottom(startExclusion, endExclusion, null);
            yOffset = clearBottom;
            startExclusion = null;
            endExclusion = null;

            final childWidth = child.requestedWidth ?? preferredWidth;
            final childConstraints = BoxConstraints(maxWidth: childWidth);
            child.layout(childConstraints, parentUsesSize: true);

            final double xOffset;
            switch (alignment) {
              case BlockAlignment.start:
                xOffset = 0.0;
              case BlockAlignment.center:
                xOffset = max(0.0, (preferredWidth - child.size.width) / 2);
              case BlockAlignment.end:
                xOffset = max(0.0, preferredWidth - child.size.width);
              case BlockAlignment.stretch:
                xOffset = 0.0;
            }

            parentData.offset = Offset(contentLeft + xOffset, yOffset);
            widestChild = max(widestChild, parentData.offset.dx + child.size.width);
            yOffset += child.size.height;
          }
        } else {
          // No active start/end exclusion (or a center exclusion) — clear any
          // remaining exclusion and lay out normally.
          if (hasCenter) {
            yOffset = centerExclusion.bottom;
            centerExclusion = null;
          }

          final childWidth = child.requestedWidth ?? preferredWidth;
          final childConstraints = BoxConstraints(maxWidth: childWidth);
          child.layout(childConstraints, parentUsesSize: true);

          final double xOffset;
          switch (alignment) {
            case BlockAlignment.start:
              xOffset = 0.0;
            case BlockAlignment.center:
              // Clamp to 0 so oversized blocks start at the left edge.
              xOffset = max(0.0, (preferredWidth - child.size.width) / 2);
            case BlockAlignment.end:
              // Clamp to 0 so oversized blocks start at the left edge.
              xOffset = max(0.0, preferredWidth - child.size.width);
            case BlockAlignment.stretch:
              xOffset = 0.0; // Already handled above, but for completeness.
          }

          parentData.offset = Offset(contentLeft + xOffset, yOffset);
          widestChild = max(widestChild, parentData.offset.dx + child.size.width);
          yOffset += child.size.height;
        }
      }

      childIndex++;
      child = childAfter(child);
    }

    // If there are still active exclusions, ensure total height accounts for them.
    final finalExclusionBottom = _maxExclusionBottom(startExclusion, endExclusion, centerExclusion);
    if (finalExclusionBottom > yOffset) {
      yOffset = finalExclusionBottom;
    }

    // Add bottom padding to total height.
    // Layout width: use the full preferred width (before padding was subtracted),
    // or the widest child (which already includes contentLeft in its dx).
    final totalHeight = yOffset + _documentPadding.bottom;
    final fullPreferredWidth = preferredWidth + _documentPadding.horizontal;
    size = Size(max(fullPreferredWidth, widestChild), totalHeight);
  }

  /// Returns the maximum [_ExclusionZone.bottom] among the given exclusion
  /// zones, or `0.0` if all are `null`.
  static double _maxExclusionBottom(
    _ExclusionZone? a,
    _ExclusionZone? b,
    _ExclusionZone? c,
  ) {
    var bottom = 0.0;
    if (a != null) bottom = max(bottom, a.bottom);
    if (b != null) bottom = max(bottom, b.bottom);
    if (c != null) bottom = max(bottom, c.bottom);
    return bottom;
  }

  // ---------------------------------------------------------------------------
  // Baseline
  // ---------------------------------------------------------------------------

  /// Returns the distance from this layout's top edge to the baseline of the
  /// first child that reports a non-null baseline.
  ///
  /// Delegates to [RenderBoxContainerDefaultsMixin.defaultComputeDistanceToFirstActualBaseline],
  /// which walks children in order, asks each for its baseline, and adds the
  /// child's paint offset so the result is in this layout's coordinate space.
  ///
  /// Returns `null` when there are no children (empty document).
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToFirstActualBaseline(baseline);
  }

  /// Returns the speculative baseline distance for the given [constraints].
  ///
  /// Asks the first child for its dry baseline at the same [constraints] and
  /// returns that value (first child's paint offset is always `Offset.zero`
  /// so no adjustment is needed).
  ///
  /// Returns `null` when there are no children.
  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final first = firstChild;
    if (first == null) return null;
    return first.getDryBaseline(
      BoxConstraints(maxWidth: constraints.maxWidth),
      baseline,
    );
  }

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  /// Paints the gutter and children.
  ///
  /// **Gutter pass** (when [showLineNumbers] is `true`) — the line-number
  /// background and labels are painted first, before any child content.
  ///
  /// **Pass 1** — [TextWrapMode.behindText] float children are painted first,
  /// behind all other content.
  ///
  /// **Pass 2** — non-float children ([DocumentBlockParentData.isFloat] is
  /// `false`) are painted in document order.  This includes stretch blocks
  /// that may wrap beside a float and have an opaque background.
  ///
  /// **Pass 3** — [TextWrapMode.wrap] and [TextWrapMode.inFrontOfText] float
  /// children are painted last, on top of all non-float content.  This ensures
  /// that a floated image (or any other float block) is never obscured by the
  /// background of a later wrapping block.
  @override
  void paint(PaintingContext context, Offset offset) {
    // -------------------------------------------------------------------
    // Gutter pass: paint line-number background and labels.
    // -------------------------------------------------------------------
    if (_showLineNumbers && _resolvedGutterWidth > 0.0) {
      final canvas = context.canvas;

      // Paint gutter background if a color is set.
      final bgColor = _lineNumberBackgroundColor;
      if (bgColor != null) {
        final gutterRect = Rect.fromLTWH(
          offset.dx + _documentPadding.left,
          offset.dy,
          _resolvedGutterWidth,
          size.height,
        );
        canvas.drawRect(gutterRect, Paint()..color = bgColor);
      }

      // Paint line-number labels for non-float children.
      final labelStyle = _lineNumberTextStyle ?? const TextStyle(fontSize: 12);
      final tp = TextPainter(textDirection: TextDirection.ltr);
      var lineNumber = 1;

      RenderDocumentBlock? child = firstChild;
      while (child != null) {
        final parentData = child.parentData as DocumentBlockParentData;

        if (!parentData.isFloat) {
          // Right-align the label with 8 dp from the gutter's right edge.
          final label = '$lineNumber';
          tp.text = TextSpan(text: label, style: labelStyle);
          tp.layout();

          // Gutter right edge in global coordinates.
          final gutterRight = offset.dx + _documentPadding.left + _resolvedGutterWidth;
          final labelX = gutterRight - 8.0 - tp.width;
          // Vertical position based on lineNumberAlignment.
          final double labelY;
          switch (_lineNumberAlignment) {
            case LineNumberAlignment.top:
              labelY = offset.dy + parentData.offset.dy;
            case LineNumberAlignment.middle:
              labelY = offset.dy + parentData.offset.dy + (child.size.height - tp.height) / 2;
            case LineNumberAlignment.bottom:
              labelY = offset.dy + parentData.offset.dy + child.size.height - tp.height;
          }
          tp.paint(canvas, Offset(labelX, labelY));

          lineNumber++;
        }

        child = childAfter(child);
      }
    }

    // Pass 1: behindText floats (painted behind everything).
    RenderDocumentBlock? child = firstChild;
    while (child != null) {
      final parentData = child.parentData as DocumentBlockParentData;
      if (parentData.isFloat && parentData.wrapMode == TextWrapMode.behindText) {
        context.paintChild(child, offset + parentData.offset);
      }
      child = childAfter(child);
    }

    // Pass 2: non-float children (normal document order).
    child = firstChild;
    while (child != null) {
      final parentData = child.parentData as DocumentBlockParentData;
      if (!parentData.isFloat) {
        context.paintChild(child, offset + parentData.offset);
      }
      child = childAfter(child);
    }

    // Pass 3: wrap + inFrontOfText floats (painted on top).
    child = firstChild;
    while (child != null) {
      final parentData = child.parentData as DocumentBlockParentData;
      if (parentData.isFloat && parentData.wrapMode != TextWrapMode.behindText) {
        context.paintChild(child, offset + parentData.offset);
      }
      child = childAfter(child);
    }
  }

  // ---------------------------------------------------------------------------
  // Hit testing
  // ---------------------------------------------------------------------------

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  // ---------------------------------------------------------------------------
  // Scroll extent
  // ---------------------------------------------------------------------------

  /// Returns the maximum scroll offset for a viewport of [viewportHeight] pixels.
  ///
  /// A non-negative value: `max(0, totalContentHeight - viewportHeight)`.
  double computeMaxScrollExtent(double viewportHeight) {
    return (size.height - viewportHeight).clamp(0.0, double.infinity);
  }

  // ---------------------------------------------------------------------------
  // Geometry queries
  // ---------------------------------------------------------------------------

  /// Returns the [RenderDocumentBlock] whose [RenderDocumentBlock.nodeId]
  /// equals [nodeId], or `null` if no child matches.
  RenderDocumentBlock? getComponentByNodeId(String nodeId) {
    RenderDocumentBlock? child = firstChild;
    while (child != null) {
      if (child.nodeId == nodeId) return child;
      child = childAfter(child);
    }
    return null;
  }

  /// Returns the [DocumentPosition] for the child whose bounds contain
  /// [localOffset], or `null` if the offset falls outside all children.
  ///
  /// Unlike the previous y-only check, this method uses the full child rect
  /// so that float layouts — where blocks can share the same y-range — are
  /// hit-tested correctly.
  DocumentPosition? getDocumentPositionAtOffset(Offset localOffset) {
    // Walk children and check both x and y bounds.
    RenderDocumentBlock? child = firstChild;
    while (child != null) {
      final childData = child.parentData as DocumentBlockParentData;
      final childRect = childData.offset & child.size;

      if (childRect.contains(localOffset)) {
        final childLocalOffset = localOffset - childData.offset;
        final nodePos = child.getPositionAtOffset(childLocalOffset);
        return DocumentPosition(nodeId: child.nodeId, nodePosition: nodePos);
      }

      child = childAfter(child);
    }
    return null;
  }

  /// Returns the [DocumentPosition] nearest to [localOffset], always
  /// returning a valid position even when the offset falls outside all
  /// children.
  ///
  /// First attempts an exact hit via [getDocumentPositionAtOffset].  When that
  /// misses, it finds the nearest child using Y-primary, X-secondary distance
  /// from [localOffset] to each child's bounding rect, then delegates to that
  /// child's [RenderDocumentBlock.getPositionAtOffset] with the offset clamped
  /// to the child bounds.
  ///
  /// Y-primary ordering ensures that vertical arrow-key navigation always
  /// reaches narrow, non-stretch blocks (e.g. center-aligned images) even
  /// when the caret's X coordinate falls outside the block's horizontal bounds.
  DocumentPosition getDocumentPositionNearestToOffset(Offset localOffset) {
    if (firstChild == null) {
      // No children — should not occur in practice, but guard against it.
      return const DocumentPosition(
        nodeId: '',
        nodePosition: _FallbackNodePosition(),
      );
    }

    // Try an exact hit first.
    final exact = getDocumentPositionAtOffset(localOffset);
    if (exact != null) return exact;

    // Find the nearest child using Y-primary, X-secondary distance.
    RenderDocumentBlock? nearest;
    double nearestYDist = double.infinity;
    double nearestXDist = double.infinity;

    RenderDocumentBlock? child = firstChild;
    while (child != null) {
      final childData = child.parentData as DocumentBlockParentData;
      final childRect = childData.offset & child.size;
      final yDist = _axisDistance(localOffset.dy, childRect.top, childRect.bottom);
      final xDist = _axisDistance(localOffset.dx, childRect.left, childRect.right);

      if (yDist < nearestYDist || (yDist == nearestYDist && xDist < nearestXDist)) {
        nearestYDist = yDist;
        nearestXDist = xDist;
        nearest = child;
      }
      child = childAfter(child);
    }

    final nearestData = nearest!.parentData as DocumentBlockParentData;
    final clampedOffset = Offset(
      (localOffset.dx - nearestData.offset.dx).clamp(0.0, nearest.size.width),
      (localOffset.dy - nearestData.offset.dy).clamp(0.0, nearest.size.height - 1),
    );
    final nodePos = nearest.getPositionAtOffset(clampedOffset);
    return DocumentPosition(nodeId: nearest.nodeId, nodePosition: nodePos);
  }

  /// Returns the absolute distance from [value] to the range [lo]..[hi].
  ///
  /// Returns 0 when [value] is inside the range.
  static double _axisDistance(double value, double lo, double hi) {
    if (value < lo) return lo - value;
    if (value > hi) return value - hi;
    return 0.0;
  }

  /// Returns the bounding [Rect], in this layout's local coordinates, for the
  /// given [DocumentPosition].
  ///
  /// Finds the child whose [RenderDocumentBlock.nodeId] matches
  /// `pos.nodeId`, delegates to [RenderDocumentBlock.getLocalRectForPosition],
  /// and offsets the result by the child's paint offset.
  ///
  /// Returns `null` when no child has a matching node id.
  Rect? getRectForDocumentPosition(DocumentPosition pos) {
    final component = getComponentByNodeId(pos.nodeId);
    if (component == null) return null;

    final childData = component.parentData as DocumentBlockParentData;
    final localRect = component.getLocalRectForPosition(pos.nodePosition);
    return localRect.shift(childData.offset);
  }

  /// Returns the set of highlight [Rect]s (in this layout's local coordinates)
  /// that represent [selection].
  ///
  /// ## Same-node selections
  ///
  /// When both [DocumentSelection.base] and [DocumentSelection.extent] refer to
  /// the same node, the method delegates directly to
  /// [RenderDocumentBlock.getEndpointsForSelection].  This uses
  /// [TextPainter.getBoxesForSelection] internally, which correctly handles
  /// mixed-font lines — avoiding the caret y-value comparison that fails when
  /// different fonts produce slightly different ascent values.
  ///
  /// ## Cross-node selections
  ///
  /// When the selection spans multiple nodes the method iterates through each
  /// block between the upstream and downstream endpoints, producing rects that
  /// respect each block's actual bounds (accounting for float offsets):
  ///
  /// - **Upstream block** (partial): from the caret position to the block's
  ///   right edge.
  /// - **Intermediate blocks** (fully selected): the block's full bounds.
  ///   Float blocks are skipped since they are not part of the text flow.
  /// - **Downstream block** (partial): from the block's left edge to the caret
  ///   position.
  ///
  /// Returns an empty list when:
  /// - [selection] is collapsed.
  /// - Either endpoint's node cannot be found among this layout's children.
  List<Rect> getRectsForSelection(DocumentSelection selection) {
    if (selection.isCollapsed) return const [];

    final base = selection.base;
    final extent = selection.extent;

    // -----------------------------------------------------------------------
    // Same-node path — delegate to the component's getEndpointsForSelection.
    // This correctly handles mixed fonts by using TextPainter.getBoxesForSelection.
    // -----------------------------------------------------------------------
    if (base.nodeId == extent.nodeId) {
      final component = getComponentByNodeId(base.nodeId);
      if (component == null) return const [];

      final childData = component.parentData as DocumentBlockParentData;
      final localRects = component.getEndpointsForSelection(base.nodePosition, extent.nodePosition);
      return localRects.map((r) => r.shift(childData.offset)).toList();
    }

    // -----------------------------------------------------------------------
    // Cross-node path — per-block iteration respecting actual block bounds.
    // -----------------------------------------------------------------------
    final baseComponent = getComponentByNodeId(base.nodeId);
    final extentComponent = getComponentByNodeId(extent.nodeId);
    if (baseComponent == null || extentComponent == null) return const [];

    final baseRect = getRectForDocumentPosition(base);
    final extentRect = getRectForDocumentPosition(extent);
    if (baseRect == null || extentRect == null) return const [];

    // Determine document order: walk the child list to find which comes first.
    final bool baseIsUpstream = _isBeforeInChildList(baseComponent, extentComponent);
    final RenderDocumentBlock upstreamBlock = baseIsUpstream ? baseComponent : extentComponent;
    final RenderDocumentBlock downstreamBlock = baseIsUpstream ? extentComponent : baseComponent;
    final Rect upstreamCaret = baseIsUpstream ? baseRect : extentRect;
    final Rect downstreamCaret = baseIsUpstream ? extentRect : baseRect;

    final rects = <Rect>[];

    // --- Upstream block (partial): caret to block's right edge ---
    final upData = upstreamBlock.parentData as DocumentBlockParentData;
    final upBlockRight = upData.offset.dx + upstreamBlock.size.width;
    rects.add(Rect.fromLTRB(
      upstreamCaret.left,
      upstreamCaret.top,
      upBlockRight,
      upstreamCaret.bottom,
    ));
    // If the upstream caret is not on the last line, fill below it to block bottom.
    final upBlockBottom = upData.offset.dy + upstreamBlock.size.height;
    if (upstreamCaret.bottom < upBlockBottom - 1.0) {
      rects.add(Rect.fromLTRB(
        upData.offset.dx,
        upstreamCaret.bottom,
        upBlockRight,
        upBlockBottom,
      ));
    }

    // --- Intermediate blocks (fully selected): use actual block bounds ---
    RenderDocumentBlock? child = childAfter(upstreamBlock);
    while (child != null && child != downstreamBlock) {
      final childData = child.parentData as DocumentBlockParentData;
      // Skip float blocks — they are not part of the text flow.
      if (!childData.isFloat) {
        rects.add(childData.offset & child.size);
      }
      child = childAfter(child);
    }

    // --- Downstream block (partial): block's left edge to caret ---
    final downData = downstreamBlock.parentData as DocumentBlockParentData;
    final downBlockLeft = downData.offset.dx;
    // If the downstream caret is not on the first line, fill above it from block top.
    if (downstreamCaret.top > downData.offset.dy + 1.0) {
      rects.add(Rect.fromLTRB(
        downBlockLeft,
        downData.offset.dy,
        downData.offset.dx + downstreamBlock.size.width,
        downstreamCaret.top,
      ));
    }
    rects.add(Rect.fromLTRB(
      downBlockLeft,
      downstreamCaret.top,
      downstreamCaret.right,
      downstreamCaret.bottom,
    ));

    return rects;
  }

  /// Returns `true` when [a] appears before [b] in the child list.
  bool _isBeforeInChildList(RenderDocumentBlock a, RenderDocumentBlock b) {
    RenderDocumentBlock? child = firstChild;
    while (child != null) {
      if (identical(child, a)) return true;
      if (identical(child, b)) return false;
      child = childAfter(child);
    }
    return true; // fallback — should not occur
  }

  // ---------------------------------------------------------------------------
  // Semantics
  // ---------------------------------------------------------------------------

  /// Configures the semantics of this document layout node.
  ///
  /// Sets three flags that together ensure the accessibility tree correctly
  /// represents an editable document:
  ///
  /// * [SemanticsConfiguration.isSemanticBoundary] — marks this render object
  ///   as a semantics boundary, isolating the document's subtree from its
  ///   ancestor in the accessibility tree.
  ///
  /// * [SemanticsConfiguration.explicitChildNodes] — instructs the semantics
  ///   system to create individual semantics nodes for each child block rather
  ///   than merging them into this node.  This allows screen readers to
  ///   navigate between document blocks (paragraphs, images, rules, etc.)
  ///   individually.
  ///
  /// * [SemanticsConfiguration.liveRegion] — marks the document as a live
  ///   region so that assistive technologies announce content changes (e.g.
  ///   newly inserted text or pasted blocks) without requiring the user to
  ///   move focus.
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..liveRegion = true;
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('blockSpacing', blockSpacing));
    properties.add(DoubleProperty('viewportWidth', viewportWidth, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsets>('documentPadding', documentPadding,
        defaultValue: EdgeInsets.zero));
    properties
        .add(DiagnosticsProperty<bool>('showLineNumbers', showLineNumbers, defaultValue: false));
    properties.add(DoubleProperty('lineNumberWidth', lineNumberWidth, defaultValue: 0.0));
    properties.add(DiagnosticsProperty<TextStyle>('lineNumberTextStyle', lineNumberTextStyle,
        defaultValue: null));
    properties.add(
        ColorProperty('lineNumberBackgroundColor', lineNumberBackgroundColor, defaultValue: null));
    properties.add(EnumProperty<LineNumberAlignment>('lineNumberAlignment', lineNumberAlignment,
        defaultValue: LineNumberAlignment.top));
  }
}

// ---------------------------------------------------------------------------
// Internal fallback (guards against empty-document edge case)
// ---------------------------------------------------------------------------

/// A sentinel [NodePosition] returned only when [RenderDocumentLayout] has no
/// children.
///
/// This type is not part of the public API and is only used internally to
/// satisfy the non-nullable return type of
/// [RenderDocumentLayout.getDocumentPositionNearestToOffset] in the
/// pathological case of a completely empty layout.
class _FallbackNodePosition implements NodePosition {
  const _FallbackNodePosition();
}
