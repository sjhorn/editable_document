/// IME connection lifecycle and delta dispatch for the editable_document
/// package.
///
/// [DocumentImeInputClient] implements [DeltaTextInputClient] — the delta
/// variant of Flutter's text-input client protocol — and bridges the platform
/// IME to the block [Document] model via [DocumentImeSerializer].
///
/// Allowed imports (services layer):
///   `dart:async`, `flutter/foundation`, `flutter/painting`, `flutter/services`,
///   and `../model/…`.  Never import from `flutter/widgets`, `flutter/rendering`,
///   `../rendering/`, or `../widgets/`.
library;

import 'package:flutter/services.dart';

import '../model/document_editing_controller.dart';
import '../model/edit_request.dart';
import 'document_ime_serializer.dart';

// ---------------------------------------------------------------------------
// DocumentImeInputClient
// ---------------------------------------------------------------------------

/// Implements [DeltaTextInputClient] and manages the platform IME connection
/// for a block document editor.
///
/// ## Responsibilities
///
/// - **Connection lifecycle:** [openConnection] attaches to the platform IME,
///   shows the keyboard, and syncs the initial [TextEditingValue].
///   [closeConnection] tears down the connection cleanly.
/// - **Incoming deltas:** [updateEditingValueWithDeltas] converts each
///   [TextEditingDelta] to one or more [EditRequest]s via
///   [DocumentImeSerializer.deltaToRequests] and forwards them to
///   [requestHandler].
/// - **Sync:** [syncToIme] pushes the current document state back to the
///   platform so the IME's internal text model stays consistent after
///   mutations applied by the command pipeline.
/// - **Keyboard visibility:** [showKeyboard] / [hideKeyboard] control the
///   soft keyboard without affecting the connection itself.
/// - **Platform callbacks:** [performAction], [updateFloatingCursor], and
///   [insertContent] forward their payloads to the optional callbacks
///   [onAction], [onFloatingCursor], and [onInsertContent] respectively.
///
/// ## Usage
///
/// ```dart
/// final client = DocumentImeInputClient(
///   serializer: const DocumentImeSerializer(),
///   controller: myController,
///   requestHandler: myEditor.submit,
///   onAction: (action) { /* handle TextInputAction */ },
/// );
///
/// // On focus gained:
/// client.openConnection(const TextInputConfiguration(enableDeltaModel: true));
///
/// // After a document mutation:
/// client.syncToIme();
///
/// // On focus lost:
/// client.closeConnection();
/// ```
class DocumentImeInputClient implements DeltaTextInputClient {
  /// Creates a [DocumentImeInputClient].
  ///
  /// - [serializer] converts between [Document]/[DocumentSelection] and
  ///   [TextEditingValue]/[TextEditingDelta] representations.
  /// - [controller] is the source of truth for the current document and
  ///   selection.
  /// - [requestHandler] is called once for each [EditRequest] produced from
  ///   an incoming IME delta.
  /// - [onAction] receives [TextInputAction] notifications (e.g. "done", "go").
  /// - [onInsertContent] receives rich content insertions from Android IMEs
  ///   (images, GIFs, stickers).
  /// - [onFloatingCursor] receives iOS floating-cursor position updates.
  DocumentImeInputClient({
    required this.serializer,
    required this.controller,
    required this.requestHandler,
    this.onAction,
    this.onInsertContent,
    this.onFloatingCursor,
  });

  /// The serializer used to convert document state ↔ [TextEditingValue] and
  /// to map incoming [TextEditingDelta]s to [EditRequest]s.
  final DocumentImeSerializer serializer;

  /// The document editing controller that owns the [MutableDocument] and
  /// current [DocumentSelection].
  final DocumentEditingController controller;

  /// Called once for every [EditRequest] derived from an incoming IME delta.
  ///
  /// Implementations typically call `editor.submit(request)` to execute the
  /// request through the command pipeline.
  final void Function(EditRequest request) requestHandler;

  /// Optional callback invoked when the IME reports a [TextInputAction] (e.g.
  /// pressing the "Done" or "Go" button on a software keyboard).
  final void Function(TextInputAction action)? onAction;

  /// Optional callback invoked when an Android IME inserts rich inline content
  /// such as an image or GIF via [KeyboardInsertedContent].
  final void Function(KeyboardInsertedContent content)? onInsertContent;

  /// Optional callback invoked when the iOS floating cursor position changes.
  ///
  /// The iOS IME sends [RawFloatingCursorPoint] events with three states:
  /// [FloatingCursorDragState.Start], [FloatingCursorDragState.Update], and
  /// [FloatingCursorDragState.End].
  final void Function(RawFloatingCursorPoint point)? onFloatingCursor;

  // -------------------------------------------------------------------------
  // Private state
  // -------------------------------------------------------------------------

  /// The active platform IME connection, or `null` when disconnected.
  TextInputConnection? _connection;

  /// The [TextEditingValue] most recently pushed to the platform via
  /// [syncToIme], or `null` if [syncToIme] has never been called.
  TextEditingValue? _lastSyncedValue;

  // -------------------------------------------------------------------------
  // Connection lifecycle
  // -------------------------------------------------------------------------

  /// Opens an IME connection using [config].
  ///
  /// If a connection is already open it is closed first. Then
  /// [TextInput.attach] is called, the keyboard is shown, and [syncToIme] is
  /// called to push the initial document state.
  ///
  /// [config] must specify `enableDeltaModel: true` — the document model
  /// requires granular delta updates.  An assertion error is thrown in debug
  /// mode if this invariant is violated.
  void openConnection(TextInputConfiguration config) {
    // Close any stale connection before opening a fresh one.
    if (_connection != null) {
      _connection!.close();
      _connection = null;
    }

    // The delta model is non-negotiable for this client. Callers must pass
    // a [TextInputConfiguration] with `enableDeltaModel: true`.
    assert(config.enableDeltaModel, 'DocumentImeInputClient requires enableDeltaModel: true');
    _connection = TextInput.attach(this, config);

    _connection!.show();
    syncToIme();
  }

  /// Closes the current IME connection and hides the keyboard.
  ///
  /// If no connection is open this is a no-op.
  void closeConnection() {
    if (_connection == null) return;
    _connection!.close();
    _connection = null;
  }

  /// Pushes the current document state to the platform IME.
  ///
  /// Serializes the controller's document + selection into a
  /// [TextEditingValue] and calls [TextInputConnection.setEditingState].
  /// Updates [currentTextEditingValue] with the new value.
  ///
  /// If no connection is open this is a no-op.
  void syncToIme() {
    if (_connection == null) return;

    final value = serializer.toTextEditingValue(
      document: controller.document,
      selection: controller.selection,
    );
    _lastSyncedValue = value;
    _connection!.setEditingState(value);
  }

  /// Shows the software keyboard without changing the connection state.
  ///
  /// If no connection is open this is a no-op.
  void showKeyboard() {
    if (_connection == null) return;
    _connection!.show();
  }

  /// Hides the software keyboard by closing the active connection.
  ///
  /// [TextInputConnection] does not expose a `hide()` method that preserves
  /// the connection — the only platform-level way to dismiss the soft keyboard
  /// through this API is to close the connection entirely.  Callers that need
  /// the keyboard again must call [openConnection] again.
  ///
  /// If no connection is open this is a no-op.
  void hideKeyboard() {
    if (_connection == null) return;
    _connection!.close();
    _connection = null;
  }

  // -------------------------------------------------------------------------
  // DeltaTextInputClient implementation
  // -------------------------------------------------------------------------

  /// Receives a list of [TextEditingDelta]s from the platform IME.
  ///
  /// Each delta is converted to zero or more [EditRequest]s by
  /// [DocumentImeSerializer.deltaToRequests]; each resulting request is
  /// forwarded to [requestHandler].
  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> deltas) {
    final requests = serializer.deltaToRequests(
      deltas: deltas,
      document: controller.document,
      selection: controller.selection,
    );
    for (final request in requests) {
      requestHandler(request);
    }

    // After processing all deltas, push the updated document state back to
    // the platform IME so the next delta is based on current text/selection.
    syncToIme();
  }

  /// Called by the platform when the user activates the keyboard action button
  /// (e.g. "Done", "Go", "Return").
  ///
  /// Forwards [action] to [onAction] if set.
  @override
  void performAction(TextInputAction action) {
    onAction?.call(action);
  }

  /// Called by the iOS IME to report floating-cursor position changes.
  ///
  /// The floating cursor follows the user's finger as they drag on the
  /// keyboard. Three states are sent in sequence:
  /// [FloatingCursorDragState.Start] → [FloatingCursorDragState.Update]
  /// (multiple) → [FloatingCursorDragState.End].
  ///
  /// Forwards [point] to [onFloatingCursor] if set.
  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    onFloatingCursor?.call(point);
  }

  /// Called by Android IMEs to insert rich inline content (images, GIFs,
  /// stickers) via the Keyboard Image Insertion API.
  ///
  /// Forwards [content] to [onInsertContent] if set.
  @override
  void insertContent(KeyboardInsertedContent content) {
    onInsertContent?.call(content);
  }

  /// Called by the platform when it has closed the connection on its side.
  ///
  /// Nullifies the internal connection reference so the client enters the
  /// disconnected state without sending an additional close to the platform.
  @override
  void connectionClosed() {
    _connection = null;
  }

  /// The [TextEditingValue] most recently synced to the platform via
  /// [syncToIme], or `null` if [syncToIme] has never been called.
  ///
  /// This value is used by the platform text-input system to determine the
  /// current editing state without re-requesting it.
  @override
  TextEditingValue? get currentTextEditingValue => _lastSyncedValue;

  /// The autofill scope for this client.
  ///
  /// Returns `null` — autofill support is implemented in Phase 4.4 via
  /// [DocumentAutofillClient].
  @override
  AutofillScope? get currentAutofillScope => null;

  // -------------------------------------------------------------------------
  // Deprecated TextInputClient stubs
  // -------------------------------------------------------------------------
  // The [DeltaTextInputClient] mixin still pulls in a few deprecated members
  // from [TextInputClient].  We provide empty implementations so the class
  // compiles cleanly under strict analysis.

  /// Not used — the delta model supersedes this method.
  @override
  void updateEditingValue(TextEditingValue value) {
    // Intentionally empty: all updates arrive via [updateEditingValueWithDeltas].
  }

  /// Not used — private command handling is not required for this client.
  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // Intentionally empty: private commands are platform-specific extensions
    // (e.g. Android emoji input) that this client does not handle.
  }

  /// Not used — input control changes are not required for this client.
  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {
    // Intentionally empty.
  }

  /// Not used — text placeholder insertion is not required for this client.
  @override
  void insertTextPlaceholder(Size size) {
    // Intentionally empty.
  }

  /// Not used — text placeholder removal is not required for this client.
  @override
  void removeTextPlaceholder() {
    // Intentionally empty.
  }

  /// Not used — macOS selector actions are not required for this client.
  @override
  void performSelector(String selectorName) {
    // Intentionally empty.
  }

  /// Not used — autocorrection prompt rect is not required for this client.
  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // Intentionally empty.
  }

  /// Not used — toolbar display is managed by the widget layer.
  @override
  void showToolbar() {
    // Intentionally empty.
  }
}
