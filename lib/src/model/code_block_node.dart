/// Code block document node for the editable_document package.
///
/// Provides [CodeBlockNode], a fenced code block that optionally specifies a
/// programming language for syntax highlighting.
library;

import 'package:flutter/foundation.dart';

import 'attributed_text.dart';
import 'text_node.dart';

/// A [TextNode] representing a fenced code block.
///
/// [CodeBlockNode] holds source code as plain [AttributedText] and stores the
/// optional [language] identifier for syntax highlighting.  Unlike
/// [ParagraphNode] with [ParagraphBlockType.codeBlock], this node type is
/// explicitly specialised for code and carries language metadata directly.
///
/// ```dart
/// final snippet = CodeBlockNode(
///   id: generateNodeId(),
///   text: AttributedText('void main() => print("hello");'),
///   language: 'dart',
/// );
/// ```
class CodeBlockNode extends TextNode {
  /// Creates a [CodeBlockNode] with optional [text] and [language].
  ///
  /// [language] may be `null` when the code block has no declared language.
  CodeBlockNode({
    required super.id,
    super.text,
    this.language,
    super.metadata,
  });

  /// The programming language identifier for syntax highlighting, or `null`.
  ///
  /// Common values include `'dart'`, `'python'`, `'javascript'`, etc.
  final String? language;

  @override
  CodeBlockNode copyWith({
    String? id,
    AttributedText? text,
    String? language,
    Map<String, dynamic>? metadata,
  }) {
    return CodeBlockNode(
      id: id ?? this.id,
      text: text ?? this.text,
      language: language ?? this.language,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is CodeBlockNode &&
        other.id == id &&
        other.text == text &&
        other.language == language &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        text,
        language,
        Object.hashAll(metadata.entries.map((e) => e)),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('language', language, defaultValue: null));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'CodeBlockNode(id: $id, language: $language, text: $text, metadata: $metadata)';
}
