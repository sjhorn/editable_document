/// Horizontal rule document node for the editable_document package.
///
/// Provides [HorizontalRuleNode], a content-less thematic break node.
/// Cursor placement uses [BinaryNodePosition] (upstream / downstream).
library;

import 'package:flutter/foundation.dart';

import 'block_alignment.dart';
import 'document_node.dart';

/// A [DocumentNode] representing a horizontal rule (thematic break).
///
/// [HorizontalRuleNode] carries no text content — it is a purely visual
/// divider analogous to the HTML `<hr>` element. Because the node has no
/// editable content, cursor placement is handled by [BinaryNodePosition]
/// (either before or after the rule).
///
/// The [alignment] field controls how the rule is positioned within the
/// available layout width when the rule has a width smaller than the full
/// layout (controlled by the rendering layer).
///
/// ```dart
/// final rule = HorizontalRuleNode(
///   id: generateNodeId(),
///   alignment: BlockAlignment.center,
/// );
/// ```
class HorizontalRuleNode extends DocumentNode {
  /// Creates a [HorizontalRuleNode] with the given [id], optional [metadata],
  /// and optional [alignment].
  ///
  /// [alignment] defaults to [BlockAlignment.stretch].
  HorizontalRuleNode({
    required super.id,
    this.alignment = BlockAlignment.stretch,
    super.metadata,
  });

  /// How the horizontal rule is aligned within the available layout width.
  ///
  /// Defaults to [BlockAlignment.stretch], which stretches the rule to fill
  /// the entire available width. Use other values when the rendering layer
  /// constrains the rule to a narrower width.
  final BlockAlignment alignment;

  @override
  HorizontalRuleNode copyWith({
    String? id,
    BlockAlignment? alignment,
    Map<String, dynamic>? metadata,
  }) {
    return HorizontalRuleNode(
      id: id ?? this.id,
      alignment: alignment ?? this.alignment,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is HorizontalRuleNode &&
        other.id == id &&
        other.alignment == alignment &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        alignment,
        Object.hashAll(metadata.entries.map((e) => e)),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      EnumProperty<BlockAlignment>('alignment', alignment, defaultValue: BlockAlignment.stretch),
    );
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'HorizontalRuleNode(id: $id, alignment: ${alignment.name}, metadata: $metadata)';
}
