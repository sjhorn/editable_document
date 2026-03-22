/// Undo/redo toolbar bar.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/document_editing_controller.dart';
import '../../model/undoable_editor.dart';

// ---------------------------------------------------------------------------
// DocumentUndoRedoBar
// ---------------------------------------------------------------------------

/// A toolbar bar for undo and redo operations.
///
/// Shows two icon buttons:
///   - Undo (enabled when [UndoableEditor.canUndo] is `true`)
///   - Redo (enabled when [UndoableEditor.canRedo] is `true`)
///
/// When a [controller] is supplied the bar listens to it and rebuilds on every
/// document change (keeping the undo/redo buttons in sync). When [controller]
/// is `null` the bar renders its current state without automatic rebuilds.
///
/// ```dart
/// DocumentUndoRedoBar(
///   editor: undoableEditor,
///   controller: controller,
/// )
/// ```
class DocumentUndoRedoBar extends StatelessWidget {
  /// Creates a [DocumentUndoRedoBar].
  const DocumentUndoRedoBar({
    super.key,
    required this.editor,
    this.controller,
  });

  /// The [UndoableEditor] that owns the undo/redo history.
  final UndoableEditor editor;

  /// Optional controller used to trigger rebuilds after each document change.
  ///
  /// Pass the same [DocumentEditingController] that the editor operates on so
  /// the bar stays in sync after every [editor.submit], [editor.undo], and
  /// [editor.redo] call.
  final DocumentEditingController? controller;

  static final _buttonStyle = IconButton.styleFrom(
    minimumSize: const Size(32, 32),
    padding: const EdgeInsets.all(4),
  );

  @override
  Widget build(BuildContext context) {
    final listenable = controller;
    if (listenable != null) {
      return ListenableBuilder(
        listenable: listenable,
        builder: (context, _) => _buildRow(),
      );
    }
    return _buildRow();
  }

  Widget _buildRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.undo, size: 18),
          onPressed: editor.canUndo ? editor.undo : null,
          tooltip: 'Undo',
          style: _buttonStyle,
        ),
        IconButton(
          icon: const Icon(Icons.redo, size: 18),
          onPressed: editor.canRedo ? editor.redo : null,
          tooltip: 'Redo',
          style: _buttonStyle,
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<UndoableEditor>('editor', editor));
    properties.add(
      DiagnosticsProperty<DocumentEditingController>('controller', controller, defaultValue: null),
    );
  }
}
