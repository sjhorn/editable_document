/// Block type toolbar bar for paragraph, blockquote, code, and list items.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/attributed_text.dart';
import '../../model/blockquote_node.dart';
import '../../model/code_block_node.dart';
import '../../model/document_editing_controller.dart';
import '../../model/document_node.dart';
import '../../model/edit_request.dart';
import '../../model/list_item_node.dart';
import '../../model/paragraph_node.dart';
import '../../model/text_node.dart';
import 'document_format_toggle.dart';

// ---------------------------------------------------------------------------
// DocumentBlockTypeBar
// ---------------------------------------------------------------------------

/// A toolbar bar for changing the block type of the selected node.
///
/// Shows a heading dropdown (H1–H6) followed by toggle buttons for:
/// paragraph, blockquote, code block, bullet list, and numbered list.
/// Each button is enabled only when the cursor is on a [TextNode].
///
/// Toggling a type that is already active converts the node back to a plain
/// paragraph (except for "paragraph" itself, which is a no-op).
///
/// The bar listens to [controller] and rebuilds whenever the selection changes.
/// Conversion requests are submitted via [requestHandler] as
/// [ReplaceNodeRequest].
///
/// ```dart
/// DocumentBlockTypeBar(
///   controller: controller,
///   requestHandler: editor.submit,
/// )
/// ```
class DocumentBlockTypeBar extends StatelessWidget {
  /// Creates a [DocumentBlockTypeBar].
  const DocumentBlockTypeBar({
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
        final node = sel != null ? controller.document.nodeById(sel.extent.nodeId) : null;
        final isOnTextNode = node is TextNode;

        final isHeading = node is ParagraphNode && _headingTypes.contains(node.blockType);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeadingDropdown(
              isActive: isHeading,
              enabled: isOnTextNode,
              currentBlockType: node is ParagraphNode ? node.blockType : null,
              onSelected: isOnTextNode ? (level) => _toggleHeading(level) : null,
            ),
            DocumentFormatToggle(
              icon: Icons.segment,
              tooltip: 'Paragraph',
              isActive: _isBlockType(node, 'paragraph'),
              onPressed: isOnTextNode ? () => _toggleBlockType('paragraph') : null,
            ),
            DocumentFormatToggle(
              icon: Icons.format_quote,
              tooltip: 'Blockquote',
              isActive: _isBlockType(node, 'blockquote'),
              onPressed: isOnTextNode ? () => _toggleBlockType('blockquote') : null,
            ),
            DocumentFormatToggle(
              icon: Icons.data_object,
              tooltip: 'Code block',
              isActive: _isBlockType(node, 'code'),
              onPressed: isOnTextNode ? () => _toggleBlockType('code') : null,
            ),
            DocumentFormatToggle(
              icon: Icons.format_list_bulleted,
              tooltip: 'Bullet list',
              isActive: _isBlockType(node, 'unordered'),
              onPressed: isOnTextNode ? () => _toggleBlockType('unordered') : null,
            ),
            DocumentFormatToggle(
              icon: Icons.format_list_numbered,
              tooltip: 'Numbered list',
              isActive: _isBlockType(node, 'ordered'),
              onPressed: isOnTextNode ? () => _toggleBlockType('ordered') : null,
            ),
          ],
        );
      },
    );
  }

  static const _headingTypes = {
    ParagraphBlockType.header1,
    ParagraphBlockType.header2,
    ParagraphBlockType.header3,
    ParagraphBlockType.header4,
    ParagraphBlockType.header5,
    ParagraphBlockType.header6,
  };

  void _toggleHeading(ParagraphBlockType level) {
    final sel = controller.selection;
    if (sel == null) return;

    final node = controller.document.nodeById(sel.extent.nodeId);
    if (node is! TextNode) return;

    // If already this heading level, toggle back to paragraph.
    final isAlready = node is ParagraphNode && node.blockType == level;
    final targetType = isAlready ? ParagraphBlockType.paragraph : level;

    final existingAlign = switch (node) {
      ParagraphNode(:final textAlign) => textAlign,
      ListItemNode(:final textAlign) => textAlign,
      BlockquoteNode(:final textAlign) => textAlign,
      _ => TextAlign.start,
    };

    requestHandler(
      ReplaceNodeRequest(
        nodeId: node.id,
        newNode: ParagraphNode(
          id: node.id,
          text: node.text,
          blockType: targetType,
          textAlign: existingAlign,
        ),
      ),
    );
  }

  bool _isBlockType(DocumentNode? node, String type) {
    return switch (type) {
      'paragraph' => node is ParagraphNode && node.blockType == ParagraphBlockType.paragraph,
      'blockquote' => node is BlockquoteNode,
      'code' => node is CodeBlockNode,
      'unordered' => node is ListItemNode && node.type == ListItemType.unordered,
      'ordered' => node is ListItemNode && node.type == ListItemType.ordered,
      _ => false,
    };
  }

  void _toggleBlockType(String type) {
    final sel = controller.selection;
    if (sel == null) return;

    final node = controller.document.nodeById(sel.extent.nodeId);
    if (node is! TextNode) return;

    // If already this type, toggle back to paragraph.
    final alreadyMatches = _isBlockType(node, type);
    final targetType = alreadyMatches && type != 'paragraph' ? 'paragraph' : type;

    if (_isBlockType(node, targetType)) return; // no-op

    final existingAlign = switch (node) {
      ParagraphNode(:final textAlign) => textAlign,
      ListItemNode(:final textAlign) => textAlign,
      BlockquoteNode(:final textAlign) => textAlign,
      _ => TextAlign.start,
    };

    final newNode = _makeNode(targetType, node.id, node.text, existingAlign);
    if (newNode != null) {
      requestHandler(ReplaceNodeRequest(nodeId: node.id, newNode: newNode));
    }
  }

  TextNode? _makeNode(
    String type,
    String id,
    AttributedText text,
    TextAlign textAlign,
  ) {
    return switch (type) {
      'paragraph' => ParagraphNode(id: id, text: text, textAlign: textAlign),
      'blockquote' => BlockquoteNode(id: id, text: text, textAlign: textAlign),
      'code' => CodeBlockNode(id: id, text: text),
      'unordered' =>
        ListItemNode(id: id, text: text, type: ListItemType.unordered, textAlign: textAlign),
      'ordered' =>
        ListItemNode(id: id, text: text, type: ListItemType.ordered, textAlign: textAlign),
      _ => null,
    };
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

// ---------------------------------------------------------------------------
// _HeadingDropdown — private heading level picker button
// ---------------------------------------------------------------------------

class _HeadingDropdown extends StatelessWidget {
  const _HeadingDropdown({
    required this.isActive,
    required this.enabled,
    required this.currentBlockType,
    required this.onSelected,
  });

  final bool isActive;
  final bool enabled;
  final ParagraphBlockType? currentBlockType;
  final ValueChanged<ParagraphBlockType>? onSelected;

  static const _levels = [
    (ParagraphBlockType.header1, 'H1'),
    (ParagraphBlockType.header2, 'H2'),
    (ParagraphBlockType.header3, 'H3'),
    (ParagraphBlockType.header4, 'H4'),
    (ParagraphBlockType.header5, 'H5'),
    (ParagraphBlockType.header6, 'H6'),
  ];

  String? get _activeLabel {
    if (!isActive || currentBlockType == null) return null;
    for (final (type, label) in _levels) {
      if (type == currentBlockType) return label;
    }
    return null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('isActive', value: isActive, ifTrue: 'active'));
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
    properties.add(
      EnumProperty<ParagraphBlockType?>('currentBlockType', currentBlockType, defaultValue: null),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<ParagraphBlockType>?>.has('onSelected', onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = _activeLabel;

    final buttonLabel = label ?? 'H';
    final textColor = enabled
        ? (isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurface)
        : colorScheme.onSurface.withValues(alpha: 0.38);

    return PopupMenuButton<ParagraphBlockType>(
      tooltip: 'Heading',
      enabled: enabled,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 48),
      itemBuilder: (context) => [
        for (final (type, text) in _levels)
          PopupMenuItem<ParagraphBlockType>(
            value: type,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type == currentBlockType)
                  Icon(Icons.check, size: 16, color: colorScheme.primary),
                if (type == currentBlockType) const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontWeight: type == currentBlockType ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            buttonLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
