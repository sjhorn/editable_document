/// Editor widget for block spacing (space before and space after).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../toolbar/dimension_field.dart';

// ---------------------------------------------------------------------------
// SpacingEditor
// ---------------------------------------------------------------------------

/// Editor for block spacing (space before and space after).
///
/// Renders two [DimensionField]s side by side, labelled "Before" and "After".
///
/// ```dart
/// SpacingEditor(
///   spaceBefore: node.spaceBefore,
///   spaceAfter: node.spaceAfter,
///   onSpaceBeforeChanged: (v) => updateSpaceBefore(v),
///   onSpaceAfterChanged: (v) => updateSpaceAfter(v),
/// )
/// ```
class SpacingEditor extends StatelessWidget {
  /// Creates a [SpacingEditor].
  const SpacingEditor({
    super.key,
    required this.spaceBefore,
    required this.spaceAfter,
    required this.onSpaceBeforeChanged,
    required this.onSpaceAfterChanged,
    this.enabled = true,
  });

  /// The current space-before value in logical pixels, or `null` for default.
  final double? spaceBefore;

  /// The current space-after value in logical pixels, or `null` for default.
  final double? spaceAfter;

  /// Called when the user changes the space-before value.
  final ValueChanged<double?> onSpaceBeforeChanged;

  /// Called when the user changes the space-after value.
  final ValueChanged<double?> onSpaceAfterChanged;

  /// Whether the editor is interactive. When `false`, the fields are disabled.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Before', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              DimensionField(
                value: spaceBefore,
                onChanged: enabled ? onSpaceBeforeChanged : (_) {},
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('After', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              DimensionField(
                value: spaceAfter,
                onChanged: enabled ? onSpaceAfterChanged : (_) {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('spaceBefore', spaceBefore, defaultValue: null));
    properties.add(DoubleProperty('spaceAfter', spaceAfter, defaultValue: null));
    properties.add(
      ObjectFlagProperty<ValueChanged<double?>>.has('onSpaceBeforeChanged', onSpaceBeforeChanged),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<double?>>.has('onSpaceAfterChanged', onSpaceAfterChanged),
    );
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
  }
}
