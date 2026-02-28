/// Edit context for the editable_document command architecture.
///
/// [EditContext] is the execution environment threaded through every
/// [EditCommand.execute] call. It gives commands access to the mutable
/// document and the editing controller without depending on Flutter widgets.
library;

import 'document_editing_controller.dart';
import 'mutable_document.dart';

// ---------------------------------------------------------------------------
// EditContext
// ---------------------------------------------------------------------------

/// Holds the shared mutable state available to [EditCommand]s during
/// execution.
///
/// An [EditContext] is created once per [Editor] and passed to every
/// [EditCommand.execute] invocation so that commands can mutate the document
/// and update the selection without depending on the widget layer.
///
/// Example:
/// ```dart
/// final ctx = EditContext(
///   document: myMutableDocument,
///   controller: myController,
/// );
/// final events = SomeCommand(...).execute(ctx);
/// ```
class EditContext {
  /// Creates an [EditContext].
  const EditContext({
    required this.document,
    required this.controller,
  });

  /// The mutable document that commands operate on.
  final MutableDocument document;

  /// The editing controller that commands may update (e.g. to move the
  /// caret after an insertion).
  final DocumentEditingController controller;
}
