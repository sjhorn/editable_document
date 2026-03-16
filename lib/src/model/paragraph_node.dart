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
  /// Creates a [ParagraphNode] with an optional [blockType], [textAlign],
  /// [lineHeight], [spaceBefore], [spaceAfter], [indentLeft], [indentRight],
  /// and [firstLineIndent].
  ///
  /// [blockType] defaults to [ParagraphBlockType.paragraph].
  /// [textAlign] defaults to [TextAlign.start].
  /// [lineHeight] defaults to `null`, which means the document default is
  /// inherited.
  /// [spaceBefore] and [spaceAfter] default to `null`, which means the
  /// document-level default spacing is used.
  /// [indentLeft], [indentRight], and [firstLineIndent] default to `null`,
  /// which means no extra indent is applied.
  ParagraphNode({
    required super.id,
    super.text,
    this.blockType = ParagraphBlockType.paragraph,
    this.textAlign = TextAlign.start,
    this.lineHeight,
    this.spaceBefore,
    this.spaceAfter,
    this.indentLeft,
    this.indentRight,
    this.firstLineIndent,
    super.metadata,
  });

  /// The semantic block type of this paragraph.
  final ParagraphBlockType blockType;

  /// The horizontal text alignment within the paragraph.
  ///
  /// Defaults to [TextAlign.start], which aligns text to the leading edge for
  /// the current text direction.
  final TextAlign textAlign;

  /// Line-height multiplier for this paragraph, or `null` to inherit the
  /// document default.
  ///
  /// A value of `1.0` uses the font's natural line height. `1.5` adds
  /// 50 % extra leading. `null` defers to whatever default the renderer
  /// applies for the document as a whole.
  final double? lineHeight;

  /// Extra space before this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceBefore;

  /// Extra space after this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceAfter;

  /// Left indent in logical pixels, or `null` for no extra indent.
  final double? indentLeft;

  /// Right indent in logical pixels, or `null` for no extra indent.
  final double? indentRight;

  /// First-line indent in logical pixels, or `null` for no special first-line treatment.
  ///
  /// Positive values indent the first line further. Negative values create a
  /// hanging indent (all lines except the first are indented).
  final double? firstLineIndent;

  @override
  ParagraphNode copyWith({
    String? id,
    AttributedText? text,
    ParagraphBlockType? blockType,
    TextAlign? textAlign,
    double? lineHeight,
    double? spaceBefore,
    double? spaceAfter,
    double? indentLeft,
    double? indentRight,
    double? firstLineIndent,
    Map<String, dynamic>? metadata,
  }) {
    return ParagraphNode(
      id: id ?? this.id,
      text: text ?? this.text,
      blockType: blockType ?? this.blockType,
      textAlign: textAlign ?? this.textAlign,
      lineHeight: lineHeight ?? this.lineHeight,
      spaceBefore: spaceBefore ?? this.spaceBefore,
      spaceAfter: spaceAfter ?? this.spaceAfter,
      indentLeft: indentLeft ?? this.indentLeft,
      indentRight: indentRight ?? this.indentRight,
      firstLineIndent: firstLineIndent ?? this.firstLineIndent,
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
        other.lineHeight == lineHeight &&
        other.spaceBefore == spaceBefore &&
        other.spaceAfter == spaceAfter &&
        other.indentLeft == indentLeft &&
        other.indentRight == indentRight &&
        other.firstLineIndent == firstLineIndent &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        text,
        blockType,
        textAlign,
        lineHeight,
        spaceBefore,
        spaceAfter,
        indentLeft,
        indentRight,
        firstLineIndent,
        Object.hashAll(metadata.entries.map((e) => e)),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<ParagraphBlockType>('blockType', blockType));
    properties.add(
      EnumProperty<TextAlign>('textAlign', textAlign, defaultValue: TextAlign.start),
    );
    properties.add(DoubleProperty('lineHeight', lineHeight, defaultValue: null));
    properties.add(DoubleProperty('spaceBefore', spaceBefore, defaultValue: null));
    properties.add(DoubleProperty('spaceAfter', spaceAfter, defaultValue: null));
    properties.add(DoubleProperty('indentLeft', indentLeft, defaultValue: null));
    properties.add(DoubleProperty('indentRight', indentRight, defaultValue: null));
    properties.add(DoubleProperty('firstLineIndent', firstLineIndent, defaultValue: null));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'ParagraphNode(id: $id, blockType: $blockType, textAlign: $textAlign, '
      'lineHeight: $lineHeight, spaceBefore: $spaceBefore, spaceAfter: $spaceAfter, '
      'indentLeft: $indentLeft, indentRight: $indentRight, firstLineIndent: $firstLineIndent, '
      'text: $text, metadata: $metadata)';
}
