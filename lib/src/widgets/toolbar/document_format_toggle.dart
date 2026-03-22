/// A compact toggle button for toolbar formatting actions.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/document_toolbar_theme.dart';

// ---------------------------------------------------------------------------
// DocumentFormatToggle
// ---------------------------------------------------------------------------

/// A compact toggle button for toolbar formatting actions.
///
/// Displays an [icon] with an active/inactive background based on [isActive].
/// Uses [DocumentToolbarTheme] for sizing and colors when available,
/// falling back to the ambient Material theme defaults.
///
/// ```dart
/// DocumentFormatToggle(
///   icon: Icons.format_bold,
///   tooltip: 'Bold',
///   isActive: isBoldActive,
///   onPressed: hasSelection ? toggleBold : null,
/// )
/// ```
class DocumentFormatToggle extends StatelessWidget {
  /// Creates a [DocumentFormatToggle].
  const DocumentFormatToggle({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  /// The icon to display inside the toggle.
  final IconData icon;

  /// Tooltip message shown on long-press / hover.
  final String tooltip;

  /// Whether the toggle is in the active (pressed) state.
  ///
  /// Active toggles display a [DocumentToolbarThemeData.activeColor] background
  /// (or [ColorScheme.primaryContainer] when no theme is provided).
  final bool isActive;

  /// Callback invoked when the toggle is tapped.
  ///
  /// When `null` the toggle is rendered in a disabled state.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DocumentToolbarTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final iconSize = theme.iconSize ?? 18.0;
    final buttonSize = theme.buttonSize ?? 32.0;
    final activeBackground = theme.activeColor ?? colorScheme.primaryContainer;
    final activeIconColor = theme.activeIconColor ?? colorScheme.onPrimaryContainer;
    final disabledColor = theme.disabledColor ?? Theme.of(context).disabledColor;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? activeBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onPressed,
          child: SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: Icon(
              icon,
              size: iconSize,
              color: onPressed == null
                  ? disabledColor
                  : isActive
                      ? activeIconColor
                      : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(StringProperty('tooltip', tooltip));
    properties.add(FlagProperty('isActive', value: isActive, ifTrue: 'active'));
    properties.add(ObjectFlagProperty<VoidCallback?>.has('onPressed', onPressed));
  }
}
