/// Theme data for document toolbar widgets.
///
/// Provides [DocumentToolbarThemeData] and the [DocumentToolbarTheme]
/// [InheritedWidget] that propagates it down the widget tree.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// DocumentToolbarThemeData
// ---------------------------------------------------------------------------

/// Immutable theme data for document toolbar widgets.
///
/// Controls the visual appearance of [DocumentFormatToggle],
/// [DocumentToolbar], and other toolbar components.
///
/// All fields are optional. When a field is `null`, toolbar widgets fall back
/// to their Material theme defaults (e.g. [Theme.of(context).colorScheme]).
///
/// Use [DocumentToolbarTheme.of] to obtain the nearest [DocumentToolbarThemeData]
/// in the widget tree. Wrap your toolbar in a [DocumentToolbarTheme] to supply
/// custom values.
@immutable
class DocumentToolbarThemeData with Diagnosticable {
  /// Creates a [DocumentToolbarThemeData].
  ///
  /// All parameters are optional and default to `null`, which causes each
  /// toolbar widget to fall back to Material theme defaults.
  const DocumentToolbarThemeData({
    this.backgroundColor,
    this.borderSide,
    this.padding,
    this.iconSize,
    this.buttonSize,
    this.dividerColor,
    this.activeColor,
    this.activeIconColor,
    this.disabledColor,
  });

  /// Background color of the toolbar container.
  final Color? backgroundColor;

  /// Border drawn below/around the toolbar container.
  final BorderSide? borderSide;

  /// Padding inside the toolbar container.
  final EdgeInsetsGeometry? padding;

  /// Size of icons in toolbar buttons.
  ///
  /// Defaults to `18.0` when `null`.
  final double? iconSize;

  /// Width and height of each toolbar button.
  ///
  /// Defaults to `32.0` when `null`.
  final double? buttonSize;

  /// Color of dividers between button groups.
  final Color? dividerColor;

  /// Background color of a toggle button when it is active.
  final Color? activeColor;

  /// Icon color of a toggle button when it is active.
  final Color? activeIconColor;

  /// Color for disabled (null-[onPressed]) buttons.
  final Color? disabledColor;

  /// Returns a copy of this theme data with the provided fields overridden.
  ///
  /// Fields that are not provided keep their current values.
  DocumentToolbarThemeData copyWith({
    Color? backgroundColor,
    BorderSide? borderSide,
    EdgeInsetsGeometry? padding,
    double? iconSize,
    double? buttonSize,
    Color? dividerColor,
    Color? activeColor,
    Color? activeIconColor,
    Color? disabledColor,
  }) {
    return DocumentToolbarThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderSide: borderSide ?? this.borderSide,
      padding: padding ?? this.padding,
      iconSize: iconSize ?? this.iconSize,
      buttonSize: buttonSize ?? this.buttonSize,
      dividerColor: dividerColor ?? this.dividerColor,
      activeColor: activeColor ?? this.activeColor,
      activeIconColor: activeIconColor ?? this.activeIconColor,
      disabledColor: disabledColor ?? this.disabledColor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentToolbarThemeData &&
        other.backgroundColor == backgroundColor &&
        other.borderSide == borderSide &&
        other.padding == padding &&
        other.iconSize == iconSize &&
        other.buttonSize == buttonSize &&
        other.dividerColor == dividerColor &&
        other.activeColor == activeColor &&
        other.activeIconColor == activeIconColor &&
        other.disabledColor == disabledColor;
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        borderSide,
        padding,
        iconSize,
        buttonSize,
        dividerColor,
        activeColor,
        activeIconColor,
        disabledColor,
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<BorderSide>('borderSide', borderSide, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding, defaultValue: null));
    properties.add(DoubleProperty('iconSize', iconSize, defaultValue: null));
    properties.add(DoubleProperty('buttonSize', buttonSize, defaultValue: null));
    properties.add(ColorProperty('dividerColor', dividerColor, defaultValue: null));
    properties.add(ColorProperty('activeColor', activeColor, defaultValue: null));
    properties.add(ColorProperty('activeIconColor', activeIconColor, defaultValue: null));
    properties.add(ColorProperty('disabledColor', disabledColor, defaultValue: null));
  }
}

// ---------------------------------------------------------------------------
// DocumentToolbarTheme
// ---------------------------------------------------------------------------

/// An [InheritedWidget] that provides [DocumentToolbarThemeData] to descendants.
///
/// Wrap your toolbar (or the section of the widget tree containing toolbars)
/// in a [DocumentToolbarTheme] to override the default styling:
///
/// ```dart
/// DocumentToolbarTheme(
///   data: DocumentToolbarThemeData(iconSize: 20.0),
///   child: DocumentToolbar(
///     controller: controller,
///     requestHandler: requestHandler,
///   ),
/// )
/// ```
///
/// Use [DocumentToolbarTheme.of] (or [DocumentToolbarTheme.maybeOf]) to read
/// the current theme from within a toolbar widget.
class DocumentToolbarTheme extends InheritedWidget {
  /// Creates a [DocumentToolbarTheme] that provides [data] to [child].
  const DocumentToolbarTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// The theme data to propagate to descendants.
  final DocumentToolbarThemeData data;

  /// Returns the [DocumentToolbarThemeData] from the nearest
  /// [DocumentToolbarTheme] ancestor, or `null` if there is none.
  static DocumentToolbarThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DocumentToolbarTheme>()?.data;
  }

  /// Returns the [DocumentToolbarThemeData] from the nearest
  /// [DocumentToolbarTheme] ancestor.
  ///
  /// Falls back to an all-`null` [DocumentToolbarThemeData] if no ancestor
  /// exists, so callers can always safely access properties and fall back to
  /// Material defaults.
  static DocumentToolbarThemeData of(BuildContext context) {
    return maybeOf(context) ?? const DocumentToolbarThemeData();
  }

  @override
  bool updateShouldNotify(DocumentToolbarTheme oldWidget) => oldWidget.data != data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DocumentToolbarThemeData>('data', data));
  }
}
