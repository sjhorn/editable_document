/// Tests for [DocumentUndoRedoBar].
library;

import 'package:editable_document/editable_document.dart';
import 'package:editable_document/src/widgets/toolbar/document_undo_redo_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] using [InkRipple] to avoid the ink_sparkle shader error.
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UndoableEditor _makeEditor() {
  final doc = MutableDocument([
    ParagraphNode(id: 'p1', text: AttributedText('Hello')),
  ]);
  final ctrl = DocumentEditingController(document: doc);
  return UndoableEditor(editContext: EditContext(document: doc, controller: ctrl));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentUndoRedoBar', () {
    testWidgets('undo button is disabled when canUndo is false', (tester) async {
      final editor = _makeEditor();

      await tester.pumpWidget(
        _wrap(DocumentUndoRedoBar(editor: editor)),
      );

      final undoButton = tester.widgetList<IconButton>(find.byType(IconButton)).first;
      expect(undoButton.onPressed, isNull);
    });

    testWidgets('redo button is disabled when canRedo is false', (tester) async {
      final editor = _makeEditor();

      await tester.pumpWidget(
        _wrap(DocumentUndoRedoBar(editor: editor)),
      );

      final redoButton = tester.widgetList<IconButton>(find.byType(IconButton)).last;
      expect(redoButton.onPressed, isNull);
    });

    testWidgets('undo button is enabled after a submit', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final ctrl = DocumentEditingController(document: doc);
      final editor = UndoableEditor(editContext: EditContext(document: doc, controller: ctrl));

      await tester.pumpWidget(
        _wrap(DocumentUndoRedoBar(editor: editor, controller: ctrl)),
      );

      editor.submit(
        InsertTextRequest(
          nodeId: 'p1',
          offset: 5,
          text: AttributedText('!'),
        ),
      );
      await tester.pump();

      final undoButton = tester.widgetList<IconButton>(find.byType(IconButton)).first;
      expect(undoButton.onPressed, isNotNull);
    });
  });
}
