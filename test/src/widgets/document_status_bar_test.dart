/// Tests for [DocumentStatusBar], [documentWordCount], and [documentCharCount].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MutableDocument _makeDocument(List<String> paragraphs) {
  return MutableDocument([
    for (int i = 0; i < paragraphs.length; i++)
      ParagraphNode(id: 'p$i', text: AttributedText(paragraphs[i])),
  ]);
}

DocumentEditingController _makeController(
  MutableDocument doc, {
  DocumentSelection? selection,
}) {
  return DocumentEditingController(document: doc, selection: selection);
}

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('documentWordCount', () {
    test('returns 0 for empty document', () {
      final doc = MutableDocument([]);
      expect(documentWordCount(doc), 0);
    });

    test('counts words in a single paragraph', () {
      final doc = _makeDocument(['Hello world foo']);
      expect(documentWordCount(doc), 3);
    });

    test('counts words across multiple paragraphs', () {
      final doc = _makeDocument(['Hello world', 'foo bar baz']);
      expect(documentWordCount(doc), 5);
    });

    test('trims whitespace before counting', () {
      final doc = _makeDocument(['  hello   world  ']);
      expect(documentWordCount(doc), 2);
    });

    test('ignores non-text nodes', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('one two')),
        HorizontalRuleNode(id: 'hr1'),
      ]);
      expect(documentWordCount(doc), 2);
    });
  });

  group('documentCharCount', () {
    test('returns 0 for empty document', () {
      final doc = MutableDocument([]);
      expect(documentCharCount(doc), 0);
    });

    test('counts characters in a single paragraph', () {
      final doc = _makeDocument(['Hello']);
      expect(documentCharCount(doc), 5);
    });

    test('counts characters across multiple paragraphs', () {
      final doc = _makeDocument(['Hello', 'World']);
      expect(documentCharCount(doc), 10);
    });

    test('ignores non-text nodes', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('abc')),
        HorizontalRuleNode(id: 'hr1'),
      ]);
      expect(documentCharCount(doc), 3);
    });
  });

  group('DocumentStatusBar', () {
    testWidgets('shows block count', (tester) async {
      final doc = _makeDocument(['a', 'b', 'c']);
      final controller = _makeController(doc);

      await tester.pumpWidget(
        _wrap(DocumentStatusBar(controller: controller)),
      );

      expect(find.text('3 blocks'), findsOneWidget);
    });

    testWidgets('shows word count', (tester) async {
      final doc = _makeDocument(['hello world', 'foo']);
      final controller = _makeController(doc);

      await tester.pumpWidget(
        _wrap(DocumentStatusBar(controller: controller)),
      );

      expect(find.text('3 words'), findsOneWidget);
    });

    testWidgets('shows character count', (tester) async {
      final doc = _makeDocument(['abc', 'de']);
      final controller = _makeController(doc);

      await tester.pumpWidget(
        _wrap(DocumentStatusBar(controller: controller)),
      );

      expect(find.text('5 chars'), findsOneWidget);
    });

    testWidgets('hides block count when showBlockCount is false', (tester) async {
      final doc = _makeDocument(['a', 'b']);
      final controller = _makeController(doc);

      await tester.pumpWidget(
        _wrap(
          DocumentStatusBar(
            controller: controller,
            showBlockCount: false,
          ),
        ),
      );

      expect(find.text('2 blocks'), findsNothing);
    });

    testWidgets('hides word count when showWordCount is false', (tester) async {
      final doc = _makeDocument(['hello world']);
      final controller = _makeController(doc);

      await tester.pumpWidget(
        _wrap(
          DocumentStatusBar(
            controller: controller,
            showWordCount: false,
          ),
        ),
      );

      expect(find.text('2 words'), findsNothing);
    });

    testWidgets('hides char count when showCharCount is false', (tester) async {
      final doc = _makeDocument(['hello']);
      final controller = _makeController(doc);

      await tester.pumpWidget(
        _wrap(
          DocumentStatusBar(
            controller: controller,
            showCharCount: false,
          ),
        ),
      );

      expect(find.text('5 chars'), findsNothing);
    });

    testWidgets('shows block type label for selected paragraph node', (tester) async {
      final doc = _makeDocument(['hello']);
      final sel = const DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p0',
          nodePosition: TextNodePosition(offset: 0),
        ),
      );
      final controller = _makeController(doc, selection: sel);

      await tester.pumpWidget(
        _wrap(DocumentStatusBar(controller: controller)),
      );

      expect(find.text('Paragraph'), findsOneWidget);
    });

    testWidgets('hides block type label when showCurrentBlockType is false', (tester) async {
      final doc = _makeDocument(['hello']);
      final sel = const DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p0',
          nodePosition: TextNodePosition(offset: 0),
        ),
      );
      final controller = _makeController(doc, selection: sel);

      await tester.pumpWidget(
        _wrap(
          DocumentStatusBar(
            controller: controller,
            showCurrentBlockType: false,
          ),
        ),
      );

      expect(find.text('Paragraph'), findsNothing);
    });

    testWidgets('shows no block type label when selection is null', (tester) async {
      final doc = _makeDocument(['hello']);
      final controller = _makeController(doc);

      await tester.pumpWidget(
        _wrap(DocumentStatusBar(controller: controller)),
      );

      // "Paragraph" should not appear without a selection
      expect(find.text('Paragraph'), findsNothing);
    });

    testWidgets('renders trailing widgets', (tester) async {
      final doc = _makeDocument(['hello']);
      final controller = _makeController(doc);

      await tester.pumpWidget(
        _wrap(
          DocumentStatusBar(
            controller: controller,
            trailing: const [Text('extra')],
          ),
        ),
      );

      expect(find.text('extra'), findsOneWidget);
    });
  });
}
