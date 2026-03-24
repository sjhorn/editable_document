/// Text color and background color toolbar bar.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/attribution.dart';
import '../../model/document_editing_controller.dart';
import '../../model/edit_request.dart';
import '../../model/node_position.dart';
import '../../model/text_node.dart';
import 'document_color_picker.dart';

// ---------------------------------------------------------------------------
// Default color presets
// ---------------------------------------------------------------------------

/// Default color presets for [DocumentColorBar].
///
/// Keys are ARGB 32-bit integer values; values are display labels.
const Map<int, String> defaultColorPresets = {
  0xFFFF0000: 'Red',
  0xFF0000FF: 'Blue',
  0xFF00AA00: 'Green',
  0xFFFF8800: 'Orange',
  0xFF800080: 'Purple',
  0xFF888888: 'Grey',
};

// ---------------------------------------------------------------------------
// DocumentColorBar
// ---------------------------------------------------------------------------

/// A toolbar bar for changing text color and background (highlight) color.
///
/// Shows two [DocumentColorPicker] buttons: one for foreground text color
/// ([TextColorAttribution]) and one for background/highlight color
/// ([BackgroundColorAttribution]).
///
/// Both pickers are enabled only when there is an expanded (non-collapsed)
/// selection on a [TextNode].
///
/// The bar listens to [controller] and rebuilds whenever the selection changes.
/// Color changes are submitted via [requestHandler] as [ApplyAttributionRequest]
/// / [RemoveAttributionRequest].
///
/// ```dart
/// DocumentColorBar(
///   controller: controller,
///   requestHandler: editor.submit,
/// )
/// ```
class DocumentColorBar extends StatelessWidget {
  /// Creates a [DocumentColorBar].
  const DocumentColorBar({
    super.key,
    required this.controller,
    required this.requestHandler,
    this.colorPresets = defaultColorPresets,
  });

  /// The document editing controller to read selection state from.
  final DocumentEditingController controller;

  /// Called with each [EditRequest] produced by the bar.
  final void Function(EditRequest) requestHandler;

  /// Color presets shown in both color pickers.
  ///
  /// Keys are ARGB 32-bit integer values; values are display labels.
  final Map<int, String> colorPresets;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.document.changes]),
      builder: (context, _) {
        final sel = controller.selection;
        final hasExpanded = sel != null && !sel.isCollapsed;
        final activeTextColor = _getAttributionValue<TextColorAttribution>()?.colorValue;
        final activeBgColor = _getAttributionValue<BackgroundColorAttribution>()?.colorValue;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DocumentColorPicker(
              icon: Icons.format_color_text,
              tooltip: 'Text color',
              activeColorValue: activeTextColor,
              enabled: hasExpanded,
              presets: colorPresets,
              onSelected: (value) {
                if (value == null) {
                  _clearAttribution<TextColorAttribution>();
                } else {
                  _applyAttribution(TextColorAttribution(value));
                }
              },
            ),
            DocumentColorPicker(
              icon: Icons.format_color_fill,
              tooltip: 'Background color',
              activeColorValue: activeBgColor,
              enabled: hasExpanded,
              presets: colorPresets,
              onSelected: (value) {
                if (value == null) {
                  _clearAttribution<BackgroundColorAttribution>();
                } else {
                  _applyAttribution(BackgroundColorAttribution(value));
                }
              },
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
    properties.add(
      DiagnosticsProperty<Map<int, String>>('colorPresets', colorPresets),
    );
  }
}
