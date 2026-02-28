/// Sealed class hierarchy describing structural and content changes to a
/// [Document].
///
/// Every mutation performed by [MutableDocument] produces one or more
/// [DocumentChangeEvent] values that are emitted through
/// `MutableDocument.changes`.
library;

// ---------------------------------------------------------------------------
// DocumentChangeEvent
// ---------------------------------------------------------------------------

/// Abstract base for all events emitted when a [Document] mutates.
///
/// Use pattern-matching or `is`-checks against the concrete subtypes:
/// [NodeInserted], [NodeDeleted], [NodeReplaced], [NodeMoved], and
/// [TextChanged].
///
/// ```dart
/// doc.changes.addListener(() {
///   for (final event in doc.changes.value) {
///     switch (event) {
///       case NodeInserted(:final nodeId, :final index):
///         print('Inserted $nodeId at $index');
///       case NodeDeleted(:final nodeId, :final index):
///         print('Deleted $nodeId from $index');
///       case NodeReplaced(:final oldNodeId, :final newNodeId):
///         print('Replaced $oldNodeId with $newNodeId');
///       case NodeMoved(:final nodeId, :final oldIndex, :final newIndex):
///         print('Moved $nodeId from $oldIndex to $newIndex');
///       case TextChanged(:final nodeId):
///         print('Text of $nodeId changed');
///     }
///   }
/// });
/// ```
sealed class DocumentChangeEvent {
  /// Creates a [DocumentChangeEvent].
  const DocumentChangeEvent();
}

// ---------------------------------------------------------------------------
// NodeInserted
// ---------------------------------------------------------------------------

/// A node with [nodeId] was inserted at [index].
///
/// Indices are zero-based and refer to the position in
/// `MutableDocument.nodes` after the insertion.
class NodeInserted extends DocumentChangeEvent {
  /// Creates a [NodeInserted] event.
  const NodeInserted({required this.nodeId, required this.index});

  /// The identifier of the node that was inserted.
  final String nodeId;

  /// The zero-based index at which the node was inserted.
  final int index;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NodeInserted && other.nodeId == nodeId && other.index == index;
  }

  @override
  int get hashCode => Object.hash(nodeId, index);

  @override
  String toString() => 'NodeInserted(nodeId: $nodeId, index: $index)';
}

// ---------------------------------------------------------------------------
// NodeDeleted
// ---------------------------------------------------------------------------

/// A node with [nodeId] was deleted from [index].
///
/// [index] is the zero-based position the node occupied before deletion.
class NodeDeleted extends DocumentChangeEvent {
  /// Creates a [NodeDeleted] event.
  const NodeDeleted({required this.nodeId, required this.index});

  /// The identifier of the node that was deleted.
  final String nodeId;

  /// The zero-based index the node held before deletion.
  final int index;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NodeDeleted && other.nodeId == nodeId && other.index == index;
  }

  @override
  int get hashCode => Object.hash(nodeId, index);

  @override
  String toString() => 'NodeDeleted(nodeId: $nodeId, index: $index)';
}

// ---------------------------------------------------------------------------
// NodeReplaced
// ---------------------------------------------------------------------------

/// A node with [oldNodeId] was replaced by a node with [newNodeId] at the
/// same index.
class NodeReplaced extends DocumentChangeEvent {
  /// Creates a [NodeReplaced] event.
  const NodeReplaced({required this.oldNodeId, required this.newNodeId});

  /// The identifier of the node that was removed.
  final String oldNodeId;

  /// The identifier of the node that replaced it.
  final String newNodeId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NodeReplaced && other.oldNodeId == oldNodeId && other.newNodeId == newNodeId;
  }

  @override
  int get hashCode => Object.hash(oldNodeId, newNodeId);

  @override
  String toString() => 'NodeReplaced(oldNodeId: $oldNodeId, newNodeId: $newNodeId)';
}

// ---------------------------------------------------------------------------
// NodeMoved
// ---------------------------------------------------------------------------

/// A node with [nodeId] was moved from [oldIndex] to [newIndex].
///
/// Both indices are zero-based positions in `MutableDocument.nodes`.
class NodeMoved extends DocumentChangeEvent {
  /// Creates a [NodeMoved] event.
  const NodeMoved({
    required this.nodeId,
    required this.oldIndex,
    required this.newIndex,
  });

  /// The identifier of the node that was moved.
  final String nodeId;

  /// The zero-based index the node occupied before the move.
  final int oldIndex;

  /// The zero-based index the node occupies after the move.
  final int newIndex;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NodeMoved &&
        other.nodeId == nodeId &&
        other.oldIndex == oldIndex &&
        other.newIndex == newIndex;
  }

  @override
  int get hashCode => Object.hash(nodeId, oldIndex, newIndex);

  @override
  String toString() => 'NodeMoved(nodeId: $nodeId, oldIndex: $oldIndex, newIndex: $newIndex)';
}

// ---------------------------------------------------------------------------
// TextChanged
// ---------------------------------------------------------------------------

/// The text content of the node identified by [nodeId] changed.
///
/// This event is emitted when the [AttributedText] content of a text-bearing
/// node (e.g. [ParagraphNode]) is updated via `MutableDocument.updateNode`.
class TextChanged extends DocumentChangeEvent {
  /// Creates a [TextChanged] event.
  const TextChanged({required this.nodeId});

  /// The identifier of the node whose text was changed.
  final String nodeId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextChanged && other.nodeId == nodeId;
  }

  @override
  int get hashCode => nodeId.hashCode;

  @override
  String toString() => 'TextChanged(nodeId: $nodeId)';
}
