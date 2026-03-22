/// Editor widget for line-height multiplier with a preset dropdown.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// LineHeightEditor
// ---------------------------------------------------------------------------

/// Editor for line-height multiplier with preset dropdown.
///
/// Presents a [DropdownButton] with the provided [options]. `null` in the
/// options list is rendered as "Default". When the user picks a value,
/// [onChanged] is called with the selected [double?].
///
/// ```dart
/// LineHeightEditor(
///   value: null,
///   onChanged: (h) => setState(() => lineHeight = h),
/// )
/// ```
class LineHeightEditor extends StatelessWidget {
  /// Creates a [LineHeightEditor].
  const LineHeightEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.options = const [null, 1.0, 1.15, 1.5, 2.0],
  });

  /// The currently selected line-height multiplier, or `null` for default.
  final double? value;

  /// Called when the user selects a value.
  final ValueChanged<double?> onChanged;

  /// Whether the editor is interactive. When `false`, the dropdown is disabled.
  final bool enabled;

  /// The preset values to offer. `null` is rendered as "Default".
  final List<double?> options;

  String _label(double? v) => v == null ? 'Default' : v.toString();

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<double?>(
        value: value,
        isExpanded: true,
        isDense: true,
        style: Theme.of(context).textTheme.bodySmall,
        onChanged: enabled ? onChanged : null,
        items: [
          for (final opt in options)
            DropdownMenuItem<double?>(
              value: opt,
              child: Text(_label(opt)),
            ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('value', value, defaultValue: null));
    properties.add(ObjectFlagProperty<ValueChanged<double?>>.has('onChanged', onChanged));
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
    properties.add(IterableProperty<double?>('options', options));
  }
}
