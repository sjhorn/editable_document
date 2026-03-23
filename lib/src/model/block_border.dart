/// Border specification for document blocks.
///
/// Defines the visual appearance of a block's outside border, including its
/// [style], `width`, and [color].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Visual style for a block border.
enum BlockBorderStyle {
  /// No border is drawn.
  none,

  /// A continuous solid line.
  solid,

  /// A series of dots.
  dotted,

  /// A series of dashes.
  dashed,
}

/// Immutable specification of a document block's outside border.
///
/// When applied to a [DocumentNode], the document layout draws a border
/// around the block's bounds using the specified [style], `width`, and [color].
///
/// The border is paint-only — it does not inset the block's content area.
///
/// ```dart
/// final bordered = ParagraphNode(
///   id: generateNodeId(),
///   text: AttributedText('Bordered paragraph'),
///   border: BlockBorder(style: BlockBorderStyle.solid, width: 2.0),
/// );
/// ```
class BlockBorder with Diagnosticable {
  /// Creates a [BlockBorder].
  ///
  /// [style] defaults to [BlockBorderStyle.solid].
  /// `width` defaults to `1.0` logical pixels.
  /// [color] defaults to `null`, which the renderer interprets as black.
  const BlockBorder({
    this.style = BlockBorderStyle.solid,
    this.width = 1.0,
    this.color,
  });

  /// The visual style of the border line.
  final BlockBorderStyle style;

  /// The stroke width in logical pixels.
  final double width;

  /// The border color, or `null` to use the default (black).
  final Color? color;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BlockBorder &&
        other.style == style &&
        other.width == width &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(style, width, color);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<BlockBorderStyle>('style', style));
    properties.add(DoubleProperty('width', width, defaultValue: 1.0));
    properties.add(ColorProperty('color', color, defaultValue: null));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'BlockBorder(style: $style, width: $width, color: $color)';
}
