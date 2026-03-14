/// Edit command implementations for the editable_document command architecture.
///
/// Each [EditCommand] corresponds to an [EditRequest] and carries out the
/// actual mutation of a [MutableDocument] via the [EditContext].
///
/// Commands return a list of [DocumentChangeEvent]s describing every mutation
/// that occurred; the [Editor] accumulates these events and delivers them to
/// reactions and listeners.
library;

import 'attribution.dart';
import 'attributed_text.dart';
import 'blockquote_node.dart';
import 'code_block_node.dart';
import 'document_change_event.dart';
import 'document_node.dart';
import 'document_position.dart';
import 'document_selection.dart';
import 'edit_context.dart';
import 'list_item_node.dart';
import 'node_position.dart';
import 'paragraph_node.dart';
import 'table_node.dart';
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
/// Throws [StateError] when [nodeId] does not exist or is not a [TableNode].
class UpdateTableCellCommand extends EditCommand {
  /// Creates an [UpdateTableCellCommand].
  const UpdateTableCellCommand({
    required this.nodeId,
    required this.row,
    required this.col,
    required this.newText,
  });

  /// The id of the target [TableNode].
  final String nodeId;

  /// Zero-based row index of the target cell.
  final int row;

  /// Zero-based column index of the target cell.
  final int col;

  /// The replacement text.
  final AttributedText newText;

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
