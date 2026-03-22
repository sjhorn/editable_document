/// Text alignment toolbar bar.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/blockquote_node.dart';
import '../../model/document_editing_controller.dart';
import '../../model/edit_request.dart';
import '../../model/list_item_node.dart';
import '../../model/paragraph_node.dart';
import '../../model/text_node.dart';
import 'document_format_toggle.dart';

// ---------------------------------------------------------------------------
// DocumentAlignmentBar
// ---------------------------------------------------------------------------

/// A toolbar bar for changing text alignment of the selected block.
///
/// Shows four toggle buttons: left (start), center, right, and justify.
/// Each button is enabled only when the cursor is on an alignable [TextNode]
/// ([ParagraphNode], [ListItemNode], or [BlockquoteNode]).
///
/// The bar listens to [controller] and rebuilds whenever the selection changes.
/// Alignment changes are submitted via [requestHandler] as
/// [ChangeTextAlignRequest].
///
/// ```dart
/// DocumentAlignmentBar(
///   controller: controller,
///   requestHandler: editor.submit,
/// )
/// ```
class DocumentAlignmentBar extends StatelessWidget {
  /// Creates a [DocumentAlignmentBar].
  const DocumentAlignmentBar({
    super.key,
    required this.controller,
    required this.requestHandler,
  });

  /// The document editing controller to read selection state from.
  final DocumentEditingController controller;

  /// Called with each [EditRequest] produced by the bar.
  final void Function(EditRequest) requestHandler;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sel = controller.selection;
        final rawNode = sel != null ? controller.document.nodeById(sel.extent.nodeId) : null;
        final textNode = rawNode is TextNode ? rawNode : null;
        final currentAlign = _currentAlign(rawNode);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DocumentFormatToggle(
              icon: Icons.format_align_left,
              tooltip: 'Align left',
              isActive: currentAlign == TextAlign.start,
              onPressed: textNode != null ? () => _setAlign(textNode, TextAlign.start) : null,
            ),
            DocumentFormatToggle(
              icon: Icons.format_align_center,
              tooltip: 'Align center',
              isActive: currentAlign == TextAlign.center,
              onPressed: textNode != null ? () => _setAlign(textNode, TextAlign.center) : null,
            ),
            DocumentFormatToggle(
              icon: Icons.format_align_right,
              tooltip: 'Align right',
              isActive: currentAlign == TextAlign.right,
              onPressed: textNode != null ? () => _setAlign(textNode, TextAlign.right) : null,
            ),
            DocumentFormatToggle(
              icon: Icons.format_align_justify,
              tooltip: 'Justify',
              isActive: currentAlign == TextAlign.justify,
              onPressed: textNode != null ? () => _setAlign(textNode, TextAlign.justify) : null,
            ),
          ],
        );
      },
    );
  }

  TextAlign? _currentAlign(dynamic node) {
    if (node is ParagraphNode) return node.textAlign;
    if (node is ListItemNode) return node.textAlign;
    if (node is BlockquoteNode) return node.textAlign;
    return null;
  }

  void _setAlign(TextNode node, TextAlign align) {
    requestHandler(ChangeTextAlignRequest(nodeId: node.id, newTextAlign: align));
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
