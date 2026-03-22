/// Editor widget for [BlockBorder] properties (style, width, color).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/block_border.dart';
import '../toolbar/border_color_button.dart';
import '../toolbar/dimension_field.dart';

// ---------------------------------------------------------------------------
// BlockBorderEditor
// ---------------------------------------------------------------------------

/// Editor for [BlockBorder] properties (style, width, color).
///
/// Shows a style dropdown (None, Solid, Dashed, Dotted). When a style other
/// than None is selected, also shows a width [DimensionField] and a row of
/// color swatch [BorderColorButton]s.
///
/// When the style is set to None, [onChanged] is called with `null`.
/// Otherwise a new [BlockBorder] is constructed and passed to [onChanged].
///
/// ```dart
/// BlockBorderEditor(
///   border: node.border,
///   onChanged: (border) => updateBorder(border),
/// )
/// ```
class BlockBorderEditor extends StatelessWidget {
  /// Creates a [BlockBorderEditor].
  const BlockBorderEditor({
    super.key,
    required this.border,
    required this.onChanged,
    this.enabled = true,
    this.colorPresets,
  });

  /// The current border, or `null` for no border.
  final BlockBorder? border;

  /// Called when the border changes. Receives `null` when no border is set.
  final ValueChanged<BlockBorder?> onChanged;

  /// Whether the editor is interactive. When `false`, all controls are disabled.
  final bool enabled;

  /// Optional map of ARGB color values to display labels for the color row.
  ///
  /// When `null`, a built-in set of presets is used.
  final Map<int, String>? colorPresets;

  static const _defaultColorPresets = <String, Color?>{
    'Default': null,
    'Red': Color(0xFFE53935),
    'Blue': Color(0xFF2196F3),
    'Green': Color(0xFF4CAF50),
    'Orange': Color(0xFFFF9800),
    'Purple': Color(0xFF9C27B0),
    'Grey': Color(0xFF757575),
  };

  Map<String, Color?> get _colorMap {
    if (colorPresets == null) return _defaultColorPresets;
    return {
      'Default': null,
      for (final entry in colorPresets!.entries) entry.value: Color(entry.key),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Style', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        DropdownButtonHideUnderline(
          child: DropdownButton<BlockBorderStyle?>(
            value: border?.style,
            isExpanded: true,
            isDense: true,
            style: Theme.of(context).textTheme.bodySmall,
            onChanged: enabled ? _onStyleChanged : null,
            items: const [
              DropdownMenuItem(value: null, child: Text('None')),
              DropdownMenuItem(value: BlockBorderStyle.solid, child: Text('Solid')),
              DropdownMenuItem(value: BlockBorderStyle.dashed, child: Text('Dashed')),
              DropdownMenuItem(value: BlockBorderStyle.dotted, child: Text('Dotted')),
            ],
          ),
        ),
        if (border != null) ...[
          const SizedBox(height: 6),
          Text('Width', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          DimensionField(
            value: border!.width,
            onChanged: enabled ? _onWidthChanged : (_) {},
          ),
          const SizedBox(height: 6),
          Text('Color', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final entry in _colorMap.entries)
                BorderColorButton(
                  color: entry.value ?? Colors.black,
                  isSelected: border!.color == entry.value,
                  onTap: enabled ? () => _onColorChanged(entry.value) : () {},
                  label: entry.key,
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _onStyleChanged(BlockBorderStyle? style) {
    if (style == null || style == BlockBorderStyle.none) {
      onChanged(null);
    } else {
      onChanged(BlockBorder(
        style: style,
        width: border?.width ?? 1.0,
        color: border?.color,
      ));
    }
  }

  void _onWidthChanged(double? width) {
    if (width == null || border == null) return;
    onChanged(BlockBorder(
      style: border!.style,
      width: width,
      color: border!.color,
    ));
  }

  void _onColorChanged(Color? color) {
    if (border == null) return;
    onChanged(BlockBorder(
      style: border!.style,
      width: border!.width,
      color: color,
    ));
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BlockBorder?>('border', border, defaultValue: null));
    properties.add(ObjectFlagProperty<ValueChanged<BlockBorder?>>.has('onChanged', onChanged));
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
    properties.add(
      DiagnosticsProperty<Map<int, String>?>('colorPresets', colorPresets, defaultValue: null),
    );
  }
}
