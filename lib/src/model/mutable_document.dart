/// Mutable document model for the editable_document package.
///
/// Provides [MutableDocument], a [Document] subclass that supports insert,
/// delete, replace, move, and update operations, emitting
/// [DocumentChangeEvent]s through a [ValueNotifier] after each mutation.
library;

import 'package:flutter/foundation.dart';

import 'document.dart';
import 'document_change_event.dart';
import 'document_node.dart';

// ---------------------------------------------------------------------------
// MutableDocument
// ---------------------------------------------------------------------------

/// A mutable [Document] that emits [DocumentChangeEvent]s after each
/// structural or content mutation.
///
/// [MutableDocument] extends [Document] and adds mutation methods:
/// [insertNode], [deleteNode], [replaceNode], [moveNode], and [updateNode].
/// After each mutation the [changes] [ValueNotifier] is updated with a list
/// containing the event(s) that describe the change, and all listeners are
/// notified.
///
/// ```dart
/// final doc = MutableDocument([
///   ParagraphNode(id: 'p1', text: AttributedText('First paragraph')),
/// ]);
///
/// doc.changes.addListener(() {
///   for (final event in doc.changes.value) {
///     debugPrint('Change: $event');
///   }
/// });
///
/// doc.insertNode(1, ParagraphNode(id: 'p2', text: AttributedText('Second')));
/// // prints: Change: NodeInserted(nodeId: p2, index: 1)
/// ```
class MutableDocument extends Document {
  /// Creates a [MutableDocument] from an optional list of initial [nodes].
  ///
  /// When [nodes] is omitted or `null` the document starts empty.
  MutableDocument([super.nodes]);

  /// Internal mutable storage. Shadows the immutable [Document._nodes] field
  /// so that mutations affect the live list.
  final List<DocumentNode> _mutableNodes = [];

  /// Lazily-initialised change notifier.
  final ValueNotifier<List<DocumentChangeEvent>> _changes =
      ValueNotifier<List<DocumentChangeEvent>>(const <DocumentChangeEvent>[]);

  // -------------------------------------------------------------------------
  // Initialisation
  // -------------------------------------------------------------------------

  bool _initialised = false;

  void _ensureInitialised() {
    if (_initialised) return;
    _initialised = true;
    // Copy the nodes passed to super() into our mutable list. Because
    // Document._nodes is final and private we read it back via the public
    // `nodes` getter which is still backed by the super field at this point
    // (before the override takes effect). We use List.from so _mutableNodes
    // gets its own copy of the elements.
    _mutableNodes.addAll(super.nodes);
  }

  // -------------------------------------------------------------------------
  // Document overrides
  // -------------------------------------------------------------------------

  /// An unmodifiable view of the mutable node list.
  ///
  /// Returns a fresh [List.unmodifiable] wrapper on every access so callers
  /// always see the current state but cannot modify the backing list.
  @override
  List<DocumentNode> get nodes {
    _ensureInitialised();
    return List<DocumentNode>.unmodifiable(_mutableNodes);
  }

  // All other [Document] getters and helpers (nodeCount, isEmpty, nodeById,
  // etc.) delegate to `nodes`, so they automatically reflect the mutable list.
  //
  // We override nodeCount, nodeAt, nodeById, getNodeIndexById, nodeAfter,
  // and nodeBefore to avoid the allocation cost of wrapping on every call.

  @override
  int get nodeCount {
    _ensureInitialised();
    return _mutableNodes.length;
  }

  @override
  bool get isEmpty {
    _ensureInitialised();
    return _mutableNodes.isEmpty;
  }

  @override
  bool get isNotEmpty {
    _ensureInitialised();
    return _mutableNodes.isNotEmpty;
  }

  @override
  DocumentNode? nodeById(String id) {
    _ensureInitialised();
    for (final node in _mutableNodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  @override
  DocumentNode nodeAt(int index) {
    _ensureInitialised();
    return _mutableNodes[index];
  }

  @override
  int getNodeIndexById(String id) {
    _ensureInitialised();
    for (var i = 0; i < _mutableNodes.length; i++) {
      if (_mutableNodes[i].id == id) return i;
    }
    return -1;
  }

  @override
  DocumentNode? nodeAfter(String id) {
    final index = getNodeIndexById(id);
    if (index < 0 || index >= _mutableNodes.length - 1) return null;
    return _mutableNodes[index + 1];
  }

  @override
  DocumentNode? nodeBefore(String id) {
    final index = getNodeIndexById(id);
    if (index <= 0) return null;
    return _mutableNodes[index - 1];
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// A [ValueNotifier] that holds the list of [DocumentChangeEvent]s produced
  /// by the most recent mutation.
  ///
  /// Listeners are notified synchronously after each call to [insertNode],
  /// [deleteNode], [replaceNode], [moveNode], or [updateNode].
  ValueNotifier<List<DocumentChangeEvent>> get changes => _changes;

  /// Inserts [node] at zero-based [index].
  ///
  /// Shifts all nodes at [index] and above one position to the right.
  /// Emits a [NodeInserted] event.
  ///
  /// Throws [RangeError] if [index] is out of the range `[0, nodeCount]`.
  void insertNode(int index, DocumentNode node) {
    _ensureInitialised();
    _mutableNodes.insert(index, node);
    _notify([NodeInserted(nodeId: node.id, index: index)]);
  }

  /// Removes the node identified by [id].
  ///
  /// Emits a [NodeDeleted] event carrying the node's former index.
  ///
  /// Throws [StateError] if no node with [id] exists.
  void deleteNode(String id) {
    _ensureInitialised();
    final index = getNodeIndexById(id);
    if (index < 0) {
      throw StateError('No node with id "$id" found in document.');
    }
    _mutableNodes.removeAt(index);
    _notify([NodeDeleted(nodeId: id, index: index)]);
  }

  /// Replaces the node identified by [oldId] with [newNode] at the same index.
  ///
  /// Emits a [NodeReplaced] event.
  ///
  /// Throws [StateError] if no node with [oldId] exists.
  void replaceNode(String oldId, DocumentNode newNode) {
    _ensureInitialised();
    final index = getNodeIndexById(oldId);
    if (index < 0) {
      throw StateError('No node with id "$oldId" found in document.');
    }
    _mutableNodes[index] = newNode;
    _notify([NodeReplaced(oldNodeId: oldId, newNodeId: newNode.id)]);
  }

  /// Moves the node identified by [id] to [newIndex].
  ///
  /// The node is removed from its current position and inserted at [newIndex]
  /// (relative to the list after removal). Emits a [NodeMoved] event.
  ///
  /// Throws [StateError] if no node with [id] exists.
  /// Throws [RangeError] if [newIndex] is out of bounds after removal.
  void moveNode(String id, int newIndex) {
    _ensureInitialised();
    final oldIndex = getNodeIndexById(id);
    if (oldIndex < 0) {
      throw StateError('No node with id "$id" found in document.');
    }
    final node = _mutableNodes.removeAt(oldIndex);
    _mutableNodes.insert(newIndex, node);
    _notify([NodeMoved(nodeId: id, oldIndex: oldIndex, newIndex: newIndex)]);
  }

  /// Applies [updater] to the node identified by [id] and stores the result.
  ///
  /// The [updater] receives the current [DocumentNode] and must return its
  /// replacement. The replacement is stored at the same index.
  ///
  /// Emits a [NodeReplaced] event with the old and new node identifiers.
  ///
  /// Throws [StateError] if no node with [id] exists.
  void updateNode(String id, DocumentNode Function(DocumentNode) updater) {
    _ensureInitialised();
    final index = getNodeIndexById(id);
    if (index < 0) {
      throw StateError('No node with id "$id" found in document.');
    }
    final oldNode = _mutableNodes[index];
    final newNode = updater(oldNode);
    _mutableNodes[index] = newNode;
    _notify([NodeReplaced(oldNodeId: oldNode.id, newNodeId: newNode.id)]);
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  void _notify(List<DocumentChangeEvent> events) {
    _changes.value = events;
  }
}
