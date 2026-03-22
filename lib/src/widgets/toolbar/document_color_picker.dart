/// A toolbar button that opens a popup menu of color presets.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/document_toolbar_theme.dart';

// ---------------------------------------------------------------------------
// _ColorChoice — sentinel wrapper so PopupMenuButton fires for null values
// ---------------------------------------------------------------------------

/// Internal wrapper that lets [PopupMenuButton] distinguish "selected null"
/// (clear color) from "dismissed without selection".
///
/// [PopupMenuButton] does not invoke [PopupMenuButton.onSelected] when the
/// route returns `null` because it treats `null` as dismissal.  Wrapping the
/// value avoids that ambiguity.
class _ColorChoice {
  const _ColorChoice(this.value);

  /// `null` means "Default / clear the color".
  final int? value;
}

// ---------------------------------------------------------------------------
// DocumentColorPicker
// ---------------------------------------------------------------------------

/// A toolbar button that opens a popup menu of color presets.
///
/// Shows a colored underline indicator for the [activeColorValue]. When
/// [enabled] is `false`, the popup does not open and the icon is dimmed.
///
/// The popup contains a "Default" entry (which calls [onSelected] with `null`)
/// followed by one entry per [presets] entry, each showing a color swatch and
/// the preset label.
///
/// Uses [DocumentToolbarTheme] for sizing when available.
///
/// ```dart
/// DocumentColorPicker(
///   icon: Icons.format_color_text,
///   tooltip: 'Text color',
///   activeColorValue: currentTextColor,
///   presets: defaultColorPresets,
///   onSelected: (value) {
///     if (value == null) clearTextColor();
///     else applyTextColor(value);
///   },
/// )
/// ```
class DocumentColorPicker extends StatelessWidget {
  /// Creates a [DocumentColorPicker].
  const DocumentColorPicker({
    super.key,
    required this.icon,
    required this.tooltip,
    this.activeColorValue,
    this.enabled = true,
    required this.presets,
    required this.onSelected,
  });

  /// The icon to display in the button.
  final IconData icon;

  /// Tooltip message shown on hover / long-press.
  final String tooltip;

  /// The currently active color as an ARGB 32-bit integer, or `null` for the
  /// default (no color applied).
  final int? activeColorValue;

  /// Whether the button is enabled and opens the popup on tap.
  final bool enabled;

  /// Map of ARGB 32-bit color values to their display labels.
  ///
  /// Shown as colored swatch + label rows in the popup menu.
  final Map<int, String> presets;

  /// Called when a color is selected.
  ///
  /// [value] is the ARGB color value, or `null` when the user chose "Default"
  /// (i.e., "clear the color").
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = DocumentToolbarTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final iconSize = theme.iconSize ?? 18.0;
    final buttonSize = theme.buttonSize ?? 32.0;

    return Tooltip(
      message: tooltip,
      child: PopupMenuButton<_ColorChoice>(
        enabled: enabled,
        offset: const Offset(0, 36),
        onSelected: (choice) => onSelected(choice.value),
        itemBuilder: _buildItems,
        child: SizedBox(
          height: buttonSize,
          width: buttonSize,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: enabled
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              Container(
                height: 3,
                width: iconSize,
                color: activeColorValue != null
                    ? Color(activeColorValue!)
                    : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<_ColorChoice>> _buildItems(BuildContext context) {
    return [
      const PopupMenuItem<_ColorChoice>(
        value: _ColorChoice(null),
        child: Text('Default'),
      ),
      for (final entry in presets.entries)
        PopupMenuItem<_ColorChoice>(
          value: _ColorChoice(entry.key),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Color(entry.key),
                  border: Border.all(color: Colors.black26, width: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(entry.value),
            ],
          ),
        ),
    ];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(StringProperty('tooltip', tooltip));
    properties.add(IntProperty('activeColorValue', activeColorValue, defaultValue: null));
    properties.add(FlagProperty('enabled', value: enabled, ifTrue: 'enabled'));
    properties.add(DiagnosticsProperty<Map<int, String>>('presets', presets));
    properties.add(ObjectFlagProperty<ValueChanged<int?>>.has('onSelected', onSelected));
  }
}
