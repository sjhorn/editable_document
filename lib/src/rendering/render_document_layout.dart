/// Container render object that lays out document blocks vertically.
///
/// This file provides [RenderDocumentLayout], a [RenderBox] that manages a
/// vertical stack of [RenderDocumentBlock] children and exposes geometry
/// queries used by the selection and caret systems.
library;

import 'package:flutter/rendering.dart';

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
/// during [RenderDocumentLayout.performLayout].
class DocumentBlockParentData extends ContainerBoxParentData<RenderDocumentBlock> {}

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
/// Children are laid out with `BoxConstraints(maxWidth: constraints.maxWidth)`.
/// Their paint offsets are stored in [DocumentBlockParentData.offset].
/// No spacing is added before the first child or after the last child.
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
  /// Creates a [RenderDocumentLayout] with optional [blockSpacing].
  ///
  /// [blockSpacing] is the vertical gap in logical pixels inserted between
  /// consecutive children.  Defaults to `12.0`.
  RenderDocumentLayout({double blockSpacing = 12.0}) : _blockSpacing = blockSpacing;

  // ---------------------------------------------------------------------------
  // blockSpacing
  // ---------------------------------------------------------------------------

  double _blockSpacing;

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
    var yOffset = 0.0;
    var childIndex = 0;
    RenderDocumentBlock? child = firstChild;

    while (child != null) {
      final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
      child.layout(childConstraints, parentUsesSize: true);

      final parentData = child.parentData as DocumentBlockParentData;

      if (childIndex > 0) {
        yOffset += _blockSpacing;
      }
      parentData.offset = Offset(0, yOffset);
      yOffset += child.size.height;

      childIndex++;
      child = childAfter(child);
    }

    size = Size(constraints.maxWidth, yOffset);
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

  /// Returns the [DocumentPosition] for the child whose vertical bounds contain
  /// [localOffset], or `null` if the offset falls outside all children (e.g.,
  /// in a gap between blocks or past the last child).
  ///
  /// The x-coordinate is passed through to the child's
  /// [RenderDocumentBlock.getPositionAtOffset] so text blocks can determine
  /// the column.
  DocumentPosition? getDocumentPositionAtOffset(Offset localOffset) {
    RenderDocumentBlock? child = firstChild;
    while (child != null) {
      final childData = child.parentData as DocumentBlockParentData;
      final childTop = childData.offset.dy;
      final childBottom = childTop + child.size.height;

      if (localOffset.dy >= childTop && localOffset.dy < childBottom) {
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
  /// - Offsets above all children are clamped to the first child.
  /// - Offsets below all children are clamped to the last child.
  /// - Offsets within a gap between two children are resolved to the nearest
  ///   child (the one whose boundary is closer in the y-direction).
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

    // Clamp: if above the first child, return position within first child.
    final firstData = firstChild!.parentData as DocumentBlockParentData;
    if (localOffset.dy < firstData.offset.dy) {
      final clampedOffset = Offset(
        localOffset.dx.clamp(0.0, firstChild!.size.width),
        0.0,
      );
      final nodePos = firstChild!.getPositionAtOffset(clampedOffset);
      return DocumentPosition(nodeId: firstChild!.nodeId, nodePosition: nodePos);
    }

    // Clamp: if below the last child, return position within last child.
    final lastData = lastChild!.parentData as DocumentBlockParentData;
    final lastBottom = lastData.offset.dy + lastChild!.size.height;
    if (localOffset.dy >= lastBottom) {
      final clampedOffset = Offset(
        localOffset.dx.clamp(0.0, lastChild!.size.width),
        lastChild!.size.height - 1,
      );
      final nodePos = lastChild!.getPositionAtOffset(clampedOffset);
      return DocumentPosition(nodeId: lastChild!.nodeId, nodePosition: nodePos);
    }

    // The offset is in a gap between children. Find the two children whose
    // gap contains the offset and pick the nearer one.
    RenderDocumentBlock? prev;
    RenderDocumentBlock? child = firstChild;
    while (child != null) {
      final childData = child.parentData as DocumentBlockParentData;
      final childTop = childData.offset.dy;

      if (prev != null && localOffset.dy < childTop) {
        // The offset is in the gap between prev and child.
        final prevData = prev.parentData as DocumentBlockParentData;
        final prevBottom = prevData.offset.dy + prev.size.height;
        final distToPrev = localOffset.dy - prevBottom;
        final distToChild = childTop - localOffset.dy;

        if (distToPrev <= distToChild) {
          final clampedOffset = Offset(
            localOffset.dx.clamp(0.0, prev.size.width),
            prev.size.height - 1,
          );
          final nodePos = prev.getPositionAtOffset(clampedOffset);
          return DocumentPosition(nodeId: prev.nodeId, nodePosition: nodePos);
        } else {
          final clampedOffset = Offset(
            localOffset.dx.clamp(0.0, child.size.width),
            0.0,
          );
          final nodePos = child.getPositionAtOffset(clampedOffset);
          return DocumentPosition(nodeId: child.nodeId, nodePosition: nodePos);
        }
      }

      prev = child;
      child = childAfter(child);
    }

    // Fallback — should be unreachable with correct accounting above.
    final clampedOffset = Offset(
      localOffset.dx.clamp(0.0, lastChild!.size.width),
      lastChild!.size.height - 1,
    );
    final nodePos = lastChild!.getPositionAtOffset(clampedOffset);
    return DocumentPosition(nodeId: lastChild!.nodeId, nodePosition: nodePos);
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
    properties.add(DoubleProperty('blockSpacing', _blockSpacing));
    properties.add(DoubleProperty('blockSpacing', blockSpacing));
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
