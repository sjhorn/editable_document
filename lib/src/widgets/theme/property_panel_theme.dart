/// Theme data for property panel widgets.
///
/// Provides [PropertyPanelThemeData] and the [PropertyPanelTheme]
/// [InheritedWidget] that propagates it down the widget tree.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// PropertyPanelThemeData
// ---------------------------------------------------------------------------

/// Immutable theme data for property panel widgets.
///
/// Controls the visual appearance of [DocumentPropertyPanel] and
/// [PropertySection] components.
///
/// All fields are optional. When a field is `null`, widgets fall back to
/// their Material theme defaults (e.g. [Theme.of(context).textTheme]).
///
/// Use [PropertyPanelTheme.of] to obtain the nearest [PropertyPanelThemeData]
/// in the widget tree. Wrap your panel in a [PropertyPanelTheme] to supply
/// custom values.
@immutable
class PropertyPanelThemeData with Diagnosticable {
  /// Creates a [PropertyPanelThemeData].
  ///
  /// All parameters are optional and default to `null`, which causes each
  /// panel widget to fall back to Material theme defaults.
  const PropertyPanelThemeData({
    this.backgroundColor,
    this.borderSide,
    this.width,
    this.padding,
    this.sectionLabelStyle,
    this.fieldLabelStyle,
    this.sectionSpacing,
  });

  /// Background color of the panel container.
  final Color? backgroundColor;

  /// Border drawn around or beside the panel container.
  final BorderSide? borderSide;

  /// Preferred width of the panel.
  ///
  /// When `null`, [DocumentPropertyPanel] falls back to its own [width]
  /// constructor parameter (default `280.0`).
  final double? width;

  /// Padding inside the panel container.
  final EdgeInsetsGeometry? padding;

  /// Text style for section heading labels in [PropertySection].
  ///
  /// Defaults to [TextTheme.labelMedium] when `null`.
  final TextStyle? sectionLabelStyle;

  /// Text style for field labels within property editors.
  final TextStyle? fieldLabelStyle;

  /// Vertical spacing inserted above each [PropertySection] label.
  ///
  /// Defaults to `12.0` when `null`.
  final double? sectionSpacing;

  /// Returns a copy of this theme data with the provided fields overridden.
  ///
  /// Fields that are not provided keep their current values.
  PropertyPanelThemeData copyWith({
    Color? backgroundColor,
    BorderSide? borderSide,
    double? width,
    EdgeInsetsGeometry? padding,
    TextStyle? sectionLabelStyle,
    TextStyle? fieldLabelStyle,
    double? sectionSpacing,
  }) {
    return PropertyPanelThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderSide: borderSide ?? this.borderSide,
      width: width ?? this.width,
      padding: padding ?? this.padding,
      sectionLabelStyle: sectionLabelStyle ?? this.sectionLabelStyle,
      fieldLabelStyle: fieldLabelStyle ?? this.fieldLabelStyle,
      sectionSpacing: sectionSpacing ?? this.sectionSpacing,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PropertyPanelThemeData &&
        other.backgroundColor == backgroundColor &&
        other.borderSide == borderSide &&
        other.width == width &&
        other.padding == padding &&
        other.sectionLabelStyle == sectionLabelStyle &&
        other.fieldLabelStyle == fieldLabelStyle &&
        other.sectionSpacing == sectionSpacing;
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        borderSide,
        width,
        padding,
        sectionLabelStyle,
        fieldLabelStyle,
        sectionSpacing,
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<BorderSide>('borderSide', borderSide, defaultValue: null));
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding, defaultValue: null));
    properties.add(
      DiagnosticsProperty<TextStyle>('sectionLabelStyle', sectionLabelStyle, defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<TextStyle>('fieldLabelStyle', fieldLabelStyle, defaultValue: null),
    );
    properties.add(DoubleProperty('sectionSpacing', sectionSpacing, defaultValue: null));
  }
}

// ---------------------------------------------------------------------------
// PropertyPanelTheme
// ---------------------------------------------------------------------------

/// An [InheritedWidget] that provides [PropertyPanelThemeData] to descendants.
///
/// Wrap your property panel (or the section of the widget tree containing
/// panels) in a [PropertyPanelTheme] to override the default styling:
///
/// ```dart
/// PropertyPanelTheme(
///   data: PropertyPanelThemeData(width: 320.0, sectionSpacing: 16.0),
///   child: DocumentPropertyPanel(
///     controller: controller,
///     requestHandler: editor.submit,
///   ),
/// )
/// ```
///
/// Use [PropertyPanelTheme.of] (or [PropertyPanelTheme.maybeOf]) to read
/// the current theme from within a panel widget.
class PropertyPanelTheme extends InheritedWidget {
  /// Creates a [PropertyPanelTheme] that provides [data] to [child].
  const PropertyPanelTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// The theme data to propagate to descendants.
  final PropertyPanelThemeData data;

  /// Returns the [PropertyPanelThemeData] from the nearest
  /// [PropertyPanelTheme] ancestor, or `null` if there is none.
  static PropertyPanelThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PropertyPanelTheme>()?.data;
  }

  /// Returns the [PropertyPanelThemeData] from the nearest
  /// [PropertyPanelTheme] ancestor.
  ///
  /// Falls back to an all-`null` [PropertyPanelThemeData] if no ancestor
  /// exists, so callers can always safely access properties and fall back to
  /// Material defaults.
  static PropertyPanelThemeData of(BuildContext context) {
    return maybeOf(context) ?? const PropertyPanelThemeData();
  }

  @override
  bool updateShouldNotify(PropertyPanelTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<PropertyPanelThemeData>('data', data));
  }
}
