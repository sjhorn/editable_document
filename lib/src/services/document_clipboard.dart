/// Clipboard operations for block documents.
///
/// Provides [DocumentClipboard], a stateless service that serializes a
/// [DocumentSelection] to plain text and wraps the Flutter [Clipboard] API.
///
/// Allowed imports:
///   `dart:async`, `flutter/foundation`, `flutter/painting`, `flutter/services`,
///   and `../model/…`.
/// Never import from `flutter/widgets`, `flutter/rendering`,
/// `../rendering/`, or `../widgets/`.
library;

import 'package:flutter/services.dart';

import '../model/attributed_text.dart';
import '../model/document.dart';
import '../model/document_node.dart';
import '../model/document_selection.dart';
import '../model/edit_request.dart';
import '../model/node_position.dart';
import '../model/text_node.dart';

// ---------------------------------------------------------------------------
// DocumentClipboard
// ---------------------------------------------------------------------------

/// A stateless clipboard service for block documents.
///
/// [DocumentClipboard] bridges the document model and the system clipboard by
/// serializing a [DocumentSelection] to plain text. It wraps Flutter's
/// [Clipboard] API so that callers do not need to depend on `flutter/services`
/// directly.
///
/// Rich-text (HTML) serialization is not supported in this version; only
/// UTF-8 plain text is written to and read from the clipboard.
///
/// ### Usage
///
/// ```dart
/// const clipboard = DocumentClipboard();
///
/// // Copy selected text
/// await clipboard.copy(document, selection);
///
/// // Cut: write to clipboard and get a deletion request
/// final deleteRequest = await clipboard.cut(document, selection);
/// if (deleteRequest != null) editor.submit(deleteRequest);
///
/// // Paste: get an insertion request at the current caret position
/// final insertRequest = await clipboard.paste(nodeId, offset);
/// if (insertRequest != null) editor.submit(insertRequest);
/// ```
class DocumentClipboard {
  /// Creates a [DocumentClipboard].
  const DocumentClipboard();

  // -------------------------------------------------------------------------
  // extractPlainText
  // -------------------------------------------------------------------------

  /// Extracts plain text from [document] covered by [selection].
  ///
  /// The algorithm walks every node from the normalized base position to the
  /// normalized extent position:
  ///
  /// * If [selection] is collapsed, returns `''`.
  /// * For a single-node selection on a [TextNode], returns the substring
  ///   `[baseOffset, extentOffset)`.
  /// * For a single-node selection on a non-text node, returns `'\n'`.
  /// * For a multi-node selection, the first node contributes its tail (from
  ///   the base offset to end of text for [TextNode], or `''` for binary
  ///   nodes), middle nodes contribute their full text (or `''` for binary
  ///   nodes — the surrounding join newlines already yield a double `\n\n`
  ///   structural break), and the last node contributes its head (from start
  ///   to extent offset for [TextNode], or `''` for binary nodes). Segments
  ///   are joined with `'\n'`.
  String extractPlainText(Document document, DocumentSelection selection) {
    if (selection.isCollapsed) return '';

    final normalised = selection.normalize(document);
    final basePos = normalised.base;
    final extentPos = normalised.extent;

    // -----------------------------------------------------------------------
    // Single-node selection
    // -----------------------------------------------------------------------
    if (basePos.nodeId == extentPos.nodeId) {
      final node = document.nodeById(basePos.nodeId);
      if (node == null) return '';

      if (node is TextNode) {
        final baseOffset = _textOffset(basePos.nodePosition);
        final extentOffset = _textOffset(extentPos.nodePosition);
        return node.text.text.substring(baseOffset, extentOffset);
      }

      // Binary node selected — treat as a line break.
      return '\n';
    }

    // -----------------------------------------------------------------------
    // Multi-node selection
    // -----------------------------------------------------------------------
    final baseIndex = document.getNodeIndexById(basePos.nodeId);
    final extentIndex = document.getNodeIndexById(extentPos.nodeId);

    final parts = <String>[];

    for (var i = baseIndex; i <= extentIndex; i++) {
      final node = document.nodeAt(i);

      if (i == baseIndex) {
        // First node: text from base offset to end.
        parts.add(_tailText(node, _textOffset(basePos.nodePosition)));
      } else if (i == extentIndex) {
        // Last node: text from start to extent offset.
        parts.add(_headText(node, _textOffset(extentPos.nodePosition)));
      } else {
        // Middle node: full text.
        parts.add(_fullText(node));
      }
    }

    return parts.join('\n');
  }

  // -------------------------------------------------------------------------
  // copy
  // -------------------------------------------------------------------------

  /// Copies the selected text to the system clipboard.
  ///
  /// No-op if [selection] is collapsed; in that case `''` is returned without
  /// touching the clipboard.
  ///
  /// Returns the plain text that was written to the clipboard.
  Future<String> copy(Document document, DocumentSelection selection) async {
    final text = extractPlainText(document, selection);
    if (text.isEmpty) return '';
    await Clipboard.setData(ClipboardData(text: text));
    return text;
  }

  // -------------------------------------------------------------------------
  // cut
  // -------------------------------------------------------------------------

  /// Copies the selected text to the system clipboard and returns a
  /// [DeleteContentRequest] that the caller should submit to the editor.
  ///
  /// Returns `null` if [selection] is collapsed.
  ///
  /// The returned [DeleteContentRequest] carries the original (non-normalised)
  /// [selection] so that the editor receives the intent exactly as specified
  /// by the caller.
  Future<DeleteContentRequest?> cut(Document document, DocumentSelection selection) async {
    if (selection.isCollapsed) return null;
    await copy(document, selection);
    return DeleteContentRequest(selection: selection);
  }

  // -------------------------------------------------------------------------
  // paste
  // -------------------------------------------------------------------------

  /// Reads plain text from the system clipboard and returns an
  /// `InsertTextRequest` targeting `nodeId` at [offset].
  ///
  /// Returns `null` if the clipboard is empty or contains only whitespace-free
  /// text (i.e. an empty string).
  Future<InsertTextRequest?> paste(String nodeId, int offset) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return null;
    return InsertTextRequest(
      nodeId: nodeId,
      offset: offset,
      text: AttributedText(text),
    );
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Extracts the text-character offset from [pos].
  ///
  /// Returns `0` for non-[TextNodePosition] positions (binary nodes).
  int _textOffset(NodePosition pos) {
    if (pos is TextNodePosition) return pos.offset;
    return 0;
  }

  /// Returns the tail of [node]'s text starting at [fromOffset].
  ///
  /// For [TextNode]: `text[fromOffset..]`.
  /// For non-text nodes: `''` (they are represented by the `'\n'` join
  /// character rather than contributing any text of their own).
  String _tailText(DocumentNode node, int fromOffset) {
    if (node is TextNode) return node.text.text.substring(fromOffset);
    return '';
  }

  /// Returns the head of [node]'s text up to (exclusive) [toOffset].
  ///
  /// For [TextNode]: `text[0..toOffset)`.
  /// For non-text nodes: `''`.
  String _headText(DocumentNode node, int toOffset) {
    if (node is TextNode) return node.text.text.substring(0, toOffset);
    return '';
  }

  /// Returns the full text of [node] for use as a middle segment.
  ///
  /// For [TextNode]: the full `text.text` string.
  /// For non-text (binary) nodes: `''` — the surrounding `'\n'` join
  /// characters already produce the double newline (`\n\n`) that represents
  /// a structural break between text nodes.
  String _fullText(DocumentNode node) {
    if (node is TextNode) return node.text.text;
    return '';
  }
}
