/// Tests for [DocumentToolbar].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] using [InkRipple] to avoid the ink_sparkle shader error.
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: SingleChildScrollView(scrollDirection: Axis.horizontal, child: child)),
    );

MutableDocument _doc() => MutableDocument([ParagraphNode(id: 'p1', text: AttributedText('Hello'))]);

UndoableEditor _editorFor(MutableDocument doc) {
  final ctrl = DocumentEditingController(document: doc);
  return UndoableEditor(editContext: EditContext(document: doc, controller: ctrl));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentToolbar', () {
    testWidgets('renders all sub-bars by default', (tester) async {
      final doc = _doc();
      final controller = DocumentEditingController(document: doc);
      final editor = _editorFor(doc);

      await tester.pumpWidget(
        _wrap(
          DocumentToolbar(
            controller: controller,
            requestHandler: (_) {},
            editor: editor,
          ),
        ),
      );

      expect(find.byType(DocumentFormattingBar), findsOneWidget);
      expect(find.byType(DocumentBlockTypeBar), findsOneWidget);
      expect(find.byType(DocumentAlignmentBar), findsOneWidget);
      expect(find.byType(DocumentInsertBar), findsOneWidget);
      expect(find.byType(DocumentFontBar), findsOneWidget);
      expect(find.byType(DocumentColorBar), findsOneWidget);
      expect(find.byType(DocumentUndoRedoBar), findsOneWidget);
      expect(find.byType(DocumentListIndentBar), findsOneWidget);
    });

    testWidgets('hides DocumentFormattingBar when showFormatting is false', (tester) async {
      final doc = _doc();
      final controller = DocumentEditingController(document: doc);

      await tester.pumpWidget(
        _wrap(
          DocumentToolbar(
            controller: controller,
            requestHandler: (_) {},
            showFormatting: false,
          ),
        ),
      );

      expect(find.byType(DocumentFormattingBar), findsNothing);
    });

    testWidgets('hides DocumentUndoRedoBar when editor is null', (tester) async {
      final doc = _doc();
      final controller = DocumentEditingController(document: doc);

      await tester.pumpWidget(
        _wrap(
          DocumentToolbar(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      expect(find.byType(DocumentUndoRedoBar), findsNothing);
    });

    testWidgets('leading and trailing widgets are rendered', (tester) async {
      final doc = _doc();
      final controller = DocumentEditingController(document: doc);

      await tester.pumpWidget(
        _wrap(
          DocumentToolbar(
            controller: controller,
            requestHandler: (_) {},
            leading: const Icon(Icons.star, key: Key('leading')),
            trailing: const Icon(Icons.settings, key: Key('trailing')),
          ),
        ),
      );

      expect(find.byKey(const Key('leading')), findsOneWidget);
      expect(find.byKey(const Key('trailing')), findsOneWidget);
    });
  });
}
