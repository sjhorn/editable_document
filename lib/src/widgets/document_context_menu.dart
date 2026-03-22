/// Default context menu builder for a document editor.
///
/// Provides [defaultDocumentContextMenuButtonItems], which returns the
/// standard Cut / Copy / Paste / Select All [ContextMenuButtonItem]s,
/// matching the convention used by Flutter's [EditableText].
library;

import 'package:flutter/material.dart';

import '../model/document_editing_controller.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/edit_request.dart';
import '../model/node_position.dart';
import '../model/text_node.dart';
import '../services/document_clipboard.dart';

// ---------------------------------------------------------------------------
// defaultDocumentContextMenuButtonItems
// ---------------------------------------------------------------------------

/// Returns the standard context-menu button items for a document editor.
///
/// Follows Flutter's [EditableText] convention:
/// - **Cut** — only when there is an expanded selection and [readOnly] is false.
/// - **Copy** — only when there is an expanded selection.
/// - **Paste** — only when [readOnly] is false.
/// - **Select All** — always present.
///
/// The [requestHandler] callback receives [EditRequest]s produced by Cut and
/// Paste (e.g. [DeleteContentRequest], [InsertTextRequest]). It may be `null`
/// when only Copy and Select All are needed (read-only scenario).
///
/// Example:
/// ```dart
/// AdaptiveTextSelectionToolbar.buttonItems(
///   anchors: TextSelectionToolbarAnchors(primaryAnchor: position),
///   buttonItems: defaultDocumentContextMenuButtonItems(
///     controller: controller,
///     clipboard: const DocumentClipboard(),
///     requestHandler: editor.submit,
///   ),
/// )
/// ```
List<ContextMenuButtonItem> defaultDocumentContextMenuButtonItems({
  required DocumentEditingController controller,
  required DocumentClipboard clipboard,
  void Function(EditRequest)? requestHandler,
  bool readOnly = false,
}) {
  final sel = controller.selection;
  final hasSelection = sel != null && !sel.isCollapsed;

  return [
    if (hasSelection && !readOnly)
      ContextMenuButtonItem(
        label: 'Cut',
        onPressed: () => _handleCut(controller, clipboard, requestHandler),
      ),
    if (hasSelection)
      ContextMenuButtonItem(
        label: 'Copy',
        onPressed: () => _handleCopy(controller, clipboard),
      ),
    if (!readOnly)
      ContextMenuButtonItem(
        label: 'Paste',
        onPressed: () => _handlePaste(controller, clipboard, requestHandler),
      ),
    ContextMenuButtonItem(
      label: 'Select All',
      onPressed: () => _handleSelectAll(controller),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

void _handleCopy(DocumentEditingController controller, DocumentClipboard clipboard) {
  final sel = controller.selection;
  if (sel == null || sel.isCollapsed) return;
  clipboard.copy(controller.document, sel);
}

void _handleCut(
  DocumentEditingController controller,
  DocumentClipboard clipboard,
  void Function(EditRequest)? requestHandler,
) {
  final sel = controller.selection;
  if (sel == null || sel.isCollapsed) return;
  clipboard.cut(controller.document, sel).then((req) {
    if (req != null) requestHandler?.call(req);
  });
}

void _handlePaste(
  DocumentEditingController controller,
  DocumentClipboard clipboard,
  void Function(EditRequest)? requestHandler,
) {
  if (requestHandler == null) return;
  final sel = controller.selection;
  if (sel != null && sel.isExpanded) {
    requestHandler(DeleteContentRequest(selection: sel));
  }
  final pasteSelection = controller.selection;
  if (pasteSelection == null) return;
  final pos = pasteSelection.extent;
  final node = controller.document.nodeById(pos.nodeId);
  if (node == null || node is! TextNode) return;
  final offset = (pos.nodePosition as TextNodePosition).offset;
  clipboard.paste(pos.nodeId, offset).then((req) {
    if (req != null) requestHandler(req);
  });
}

void _handleSelectAll(DocumentEditingController controller) {
  final document = controller.document;
  if (document.nodes.isEmpty) return;
  final first = document.nodes.first;
  final last = document.nodes.last;
  controller.setSelection(
    DocumentSelection(
      base: DocumentPosition(
        nodeId: first.id,
        nodePosition: first is TextNode
            ? const TextNodePosition(offset: 0)
            : const BinaryNodePosition.upstream(),
      ),
      extent: DocumentPosition(
        nodeId: last.id,
        nodePosition: last is TextNode
            ? TextNodePosition(offset: last.text.text.length)
            : const BinaryNodePosition.downstream(),
      ),
    ),
  );
}
