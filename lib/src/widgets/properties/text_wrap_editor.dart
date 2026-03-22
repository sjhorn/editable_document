/// Editor widget for [TextWrapMode] with segmented toggle buttons.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/text_wrap_mode.dart';

// ---------------------------------------------------------------------------
// TextWrapEditor
// ---------------------------------------------------------------------------

/// Editor for [TextWrapMode] with segmented toggle buttons.
///
/// Renders four [IconButton]s for none, wrap, behindText, and inFrontOfText
/// modes. The active button is highlighted using [ColorScheme.primaryContainer].
///
/// ```dart
/// TextWrapEditor(
///   value: TextWrapMode.none,
///   onChanged: (mode) => updateTextWrap(mode),
/// )
/// ```
class TextWrapEditor extends StatelessWidget {
  /// Creates a [TextWrapEditor].
  const TextWrapEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// The currently active text wrap mode.
  final TextWrapMode value;

  /// Called when the user selects a new wrap mode.
  final ValueChanged<TextWrapMode> onChanged;

  /// Whether the editor is interactive. When `false`, all buttons are disabled.
  final bool enabled;

  static const _modes = <TextWrapMode, IconData>{
    TextWrapMode.none: Icons.close,
    TextWrapMode.wrap: Icons.wrap_text,
    TextWrapMode.behindText: Icons.flip_to_back,
    TextWrapMode.inFrontOfText: Icons.flip_to_front,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final entry in _modes.entries)
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
    properties.add(EnumProperty<TextWrapMode>('value', value));
    properties.add(
      ObjectFlagProperty<ValueChanged<TextWrapMode>>.has('onChanged', onChanged),
    );
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
  }
}
