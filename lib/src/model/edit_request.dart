/// Edit request value types for the editable_document command architecture.
///
/// An [EditRequest] is an immutable description of a desired mutation. Requests
/// are submitted to an [Editor], which maps each one to an [EditCommand] for
/// execution.
///
/// Requests are dispatched by the [Editor] via a type-check chain that covers
/// every concrete subtype defined in this file.
library;

import 'attribution.dart';
import 'attributed_text.dart';
import 'document_node.dart';
import 'document_selection.dart';
import 'paragraph_node.dart';

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
