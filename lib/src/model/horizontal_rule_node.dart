/// Horizontal rule document node for the editable_document package.
///
/// Provides [HorizontalRuleNode], a content-less thematic break node.
/// Cursor placement uses [BinaryNodePosition] (upstream / downstream).
library;

import 'package:flutter/foundation.dart';

import 'document_node.dart';

/// A [DocumentNode] representing a horizontal rule (thematic break).
///
/// [HorizontalRuleNode] carries no text content — it is a purely visual
/// divider analogous to the HTML `<hr>` element. Because the node has no
/// editable content, cursor placement is handled by [BinaryNodePosition]
/// (either before or after the rule).
///
/// ```dart
/// final rule = HorizontalRuleNode(id: generateNodeId());
/// ```
class HorizontalRuleNode extends DocumentNode {
  /// Creates a [HorizontalRuleNode] with the given [id] and optional [metadata].
  HorizontalRuleNode({required super.id, super.metadata});

  @override
  HorizontalRuleNode copyWith({String? id, Map<String, dynamic>? metadata}) {
    return HorizontalRuleNode(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is HorizontalRuleNode && other.id == id && mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(id, Object.hashAll(metadata.entries.map((e) => e)));

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'HorizontalRuleNode(id: $id, metadata: $metadata)';
}
