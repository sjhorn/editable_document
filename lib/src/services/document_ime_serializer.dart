/// Bidirectional serialization between the block [Document] model and
/// Flutter's flat [TextEditingValue] used by the platform IME.
///
/// The services layer is the highest-risk part of the package because it
/// bridges two fundamentally different text models.  Every public method in
/// this file must remain within the allowed import set:
///   `dart:async`, `flutter/foundation`, `flutter/painting`, `flutter/services`,
///   and `../model/…`.  Never import from `flutter/widgets`, `flutter/rendering`,
///   `../rendering/`, or `../widgets/`.
library;

import 'package:flutter/services.dart';

import '../model/attributed_text.dart';
import '../model/blockquote_node.dart';
import '../model/code_block_node.dart';
import '../model/document.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/edit_request.dart';
import '../model/node_position.dart';
import '../model/table_node.dart';
import '../model/text_node.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// The synthetic placeholder string used when the document state cannot be
/// represented as a single flat string (Mode 2 serialization).
///
/// A zero-width space is used so that the IME sees *some* content (preventing
/// it from sending a confusing empty-string delta) while keeping the synthetic
/// value invisible to the user.
const String _kSyntheticPlaceholder = '\u200B';

// ---------------------------------------------------------------------------
// DocumentImeSerializer
// ---------------------------------------------------------------------------

/// Converts a [Document] and [DocumentSelection] to a [TextEditingValue] for
/// consumption by the platform IME, and maps incoming [TextEditingDelta]s back
/// to [EditRequest]s for the document command pipeline.
///
/// ## Serialization modes
///
/// ### Mode 1 — Text Editing (single [TextNode] selected)
///
/// When [selection] is non-null and both [DocumentSelection.base] and
/// [DocumentSelection.extent] refer to the *same* [TextNode], the node's full
/// plain text is placed in [TextEditingValue.text] and the selection offsets
/// are mapped directly.  This preserves autocorrect, voice dictation, and IME
/// composition suggestions.
///
/// ### Mode 2 — Synthetic (cross-block, non-text node, or no selection)
///
/// In all other cases a minimal synthetic string ([_kSyntheticPlaceholder])
/// is returned with a collapsed selection.  Incoming deltas are intercepted
/// and mapped to document-level [EditRequest]s *without* relying on the IME's
/// text model.  When [selection] is `null`, an empty string is returned
/// instead of the placeholder.
///
/// ### Mode 3 — Table Cell (single [TableNode] cell selected)
///
/// When [selection] is non-null and both endpoints refer to the same cell
/// within a [TableNode] (identified by matching `row` and `col` in their
/// [TableCellPosition]s), the cell's plain text is placed in
/// [TextEditingValue.text] and the selection offsets are mapped to character
/// positions within that cell.  Incoming deltas are converted to
/// [UpdateTableCellRequest]s that replace the full cell text (newline
/// insertions are treated as embedded newlines rather than paragraph splits).
///
/// ## Delta → EditRequest mapping
///
/// | Delta type | TextNode target | Produces |
/// |---|---|---|
/// | [TextEditingDeltaInsertion] (normal text) | [TextNode] | `InsertTextRequest` |
/// | [TextEditingDeltaInsertion] (`'\n'`) | [TextNode] (not [CodeBlockNode] or [BlockquoteNode]) | [SplitParagraphRequest] |
/// | [TextEditingDeltaInsertion] (`'\n'`) | [CodeBlockNode] or [BlockquoteNode] | `InsertTextRequest` |
/// | [TextEditingDeltaDeletion] | [TextNode] | [DeleteContentRequest] |
/// | [TextEditingDeltaReplacement] | [TextNode] | [DeleteContentRequest] + `InsertTextRequest` |
/// | [TextEditingDeltaNonTextUpdate] | any | *(empty — selection-only update)* |
/// | any delta | [TableNode] cell | [UpdateTableCellRequest] |
class DocumentImeSerializer {
  /// Creates a [DocumentImeSerializer].
  const DocumentImeSerializer();

  // -------------------------------------------------------------------------
  // toTextEditingValue
  // -------------------------------------------------------------------------

  /// Converts [document] and [selection] to a [TextEditingValue] suitable for
  /// the platform IME.
  ///
  /// When [selection] is non-null and refers to a single [TextNode] (Mode 1),
  /// the node's full text is serialized together with the selection mapped to
  /// character offsets.  An optional composing region can be provided via
  /// [composingNodeId], [composingBase], and [composingExtent]; the region is
  /// only used in Mode 1 (it is ignored in Mode 2).
  ///
  /// When [selection] is non-null and both endpoints are inside the *same*
  /// cell of a [TableNode] (Mode 3), the cell's text is serialized with the
  /// character offsets mapped.  The composing region is honoured only when
  /// [composingNodeId] matches the table node id **and** [composingRow] /
  /// [composingCol] match the selected cell.
  ///
  /// When [selection] is `null`, an empty [TextEditingValue] is returned.
  ///
  /// In all other cases (cross-block selection, cross-cell table selection,
  /// non-text / non-table node selection) a synthetic Mode 2 value is returned
  /// — see [_kSyntheticPlaceholder].
  TextEditingValue toTextEditingValue({
    required Document document,
    required DocumentSelection? selection,
    String? composingNodeId,
    int? composingBase,
    int? composingExtent,
    // Mode 3: row/col of the composing cell within a TableNode.
    int? composingRow,
    int? composingCol,
  }) {
    // Null selection — caller has nothing selected.
    if (selection == null) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final baseNode = document.nodeById(selection.base.nodeId);
    final extentNode = document.nodeById(selection.extent.nodeId);

    // Both endpoints must refer to the same node.
    final sameNode = baseNode != null && extentNode != null && identical(baseNode, extentNode);
    if (!sameNode) return _syntheticValue();

    // Mode 1: single TextNode selected.
    if (baseNode is TextNode) {
      final basePos = selection.base.nodePosition;
      final extentPos = selection.extent.nodePosition;

      if (basePos is! TextNodePosition || extentPos is! TextNodePosition) {
        return _syntheticValue();
      }

      final nodeText = baseNode.text.text;
      final textSel = TextSelection(
        baseOffset: basePos.offset,
        extentOffset: extentPos.offset,
      );

      TextRange composing = TextRange.empty;
      if (composingNodeId == baseNode.id && composingBase != null && composingExtent != null) {
        composing = TextRange(start: composingBase, end: composingExtent);
      }

      return TextEditingValue(
        text: nodeText,
        selection: textSel,
        composing: composing,
      );
    }

    // Mode 3: single TableNode cell selected.
    if (baseNode is TableNode) {
      final basePos = selection.base.nodePosition;
      final extentPos = selection.extent.nodePosition;

      if (basePos is! TableCellPosition || extentPos is! TableCellPosition) {
        return _syntheticValue();
      }

      // Both positions must refer to the same cell.
      if (basePos.row != extentPos.row || basePos.col != extentPos.col) {
        return _syntheticValue();
      }

      final cellText = baseNode.cellAt(basePos.row, basePos.col).text;
      final textSel = TextSelection(
        baseOffset: basePos.offset,
        extentOffset: extentPos.offset,
      );

      TextRange composing = TextRange.empty;
      if (composingNodeId == baseNode.id &&
          composingRow == basePos.row &&
          composingCol == basePos.col &&
          composingBase != null &&
          composingExtent != null) {
        composing = TextRange(start: composingBase, end: composingExtent);
      }

      return TextEditingValue(
        text: cellText,
        selection: textSel,
        composing: composing,
      );
    }

    // Mode 2: non-text, non-table node.
    return _syntheticValue();
  }

  // -------------------------------------------------------------------------
  // toDocumentSelection
  // -------------------------------------------------------------------------

  /// Converts an IME [imeValue] back to a [DocumentSelection].
  ///
  /// [serializedNodeId] must be the id of the node that was serialized during
  /// the corresponding [toTextEditingValue] call.  When `null`, the call was
  /// Mode 2 and `null` is returned.
  ///
  /// For Mode 3 (table cell), [serializedRow] and [serializedCol] must be the
  /// zero-based indices of the cell that was serialized.  When either is
  /// `null`, `null` is returned.
  ///
  /// Returns `null` when:
  /// - [serializedNodeId] is `null`.
  /// - No node with [serializedNodeId] exists in [document].
  /// - The [imeValue] selection is invalid (negative offsets).
  /// - [serializedNodeId] refers to a [TableNode] but [serializedRow] or
  ///   [serializedCol] is `null`.
  DocumentSelection? toDocumentSelection({
    required TextEditingValue imeValue,
    required Document document,
    required String? serializedNodeId,
    int? serializedRow,
    int? serializedCol,
  }) {
    if (serializedNodeId == null) return null;

    final node = document.nodeById(serializedNodeId);
    if (node == null) return null;

    final sel = imeValue.selection;
    if (sel.baseOffset < 0 || sel.extentOffset < 0) return null;

    // Mode 3: table cell deserialization.
    if (node is TableNode) {
      if (serializedRow == null || serializedCol == null) return null;

      final base = DocumentPosition(
        nodeId: serializedNodeId,
        nodePosition: TableCellPosition(
          row: serializedRow,
          col: serializedCol,
          offset: sel.baseOffset,
        ),
      );
      final extent = DocumentPosition(
        nodeId: serializedNodeId,
        nodePosition: TableCellPosition(
          row: serializedRow,
          col: serializedCol,
          offset: sel.extentOffset,
        ),
      );
      return DocumentSelection(base: base, extent: extent);
    }

    // Mode 1: text node deserialization.
    final base = DocumentPosition(
      nodeId: serializedNodeId,
      nodePosition: TextNodePosition(offset: sel.baseOffset),
    );
    final extent = DocumentPosition(
      nodeId: serializedNodeId,
      nodePosition: TextNodePosition(offset: sel.extentOffset),
    );

    return DocumentSelection(base: base, extent: extent);
  }

  // -------------------------------------------------------------------------
  // deltaToRequests
  // -------------------------------------------------------------------------

  /// Maps a list of [TextEditingDelta]s to [EditRequest]s for the document
  /// command pipeline.
  ///
  /// [selection] is the *current* [DocumentSelection] at the time the deltas
  /// arrive.  When [selection] is `null` (Mode 2 with no active selection),
  /// the method cannot resolve a target node and returns an empty list.
  ///
  /// For Mode 3 (table cell), each delta that mutates text produces an
  /// [UpdateTableCellRequest] carrying the new full cell text derived by
  /// applying the delta to the cell's current content.  Newline insertions
  /// are treated as embedded newlines (no paragraph split occurs within a
  /// table cell).
  ///
  /// The deltas are processed in order; each delta may produce zero, one, or
  /// two [EditRequest]s.  See [DocumentImeSerializer] class docs for the
  /// full mapping table.
  List<EditRequest> deltaToRequests({
    required List<TextEditingDelta> deltas,
    required Document document,
    required DocumentSelection? selection,
  }) {
    if (deltas.isEmpty) return const [];
    if (selection == null) return const [];

    // Check if this is a table cell selection (Mode 3).
    final tableCellTarget = _resolveTableCellTarget(document, selection);
    if (tableCellTarget != null) {
      return _tableCellDeltaToRequests(deltas, document, tableCellTarget);
    }

    // Resolve the target node — only Mode 1 (single TextNode) is actionable.
    final targetNodeId = _resolveTargetNodeId(document, selection);
    if (targetNodeId == null) {
      // Check if this is a collapsed selection at a binary node.
      return _binaryNodeDeltaToRequests(deltas, document, selection);
    }

    final requests = <EditRequest>[];

    for (final delta in deltas) {
      if (delta is TextEditingDeltaInsertion) {
        requests.addAll(_insertionToRequests(delta, targetNodeId, document));
      } else if (delta is TextEditingDeltaDeletion) {
        requests.addAll(_deletionToRequests(delta, targetNodeId));
      } else if (delta is TextEditingDeltaReplacement) {
        requests.addAll(_replacementToRequests(delta, targetNodeId));
      }
      // TextEditingDeltaNonTextUpdate → no document mutation.
    }

    return requests;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Returns the Mode 2 synthetic [TextEditingValue].
  TextEditingValue _syntheticValue() {
    return const TextEditingValue(
      text: _kSyntheticPlaceholder,
      selection: TextSelection.collapsed(offset: 1),
    );
  }

  /// Returns the node id to target for delta mapping, or `null` if the
  /// current selection cannot be resolved to a single [TextNode].
  String? _resolveTargetNodeId(Document document, DocumentSelection selection) {
    // Both endpoints must refer to the same node.
    if (selection.base.nodeId != selection.extent.nodeId) return null;

    final node = document.nodeById(selection.base.nodeId);
    if (node == null || node is! TextNode) return null;

    return node.id;
  }

  /// Identifies whether the selection is inside a single table cell.
  ///
  /// Returns a [_TableCellTarget] when both endpoints of [selection] refer to
  /// the same [TableNode] and the same cell (matching row and col). Returns
  /// `null` in all other cases.
  _TableCellTarget? _resolveTableCellTarget(Document document, DocumentSelection selection) {
    if (selection.base.nodeId != selection.extent.nodeId) return null;

    final node = document.nodeById(selection.base.nodeId);
    if (node == null || node is! TableNode) return null;

    final basePos = selection.base.nodePosition;
    final extentPos = selection.extent.nodePosition;
    if (basePos is! TableCellPosition || extentPos is! TableCellPosition) return null;
    if (basePos.row != extentPos.row || basePos.col != extentPos.col) return null;

    return _TableCellTarget(nodeId: node.id, row: basePos.row, col: basePos.col);
  }

  /// Maps deltas to [UpdateTableCellRequest]s for a table cell target.
  ///
  /// Each text-mutating delta produces a single [UpdateTableCellRequest] that
  /// carries the full new text of the cell (derived by applying the delta to
  /// the current cell content). [TextEditingDeltaNonTextUpdate] produces no
  /// request. Newlines are embedded as text — no paragraph split.
  List<EditRequest> _tableCellDeltaToRequests(
    List<TextEditingDelta> deltas,
    Document document,
    _TableCellTarget target,
  ) {
    final node = document.nodeById(target.nodeId);
    if (node == null || node is! TableNode) return const [];

    final requests = <EditRequest>[];

    for (final delta in deltas) {
      if (delta is TextEditingDeltaNonTextUpdate) continue;

      // Compute the new cell text by applying the delta.
      final currentText = node.cellAt(target.row, target.col).text;
      final String newText;

      if (delta is TextEditingDeltaInsertion) {
        // Apply insertion: insert textInserted at insertionOffset.
        newText = currentText.substring(0, delta.insertionOffset) +
            delta.textInserted +
            currentText.substring(delta.insertionOffset);
      } else if (delta is TextEditingDeltaDeletion) {
        // Apply deletion: remove characters in deletedRange.
        newText = currentText.substring(0, delta.deletedRange.start) +
            currentText.substring(delta.deletedRange.end);
      } else if (delta is TextEditingDeltaReplacement) {
        // Apply replacement: replace characters in replacedRange.
        newText = currentText.substring(0, delta.replacedRange.start) +
            delta.replacementText +
            currentText.substring(delta.replacedRange.end);
      } else {
        continue;
      }

      // Skip if the keyboard handler already modified the cell before this
      // IME delta arrived. The delta's oldText reflects the pre-edit state;
      // if the cell text no longer matches, the edit was already applied.
      if (delta.oldText != currentText) continue;

      requests.add(
        UpdateTableCellRequest(
          nodeId: target.nodeId,
          row: target.row,
          col: target.col,
          newText: AttributedText(newText),
          newCursorOffset: delta.selection.extentOffset,
        ),
      );
    }

    return requests;
  }

  /// Maps a [TextEditingDeltaInsertion] to one [EditRequest].
  ///
  /// A newline produces a [SplitParagraphRequest] for most [TextNode] types.
  /// The exceptions are [CodeBlockNode] and [BlockquoteNode]: these node types
  /// embed newlines as text content rather than splitting into two blocks, so a
  /// newline there produces an `InsertTextRequest` instead.
  /// Any other text always produces an `InsertTextRequest`.
  List<EditRequest> _insertionToRequests(
    TextEditingDeltaInsertion delta,
    String nodeId,
    Document document,
  ) {
    if (delta.textInserted == '\n') {
      // Code blocks and blockquotes embed newlines as text content — they
      // should not be split into two blocks by the IME.
      final node = document.nodeById(nodeId);
      if (node is CodeBlockNode || node is BlockquoteNode) {
        return [
          InsertTextRequest(
            nodeId: nodeId,
            offset: delta.insertionOffset,
            text: AttributedText('\n'),
          ),
        ];
      }
      return [
        SplitParagraphRequest(
          nodeId: nodeId,
          splitOffset: delta.insertionOffset,
        ),
      ];
    }

    return [
      InsertTextRequest(
        nodeId: nodeId,
        offset: delta.insertionOffset,
        text: AttributedText(delta.textInserted),
      ),
    ];
  }

  /// Maps a [TextEditingDeltaDeletion] to a [DeleteContentRequest].
  List<EditRequest> _deletionToRequests(
    TextEditingDeltaDeletion delta,
    String nodeId,
  ) {
    final base = DocumentPosition(
      nodeId: nodeId,
      nodePosition: TextNodePosition(offset: delta.deletedRange.start),
    );
    final extent = DocumentPosition(
      nodeId: nodeId,
      nodePosition: TextNodePosition(offset: delta.deletedRange.end),
    );

    return [
      DeleteContentRequest(
        selection: DocumentSelection(base: base, extent: extent),
      ),
    ];
  }

  /// Maps a [TextEditingDeltaReplacement] to a [DeleteContentRequest] followed
  /// by an `InsertTextRequest`.
  List<EditRequest> _replacementToRequests(
    TextEditingDeltaReplacement delta,
    String nodeId,
  ) {
    final base = DocumentPosition(
      nodeId: nodeId,
      nodePosition: TextNodePosition(offset: delta.replacedRange.start),
    );
    final extent = DocumentPosition(
      nodeId: nodeId,
      nodePosition: TextNodePosition(offset: delta.replacedRange.end),
    );

    return [
      DeleteContentRequest(
        selection: DocumentSelection(base: base, extent: extent),
      ),
      InsertTextRequest(
        nodeId: nodeId,
        offset: delta.replacedRange.start,
        text: AttributedText(delta.replacementText),
      ),
    ];
  }

  /// Handles deltas when the selection is at a binary-position node.
  ///
  /// Only [TextEditingDeltaInsertion] deltas produce requests — an
  /// [InsertTextAtBinaryNodeRequest] is emitted for each insertion.
  /// Deletion and replacement deltas are silently ignored because binary
  /// nodes contain no text to delete.
  List<EditRequest> _binaryNodeDeltaToRequests(
    List<TextEditingDelta> deltas,
    Document document,
    DocumentSelection selection,
  ) {
    // Must be a collapsed selection at a single binary node.
    if (!selection.isCollapsed) return const [];
    if (selection.base.nodeId != selection.extent.nodeId) return const [];

    final node = document.nodeById(selection.base.nodeId);
    if (node == null) return const [];
    if (node is TextNode) return const [];

    final nodePosition = selection.base.nodePosition;
    if (nodePosition is! BinaryNodePosition) return const [];

    final requests = <EditRequest>[];
    for (final delta in deltas) {
      if (delta is TextEditingDeltaInsertion) {
        requests.add(
          InsertTextAtBinaryNodeRequest(
            nodeId: node.id,
            nodePosition: nodePosition.type,
            text: AttributedText(delta.textInserted),
          ),
        );
      }
      // Deletion/replacement at binary node → no-op (nothing to delete).
    }
    return requests;
  }
}

// ---------------------------------------------------------------------------
// Private data types
// ---------------------------------------------------------------------------

/// Internal descriptor for a resolved table cell target.
class _TableCellTarget {
  const _TableCellTarget({
    required this.nodeId,
    required this.row,
    required this.col,
  });

  final String nodeId;
  final int row;
  final int col;
}
