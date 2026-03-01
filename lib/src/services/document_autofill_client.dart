/// Autofill support for single-text-node documents.
///
/// Implements [AutofillClient] so that a document editor can participate in
/// platform autofill groups (e.g. username, email, password fields).
///
/// Autofill is only meaningful when the document contains a **single
/// [TextNode]** and [DocumentEditingController.autofillHints] is non-null and
/// non-empty. In all other cases [enabled] returns `false` and
/// [textInputConfiguration] returns [AutofillConfiguration.disabled].
library;

import 'package:flutter/services.dart';

import '../model/attributed_text.dart';
import '../model/document_editing_controller.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/edit_request.dart';
import '../model/node_position.dart';
import '../model/text_node.dart';
import 'document_ime_serializer.dart';

// ---------------------------------------------------------------------------
// DocumentAutofillClient
// ---------------------------------------------------------------------------

/// Autofill support for single-text-node documents.
///
/// Implements [AutofillClient] so that a document editor can participate in
/// the platform autofill group. When [enabled] returns `false` (e.g. the
/// document has multiple nodes, no [TextNode], or
/// [DocumentEditingController.autofillHints] is null/empty), all methods
/// become no-ops and [textInputConfiguration] reports autofill as disabled.
///
/// ## Usage
///
/// ```dart
/// final autofillClient = DocumentAutofillClient(
///   controller: myController,
///   serializer: const DocumentImeSerializer(),
///   requestHandler: myEditor.submit,
/// );
///
/// // Pass as the autofill scope member to DocumentImeInputClient:
/// final imeClient = DocumentImeInputClient(
///   serializer: const DocumentImeSerializer(),
///   controller: myController,
///   requestHandler: myEditor.submit,
///   autofillScopeGetter: () => myAutofillScope,
/// );
/// ```
class DocumentAutofillClient implements AutofillClient {
  /// Creates a [DocumentAutofillClient].
  ///
  /// - [controller] provides the document, selection, and autofill hints.
  /// - [serializer] converts the document state to a [TextEditingValue] for
  ///   the [AutofillConfiguration.currentEditingValue] field.
  /// - [requestHandler] is called with each [EditRequest] produced during
  ///   [autofill] (delete and/or insert operations).
  DocumentAutofillClient({
    required this.controller,
    required this.serializer,
    required this.requestHandler,
  });

  /// The document editing controller that owns the document and selection.
  final DocumentEditingController controller;

  /// The serializer used to convert the current document state to a
  /// [TextEditingValue] for the autofill configuration.
  final DocumentImeSerializer serializer;

  /// Called once for every [EditRequest] generated during [autofill].
  ///
  /// Implementations typically call `editor.submit(request)` to run the
  /// request through the command pipeline.
  final void Function(EditRequest request) requestHandler;

  // -------------------------------------------------------------------------
  // AutofillClient
  // -------------------------------------------------------------------------

  @override
  String get autofillId => 'DocumentAutofillClient-$hashCode';

  /// Whether autofill is currently active for this client.
  ///
  /// Returns `true` only when all three conditions are satisfied:
  ///
  /// 1. [DocumentEditingController.autofillHints] is non-null and non-empty.
  /// 2. The document contains exactly one node.
  /// 3. That single node is a [TextNode].
  bool get enabled {
    final hints = controller.autofillHints;
    if (hints == null || hints.isEmpty) return false;
    final doc = controller.document;
    if (doc.nodes.length != 1) return false;
    return doc.nodes.first is TextNode;
  }

  /// Returns the [TextInputConfiguration] describing this autofill participant.
  ///
  /// When [enabled] is `false`, returns a configuration with
  /// [AutofillConfiguration.disabled]. When [enabled] is `true`, returns a
  /// configuration with a fully-populated [AutofillConfiguration] — including
  /// the current text as [AutofillConfiguration.currentEditingValue].
  @override
  TextInputConfiguration get textInputConfiguration {
    if (!enabled) {
      return const TextInputConfiguration(
        autofillConfiguration: AutofillConfiguration.disabled,
      );
    }

    final value = serializer.toTextEditingValue(
      document: controller.document,
      selection: controller.selection,
    );

    return TextInputConfiguration(
      autofillConfiguration: AutofillConfiguration(
        uniqueIdentifier: autofillId,
        autofillHints: controller.autofillHints!,
        currentEditingValue: value,
      ),
    );
  }

  /// Applies an autofill [value] to the document.
  ///
  /// When [enabled] is `false` this is a no-op. Otherwise the method:
  ///
  /// 1. If the current text differs from [value.text], issues a
  ///    [DeleteContentRequest] covering the full existing text (when non-empty)
  ///    followed by an [InsertTextRequest] with [value.text] (when non-empty).
  /// 2. Always updates [DocumentEditingController.selection] to match
  ///    [value.selection].
  @override
  void autofill(TextEditingValue value) {
    if (!enabled) return;

    final node = controller.document.nodes.first;
    if (node is! TextNode) return;

    final currentText = node.text.text;
    final newText = value.text;

    if (currentText == newText) {
      // Text is unchanged — only update the selection.
      _updateSelectionFromValue(node.id, value);
      return;
    }

    // Delete existing text if present.
    if (currentText.isNotEmpty) {
      final deleteSelection = DocumentSelection(
        base: DocumentPosition(
          nodeId: node.id,
          nodePosition: const TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: currentText.length),
        ),
      );
      requestHandler(DeleteContentRequest(selection: deleteSelection));
    }

    // Insert new text if present.
    if (newText.isNotEmpty) {
      requestHandler(
        InsertTextRequest(
          nodeId: node.id,
          offset: 0,
          text: AttributedText(newText),
        ),
      );
    }

    // Update the selection to match the incoming value.
    _updateSelectionFromValue(node.id, value);
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Updates [DocumentEditingController.selection] from [value.selection].
  void _updateSelectionFromValue(String nodeId, TextEditingValue value) {
    final sel = value.selection;
    controller.setSelection(
      DocumentSelection(
        base: DocumentPosition(
          nodeId: nodeId,
          nodePosition: TextNodePosition(offset: sel.baseOffset),
        ),
        extent: DocumentPosition(
          nodeId: nodeId,
          nodePosition: TextNodePosition(offset: sel.extentOffset),
        ),
      ),
    );
  }
}
