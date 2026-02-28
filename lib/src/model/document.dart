/// Immutable document model for the editable_document package.
///
/// Provides [Document], an ordered, immutable list of [DocumentNode]s with
/// efficient look-up helpers. For a mutable variant that emits change events,
/// see [MutableDocument].
library;

import 'package:flutter/foundation.dart';

import 'document_node.dart';

// ---------------------------------------------------------------------------
// Document
// ---------------------------------------------------------------------------

/// An immutable, ordered list of [DocumentNode]s.
///
/// [Document] is the read-only view of a block-structured document. It
/// provides look-up helpers ([nodeById], [nodeAt], [nodeAfter], [nodeBefore],
/// [getNodeIndexById]) but no mutation methods.
///
/// For a mutable variant that emits [DocumentChangeEvent]s, use
/// [MutableDocument].
///
/// ```dart
/// final doc = Document([
///   ParagraphNode(id: 'intro', text: AttributedText('Hello world')),
///   HorizontalRuleNode(id: 'divider'),
/// ]);
///
/// final intro = doc.nodeById('intro'); // → ParagraphNode
/// final after = doc.nodeAfter('intro'); // → HorizontalRuleNode
/// ```
class Document {
  /// Creates a [Document] from an optional list of [nodes].
  ///
  /// When [nodes] is omitted or `null` the document starts empty.
  /// The list is wrapped in [List.unmodifiable] so external code cannot
  /// bypass the read-only contract.
  Document([List<DocumentNode>? nodes])
      : _nodes = List<DocumentNode>.unmodifiable(nodes ?? const <DocumentNode>[]);

  /// Internal storage. Subclasses may shadow this field with a mutable list
  /// while still returning an unmodifiable view from [nodes].
  final List<DocumentNode> _nodes;

  /// An unmodifiable ordered view of all nodes in this document.
  List<DocumentNode> get nodes => _nodes;

  /// The number of nodes in this document.
  int get nodeCount => _nodes.length;

  /// Whether this document contains no nodes.
  bool get isEmpty => _nodes.isEmpty;

  /// Whether this document contains at least one node.
  bool get isNotEmpty => _nodes.isNotEmpty;

  // -------------------------------------------------------------------------
  // Look-up helpers
  // -------------------------------------------------------------------------

  /// Returns the node with the given [id], or `null` if no node has that id.
  ///
  /// Performs a linear scan; for large documents with frequent look-ups,
  /// consider maintaining an index at a higher layer.
  DocumentNode? nodeById(String id) {
    for (final node in _nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// Returns the node at zero-based [index].
  ///
  /// Throws [RangeError] if [index] is out of bounds.
  DocumentNode nodeAt(int index) => _nodes[index];

  /// Returns the node immediately after the node with [id], or `null` if [id]
  /// is the last node or is not found.
  DocumentNode? nodeAfter(String id) {
    final index = getNodeIndexById(id);
    if (index < 0 || index >= _nodes.length - 1) return null;
    return _nodes[index + 1];
  }

  /// Returns the node immediately before the node with [id], or `null` if [id]
  /// is the first node or is not found.
  DocumentNode? nodeBefore(String id) {
    final index = getNodeIndexById(id);
    if (index <= 0) return null;
    return _nodes[index - 1];
  }

  /// Returns the zero-based index of the node with [id], or `-1` if not found.
  int getNodeIndexById(String id) {
    for (var i = 0; i < _nodes.length; i++) {
      if (_nodes[i].id == id) return i;
    }
    return -1;
  }

  // -------------------------------------------------------------------------
  // Equality / hashCode / toString
  // -------------------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Document) return false;
    return listEquals(_nodes, other._nodes);
  }

  @override
  int get hashCode => Object.hashAll(_nodes);

  @override
  String toString() => 'Document(nodeCount: $nodeCount, nodes: $_nodes)';
}
