/// Editor widget for [TextAlign] with segmented toggle buttons.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// TextAlignmentEditor
// ---------------------------------------------------------------------------

/// Editor for [TextAlign] with segmented toggle buttons.
///
/// Renders four [IconButton]s for start, center, right, and justify alignment.
/// The active button is highlighted using [ColorScheme.primaryContainer].
///
/// ```dart
/// TextAlignmentEditor(
///   value: TextAlign.start,
///   onChanged: (align) => setState(() => textAlign = align),
/// )
/// ```
class TextAlignmentEditor extends StatelessWidget {
  /// Creates a [TextAlignmentEditor].
  const TextAlignmentEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// The currently active text alignment, or `null` for none selected.
  final TextAlign? value;

  /// Called when the user selects a new alignment.
  final ValueChanged<TextAlign> onChanged;

  /// Whether the editor is interactive. When `false`, all buttons are disabled.
  final bool enabled;

  static const _alignments = <TextAlign, IconData>{
    TextAlign.start: Icons.format_align_left,
    TextAlign.center: Icons.format_align_center,
    TextAlign.right: Icons.format_align_right,
    TextAlign.justify: Icons.format_align_justify,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final entry in _alignments.entries)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(entry.value, size: 20),
              isSelected: value == entry.key,
              style: IconButton.styleFrom(
                backgroundColor: value == entry.key ? colorScheme.primaryContainer : null,
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
              tooltip: entry.key.name,
              onPressed: enabled ? () => onChanged(entry.key) : null,
            ),
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TextAlign?>('value', value, defaultValue: null));
    properties.add(ObjectFlagProperty<ValueChanged<TextAlign>>.has('onChanged', onChanged));
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
  }
}
