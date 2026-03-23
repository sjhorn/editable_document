/// Theme data for document content styling.
///
/// Provides [DocumentThemeData] and the [DocumentTheme] [InheritedTheme]
/// that propagates it down the widget tree.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'document_toolbar_theme.dart';
import 'property_panel_theme.dart';

// ---------------------------------------------------------------------------
// StatusBarThemeData
// ---------------------------------------------------------------------------

/// Theme data for the status bar displayed at the bottom of a [DocumentEditor].
///
/// All fields are optional. When `null`, [DocumentEditor] falls back to
/// Material 3 defaults: `colorScheme.surfaceContainerHighest` for background,
/// `dividerColor` for the top border, and inherited text style.
@immutable
class StatusBarThemeData with Diagnosticable {
  /// Creates a [StatusBarThemeData].
  const StatusBarThemeData({
    this.backgroundColor,
    this.borderSide,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.textStyle,
  });

  /// Background color of the status bar.
  ///
  /// When `null`, defaults to `colorScheme.surfaceContainerHighest`.
  final Color? backgroundColor;

  /// The top border drawn above the status bar.
  ///
  /// When `null`, defaults to `BorderSide(color: dividerColor)`.
  final BorderSide? borderSide;

  /// Padding inside the status bar container.
  ///
  /// Defaults to `EdgeInsets.symmetric(horizontal: 16, vertical: 6)`.
  final EdgeInsets padding;

  /// Text style applied to status bar labels.
  ///
  /// When `null`, the Material theme's `bodySmall` is used.
  final TextStyle? textStyle;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StatusBarThemeData &&
        other.backgroundColor == backgroundColor &&
        other.borderSide == borderSide &&
        other.padding == padding &&
        other.textStyle == textStyle;
  }

  @override
  int get hashCode => Object.hash(backgroundColor, borderSide, padding, textStyle);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(
      DiagnosticsProperty<BorderSide?>('borderSide', borderSide, defaultValue: null),
    );
    properties.add(DiagnosticsProperty<EdgeInsets>('padding', padding));
    properties.add(
      DiagnosticsProperty<TextStyle?>('textStyle', textStyle, defaultValue: null),
    );
  }
}

// ---------------------------------------------------------------------------
// DocumentThemeData
// ---------------------------------------------------------------------------

/// Immutable theme data for document content styling.
///
/// Controls the visual appearance of document content rendered by
/// [EditableDocument] and [DocumentField].
///
/// All fields are optional. When `null`, widgets fall back to Material
/// theme defaults from [Theme.of(context)].
///
/// Use [DocumentTheme.of] to obtain the nearest [DocumentThemeData] in the
/// widget tree. Wrap your document in a [DocumentTheme] to supply custom
/// values.
@immutable
class DocumentThemeData with Diagnosticable {
  /// Creates a [DocumentThemeData] with the given properties.
  ///
  /// All parameters are optional and default to `null`, which causes each
  /// widget to fall back to Material theme defaults.
  const DocumentThemeData({
    this.defaultTextStyle,
    this.defaultLineHeight,
    this.defaultBlockSpacing,
    this.defaultDocumentPadding,
    this.heading1Style,
    this.heading2Style,
    this.heading3Style,
    this.blockquoteStyle,
    this.codeBlockStyle,
    this.codeBlockBackgroundColor,
    this.codeBlockPadding,
    this.listItemBulletColor,
    this.horizontalRuleColor,
    this.horizontalRuleThickness,
    this.selectionColor,
    this.caretColor,
    this.caretWidth,
    this.toolbarTheme,
    this.propertyPanelTheme,
    this.statusBarTheme,
  });

  // ---------------------------------------------------------------------------
  // Text styles
  // ---------------------------------------------------------------------------

  /// Default text style applied to all document content.
  final TextStyle? defaultTextStyle;

  /// Default line height multiplier for document text.
  final double? defaultLineHeight;

  /// Text style for first-level headings.
  final TextStyle? heading1Style;

  /// Text style for second-level headings.
  final TextStyle? heading2Style;

  /// Text style for third-level headings.
  final TextStyle? heading3Style;

  /// Text style for blockquote content.
  final TextStyle? blockquoteStyle;

  /// Text style for code block content (typically a monospace font).
  final TextStyle? codeBlockStyle;

  // ---------------------------------------------------------------------------
  // Block styling
  // ---------------------------------------------------------------------------

  /// Default vertical spacing between document blocks.
  final double? defaultBlockSpacing;

  /// Padding around the document content area.
  final EdgeInsets? defaultDocumentPadding;

  /// Background color of code block containers.
  final Color? codeBlockBackgroundColor;

  /// Inner padding applied inside code block containers.
  final double? codeBlockPadding;

  /// Color used for bullet points and list item markers.
  final Color? listItemBulletColor;

  /// Color of horizontal rule dividers.
  final Color? horizontalRuleColor;

  /// Stroke width of horizontal rule dividers.
  final double? horizontalRuleThickness;

  // ---------------------------------------------------------------------------
  // Selection and caret
  // ---------------------------------------------------------------------------

  /// Background color used to highlight selected text ranges.
  final Color? selectionColor;

  /// Color of the text insertion caret.
  final Color? caretColor;

  /// Width (in logical pixels) of the text insertion caret.
  final double? caretWidth;

  // ---------------------------------------------------------------------------
  // Nested themes
  // ---------------------------------------------------------------------------

  /// Theme data for toolbar widgets embedded within the document.
  final DocumentToolbarThemeData? toolbarTheme;

  /// Theme data for property panel widgets embedded beside the document.
  final PropertyPanelThemeData? propertyPanelTheme;

  /// Theme data for the status bar displayed at the bottom of a
  /// [DocumentEditor].
  final StatusBarThemeData? statusBarTheme;

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  /// Returns a copy of this theme data with the provided fields overridden.
  ///
  /// Fields that are not provided keep their current values.
  DocumentThemeData copyWith({
    TextStyle? defaultTextStyle,
    double? defaultLineHeight,
    double? defaultBlockSpacing,
    EdgeInsets? defaultDocumentPadding,
    TextStyle? heading1Style,
    TextStyle? heading2Style,
    TextStyle? heading3Style,
    TextStyle? blockquoteStyle,
    TextStyle? codeBlockStyle,
    Color? codeBlockBackgroundColor,
    double? codeBlockPadding,
    Color? listItemBulletColor,
    Color? horizontalRuleColor,
    double? horizontalRuleThickness,
    Color? selectionColor,
    Color? caretColor,
    double? caretWidth,
    DocumentToolbarThemeData? toolbarTheme,
    PropertyPanelThemeData? propertyPanelTheme,
    StatusBarThemeData? statusBarTheme,
  }) {
    return DocumentThemeData(
      defaultTextStyle: defaultTextStyle ?? this.defaultTextStyle,
      defaultLineHeight: defaultLineHeight ?? this.defaultLineHeight,
      defaultBlockSpacing: defaultBlockSpacing ?? this.defaultBlockSpacing,
      defaultDocumentPadding: defaultDocumentPadding ?? this.defaultDocumentPadding,
      heading1Style: heading1Style ?? this.heading1Style,
      heading2Style: heading2Style ?? this.heading2Style,
      heading3Style: heading3Style ?? this.heading3Style,
      blockquoteStyle: blockquoteStyle ?? this.blockquoteStyle,
      codeBlockStyle: codeBlockStyle ?? this.codeBlockStyle,
      codeBlockBackgroundColor: codeBlockBackgroundColor ?? this.codeBlockBackgroundColor,
      codeBlockPadding: codeBlockPadding ?? this.codeBlockPadding,
      listItemBulletColor: listItemBulletColor ?? this.listItemBulletColor,
      horizontalRuleColor: horizontalRuleColor ?? this.horizontalRuleColor,
      horizontalRuleThickness: horizontalRuleThickness ?? this.horizontalRuleThickness,
      selectionColor: selectionColor ?? this.selectionColor,
      caretColor: caretColor ?? this.caretColor,
      caretWidth: caretWidth ?? this.caretWidth,
      toolbarTheme: toolbarTheme ?? this.toolbarTheme,
      propertyPanelTheme: propertyPanelTheme ?? this.propertyPanelTheme,
      statusBarTheme: statusBarTheme ?? this.statusBarTheme,
    );
  }

  // ---------------------------------------------------------------------------
  // merge
  // ---------------------------------------------------------------------------

  /// Returns a new [DocumentThemeData] where each `null` field in `this` is
  /// filled from [other].
  ///
  /// Fields that are already non-`null` in `this` are preserved. If [other]
  /// is `null` the same instance is returned unchanged.
  DocumentThemeData merge(DocumentThemeData? other) {
    if (other == null) return this;
    return DocumentThemeData(
      defaultTextStyle: defaultTextStyle ?? other.defaultTextStyle,
      defaultLineHeight: defaultLineHeight ?? other.defaultLineHeight,
      defaultBlockSpacing: defaultBlockSpacing ?? other.defaultBlockSpacing,
      defaultDocumentPadding: defaultDocumentPadding ?? other.defaultDocumentPadding,
      heading1Style: heading1Style ?? other.heading1Style,
      heading2Style: heading2Style ?? other.heading2Style,
      heading3Style: heading3Style ?? other.heading3Style,
      blockquoteStyle: blockquoteStyle ?? other.blockquoteStyle,
      codeBlockStyle: codeBlockStyle ?? other.codeBlockStyle,
      codeBlockBackgroundColor: codeBlockBackgroundColor ?? other.codeBlockBackgroundColor,
      codeBlockPadding: codeBlockPadding ?? other.codeBlockPadding,
      listItemBulletColor: listItemBulletColor ?? other.listItemBulletColor,
      horizontalRuleColor: horizontalRuleColor ?? other.horizontalRuleColor,
      horizontalRuleThickness: horizontalRuleThickness ?? other.horizontalRuleThickness,
      selectionColor: selectionColor ?? other.selectionColor,
      caretColor: caretColor ?? other.caretColor,
      caretWidth: caretWidth ?? other.caretWidth,
      toolbarTheme: toolbarTheme ?? other.toolbarTheme,
      propertyPanelTheme: propertyPanelTheme ?? other.propertyPanelTheme,
      statusBarTheme: statusBarTheme ?? other.statusBarTheme,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentThemeData &&
        other.defaultTextStyle == defaultTextStyle &&
        other.defaultLineHeight == defaultLineHeight &&
        other.defaultBlockSpacing == defaultBlockSpacing &&
        other.defaultDocumentPadding == defaultDocumentPadding &&
        other.heading1Style == heading1Style &&
        other.heading2Style == heading2Style &&
        other.heading3Style == heading3Style &&
        other.blockquoteStyle == blockquoteStyle &&
        other.codeBlockStyle == codeBlockStyle &&
        other.codeBlockBackgroundColor == codeBlockBackgroundColor &&
        other.codeBlockPadding == codeBlockPadding &&
        other.listItemBulletColor == listItemBulletColor &&
        other.horizontalRuleColor == horizontalRuleColor &&
        other.horizontalRuleThickness == horizontalRuleThickness &&
        other.selectionColor == selectionColor &&
        other.caretColor == caretColor &&
        other.caretWidth == caretWidth &&
        other.toolbarTheme == toolbarTheme &&
        other.propertyPanelTheme == propertyPanelTheme &&
        other.statusBarTheme == statusBarTheme;
  }

  @override
  int get hashCode => Object.hashAll([
        defaultTextStyle,
        defaultLineHeight,
        defaultBlockSpacing,
        defaultDocumentPadding,
        heading1Style,
        heading2Style,
        heading3Style,
        blockquoteStyle,
        codeBlockStyle,
        codeBlockBackgroundColor,
        codeBlockPadding,
        listItemBulletColor,
        horizontalRuleColor,
        horizontalRuleThickness,
        selectionColor,
        caretColor,
        caretWidth,
        toolbarTheme,
        propertyPanelTheme,
        statusBarTheme,
      ]);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<TextStyle>('defaultTextStyle', defaultTextStyle, defaultValue: null),
    );
    properties.add(DoubleProperty('defaultLineHeight', defaultLineHeight, defaultValue: null));
    properties.add(DoubleProperty('defaultBlockSpacing', defaultBlockSpacing, defaultValue: null));
    properties.add(
      DiagnosticsProperty<EdgeInsets>(
        'defaultDocumentPadding',
        defaultDocumentPadding,
        defaultValue: null,
      ),
    );
    properties.add(
      DiagnosticsProperty<TextStyle>('heading1Style', heading1Style, defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<TextStyle>('heading2Style', heading2Style, defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<TextStyle>('heading3Style', heading3Style, defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<TextStyle>('blockquoteStyle', blockquoteStyle, defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<TextStyle>('codeBlockStyle', codeBlockStyle, defaultValue: null),
    );
    properties.add(
      ColorProperty('codeBlockBackgroundColor', codeBlockBackgroundColor, defaultValue: null),
    );
    properties.add(DoubleProperty('codeBlockPadding', codeBlockPadding, defaultValue: null));
    properties.add(ColorProperty('listItemBulletColor', listItemBulletColor, defaultValue: null));
    properties.add(ColorProperty('horizontalRuleColor', horizontalRuleColor, defaultValue: null));
    properties.add(
      DoubleProperty('horizontalRuleThickness', horizontalRuleThickness, defaultValue: null),
    );
    properties.add(ColorProperty('selectionColor', selectionColor, defaultValue: null));
    properties.add(ColorProperty('caretColor', caretColor, defaultValue: null));
    properties.add(DoubleProperty('caretWidth', caretWidth, defaultValue: null));
    properties.add(
      DiagnosticsProperty<DocumentToolbarThemeData>('toolbarTheme', toolbarTheme,
          defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<PropertyPanelThemeData>(
        'propertyPanelTheme',
        propertyPanelTheme,
        defaultValue: null,
      ),
    );
    properties.add(
      DiagnosticsProperty<StatusBarThemeData>(
        'statusBarTheme',
        statusBarTheme,
        defaultValue: null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DocumentTheme
// ---------------------------------------------------------------------------

/// An [InheritedTheme] that provides [DocumentThemeData] to descendant widgets.
///
/// Widgets like [EditableDocument], [DocumentToolbar], and
/// [DocumentPropertyPanel] read this theme via [DocumentTheme.of].
///
/// ```dart
/// DocumentTheme(
///   data: DocumentThemeData(
///     defaultBlockSpacing: 16.0,
///     caretColor: Colors.blue,
///   ),
///   child: EditableDocument(...),
/// )
/// ```
class DocumentTheme extends InheritedTheme {
  /// Creates a [DocumentTheme] that provides [data] to [child].
  const DocumentTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// The theme data to propagate to descendants.
  final DocumentThemeData data;

  /// Returns the [DocumentThemeData] from the closest ancestor [DocumentTheme],
  /// or a default [DocumentThemeData()] if none exists.
  static DocumentThemeData of(BuildContext context) {
    return maybeOf(context) ?? const DocumentThemeData();
  }

  /// Returns the [DocumentThemeData] from the closest ancestor [DocumentTheme],
  /// or `null` if none exists.
  static DocumentThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DocumentTheme>()?.data;
  }

  @override
  bool updateShouldNotify(DocumentTheme oldWidget) => data != oldWidget.data;

  @override
  Widget wrap(BuildContext context, Widget child) {
    return DocumentTheme(data: data, child: child);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DocumentThemeData>('data', data));
  }
}
