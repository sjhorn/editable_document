/// Edit request value types for the editable_document command architecture.
///
/// An [EditRequest] is an immutable description of a desired mutation. Requests
/// are submitted to an [Editor], which maps each one to an [EditCommand] for
/// execution.
///
/// Requests are dispatched by the [Editor] via a type-check chain that covers
/// every concrete subtype defined in this file.
library;

import 'dart:ui' show TextAlign;

import 'attribution.dart';
import 'attributed_text.dart';
import 'document_node.dart';
import 'document_position.dart';
import 'document_selection.dart';
import 'node_position.dart';
import 'paragraph_node.dart';
import 'table_node.dart';

// ---------------------------------------------------------------------------
// EditRequest (abstract base)
// ---------------------------------------------------------------------------

/// Abstract base class for all edit requests.
///
/// An [EditRequest] describes *what* should happen to a document; the
/// corresponding [EditCommand] knows *how* to carry it out.
///
/// Submit requests through [Editor.submit]. Do not execute them directly.
abstract class EditRequest {
  /// Creates an [EditRequest].
  const EditRequest();
}

// ---------------------------------------------------------------------------
// InsertTextRequest
// ---------------------------------------------------------------------------

/// Request to insert [text] into a text node at [offset].
///
/// The node identified by [nodeId] must exist in the document and must be a
/// text-bearing node. The [text] is inserted immediately before the character
/// currently at [offset] (i.e., offset 0 prepends, `text.length` appends).
class InsertTextRequest extends EditRequest {
  /// Creates an [InsertTextRequest].
  const InsertTextRequest({
    required this.nodeId,
    required this.offset,
    required this.text,
  });

  /// The id of the target [TextNode].
  final String nodeId;

  /// The character offset within the node at which to insert.
  final int offset;

  /// The rich text to insert.
  final AttributedText text;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InsertTextRequest &&
        other.nodeId == nodeId &&
        other.offset == offset &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(nodeId, offset, text);

  @override
  String toString() => 'InsertTextRequest(nodeId: $nodeId, offset: $offset, text: $text)';
}

// ---------------------------------------------------------------------------
// DeleteContentRequest
// ---------------------------------------------------------------------------

/// Request to delete the content covered by [selection].
///
/// If [selection] is collapsed the command is a no-op. For expanded selections
/// the content between [DocumentSelection.base] and [DocumentSelection.extent]
/// is removed; text nodes at the boundary are merged if both endpoints fall
/// inside text nodes.
class DeleteContentRequest extends EditRequest {
  /// Creates a [DeleteContentRequest].
  const DeleteContentRequest({required this.selection});

  /// The selection whose content will be deleted.
  final DocumentSelection selection;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeleteContentRequest && other.selection == selection;
  }

  @override
  int get hashCode => selection.hashCode;

  @override
  String toString() => 'DeleteContentRequest(selection: $selection)';
}

// ---------------------------------------------------------------------------
// ReplaceNodeRequest
// ---------------------------------------------------------------------------

/// Request to replace the node identified by [nodeId] with [newNode].
///
/// The replacement is inserted at the same index. The [newNode] may have a
/// different id than [nodeId].
class ReplaceNodeRequest extends EditRequest {
  /// Creates a [ReplaceNodeRequest].
  const ReplaceNodeRequest({required this.nodeId, required this.newNode});

  /// The id of the node to replace.
  final String nodeId;

  /// The node to put in its place.
  final DocumentNode newNode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReplaceNodeRequest && other.nodeId == nodeId && other.newNode == newNode;
  }

  @override
  int get hashCode => Object.hash(nodeId, newNode);

  @override
  String toString() => 'ReplaceNodeRequest(nodeId: $nodeId, newNode: $newNode)';
}

// ---------------------------------------------------------------------------
// SplitParagraphRequest
// ---------------------------------------------------------------------------

/// Request to split the text node [nodeId] at [splitOffset].
///
/// The original node retains text `[0, splitOffset)` and a freshly generated
/// node is inserted immediately after with text `[splitOffset, end)`. Both
/// nodes preserve the block type of the original.
class SplitParagraphRequest extends EditRequest {
  /// Creates a [SplitParagraphRequest].
  const SplitParagraphRequest({required this.nodeId, required this.splitOffset});

  /// The id of the node to split.
  final String nodeId;

  /// The character offset at which to split.
  ///
  /// Characters before this offset remain in the original node; characters
  /// from this offset onward move to the new node.
  final int splitOffset;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SplitParagraphRequest &&
        other.nodeId == nodeId &&
        other.splitOffset == splitOffset;
  }

  @override
  int get hashCode => Object.hash(nodeId, splitOffset);

  @override
  String toString() => 'SplitParagraphRequest(nodeId: $nodeId, splitOffset: $splitOffset)';
}

// ---------------------------------------------------------------------------
// MergeNodeRequest
// ---------------------------------------------------------------------------

/// Request to merge two adjacent text nodes.
///
/// The [secondNodeId] node's text is appended to [firstNodeId]'s text, then
/// [secondNodeId] is deleted from the document. Both nodes must be text-bearing.
class MergeNodeRequest extends EditRequest {
  /// Creates a [MergeNodeRequest].
  const MergeNodeRequest({required this.firstNodeId, required this.secondNodeId});

  /// The id of the node that will absorb the second node's text.
  final String firstNodeId;

  /// The id of the node that will be deleted after merging.
  final String secondNodeId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MergeNodeRequest &&
        other.firstNodeId == firstNodeId &&
        other.secondNodeId == secondNodeId;
  }

  @override
  int get hashCode => Object.hash(firstNodeId, secondNodeId);

  @override
  String toString() => 'MergeNodeRequest(firstNodeId: $firstNodeId, secondNodeId: $secondNodeId)';
}

// ---------------------------------------------------------------------------
// MoveNodeRequest
// ---------------------------------------------------------------------------

/// Request to move the node identified by [nodeId] to [newIndex].
///
/// [newIndex] is relative to the list after the node has been removed from its
/// current position, matching [MutableDocument.moveNode] semantics.
class MoveNodeRequest extends EditRequest {
  /// Creates a [MoveNodeRequest].
  const MoveNodeRequest({required this.nodeId, required this.newIndex});

  /// The id of the node to move.
  final String nodeId;

  /// The target zero-based index (post-removal).
  final int newIndex;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoveNodeRequest && other.nodeId == nodeId && other.newIndex == newIndex;
  }

  @override
  int get hashCode => Object.hash(nodeId, newIndex);

  @override
  String toString() => 'MoveNodeRequest(nodeId: $nodeId, newIndex: $newIndex)';
}

// ---------------------------------------------------------------------------
// ChangeBlockTypeRequest
// ---------------------------------------------------------------------------

/// Request to change the [ParagraphBlockType] of a [ParagraphNode].
///
/// The node identified by [nodeId] must be a [ParagraphNode].
class ChangeBlockTypeRequest extends EditRequest {
  /// Creates a [ChangeBlockTypeRequest].
  const ChangeBlockTypeRequest({required this.nodeId, required this.newBlockType});

  /// The id of the [ParagraphNode] to update.
  final String nodeId;

  /// The new block type to apply.
  final ParagraphBlockType newBlockType;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChangeBlockTypeRequest &&
        other.nodeId == nodeId &&
        other.newBlockType == newBlockType;
  }

  @override
  int get hashCode => Object.hash(nodeId, newBlockType);

  @override
  String toString() => 'ChangeBlockTypeRequest(nodeId: $nodeId, newBlockType: $newBlockType)';
}

// ---------------------------------------------------------------------------
// ChangeTextAlignRequest
// ---------------------------------------------------------------------------

/// Request to change the [TextAlign] of a text block node.
///
/// The node identified by [nodeId] must be a [ParagraphNode],
/// [ListItemNode], or [BlockquoteNode]. Other node types will cause the
/// corresponding command to throw a [StateError].
class ChangeTextAlignRequest extends EditRequest {
  /// Creates a [ChangeTextAlignRequest].
  const ChangeTextAlignRequest({required this.nodeId, required this.newTextAlign});

  /// The id of the text block node to update.
  final String nodeId;

  /// The new text alignment to apply.
  final TextAlign newTextAlign;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChangeTextAlignRequest &&
        other.nodeId == nodeId &&
        other.newTextAlign == newTextAlign;
  }

  @override
  int get hashCode => Object.hash(nodeId, newTextAlign);

  @override
  String toString() => 'ChangeTextAlignRequest(nodeId: $nodeId, newTextAlign: $newTextAlign)';
}

// ---------------------------------------------------------------------------
// ChangeLineHeightRequest
// ---------------------------------------------------------------------------

/// Request to change the line height multiplier of a text block node.
///
/// The node identified by [nodeId] must be a [ParagraphNode],
/// [ListItemNode], [BlockquoteNode], or [CodeBlockNode]. Other node types
/// will cause the corresponding command to throw a [StateError].
///
/// A [newLineHeight] of `null` resets the block to inherit the document
/// default line height.
class ChangeLineHeightRequest extends EditRequest {
  /// Creates a [ChangeLineHeightRequest].
  const ChangeLineHeightRequest({required this.nodeId, required this.newLineHeight});

  /// The id of the text block node to update.
  final String nodeId;

  /// The new line height multiplier to apply, or `null` to inherit the
  /// document default.
  final double? newLineHeight;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChangeLineHeightRequest &&
        other.nodeId == nodeId &&
        other.newLineHeight == newLineHeight;
  }

  @override
  int get hashCode => Object.hash(nodeId, newLineHeight);

  @override
  String toString() => 'ChangeLineHeightRequest(nodeId: $nodeId, newLineHeight: $newLineHeight)';
}

// ---------------------------------------------------------------------------
// ChangeIndentRequest
// ---------------------------------------------------------------------------

/// Request to change the indent properties of a text block node.
///
/// The node identified by [nodeId] must be a [ParagraphNode],
/// [ListItemNode], or [BlockquoteNode]. Only non-null values are applied.
/// For [ListItemNode], [newFirstLineIndent] is ignored.
class ChangeIndentRequest extends EditRequest {
  /// Creates a [ChangeIndentRequest].
  const ChangeIndentRequest({
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
  /// This field is ignored for [ListItemNode] targets.
  final double? newFirstLineIndent;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChangeIndentRequest &&
        other.nodeId == nodeId &&
        other.newIndentLeft == newIndentLeft &&
        other.newIndentRight == newIndentRight &&
        other.newFirstLineIndent == newFirstLineIndent;
  }

  @override
  int get hashCode => Object.hash(nodeId, newIndentLeft, newIndentRight, newFirstLineIndent);

  @override
  String toString() => 'ChangeIndentRequest(nodeId: $nodeId, '
      'newIndentLeft: $newIndentLeft, newIndentRight: $newIndentRight, '
      'newFirstLineIndent: $newFirstLineIndent)';
}

// ---------------------------------------------------------------------------
// ChangeSpacingRequest
// ---------------------------------------------------------------------------

/// Request to change the spacing before and/or after a block node.
///
/// The node identified by [nodeId] can be any [DocumentNode] type that
/// carries spacing fields: [ParagraphNode], [ListItemNode], [BlockquoteNode],
/// [CodeBlockNode], [ImageNode], [HorizontalRuleNode], and [TableNode].
///
/// Both [newSpaceBefore] and [newSpaceAfter] are optional — only non-null
/// values are applied. Passing `null` for a field leaves that spacing
/// value unchanged on the target node.
class ChangeSpacingRequest extends EditRequest {
  /// Creates a [ChangeSpacingRequest].
  const ChangeSpacingRequest({
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
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChangeSpacingRequest &&
        other.nodeId == nodeId &&
        other.newSpaceBefore == newSpaceBefore &&
        other.newSpaceAfter == newSpaceAfter;
  }

  @override
  int get hashCode => Object.hash(nodeId, newSpaceBefore, newSpaceAfter);

  @override
  String toString() => 'ChangeSpacingRequest(nodeId: $nodeId, '
      'newSpaceBefore: $newSpaceBefore, newSpaceAfter: $newSpaceAfter)';
}

// ---------------------------------------------------------------------------
// ApplyAttributionRequest
// ---------------------------------------------------------------------------

/// Request to apply [attribution] to all text nodes within [selection].
///
/// For text nodes at the boundary of [selection], the attribution is applied
/// only to the selected portion of the node's text. Middle nodes (fully inside
/// the selection) receive the attribution over their entire text.
class ApplyAttributionRequest extends EditRequest {
  /// Creates an [ApplyAttributionRequest].
  const ApplyAttributionRequest({required this.selection, required this.attribution});

  /// The selection range over which to apply the attribution.
  final DocumentSelection selection;

  /// The attribution to apply.
  final Attribution attribution;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApplyAttributionRequest &&
        other.selection == selection &&
        other.attribution == attribution;
  }

  @override
  int get hashCode => Object.hash(selection, attribution);

  @override
  String toString() => 'ApplyAttributionRequest(selection: $selection, attribution: $attribution)';
}

// ---------------------------------------------------------------------------
// RemoveAttributionRequest
// ---------------------------------------------------------------------------

/// Request to remove [attribution] from all text nodes within [selection].
///
/// The inverse of [ApplyAttributionRequest]. Only the portion of each node
/// that falls within [selection] has the attribution removed; text outside the
/// selection is unchanged.
class RemoveAttributionRequest extends EditRequest {
  /// Creates a [RemoveAttributionRequest].
  const RemoveAttributionRequest({required this.selection, required this.attribution});

  /// The selection range from which to remove the attribution.
  final DocumentSelection selection;

  /// The attribution to remove.
  final Attribution attribution;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RemoveAttributionRequest &&
        other.selection == selection &&
        other.attribution == attribution;
  }

  @override
  int get hashCode => Object.hash(selection, attribution);

  @override
  String toString() => 'RemoveAttributionRequest(selection: $selection, attribution: $attribution)';
}

// ---------------------------------------------------------------------------
// IndentListItemRequest
// ---------------------------------------------------------------------------

/// Request to increase the indent level of the [ListItemNode] identified by
/// [nodeId] by one step.
///
/// The node must be a [ListItemNode]; an [Editor] that handles this request
/// should be a no-op (or clamp) when the indent is already at the maximum
/// nesting depth.
class IndentListItemRequest extends EditRequest {
  /// Creates an [IndentListItemRequest].
  const IndentListItemRequest({required this.nodeId});

  /// The id of the [ListItemNode] to indent.
  final String nodeId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IndentListItemRequest && other.nodeId == nodeId;
  }

  @override
  int get hashCode => nodeId.hashCode;

  @override
  String toString() => 'IndentListItemRequest(nodeId: $nodeId)';
}

// ---------------------------------------------------------------------------
// UnindentListItemRequest
// ---------------------------------------------------------------------------

/// Request to decrease the indent level of the [ListItemNode] identified by
/// [nodeId] by one step.
///
/// The node must be a [ListItemNode]; an [Editor] that handles this request
/// should be a no-op (or clamp) when the indent is already at `0`.
class UnindentListItemRequest extends EditRequest {
  /// Creates an [UnindentListItemRequest].
  const UnindentListItemRequest({required this.nodeId});

  /// The id of the [ListItemNode] to unindent.
  final String nodeId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnindentListItemRequest && other.nodeId == nodeId;
  }

  @override
  int get hashCode => nodeId.hashCode;

  @override
  String toString() => 'UnindentListItemRequest(nodeId: $nodeId)';
}

// ---------------------------------------------------------------------------
// ConvertListItemToParagraphRequest
// ---------------------------------------------------------------------------

/// Request to convert the [ListItemNode] identified by [nodeId] into a plain
/// [ParagraphNode].
///
/// This is used when Enter or Backspace is pressed on an empty list item,
/// exiting the list by converting it to a regular paragraph. The node must
/// be a [ListItemNode].
class ConvertListItemToParagraphRequest extends EditRequest {
  /// Creates a [ConvertListItemToParagraphRequest].
  const ConvertListItemToParagraphRequest({required this.nodeId});

  /// The id of the [ListItemNode] to convert.
  final String nodeId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConvertListItemToParagraphRequest && other.nodeId == nodeId;
  }

  @override
  int get hashCode => nodeId.hashCode;

  @override
  String toString() => 'ConvertListItemToParagraphRequest(nodeId: $nodeId)';
}

// ---------------------------------------------------------------------------
// ExitCodeBlockRequest
// ---------------------------------------------------------------------------

/// Request to exit a [CodeBlockNode] by converting it to — or splitting it
/// into — a plain [ParagraphNode].
///
/// Used when the user presses Enter on an empty code block, double-Enter on
/// a trailing empty line, or Shift+Enter at any offset.
///
/// * [splitOffset] — character offset at which to split. Text before this
///   offset stays in the code block; text from this offset onward moves to
///   a new [ParagraphNode].
/// * [removeTrailingNewline] — when `true` **and** the character at
///   `splitOffset - 1` is `'\n'`, the effective split offset is decremented
///   by one so the trailing newline is consumed rather than left in the code
///   block. This handles the double-Enter exit gesture.
class ExitCodeBlockRequest extends EditRequest {
  /// Creates an [ExitCodeBlockRequest].
  const ExitCodeBlockRequest({
    required this.nodeId,
    required this.splitOffset,
    this.removeTrailingNewline = false,
  });

  /// The id of the [CodeBlockNode] to exit.
  final String nodeId;

  /// The character offset at which to split the code block text.
  final int splitOffset;

  /// Whether to consume a trailing `'\n'` immediately before [splitOffset].
  final bool removeTrailingNewline;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExitCodeBlockRequest &&
        other.nodeId == nodeId &&
        other.splitOffset == splitOffset &&
        other.removeTrailingNewline == removeTrailingNewline;
  }

  @override
  int get hashCode => Object.hash(nodeId, splitOffset, removeTrailingNewline);

  @override
  String toString() => 'ExitCodeBlockRequest(nodeId: $nodeId, splitOffset: $splitOffset, '
      'removeTrailingNewline: $removeTrailingNewline)';
}

// ---------------------------------------------------------------------------
// ExitBlockquoteRequest
// ---------------------------------------------------------------------------

/// Request to exit a [BlockquoteNode] at [splitOffset], producing a new
/// [ParagraphNode] below the (possibly truncated) blockquote.
///
/// When [removeTrailingNewline] is `true` and the character before
/// [splitOffset] is `'\n'`, the effective split offset is decremented by one
/// so the trailing newline is consumed by the exit gesture rather than left
/// in the blockquote.
class ExitBlockquoteRequest extends EditRequest {
  /// Creates an [ExitBlockquoteRequest].
  const ExitBlockquoteRequest({
    required this.nodeId,
    required this.splitOffset,
    this.removeTrailingNewline = false,
  });

  /// The id of the [BlockquoteNode] to exit.
  final String nodeId;

  /// Character offset within the blockquote's text at which to split.
  final int splitOffset;

  /// Whether to consume a trailing `'\n'` before the split offset.
  final bool removeTrailingNewline;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExitBlockquoteRequest &&
          other.nodeId == nodeId &&
          other.splitOffset == splitOffset &&
          other.removeTrailingNewline == removeTrailingNewline;

  @override
  int get hashCode => Object.hash(nodeId, splitOffset, removeTrailingNewline);

  @override
  String toString() => 'ExitBlockquoteRequest(nodeId: $nodeId, splitOffset: $splitOffset, '
      'removeTrailingNewline: $removeTrailingNewline)';
}

// ---------------------------------------------------------------------------
// InsertTextAtBinaryNodeRequest
// ---------------------------------------------------------------------------

/// Request to insert text when the caret is at a binary-position node.
///
/// Binary nodes (e.g. [HorizontalRuleNode], [ImageNode]) cannot contain
/// text. This request tells the [Editor] to find or create an adjacent
/// [ParagraphNode] and insert [text] there.
///
/// The [nodePosition] indicates which edge of the binary node the caret
/// occupies:
///
/// * [BinaryNodePositionType.upstream] — insert into (or create before)
///   the previous node.
/// * [BinaryNodePositionType.downstream] — insert into (or create after)
///   the next node.
class InsertTextAtBinaryNodeRequest extends EditRequest {
  /// Creates an [InsertTextAtBinaryNodeRequest].
  const InsertTextAtBinaryNodeRequest({
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
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InsertTextAtBinaryNodeRequest &&
        other.nodeId == nodeId &&
        other.nodePosition == nodePosition &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(nodeId, nodePosition, text);

  @override
  String toString() => 'InsertTextAtBinaryNodeRequest(nodeId: $nodeId, '
      'nodePosition: $nodePosition, text: $text)';
}

// ---------------------------------------------------------------------------
// InsertTableRequest
// ---------------------------------------------------------------------------

/// Request to insert a new [TableNode] into the document.
///
/// A [TableNode] with [rowCount] rows and [columnCount] columns is created,
/// with all cells initialised to empty [AttributedText]. It is inserted at
/// [insertIndex] when non-null, or appended to the end of the document when
/// [insertIndex] is `null`.
class InsertTableRequest extends EditRequest {
  /// Creates an [InsertTableRequest].
  const InsertTableRequest({
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

  /// Zero-based index at which to insert the table, or `null` to append.
  final int? insertIndex;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InsertTableRequest &&
        other.nodeId == nodeId &&
        other.rowCount == rowCount &&
        other.columnCount == columnCount &&
        other.insertIndex == insertIndex;
  }

  @override
  int get hashCode => Object.hash(nodeId, rowCount, columnCount, insertIndex);

  @override
  String toString() => 'InsertTableRequest(nodeId: $nodeId, rowCount: $rowCount, '
      'columnCount: $columnCount, insertIndex: $insertIndex)';
}

// ---------------------------------------------------------------------------
// UpdateTableCellRequest
// ---------------------------------------------------------------------------

/// Request to update the text content of a specific [TableNode] cell.
///
/// The [TableNode] identified by [nodeId] must exist and the [row] and [col]
/// indices must be within bounds. The cell at ([row], [col]) is replaced with
/// [newText].
class UpdateTableCellRequest extends EditRequest {
  /// Creates an [UpdateTableCellRequest].
  const UpdateTableCellRequest({
    required this.nodeId,
    required this.row,
    required this.col,
    required this.newText,
  });

  /// The id of the target [TableNode].
  final String nodeId;

  /// Zero-based row index of the cell to update.
  final int row;

  /// Zero-based column index of the cell to update.
  final int col;

  /// The new text content for the cell.
  final AttributedText newText;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateTableCellRequest &&
        other.nodeId == nodeId &&
        other.row == row &&
        other.col == col &&
        other.newText == newText;
  }

  @override
  int get hashCode => Object.hash(nodeId, row, col, newText);

  @override
  String toString() => 'UpdateTableCellRequest(nodeId: $nodeId, row: $row, '
      'col: $col, newText: $newText)';
}

// ---------------------------------------------------------------------------
// DeleteTableRequest
// ---------------------------------------------------------------------------

/// Request to delete the [TableNode] identified by [nodeId] from the document.
///
/// The node must exist and must be a [TableNode]. After deletion the controller
/// selection is collapsed to the nearest surviving node, or cleared when the
/// document becomes empty.
class DeleteTableRequest extends EditRequest {
  /// Creates a [DeleteTableRequest].
  const DeleteTableRequest({required this.nodeId});

  /// The id of the [TableNode] to delete.
  final String nodeId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeleteTableRequest && other.nodeId == nodeId;
  }

  @override
  int get hashCode => nodeId.hashCode;

  @override
  String toString() => 'DeleteTableRequest(nodeId: $nodeId)';
}

// ---------------------------------------------------------------------------
// MoveNodeToPositionRequest
// ---------------------------------------------------------------------------

/// Request to move a block node to a [DocumentPosition] within the document.
///
/// When [position] falls mid-text (i.e. a [TextNodePosition] with offset > 0
/// and < text.length), the text node is split at that offset and the block is
/// inserted between the two halves. When [position] is at a block boundary,
/// the block is simply moved to the appropriate index.
///
/// The node identified by [nodeId] must exist and implement [HasBlockLayout];
/// the target [position.nodeId] must also exist in the document.
class MoveNodeToPositionRequest extends EditRequest {
  /// Creates a [MoveNodeToPositionRequest].
  const MoveNodeToPositionRequest({required this.nodeId, required this.position});

  /// The id of the block node to move.
  final String nodeId;

  /// The document position to move the block to.
  ///
  /// When this is a [TextNodePosition] with a mid-text offset, the target text
  /// node is split and the block is inserted between the two halves.
  final DocumentPosition position;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoveNodeToPositionRequest &&
        other.nodeId == nodeId &&
        other.position == position;
  }

  @override
  int get hashCode => Object.hash(nodeId, position);

  @override
  String toString() => 'MoveNodeToPositionRequest(nodeId: $nodeId, position: $position)';
}

// ---------------------------------------------------------------------------
// InsertNodeAtPositionRequest
// ---------------------------------------------------------------------------

/// Request to insert a new [DocumentNode] at a [DocumentPosition] within the
/// document.
///
/// When [position] falls mid-text, the text node is split at that offset and
/// the new node is inserted between the two halves. When [position] is `null`,
/// the node is appended at the end of the document.
///
/// If [followOnNode] is provided, it is inserted immediately after [node].
/// This is useful for non-text block insertions where an empty paragraph
/// should follow so the cursor has somewhere to land.
class InsertNodeAtPositionRequest extends EditRequest {
  /// Creates an [InsertNodeAtPositionRequest].
  InsertNodeAtPositionRequest({
    required this.node,
    this.position,
    this.followOnNode,
  });

  /// The new node to insert.
  final DocumentNode node;

  /// Where to insert. If null, append to end of document.
  final DocumentPosition? position;

  /// Optional node to insert immediately after [node] (e.g. an empty
  /// paragraph so the cursor has somewhere to land after a non-text block).
  final DocumentNode? followOnNode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InsertNodeAtPositionRequest &&
        other.node == node &&
        other.position == position &&
        other.followOnNode == followOnNode;
  }

  @override
  int get hashCode => Object.hash(node, position, followOnNode);

  @override
  String toString() => 'InsertNodeAtPositionRequest(node: $node, position: $position, '
      'followOnNode: $followOnNode)';
}
