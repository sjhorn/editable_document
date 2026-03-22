/// A numeric text field for editing dimension values (width, height, spacing).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// DimensionField
// ---------------------------------------------------------------------------

/// A numeric text field for editing dimension values (width, height, spacing).
///
/// Shows [hintText] (default `'auto'`) as a placeholder when [value] is `null`.
/// On change, parses the text as a positive [double] and calls [onChanged] with
/// the result, or `null` when the field is empty. Non-numeric and non-positive
/// values are silently ignored.
///
/// ```dart
/// DimensionField(
///   value: imageWidth,
///   onChanged: (v) => setState(() => imageWidth = v),
/// )
/// ```
class DimensionField extends StatefulWidget {
  /// Creates a [DimensionField].
  const DimensionField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = 'auto',
  });

  /// The current numeric dimension value, or `null` for "auto" / unset.
  final double? value;

  /// Called when the user changes the value.
  ///
  /// Receives the parsed [double] or `null` when the field is cleared.
  final ValueChanged<double?> onChanged;

  /// Placeholder text when [value] is `null`. Defaults to `'auto'`.
  final String hintText;

  @override
  State<DimensionField> createState() => _DimensionFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('value', value, defaultValue: null));
    properties.add(ObjectFlagProperty<ValueChanged<double?>>.has('onChanged', onChanged));
    properties.add(StringProperty('hintText', hintText, defaultValue: 'auto'));
  }
}

class _DimensionFieldState extends State<DimensionField> {
  late final TextEditingController _textController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.value != null ? widget.value!.toStringAsFixed(0) : '',
    );
  }

  @override
  void didUpdateWidget(DimensionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync from widget when not actively editing to avoid cursor jump.
    if (!_isEditing) {
      final newText = widget.value != null ? widget.value!.toStringAsFixed(0) : '';
      if (_textController.text != newText) {
        _textController.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      widget.onChanged(null);
    } else {
      final parsed = double.tryParse(trimmed);
      if (parsed != null && parsed > 0) {
        widget.onChanged(parsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Focus(
        onFocusChange: (hasFocus) => _isEditing = hasFocus,
        child: TextField(
          controller: _textController,
          decoration: InputDecoration(
            hintText: widget.hintText,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          style: Theme.of(context).textTheme.bodySmall,
          onChanged: _onChanged,
        ),
      ),
    );
  }
}
