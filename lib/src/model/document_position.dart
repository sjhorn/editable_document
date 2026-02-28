/// Document-level position model for the editable_document package.
///
/// Provides [DocumentPosition], which pairs a node id with a within-node
/// [NodePosition] to address a specific location in a [Document].
library;

import 'node_position.dart';

// ---------------------------------------------------------------------------
// DocumentPosition
// ---------------------------------------------------------------------------

/// A position within a [Document], combining a [nodeId] with a
/// [nodePosition] within that node.
///
/// This is the document-level equivalent of Flutter's [TextPosition] —
/// it addresses a specific location in a structured document.
///
/// [nodeId] identifies the [DocumentNode] and [nodePosition] further
/// refines the location within that node (e.g., a character offset for
/// text nodes, or upstream/downstream for binary nodes).
///
/// Example:
/// ```dart
/// const pos = DocumentPosition(
///   nodeId: 'node-1',
///   nodePosition: TextNodePosition(offset: 5),
/// );
/// ```
class DocumentPosition {
  /// Creates a [DocumentPosition] with the given [nodeId] and [nodePosition].
  const DocumentPosition({
    required this.nodeId,
    required this.nodePosition,
  });

  /// The id of the [DocumentNode] this position refers to.
  final String nodeId;

  /// The position within the node identified by [nodeId].
  final NodePosition nodePosition;

  /// Returns a copy of this position with the given fields replaced.
  ///
  /// Fields not provided retain their current values.
  DocumentPosition copyWith({String? nodeId, NodePosition? nodePosition}) {
    return DocumentPosition(
      nodeId: nodeId ?? this.nodeId,
      nodePosition: nodePosition ?? this.nodePosition,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentPosition &&
        other.nodeId == nodeId &&
        other.nodePosition == nodePosition;
  }

  @override
  int get hashCode => Object.hash(nodeId, nodePosition);

  @override
  String toString() => 'DocumentPosition(nodeId: $nodeId, nodePosition: $nodePosition)';
}
