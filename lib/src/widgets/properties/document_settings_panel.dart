/// A panel for editing document-wide settings.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../rendering/render_document_layout.dart';
import '../theme/property_panel_theme.dart';
import '../toolbar/document_color_picker.dart';
import 'property_section.dart';

// ---------------------------------------------------------------------------
// DocumentSettingsPanel
// ---------------------------------------------------------------------------

/// A panel for editing document-wide settings.
///
/// Controls block spacing, default line height, document padding,
/// and line number configuration. Uses [PropertySection] for layout
/// and [PropertyPanelTheme] for styling.
///
/// The Line Numbers section is only shown when [onShowLineNumbersChanged]
/// is non-null. When [showLineNumbers] is `true`, additional controls for
/// vertical alignment, font family, font size, number color, and gutter
/// background color are revealed.
///
/// ```dart
/// DocumentSettingsPanel(
///   blockSpacing: 0.0,
///   onBlockSpacingChanged: (v) => setState(() => blockSpacing = v),
///   defaultLineHeight: null,
///   onDefaultLineHeightChanged: (v) => setState(() => lineHeight = v),
///   documentPadding: EdgeInsets.zero,
///   onDocumentPaddingChanged: (v) => setState(() => padding = v),
///   showLineNumbers: showLineNumbers,
///   onShowLineNumbersChanged: (v) => setState(() => showLineNumbers = v),
/// )
/// ```
class DocumentSettingsPanel extends StatelessWidget {
  /// Creates a [DocumentSettingsPanel].
  const DocumentSettingsPanel({
    super.key,
    required this.blockSpacing,
    required this.onBlockSpacingChanged,
    required this.defaultLineHeight,
    required this.onDefaultLineHeightChanged,
    required this.documentPadding,
    required this.onDocumentPaddingChanged,
    this.showLineNumbers = false,
    this.onShowLineNumbersChanged,
    this.lineNumberAlignment,
    this.onLineNumberAlignmentChanged,
    this.lineNumberFontFamily,
    this.onLineNumberFontFamilyChanged,
    this.lineNumberFontSize,
    this.onLineNumberFontSizeChanged,
    this.lineNumberColor,
    this.onLineNumberColorChanged,
    this.lineNumberBackgroundColor,
    this.onLineNumberBackgroundColorChanged,
    this.width = 280.0,
    this.colorPresets = _defaultColorPresets,
  });

  /// Vertical spacing between document blocks, in logical pixels.
  final double blockSpacing;

  /// Called when the user changes the block spacing value.
  final ValueChanged<double> onBlockSpacingChanged;

  /// Document-level default line height multiplier. `null` means inherit.
  final double? defaultLineHeight;

  /// Called when the user changes the default line height.
  final ValueChanged<double?> onDefaultLineHeightChanged;

  /// Padding applied symmetrically around the document content area.
  final EdgeInsets documentPadding;

  /// Called when the user changes the document padding.
  final ValueChanged<EdgeInsets> onDocumentPaddingChanged;

  /// Whether the line number gutter is shown.
  ///
  /// Only used when [onShowLineNumbersChanged] is non-null.
  final bool showLineNumbers;

  /// Called when the user toggles the line number visibility switch.
  ///
  /// When `null`, the entire Line Numbers section is hidden.
  final ValueChanged<bool>? onShowLineNumbersChanged;

  /// Vertical alignment of line number labels within their block row.
  final LineNumberAlignment? lineNumberAlignment;

  /// Called when the user taps a line number alignment button.
  ///
  /// Only relevant when [showLineNumbers] is `true`.
  final ValueChanged<LineNumberAlignment>? onLineNumberAlignmentChanged;

  /// Font family for line number labels. `null` inherits from the document.
  final String? lineNumberFontFamily;

  /// Called when the user selects a line number font family.
  final ValueChanged<String?>? onLineNumberFontFamilyChanged;

  /// Font size for line number labels, in logical pixels. `null` inherits.
  final double? lineNumberFontSize;

  /// Called when the user selects a line number font size.
  final ValueChanged<double?>? onLineNumberFontSizeChanged;

  /// Text color for line number labels as an ARGB 32-bit integer.
  /// `null` inherits from the document.
  final int? lineNumberColor;

  /// Called when the user selects a line number text color.
  final ValueChanged<int?>? onLineNumberColorChanged;

  /// Gutter background color as an ARGB 32-bit integer.
  /// `null` means transparent.
  final int? lineNumberBackgroundColor;

  /// Called when the user selects a gutter background color.
  final ValueChanged<int?>? onLineNumberBackgroundColorChanged;

  /// The preferred width of the panel. Defaults to `280.0`.
  ///
  /// Overridden by [PropertyPanelThemeData.width] when a [PropertyPanelTheme]
  /// ancestor is present.
  final double width;

  /// Color presets for the line number color pickers.
  ///
  /// Keys are ARGB 32-bit integer values; values are display labels.
  final Map<int, String> colorPresets;

  /// Block spacing dropdown options: value → label.
  static const List<(double, String)> _blockSpacingOptions = [
    (0.0, 'Single'),
    (12.0, '1.5 lines'),
    (24.0, 'Double'),
  ];

  /// Default line height dropdown options.
  static const List<(double?, String)> _lineHeightOptions = [
    (null, 'Single'),
    (1.15, '1.15'),
    (1.5, '1.5 lines'),
    (2.0, 'Double'),
  ];

  /// Font family options for line number labels.
  static const List<(String?, String)> _fontFamilyOptions = [
    (null, 'Default'),
    ('Georgia', 'Serif'),
    ('Courier New', 'Mono'),
    ('Comic Sans MS', 'Casual'),
  ];

  /// Font size options for line number labels.
  static const List<(double?, String)> _fontSizeOptions = [
    (null, 'Default'),
    (12.0, '12'),
    (14.0, '14'),
    (16.0, '16'),
    (18.0, '18'),
    (24.0, '24'),
    (32.0, '32'),
  ];

  /// Default color presets for line number color pickers.
  static const Map<int, String> _defaultColorPresets = {
    0xFFFF0000: 'Red',
    0xFF0000FF: 'Blue',
    0xFF00AA00: 'Green',
    0xFFFF8800: 'Orange',
    0xFF800080: 'Purple',
    0xFF888888: 'Grey',
  };

  /// Returns the effective panel width, preferring [PropertyPanelThemeData.width]
  /// when present.
  double _effectiveWidth(PropertyPanelThemeData? themeData) {
    return themeData?.width ?? width;
  }

  @override
  Widget build(BuildContext context) {
    final panelTheme = PropertyPanelTheme.maybeOf(context);
    final resolvedWidth = _effectiveWidth(panelTheme);

    return SizedBox(
      width: resolvedWidth,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _buildContent(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    return [
      Text('Document Settings', style: Theme.of(context).textTheme.titleSmall),
      PropertySection(
        label: 'Block Spacing',
        child: _buildBlockSpacingDropdown(context),
      ),
      PropertySection(
        label: 'Default Line Height',
        child: _buildLineHeightDropdown(context),
      ),
      PropertySection(
        label: 'Document Padding',
        child: _buildPaddingSliders(context),
      ),
      if (onShowLineNumbersChanged != null)
        PropertySection(
          label: 'Line Numbers',
          child: _buildLineNumbersSection(context),
        ),
    ];
  }

  Widget _buildBlockSpacingDropdown(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<double>(
        value: blockSpacing,
        isExpanded: true,
        isDense: true,
        style: Theme.of(context).textTheme.bodySmall,
        onChanged: (value) {
          if (value != null) onBlockSpacingChanged(value);
        },
        items: [
          for (final (value, label) in _blockSpacingOptions)
            DropdownMenuItem<double>(value: value, child: Text(label)),
        ],
      ),
    );
  }

  Widget _buildLineHeightDropdown(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<double?>(
        value: defaultLineHeight,
        isExpanded: true,
        isDense: true,
        style: Theme.of(context).textTheme.bodySmall,
        onChanged: onDefaultLineHeightChanged,
        items: [
          for (final (value, label) in _lineHeightOptions)
            DropdownMenuItem<double?>(value: value, child: Text(label)),
        ],
      ),
    );
  }

  Widget _buildPaddingSliders(BuildContext context) {
    final h = documentPadding.left;
    final v = documentPadding.top;

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                'H: ${h.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: Slider(
                value: h,
                min: 0,
                max: 80,
                divisions: 8,
                label: h.toStringAsFixed(0),
                onChanged: (value) => onDocumentPaddingChanged(
                  EdgeInsets.symmetric(horizontal: value, vertical: v),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                'V: ${v.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: Slider(
                value: v,
                min: 0,
                max: 80,
                divisions: 8,
                label: v.toStringAsFixed(0),
                onChanged: (value) => onDocumentPaddingChanged(
                  EdgeInsets.symmetric(horizontal: h, vertical: value),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLineNumbersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Show line numbers',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Switch(
              value: showLineNumbers,
              onChanged: onShowLineNumbersChanged,
            ),
          ],
        ),
        if (showLineNumbers) ..._buildLineNumberDetails(context),
      ],
    );
  }

  List<Widget> _buildLineNumberDetails(BuildContext context) {
    return [
      const SizedBox(height: 8),
      Text('Vertical Alignment', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 4),
      _buildAlignmentButtons(context),
      const SizedBox(height: 8),
      Text('Font', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 4),
      _buildFontFamilyDropdown(context),
      const SizedBox(height: 8),
      Text('Size', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 4),
      _buildFontSizeDropdown(context),
      const SizedBox(height: 8),
      Text('Color', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 4),
      _buildColorPickers(),
    ];
  }

  Widget _buildAlignmentButtons(BuildContext context) {
    const alignmentIcons = {
      LineNumberAlignment.top: (Icons.vertical_align_top, 'top'),
      LineNumberAlignment.middle: (Icons.vertical_align_center, 'middle'),
      LineNumberAlignment.bottom: (Icons.vertical_align_bottom, 'bottom'),
    };
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (final entry in alignmentIcons.entries)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(entry.value.$1, size: 20),
              isSelected: lineNumberAlignment == entry.key,
              style: IconButton.styleFrom(
                backgroundColor:
                    lineNumberAlignment == entry.key ? colorScheme.primaryContainer : null,
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
              tooltip: entry.value.$2,
              onPressed: onLineNumberAlignmentChanged != null
                  ? () => onLineNumberAlignmentChanged!(entry.key)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildFontFamilyDropdown(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: lineNumberFontFamily,
        isExpanded: true,
        isDense: true,
        style: Theme.of(context).textTheme.bodySmall,
        onChanged: onLineNumberFontFamilyChanged,
        items: [
          for (final (value, label) in _fontFamilyOptions)
            DropdownMenuItem<String?>(value: value, child: Text(label)),
        ],
      ),
    );
  }

  Widget _buildFontSizeDropdown(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<double?>(
        value: lineNumberFontSize,
        isExpanded: true,
        isDense: true,
        style: Theme.of(context).textTheme.bodySmall,
        onChanged: onLineNumberFontSizeChanged,
        items: [
          for (final (value, label) in _fontSizeOptions)
            DropdownMenuItem<double?>(value: value, child: Text(label)),
        ],
      ),
    );
  }

  Widget _buildColorPickers() {
    return Row(
      children: [
        DocumentColorPicker(
          icon: Icons.format_color_text,
          tooltip: 'Number color',
          activeColorValue: lineNumberColor,
          presets: colorPresets,
          onSelected: onLineNumberColorChanged ?? (_) {},
          enabled: onLineNumberColorChanged != null,
        ),
        const SizedBox(width: 8),
        DocumentColorPicker(
          icon: Icons.format_color_fill,
          tooltip: 'Gutter background',
          activeColorValue: lineNumberBackgroundColor,
          presets: colorPresets,
          onSelected: onLineNumberBackgroundColorChanged ?? (_) {},
          enabled: onLineNumberBackgroundColorChanged != null,
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('blockSpacing', blockSpacing));
    properties.add(
      ObjectFlagProperty<ValueChanged<double>>.has('onBlockSpacingChanged', onBlockSpacingChanged),
    );
    properties.add(DoubleProperty('defaultLineHeight', defaultLineHeight, defaultValue: null));
    properties.add(
      ObjectFlagProperty<ValueChanged<double?>>.has(
        'onDefaultLineHeightChanged',
        onDefaultLineHeightChanged,
      ),
    );
    properties.add(DiagnosticsProperty<EdgeInsets>('documentPadding', documentPadding));
    properties.add(
      ObjectFlagProperty<ValueChanged<EdgeInsets>>.has(
        'onDocumentPaddingChanged',
        onDocumentPaddingChanged,
      ),
    );
    properties.add(FlagProperty('showLineNumbers', value: showLineNumbers, ifTrue: 'showing'));
    properties.add(
      ObjectFlagProperty<ValueChanged<bool>?>.has(
        'onShowLineNumbersChanged',
        onShowLineNumbersChanged,
      ),
    );
    properties.add(
      EnumProperty<LineNumberAlignment?>('lineNumberAlignment', lineNumberAlignment,
          defaultValue: null),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<LineNumberAlignment>?>.has(
        'onLineNumberAlignmentChanged',
        onLineNumberAlignmentChanged,
      ),
    );
    properties
        .add(StringProperty('lineNumberFontFamily', lineNumberFontFamily, defaultValue: null));
    properties.add(
      ObjectFlagProperty<ValueChanged<String?>?>.has(
        'onLineNumberFontFamilyChanged',
        onLineNumberFontFamilyChanged,
      ),
    );
    properties.add(DoubleProperty('lineNumberFontSize', lineNumberFontSize, defaultValue: null));
    properties.add(
      ObjectFlagProperty<ValueChanged<double?>?>.has(
        'onLineNumberFontSizeChanged',
        onLineNumberFontSizeChanged,
      ),
    );
    properties.add(IntProperty('lineNumberColor', lineNumberColor, defaultValue: null));
    properties.add(
      ObjectFlagProperty<ValueChanged<int?>?>.has(
          'onLineNumberColorChanged', onLineNumberColorChanged),
    );
    properties.add(
      IntProperty('lineNumberBackgroundColor', lineNumberBackgroundColor, defaultValue: null),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<int?>?>.has(
        'onLineNumberBackgroundColorChanged',
        onLineNumberBackgroundColorChanged,
      ),
    );
    properties.add(DoubleProperty('width', width, defaultValue: 280.0));
    properties.add(DiagnosticsProperty<Map<int, String>>('colorPresets', colorPresets));
  }
}
