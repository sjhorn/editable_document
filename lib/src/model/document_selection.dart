/// Document-level selection model for the editable_document package.
///
/// Provides [DocumentSelection], which pairs a [base] and [extent]
/// [DocumentPosition] to describe a potentially multi-node selection.
library;

import 'dart:ui' show TextAffinity;

import 'document.dart';
import 'document_position.dart';
import 'node_position.dart';

// ---------------------------------------------------------------------------
// DocumentSelection
// ---------------------------------------------------------------------------

/// A selection within a [Document], defined by a [base] and [extent]
/// [DocumentPosition].
///
/// The selection may span multiple nodes. [base] is where the selection
/// started (the anchor) and [extent] is where it currently ends (the
/// moving end). When [base] == [extent], the selection is collapsed (a
/// caret).
///
/// Directionality is captured by [affinity]: [TextAffinity.downstream]
/// when the extent follows the base in document order, and
/// [TextAffinity.upstream] when the extent precedes it.
///
/// Use [normalize] to obtain a copy where [base] always comes before
/// [extent] in document order, regardless of the original selection
/// direction.
///
/// Example:
/// ```dart
/// final collapsed = DocumentSelection.collapsed(
///   position: DocumentPosition(
///     nodeId: 'node-1',
///     nodePosition: TextNodePosition(offset: 3),
///   ),
/// );
/// assert(collapsed.isCollapsed);
/// ```
class DocumentSelection {
  /// Creates a [DocumentSelection] with the given [base] and [extent].
  const DocumentSelection({
    required this.base,
    required this.extent,
  });

  /// Creates a collapsed selection (caret) at [position].
  ///
  /// Both [base] and [extent] are set to [position].
  const DocumentSelection.collapsed({required DocumentPosition position})
      : base = position,
        extent = position;

  /// The anchor position where the selection started.
  final DocumentPosition base;

  /// The moving end of the selection.
  final DocumentPosition extent;

  /// Whether this selection is collapsed (caret — base equals extent).
  bool get isCollapsed => base == extent;

  /// Whether this selection spans a range (base differs from extent).
  bool get isExpanded => !isCollapsed;

  /// The reading-direction affinity of this selection within [document].
  ///
  /// Returns [TextAffinity.downstream] when the extent is at or after the
  /// base in document order, and [TextAffinity.upstream] otherwise.
  ///
  /// For a collapsed selection, always returns [TextAffinity.downstream].
  ///
  /// When both positions are in the same node and both are
  /// [TextNodePosition]s, affinity is determined by comparing character
  /// offsets. When both are [BinaryNodePosition]s, [BinaryNodePositionType.upstream]
  /// is treated as coming before [BinaryNodePositionType.downstream].
  /// For any other same-node combination the method returns
  /// [TextAffinity.downstream].
  TextAffinity affinity(Document document) {
    if (isCollapsed) return TextAffinity.downstream;

    final baseIndex = document.getNodeIndexById(base.nodeId);
    final extentIndex = document.getNodeIndexById(extent.nodeId);

    if (extentIndex > baseIndex) return TextAffinity.downstream;
    if (extentIndex < baseIndex) return TextAffinity.upstream;

    // Same node — compare node positions.
    final basePos = base.nodePosition;
    final extentPos = extent.nodePosition;

    if (basePos is TextNodePosition && extentPos is TextNodePosition) {
      return extentPos.offset >= basePos.offset ? TextAffinity.downstream : TextAffinity.upstream;
    }

    if (basePos is BinaryNodePosition && extentPos is BinaryNodePosition) {
      if (basePos == extentPos) return TextAffinity.downstream;
      return extentPos.type == BinaryNodePositionType.downstream
          ? TextAffinity.downstream
          : TextAffinity.upstream;
    }

    return TextAffinity.downstream;
  }

  /// Returns a normalized copy of this selection where [base] always
  /// comes before [extent] in document order.
  ///
  /// Useful when you need to iterate from start to end regardless of
  /// selection direction. If the selection is already downstream (or
  /// collapsed) it is returned unchanged.
  DocumentSelection normalize(Document document) {
    if (isCollapsed) return this;
    if (affinity(document) == TextAffinity.upstream) {
      return DocumentSelection(base: extent, extent: base);
    }
    return this;
  }

  /// Returns a copy of this selection with the given fields replaced.
  ///
  /// Fields not provided retain their current values.
  DocumentSelection copyWith({DocumentPosition? base, DocumentPosition? extent}) {
    return DocumentSelection(
      base: base ?? this.base,
      extent: extent ?? this.extent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentSelection && other.base == base && other.extent == extent;
  }

  @override
  int get hashCode => Object.hash(base, extent);

  @override
  String toString() => 'DocumentSelection(base: $base, extent: $extent)';
}
