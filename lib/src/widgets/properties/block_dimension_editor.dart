/// Editor widget for block width and height with px/% unit toggles.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/block_dimension.dart';
import '../toolbar/dimension_field.dart';

// ---------------------------------------------------------------------------
// BlockDimensionEditor
// ---------------------------------------------------------------------------

/// Editor for block width and height with px/% unit toggles.
///
/// Renders two [DimensionField]s separated by a "×" divider. Each field has
/// an adjacent [ToggleButtons] for switching between px and % units.
///
/// When the user clears a field, [onWidthChanged] or [onHeightChanged] is
/// called with `null`. When a value is entered, the callback receives a
/// [PixelDimension] or [PercentDimension] depending on the current toggle.
///
/// ```dart
/// BlockDimensionEditor(
///   width: node.width,
///   height: node.height,
///   onWidthChanged: (w) => updateWidth(w),
///   onHeightChanged: (h) => updateHeight(h),
/// )
/// ```
class BlockDimensionEditor extends StatelessWidget {
  /// Creates a [BlockDimensionEditor].
  const BlockDimensionEditor({
    super.key,
    required this.width,
    required this.height,
    required this.onWidthChanged,
    required this.onHeightChanged,
    this.enabled = true,
  });

  /// The current width dimension, or `null` for intrinsic / auto.
  final BlockDimension? width;

  /// The current height dimension, or `null` for intrinsic / auto.
  final BlockDimension? height;

  /// Called when the user changes the width.
  final ValueChanged<BlockDimension?> onWidthChanged;

  /// Called when the user changes the height.
  final ValueChanged<BlockDimension?> onHeightChanged;

  /// Whether the editor is interactive. When `false`, all controls are disabled.
  final bool enabled;

  bool get _widthIsPercent => width is PercentDimension;
  bool get _heightIsPercent => height is PercentDimension;

  double? get _widthDisplay => switch (width) {
        PixelDimension(:final value) => value,
        PercentDimension(:final value) => value * 100,
        null => null,
      };

  double? get _heightDisplay => switch (height) {
        PixelDimension(:final value) => value,
        PercentDimension(:final value) => value * 100,
        null => null,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DimensionField(
            value: _widthDisplay,
            onChanged: enabled ? _onWidthValueChanged : (_) {},
          ),
        ),
        _UnitToggle(
          isPercent: _widthIsPercent,
          onChanged: enabled ? _onWidthUnitChanged : (_) {},
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('\u00d7'), // ×
        ),
        Expanded(
          child: DimensionField(
            value: _heightDisplay,
            onChanged: enabled ? _onHeightValueChanged : (_) {},
          ),
        ),
        _UnitToggle(
          isPercent: _heightIsPercent,
          onChanged: enabled ? _onHeightUnitChanged : (_) {},
        ),
      ],
    );
  }

  void _onWidthValueChanged(double? value) {
    if (value == null) {
      onWidthChanged(null);
    } else {
      onWidthChanged(
        _widthIsPercent ? BlockDimension.percent(value / 100) : BlockDimension.pixels(value),
      );
    }
  }

  void _onHeightValueChanged(double? value) {
    if (value == null) {
      onHeightChanged(null);
    } else {
      onHeightChanged(
        _heightIsPercent ? BlockDimension.percent(value / 100) : BlockDimension.pixels(value),
      );
    }
  }

  void _onWidthUnitChanged(bool isPercent) {
    if (width == null) return;
    final newDim = switch (width!) {
      PixelDimension(:final value) when isPercent => BlockDimension.percent(value / 100),
      PercentDimension(:final value) when !isPercent => BlockDimension.pixels(value * 100),
      _ => width!,
    };
    onWidthChanged(newDim);
  }

  void _onHeightUnitChanged(bool isPercent) {
    if (height == null) return;
    final newDim = switch (height!) {
      PixelDimension(:final value) when isPercent => BlockDimension.percent(value / 100),
      PercentDimension(:final value) when !isPercent => BlockDimension.pixels(value * 100),
      _ => height!,
    };
    onHeightChanged(newDim);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BlockDimension?>('width', width, defaultValue: null));
    properties.add(DiagnosticsProperty<BlockDimension?>('height', height, defaultValue: null));
    properties.add(
      ObjectFlagProperty<ValueChanged<BlockDimension?>>.has('onWidthChanged', onWidthChanged),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<BlockDimension?>>.has('onHeightChanged', onHeightChanged),
    );
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
  }
}

// ---------------------------------------------------------------------------
// _UnitToggle (private helper)
// ---------------------------------------------------------------------------

/// Compact px / % toggle buttons used next to each [DimensionField].
class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.isPercent,
    required this.onChanged,
  });

  // ignore: diagnostic_describe_all_properties
  final bool isPercent;
  // ignore: diagnostic_describe_all_properties
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: ToggleButtons(
        isSelected: [!isPercent, isPercent],
        onPressed: (index) => onChanged(index == 1),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        textStyle: const TextStyle(fontSize: 11),
        borderRadius: BorderRadius.circular(4),
        children: const [Text('px'), Text('%')],
      ),
    );
  }
}
