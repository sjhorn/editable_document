/// Image document node for the editable_document package.
///
/// Provides [ImageNode], a block-level node that embeds an image by URL.
/// Cursor placement uses [BinaryNodePosition] (upstream / downstream).
library;

import 'package:flutter/foundation.dart';

import 'document_node.dart';

/// A [DocumentNode] representing a block-level image.
///
/// [ImageNode] stores the image source as a [imageUrl] string together with
/// optional [altText], [width], and [height] hints for rendering. Because the
/// node has no editable text, cursor placement is handled by
/// [BinaryNodePosition] (either before or after the image).
///
/// ```dart
/// final image = ImageNode(
///   id: generateNodeId(),
///   imageUrl: 'https://example.com/photo.jpg',
///   altText: 'A scenic mountain vista',
///   width: 1920.0,
///   height: 1080.0,
/// );
/// ```
class ImageNode extends DocumentNode {
  /// Creates an [ImageNode] with a required [imageUrl] and optional fields.
  ImageNode({
    required super.id,
    required this.imageUrl,
    this.altText,
    this.width,
    this.height,
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

  @override
  ImageNode copyWith({
    String? id,
    String? imageUrl,
    String? altText,
    double? width,
    double? height,
    Map<String, dynamic>? metadata,
  }) {
    return ImageNode(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      altText: altText ?? this.altText,
      width: width ?? this.width,
      height: height ?? this.height,
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
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        imageUrl,
        altText,
        width,
        height,
        Object.hashAll(metadata.entries.map((e) => e)),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('imageUrl', imageUrl));
    properties.add(StringProperty('altText', altText, defaultValue: null));
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DoubleProperty('height', height, defaultValue: null));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'ImageNode(id: $id, imageUrl: $imageUrl, altText: $altText, '
      'width: $width, height: $height, metadata: $metadata)';
}
