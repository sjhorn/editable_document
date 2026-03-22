/// Tests for [DocumentAlignmentBar].
library;

import 'package:editable_document/editable_document.dart';
import 'package:editable_document/src/widgets/toolbar/document_alignment_bar.dart';
import 'package:editable_document/src/widgets/toolbar/document_format_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] using [InkRipple] to avoid the ink_sparkle shader error.
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('DocumentAlignmentBar', () {
    testWidgets('renders four alignment toggles', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = DocumentEditingController(document: doc);

      await tester.pumpWidget(
        _wrap(
          DocumentAlignmentBar(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      // Left, Center, Right, Justify.
      expect(find.byType(DocumentFormatToggle), findsNWidgets(4));
    });

    testWidgets('left-align toggle is active for default paragraph', (tester) async {
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
          DocumentAlignmentBar(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      // First toggle = Left (TextAlign.start) — should be active.
      final leftToggle =
          tester.widgetList<DocumentFormatToggle>(find.byType(DocumentFormatToggle)).first;
      expect(leftToggle.isActive, isTrue);
    });

    testWidgets('emits ChangeTextAlignRequest when alignment toggle pressed', (tester) async {
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
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentAlignmentBar(
            controller: controller,
            requestHandler: requests.add,
          ),
        ),
      );

      // Tap Center (second toggle).
      await tester.tap(find.byType(DocumentFormatToggle).at(1));
      await tester.pump();

      expect(requests, isNotEmpty);
      expect(requests.last, isA<ChangeTextAlignRequest>());
      expect((requests.last as ChangeTextAlignRequest).newTextAlign, TextAlign.center);
    });
  });
}
