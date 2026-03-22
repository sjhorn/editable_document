/// Editor widget for [BlockAlignment] with segmented toggle buttons.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/block_alignment.dart';

// ---------------------------------------------------------------------------
// BlockAlignmentEditor
// ---------------------------------------------------------------------------

/// Editor for [BlockAlignment] with segmented toggle buttons.
///
/// Renders four [IconButton]s for start, center, end, and stretch alignment.
/// The active button is highlighted using [ColorScheme.primaryContainer].
///
/// ```dart
/// BlockAlignmentEditor(
///   value: BlockAlignment.center,
///   onChanged: (align) => updateAlignment(align),
/// )
/// ```
class BlockAlignmentEditor extends StatelessWidget {
  /// Creates a [BlockAlignmentEditor].
  const BlockAlignmentEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// The currently active block alignment.
  final BlockAlignment value;

  /// Called when the user selects a new alignment.
  final ValueChanged<BlockAlignment> onChanged;

  /// Whether the editor is interactive. When `false`, all buttons are disabled.
  final bool enabled;

  static const _alignments = <BlockAlignment, IconData>{
    BlockAlignment.start: Icons.align_horizontal_left,
    BlockAlignment.center: Icons.align_horizontal_center,
    BlockAlignment.end: Icons.align_horizontal_right,
    BlockAlignment.stretch: Icons.expand,
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
              icon: entry.key == BlockAlignment.stretch
                  ? const RotatedBox(
                      quarterTurns: 1,
                      child: Icon(Icons.expand, size: 20),
                    )
                  : Icon(entry.value, size: 20),
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
    properties.add(EnumProperty<BlockAlignment>('value', value));
    properties.add(
      ObjectFlagProperty<ValueChanged<BlockAlignment>>.has('onChanged', onChanged),
    );
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
  }
}
