/// UndoableEditor — an [Editor] with snapshot-based undo/redo history.
///
/// Wraps the [Editor] command pipeline so that every [submit] call captures a
/// full document snapshot before execution. [undo] restores the document and
/// selection to the pre-submit state; [redo] re-applies the reversed operation.
library;

import 'document_change_event.dart';
import 'document_node.dart';
import 'document_selection.dart';
import 'edit_request.dart';
import 'editor.dart';

// ---------------------------------------------------------------------------
// _UndoEntry (private)
// ---------------------------------------------------------------------------

/// A snapshot of document and selection state taken immediately before a
/// [submit] call, paired with the original request for redo re-submission.
class _UndoEntry {
  _UndoEntry({
    required this.request,
    required this.documentSnapshot,
    required this.selectionSnapshot,
  });

  /// The request that produced this history entry.
  ///
  /// Retained so [UndoableEditor.redo] can re-submit it through the normal
  /// command pipeline.
  final EditRequest request;

  /// Deep copy of every [DocumentNode] in the document *before* [request]
  /// was applied. Produced by calling [DocumentNode.copyWith] on each node.
  final List<DocumentNode> documentSnapshot;

  /// The controller selection *before* [request] was applied, or `null` when
  /// there was no active selection at that point.
  final DocumentSelection? selectionSnapshot;
}

// ---------------------------------------------------------------------------
// UndoableEditor
// ---------------------------------------------------------------------------

/// An [Editor] that records every submitted request for undo/redo.
///
/// Each call to [submit] pushes the request (and a snapshot of any state
/// needed to reverse it) onto the undo stack. [undo] reverses the most
/// recent operation. [redo] re-applies an undone operation.
///
/// The redo stack is cleared whenever a new request is submitted directly
/// via [submit] (not via [redo]), matching standard text editor behaviour.
///
/// Snapshot approach: before each [submit], a deep copy of every document
/// node and the current selection is captured. On [undo], the document is
/// reset to that snapshot via [MutableDocument.reset] and the selection is
/// restored. On [redo], the original request is re-submitted through
/// `super.submit`, producing a new undo entry automatically.
///
/// Example:
/// ```dart
/// final editor = UndoableEditor(
///   editContext: EditContext(document: doc, controller: ctrl),
///   maxUndoLevels: 50,
/// );
///
/// editor.submit(InsertTextRequest(nodeId: 'p1', offset: 3, text: AttributedText('!')));
///
/// if (editor.canUndo) editor.undo();
/// if (editor.canRedo) editor.redo();
///
/// editor.clearHistory();
/// editor.dispose();
/// ```
class UndoableEditor extends Editor {
  /// Creates an [UndoableEditor].
  ///
  /// [editContext] is the shared execution context for all commands.
  /// [reactions] and [listeners] are optional initial registrations forwarded
  /// to the parent [Editor].
  /// [maxUndoLevels] caps the undo stack depth; defaults to 100. Once the
  /// cap is reached, the oldest entry is evicted on each new [submit].
  UndoableEditor({
    required super.editContext,
    super.reactions,
    super.listeners,
    this.maxUndoLevels = 100,
  });

  /// Maximum number of undo levels retained in memory.
  ///
  /// When the undo stack length exceeds this value the oldest entry is
  /// discarded before adding the new one. Must be at least 1.
  final int maxUndoLevels;

  final List<_UndoEntry> _undoStack = [];
  final List<_UndoEntry> _redoStack = [];

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Whether there is at least one operation that can be undone.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there is at least one undone operation that can be redone.
  bool get canRedo => _redoStack.isNotEmpty;

  // -------------------------------------------------------------------------
  // Submit (override — records history then delegates)
  // -------------------------------------------------------------------------

  /// Submits [request] through the command pipeline and records an undo entry.
  ///
  /// Before executing [request], a snapshot of the document and selection is
  /// pushed onto the undo stack. The redo stack is cleared (a new action
  /// invalidates the redo history).
  ///
  /// Delegates to [Editor.submit] for the actual command execution, reactions,
  /// and listener notifications.
  @override
  void submit(EditRequest request) {
    _pushUndoSnapshot(request);
    _redoStack.clear();
    super.submit(request);
  }

  // -------------------------------------------------------------------------
  // Undo
  // -------------------------------------------------------------------------

  /// Reverses the most recent operation.
  ///
  /// Before restoring the snapshot, the current document and selection state
  /// is saved onto the redo stack so that [redo] can re-apply the operation.
  /// All registered [EditListener]s are notified with the [DocumentChangeEvent]s
  /// produced by the restore.
  ///
  /// Throws [StateError] if [canUndo] is false.
  void undo() {
    if (!canUndo) {
      throw StateError('UndoableEditor.undo: nothing to undo.');
    }

    final entry = _undoStack.removeLast();

    // Save current state onto the redo stack.
    _redoStack.add(
      _UndoEntry(
        request: entry.request,
        documentSnapshot: _snapshotDocument(),
        selectionSnapshot: editContext.controller.selection,
      ),
    );

    _restoreSnapshot(entry);
  }

  // -------------------------------------------------------------------------
  // Redo
  // -------------------------------------------------------------------------

  /// Re-applies the most recently undone operation.
  ///
  /// The redo entry is consumed and an undo snapshot is pushed for the
  /// restored state (so [undo] can reverse the redo). Then `super.submit` is
  /// called directly — bypassing the [submit] override — to execute the
  /// original request without clearing the remaining redo stack entries.
  ///
  /// Throws [StateError] if [canRedo] is false.
  void redo() {
    if (!canRedo) {
      throw StateError('UndoableEditor.redo: nothing to redo.');
    }

    final entry = _redoStack.removeLast();

    // Record the pre-redo state as a new undo entry.
    _pushUndoSnapshot(entry.request);

    // Execute via super.submit to avoid clearing the redo stack and to run
    // the full pipeline (reactions + listeners).
    super.submit(entry.request);
  }

  // -------------------------------------------------------------------------
  // clearHistory
  // -------------------------------------------------------------------------

  /// Clears both the undo and redo stacks.
  ///
  /// The document and selection are left unchanged. After [clearHistory],
  /// both [canUndo] and [canRedo] return `false`.
  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Captures the current document and selection into an [_UndoEntry] and
  /// pushes it onto [_undoStack].
  ///
  /// When the stack size exceeds [maxUndoLevels], the oldest entry is evicted.
  void _pushUndoSnapshot(EditRequest request) {
    final entry = _UndoEntry(
      request: request,
      documentSnapshot: _snapshotDocument(),
      selectionSnapshot: editContext.controller.selection,
    );
    _undoStack.add(entry);
    if (_undoStack.length > maxUndoLevels) {
      _undoStack.removeAt(0);
    }
  }

  /// Returns a deep copy of every node currently in the document.
  ///
  /// Each node is cloned via [DocumentNode.copyWith] with no overrides so
  /// that the snapshot captures the full current state of every field.
  List<DocumentNode> _snapshotDocument() =>
      editContext.document.nodes.map((n) => n.copyWith()).toList();

  /// Restores the document and selection to the state captured in [entry].
  ///
  /// Uses [MutableDocument.reset] to atomically replace all nodes, then
  /// notifies all registered [EditListener]s with the resulting change events.
  void _restoreSnapshot(_UndoEntry entry) {
    final events = <DocumentChangeEvent>[];

    // Temporarily subscribe to the document's changes notifier to collect
    // the NodeDeleted / NodeInserted events emitted by reset().
    void onDocChange() => events.addAll(editContext.document.changes.value);
    editContext.document.changes.addListener(onDocChange);
    editContext.document.reset(entry.documentSnapshot);
    editContext.document.changes.removeListener(onDocChange);

    // Restore the selection.
    editContext.controller.setSelection(entry.selectionSnapshot);

    // Deliver the restore events to all Editor listeners.
    notifyEditListeners(events);
  }
}
