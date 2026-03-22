/// Editor widget for block indentation (left, right, first-line).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../toolbar/dimension_field.dart';

// ---------------------------------------------------------------------------
// IndentEditor
// ---------------------------------------------------------------------------

/// Editor for block indentation (left, right, first-line).
///
/// Renders two [DimensionField]s side by side for left and right indent.
/// When [showFirstLine] is `true`, also shows a first-line indent field below.
///
/// ```dart
/// IndentEditor(
///   indentLeft: node.indentLeft,
///   indentRight: node.indentRight,
///   firstLineIndent: node.firstLineIndent,
///   onIndentLeftChanged: (v) => updateLeft(v),
///   onIndentRightChanged: (v) => updateRight(v),
///   onFirstLineIndentChanged: (v) => updateFirstLine(v),
///   showFirstLine: node is! ListItemNode,
/// )
/// ```
class IndentEditor extends StatelessWidget {
  /// Creates an [IndentEditor].
  const IndentEditor({
    super.key,
    required this.indentLeft,
    required this.indentRight,
    this.firstLineIndent,
    required this.onIndentLeftChanged,
    required this.onIndentRightChanged,
    this.onFirstLineIndentChanged,
    this.showFirstLine = true,
    this.enabled = true,
  });

  /// The current left indent in logical pixels, or `null` for no indent.
  final double? indentLeft;

  /// The current right indent in logical pixels, or `null` for no indent.
  final double? indentRight;

  /// The current first-line indent in logical pixels, or `null` for no indent.
  ///
  /// Ignored when [showFirstLine] is `false`.
  final double? firstLineIndent;

  /// Called when the user changes the left indent value.
  final ValueChanged<double?> onIndentLeftChanged;

  /// Called when the user changes the right indent value.
  final ValueChanged<double?> onIndentRightChanged;

  /// Called when the user changes the first-line indent value.
  ///
  /// Only called when [showFirstLine] is `true`.
  final ValueChanged<double?>? onFirstLineIndentChanged;

  /// Whether to show the first-line indent field.
  ///
  /// Set to `false` for [ListItemNode]s which do not use first-line indent.
  final bool showFirstLine;

  /// Whether the editor is interactive. When `false`, all fields are disabled.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Left', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 2),
                  DimensionField(
                    value: indentLeft,
                    onChanged: enabled ? onIndentLeftChanged : (_) {},
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Right', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 2),
                  DimensionField(
                    value: indentRight,
                    onChanged: enabled ? onIndentRightChanged : (_) {},
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showFirstLine) ...[
          const SizedBox(height: 6),
          Text('First Line', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          DimensionField(
            value: firstLineIndent,
            onChanged: enabled ? (onFirstLineIndentChanged ?? (_) {}) : (_) {},
          ),
        ],
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('indentLeft', indentLeft, defaultValue: null));
    properties.add(DoubleProperty('indentRight', indentRight, defaultValue: null));
    properties.add(DoubleProperty('firstLineIndent', firstLineIndent, defaultValue: null));
    properties.add(
      ObjectFlagProperty<ValueChanged<double?>>.has('onIndentLeftChanged', onIndentLeftChanged),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<double?>>.has('onIndentRightChanged', onIndentRightChanged),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<double?>?>.has(
          'onFirstLineIndentChanged', onFirstLineIndentChanged),
    );
    properties.add(FlagProperty('showFirstLine', value: showFirstLine, ifFalse: 'no first line'));
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
  }
}
