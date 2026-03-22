/// Tests for [defaultDocumentContextMenuButtonItems].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DocumentEditingController _makeController({
    String text = 'Hello world',
    DocumentSelection? selection,
  }) {
    final doc = MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText(text)),
    ]);
    return DocumentEditingController(document: doc, selection: selection);
  }

  DocumentSelection _expandedSelection() => const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );

  DocumentSelection _collapsedSelection() => const DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );

  group('defaultDocumentContextMenuButtonItems', () {
    test('returns Cut, Copy, Paste, SelectAll when selection is expanded', () {
      final controller = _makeController(selection: _expandedSelection());
      const clipboard = DocumentClipboard();
      final items = defaultDocumentContextMenuButtonItems(
        controller: controller,
        clipboard: clipboard,
      );

      final labels = items.map((i) => i.label).toList();
      expect(labels, containsAll(['Cut', 'Copy', 'Paste', 'Select All']));
    });

    test('omits Cut when readOnly is true', () {
      final controller = _makeController(selection: _expandedSelection());
      const clipboard = DocumentClipboard();
      final items = defaultDocumentContextMenuButtonItems(
        controller: controller,
        clipboard: clipboard,
        readOnly: true,
      );

      final labels = items.map((i) => i.label).toList();
      expect(labels, isNot(contains('Cut')));
      expect(labels, contains('Copy'));
      expect(labels, isNot(contains('Paste')));
      expect(labels, contains('Select All'));
    });

    test('omits Cut and Copy when selection is collapsed', () {
      final controller = _makeController(selection: _collapsedSelection());
      const clipboard = DocumentClipboard();
      final items = defaultDocumentContextMenuButtonItems(
        controller: controller,
        clipboard: clipboard,
      );

      final labels = items.map((i) => i.label).toList();
      expect(labels, isNot(contains('Cut')));
      expect(labels, isNot(contains('Copy')));
      expect(labels, contains('Paste'));
      expect(labels, contains('Select All'));
    });

    test('omits Cut and Copy when selection is null', () {
      final controller = _makeController();
      const clipboard = DocumentClipboard();
      final items = defaultDocumentContextMenuButtonItems(
        controller: controller,
        clipboard: clipboard,
      );

      final labels = items.map((i) => i.label).toList();
      expect(labels, isNot(contains('Cut')));
      expect(labels, isNot(contains('Copy')));
      expect(labels, contains('Paste'));
      expect(labels, contains('Select All'));
    });

    test('returns only Copy and SelectAll when readOnly with expanded selection', () {
      final controller = _makeController(selection: _expandedSelection());
      const clipboard = DocumentClipboard();
      final items = defaultDocumentContextMenuButtonItems(
        controller: controller,
        clipboard: clipboard,
        readOnly: true,
      );

      final labels = items.map((i) => i.label).toList();
      expect(labels, ['Copy', 'Select All']);
    });

    testWidgets('Cut button calls clipboard.cut via onPressed', (WidgetTester tester) async {
      // Install a clipboard mock so Clipboard.setData doesn't throw.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') return null;
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': ''};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      EditRequest? submittedRequest;
      final controller = _makeController(selection: _expandedSelection());
      const clipboard = DocumentClipboard();

      final items = defaultDocumentContextMenuButtonItems(
        controller: controller,
        clipboard: clipboard,
        requestHandler: (req) => submittedRequest = req,
      );

      final cutItem = items.firstWhere((i) => i.label == 'Cut');
      cutItem.onPressed!();
      await tester.pumpAndSettle();

      expect(submittedRequest, isA<DeleteContentRequest>());
    });
  });
}
