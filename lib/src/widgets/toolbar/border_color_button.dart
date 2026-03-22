/// A small color swatch button for border color selection.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// BorderColorButton
// ---------------------------------------------------------------------------

/// A small color swatch button for border color selection.
///
/// Shows a 24 × 24 rounded square filled with [color]. When [isSelected],
/// the border uses [ColorScheme.primary] at double width to indicate the
/// active choice.
///
/// An optional [label] is shown in a [Tooltip] on hover / long-press.
///
/// ```dart
/// BorderColorButton(
///   color: Colors.red,
///   isSelected: selectedColor == Colors.red,
///   onTap: () => setState(() => selectedColor = Colors.red),
///   label: 'Red',
/// )
/// ```
class BorderColorButton extends StatelessWidget {
  /// Creates a [BorderColorButton].
  const BorderColorButton({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.label,
  });

  /// Fill color of the swatch.
  final Color color;

  /// Whether this swatch is the currently selected color.
  ///
  /// When `true`, the border uses [ColorScheme.primary] at `2.0` width.
  final bool isSelected;

  /// Called when the user taps the swatch.
  final VoidCallback onTap;

  /// Optional tooltip label for accessibility. When `null`, no [Tooltip] is
  /// added.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final swatch = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );

    if (label != null) {
      return Tooltip(message: label!, child: swatch);
    }
    return swatch;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('color', color));
    properties.add(FlagProperty('isSelected', value: isSelected, ifTrue: 'selected'));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
    properties.add(StringProperty('label', label, defaultValue: null));
  }
}
