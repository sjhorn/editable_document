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
import 'document_change_event.dart';
import 'document_node.dart';
import 'document_position.dart';
import 'document_selection.dart';
import 'edit_context.dart';
import 'list_item_node.dart';
import 'node_position.dart';
import 'paragraph_node.dart';
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
