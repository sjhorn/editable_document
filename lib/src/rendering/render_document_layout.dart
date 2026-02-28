/// Container render object that lays out document blocks vertically.
///
/// This file provides [RenderDocumentLayout], a [RenderBox] that manages a
/// vertical stack of [RenderDocumentBlock] children and exposes geometry
/// queries used by the selection and caret systems.
library;

import 'package:flutter/rendering.dart';

import '../model/document_position.dart';
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
  /// [pos.nodeId], delegates to [RenderDocumentBlock.getLocalRectForPosition],
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
