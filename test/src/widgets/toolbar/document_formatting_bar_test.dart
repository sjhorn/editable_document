/// Tests for [DocumentFormattingBar].
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
      home: Scaffold(body: child),
    );

MutableDocument _doc(String text) =>
    MutableDocument([ParagraphNode(id: 'p1', text: AttributedText(text))]);

DocumentEditingController _controllerWithSelection(
  MutableDocument doc,
  int start,
  int end,
) {
  final ctrl = DocumentEditingController(document: doc);
  ctrl.setSelection(
    DocumentSelection(
      base: DocumentPosition(
        nodeId: 'p1',
        nodePosition: TextNodePosition(offset: start),
      ),
      extent: DocumentPosition(
        nodeId: 'p1',
        nodePosition: TextNodePosition(offset: end),
      ),
    ),
  );
  return ctrl;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentFormattingBar', () {
    testWidgets('renders five toggle buttons', (tester) async {
      final doc = _doc('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentFormattingBar(
            controller: controller,
            requestHandler: requests.add,
          ),
        ),
      );

      // Bold, Italic, Underline, Strikethrough, Code.
      expect(find.byType(DocumentFormatToggle), findsNWidgets(5));
    });

    testWidgets('bold toggle emits ApplyAttributionRequest when no attribution active',
        (tester) async {
      final doc = _doc('Hello world');
      final controller = _controllerWithSelection(doc, 0, 5);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentFormattingBar(
            controller: controller,
            requestHandler: requests.add,
          ),
        ),
      );

      // Tap the Bold toggle.
      await tester.tap(find.byType(DocumentFormatToggle).first);
      await tester.pump();

      expect(requests, isNotEmpty);
      expect(requests.last, isA<ApplyAttributionRequest>());
    });

    testWidgets('toggles are disabled when selection is collapsed', (tester) async {
      final doc = _doc('Hello');
      final controller = DocumentEditingController(document: doc);
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentFormattingBar(
            controller: controller,
            requestHandler: requests.add,
          ),
        ),
      );

      for (final widget in tester.widgetList<DocumentFormatToggle>(
        find.byType(DocumentFormatToggle),
      )) {
        expect(widget.onPressed, isNull);
      }
    });

    testWidgets('rebuilds when controller selection changes', (tester) async {
      final doc = _doc('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentFormattingBar(
            controller: controller,
            requestHandler: requests.add,
          ),
        ),
      );

      // Initially collapsed — all toggles disabled.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      // Now expand selection.
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        ),
      );
      await tester.pump();

      // Bold toggle should now be enabled.
      final boldToggle =
          tester.widgetList<DocumentFormatToggle>(find.byType(DocumentFormatToggle)).first;
      expect(boldToggle.onPressed, isNotNull);
    });
  });
}
