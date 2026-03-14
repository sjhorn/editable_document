/// Image document node for the editable_document package.
///
/// Provides [ImageNode], a block-level node that embeds an image by URL.
/// Cursor placement uses [BinaryNodePosition] (upstream / downstream).
library;

import 'package:flutter/foundation.dart';

import 'block_alignment.dart';
import 'block_layout.dart';
import 'document_node.dart';
import 'text_wrap_mode.dart';

/// A [DocumentNode] representing a block-level image.
///
/// [ImageNode] stores the image source as a [imageUrl] string together with
/// optional [altText], [width], and [height] hints for rendering. Because the
/// node has no editable text, cursor placement is handled by
/// [BinaryNodePosition] (either before or after the image).
///
/// The [alignment] field controls how the image is positioned within the
/// available layout width. The [textWrap] field controls how surrounding
/// text interacts with this image.
///
/// ```dart
/// final image = ImageNode(
///   id: generateNodeId(),
///   imageUrl: 'https://example.com/photo.jpg',
///   altText: 'A scenic mountain vista',
///   width: 1920.0,
///   height: 1080.0,
///   alignment: BlockAlignment.center,
///   textWrap: TextWrapMode.none,
/// );
/// ```
class ImageNode extends DocumentNode implements HasBlockLayout {
  /// Creates an [ImageNode] with a required [imageUrl] and optional fields.
  ///
  /// [alignment] defaults to [BlockAlignment.stretch] (full-width).
  /// [textWrap] defaults to [TextWrapMode.none] (no text wrapping around the image).
  ImageNode({
    required super.id,
    required this.imageUrl,
    this.altText,
    this.width,
    this.height,
    this.alignment = BlockAlignment.stretch,
    this.textWrap = TextWrapMode.none,
    super.metadata,
  });

  /// The URL of the image to display.
  final String imageUrl;

  /// Accessible description of the image, or `null` if not provided.
  final String? altText;

  /// Preferred display width in logical pixels, or `null` to use intrinsic size.
  final double? width;

  /// Preferred display height in logical pixels, or `null` to use intrinsic size.
  final double? height;

  /// How the image is horizontally aligned within the available layout width.
  ///
  /// Defaults to [BlockAlignment.stretch], which causes the image to fill the
  /// entire available width. Use [BlockAlignment.center] or the other values
  /// when the image has an explicit [width] that is smaller than the layout.
  final BlockAlignment alignment;

  /// How surrounding text interacts with this image.
  ///
  /// Defaults to [TextWrapMode.none], which causes the image to occupy a full
  /// vertical row. Use [TextWrapMode.wrap] to enable float-like layout
  /// (similar to CSS `float`).
  final TextWrapMode textWrap;

  @override
  bool get isDraggable => true;

  @override
  bool get isResizable => alignment != BlockAlignment.stretch;

  @override
  DocumentNode copyWithSize({double? width, double? height}) =>
      copyWith(width: width ?? this.width, height: height ?? this.height);

  @override
  ImageNode copyWith({
    String? id,
    String? imageUrl,
    String? altText,
    double? width,
    double? height,
    BlockAlignment? alignment,
    TextWrapMode? textWrap,
    Map<String, dynamic>? metadata,
  }) {
    return ImageNode(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      altText: altText ?? this.altText,
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
    return other is ImageNode &&
        other.id == id &&
        other.imageUrl == imageUrl &&
        other.altText == altText &&
        other.width == width &&
        other.height == height &&
        other.alignment == alignment &&
        other.textWrap == textWrap &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        imageUrl,
        altText,
        width,
        height,
        alignment,
        textWrap,
        Object.hashAll(metadata.entries.map((e) => e)),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('imageUrl', imageUrl));
    properties.add(StringProperty('altText', altText, defaultValue: null));
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
      'ImageNode(id: $id, imageUrl: $imageUrl, altText: $altText, '
      'width: $width, height: $height, alignment: ${alignment.name}, '
      'textWrap: $textWrap, metadata: $metadata)';
}
