/// Edit reaction interface for the editable_document command architecture.
///
/// [EditReaction]s participate in the [Editor] pipeline and may inject
/// additional [EditRequest]s in response to observed [DocumentChangeEvent]s.
library;

import 'document_change_event.dart';
import 'edit_context.dart';
import 'edit_request.dart';

// ---------------------------------------------------------------------------
// EditReaction
// ---------------------------------------------------------------------------

/// An observer in the [Editor] pipeline that may produce additional
/// [EditRequest]s in response to [DocumentChangeEvent]s.
///
/// Reactions run synchronously after each command execution. If a reaction
/// returns non-empty requests, the [Editor] processes those requests before
/// notifying [EditListener]s. This allows reactions to implement side-effect
/// logic such as auto-formatting or structural constraints.
///
/// The [Editor] enforces a cycle limit to prevent infinite reaction chains.
/// A reaction that always returns new requests will be stopped after the
/// maximum depth is reached.
///
/// Register reactions with [Editor.addReaction] and deregister with
/// [Editor.removeReaction].
///
/// Example:
/// ```dart
/// class MyReaction implements EditReaction {
///   @override
///   List<EditRequest> react(
///     EditContext context,
///     List<EditRequest> requests,
///     List<DocumentChangeEvent> changes,
///   ) {
///     // Return additional requests to process, or an empty list.
///     return const [];
///   }
/// }
/// ```
abstract interface class EditReaction {
  /// Called after a set of [EditRequest]s has been executed.
  ///
  /// [context] provides access to the document and controller. [requests] are
  /// the original requests that produced [changes]. The returned list contains
  /// zero or more additional [EditRequest]s that the [Editor] will process
  /// before notifying listeners.
  ///
  /// Return `const []` (or an empty list) when no follow-up action is needed.
  List<EditRequest> react(
    EditContext context,
    List<EditRequest> requests,
    List<DocumentChangeEvent> changes,
  );
}
