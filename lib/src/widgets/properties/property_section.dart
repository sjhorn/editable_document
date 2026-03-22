/// A labeled section widget used within property panels.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/property_panel_theme.dart';

// ---------------------------------------------------------------------------
// PropertySection
// ---------------------------------------------------------------------------

/// A labeled section within a property panel.
///
/// Renders a [label] using [PropertyPanelThemeData.sectionLabelStyle] when
/// a [PropertyPanelTheme] ancestor is present, falling back to
/// [TextTheme.labelMedium]. Adds vertical spacing above the label controlled
/// by [PropertyPanelThemeData.sectionSpacing] (default `12.0`).
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
    final panelTheme = PropertyPanelTheme.maybeOf(context);
    final spacing = panelTheme?.sectionSpacing ?? 12.0;
    final labelStyle = panelTheme?.sectionLabelStyle ?? Theme.of(context).textTheme.labelMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: spacing),
        Text(label, style: labelStyle),
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
