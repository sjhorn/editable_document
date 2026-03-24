/// Font family and size toolbar bar.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/attribution.dart';
import '../../model/document_editing_controller.dart';
import '../../model/edit_request.dart';
import '../../model/node_position.dart';
import '../../model/text_node.dart';

// ---------------------------------------------------------------------------
// DocumentFontBar
// ---------------------------------------------------------------------------

/// A toolbar bar for changing font family and font size.
///
/// Shows two dropdowns: font family and font size. Both are enabled only when
/// there is an expanded (non-collapsed) selection on a [TextNode].
///
/// The bar listens to [controller] and rebuilds whenever the selection changes.
/// Font changes are submitted via [requestHandler] as [ApplyAttributionRequest]
/// / [RemoveAttributionRequest].
///
/// ```dart
/// DocumentFontBar(
///   controller: controller,
///   requestHandler: editor.submit,
/// )
/// ```
class DocumentFontBar extends StatelessWidget {
  /// Creates a [DocumentFontBar].
  const DocumentFontBar({
    super.key,
    required this.controller,
    required this.requestHandler,
    this.fontFamilies = defaultFontFamilies,
    this.fontSizes = defaultFontSizes,
  });

  /// The document editing controller to read selection state from.
  final DocumentEditingController controller;

  /// Called with each [EditRequest] produced by the bar.
  final void Function(EditRequest) requestHandler;

  /// Map of font family values to display names.
  ///
  /// A `null` key represents "Default" (no [FontFamilyAttribution] applied).
  final Map<String?, String> fontFamilies;

  /// List of font size values.
  ///
  /// A `null` entry represents "Default" (no [FontSizeAttribution] applied).
  final List<double?> fontSizes;

  /// Default font families shown in the dropdown.
  static const Map<String?, String> defaultFontFamilies = {
    null: 'Default',
    'Georgia': 'Serif',
    'Courier New': 'Mono',
  };

  /// Default font sizes shown in the dropdown.
  static const List<double?> defaultFontSizes = [
    null,
    12.0,
    14.0,
    16.0,
    18.0,
    24.0,
    32.0,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.document.changes]),
      builder: (context, _) {
        final sel = controller.selection;
        final hasExpanded = sel != null && !sel.isCollapsed;
        final bodySmall = Theme.of(context).textTheme.bodySmall;

        final currentFontFamily = _getAttributionValue<FontFamilyAttribution>()?.fontFamily;
        final currentFontSize = _getAttributionValue<FontSizeAttribution>()?.fontSize;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 32,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: currentFontFamily,
                  hint: Text('Font', style: bodySmall),
                  style: bodySmall,
                  isDense: true,
                  isExpanded: true,
                  onChanged: hasExpanded
                      ? (value) {
                          if (value == null) {
                            _clearAttribution<FontFamilyAttribution>();
                          } else {
                            _applyAttribution(FontFamilyAttribution(value));
                          }
                        }
                      : null,
                  items: [
                    for (final entry in fontFamilies.entries)
                      DropdownMenuItem<String?>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 80,
              height: 32,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<double?>(
                  value: currentFontSize,
                  hint: Text('Size', style: bodySmall),
                  style: bodySmall,
                  isDense: true,
                  isExpanded: true,
                  onChanged: hasExpanded
                      ? (value) {
                          if (value == null) {
                            _clearAttribution<FontSizeAttribution>();
                          } else {
                            _applyAttribution(FontSizeAttribution(value));
                          }
                        }
                      : null,
                  items: [
                    for (final size in fontSizes)
                      DropdownMenuItem<double?>(
                        value: size,
                        child: Text(size == null ? 'Default' : size.toStringAsFixed(0)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  T? _getAttributionValue<T extends Attribution>() {
    final sel = controller.selection;
    if (sel == null) return null;
    final node = controller.document.nodeById(sel.base.nodeId);
    if (node is! TextNode) return null;
    final pos = sel.base.nodePosition;
    if (pos is! TextNodePosition) return null;
    return node.text.getAttributionsAt(pos.offset).whereType<T>().firstOrNull;
  }

  void _applyAttribution(Attribution newAttribution) {
    final sel = controller.selection;
    if (sel == null || sel.isCollapsed) return;

    // Remove existing attribution of the same type first.
    final node = controller.document.nodeById(sel.base.nodeId);
    if (node is TextNode) {
      final pos = sel.base.nodePosition;
      if (pos is TextNodePosition) {
        for (final attr in node.text.getAttributionsAt(pos.offset)) {
          if (attr.runtimeType == newAttribution.runtimeType) {
            requestHandler(RemoveAttributionRequest(selection: sel, attribution: attr));
          }
        }
      }
    }

    requestHandler(ApplyAttributionRequest(selection: sel, attribution: newAttribution));
  }

  void _clearAttribution<T extends Attribution>() {
    final sel = controller.selection;
    if (sel == null || sel.isCollapsed) return;
    final node = controller.document.nodeById(sel.base.nodeId);
    if (node is! TextNode) return;
    final pos = sel.base.nodePosition;
    if (pos is! TextNodePosition) return;
    for (final attr in node.text.getAttributionsAt(pos.offset).whereType<T>()) {
      requestHandler(RemoveAttributionRequest(selection: sel, attribution: attr));
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController>('controller', controller),
    );
    properties.add(
      ObjectFlagProperty<void Function(EditRequest)>.has('requestHandler', requestHandler),
    );
    properties.add(DiagnosticsProperty<Map<String?, String>>('fontFamilies', fontFamilies));
    properties.add(IterableProperty<double?>('fontSizes', fontSizes));
  }
}
