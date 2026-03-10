/// Blockquote document node for the editable_document package.
///
/// Provides [BlockquoteNode], a text-bearing block that visually represents
/// quoted content with optional container layout properties.
library;

import 'package:flutter/foundation.dart';

import 'attributed_text.dart';
import 'block_alignment.dart';
import 'block_layout.dart';
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
  /// [width] and [height] default to `null` (use available / intrinsic size).
  BlockquoteNode({
    required super.id,
    super.text,
    this.width,
    this.height,
    this.alignment = BlockAlignment.stretch,
    this.textWrap = TextWrapMode.none,
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

  @override
  BlockquoteNode copyWith({
    String? id,
    AttributedText? text,
    double? width,
    double? height,
    BlockAlignment? alignment,
    TextWrapMode? textWrap,
    Map<String, dynamic>? metadata,
  }) {
    return BlockquoteNode(
      id: id ?? this.id,
      text: text ?? this.text,
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
    return other is BlockquoteNode &&
        other.id == id &&
        other.text == text &&
        other.width == width &&
        other.height == height &&
        other.alignment == alignment &&
        other.textWrap == textWrap &&
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
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'BlockquoteNode(id: $id, text: $text, width: $width, height: $height, '
      'alignment: ${alignment.name}, textWrap: $textWrap, metadata: $metadata)';
}
