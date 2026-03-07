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
  });

  /// Which side the float is on.
  final BlockAlignment side;

  /// Width consumed by the float (including gap).
  final double width;

  /// Top of the exclusion zone in layout coordinates.
  final double top;

  /// Bottom of the exclusion zone in layout coordinates.
  final double bottom;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Horizontal gap between a floated block and adjacent content.
const double _kFloatGap = 8.0;

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
/// - [BlockAlignment.start] / [BlockAlignment.end] (without [RenderDocumentBlock.textWrap])
///   — the block is aligned to the corresponding edge but occupies a full
///   vertical row (no wrapping of adjacent content).
/// - [BlockAlignment.start] / [BlockAlignment.end] (with [RenderDocumentBlock.textWrap] `true`)
///   — the block becomes a *float*: it is pinned to the edge, and subsequent
///   blocks are narrowed to wrap beside it until the float's bottom is cleared.
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
/// in [DocumentBlockParentData.offset].  No spacing is added before the first
/// child or after the last child.
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
  /// Creates a [RenderDocumentLayout] with optional [blockSpacing] and [viewportWidth].
  ///
  /// [blockSpacing] is the vertical gap in logical pixels inserted between
  /// consecutive children.  Defaults to `12.0`.
  ///
  /// [viewportWidth] overrides the constraint width used to lay out and size
  /// each block.  When `null` (the default), the layout uses
  /// `constraints.maxWidth`.  Supply a fixed value (e.g. the viewport pixel
  /// width) when the layout is inside an infinite-width scroll view so that
  /// blocks size to the visible area rather than to infinity.
  RenderDocumentLayout({double blockSpacing = 12.0, double? viewportWidth})
      : _blockSpacing = blockSpacing,
        _viewportWidth = viewportWidth;

  // ---------------------------------------------------------------------------
  // blockSpacing
  // ---------------------------------------------------------------------------

  double _blockSpacing;

  // ---------------------------------------------------------------------------
  // viewportWidth
  // ---------------------------------------------------------------------------

  double? _viewportWidth;

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
    return total;
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    final maxW = constraints.maxWidth;
    final preferredWidth = _viewportWidth ?? maxW;
    var yOffset = 0.0;
    var childIndex = 0;
    var widestChild = 0.0;
    _ExclusionZone? activeExclusion;
    RenderDocumentBlock? child = firstChild;

    while (child != null) {
      final parentData = child.parentData as DocumentBlockParentData;
      final alignment = child.blockAlignment;
      final isFloat =
          child.textWrap && (alignment == BlockAlignment.start || alignment == BlockAlignment.end);
      parentData.isFloat = isFloat;

      if (childIndex > 0) {
        yOffset += _blockSpacing;
      }

      // Check if the active exclusion zone has been cleared (we're past its bottom).
      if (activeExclusion != null && yOffset >= activeExclusion.bottom) {
        activeExclusion = null;
      }

      if (alignment == BlockAlignment.stretch) {
        // Case 1: Stretch — fill width, but account for any active exclusion zone.
        double childMaxWidth = preferredWidth;
        double xOffset = 0.0;

        if (activeExclusion != null && yOffset < activeExclusion.bottom) {
          // Narrow the block to avoid the exclusion zone.
          childMaxWidth = preferredWidth - activeExclusion.width;
          if (activeExclusion.side == BlockAlignment.start) {
            xOffset = activeExclusion.width;
          }
        }

        child.layout(
          BoxConstraints.tightFor(width: childMaxWidth),
          parentUsesSize: true,
        );
        parentData.offset = Offset(xOffset, yOffset);
        widestChild = max(widestChild, parentData.offset.dx + child.size.width);
        yOffset += child.size.height;
      } else if (isFloat) {
        // Case 3: Float — aligned block with text wrap enabled.
        final childWidth = child.requestedWidth ?? preferredWidth;
        final childConstraints = BoxConstraints(maxWidth: childWidth);
        child.layout(childConstraints, parentUsesSize: true);

        final double xOffset;
        if (alignment == BlockAlignment.start) {
          xOffset = 0.0;
        } else {
          // BlockAlignment.end
          xOffset = preferredWidth - child.size.width;
        }

        parentData.offset = Offset(xOffset, yOffset);
        widestChild = max(widestChild, parentData.offset.dx + child.size.width);

        // Create exclusion zone so subsequent blocks wrap beside the float.
        activeExclusion = _ExclusionZone(
          side: alignment,
          width: child.size.width + _kFloatGap,
          top: yOffset,
          bottom: yOffset + child.size.height,
        );

        // Do not advance yOffset — next block wraps beside the float.
      } else {
        // Case 2: Aligned, no text wrap — block takes a full vertical row.
        final childWidth = child.requestedWidth ?? preferredWidth;
        final childConstraints = BoxConstraints(maxWidth: childWidth);
        child.layout(childConstraints, parentUsesSize: true);

        final double xOffset;
        switch (alignment) {
          case BlockAlignment.start:
            xOffset = 0.0;
          case BlockAlignment.center:
            xOffset = (preferredWidth - child.size.width) / 2;
          case BlockAlignment.end:
            xOffset = preferredWidth - child.size.width;
          case BlockAlignment.stretch:
            xOffset = 0.0; // Already handled above, but for completeness.
        }

        parentData.offset = Offset(xOffset, yOffset);
        widestChild = max(widestChild, parentData.offset.dx + child.size.width);
        yOffset += child.size.height;
      }

      childIndex++;
      child = childAfter(child);
    }

    // If there is still an active exclusion, ensure total height accounts for it.
    if (activeExclusion != null && activeExclusion.bottom > yOffset) {
      yOffset = activeExclusion.bottom;
    }

    size = Size(max(preferredWidth, widestChild), yOffset);
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

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
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
  /// misses, it finds the nearest child by Euclidean distance from [localOffset]
  /// to each child's bounding rect, then delegates to that child's
  /// [RenderDocumentBlock.getPositionAtOffset] with the offset clamped to the
  /// child bounds.
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

    // Find the nearest child by distance from offset to child rect.
    RenderDocumentBlock? nearest;
    double nearestDist = double.infinity;

    RenderDocumentBlock? child = firstChild;
    while (child != null) {
      final childData = child.parentData as DocumentBlockParentData;
      final childRect = childData.offset & child.size;
      final dist = _distanceToRect(localOffset, childRect);
      if (dist < nearestDist) {
        nearestDist = dist;
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

  /// Returns the minimum squared Euclidean distance from [point] to [rect].
  ///
  /// The square root is intentionally omitted because this method is only used
  /// for relative comparisons.
  static double _distanceToRect(Offset point, Rect rect) {
    final dx = (point.dx - point.dx.clamp(rect.left, rect.right)).abs();
    final dy = (point.dy - point.dy.clamp(rect.top, rect.bottom)).abs();
    return (dx * dx + dy * dy); // Skip sqrt — only comparing relative distances.
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
  /// When the selection spans multiple nodes the method falls back to computing
  /// rects from the caret endpoint geometry:
  ///
  /// - **Top line**: from the base endpoint's left edge to the full layout width.
  /// - **Intermediate gap** (when there is vertical space between the top line's
  ///   bottom and the bottom line's top): a full-width rect.
  /// - **Bottom line**: from the left edge to the extent endpoint's right edge.
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
    // Cross-node path — use caret endpoint rects with top/middle/bottom logic.
    // -----------------------------------------------------------------------
    final baseRect = getRectForDocumentPosition(base);
    final extentRect = getRectForDocumentPosition(extent);

    if (baseRect == null || extentRect == null) return const [];

    // Determine which rect is upstream (top) and which is downstream (bottom).
    final topRect = baseRect.top <= extentRect.top ? baseRect : extentRect;
    final bottomRect = baseRect.top <= extentRect.top ? extentRect : baseRect;

    final layoutWidth = size.width;
    final rects = <Rect>[];

    // Top line: from the upstream endpoint to the right edge.
    rects.add(Rect.fromLTRB(topRect.left, topRect.top, layoutWidth, topRect.bottom));

    // Intermediate lines (fill the gap between top and bottom, if any).
    if (bottomRect.top > topRect.bottom + 1.0) {
      rects.add(Rect.fromLTRB(0, topRect.bottom, layoutWidth, bottomRect.top));
    }

    // Bottom line: from the left edge to the downstream endpoint's right edge.
    rects.add(Rect.fromLTRB(0, bottomRect.top, bottomRect.right, bottomRect.bottom));

    return rects;
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
