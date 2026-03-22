/// Inline formatting toolbar bar for bold, italic, underline, etc.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/attribution.dart';
import '../../model/document_editing_controller.dart';
import '../../model/edit_request.dart';
import '../../model/node_position.dart';
import '../../model/text_node.dart';
import 'document_format_toggle.dart';

// ---------------------------------------------------------------------------
// DocumentFormattingBar
// ---------------------------------------------------------------------------

/// A toolbar bar for toggling inline text formatting.
///
/// Shows toggle buttons for bold, italic, underline, strikethrough, and
/// inline code. Each button is enabled only when there is an expanded
/// (non-collapsed) selection.
///
/// The bar listens to [controller] and rebuilds whenever the selection changes.
///
/// Formatting actions are submitted as [ApplyAttributionRequest] /
/// [RemoveAttributionRequest] via [requestHandler].
///
/// ```dart
/// DocumentFormattingBar(
///   controller: controller,
///   requestHandler: editor.submit,
/// )
/// ```
class DocumentFormattingBar extends StatelessWidget {
  /// Creates a [DocumentFormattingBar].
  const DocumentFormattingBar({
    super.key,
    required this.controller,
    required this.requestHandler,
  });

  /// The document editing controller to read selection state from.
  final DocumentEditingController controller;

  /// Called with each [EditRequest] when the user activates a button.
  final void Function(EditRequest) requestHandler;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sel = controller.selection;
        final hasExpanded = sel != null && !sel.isCollapsed;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DocumentFormatToggle(
              icon: Icons.format_bold,
              tooltip: 'Bold',
              isActive: _isActive(NamedAttribution.bold),
              onPressed: hasExpanded ? () => _toggle(NamedAttribution.bold) : null,
            ),
            DocumentFormatToggle(
              icon: Icons.format_italic,
              tooltip: 'Italic',
              isActive: _isActive(NamedAttribution.italics),
              onPressed: hasExpanded ? () => _toggle(NamedAttribution.italics) : null,
            ),
            DocumentFormatToggle(
              icon: Icons.format_underlined,
              tooltip: 'Underline',
              isActive: _isActive(NamedAttribution.underline),
              onPressed: hasExpanded ? () => _toggle(NamedAttribution.underline) : null,
            ),
            DocumentFormatToggle(
              icon: Icons.strikethrough_s,
              tooltip: 'Strikethrough',
              isActive: _isActive(NamedAttribution.strikethrough),
              onPressed: hasExpanded ? () => _toggle(NamedAttribution.strikethrough) : null,
            ),
            DocumentFormatToggle(
              icon: Icons.code,
              tooltip: 'Inline code',
              isActive: _isActive(NamedAttribution.code),
              onPressed: hasExpanded ? () => _toggle(NamedAttribution.code) : null,
            ),
          ],
        );
      },
    );
  }

  bool _isActive(Attribution attribution) {
    final sel = controller.selection;
    if (sel == null || sel.isCollapsed) return false;
    final node = controller.document.nodeById(sel.base.nodeId);
    if (node is! TextNode) return false;
    final pos = sel.base.nodePosition;
    if (pos is! TextNodePosition) return false;
    return node.text.hasAttributionAt(pos.offset, attribution);
  }

  void _toggle(Attribution attribution) {
    final sel = controller.selection;
    if (sel == null || sel.isCollapsed) return;

    final startNode = controller.document.nodeById(sel.base.nodeId);
    final isApplied = startNode is TextNode &&
        sel.base.nodePosition is TextNodePosition &&
        startNode.text.hasAttributionAt(
          (sel.base.nodePosition as TextNodePosition).offset,
          attribution,
        );

    if (isApplied) {
      requestHandler(RemoveAttributionRequest(selection: sel, attribution: attribution));
    } else {
      requestHandler(ApplyAttributionRequest(selection: sel, attribution: attribution));
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
  }
}
