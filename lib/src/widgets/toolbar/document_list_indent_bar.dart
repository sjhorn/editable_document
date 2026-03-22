/// List indent/unindent toolbar bar.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/document_editing_controller.dart';
import '../../model/edit_request.dart';
import '../../model/list_item_node.dart';

// ---------------------------------------------------------------------------
// DocumentListIndentBar
// ---------------------------------------------------------------------------

/// A toolbar bar for indenting and unindenting list items.
///
/// Shows two icon buttons:
///   - Indent (enabled when the cursor is on a [ListItemNode])
///   - Unindent (enabled when the cursor is on a [ListItemNode] with
///     [ListItemNode.indent] > 0)
///
/// The bar listens to [controller] and rebuilds whenever the selection changes.
/// Indentation changes are submitted via [requestHandler] as
/// [IndentListItemRequest] / [UnindentListItemRequest].
///
/// ```dart
/// DocumentListIndentBar(
///   controller: controller,
///   requestHandler: editor.submit,
/// )
/// ```
class DocumentListIndentBar extends StatelessWidget {
  /// Creates a [DocumentListIndentBar].
  const DocumentListIndentBar({
    super.key,
    required this.controller,
    required this.requestHandler,
  });

  /// The document editing controller to read selection state from.
  final DocumentEditingController controller;

  /// Called with each [EditRequest] produced by the bar.
  final void Function(EditRequest) requestHandler;

  static final _buttonStyle = IconButton.styleFrom(
    minimumSize: const Size(32, 32),
    padding: const EdgeInsets.all(4),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sel = controller.selection;
        final node = sel != null ? controller.document.nodeById(sel.extent.nodeId) : null;
        final listNode = node is ListItemNode ? node : null;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.format_indent_increase, size: 18),
              onPressed: listNode != null
                  ? () => requestHandler(IndentListItemRequest(nodeId: listNode.id))
                  : null,
              tooltip: 'Indent',
              style: _buttonStyle,
            ),
            IconButton(
              icon: const Icon(Icons.format_indent_decrease, size: 18),
              onPressed: listNode != null && listNode.indent > 0
                  ? () => requestHandler(UnindentListItemRequest(nodeId: listNode.id))
                  : null,
              tooltip: 'Unindent',
              style: _buttonStyle,
            ),
          ],
        );
      },
    );
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
