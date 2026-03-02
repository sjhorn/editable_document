/// Tests for [ComposerPreferences] and [DocumentEditingController].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates a small three-node document for use across tests.
MutableDocument createTestDocument() => MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText('Hello world')),
      ParagraphNode(id: 'p2', text: AttributedText('Second paragraph')),
      ImageNode(id: 'img1', imageUrl: 'https://example.com/image.png'),
    ]);

/// A collapsed [DocumentSelection] anchored at offset 5 in node `p1`.
DocumentSelection get _collapsedAtFive => const DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: 'p1',
        nodePosition: TextNodePosition(offset: 5),
      ),
    );

/// An expanded [DocumentSelection] from offset 0 in `p1` to offset 5 in `p1`.
DocumentSelection get _expandedSelection => const DocumentSelection(
      base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
      extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
    );

void main() {
  // =========================================================================
  // ComposerPreferences
  // =========================================================================

  group('ComposerPreferences', () {
    test('1. default has no active attributions', () {
      final prefs = ComposerPreferences();
      expect(prefs.attributions, isEmpty);
    });

    test('2. activate adds an attribution', () {
      final prefs = ComposerPreferences();
      prefs.activate(NamedAttribution.bold);
      expect(prefs.attributions, contains(NamedAttribution.bold));
    });

    test('3. deactivate removes an attribution', () {
      final prefs = ComposerPreferences(
        attributions: {NamedAttribution.bold, NamedAttribution.italics},
      );
      prefs.deactivate(NamedAttribution.bold);
      expect(prefs.attributions, isNot(contains(NamedAttribution.bold)));
      expect(prefs.attributions, contains(NamedAttribution.italics));
    });

    test('4. toggle activates when inactive', () {
      final prefs = ComposerPreferences();
      prefs.toggle(NamedAttribution.bold);
      expect(prefs.attributions, contains(NamedAttribution.bold));
    });

    test('5. toggle deactivates when active', () {
      final prefs = ComposerPreferences(attributions: {NamedAttribution.bold});
      prefs.toggle(NamedAttribution.bold);
      expect(prefs.attributions, isNot(contains(NamedAttribution.bold)));
    });

    test('6. isActive returns true for active attributions', () {
      final prefs = ComposerPreferences(attributions: {NamedAttribution.bold});
      expect(prefs.isActive(NamedAttribution.bold), isTrue);
    });

    test('7. isActive returns false for inactive attributions', () {
      final prefs = ComposerPreferences();
      expect(prefs.isActive(NamedAttribution.bold), isFalse);
    });

    test('8. clearAll removes all attributions', () {
      final prefs = ComposerPreferences(
        attributions: {NamedAttribution.bold, NamedAttribution.italics},
      );
      prefs.clearAll();
      expect(prefs.attributions, isEmpty);
    });

    test('9. attributions getter returns unmodifiable set', () {
      final prefs = ComposerPreferences(attributions: {NamedAttribution.bold});
      expect(
        () => prefs.attributions.add(NamedAttribution.italics),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('10. equality: same attributions are equal', () {
      final a = ComposerPreferences(attributions: {NamedAttribution.bold});
      final b = ComposerPreferences(attributions: {NamedAttribution.bold});
      expect(a, equals(b));
    });

    test('11. equality: different attributions not equal', () {
      final a = ComposerPreferences(attributions: {NamedAttribution.bold});
      final b = ComposerPreferences(attributions: {NamedAttribution.italics});
      expect(a, isNot(equals(b)));
    });

    test('12. toString includes attributions', () {
      final prefs = ComposerPreferences(attributions: {NamedAttribution.bold});
      expect(prefs.toString(), contains('bold'));
    });
  });

  // =========================================================================
  // DocumentEditingController
  // =========================================================================

  group('DocumentEditingController', () {
    test('1. initial state: document is set, selection is null, preferences empty', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      expect(controller.document, same(doc));
      expect(controller.selection, isNull);
      expect(controller.preferences.attributions, isEmpty);
      controller.dispose();
    });

    test('2. initial state with selection: selection preserved', () {
      final doc = createTestDocument();
      final sel = _collapsedAtFive;
      final controller = DocumentEditingController(document: doc, selection: sel);
      expect(controller.selection, equals(sel));
      controller.dispose();
    });

    test('3. setSelection updates selection and notifies', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setSelection(_collapsedAtFive);

      expect(controller.selection, equals(_collapsedAtFive));
      expect(notifyCount, 1);
      controller.dispose();
    });

    test('4. setSelection with same value does not notify', () {
      final doc = createTestDocument();
      final sel = _collapsedAtFive;
      final controller = DocumentEditingController(document: doc, selection: sel);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setSelection(sel);

      expect(notifyCount, 0);
      controller.dispose();
    });

    test('5. clearSelection sets selection to null and notifies', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc, selection: _collapsedAtFive);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.clearSelection();

      expect(controller.selection, isNull);
      expect(notifyCount, 1);
      controller.dispose();
    });

    test('6. collapseSelection collapses expanded selection to extent', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc, selection: _expandedSelection);

      controller.collapseSelection();

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        controller.selection!.extent,
        equals(_expandedSelection.extent),
      );
      controller.dispose();
    });

    test('7. collapseSelection is no-op when already collapsed', () {
      final doc = createTestDocument();
      final sel = _collapsedAtFive;
      final controller = DocumentEditingController(document: doc, selection: sel);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.collapseSelection();

      expect(notifyCount, 0);
      expect(controller.selection, equals(sel));
      controller.dispose();
    });

    test('8. collapseSelection is no-op when selection is null', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.collapseSelection();

      expect(notifyCount, 0);
      expect(controller.selection, isNull);
      controller.dispose();
    });

    test('9. document getter returns the document', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      expect(controller.document, same(doc));
      controller.dispose();
    });

    test('10. preferences getter returns preferences', () {
      final doc = createTestDocument();
      final prefs = ComposerPreferences(attributions: {NamedAttribution.bold});
      final controller = DocumentEditingController(document: doc, preferences: prefs);
      expect(controller.preferences, same(prefs));
      controller.dispose();
    });

    test('11. listener fires on setSelection', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      var fired = false;
      controller.addListener(() => fired = true);

      controller.setSelection(_collapsedAtFive);

      expect(fired, isTrue);
      controller.dispose();
    });

    test('12. multiple listeners all fire', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      var count1 = 0;
      var count2 = 0;
      controller.addListener(() => count1++);
      controller.addListener(() => count2++);

      controller.setSelection(_collapsedAtFive);

      expect(count1, 1);
      expect(count2, 1);
      controller.dispose();
    });

    test('13. removing listener stops notifications', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      var count = 0;
      void listener() => count++;
      controller.addListener(listener);

      controller.setSelection(_collapsedAtFive);
      controller.removeListener(listener);
      controller.setSelection(null);

      expect(count, 1);
      controller.dispose();
    });

    test('14. buildNodeSpan returns TextSpan for TextNode', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      final node = TextNode(id: 'tn1', text: AttributedText('raw text'));

      final span = controller.buildNodeSpan(node);

      expect(span, isA<TextSpan>());
      expect((span! as TextSpan).text, equals('raw text'));
      controller.dispose();
    });

    test('15. buildNodeSpan returns TextSpan for ParagraphNode', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      final node = doc.nodeById('p1')!;

      final span = controller.buildNodeSpan(node);

      expect(span, isA<TextSpan>());
      expect((span! as TextSpan).text, equals('Hello world'));
      controller.dispose();
    });

    test('16. buildNodeSpan returns null for non-text nodes', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);

      final imgNode = doc.nodeById('img1')!;
      expect(controller.buildNodeSpan(imgNode), isNull);

      final hrNode = HorizontalRuleNode(id: 'hr1');
      expect(controller.buildNodeSpan(hrNode), isNull);

      controller.dispose();
    });

    test('17. buildNodeSpan applies style parameter', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      const style = TextStyle(fontSize: 24.0);
      final node = doc.nodeById('p1')!;

      final span = controller.buildNodeSpan(node, style: style);

      expect(span, isA<TextSpan>());
      expect((span! as TextSpan).style, equals(style));
      controller.dispose();
    });

    test('18. dispose does not throw', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      expect(() => controller.dispose(), returnsNormally);
    });

    test('19. autofillHints defaults to null', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      expect(controller.autofillHints, isNull);
      controller.dispose();
    });

    test('20. autofillHints constructor parameter round-trips', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(
        document: doc,
        autofillHints: ['email'],
      );
      expect(controller.autofillHints, equals(['email']));
      controller.dispose();
    });

    test('21. autofillHints setter fires listeners', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(document: doc);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.autofillHints = ['password'];

      expect(controller.autofillHints, equals(['password']));
      expect(notifyCount, 1);
      controller.dispose();
    });

    test('22. autofillHints setter with same value does not notify', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(
        document: doc,
        autofillHints: ['email'],
      );
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.autofillHints = ['email'];

      expect(notifyCount, 0);
      controller.dispose();
    });

    test('23. autofillHints setter with null fires listeners when was non-null', () {
      final doc = createTestDocument();
      final controller = DocumentEditingController(
        document: doc,
        autofillHints: ['email'],
      );
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.autofillHints = null;

      expect(controller.autofillHints, isNull);
      expect(notifyCount, 1);
      controller.dispose();
    });
  });
}
