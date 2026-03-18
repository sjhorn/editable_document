/// Edit command implementations for the editable_document command architecture.
///
/// Each [EditCommand] corresponds to an [EditRequest] and carries out the
/// actual mutation of a [MutableDocument] via the [EditContext].
///
/// Commands return a list of [DocumentChangeEvent]s describing every mutation
/// that occurred; the [Editor] accumulates these events and delivers them to
/// reactions and listeners.
library;

import 'dart:ui' show TextAlign;

import 'attribution.dart';
import 'attributed_text.dart';
import 'blockquote_node.dart';
import 'code_block_node.dart';
import 'document_change_event.dart';
import 'document_node.dart';
import 'document_position.dart';
import 'document_selection.dart';
import 'edit_context.dart';
import 'horizontal_rule_node.dart';
import 'mutable_document.dart';
import 'image_node.dart';
import 'list_item_node.dart';
import 'node_position.dart';
import 'paragraph_node.dart';
import 'table_node.dart';
import 'table_vertical_alignment.dart';
import 'text_node.dart';

// ---------------------------------------------------------------------------
// EditCommand (abstract base)
// ---------------------------------------------------------------------------

/// Abstract base class for all edit commands.
///
/// An [EditCommand] performs mutations on the document and controller exposed
/// by [EditContext], then returns the list of [DocumentChangeEvent]s produced.
///
/// Create [EditCommand]s through [Editor]'s internal factory — do not
/// instantiate them manually unless writing tests for individual commands.
abstract class EditCommand {
  /// Creates an [EditCommand].
  const EditCommand();

  /// Executes this command against [context].
  ///
  /// Mutates `context.document` and optionally updates
  /// `context.controller.selection`. Returns the [DocumentChangeEvent]s
  /// that describe all mutations performed.
  List<DocumentChangeEvent> execute(EditContext context);
}

// ---------------------------------------------------------------------------
// InsertTextCommand
// ---------------------------------------------------------------------------

/// Inserts [text] into the text node [nodeId] at [offset].
///
/// After insertion the controller selection is collapsed to the position
/// immediately after the inserted text.
///
/// Throws [StateError] when [nodeId] does not exist or is not a [TextNode].
class InsertTextCommand extends EditCommand {
  /// Creates an [InsertTextCommand].
  const InsertTextCommand({
    required this.nodeId,
    required this.offset,
    required this.text,
  });

  /// The id of the target text node.
  final String nodeId;

  /// The insertion point within the node's text.
  final int offset;

  /// The rich text to insert.
  final AttributedText text;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final node = context.document.nodeById(nodeId);
    if (node == null) {
      throw StateError('InsertTextCommand: no node with id "$nodeId".');
    }
    if (node is! TextNode) {
      throw StateError('InsertTextCommand: node "$nodeId" is not a TextNode.');
    }

    final newText = node.text.insert(offset, text);
    context.document.updateNode(nodeId, (n) => (n as TextNode).copyWith(text: newText));

    // Move caret to just after the inserted text.
    final newOffset = offset + text.length;
    context.controller.setSelection(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: TextNodePosition(offset: newOffset),
        ),
      ),
    );

    return [TextChanged(nodeId: nodeId)];
  }
}

// ---------------------------------------------------------------------------
// DeleteContentCommand
// ---------------------------------------------------------------------------

/// Deletes the content covered by [selection].
///
/// Handles single-node and multi-node selections. When the selection spans
/// multiple text nodes, the tail of the first text node is preserved, middle
/// nodes are removed, the head of the last text node is removed, and the
/// remaining tails of the first and last nodes are merged into the first.
///
/// The controller selection is collapsed to the deletion start position.
class DeleteContentCommand extends EditCommand {
  /// Creates a [DeleteContentCommand].
  const DeleteContentCommand({required this.selection});

  /// The selection whose content will be deleted.
  final DocumentSelection selection;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    if (selection.isCollapsed) return const [];

    final doc = context.document;
    final normalized = selection.normalize(doc);
    final startPos = normalized.base;
    final endPos = normalized.extent;

    final startIndex = doc.getNodeIndexById(startPos.nodeId);
    final endIndex = doc.getNodeIndexById(endPos.nodeId);

    final events = <DocumentChangeEvent>[];

    if (startIndex == endIndex) {
      // ----------------------------------------------------------------
      // Single-node deletion
      // ----------------------------------------------------------------
      final node = doc.nodeById(startPos.nodeId);
      if (node is TextNode) {
        final startOffset = (startPos.nodePosition as TextNodePosition).offset;
        final endOffset = (endPos.nodePosition as TextNodePosition).offset;
        final newText = node.text.delete(startOffset, endOffset);
        doc.updateNode(startPos.nodeId, (n) => (n as TextNode).copyWith(text: newText));
        events.add(TextChanged(nodeId: startPos.nodeId));

        context.controller.setSelection(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: startPos.nodeId,
              nodePosition: TextNodePosition(offset: startOffset),
            ),
          ),
        );
      } else if (node is TableNode &&
          startPos.nodePosition is TableCellPosition &&
          endPos.nodePosition is TableCellPosition) {
        // Table cell deletion — delete selected text within the same cell.
        final startCell = startPos.nodePosition as TableCellPosition;
        final endCell = endPos.nodePosition as TableCellPosition;
        if (startCell.row == endCell.row && startCell.col == endCell.col) {
          final cellText = node.cellAt(startCell.row, startCell.col).text;
          final newCellText =
              cellText.substring(0, startCell.offset) + cellText.substring(endCell.offset);
          final newCells = List<List<AttributedText>>.generate(
            node.rowCount,
            (r) => List<AttributedText>.generate(
              node.columnCount,
              (c) => (r == startCell.row && c == startCell.col)
                  ? AttributedText(newCellText)
                  : node.cellAt(r, c),
            ),
          );
          doc.replaceNode(startPos.nodeId, node.copyWith(cells: newCells));
          events.add(NodeReplaced(oldNodeId: startPos.nodeId, newNodeId: startPos.nodeId));

          context.controller.setSelection(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: startPos.nodeId,
                nodePosition: TableCellPosition(
                  row: startCell.row,
                  col: startCell.col,
                  offset: startCell.offset,
                ),
              ),
            ),
          );
        }
        // Cross-cell deletion is not supported — fall through to no-op.
      } else {
        // Binary / block node (e.g. HorizontalRuleNode, ImageNode) — delete
        // the whole node and move the selection to the nearest surviving node.
        final prevNode = doc.nodeBefore(startPos.nodeId);
        final nextNode = doc.nodeAfter(startPos.nodeId);

        final nodeIndex = doc.getNodeIndexById(startPos.nodeId);
        doc.deleteNode(startPos.nodeId);
        events.add(NodeDeleted(nodeId: startPos.nodeId, index: nodeIndex));

        if (prevNode is TextNode) {
          // Collapse to the end of the preceding text node.
          context.controller.setSelection(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: prevNode.id,
                nodePosition: TextNodePosition(offset: prevNode.text.length),
              ),
            ),
          );
        } else if (nextNode != null) {
          // No text node before — collapse to the start of the next node.
          context.controller.setSelection(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: nextNode.id,
                nodePosition: const TextNodePosition(offset: 0),
              ),
            ),
          );
        } else {
          // Document is now empty — clear the selection entirely.
          context.controller.clearSelection();
        }
      }
    } else {
      // ----------------------------------------------------------------
      // Multi-node deletion
      // ----------------------------------------------------------------

      // Snapshot node ids in the range before mutations.
      final nodeIds = <String>[];
      for (var i = startIndex; i <= endIndex; i++) {
        nodeIds.add(doc.nodeAt(i).id);
      }

      final firstNodeId = nodeIds.first;
      final lastNodeId = nodeIds.last;

      // 1. Trim the tail of the first node.
      final firstNode = doc.nodeById(firstNodeId);
      int? firstNodeTrimOffset;
      if (firstNode is TextNode) {
        firstNodeTrimOffset = (startPos.nodePosition as TextNodePosition).offset;
        final trimmed = firstNode.text.copyText(0, firstNodeTrimOffset);
        doc.updateNode(firstNodeId, (n) => (n as TextNode).copyWith(text: trimmed));
        events.add(TextChanged(nodeId: firstNodeId));
      }

      // 2. Delete middle nodes (all except first and last).
      for (var i = 1; i < nodeIds.length - 1; i++) {
        final midId = nodeIds[i];
        final midIndex = doc.getNodeIndexById(midId);
        doc.deleteNode(midId);
        events.add(NodeDeleted(nodeId: midId, index: midIndex));
      }

      // 3. Trim head of last node and merge remainder into first.
      final lastNode = doc.nodeById(lastNodeId);
      if (lastNode is TextNode && firstNode is TextNode) {
        final lastTrimOffset = (endPos.nodePosition as TextNodePosition).offset;
        final lastTail = lastNode.text.copyText(lastTrimOffset);

        final firstUpdated = doc.nodeById(firstNodeId) as TextNode;
        final merged = firstUpdated.text.insert(firstUpdated.text.length, lastTail);
        doc.updateNode(firstNodeId, (n) => (n as TextNode).copyWith(text: merged));

        // Avoid duplicate TextChanged for first node.
        final alreadyHasFirstNodeChange = events.whereType<TextChanged>().any(
              (e) => e.nodeId == firstNodeId,
            );
        if (!alreadyHasFirstNodeChange) {
          events.add(TextChanged(nodeId: firstNodeId));
        }

        final lastIndex = doc.getNodeIndexById(lastNodeId);
        doc.deleteNode(lastNodeId);
        events.add(NodeDeleted(nodeId: lastNodeId, index: lastIndex));
      } else if (lastNode != null) {
        // Last node is not text — just delete it.
        final lastIndex = doc.getNodeIndexById(lastNodeId);
        doc.deleteNode(lastNodeId);
        events.add(NodeDeleted(nodeId: lastNodeId, index: lastIndex));
      }

      // Collapse selection to the deletion start.
      final collapseOffset = firstNodeTrimOffset ?? 0;
      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: firstNodeId,
            nodePosition: TextNodePosition(offset: collapseOffset),
          ),
        ),
      );
    }

    return events;
  }
}

// ---------------------------------------------------------------------------
// ReplaceNodeCommand
// ---------------------------------------------------------------------------

/// Replaces the node identified by [nodeId] with [newNode].
///
/// Throws [StateError] when [nodeId] does not exist.
class ReplaceNodeCommand extends EditCommand {
  /// Creates a [ReplaceNodeCommand].
  const ReplaceNodeCommand({required this.nodeId, required this.newNode});

  /// The id of the node to replace.
  final String nodeId;

  /// The replacement node.
  final DocumentNode newNode;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final existing = context.document.nodeById(nodeId);
    if (existing == null) {
      throw StateError('ReplaceNodeCommand: no node with id "$nodeId".');
    }
    context.document.replaceNode(nodeId, newNode);
    return [NodeReplaced(oldNodeId: nodeId, newNodeId: newNode.id)];
  }
}

// ---------------------------------------------------------------------------
// SplitParagraphCommand
// ---------------------------------------------------------------------------

/// Splits the text node [nodeId] at [splitOffset].
///
/// The original node retains `text[0, splitOffset)`. A new node (with a
/// fresh id from [generateNodeId]) containing `text[splitOffset, end)` is
/// inserted immediately after. The controller selection is collapsed to
/// offset 0 of the new node.
///
/// Throws [StateError] when [nodeId] does not exist or is not a [TextNode].
class SplitParagraphCommand extends EditCommand {
  /// Creates a [SplitParagraphCommand].
  const SplitParagraphCommand({required this.nodeId, required this.splitOffset});

  /// The id of the node to split.
  final String nodeId;

  /// The character offset at which to split the text.
  ///
  /// Characters before this offset remain in the original node; characters
  /// from this offset onward move to the new node.
  final int splitOffset;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final node = doc.nodeById(nodeId);
    if (node == null) {
      throw StateError('SplitParagraphCommand: no node with id "$nodeId".');
    }
    if (node is! TextNode) {
      throw StateError('SplitParagraphCommand: node "$nodeId" is not a TextNode.');
    }

    final firstText = node.text.copyText(0, splitOffset);
    final secondText = node.text.copyText(splitOffset);

    // Update first node with its portion of text.
    doc.updateNode(nodeId, (n) => (n as TextNode).copyWith(text: firstText));

    // Build the second (new) node preserving type.
    final newId = generateNodeId();
    final DocumentNode newNode = node.copyWith(id: newId, text: secondText);

    final insertIndex = doc.getNodeIndexById(nodeId) + 1;
    doc.insertNode(insertIndex, newNode);

    // Move selection to the beginning of the new node.
    context.controller.setSelection(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: newId,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ),
    );

    return [
      TextChanged(nodeId: nodeId),
      NodeInserted(nodeId: newId, index: insertIndex),
    ];
  }
}

// ---------------------------------------------------------------------------
// MergeNodeCommand
// ---------------------------------------------------------------------------

/// Merges two text nodes by appending the second node's text to the first,
/// then deleting the second node.
///
/// Throws [StateError] when either node is missing or is not a [TextNode].
class MergeNodeCommand extends EditCommand {
  /// Creates a [MergeNodeCommand].
  const MergeNodeCommand({required this.firstNodeId, required this.secondNodeId});

  /// The id of the node that absorbs the second node's text.
  final String firstNodeId;

  /// The id of the node that is deleted after merging.
  final String secondNodeId;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;

    final first = doc.nodeById(firstNodeId);
    if (first == null) {
      throw StateError('MergeNodeCommand: no node with id "$firstNodeId".');
    }
    if (first is! TextNode) {
      throw StateError('MergeNodeCommand: node "$firstNodeId" is not a TextNode.');
    }

    final second = doc.nodeById(secondNodeId);
    if (second == null) {
      throw StateError('MergeNodeCommand: no node with id "$secondNodeId".');
    }
    if (second is! TextNode) {
      throw StateError('MergeNodeCommand: node "$secondNodeId" is not a TextNode.');
    }

    // Capture the join point before the merge so the caret can be placed
    // precisely at the boundary between the original first-node text and the
    // appended second-node text.
    final joinOffset = first.text.length;

    final merged = first.text.insert(first.text.length, second.text);
    doc.updateNode(firstNodeId, (n) => (n as TextNode).copyWith(text: merged));

    final secondIndex = doc.getNodeIndexById(secondNodeId);
    doc.deleteNode(secondNodeId);

    // Move the caret to the join point.
    context.controller.setSelection(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: firstNodeId,
          nodePosition: TextNodePosition(offset: joinOffset),
        ),
      ),
    );

    return [
      TextChanged(nodeId: firstNodeId),
      NodeDeleted(nodeId: secondNodeId, index: secondIndex),
    ];
  }
}

// ---------------------------------------------------------------------------
// MoveNodeCommand
// ---------------------------------------------------------------------------

/// Moves the node identified by [nodeId] to [newIndex].
///
/// Delegates to [MutableDocument.moveNode]. Returns a [NodeMoved] event.
///
/// Throws [StateError] when [nodeId] does not exist.
class MoveNodeCommand extends EditCommand {
  /// Creates a [MoveNodeCommand].
  const MoveNodeCommand({required this.nodeId, required this.newIndex});

  /// The id of the node to move.
  final String nodeId;

  /// The target index (post-removal).
  final int newIndex;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final oldIndex = doc.getNodeIndexById(nodeId);
    if (oldIndex < 0) {
      throw StateError('MoveNodeCommand: no node with id "$nodeId".');
    }
    doc.moveNode(nodeId, newIndex);
    return [NodeMoved(nodeId: nodeId, oldIndex: oldIndex, newIndex: newIndex)];
  }
}

// ---------------------------------------------------------------------------
// ChangeBlockTypeCommand
// ---------------------------------------------------------------------------

/// Changes the [ParagraphBlockType] of the [ParagraphNode] identified by
/// [nodeId].
///
/// Throws [StateError] when [nodeId] does not exist or is not a
/// [ParagraphNode].
class ChangeBlockTypeCommand extends EditCommand {
  /// Creates a [ChangeBlockTypeCommand].
  const ChangeBlockTypeCommand({required this.nodeId, required this.newBlockType});

  /// The id of the paragraph node to update.
  final String nodeId;

  /// The new block type to apply.
  final ParagraphBlockType newBlockType;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final node = context.document.nodeById(nodeId);
    if (node == null) {
      throw StateError('ChangeBlockTypeCommand: no node with id "$nodeId".');
    }
    if (node is! ParagraphNode) {
      throw StateError('ChangeBlockTypeCommand: node "$nodeId" is not a ParagraphNode.');
    }
    context.document.replaceNode(nodeId, node.copyWith(blockType: newBlockType));
    return [NodeReplaced(oldNodeId: nodeId, newNodeId: nodeId)];
  }
}

// ---------------------------------------------------------------------------
// ChangeTextAlignCommand
// ---------------------------------------------------------------------------

/// Changes the [TextAlign] of a text block node.
///
/// Supports [ParagraphNode], [ListItemNode], and [BlockquoteNode].
///
/// Throws [StateError] when [nodeId] does not exist, or when the identified
/// node is not one of the supported text block types.
class ChangeTextAlignCommand extends EditCommand {
  /// Creates a [ChangeTextAlignCommand].
  const ChangeTextAlignCommand({required this.nodeId, required this.newTextAlign});

  /// The id of the text block node to update.
  final String nodeId;

  /// The new text alignment to apply.
  final TextAlign newTextAlign;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final node = context.document.nodeById(nodeId);
    if (node == null) {
      throw StateError('ChangeTextAlignCommand: no node with id "$nodeId".');
    }
    if (node is ParagraphNode) {
      context.document.replaceNode(nodeId, node.copyWith(textAlign: newTextAlign));
    } else if (node is ListItemNode) {
      context.document.replaceNode(nodeId, node.copyWith(textAlign: newTextAlign));
    } else if (node is BlockquoteNode) {
      context.document.replaceNode(nodeId, node.copyWith(textAlign: newTextAlign));
    } else {
      throw StateError(
        'ChangeTextAlignCommand: node "$nodeId" (${node.runtimeType}) does not support textAlign.',
      );
    }
    return [NodeReplaced(oldNodeId: nodeId, newNodeId: nodeId)];
  }
}

// ---------------------------------------------------------------------------
// ChangeLineHeightCommand
// ---------------------------------------------------------------------------

/// Changes the [lineHeight] multiplier of the text block identified by
/// [nodeId].
///
/// Supports [ParagraphNode], [ListItemNode], [BlockquoteNode], and
/// [CodeBlockNode].
///
/// Throws [StateError] when [nodeId] does not exist, or when the identified
/// node is not one of the supported text block types.
class ChangeLineHeightCommand extends EditCommand {
  /// Creates a [ChangeLineHeightCommand].
  const ChangeLineHeightCommand({required this.nodeId, required this.newLineHeight});

  /// The id of the text block node to update.
  final String nodeId;

  /// The new line height multiplier to apply, or `null` to reset to the
  /// document default.
  final double? newLineHeight;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final node = context.document.nodeById(nodeId);
    if (node == null) {
      throw StateError('ChangeLineHeightCommand: no node with id "$nodeId".');
    }
    if (node is ParagraphNode) {
      context.document.replaceNode(nodeId, node.copyWith(lineHeight: newLineHeight));
    } else if (node is ListItemNode) {
      context.document.replaceNode(nodeId, node.copyWith(lineHeight: newLineHeight));
    } else if (node is BlockquoteNode) {
      context.document.replaceNode(nodeId, node.copyWith(lineHeight: newLineHeight));
    } else if (node is CodeBlockNode) {
      context.document.replaceNode(nodeId, node.copyWith(lineHeight: newLineHeight));
    } else {
      throw StateError(
        'ChangeLineHeightCommand: node "$nodeId" (${node.runtimeType}) does not support lineHeight.',
      );
    }
    return [NodeReplaced(oldNodeId: nodeId, newNodeId: nodeId)];
  }
}

// ---------------------------------------------------------------------------
// ChangeSpacingCommand
// ---------------------------------------------------------------------------

/// Changes the [spaceBefore] and/or [spaceAfter] of the block identified by
/// [nodeId].
///
/// Supports all block node types that carry spacing fields:
/// [ParagraphNode], [ListItemNode], [BlockquoteNode], [CodeBlockNode],
/// [ImageNode], [HorizontalRuleNode], and [TableNode].
///
/// Only non-null values in [newSpaceBefore] and [newSpaceAfter] are applied;
/// `null` values leave the corresponding spacing field unchanged on the node.
///
/// Throws [StateError] when [nodeId] does not exist.
class ChangeSpacingCommand extends EditCommand {
  /// Creates a [ChangeSpacingCommand].
  const ChangeSpacingCommand({
    required this.nodeId,
    this.newSpaceBefore,
    this.newSpaceAfter,
  });

  /// The id of the block node to update.
  final String nodeId;

  /// The new space before value in logical pixels, or `null` to leave
  /// the current value unchanged.
  final double? newSpaceBefore;

  /// The new space after value in logical pixels, or `null` to leave
  /// the current value unchanged.
  final double? newSpaceAfter;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final node = context.document.nodeById(nodeId);
    if (node == null) {
      throw StateError('ChangeSpacingCommand: no node with id "$nodeId".');
    }
    if (node is ParagraphNode) {
      context.document.replaceNode(
        nodeId,
        node.copyWith(
          spaceBefore: newSpaceBefore ?? node.spaceBefore,
          spaceAfter: newSpaceAfter ?? node.spaceAfter,
        ),
      );
    } else if (node is ListItemNode) {
      context.document.replaceNode(
        nodeId,
        node.copyWith(
          spaceBefore: newSpaceBefore ?? node.spaceBefore,
          spaceAfter: newSpaceAfter ?? node.spaceAfter,
        ),
      );
    } else if (node is BlockquoteNode) {
      context.document.replaceNode(
        nodeId,
        node.copyWith(
          spaceBefore: newSpaceBefore ?? node.spaceBefore,
          spaceAfter: newSpaceAfter ?? node.spaceAfter,
        ),
      );
    } else if (node is CodeBlockNode) {
      context.document.replaceNode(
        nodeId,
        node.copyWith(
          spaceBefore: newSpaceBefore ?? node.spaceBefore,
          spaceAfter: newSpaceAfter ?? node.spaceAfter,
        ),
      );
    } else if (node is ImageNode) {
      context.document.replaceNode(
        nodeId,
        node.copyWith(
          spaceBefore: newSpaceBefore ?? node.spaceBefore,
          spaceAfter: newSpaceAfter ?? node.spaceAfter,
        ),
      );
    } else if (node is HorizontalRuleNode) {
      context.document.replaceNode(
        nodeId,
        node.copyWith(
          spaceBefore: newSpaceBefore ?? node.spaceBefore,
          spaceAfter: newSpaceAfter ?? node.spaceAfter,
        ),
      );
    } else if (node is TableNode) {
      context.document.replaceNode(
        nodeId,
        node.copyWith(
          spaceBefore: newSpaceBefore ?? node.spaceBefore,
          spaceAfter: newSpaceAfter ?? node.spaceAfter,
        ),
      );
    } else {
      throw StateError(
        'ChangeSpacingCommand: node "$nodeId" (${node.runtimeType}) does not support spacing.',
      );
    }
    return [NodeReplaced(oldNodeId: nodeId, newNodeId: nodeId)];
  }
}

// ---------------------------------------------------------------------------
// ChangeIndentCommand
// ---------------------------------------------------------------------------

/// Changes the indent properties of the text block identified by [nodeId].
///
/// Supports [ParagraphNode], [ListItemNode], and [BlockquoteNode].
///
/// Only non-null values in [newIndentLeft], [newIndentRight], and
/// [newFirstLineIndent] are applied; `null` values leave the corresponding
/// field unchanged on the node. For [ListItemNode] targets, [newFirstLineIndent]
/// is always ignored.
///
/// Throws [StateError] when [nodeId] does not exist, or when the identified
/// node is not one of the supported text block types.
class ChangeIndentCommand extends EditCommand {
  /// Creates a [ChangeIndentCommand].
  const ChangeIndentCommand({
    required this.nodeId,
    this.newIndentLeft,
    this.newIndentRight,
    this.newFirstLineIndent,
  });

  /// The id of the text block node to update.
  final String nodeId;

  /// The new left indent in logical pixels, or `null` to leave unchanged.
  final double? newIndentLeft;

  /// The new right indent in logical pixels, or `null` to leave unchanged.
  final double? newIndentRight;

  /// The new first-line indent in logical pixels, or `null` to leave unchanged.
  ///
  /// Ignored for [ListItemNode] targets.
  final double? newFirstLineIndent;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final node = context.document.nodeById(nodeId);
    if (node == null) {
      throw StateError('ChangeIndentCommand: no node with id "$nodeId".');
    }
    if (node is ParagraphNode) {
      context.document.replaceNode(
        nodeId,
        node.copyWith(
          indentLeft: newIndentLeft ?? node.indentLeft,
          indentRight: newIndentRight ?? node.indentRight,
          firstLineIndent: newFirstLineIndent ?? node.firstLineIndent,
        ),
      );
    } else if (node is ListItemNode) {
      // firstLineIndent is not applicable to list items (marker alignment).
      context.document.replaceNode(
        nodeId,
        node.copyWith(
          indentLeft: newIndentLeft ?? node.indentLeft,
          indentRight: newIndentRight ?? node.indentRight,
        ),
      );
    } else if (node is BlockquoteNode) {
      context.document.replaceNode(
        nodeId,
        node.copyWith(
          indentLeft: newIndentLeft ?? node.indentLeft,
          indentRight: newIndentRight ?? node.indentRight,
          firstLineIndent: newFirstLineIndent ?? node.firstLineIndent,
        ),
      );
    } else {
      throw StateError(
        'ChangeIndentCommand: node "$nodeId" (${node.runtimeType}) does not support indent.',
      );
    }
    return [NodeReplaced(oldNodeId: nodeId, newNodeId: nodeId)];
  }
}

// ---------------------------------------------------------------------------
// ApplyAttributionCommand
// ---------------------------------------------------------------------------

/// Applies [attribution] to all text within [selection].
///
/// For text nodes at the boundaries of the selection, only the selected
/// portion receives the attribution. Middle nodes (entirely within the
/// selection) are attributed over their full length.
///
/// Returns a [TextChanged] event for each modified node. Returns an empty
/// list when [selection] is collapsed.
class ApplyAttributionCommand extends EditCommand {
  /// Creates an [ApplyAttributionCommand].
  const ApplyAttributionCommand({required this.selection, required this.attribution});

  /// The selection range over which to apply.
  final DocumentSelection selection;

  /// The attribution to apply.
  final Attribution attribution;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    if (selection.isCollapsed) return const [];

    final doc = context.document;
    final normalized = selection.normalize(doc);
    final startPos = normalized.base;
    final endPos = normalized.extent;

    final startIndex = doc.getNodeIndexById(startPos.nodeId);
    final endIndex = doc.getNodeIndexById(endPos.nodeId);

    final events = <DocumentChangeEvent>[];

    for (var i = startIndex; i <= endIndex; i++) {
      final node = doc.nodeAt(i);
      if (node is! TextNode) continue;

      final int rangeStart;
      final int rangeEnd;

      if (i == startIndex && i == endIndex) {
        rangeStart = (startPos.nodePosition as TextNodePosition).offset;
        rangeEnd = (endPos.nodePosition as TextNodePosition).offset - 1;
      } else if (i == startIndex) {
        rangeStart = (startPos.nodePosition as TextNodePosition).offset;
        rangeEnd = node.text.length - 1;
      } else if (i == endIndex) {
        rangeStart = 0;
        rangeEnd = (endPos.nodePosition as TextNodePosition).offset - 1;
      } else {
        rangeStart = 0;
        rangeEnd = node.text.length - 1;
      }

      if (rangeStart > rangeEnd || rangeEnd < 0) continue;

      final newText = node.text.applyAttribution(attribution, rangeStart, rangeEnd);
      doc.updateNode(node.id, (n) => (n as TextNode).copyWith(text: newText));
      events.add(TextChanged(nodeId: node.id));
    }

    return events;
  }
}

// ---------------------------------------------------------------------------
// RemoveAttributionCommand
// ---------------------------------------------------------------------------

/// Removes [attribution] from all text within [selection].
///
/// The inverse of [ApplyAttributionCommand]. Returns a [TextChanged] event
/// for each modified node. Returns an empty list when [selection] is
/// collapsed.
class RemoveAttributionCommand extends EditCommand {
  /// Creates a [RemoveAttributionCommand].
  const RemoveAttributionCommand({required this.selection, required this.attribution});

  /// The selection range from which to remove.
  final DocumentSelection selection;

  /// The attribution to remove.
  final Attribution attribution;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    if (selection.isCollapsed) return const [];

    final doc = context.document;
    final normalized = selection.normalize(doc);
    final startPos = normalized.base;
    final endPos = normalized.extent;

    final startIndex = doc.getNodeIndexById(startPos.nodeId);
    final endIndex = doc.getNodeIndexById(endPos.nodeId);

    final events = <DocumentChangeEvent>[];

    for (var i = startIndex; i <= endIndex; i++) {
      final node = doc.nodeAt(i);
      if (node is! TextNode) continue;

      final int rangeStart;
      final int rangeEnd;

      if (i == startIndex && i == endIndex) {
        rangeStart = (startPos.nodePosition as TextNodePosition).offset;
        rangeEnd = (endPos.nodePosition as TextNodePosition).offset - 1;
      } else if (i == startIndex) {
        rangeStart = (startPos.nodePosition as TextNodePosition).offset;
        rangeEnd = node.text.length - 1;
      } else if (i == endIndex) {
        rangeStart = 0;
        rangeEnd = (endPos.nodePosition as TextNodePosition).offset - 1;
      } else {
        rangeStart = 0;
        rangeEnd = node.text.length - 1;
      }

      if (rangeStart > rangeEnd || rangeEnd < 0) continue;

      final newText = node.text.removeAttribution(attribution, rangeStart, rangeEnd);
      doc.updateNode(node.id, (n) => (n as TextNode).copyWith(text: newText));
      events.add(TextChanged(nodeId: node.id));
    }

    return events;
  }
}

// ---------------------------------------------------------------------------
// ConvertListItemToParagraphCommand
// ---------------------------------------------------------------------------

/// Converts a [ListItemNode] into a plain [ParagraphNode], preserving
/// the node's id, text, and metadata.
///
/// This command is used when the user presses Enter or Backspace on an empty
/// list item, effectively exiting the list.
///
/// Throws [StateError] when [nodeId] does not exist or is not a
/// [ListItemNode].
class ConvertListItemToParagraphCommand extends EditCommand {
  /// Creates a [ConvertListItemToParagraphCommand].
  const ConvertListItemToParagraphCommand({required this.nodeId});

  /// The id of the list item node to convert.
  final String nodeId;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final node = context.document.nodeById(nodeId);
    if (node == null) {
      throw StateError('ConvertListItemToParagraphCommand: no node with id "$nodeId".');
    }
    if (node is! ListItemNode) {
      throw StateError(
        'ConvertListItemToParagraphCommand: node "$nodeId" is not a ListItemNode.',
      );
    }

    final paragraph = ParagraphNode(
      id: node.id,
      text: node.text,
      textAlign: node.textAlign,
      metadata: node.metadata,
    );
    context.document.replaceNode(nodeId, paragraph);

    // Collapse the caret to offset 0 of the (now paragraph) node.
    context.controller.setSelection(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ),
    );

    return [NodeReplaced(oldNodeId: nodeId, newNodeId: nodeId)];
  }
}

// ---------------------------------------------------------------------------
// IndentListItemCommand
// ---------------------------------------------------------------------------

/// Increases the indent level of the [ListItemNode] identified by [nodeId] by
/// one step.
///
/// The node's [ListItemNode.indent] is incremented by 1 and the node is
/// replaced in the document via [MutableDocument.replaceNode]. No maximum
/// nesting depth is enforced; callers are responsible for applying any
/// upper-bound policy before submitting this command.
///
/// Returns a [NodeReplaced] event with identical [oldNodeId] and [newNodeId].
///
/// Throws [StateError] when [nodeId] does not exist or is not a
/// [ListItemNode].
class IndentListItemCommand extends EditCommand {
  /// Creates an [IndentListItemCommand].
  const IndentListItemCommand({required this.nodeId});

  /// The id of the [ListItemNode] to indent.
  final String nodeId;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final node = context.document.nodeById(nodeId);
    if (node == null) {
      throw StateError('IndentListItemCommand: no node with id "$nodeId".');
    }
    if (node is! ListItemNode) {
      throw StateError('IndentListItemCommand: node "$nodeId" is not a ListItemNode.');
    }

    context.document.replaceNode(nodeId, node.copyWith(indent: node.indent + 1));
    return [NodeReplaced(oldNodeId: nodeId, newNodeId: nodeId)];
  }
}

// ---------------------------------------------------------------------------
// UnindentListItemCommand
// ---------------------------------------------------------------------------

/// Decreases the indent level of the [ListItemNode] identified by [nodeId] by
/// one step, clamped to a minimum of `0`.
///
/// The node's [ListItemNode.indent] is decremented by 1 (floor `0`) and the
/// node is replaced in the document via [MutableDocument.replaceNode].
///
/// Returns a [NodeReplaced] event with identical [oldNodeId] and [newNodeId].
///
/// Throws [StateError] when [nodeId] does not exist or is not a
/// [ListItemNode].
class UnindentListItemCommand extends EditCommand {
  /// Creates an [UnindentListItemCommand].
  const UnindentListItemCommand({required this.nodeId});

  /// The id of the [ListItemNode] to unindent.
  final String nodeId;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final node = context.document.nodeById(nodeId);
    if (node == null) {
      throw StateError('UnindentListItemCommand: no node with id "$nodeId".');
    }
    if (node is! ListItemNode) {
      throw StateError('UnindentListItemCommand: node "$nodeId" is not a ListItemNode.');
    }

    final newIndent = (node.indent - 1).clamp(0, node.indent);
    context.document.replaceNode(nodeId, node.copyWith(indent: newIndent));
    return [NodeReplaced(oldNodeId: nodeId, newNodeId: nodeId)];
  }
}

// ---------------------------------------------------------------------------
// ExitCodeBlockCommand
// ---------------------------------------------------------------------------

/// Exits a [CodeBlockNode] by converting it to — or splitting it into — a
/// plain [ParagraphNode].
///
/// ### Algorithm
///
/// 1. If [removeTrailingNewline] and the character at `splitOffset - 1` is
///    `'\n'`, decrement the effective offset by one.
/// 2. Compute `codeText = text[0, effectiveOffset)` and
///    `remainingText = text[splitOffset, end)`.
/// 3. If `codeText` is empty: **convert in place** — replace the
///    [CodeBlockNode] with a [ParagraphNode] carrying `remainingText`.
/// 4. Otherwise: **split** — truncate the code block to `codeText` and
///    insert a new [ParagraphNode] with `remainingText` after it.
/// 5. Collapse the selection to offset 0 of the (new or converted)
///    paragraph.
///
/// Throws [StateError] when [nodeId] does not exist or is not a
/// [CodeBlockNode].
class ExitCodeBlockCommand extends EditCommand {
  /// Creates an [ExitCodeBlockCommand].
  const ExitCodeBlockCommand({
    required this.nodeId,
    required this.splitOffset,
    this.removeTrailingNewline = false,
  });

  /// The id of the code block node to exit.
  final String nodeId;

  /// The character offset at which to split.
  final int splitOffset;

  /// Whether to consume a trailing newline before the split offset.
  final bool removeTrailingNewline;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final node = context.document.nodeById(nodeId);
    if (node == null) {
      throw StateError('ExitCodeBlockCommand: no node with id "$nodeId".');
    }
    if (node is! CodeBlockNode) {
      throw StateError('ExitCodeBlockCommand: node "$nodeId" is not a CodeBlockNode.');
    }

    // 1. Compute effective split offset.
    var effectiveOffset = splitOffset;
    if (removeTrailingNewline &&
        effectiveOffset > 0 &&
        node.text.text[effectiveOffset - 1] == '\n') {
      effectiveOffset -= 1;
    }

    // 2. Split the text.
    final codeText = node.text.copyText(0, effectiveOffset);
    final remainingText = node.text.copyText(splitOffset);

    if (codeText.text.isEmpty) {
      // 3. Convert in place — replace CodeBlockNode with ParagraphNode.
      final paragraph = ParagraphNode(
        id: node.id,
        text: remainingText,
        metadata: node.metadata,
      );
      context.document.replaceNode(nodeId, paragraph);

      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: nodeId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );

      return [NodeReplaced(oldNodeId: nodeId, newNodeId: nodeId)];
    }

    // 4. Split — truncate code block, insert paragraph after.
    context.document.updateNode(
      nodeId,
      (n) => (n as CodeBlockNode).copyWith(text: codeText),
    );

    final newId = generateNodeId();
    final paragraph = ParagraphNode(id: newId, text: remainingText);
    final insertIndex = context.document.getNodeIndexById(nodeId) + 1;
    context.document.insertNode(insertIndex, paragraph);

    context.controller.setSelection(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: newId,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ),
    );

    return [
      TextChanged(nodeId: nodeId),
      NodeInserted(nodeId: newId, index: insertIndex),
    ];
  }
}

// ---------------------------------------------------------------------------
// ExitBlockquoteCommand
// ---------------------------------------------------------------------------

/// Exits a [BlockquoteNode] by converting it to — or splitting it into — a
/// plain [ParagraphNode].
///
/// ### Algorithm
///
/// 1. If [removeTrailingNewline] and the character at `splitOffset - 1` is
///    `'\n'`, decrement the effective offset by one.
/// 2. Compute `blockquoteText = text[0, effectiveOffset)` and
///    `remainingText = text[splitOffset, end)`.
/// 3. If `blockquoteText` is empty: **convert in place** — replace the
///    [BlockquoteNode] with a [ParagraphNode] carrying `remainingText`.
/// 4. Otherwise: **split** — truncate the blockquote to `blockquoteText` and
///    insert a new [ParagraphNode] with `remainingText` after it.
/// 5. Collapse the selection to offset 0 of the (new or converted)
///    paragraph.
///
/// Throws [StateError] when [nodeId] does not exist or is not a
/// [BlockquoteNode].
class ExitBlockquoteCommand extends EditCommand {
  /// Creates an [ExitBlockquoteCommand].
  const ExitBlockquoteCommand({
    required this.nodeId,
    required this.splitOffset,
    this.removeTrailingNewline = false,
  });

  /// The id of the blockquote node to exit.
  final String nodeId;

  /// The character offset at which to split.
  final int splitOffset;

  /// Whether to consume a trailing newline before the split offset.
  final bool removeTrailingNewline;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final node = context.document.nodeById(nodeId);
    if (node == null) {
      throw StateError('ExitBlockquoteCommand: no node with id "$nodeId".');
    }
    if (node is! BlockquoteNode) {
      throw StateError('ExitBlockquoteCommand: node "$nodeId" is not a BlockquoteNode.');
    }

    // 1. Compute effective split offset.
    var effectiveOffset = splitOffset;
    if (removeTrailingNewline &&
        effectiveOffset > 0 &&
        node.text.text[effectiveOffset - 1] == '\n') {
      effectiveOffset -= 1;
    }

    // 2. Split the text.
    final blockquoteText = node.text.copyText(0, effectiveOffset);
    final remainingText = node.text.copyText(splitOffset);

    if (blockquoteText.text.isEmpty) {
      // 3. Convert in place — replace BlockquoteNode with ParagraphNode.
      final paragraph = ParagraphNode(
        id: node.id,
        text: remainingText,
        metadata: node.metadata,
      );
      context.document.replaceNode(nodeId, paragraph);

      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: nodeId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );

      return [NodeReplaced(oldNodeId: nodeId, newNodeId: nodeId)];
    }

    // 4. Split — truncate blockquote, insert paragraph after.
    context.document.updateNode(
      nodeId,
      (n) => (n as BlockquoteNode).copyWith(text: blockquoteText),
    );

    final newId = generateNodeId();
    final paragraph = ParagraphNode(id: newId, text: remainingText);
    final insertIndex = context.document.getNodeIndexById(nodeId) + 1;
    context.document.insertNode(insertIndex, paragraph);

    context.controller.setSelection(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: newId,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ),
    );

    return [
      TextChanged(nodeId: nodeId),
      NodeInserted(nodeId: newId, index: insertIndex),
    ];
  }
}

// ---------------------------------------------------------------------------
// InsertTextAtBinaryNodeCommand
// ---------------------------------------------------------------------------

/// Inserts text at a binary-position node by finding or creating an
/// adjacent [ParagraphNode].
///
/// ### Behavior
///
/// | Caret position | Adjacent node exists? | Action |
/// |---|---|---|
/// | **Upstream** | Previous is [TextNode] | Append text to end of previous node |
/// | **Upstream** | No previous [TextNode] | Create new [ParagraphNode] before binary node |
/// | **Downstream** | Next is [TextNode] | Prepend text to start of next node |
/// | **Downstream** | No next [TextNode] | Create new [ParagraphNode] after binary node |
/// | Either, text is `'\n'` | — | Create empty [ParagraphNode] adjacent, move caret there |
///
/// Throws [StateError] when [nodeId] does not exist in the document.
class InsertTextAtBinaryNodeCommand extends EditCommand {
  /// Creates an [InsertTextAtBinaryNodeCommand].
  const InsertTextAtBinaryNodeCommand({
    required this.nodeId,
    required this.nodePosition,
    required this.text,
  });

  /// The id of the binary node at which the caret sits.
  final String nodeId;

  /// Which edge of the binary node the caret occupies.
  final BinaryNodePositionType nodePosition;

  /// The rich text to insert adjacent to the binary node.
  final AttributedText text;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final node = doc.nodeById(nodeId);
    if (node == null) {
      throw StateError(
        'InsertTextAtBinaryNodeCommand: no node with id "$nodeId".',
      );
    }

    // Newline → always create an empty paragraph adjacent to the binary node.
    if (text.text == '\n') {
      return _handleNewline(context);
    }

    if (nodePosition == BinaryNodePositionType.upstream) {
      return _handleUpstreamInsert(context);
    } else {
      return _handleDownstreamInsert(context);
    }
  }

  List<DocumentChangeEvent> _handleNewline(EditContext context) {
    final doc = context.document;
    final newId = generateNodeId();
    final paragraph = ParagraphNode(id: newId, text: AttributedText());

    if (nodePosition == BinaryNodePositionType.upstream) {
      // Insert empty paragraph before the binary node.
      final insertIndex = doc.getNodeIndexById(nodeId);
      doc.insertNode(insertIndex, paragraph);

      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: newId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );

      return [NodeInserted(nodeId: newId, index: insertIndex)];
    } else {
      // Insert empty paragraph after the binary node.
      final insertIndex = doc.getNodeIndexById(nodeId) + 1;
      doc.insertNode(insertIndex, paragraph);

      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: newId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );

      return [NodeInserted(nodeId: newId, index: insertIndex)];
    }
  }

  List<DocumentChangeEvent> _handleUpstreamInsert(EditContext context) {
    final doc = context.document;
    final prevNode = doc.nodeBefore(nodeId);

    if (prevNode is TextNode) {
      // Append to end of previous text node.
      final insertOffset = prevNode.text.length;
      final newText = prevNode.text.insert(insertOffset, text);
      doc.updateNode(prevNode.id, (n) => (n as TextNode).copyWith(text: newText));

      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: prevNode.id,
            nodePosition: TextNodePosition(offset: insertOffset + text.length),
          ),
        ),
      );

      return [TextChanged(nodeId: prevNode.id)];
    } else {
      // No previous TextNode — create paragraph before binary node.
      final newId = generateNodeId();
      final paragraph = ParagraphNode(id: newId, text: text);
      final insertIndex = doc.getNodeIndexById(nodeId);
      doc.insertNode(insertIndex, paragraph);

      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: newId,
            nodePosition: TextNodePosition(offset: text.length),
          ),
        ),
      );

      return [NodeInserted(nodeId: newId, index: insertIndex)];
    }
  }

  List<DocumentChangeEvent> _handleDownstreamInsert(EditContext context) {
    final doc = context.document;
    final nextNode = doc.nodeAfter(nodeId);

    if (nextNode is TextNode) {
      // Prepend to start of next text node.
      final newText = nextNode.text.insert(0, text);
      doc.updateNode(nextNode.id, (n) => (n as TextNode).copyWith(text: newText));

      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: nextNode.id,
            nodePosition: TextNodePosition(offset: text.length),
          ),
        ),
      );

      return [TextChanged(nodeId: nextNode.id)];
    } else {
      // No next TextNode — create paragraph after binary node.
      final newId = generateNodeId();
      final paragraph = ParagraphNode(id: newId, text: text);
      final insertIndex = doc.getNodeIndexById(nodeId) + 1;
      doc.insertNode(insertIndex, paragraph);

      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: newId,
            nodePosition: TextNodePosition(offset: text.length),
          ),
        ),
      );

      return [NodeInserted(nodeId: newId, index: insertIndex)];
    }
  }
}

// ---------------------------------------------------------------------------
// InsertTableCommand
// ---------------------------------------------------------------------------

/// Inserts a new [TableNode] into the document.
///
/// Creates a [TableNode] with [rowCount] rows, [columnCount] columns, and all
/// cells initialised to empty [AttributedText]. The node is inserted at
/// [insertIndex] when non-null, or appended when [insertIndex] is `null`.
///
/// The controller selection is not changed by this command; callers should
/// update the selection to the desired cell after submission if needed.
class InsertTableCommand extends EditCommand {
  /// Creates an [InsertTableCommand].
  const InsertTableCommand({
    required this.nodeId,
    required this.rowCount,
    required this.columnCount,
    this.insertIndex,
  });

  /// The id to assign to the new [TableNode].
  final String nodeId;

  /// Number of rows in the table.
  final int rowCount;

  /// Number of columns in the table.
  final int columnCount;

  /// Insertion index, or `null` to append.
  final int? insertIndex;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;

    // Build empty cells grid.
    final cells = List<List<AttributedText>>.generate(
      rowCount,
      (_) => List<AttributedText>.generate(columnCount, (_) => AttributedText()),
    );

    final table = TableNode(
      id: nodeId,
      rowCount: rowCount,
      columnCount: columnCount,
      cells: cells,
    );

    final index = insertIndex ?? doc.nodeCount;
    doc.insertNode(index, table);

    return [NodeInserted(nodeId: nodeId, index: index)];
  }
}

// ---------------------------------------------------------------------------
// UpdateTableCellCommand
// ---------------------------------------------------------------------------

/// Updates the text of a single cell in a [TableNode].
///
/// Replaces the [AttributedText] at ([row], [col]) of the [TableNode]
/// identified by [nodeId] with [newText]. All other cells are unchanged.
///
/// When [newCursorOffset] is non-null, the controller selection is collapsed
/// to that character offset within the updated cell. The offset is clamped to
/// `[0, newText.length]`. When [newCursorOffset] is `null`, the selection is
/// left unchanged.
///
/// Throws [StateError] when [nodeId] does not exist or is not a [TableNode].
class UpdateTableCellCommand extends EditCommand {
  /// Creates an [UpdateTableCellCommand].
  const UpdateTableCellCommand({
    required this.nodeId,
    required this.row,
    required this.col,
    required this.newText,
    this.newCursorOffset,
  });

  /// The id of the target [TableNode].
  final String nodeId;

  /// Zero-based row index of the target cell.
  final int row;

  /// Zero-based column index of the target cell.
  final int col;

  /// The replacement text.
  final AttributedText newText;

  /// The character offset within the cell to place the cursor after the update,
  /// or `null` to leave the selection unchanged.
  final int? newCursorOffset;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final node = doc.nodeById(nodeId);
    if (node == null) {
      throw StateError('UpdateTableCellCommand: no node with id "$nodeId".');
    }
    if (node is! TableNode) {
      throw StateError('UpdateTableCellCommand: node "$nodeId" is not a TableNode.');
    }

    // Build a new cells grid with the target cell replaced.
    final newCells = List<List<AttributedText>>.generate(
      node.rowCount,
      (r) => List<AttributedText>.generate(
        node.columnCount,
        (c) => (r == row && c == col) ? newText : node.cellAt(r, c),
      ),
    );

    doc.replaceNode(nodeId, node.copyWith(cells: newCells));

    // Update the cursor position within the cell if requested.
    if (newCursorOffset != null) {
      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: nodeId,
            nodePosition: TableCellPosition(
              row: row,
              col: col,
              offset: newCursorOffset!.clamp(0, newText.length),
            ),
          ),
        ),
      );
    }

    return [NodeReplaced(oldNodeId: nodeId, newNodeId: nodeId)];
  }
}

// ---------------------------------------------------------------------------
// DeleteTableCommand
// ---------------------------------------------------------------------------

/// Deletes a [TableNode] from the document.
///
/// After deletion the controller selection is collapsed to the nearest
/// surviving node (previous preferred, then next), or cleared when the
/// document becomes empty.
///
/// Throws [StateError] when [nodeId] does not exist.
class DeleteTableCommand extends EditCommand {
  /// Creates a [DeleteTableCommand].
  const DeleteTableCommand({required this.nodeId});

  /// The id of the [TableNode] to delete.
  final String nodeId;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final node = doc.nodeById(nodeId);
    if (node == null) {
      throw StateError('DeleteTableCommand: no node with id "$nodeId".');
    }

    final prevNode = doc.nodeBefore(nodeId);
    final nextNode = doc.nodeAfter(nodeId);
    final nodeIndex = doc.getNodeIndexById(nodeId);
    doc.deleteNode(nodeId);

    if (prevNode is TextNode) {
      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: prevNode.id,
            nodePosition: TextNodePosition(offset: prevNode.text.length),
          ),
        ),
      );
    } else if (nextNode != null) {
      context.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: nextNode.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );
    } else {
      context.controller.clearSelection();
    }

    return [NodeDeleted(nodeId: nodeId, index: nodeIndex)];
  }
}

// ---------------------------------------------------------------------------
// MoveNodeToPositionCommand
// ---------------------------------------------------------------------------

/// Moves the block node identified by [nodeId] to the document location
/// described by [position].
///
/// ### Algorithm
///
/// 1. Validate [nodeId] exists; throw [StateError] otherwise.
/// 2. Validate [position.nodeId] exists; throw [StateError] otherwise.
/// 3. Remove the block from its current position.
/// 4. Determine the insertion index based on [position]:
///    - **[BinaryNodePosition.upstream]** — insert before the target node.
///    - **[BinaryNodePosition.downstream]** — insert after the target node.
///    - **[TextNodePosition] at offset 0** — insert before the target node.
///    - **[TextNodePosition] at offset >= text.length** — insert after the
///      target node.
///    - **[TextNodePosition] at mid-text offset** — split the target text node
///      at that offset, then insert the block between the two halves.
///      A fresh [ParagraphNode] is created for the text after the offset.
/// 5. The controller selection is set to the block node at its new position.
///
/// Throws [StateError] when [nodeId] or [position.nodeId] does not exist.
class MoveNodeToPositionCommand extends EditCommand {
  /// Creates a [MoveNodeToPositionCommand].
  const MoveNodeToPositionCommand({required this.nodeId, required this.position});

  /// The id of the block node to move.
  final String nodeId;

  /// The document position to move the block to.
  final DocumentPosition position;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;

    // 1. Validate the node to move.
    final nodeToMove = doc.nodeById(nodeId);
    if (nodeToMove == null) {
      throw StateError('MoveNodeToPositionCommand: no node with id "$nodeId".');
    }

    // 2. Validate the target position node.
    final targetNode = doc.nodeById(position.nodeId);
    if (targetNode == null) {
      throw StateError(
        'MoveNodeToPositionCommand: target node "${position.nodeId}" not found.',
      );
    }

    // Self-move is a no-op — the node is already at its own position.
    if (position.nodeId == nodeId) return [];

    final events = <DocumentChangeEvent>[];

    // 3. Remove the block from its current position.
    final oldIndex = doc.getNodeIndexById(nodeId);
    doc.deleteNode(nodeId);
    events.add(NodeDeleted(nodeId: nodeId, index: oldIndex));

    // After removal the target node index may have shifted.
    final targetIndex = doc.getNodeIndexById(position.nodeId);

    // 4. Determine the insertion index.
    final nodePosition = position.nodePosition;

    if (nodePosition is BinaryNodePosition) {
      final insertIndex =
          nodePosition.type == BinaryNodePositionType.upstream ? targetIndex : targetIndex + 1;
      doc.insertNode(insertIndex, nodeToMove);
      events.add(NodeInserted(nodeId: nodeId, index: insertIndex));
    } else if (nodePosition is TextNodePosition) {
      final textOffset = nodePosition.offset;

      if (targetNode is! TextNode) {
        // Target is not a text node — treat as if inserting after.
        final insertIndex = targetIndex + 1;
        doc.insertNode(insertIndex, nodeToMove);
        events.add(NodeInserted(nodeId: nodeId, index: insertIndex));
      } else {
        final textLength = targetNode.text.length;

        if (textOffset <= 0) {
          // Insert before target node.
          doc.insertNode(targetIndex, nodeToMove);
          events.add(NodeInserted(nodeId: nodeId, index: targetIndex));
        } else if (textOffset >= textLength) {
          // Insert after target node.
          final insertIndex = targetIndex + 1;
          doc.insertNode(insertIndex, nodeToMove);
          events.add(NodeInserted(nodeId: nodeId, index: insertIndex));
        } else {
          // Mid-text: split the target node, then insert the block between
          // the two halves.
          final firstText = targetNode.text.copyText(0, textOffset);
          final secondText = targetNode.text.copyText(textOffset);

          // Truncate the original node to text before offset.
          doc.updateNode(
            position.nodeId,
            (n) => (n as TextNode).copyWith(text: firstText),
          );
          events.add(TextChanged(nodeId: position.nodeId));

          // Insert the block immediately after the (now truncated) target.
          final blockInsertIndex = targetIndex + 1;
          doc.insertNode(blockInsertIndex, nodeToMove);
          events.add(NodeInserted(nodeId: nodeId, index: blockInsertIndex));

          // Insert a new paragraph node with the remaining text after the block.
          final newId = generateNodeId();
          final newParagraph = ParagraphNode(id: newId, text: secondText);
          final paragraphInsertIndex = blockInsertIndex + 1;
          doc.insertNode(paragraphInsertIndex, newParagraph);
          events.add(NodeInserted(nodeId: newId, index: paragraphInsertIndex));
        }
      }
    } else {
      // Unknown position type — fall back to appending at the end.
      final insertIndex = doc.nodeCount;
      doc.insertNode(insertIndex, nodeToMove);
      events.add(NodeInserted(nodeId: nodeId, index: insertIndex));
    }

    return events;
  }
}

// ---------------------------------------------------------------------------
// InsertNodeAtPositionCommand
// ---------------------------------------------------------------------------

/// Inserts a new [DocumentNode] at the document location described by
/// [position].
///
/// ### Algorithm
///
/// 1. If [position] is `null`, append [node] at the end of the document.
/// 2. Validate [position.nodeId] exists; throw [StateError] otherwise.
/// 3. Determine the insertion index based on [position]:
///    - **[BinaryNodePosition.upstream]** — insert before the target node.
///    - **[BinaryNodePosition.downstream]** — insert after the target node.
///    - **[TextNodePosition] at offset 0** — insert before the target node.
///    - **[TextNodePosition] at offset >= text.length** — insert after the
///      target node.
///    - **[TextNodePosition] at mid-text offset** — split the target text
///      node at that offset, then insert the node between the two halves.
/// 4. If [followOnNode] is non-null, insert it immediately after [node] — except
///    in the mid-text split case, where the remaining-text paragraph already
///    serves as a cursor landing spot.
class InsertNodeAtPositionCommand extends EditCommand {
  /// Creates an [InsertNodeAtPositionCommand].
  InsertNodeAtPositionCommand({
    required this.node,
    this.position,
    this.followOnNode,
  });

  /// The new node to insert.
  final DocumentNode node;

  /// Where to insert. If null, append to end of document.
  final DocumentPosition? position;

  /// Optional follow-on node inserted immediately after [node].
  final DocumentNode? followOnNode;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final events = <DocumentChangeEvent>[];

    // 1. No position — append at end.
    if (position == null) {
      final insertIndex = doc.nodeCount;
      doc.insertNode(insertIndex, node);
      events.add(NodeInserted(nodeId: node.id, index: insertIndex));
      _insertFollowOn(doc, events, insertIndex + 1);
      return events;
    }

    // 2. Validate the target position node.
    final targetNode = doc.nodeById(position!.nodeId);
    if (targetNode == null) {
      throw StateError(
        'InsertNodeAtPositionCommand: target node "${position!.nodeId}" not found.',
      );
    }

    final targetIndex = doc.getNodeIndexById(position!.nodeId);
    final nodePosition = position!.nodePosition;

    if (nodePosition is BinaryNodePosition) {
      final insertIndex =
          nodePosition.type == BinaryNodePositionType.upstream ? targetIndex : targetIndex + 1;
      doc.insertNode(insertIndex, node);
      events.add(NodeInserted(nodeId: node.id, index: insertIndex));
      _insertFollowOn(doc, events, insertIndex + 1);
    } else if (nodePosition is TextNodePosition) {
      final textOffset = nodePosition.offset;

      if (targetNode is! TextNode) {
        // Target is not a text node — treat as inserting after.
        final insertIndex = targetIndex + 1;
        doc.insertNode(insertIndex, node);
        events.add(NodeInserted(nodeId: node.id, index: insertIndex));
        _insertFollowOn(doc, events, insertIndex + 1);
      } else {
        final textLength = targetNode.text.length;

        if (textOffset <= 0) {
          // Insert before target node.
          doc.insertNode(targetIndex, node);
          events.add(NodeInserted(nodeId: node.id, index: targetIndex));
          _insertFollowOn(doc, events, targetIndex + 1);
        } else if (textOffset >= textLength) {
          // Insert after target node.
          final insertIndex = targetIndex + 1;
          doc.insertNode(insertIndex, node);
          events.add(NodeInserted(nodeId: node.id, index: insertIndex));
          _insertFollowOn(doc, events, insertIndex + 1);
        } else {
          // Mid-text: split the target node, then insert the new node between
          // the two halves. The remaining-text paragraph serves as the cursor
          // landing spot, so followOnNode is intentionally skipped here.
          final firstText = targetNode.text.copyText(0, textOffset);
          final secondText = targetNode.text.copyText(textOffset);

          // Truncate the original node to text before the offset.
          doc.updateNode(
            position!.nodeId,
            (n) => (n as TextNode).copyWith(text: firstText),
          );
          events.add(TextChanged(nodeId: position!.nodeId));

          // Insert the new node immediately after the (now truncated) target.
          final blockInsertIndex = targetIndex + 1;
          doc.insertNode(blockInsertIndex, node);
          events.add(NodeInserted(nodeId: node.id, index: blockInsertIndex));

          // New paragraph with remaining text.
          final newId = generateNodeId();
          final newParagraph = ParagraphNode(id: newId, text: secondText);
          final paragraphInsertIndex = blockInsertIndex + 1;
          doc.insertNode(paragraphInsertIndex, newParagraph);
          events.add(NodeInserted(nodeId: newId, index: paragraphInsertIndex));
        }
      }
    } else {
      // Unknown position type — fall back to appending at the end.
      final insertIndex = doc.nodeCount;
      doc.insertNode(insertIndex, node);
      events.add(NodeInserted(nodeId: node.id, index: insertIndex));
      _insertFollowOn(doc, events, insertIndex + 1);
    }

    return events;
  }

  void _insertFollowOn(
    MutableDocument doc,
    List<DocumentChangeEvent> events,
    int index,
  ) {
    if (followOnNode == null) return;
    doc.insertNode(index, followOnNode!);
    events.add(NodeInserted(nodeId: followOnNode!.id, index: index));
  }
}

// ---------------------------------------------------------------------------
// InsertTableRowCommand
// ---------------------------------------------------------------------------

/// Inserts an empty row into the [TableNode] identified by [nodeId].
///
/// When [insertBefore] is `true`, the new row is inserted at [rowIndex].
/// When `false`, it is inserted at `rowIndex + 1`.
///
/// If [TableNode.rowVerticalAligns] is non-null, a default
/// [TableVerticalAlignment.top] entry is inserted at the corresponding
/// position.
///
/// If the cursor is a [TableCellPosition] in this table and its row is at or
/// after the insertion point, the cursor row is incremented by one.
///
/// Returns a [NodeChangeEvent].
class InsertTableRowCommand extends EditCommand {
  /// Creates an [InsertTableRowCommand].
  const InsertTableRowCommand({
    required this.nodeId,
    required this.rowIndex,
    this.insertBefore = true,
  });

  /// The id of the target [TableNode].
  final String nodeId;

  /// The zero-based row index at which to insert.
  final int rowIndex;

  /// Whether to insert before (true) or after (false) [rowIndex].
  final bool insertBefore;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final node = doc.nodeById(nodeId);
    if (node == null) {
      throw StateError('InsertTableRowCommand: no node with id "$nodeId".');
    }
    if (node is! TableNode) {
      throw StateError('InsertTableRowCommand: node "$nodeId" is not a TableNode.');
    }

    final insertAt = insertBefore ? rowIndex : rowIndex + 1;

    // Build new cells list with an empty row inserted at insertAt.
    final newCells = <List<AttributedText>>[];
    for (int r = 0; r < node.rowCount; r++) {
      if (r == insertAt) {
        newCells.add(List<AttributedText>.generate(node.columnCount, (_) => AttributedText()));
      }
      newCells.add(List<AttributedText>.generate(node.columnCount, (c) => node.cellAt(r, c)));
    }
    if (insertAt >= node.rowCount) {
      newCells.add(List<AttributedText>.generate(node.columnCount, (_) => AttributedText()));
    }

    // Extend rowVerticalAligns if present.
    List<TableVerticalAlignment>? newRowVerticalAligns;
    if (node.rowVerticalAligns != null) {
      final aligns = List<TableVerticalAlignment>.of(node.rowVerticalAligns!);
      aligns.insert(insertAt.clamp(0, aligns.length), TableVerticalAlignment.top);
      newRowVerticalAligns = aligns;
    }

    final newTable = node.copyWith(
      rowCount: node.rowCount + 1,
      cells: newCells,
      rowVerticalAligns: newRowVerticalAligns,
    );
    doc.replaceNode(nodeId, newTable);

    // Adjust cursor if it is a TableCellPosition in this table.
    _shiftCursorRowIfNeeded(context, insertAt);

    return [NodeChangeEvent(nodeId: nodeId)];
  }

  void _shiftCursorRowIfNeeded(EditContext context, int insertAt) {
    final sel = context.controller.selection;
    if (sel == null) return;
    final pos = sel.base.nodePosition;
    if (sel.base.nodeId != nodeId) return;
    if (pos is! TableCellPosition) return;
    if (pos.row < insertAt) return;

    context.controller.setSelection(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: pos.copyWith(row: pos.row + 1),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// InsertTableColumnCommand
// ---------------------------------------------------------------------------

/// Inserts an empty column into the [TableNode] identified by [nodeId].
///
/// When [insertBefore] is `true`, the new column is inserted at [colIndex].
/// When `false`, it is inserted at `colIndex + 1`.
///
/// If [TableNode.columnWidths] is non-null, a `null` entry (auto-sized) is
/// inserted at the corresponding position.
///
/// If [TableNode.columnTextAligns] is non-null, a [TextAlign.start] entry is
/// inserted at the corresponding position.
///
/// If the cursor is a [TableCellPosition] in this table and its column is at
/// or after the insertion point, the cursor column is incremented by one.
///
/// Returns a [NodeChangeEvent].
class InsertTableColumnCommand extends EditCommand {
  /// Creates an [InsertTableColumnCommand].
  const InsertTableColumnCommand({
    required this.nodeId,
    required this.colIndex,
    this.insertBefore = true,
  });

  /// The id of the target [TableNode].
  final String nodeId;

  /// The zero-based column index at which to insert.
  final int colIndex;

  /// Whether to insert before (true) or after (false) [colIndex].
  final bool insertBefore;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final node = doc.nodeById(nodeId);
    if (node == null) {
      throw StateError('InsertTableColumnCommand: no node with id "$nodeId".');
    }
    if (node is! TableNode) {
      throw StateError('InsertTableColumnCommand: node "$nodeId" is not a TableNode.');
    }

    final insertAt = insertBefore ? colIndex : colIndex + 1;

    // Build new cells list with an empty column inserted at insertAt for each row.
    final newCells = List<List<AttributedText>>.generate(
      node.rowCount,
      (r) {
        final oldRow = List<AttributedText>.generate(node.columnCount, (c) => node.cellAt(r, c));
        final newRow = <AttributedText>[];
        for (int c = 0; c < node.columnCount; c++) {
          if (c == insertAt) {
            newRow.add(AttributedText());
          }
          newRow.add(oldRow[c]);
        }
        if (insertAt >= node.columnCount) {
          newRow.add(AttributedText());
        }
        return newRow;
      },
    );

    // Extend columnWidths if present.
    List<double?>? newColumnWidths;
    if (node.columnWidths != null) {
      final widths = List<double?>.of(node.columnWidths!);
      widths.insert(insertAt.clamp(0, widths.length), null);
      newColumnWidths = widths;
    }

    // Extend columnTextAligns if present.
    List<TextAlign>? newColumnTextAligns;
    if (node.columnTextAligns != null) {
      final aligns = List<TextAlign>.of(node.columnTextAligns!);
      aligns.insert(insertAt.clamp(0, aligns.length), TextAlign.start);
      newColumnTextAligns = aligns;
    }

    final newTable = node.copyWith(
      columnCount: node.columnCount + 1,
      cells: newCells,
      columnWidths: newColumnWidths,
      columnTextAligns: newColumnTextAligns,
    );
    doc.replaceNode(nodeId, newTable);

    // Adjust cursor if it is a TableCellPosition in this table.
    _shiftCursorColIfNeeded(context, insertAt);

    return [NodeChangeEvent(nodeId: nodeId)];
  }

  void _shiftCursorColIfNeeded(EditContext context, int insertAt) {
    final sel = context.controller.selection;
    if (sel == null) return;
    final pos = sel.base.nodePosition;
    if (sel.base.nodeId != nodeId) return;
    if (pos is! TableCellPosition) return;
    if (pos.col < insertAt) return;

    context.controller.setSelection(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: pos.copyWith(col: pos.col + 1),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DeleteTableRowCommand
// ---------------------------------------------------------------------------

/// Deletes a row from the [TableNode] identified by [nodeId].
///
/// When the table has only one row, the entire [TableNode] is deleted from
/// the document (same behaviour as [DeleteTableCommand]).
///
/// If [TableNode.rowVerticalAligns] is non-null, the corresponding entry is
/// removed.
///
/// If the cursor is at the deleted row, it is moved to the previous row, or
/// row 0 when deleting row 0.
///
/// Returns a [NodeChangeEvent] (or a [NodeDeleted] event when the whole table
/// is removed).
class DeleteTableRowCommand extends EditCommand {
  /// Creates a [DeleteTableRowCommand].
  const DeleteTableRowCommand({required this.nodeId, required this.rowIndex});

  /// The id of the target [TableNode].
  final String nodeId;

  /// The zero-based row index to delete.
  final int rowIndex;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final node = doc.nodeById(nodeId);
    if (node == null) {
      throw StateError('DeleteTableRowCommand: no node with id "$nodeId".');
    }
    if (node is! TableNode) {
      throw StateError('DeleteTableRowCommand: node "$nodeId" is not a TableNode.');
    }

    // If only one row, delete the entire table.
    if (node.rowCount == 1) {
      final prevNode = doc.nodeBefore(nodeId);
      final nextNode = doc.nodeAfter(nodeId);
      final nodeIndex = doc.getNodeIndexById(nodeId);
      doc.deleteNode(nodeId);

      if (prevNode is TextNode) {
        context.controller.setSelection(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: prevNode.id,
              nodePosition: TextNodePosition(offset: prevNode.text.length),
            ),
          ),
        );
      } else if (nextNode != null) {
        context.controller.setSelection(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nextNode.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      } else {
        context.controller.clearSelection();
      }
      return [NodeDeleted(nodeId: nodeId, index: nodeIndex)];
    }

    // Build new cells list without the deleted row.
    final newCells = <List<AttributedText>>[];
    for (int r = 0; r < node.rowCount; r++) {
      if (r == rowIndex) continue;
      newCells.add(List<AttributedText>.generate(node.columnCount, (c) => node.cellAt(r, c)));
    }

    // Trim rowVerticalAligns if present.
    List<TableVerticalAlignment>? newRowVerticalAligns;
    if (node.rowVerticalAligns != null) {
      final aligns = List<TableVerticalAlignment>.of(node.rowVerticalAligns!);
      aligns.removeAt(rowIndex.clamp(0, aligns.length - 1));
      newRowVerticalAligns = aligns;
    }

    final newTable = node.copyWith(
      rowCount: node.rowCount - 1,
      cells: newCells,
      rowVerticalAligns: newRowVerticalAligns,
    );
    doc.replaceNode(nodeId, newTable);

    // Adjust cursor.
    _adjustCursorAfterRowDelete(context, newTable);

    return [NodeChangeEvent(nodeId: nodeId)];
  }

  void _adjustCursorAfterRowDelete(EditContext context, TableNode newTable) {
    final sel = context.controller.selection;
    if (sel == null) return;
    final pos = sel.base.nodePosition;
    if (sel.base.nodeId != nodeId) return;
    if (pos is! TableCellPosition) return;
    if (pos.row != rowIndex) return;

    final newRow = (rowIndex - 1).clamp(0, newTable.rowCount - 1);
    final cellLength = newTable.cellAt(newRow, pos.col).text.length;
    context.controller.setSelection(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: pos.copyWith(row: newRow, offset: pos.offset.clamp(0, cellLength)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DeleteTableColumnCommand
// ---------------------------------------------------------------------------

/// Deletes a column from the [TableNode] identified by [nodeId].
///
/// When the table has only one column, the entire [TableNode] is deleted from
/// the document.
///
/// If [TableNode.columnWidths] or [TableNode.columnTextAligns] is non-null,
/// the corresponding entry is removed.
///
/// If the cursor is at the deleted column, it is moved to the previous column,
/// or column 0 when deleting column 0.
///
/// Returns a [NodeChangeEvent] (or a [NodeDeleted] event when the whole table
/// is removed).
class DeleteTableColumnCommand extends EditCommand {
  /// Creates a [DeleteTableColumnCommand].
  const DeleteTableColumnCommand({required this.nodeId, required this.colIndex});

  /// The id of the target [TableNode].
  final String nodeId;

  /// The zero-based column index to delete.
  final int colIndex;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final node = doc.nodeById(nodeId);
    if (node == null) {
      throw StateError('DeleteTableColumnCommand: no node with id "$nodeId".');
    }
    if (node is! TableNode) {
      throw StateError('DeleteTableColumnCommand: node "$nodeId" is not a TableNode.');
    }

    // If only one column, delete the entire table.
    if (node.columnCount == 1) {
      final prevNode = doc.nodeBefore(nodeId);
      final nextNode = doc.nodeAfter(nodeId);
      final nodeIndex = doc.getNodeIndexById(nodeId);
      doc.deleteNode(nodeId);

      if (prevNode is TextNode) {
        context.controller.setSelection(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: prevNode.id,
              nodePosition: TextNodePosition(offset: prevNode.text.length),
            ),
          ),
        );
      } else if (nextNode != null) {
        context.controller.setSelection(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nextNode.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      } else {
        context.controller.clearSelection();
      }
      return [NodeDeleted(nodeId: nodeId, index: nodeIndex)];
    }

    // Build new cells list without the deleted column.
    final newCells = List<List<AttributedText>>.generate(
      node.rowCount,
      (r) {
        final newRow = <AttributedText>[];
        for (int c = 0; c < node.columnCount; c++) {
          if (c == colIndex) continue;
          newRow.add(node.cellAt(r, c));
        }
        return newRow;
      },
    );

    // Trim columnWidths if present.
    List<double?>? newColumnWidths;
    if (node.columnWidths != null) {
      final widths = List<double?>.of(node.columnWidths!);
      widths.removeAt(colIndex.clamp(0, widths.length - 1));
      newColumnWidths = widths;
    }

    // Trim columnTextAligns if present.
    List<TextAlign>? newColumnTextAligns;
    if (node.columnTextAligns != null) {
      final aligns = List<TextAlign>.of(node.columnTextAligns!);
      aligns.removeAt(colIndex.clamp(0, aligns.length - 1));
      newColumnTextAligns = aligns;
    }

    final newTable = node.copyWith(
      columnCount: node.columnCount - 1,
      cells: newCells,
      columnWidths: newColumnWidths,
      columnTextAligns: newColumnTextAligns,
    );
    doc.replaceNode(nodeId, newTable);

    // Adjust cursor.
    _adjustCursorAfterColDelete(context, newTable);

    return [NodeChangeEvent(nodeId: nodeId)];
  }

  void _adjustCursorAfterColDelete(EditContext context, TableNode newTable) {
    final sel = context.controller.selection;
    if (sel == null) return;
    final pos = sel.base.nodePosition;
    if (sel.base.nodeId != nodeId) return;
    if (pos is! TableCellPosition) return;
    if (pos.col != colIndex) return;

    final newCol = (colIndex - 1).clamp(0, newTable.columnCount - 1);
    final cellLength = newTable.cellAt(pos.row, newCol).text.length;
    context.controller.setSelection(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: pos.copyWith(col: newCol, offset: pos.offset.clamp(0, cellLength)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ResizeTableCommand
// ---------------------------------------------------------------------------

/// Resizes a [TableNode] to [newRowCount] × [newColumnCount].
///
/// Cells are preserved when they fall within the new bounds; new cells are
/// initialised to empty [AttributedText]. Alignment lists are truncated or
/// extended to match the new dimensions; null alignment lists remain null.
///
/// The cursor is clamped to the new bounds if it was out of range.
///
/// Returns a [NodeChangeEvent].
class ResizeTableCommand extends EditCommand {
  /// Creates a [ResizeTableCommand].
  const ResizeTableCommand({
    required this.nodeId,
    required this.newRowCount,
    required this.newColumnCount,
  });

  /// The id of the target [TableNode].
  final String nodeId;

  /// The desired new number of rows.
  final int newRowCount;

  /// The desired new number of columns.
  final int newColumnCount;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final node = doc.nodeById(nodeId);
    if (node == null) {
      throw StateError('ResizeTableCommand: no node with id "$nodeId".');
    }
    if (node is! TableNode) {
      throw StateError('ResizeTableCommand: node "$nodeId" is not a TableNode.');
    }

    // Build new cells grid.
    final newCells = List<List<AttributedText>>.generate(
      newRowCount,
      (r) => List<AttributedText>.generate(
        newColumnCount,
        (c) => (r < node.rowCount && c < node.columnCount) ? node.cellAt(r, c) : AttributedText(),
      ),
    );

    // Adjust columnWidths.
    List<double?>? newColumnWidths;
    if (node.columnWidths != null) {
      final widths = List<double?>.of(node.columnWidths!);
      if (newColumnCount < widths.length) {
        newColumnWidths = widths.sublist(0, newColumnCount);
      } else {
        while (widths.length < newColumnCount) {
          widths.add(null);
        }
        newColumnWidths = widths;
      }
    }

    // Adjust columnTextAligns.
    List<TextAlign>? newColumnTextAligns;
    if (node.columnTextAligns != null) {
      final aligns = List<TextAlign>.of(node.columnTextAligns!);
      if (newColumnCount < aligns.length) {
        newColumnTextAligns = aligns.sublist(0, newColumnCount);
      } else {
        while (aligns.length < newColumnCount) {
          aligns.add(TextAlign.start);
        }
        newColumnTextAligns = aligns;
      }
    }

    // Adjust rowVerticalAligns.
    List<TableVerticalAlignment>? newRowVerticalAligns;
    if (node.rowVerticalAligns != null) {
      final aligns = List<TableVerticalAlignment>.of(node.rowVerticalAligns!);
      if (newRowCount < aligns.length) {
        newRowVerticalAligns = aligns.sublist(0, newRowCount);
      } else {
        while (aligns.length < newRowCount) {
          aligns.add(TableVerticalAlignment.top);
        }
        newRowVerticalAligns = aligns;
      }
    }

    final newTable = node.copyWith(
      rowCount: newRowCount,
      columnCount: newColumnCount,
      cells: newCells,
      columnWidths: newColumnWidths,
      columnTextAligns: newColumnTextAligns,
      rowVerticalAligns: newRowVerticalAligns,
    );
    doc.replaceNode(nodeId, newTable);

    // Clamp cursor if out of bounds.
    _clampCursor(context, newTable);

    return [NodeChangeEvent(nodeId: nodeId)];
  }

  void _clampCursor(EditContext context, TableNode newTable) {
    final sel = context.controller.selection;
    if (sel == null) return;
    final pos = sel.base.nodePosition;
    if (sel.base.nodeId != nodeId) return;
    if (pos is! TableCellPosition) return;

    final newRow = pos.row.clamp(0, newTable.rowCount - 1);
    final newCol = pos.col.clamp(0, newTable.columnCount - 1);
    final cellLength = newTable.cellAt(newRow, newCol).text.length;
    final newOffset = pos.offset.clamp(0, cellLength);
    if (newRow == pos.row && newCol == pos.col && newOffset == pos.offset) return;

    context.controller.setSelection(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: pos.copyWith(row: newRow, col: newCol, offset: newOffset),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ChangeTableColumnAlignCommand
// ---------------------------------------------------------------------------

/// Changes the horizontal text alignment of a column in the [TableNode]
/// identified by [nodeId].
///
/// If [TableNode.columnTextAligns] is `null`, it is initialised to
/// [TextAlign.start] for all columns before applying the change.
///
/// Returns a [NodeChangeEvent].
class ChangeTableColumnAlignCommand extends EditCommand {
  /// Creates a [ChangeTableColumnAlignCommand].
  const ChangeTableColumnAlignCommand({
    required this.nodeId,
    required this.colIndex,
    required this.textAlign,
  });

  /// The id of the target [TableNode].
  final String nodeId;

  /// The zero-based column index whose alignment to change.
  final int colIndex;

  /// The new horizontal text alignment.
  final TextAlign textAlign;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final node = doc.nodeById(nodeId);
    if (node == null) {
      throw StateError('ChangeTableColumnAlignCommand: no node with id "$nodeId".');
    }
    if (node is! TableNode) {
      throw StateError('ChangeTableColumnAlignCommand: node "$nodeId" is not a TableNode.');
    }

    final aligns = node.columnTextAligns != null
        ? List<TextAlign>.of(node.columnTextAligns!)
        : List<TextAlign>.filled(node.columnCount, TextAlign.start);
    aligns[colIndex] = textAlign;

    doc.replaceNode(nodeId, node.copyWith(columnTextAligns: aligns));
    return [NodeChangeEvent(nodeId: nodeId)];
  }
}

// ---------------------------------------------------------------------------
// ChangeTableRowVerticalAlignCommand
// ---------------------------------------------------------------------------

/// Changes the vertical alignment of a row in the [TableNode] identified by
/// [nodeId].
///
/// If [TableNode.rowVerticalAligns] is `null`, it is initialised to
/// [TableVerticalAlignment.top] for all rows before applying the change.
///
/// Returns a [NodeChangeEvent].
class ChangeTableRowVerticalAlignCommand extends EditCommand {
  /// Creates a [ChangeTableRowVerticalAlignCommand].
  const ChangeTableRowVerticalAlignCommand({
    required this.nodeId,
    required this.rowIndex,
    required this.verticalAlign,
  });

  /// The id of the target [TableNode].
  final String nodeId;

  /// The zero-based row index whose vertical alignment to change.
  final int rowIndex;

  /// The new vertical alignment.
  final TableVerticalAlignment verticalAlign;

  @override
  List<DocumentChangeEvent> execute(EditContext context) {
    final doc = context.document;
    final node = doc.nodeById(nodeId);
    if (node == null) {
      throw StateError('ChangeTableRowVerticalAlignCommand: no node with id "$nodeId".');
    }
    if (node is! TableNode) {
      throw StateError('ChangeTableRowVerticalAlignCommand: node "$nodeId" is not a TableNode.');
    }

    final aligns = node.rowVerticalAligns != null
        ? List<TableVerticalAlignment>.of(node.rowVerticalAligns!)
        : List<TableVerticalAlignment>.filled(node.rowCount, TableVerticalAlignment.top);
    aligns[rowIndex] = verticalAlign;

    doc.replaceNode(nodeId, node.copyWith(rowVerticalAligns: aligns));
    return [NodeChangeEvent(nodeId: nodeId)];
  }
}
