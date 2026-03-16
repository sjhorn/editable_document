/// Code block document node for the editable_document package.
///
/// Provides [CodeBlockNode], a fenced code block that optionally specifies a
/// programming language for syntax highlighting.
library;

import 'package:flutter/foundation.dart';

import 'attributed_text.dart';
import 'block_alignment.dart';
import 'block_layout.dart';
import 'document_node.dart';
import 'text_node.dart';
import 'text_wrap_mode.dart';

/// A [TextNode] representing a fenced code block.
///
/// [CodeBlockNode] holds source code as plain [AttributedText] and stores the
/// optional [language] identifier for syntax highlighting. Unlike
/// [ParagraphNode] with [ParagraphBlockType.codeBlock], this node type is
/// explicitly specialised for code and carries language metadata directly.
///
/// The [width] and [height] fields constrain the rendered block to a fixed
/// size. The [alignment] field positions the block within available layout
/// width. The [textWrap] field controls how surrounding text interacts with
/// this code block.
///
/// ```dart
/// final snippet = CodeBlockNode(
///   id: generateNodeId(),
///   text: AttributedText('void main() => print("hello");'),
///   language: 'dart',
///   width: 640.0,
///   alignment: BlockAlignment.center,
/// );
/// ```
class CodeBlockNode extends TextNode implements HasBlockLayout {
  /// Creates a [CodeBlockNode] with optional [text], [language], sizing, and
  /// layout fields.
  ///
  /// [alignment] defaults to [BlockAlignment.stretch].
  /// [textWrap] defaults to [TextWrapMode.none].
  /// [lineHeight] defaults to `null` (inherit document default).
  /// [width] and [height] default to `null` (use available / intrinsic size).
  /// [spaceBefore] and [spaceAfter] default to `null` (use document-level
  /// default spacing).
  CodeBlockNode({
    required super.id,
    super.text,
    this.language,
    this.width,
    this.height,
    this.alignment = BlockAlignment.stretch,
    this.textWrap = TextWrapMode.none,
    this.lineHeight,
    this.spaceBefore,
    this.spaceAfter,
    super.metadata,
  });

  /// The programming language identifier for syntax highlighting, or `null`.
  ///
  /// Common values include `'dart'`, `'python'`, `'javascript'`, etc.
  final String? language;

  /// Preferred display width in logical pixels, or `null` to fill available width.
  final double? width;

  /// Preferred display height in logical pixels, or `null` to use intrinsic height.
  final double? height;

  /// How the code block is horizontally aligned within the available layout width.
  ///
  /// Defaults to [BlockAlignment.stretch], which causes the block to fill the
  /// entire available width. Use other values when [width] is smaller than the
  /// layout width.
  final BlockAlignment alignment;

  /// How surrounding text interacts with this code block.
  ///
  /// Defaults to [TextWrapMode.none], which causes the block to occupy a full
  /// vertical row. Use [TextWrapMode.wrap] to enable float-like layout.
  final TextWrapMode textWrap;

  /// Line-height multiplier for this code block, or `null` to inherit the
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
  CodeBlockNode copyWith({
    String? id,
    AttributedText? text,
    String? language,
    double? width,
    double? height,
    BlockAlignment? alignment,
    TextWrapMode? textWrap,
    double? lineHeight,
    double? spaceBefore,
    double? spaceAfter,
    Map<String, dynamic>? metadata,
  }) {
    return CodeBlockNode(
      id: id ?? this.id,
      text: text ?? this.text,
      language: language ?? this.language,
      width: width ?? this.width,
      height: height ?? this.height,
      alignment: alignment ?? this.alignment,
      textWrap: textWrap ?? this.textWrap,
      lineHeight: lineHeight ?? this.lineHeight,
      spaceBefore: spaceBefore ?? this.spaceBefore,
      spaceAfter: spaceAfter ?? this.spaceAfter,
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
        other.width == width &&
        other.height == height &&
        other.alignment == alignment &&
        other.textWrap == textWrap &&
        other.lineHeight == lineHeight &&
        other.spaceBefore == spaceBefore &&
        other.spaceAfter == spaceAfter &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        text,
        language,
        width,
        height,
        alignment,
        textWrap,
        lineHeight,
        spaceBefore,
        spaceAfter,
        Object.hashAll(metadata.entries.map((e) => e)),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('language', language, defaultValue: null));
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DoubleProperty('height', height, defaultValue: null));
    properties.add(
      EnumProperty<BlockAlignment>('alignment', alignment, defaultValue: BlockAlignment.stretch),
    );
    properties.add(
      EnumProperty<TextWrapMode>('textWrap', textWrap, defaultValue: TextWrapMode.none),
    );
    properties.add(DoubleProperty('lineHeight', lineHeight, defaultValue: null));
    properties.add(DoubleProperty('spaceBefore', spaceBefore, defaultValue: null));
    properties.add(DoubleProperty('spaceAfter', spaceAfter, defaultValue: null));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'CodeBlockNode(id: $id, language: $language, width: $width, height: $height, '
      'alignment: ${alignment.name}, textWrap: $textWrap, lineHeight: $lineHeight, '
      'spaceBefore: $spaceBefore, spaceAfter: $spaceAfter, '
      'text: $text, metadata: $metadata)';
}
