/// Blockquote document node for the editable_document package.
///
/// Provides [BlockquoteNode], a text-bearing block that visually represents
/// quoted content with optional container layout properties.
library;

import 'dart:ui' show TextAlign;

import 'package:flutter/foundation.dart';

import 'attributed_text.dart';
import 'block_alignment.dart';
import 'block_layout.dart';
import 'document_node.dart';
import 'text_node.dart';
import 'text_wrap_mode.dart';

/// A [TextNode] representing a blockquote.
///
/// [BlockquoteNode] holds rich text content like any other [TextNode] but
/// additionally supports container-level layout properties: explicit [width]
/// and [height], horizontal [alignment], and [textWrap] for float-like
/// behaviour where subsequent blocks wrap around this one.
///
/// While [ParagraphNode] with `ParagraphBlockType.blockquote` can also
/// represent quoted text, [BlockquoteNode] is the preferred type when
/// container layout properties are needed.
///
/// ```dart
/// final quote = BlockquoteNode(
///   id: generateNodeId(),
///   text: AttributedText('To be or not to be'),
///   alignment: BlockAlignment.center,
/// );
/// ```
class BlockquoteNode extends TextNode implements HasBlockLayout {
  /// Creates a [BlockquoteNode] with optional layout properties.
  ///
  /// [alignment] defaults to [BlockAlignment.stretch].
  /// [textWrap] defaults to [TextWrapMode.none].
  /// [textAlign] defaults to [TextAlign.start].
  /// [lineHeight] defaults to `null` (inherit document default).
  /// [width] and [height] default to `null` (use available / intrinsic size).
  /// [spaceBefore] and [spaceAfter] default to `null` (use document-level
  /// default spacing).
  /// [indentLeft], [indentRight], and [firstLineIndent] default to `null`
  /// (no extra indent applied).
  BlockquoteNode({
    required super.id,
    super.text,
    this.width,
    this.height,
    this.alignment = BlockAlignment.stretch,
    this.textWrap = TextWrapMode.none,
    this.textAlign = TextAlign.start,
    this.lineHeight,
    this.spaceBefore,
    this.spaceAfter,
    this.indentLeft,
    this.indentRight,
    this.firstLineIndent,
    super.metadata,
  });

  /// Preferred display width in logical pixels, or `null` to use available width.
  final double? width;

  /// Preferred display height in logical pixels, or `null` for intrinsic height.
  final double? height;

  /// Horizontal alignment within the available layout width.
  ///
  /// Defaults to [BlockAlignment.stretch].
  final BlockAlignment alignment;

  /// How surrounding text interacts with this blockquote.
  ///
  /// When [TextWrapMode.wrap] and [alignment] is [BlockAlignment.start] or
  /// [BlockAlignment.end], adjacent blocks receive reduced-width constraints
  /// so they flow beside this blockquote. Defaults to [TextWrapMode.none].
  final TextWrapMode textWrap;

  /// The horizontal text alignment within this blockquote.
  ///
  /// Defaults to [TextAlign.start], which aligns text to the leading edge for
  /// the current text direction.
  final TextAlign textAlign;

  /// Line-height multiplier for this blockquote, or `null` to inherit the
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
  bool get isDraggable => true;

  @override
  bool get isResizable => alignment != BlockAlignment.stretch;

  @override
  DocumentNode copyWithSize({double? width, double? height, BlockAlignment? alignment}) => copyWith(
        width: width ?? this.width,
        height: height ?? this.height,
        alignment: alignment ?? this.alignment,
      );

  @override
  BlockquoteNode copyWith({
    String? id,
    AttributedText? text,
    double? width,
    double? height,
    BlockAlignment? alignment,
    TextWrapMode? textWrap,
    TextAlign? textAlign,
    double? lineHeight,
    double? spaceBefore,
    double? spaceAfter,
    double? indentLeft,
    double? indentRight,
    double? firstLineIndent,
    Map<String, dynamic>? metadata,
  }) {
    return BlockquoteNode(
      id: id ?? this.id,
      text: text ?? this.text,
      width: width ?? this.width,
      height: height ?? this.height,
      alignment: alignment ?? this.alignment,
      textWrap: textWrap ?? this.textWrap,
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
    return other is BlockquoteNode &&
        other.id == id &&
        other.text == text &&
        other.width == width &&
        other.height == height &&
        other.alignment == alignment &&
        other.textWrap == textWrap &&
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
        width,
        height,
        alignment,
        textWrap,
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
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DoubleProperty('height', height, defaultValue: null));
    properties.add(
      EnumProperty<BlockAlignment>('alignment', alignment, defaultValue: BlockAlignment.stretch),
    );
    properties.add(
      EnumProperty<TextWrapMode>('textWrap', textWrap, defaultValue: TextWrapMode.none),
    );
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
      'BlockquoteNode(id: $id, text: $text, width: $width, height: $height, '
      'alignment: ${alignment.name}, textWrap: $textWrap, textAlign: $textAlign, '
      'lineHeight: $lineHeight, spaceBefore: $spaceBefore, spaceAfter: $spaceAfter, '
      'indentLeft: $indentLeft, indentRight: $indentRight, firstLineIndent: $firstLineIndent, '
      'metadata: $metadata)';
}
