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
/// available layout width when the rule has an explicit [width] smaller than
/// the full layout (controlled by the rendering layer).
///
/// The optional [width] and [height] fields provide sizing hints to the
/// rendering layer. When `null`, the rendering layer applies its default
/// auto-sizing behaviour (typically full-width, thin line).
///
/// The [textWrap] field controls whether surrounding text may flow around
/// this rule.
///
/// ```dart
/// final rule = HorizontalRuleNode(
///   id: generateNodeId(),
///   width: 400.0,
///   height: 2.0,
///   alignment: BlockAlignment.center,
///   textWrap: false,
/// );
/// ```
class HorizontalRuleNode extends DocumentNode {
  /// Creates a [HorizontalRuleNode] with the given [id], optional [metadata],
  /// optional [alignment], optional [width], optional [height], and optional
  /// [textWrap].
  ///
  /// [alignment] defaults to [BlockAlignment.stretch].
  /// [textWrap] defaults to `false`.
  HorizontalRuleNode({
    required super.id,
    this.width,
    this.height,
    this.alignment = BlockAlignment.stretch,
    this.textWrap = false,
    super.metadata,
  });

  /// Preferred display width in logical pixels, or `null` for auto sizing.
  final double? width;

  /// Preferred display height in logical pixels, or `null` for auto sizing.
  final double? height;

  /// How the horizontal rule is aligned within the available layout width.
  ///
  /// Defaults to [BlockAlignment.stretch], which stretches the rule to fill
  /// the entire available width. Use other values when the rendering layer
  /// constrains the rule to a narrower width.
  final BlockAlignment alignment;

  /// Whether surrounding text may flow around this horizontal rule.
  ///
  /// When `true` the rendering layer is expected to apply text-wrap layout
  /// (similar to CSS `float`).
  ///
  /// Defaults to `false`.
  final bool textWrap;

  @override
  HorizontalRuleNode copyWith({
    String? id,
    double? width,
    double? height,
    BlockAlignment? alignment,
    bool? textWrap,
    Map<String, dynamic>? metadata,
  }) {
    return HorizontalRuleNode(
      id: id ?? this.id,
      width: width ?? this.width,
      height: height ?? this.height,
      alignment: alignment ?? this.alignment,
      textWrap: textWrap ?? this.textWrap,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is HorizontalRuleNode &&
        other.id == id &&
        other.width == width &&
        other.height == height &&
        other.alignment == alignment &&
        other.textWrap == textWrap &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        width,
        height,
        alignment,
        textWrap,
        Object.hashAll(metadata.entries.map((e) => e)),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DoubleProperty('height', height, defaultValue: null));
    properties.add(
      EnumProperty<BlockAlignment>('alignment', alignment, defaultValue: BlockAlignment.stretch),
    );
    properties.add(DiagnosticsProperty<bool>('textWrap', textWrap, defaultValue: false));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'HorizontalRuleNode(id: $id, width: $width, height: $height, '
      'alignment: ${alignment.name}, textWrap: $textWrap, metadata: $metadata)';
}
