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
import '../model/document.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/edit_request.dart';
import '../model/node_position.dart';
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
/// ## Delta → EditRequest mapping
///
/// | Delta type | Produces |
/// |---|---|
/// | [TextEditingDeltaInsertion] (normal text) | [InsertTextRequest] |
/// | [TextEditingDeltaInsertion] (`'\n'`) | [SplitParagraphRequest] |
/// | [TextEditingDeltaDeletion] | [DeleteContentRequest] |
/// | [TextEditingDeltaReplacement] | [DeleteContentRequest] + [InsertTextRequest] |
/// | [TextEditingDeltaNonTextUpdate] | *(empty — selection-only update)* |
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
  /// When [selection] is `null`, an empty [TextEditingValue] is returned.
  ///
  /// In all other cases (cross-block selection, non-text node selection) a
  /// synthetic Mode 2 value is returned — see [_kSyntheticPlaceholder].
  TextEditingValue toTextEditingValue({
    required Document document,
    required DocumentSelection? selection,
    String? composingNodeId,
    int? composingBase,
    int? composingExtent,
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

    // Mode 1: both endpoints are in the same TextNode.
    final sameNode = baseNode != null && extentNode != null && identical(baseNode, extentNode);
    if (sameNode && baseNode is TextNode) {
      final nodeText = baseNode.text.text;

      // Map DocumentSelection → TextSelection within this node's text.
      final basePos = selection.base.nodePosition;
      final extentPos = selection.extent.nodePosition;

      if (basePos is! TextNodePosition || extentPos is! TextNodePosition) {
        // Fall through to Mode 2 if node positions are not text positions.
        return _syntheticValue();
      }

      final textSel = TextSelection(
        baseOffset: basePos.offset,
        extentOffset: extentPos.offset,
      );

      // Build composing range if requested for this node.
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

    // Mode 2: cross-block or non-text node.
    return _syntheticValue();
  }

  // -------------------------------------------------------------------------
  // toDocumentSelection
  // -------------------------------------------------------------------------

  /// Converts an IME [imeValue] back to a [DocumentSelection].
  ///
  /// [serializedNodeId] must be the id of the [TextNode] that was serialized
  /// during the corresponding [toTextEditingValue] call (Mode 1).  When
  /// [serializedNodeId] is `null` the call was Mode 2 and `null` is returned.
  ///
  /// Returns `null` when:
  /// - [serializedNodeId] is `null`.
  /// - No node with [serializedNodeId] exists in [document].
  /// - The [imeValue] selection is invalid (negative offsets).
  DocumentSelection? toDocumentSelection({
    required TextEditingValue imeValue,
    required Document document,
    required String? serializedNodeId,
  }) {
    if (serializedNodeId == null) return null;

    final node = document.nodeById(serializedNodeId);
    if (node == null) return null;

    final sel = imeValue.selection;
    if (sel.baseOffset < 0 || sel.extentOffset < 0) return null;

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

    // Resolve the target node — only Mode 1 (single TextNode) is actionable.
    final targetNodeId = _resolveTargetNodeId(document, selection);
    if (targetNodeId == null) return const [];

    final requests = <EditRequest>[];

    for (final delta in deltas) {
      if (delta is TextEditingDeltaInsertion) {
        requests.addAll(_insertionToRequests(delta, targetNodeId));
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

  /// Maps a [TextEditingDeltaInsertion] to one [EditRequest].
  ///
  /// A newline produces a [SplitParagraphRequest]; any other text produces an
  /// [InsertTextRequest].
  List<EditRequest> _insertionToRequests(
    TextEditingDeltaInsertion delta,
    String nodeId,
  ) {
    if (delta.textInserted == '\n') {
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
  /// by an [InsertTextRequest].
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
}
