/// Block dimension types for the editable_document package.
///
/// Provides [BlockDimension], [PixelDimension], and [PercentDimension] for
/// expressing block-level widths and heights as either absolute pixels or a
/// fraction of a reference size.
library;

import 'package:flutter/foundation.dart';

/// A block-level dimension that can be expressed as absolute pixels or as a
/// percentage of a reference size.
///
/// Use [BlockDimension.pixels] for fixed sizes and [BlockDimension.percent]
/// for sizes relative to the document width (for width dimensions) or
/// viewport height (for height dimensions).
///
/// ```dart
/// final w = BlockDimension.pixels(400.0);
/// final h = BlockDimension.percent(0.5); // 50 % of reference
/// final resolved = BlockDimension.resolve(w, 800.0); // → 400.0
/// final resolved2 = BlockDimension.resolve(h, 600.0); // → 300.0
/// ```
sealed class BlockDimension with Diagnosticable {
  /// Creates a [BlockDimension].
  const BlockDimension();

  /// A dimension expressed as absolute logical pixels.
  const factory BlockDimension.pixels(double value) = PixelDimension;

  /// A dimension expressed as a fraction of a reference size.
  ///
  /// [value] should be in the range 0.0–1.0 (Flutter convention), where
  /// 0.5 means 50 % of the reference dimension.
  const factory BlockDimension.percent(double value) = PercentDimension;

  /// Resolves [dimension] to logical pixels using [referenceSize].
  ///
  /// Returns `null` when [dimension] is `null`. For [PixelDimension],
  /// returns the pixel value directly. For [PercentDimension], multiplies
  /// [value] by [referenceSize].
  static double? resolve(BlockDimension? dimension, double referenceSize) {
    if (dimension == null) return null;
    return switch (dimension) {
      PixelDimension(:final value) => value,
      PercentDimension(:final value) => value * referenceSize,
    };
  }
}

/// A [BlockDimension] expressed as absolute logical pixels.
class PixelDimension extends BlockDimension {
  /// Creates a pixel dimension with the given [value].
  const PixelDimension(this.value);

  /// The dimension in logical pixels.
  final double value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PixelDimension && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('value', value));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'BlockDimension.pixels($value)';
}

/// A [BlockDimension] expressed as a fraction of a reference size (0.0–1.0).
class PercentDimension extends BlockDimension {
  /// Creates a percentage dimension with the given [value].
  ///
  /// [value] should be in the range 0.0–1.0, where 0.5 means 50 %.
  const PercentDimension(this.value);

  /// The fraction of the reference size (0.0–1.0).
  final double value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PercentDimension && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('value', value));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'BlockDimension.percent($value)';
}
