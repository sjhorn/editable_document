/// Abstract document node model for the editable_document package.
///
/// This file defines [DocumentNode], the abstract base class for all block-level
/// elements in a document, and [generateNodeId], a helper for creating unique
/// node identifiers without external dependencies.
library;

import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// generateNodeId
// ---------------------------------------------------------------------------

int _nodeIdCounter = 0;

/// Generates a unique node identifier string.
///
/// Returns a string of the form `'node-<counter>'` where `<counter>` is a
/// monotonically increasing integer. The counter is process-scoped and resets
/// when the Dart isolate restarts.
///
/// This does not rely on any external package — it uses a simple static
/// counter so the model layer stays dependency-free.
String generateNodeId() => 'node-${_nodeIdCounter++}';

// ---------------------------------------------------------------------------
// DocumentNode
// ---------------------------------------------------------------------------

/// Abstract base class for all block-level nodes in a document.
///
/// Every node has a unique [id] (typically produced by [generateNodeId] or
/// a UUID v4 string supplied by the caller) and a [metadata] map for
/// extensible per-node properties such as block type or heading level.
///
/// The [metadata] map is stored as an unmodifiable view so callers cannot
/// mutate node state directly; use [copyWith] to derive a modified copy.
///
/// Concrete subtypes include [TextNode], [ParagraphNode], [ListItemNode],
/// [ImageNode], [CodeBlockNode], and [HorizontalRuleNode].
abstract class DocumentNode with Diagnosticable {
  /// Creates a [DocumentNode] with the given [id] and optional [metadata].
  ///
  /// [metadata] is wrapped in [Map.unmodifiable] so external code cannot
  /// modify node state after construction. Pass `null` or omit [metadata]
  /// to use an empty immutable map.
  DocumentNode({required this.id, Map<String, dynamic>? metadata})
      : metadata = Map<String, dynamic>.unmodifiable(metadata ?? const {});

  /// Unique identifier for this node.
  ///
  /// Typically a value produced by [generateNodeId] or a UUID v4 string.
  /// Two nodes with the same [id] in the same [Document] are considered the
  /// same logical block.
  final String id;

  /// Extensible, unmodifiable metadata map for this node.
  ///
  /// Use [copyWith] with a new metadata map to update properties such as
  /// block type, heading level, or custom renderer hints.
  final Map<String, dynamic> metadata;

  /// Returns a copy of this node with the specified fields replaced.
  ///
  /// Each concrete subtype overrides this to expose its own typed parameters.
  DocumentNode copyWith({String? id, Map<String, dynamic>? metadata});

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('id', id));
    properties.add(DiagnosticsProperty<Map<String, dynamic>>('metadata', metadata));
  }
}
