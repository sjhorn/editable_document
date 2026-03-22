/// Insert-block toolbar bar for horizontal rule, image, and table.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/attributed_text.dart';
import '../../model/document_editing_controller.dart';
import '../../model/document_node.dart';
import '../../model/document_position.dart';
import '../../model/edit_request.dart';
import '../../model/horizontal_rule_node.dart';
import '../../model/image_node.dart';
import '../../model/paragraph_node.dart';
import '../../model/table_node.dart';
import 'table_size_picker.dart';

// ---------------------------------------------------------------------------
// DocumentInsertBar
// ---------------------------------------------------------------------------

/// A toolbar bar for inserting block-level content.
///
/// Shows three buttons:
///   - Horizontal rule
///   - Image (inserts a placeholder image)
///   - Table (uses a [TableSizePicker] grid overlay)
///
/// All buttons are enabled only when the controller has an active selection
/// (cursor or range).
///
/// The bar listens to [controller] and rebuilds whenever the selection changes.
/// Insert operations are submitted via [requestHandler] as
/// [InsertNodeAfterRequest].
///
/// ```dart
/// DocumentInsertBar(
///   controller: controller,
///   requestHandler: editor.submit,
/// )
/// ```
class DocumentInsertBar extends StatelessWidget {
  /// Creates a [DocumentInsertBar].
  const DocumentInsertBar({
    super.key,
    required this.controller,
    required this.requestHandler,
    this.defaultImageUrl = 'https://picsum.photos/600/200',
  });

  /// The document editing controller to read selection state from.
  final DocumentEditingController controller;

  /// Called with each [EditRequest] produced by the bar.
  final void Function(EditRequest) requestHandler;

  /// URL used when inserting a placeholder image.
  ///
  /// Defaults to `'https://picsum.photos/600/200'`.
  final String defaultImageUrl;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasCursor = controller.selection != null;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.horizontal_rule, size: 18),
              onPressed: hasCursor ? () => _insertNode(_newHorizontalRule()) : null,
              tooltip: 'Horizontal rule',
              style: _buttonStyle,
            ),
            IconButton(
              icon: const Icon(Icons.image_outlined, size: 18),
              onPressed: hasCursor ? () => _insertNode(_newImage()) : null,
              tooltip: 'Image',
              style: _buttonStyle,
            ),
            TableSizePicker(
              enabled: hasCursor,
              onSelect: (rows, cols) => _insertNode(_newTable(rows, cols)),
            ),
          ],
        );
      },
    );
  }

  static final _buttonStyle = IconButton.styleFrom(
    minimumSize: const Size(32, 32),
    padding: const EdgeInsets.all(4),
  );

  void _insertNode(DocumentNode node) {
    final sel = controller.selection;
    if (sel == null) return;

    requestHandler(
      InsertNodeAtPositionRequest(
        node: node,
        position: DocumentPosition(
          nodeId: sel.extent.nodeId,
          nodePosition: sel.extent.nodePosition,
        ),
        followOnNode: ParagraphNode(id: _generateId(), text: AttributedText('')),
      ),
    );
  }

  HorizontalRuleNode _newHorizontalRule() =>
      HorizontalRuleNode(id: _generateId());

  ImageNode _newImage() => ImageNode(
        id: _generateId(),
        imageUrl: defaultImageUrl,
        altText: 'Inserted image',
      );

  TableNode _newTable(int rows, int cols) => TableNode(
        id: _generateId(),
        rowCount: rows,
        columnCount: cols,
        cells: List.generate(rows, (_) => List.generate(cols, (_) => AttributedText(''))),
      );

  String _generateId() => 'node-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController>('controller', controller),
    );
    properties.add(
      ObjectFlagProperty<void Function(EditRequest)>.has('requestHandler', requestHandler),
    );
    properties.add(StringProperty('defaultImageUrl', defaultImageUrl));
  }
}
