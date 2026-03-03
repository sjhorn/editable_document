/// Editor — the command pipeline coordinator for editable_document.
///
/// [Editor] accepts [EditRequest]s, maps each to an [EditCommand], executes
/// the command, passes the resulting events through registered [EditReaction]s,
/// and finally delivers all events to [EditListener]s.
library;

import 'package:flutter/foundation.dart';

import 'document_change_event.dart';
import 'edit_command.dart';
import 'edit_context.dart';
import 'edit_listener.dart';
import 'edit_reaction.dart';
import 'edit_request.dart';

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

/// The central coordinator of the editable_document command architecture.
///
/// [Editor] owns the [EditContext] and maintains ordered lists of
/// [EditReaction]s and [EditListener]s. Each call to [submit] executes the
/// following pipeline:
///
/// 1. Map [EditRequest] → [EditCommand] via [_createCommand].
/// 2. Execute the command; collect [DocumentChangeEvent]s.
/// 3. Offer the events to each [EditReaction]; reactions may return
///    additional [EditRequest]s, which are processed recursively.
///    A cycle limit of [_maxReactionDepth] prevents infinite loops.
/// 4. Notify every [EditListener] with the full accumulated event list.
///
/// ```dart
/// final editor = Editor(editContext: ctx);
/// editor.addListener(myListener);
/// editor.submit(InsertTextRequest(nodeId: 'p1', offset: 3, text: AttributedText('!')));
/// editor.dispose();
/// ```
class Editor {
  /// Creates an [Editor] with the given [editContext].
  ///
  /// [reactions] and [listeners] are optional initial registrations.
  Editor({
    required EditContext editContext,
    List<EditReaction> reactions = const [],
    List<EditListener> listeners = const [],
  })  : _context = editContext,
        _reactions = List<EditReaction>.of(reactions),
        _listeners = List<EditListener>.of(listeners);

  /// The shared execution context passed to every [EditCommand].
  final EditContext _context;

  /// The execution context for this editor, accessible to subclasses.
  ///
  /// Subclasses such as [UndoableEditor] may read [editContext] to snapshot
  /// or restore document state. Callers must not mutate the document directly
  /// through this reference; always go through [submit].
  @protected
  EditContext get editContext => _context;

  final List<EditReaction> _reactions;
  final List<EditListener> _listeners;

  /// Maximum reaction chaining depth. Prevents infinite loops.
  static const int _maxReactionDepth = 10;

  // -------------------------------------------------------------------------
  // Registration
  // -------------------------------------------------------------------------

  /// Appends [reaction] to the reaction list.
  void addReaction(EditReaction reaction) => _reactions.add(reaction);

  /// Removes [reaction] from the reaction list.
  ///
  /// If [reaction] was not registered this is a no-op.
  void removeReaction(EditReaction reaction) => _reactions.remove(reaction);

  /// Appends [listener] to the listener list.
  void addListener(EditListener listener) => _listeners.add(listener);

  /// Removes [listener] from the listener list.
  ///
  /// If [listener] was not registered this is a no-op.
  void removeListener(EditListener listener) => _listeners.remove(listener);

  // -------------------------------------------------------------------------
  // Submit
  // -------------------------------------------------------------------------

  /// Submits [request] to the pipeline and processes all side-effects.
  ///
  /// The request is converted to a command, executed, and then reactions are
  /// given the opportunity to inject follow-up requests. The complete list of
  /// [DocumentChangeEvent]s from all commands is delivered to every listener.
  void submit(EditRequest request) {
    final allEvents = <DocumentChangeEvent>[];
    _processRequest(request, allEvents, depth: 0);
    notifyEditListeners(allEvents);
  }

  /// Recursively processes [request] and any follow-up requests from reactions.
  void _processRequest(EditRequest request, List<DocumentChangeEvent> accumulated,
      {required int depth}) {
    if (depth >= _maxReactionDepth) return;

    final command = _createCommand(request);
    final events = command.execute(_context);
    accumulated.addAll(events);

    // Run each reaction once and collect follow-up requests.
    final followUps = <EditRequest>[];
    for (final reaction in List<EditReaction>.of(_reactions)) {
      final additional = reaction.react(_context, [request], events);
      followUps.addAll(additional);
    }

    // Process follow-ups at the next depth level.
    for (final followUp in followUps) {
      _processRequest(followUp, accumulated, depth: depth + 1);
    }
  }

  /// Maps an [EditRequest] to the corresponding [EditCommand].
  ///
  /// Throws [ArgumentError] when no command is registered for [request].
  EditCommand _createCommand(EditRequest request) {
    if (request is InsertTextRequest) {
      return InsertTextCommand(nodeId: request.nodeId, offset: request.offset, text: request.text);
    } else if (request is DeleteContentRequest) {
      return DeleteContentCommand(selection: request.selection);
    } else if (request is ReplaceNodeRequest) {
      return ReplaceNodeCommand(nodeId: request.nodeId, newNode: request.newNode);
    } else if (request is SplitParagraphRequest) {
      return SplitParagraphCommand(nodeId: request.nodeId, splitOffset: request.splitOffset);
    } else if (request is MergeNodeRequest) {
      return MergeNodeCommand(
        firstNodeId: request.firstNodeId,
        secondNodeId: request.secondNodeId,
      );
    } else if (request is MoveNodeRequest) {
      return MoveNodeCommand(nodeId: request.nodeId, newIndex: request.newIndex);
    } else if (request is ChangeBlockTypeRequest) {
      return ChangeBlockTypeCommand(nodeId: request.nodeId, newBlockType: request.newBlockType);
    } else if (request is ApplyAttributionRequest) {
      return ApplyAttributionCommand(
        selection: request.selection,
        attribution: request.attribution,
      );
    } else if (request is RemoveAttributionRequest) {
      return RemoveAttributionCommand(
        selection: request.selection,
        attribution: request.attribution,
      );
    } else if (request is ConvertListItemToParagraphRequest) {
      return ConvertListItemToParagraphCommand(nodeId: request.nodeId);
    }
    throw ArgumentError('No command registered for request type ${request.runtimeType}.');
  }

  /// Notifies all registered listeners with the accumulated event list.
  ///
  /// This method is marked `@protected` so that subclasses such as
  /// [UndoableEditor] can deliver synthetic change events (e.g. from a
  /// snapshot restore) through the same listener pipeline.
  @protected
  void notifyEditListeners(List<DocumentChangeEvent> events) {
    final snapshot = List<EditListener>.of(_listeners);
    for (final listener in snapshot) {
      listener.onEdit(List<DocumentChangeEvent>.unmodifiable(events));
    }
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Releases any resources held by this [Editor].
  ///
  /// After [dispose] the [Editor] must not be used.
  void dispose() {
    _reactions.clear();
    _listeners.clear();
  }
}
