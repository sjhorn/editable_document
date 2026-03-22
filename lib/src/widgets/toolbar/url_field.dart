/// A text field for editing URLs.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// UrlField
// ---------------------------------------------------------------------------

/// A text field for editing URLs, with an `https://...` placeholder.
///
/// Submits on Enter key. Only calls [onChanged] when the submitted text is
/// non-empty after trimming whitespace.
///
/// ```dart
/// UrlField(
///   value: imageUrl,
///   onChanged: (url) => setState(() => imageUrl = url),
/// )
/// ```
class UrlField extends StatefulWidget {
  /// Creates a [UrlField].
  const UrlField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// The current URL value. Displayed as the field's text.
  final String value;

  /// Called with the new URL when the user submits a non-empty value.
  final ValueChanged<String> onChanged;

  @override
  State<UrlField> createState() => _UrlFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('value', value));
    properties.add(ObjectFlagProperty<ValueChanged<String>>.has('onChanged', onChanged));
  }
}

class _UrlFieldState extends State<UrlField> {
  late final TextEditingController _textController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(UrlField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.value != oldWidget.value) {
      _textController.text = widget.value;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Focus(
        onFocusChange: (hasFocus) => _isEditing = hasFocus,
        child: TextField(
          controller: _textController,
          decoration: const InputDecoration(
            hintText: 'https://...',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(),
          ),
          style: Theme.of(context).textTheme.bodySmall,
          onSubmitted: (text) {
            final trimmed = text.trim();
            if (trimmed.isNotEmpty) widget.onChanged(trimmed);
          },
        ),
      ),
    );
  }
}
