/// Editor widget for image-specific properties (URL, aspect lock, file picker).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../toolbar/url_field.dart';

// ---------------------------------------------------------------------------
// ImagePropertiesEditor
// ---------------------------------------------------------------------------

/// Editor for image-specific properties (URL, aspect lock, file picker).
///
/// Shows a [UrlField] for the image URL, a "Lock Aspect" checkbox, and
/// optionally a "Choose File" button when [onPickFile] is provided.
///
/// ```dart
/// ImagePropertiesEditor(
///   imageUrl: node.imageUrl,
///   lockAspect: node.lockAspect,
///   onUrlChanged: (url) => updateUrl(url),
///   onLockAspectChanged: (v) => updateLockAspect(v),
///   onPickFile: () => pickImageFile(),
/// )
/// ```
class ImagePropertiesEditor extends StatelessWidget {
  /// Creates an [ImagePropertiesEditor].
  const ImagePropertiesEditor({
    super.key,
    required this.imageUrl,
    required this.lockAspect,
    required this.onUrlChanged,
    required this.onLockAspectChanged,
    this.onPickFile,
    this.enabled = true,
  });

  /// The current image URL displayed in the URL field.
  final String imageUrl;

  /// Whether the aspect ratio is locked during resize.
  final bool lockAspect;

  /// Called when the user submits a new URL.
  final ValueChanged<String> onUrlChanged;

  /// Called when the user toggles the lock-aspect checkbox.
  final ValueChanged<bool> onLockAspectChanged;

  /// Called when the user taps "Choose File". When `null`, the button is hidden.
  final VoidCallback? onPickFile;

  /// Whether the editor is interactive. When `false`, all controls are disabled.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Lock Aspect',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Checkbox(
              value: lockAspect,
              onChanged: enabled ? (v) => onLockAspectChanged(v ?? true) : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Image URL', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        UrlField(
          value: imageUrl,
          onChanged: enabled ? onUrlChanged : (_) {},
        ),
        if (onPickFile != null) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Choose File'),
              onPressed: enabled ? onPickFile : null,
            ),
          ),
        ],
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('imageUrl', imageUrl));
    properties.add(FlagProperty('lockAspect', value: lockAspect, ifTrue: 'locked'));
    properties.add(
      ObjectFlagProperty<ValueChanged<String>>.has('onUrlChanged', onUrlChanged),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<bool>>.has('onLockAspectChanged', onLockAspectChanged),
    );
    properties.add(ObjectFlagProperty<VoidCallback?>.has('onPickFile', onPickFile));
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
  }
}
