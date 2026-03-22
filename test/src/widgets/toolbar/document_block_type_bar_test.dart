/// Tests for [DocumentBlockTypeBar].
library;

import 'package:editable_document/editable_document.dart';
import 'package:editable_document/src/widgets/toolbar/document_block_type_bar.dart';
import 'package:editable_document/src/widgets/toolbar/document_format_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] using [InkRipple] to avoid the ink_sparkle shader error.
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('DocumentBlockTypeBar', () {
    testWidgets('renders five block type toggles', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = DocumentEditingController(document: doc);

      await tester.pumpWidget(
        _wrap(
          DocumentBlockTypeBar(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      // Paragraph, Blockquote, Code, Bullet, Numbered.
      expect(find.byType(DocumentFormatToggle), findsNWidgets(5));
    });

    testWidgets('all toggles are disabled when no cursor in document', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = DocumentEditingController(document: doc);

      await tester.pumpWidget(
        _wrap(
          DocumentBlockTypeBar(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      for (final toggle in tester.widgetList<DocumentFormatToggle>(
        find.byType(DocumentFormatToggle),
      )) {
        expect(toggle.onPressed, isNull);
      }
    });

    testWidgets('paragraph toggle is active when cursor is on a paragraph', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = DocumentEditingController(document: doc);
      controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          DocumentBlockTypeBar(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      // First toggle = Paragraph — should be active.
      final paragraphToggle =
          tester.widgetList<DocumentFormatToggle>(find.byType(DocumentFormatToggle)).first;
      expect(paragraphToggle.isActive, isTrue);
    });

    testWidgets('paragraph toggle submits ReplaceNodeRequest on press', (tester) async {
      final doc = MutableDocument([
        ListItemNode(
          id: 'li1',
          text: AttributedText('Hello'),
          type: ListItemType.unordered,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'li1',
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentBlockTypeBar(
            controller: controller,
            requestHandler: requests.add,
          ),
        ),
      );

      // Tap Paragraph toggle.
      await tester.tap(find.byType(DocumentFormatToggle).first);
      await tester.pump();

      expect(requests, isNotEmpty);
      expect(requests.last, isA<ReplaceNodeRequest>());
    });
  });
}
