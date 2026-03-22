/// A status bar widget that displays document statistics.
///
/// Provides [DocumentStatusBar] and utility functions [documentWordCount]
/// and [documentCharCount].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../model/blockquote_node.dart';
import '../model/code_block_node.dart';
import '../model/document.dart';
import '../model/document_editing_controller.dart';
import '../model/horizontal_rule_node.dart';
import '../model/image_node.dart';
import '../model/list_item_node.dart';
import '../model/paragraph_node.dart';
import '../model/table_node.dart';
import '../model/text_node.dart';

// ---------------------------------------------------------------------------
// Utility functions
// ---------------------------------------------------------------------------

/// Returns the total word count across all [TextNode]s in [document].
///
/// Words are separated by whitespace. Leading and trailing whitespace on each
/// node's text is trimmed before counting, so blank nodes contribute zero.
///
/// Non-text nodes (images, horizontal rules, tables, etc.) are ignored.
int documentWordCount(Document document) {
  var count = 0;
  for (final node in document.nodes) {
    if (node is TextNode) {
      final trimmed = node.text.text.trim();
      if (trimmed.isNotEmpty) {
        count += trimmed.split(RegExp(r'\s+')).length;
      }
    }
  }
  return count;
}

/// Returns the total character count across all [TextNode]s in [document].
///
/// Non-text nodes (images, horizontal rules, tables, etc.) are ignored.
int documentCharCount(Document document) {
  var count = 0;
  for (final node in document.nodes) {
    if (node is TextNode) {
      count += node.text.text.length;
    }
  }
  return count;
}

// ---------------------------------------------------------------------------
// DocumentStatusBar
// ---------------------------------------------------------------------------

/// A status bar that displays document statistics.
///
/// Shows the block count, word count, character count, and the current block
/// type label, depending on which visibility flags are enabled. Additional
/// custom widgets can be appended via [trailing].
///
/// Rebuild is driven by [ListenableBuilder] on [controller], so it updates
/// automatically when the document or selection changes.
///
/// ```dart
/// DocumentStatusBar(
///   controller: controller,
///   trailing: [Text('Ready')],
/// )
/// ```
class DocumentStatusBar extends StatelessWidget {
  /// Creates a [DocumentStatusBar].
  const DocumentStatusBar({
    super.key,
    required this.controller,
    this.showBlockCount = true,
    this.showWordCount = true,
    this.showCharCount = true,
    this.showCurrentBlockType = true,
    this.trailing,
  });

  /// The document editing controller that drives the statistics display.
  final DocumentEditingController controller;

  /// Whether to show the block count.
  final bool showBlockCount;

  /// Whether to show the word count.
  final bool showWordCount;

  /// Whether to show the character count.
  final bool showCharCount;

  /// Whether to show the current block type label.
  final bool showCurrentBlockType;

  /// Optional widgets appended at the trailing end of the status bar.
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final doc = controller.document;

    return Row(
      children: [
        if (showBlockCount) Text('${doc.nodeCount} blocks', style: style),
        if (showBlockCount && (showWordCount || showCharCount || showCurrentBlockType))
          const SizedBox(width: 16),
        if (showWordCount) Text('${documentWordCount(doc)} words', style: style),
        if (showWordCount && (showCharCount || showCurrentBlockType)) const SizedBox(width: 16),
        if (showCharCount) Text('${documentCharCount(doc)} chars', style: style),
        const Spacer(),
        if (showCurrentBlockType && controller.selection != null)
          Text(_currentBlockLabel(), style: style),
        if (trailing != null) ...trailing!,
      ],
    );
  }

  /// Returns a human-readable block type label for the currently selected node.
  String _currentBlockLabel() {
    final sel = controller.selection;
    if (sel == null) return '';
    final node = controller.document.nodeById(sel.extent.nodeId);
    if (node is ParagraphNode) {
      return switch (node.blockType) {
        ParagraphBlockType.header1 => 'H1',
        ParagraphBlockType.header2 => 'H2',
        ParagraphBlockType.header3 => 'H3',
        ParagraphBlockType.header4 => 'H4',
        ParagraphBlockType.header5 => 'H5',
        ParagraphBlockType.header6 => 'H6',
        ParagraphBlockType.blockquote => 'Blockquote',
        ParagraphBlockType.codeBlock => 'Code block',
        ParagraphBlockType.paragraph => 'Paragraph',
      };
    } else if (node is ListItemNode) {
      return node.type == ListItemType.ordered ? 'Ordered list' : 'Bullet list';
    } else if (node is BlockquoteNode) {
      return 'Blockquote';
    } else if (node is CodeBlockNode) {
      return 'Code block';
    } else if (node is HorizontalRuleNode) {
      return 'Horizontal rule';
    } else if (node is ImageNode) {
      return 'Image';
    } else if (node is TableNode) {
      return 'Table';
    }
    return '';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController>('controller', controller),
    );
    properties.add(
      FlagProperty('showBlockCount', value: showBlockCount, ifFalse: 'hidden'),
    );
    properties.add(
      FlagProperty('showWordCount', value: showWordCount, ifFalse: 'hidden'),
    );
    properties.add(
      FlagProperty('showCharCount', value: showCharCount, ifFalse: 'hidden'),
    );
    properties.add(
      FlagProperty('showCurrentBlockType', value: showCurrentBlockType, ifFalse: 'hidden'),
    );
  }
}
