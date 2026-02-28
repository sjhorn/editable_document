/// Text-bearing document node for the editable_document package.
///
/// Provides [TextNode], the base class for all nodes that hold rich text
/// content via [AttributedText].
library;

import 'package:flutter/foundation.dart';

import 'attributed_text.dart';
import 'document_node.dart';

/// A [DocumentNode] that holds rich text content via [AttributedText].
///
/// [TextNode] is the base class for all text-bearing node subtypes such as
/// [ParagraphNode], [ListItemNode], and [CodeBlockNode]. It adds a single
/// [text] field on top of the base [DocumentNode] contract.
///
/// ```dart
/// final node = TextNode(id: generateNodeId(), text: AttributedText('Hello'));
/// final bold = node.text.applyAttribution(NamedAttribution.bold, 0, 4);
/// final updated = node.copyWith(text: bold);
/// ```
class TextNode extends DocumentNode {
  /// Creates a [TextNode] with the given [id] and optional [text].
  ///
  /// When [text] is omitted an empty [AttributedText] is used.
  TextNode({
    required super.id,
    AttributedText? text,
    super.metadata,
  }) : text = text ?? AttributedText();

  /// The rich text content of this node.
  final AttributedText text;

  @override
  TextNode copyWith({String? id, AttributedText? text, Map<String, dynamic>? metadata}) {
    return TextNode(
      id: id ?? this.id,
      text: text ?? this.text,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is TextNode &&
        other.id == id &&
        other.text == text &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(id, text, Object.hashAll(metadata.entries.map((e) => e)));

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AttributedText>('text', text));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'TextNode(id: $id, text: $text, metadata: $metadata)';
}
