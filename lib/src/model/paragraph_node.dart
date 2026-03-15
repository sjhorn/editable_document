/// Paragraph document node for the editable_document package.
///
/// Provides [ParagraphBlockType] and [ParagraphNode], the primary text block
/// used for body text, headings, blockquotes, and inline code blocks.
library;

import 'dart:ui' show TextAlign;

import 'package:flutter/foundation.dart';

import 'attributed_text.dart';
import 'text_node.dart';

// ---------------------------------------------------------------------------
// ParagraphBlockType
// ---------------------------------------------------------------------------

/// Semantic block type for a [ParagraphNode].
///
/// The block type controls how a paragraph is rendered: as a body paragraph,
/// one of six heading levels, a blockquote, or a fenced code block.
enum ParagraphBlockType {
  /// A standard body paragraph.
  paragraph,

  /// A level-1 heading (`<h1>`).
  header1,

  /// A level-2 heading (`<h2>`).
  header2,

  /// A level-3 heading (`<h3>`).
  header3,

  /// A level-4 heading (`<h4>`).
  header4,

  /// A level-5 heading (`<h5>`).
  header5,

  /// A level-6 heading (`<h6>`).
  header6,

  /// A blockquote (`<blockquote>`).
  blockquote,

  /// A fenced code block (inline code at block level).
  codeBlock,
}

// ---------------------------------------------------------------------------
// ParagraphNode
// ---------------------------------------------------------------------------

/// A [TextNode] representing a paragraph with an optional [blockType].
///
/// [ParagraphNode] is the most common node type in a document. Its [blockType]
/// determines semantic rendering (heading, blockquote, code block, etc.).
///
/// ```dart
/// final heading = ParagraphNode(
///   id: generateNodeId(),
///   text: AttributedText('Introduction'),
///   blockType: ParagraphBlockType.header1,
/// );
/// ```
class ParagraphNode extends TextNode {
  /// Creates a [ParagraphNode] with an optional [blockType] and [textAlign].
  ///
  /// [blockType] defaults to [ParagraphBlockType.paragraph].
  /// [textAlign] defaults to [TextAlign.start].
  ParagraphNode({
    required super.id,
    super.text,
    this.blockType = ParagraphBlockType.paragraph,
    this.textAlign = TextAlign.start,
    super.metadata,
  });

  /// The semantic block type of this paragraph.
  final ParagraphBlockType blockType;

  /// The horizontal text alignment within the paragraph.
  ///
  /// Defaults to [TextAlign.start], which aligns text to the leading edge for
  /// the current text direction.
  final TextAlign textAlign;

  @override
  ParagraphNode copyWith({
    String? id,
    AttributedText? text,
    ParagraphBlockType? blockType,
    TextAlign? textAlign,
    Map<String, dynamic>? metadata,
  }) {
    return ParagraphNode(
      id: id ?? this.id,
      text: text ?? this.text,
      blockType: blockType ?? this.blockType,
      textAlign: textAlign ?? this.textAlign,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is ParagraphNode &&
        other.id == id &&
        other.text == text &&
        other.blockType == blockType &&
        other.textAlign == textAlign &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        text,
        blockType,
        textAlign,
        Object.hashAll(metadata.entries.map((e) => e)),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<ParagraphBlockType>('blockType', blockType));
    properties.add(
      EnumProperty<TextAlign>('textAlign', textAlign, defaultValue: TextAlign.start),
    );
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'ParagraphNode(id: $id, blockType: $blockType, textAlign: $textAlign, '
      'text: $text, metadata: $metadata)';
}
