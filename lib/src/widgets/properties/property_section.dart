/// A labeled section widget used within property panels.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// PropertySection
// ---------------------------------------------------------------------------

/// A labeled section within a property panel.
///
/// Renders a [label] using [TextTheme.labelMedium] followed by [child].
/// Adds vertical spacing above the label so consecutive sections are
/// visually separated.
///
/// ```dart
/// PropertySection(
///   label: 'Text Alignment',
///   child: TextAlignmentEditor(
///     value: TextAlign.start,
///     onChanged: (v) => setState(() => align = v),
///   ),
/// )
/// ```
class PropertySection extends StatelessWidget {
  /// Creates a [PropertySection].
  const PropertySection({
    super.key,
    required this.label,
    required this.child,
  });

  /// The section heading label.
  final String label;

  /// The content widget for this section.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
  }
}
