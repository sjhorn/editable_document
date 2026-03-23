/// Tests for [DocumentFontBar].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: Center(child: child)),
    );

/// Builds a controller with a paragraph containing [text], with a selection
/// spanning [start]..[end] in node [id].
DocumentEditingController _controllerWithExpanded({
  required String text,
  required int start,
  required int end,
  String id = 'p1',
}) {
  final doc = MutableDocument([ParagraphNode(id: id, text: AttributedText(text))]);
  return DocumentEditingController(
    document: doc,
    selection: DocumentSelection(
      base: DocumentPosition(nodeId: id, nodePosition: TextNodePosition(offset: start)),
      extent: DocumentPosition(nodeId: id, nodePosition: TextNodePosition(offset: end)),
    ),
  );
}

/// Builds a controller with no selection.
DocumentEditingController _controllerNoSelection({String text = 'Hello'}) {
  final doc = MutableDocument([ParagraphNode(id: 'p1', text: AttributedText(text))]);
  return DocumentEditingController(document: doc);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentFontBar', () {
    // -----------------------------------------------------------------------
    // Rendering
    // -----------------------------------------------------------------------

    testWidgets('renders two DropdownButtons when no selection', (tester) async {
      final controller = _controllerNoSelection();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentFontBar(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      // Two DropdownButton widgets present (font family + font size).
      expect(find.byType(DropdownButton<String?>), findsOneWidget);
      expect(find.byType(DropdownButton<double?>), findsOneWidget);
    });

    testWidgets('dropdowns are disabled (null onChanged) when no selection', (tester) async {
      final controller = _controllerNoSelection();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentFontBar(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      final fontDrop = tester.widget<DropdownButton<String?>>(
        find.byType(DropdownButton<String?>),
      );
      final sizeDrop = tester.widget<DropdownButton<double?>>(
        find.byType(DropdownButton<double?>),
      );

      expect(fontDrop.onChanged, isNull);
      expect(sizeDrop.onChanged, isNull);
    });

    testWidgets('dropdowns are enabled when there is an expanded selection', (tester) async {
      final controller = _controllerWithExpanded(text: 'Hello', start: 0, end: 5);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentFontBar(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      final fontDrop = tester.widget<DropdownButton<String?>>(
        find.byType(DropdownButton<String?>),
      );
      final sizeDrop = tester.widget<DropdownButton<double?>>(
        find.byType(DropdownButton<double?>),
      );

      expect(fontDrop.onChanged, isNotNull);
      expect(sizeDrop.onChanged, isNotNull);
    });

    testWidgets('rebuilds when controller selection changes', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentFontBar(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      // Initially disabled.
      expect(
        tester.widget<DropdownButton<String?>>(find.byType(DropdownButton<String?>)).onChanged,
        isNull,
      );

      // Give it an expanded selection.
      controller.setSelection(const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      ));
      await tester.pump();

      expect(
        tester.widget<DropdownButton<String?>>(find.byType(DropdownButton<String?>)).onChanged,
        isNotNull,
      );
    });

    testWidgets('uses custom fontFamilies and fontSizes when provided', (tester) async {
      final controller = _controllerNoSelection();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentFontBar(
            controller: controller,
            requestHandler: (_) {},
            fontFamilies: const {null: 'Default', 'Arial': 'Arial'},
            fontSizes: const [null, 10.0, 20.0],
          ),
        ),
      );

      expect(find.byType(DocumentFontBar), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // _applyAttribution — font family
    // -----------------------------------------------------------------------

    testWidgets('selecting a font family emits ApplyAttributionRequest', (tester) async {
      final controller = _controllerWithExpanded(text: 'Hello', start: 0, end: 5);
      addTearDown(controller.dispose);

      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentFontBar(
            controller: controller,
            requestHandler: requests.add,
            fontFamilies: const {null: 'Default', 'Georgia': 'Serif'},
            fontSizes: DocumentFontBar.defaultFontSizes,
          ),
        ),
      );

      // Open the font-family dropdown.
      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();

      // Tap 'Serif' (Georgia).
      await tester.tap(find.text('Serif').last);
      await tester.pumpAndSettle();

      expect(
        requests.any((r) => r is ApplyAttributionRequest),
        isTrue,
      );
      final apply = requests.whereType<ApplyAttributionRequest>().first;
      expect(apply.attribution, isA<FontFamilyAttribution>());
      expect((apply.attribution as FontFamilyAttribution).fontFamily, 'Georgia');
    });

    testWidgets('selecting Default font family emits nothing when no existing attribution',
        (tester) async {
      final controller = _controllerWithExpanded(text: 'Hello', start: 0, end: 5);
      addTearDown(controller.dispose);

      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentFontBar(
            controller: controller,
            requestHandler: requests.add,
            fontFamilies: const {null: 'Default', 'Georgia': 'Serif'},
            fontSizes: DocumentFontBar.defaultFontSizes,
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();

      // Tap 'Default' (null value).
      await tester.tap(find.text('Default').last);
      await tester.pumpAndSettle();

      // _clearAttribution finds no FontFamilyAttribution to remove, so no requests.
      expect(requests.whereType<RemoveAttributionRequest>().isEmpty, isTrue);
    });

    // -----------------------------------------------------------------------
    // _applyAttribution — font size
    // -----------------------------------------------------------------------

    testWidgets('selecting a font size emits ApplyAttributionRequest', (tester) async {
      final controller = _controllerWithExpanded(text: 'Hello', start: 0, end: 5);
      addTearDown(controller.dispose);

      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentFontBar(
            controller: controller,
            requestHandler: requests.add,
            fontFamilies: DocumentFontBar.defaultFontFamilies,
            fontSizes: const [null, 16.0],
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButton<double?>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('16').last);
      await tester.pumpAndSettle();

      expect(requests.any((r) => r is ApplyAttributionRequest), isTrue);
      final apply = requests.whereType<ApplyAttributionRequest>().first;
      expect(apply.attribution, isA<FontSizeAttribution>());
      expect((apply.attribution as FontSizeAttribution).fontSize, 16.0);
    });

    testWidgets('selecting Default size calls _clearAttribution (no requests when none set)',
        (tester) async {
      final controller = _controllerWithExpanded(text: 'Hello', start: 0, end: 5);
      addTearDown(controller.dispose);

      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentFontBar(
            controller: controller,
            requestHandler: requests.add,
            fontFamilies: DocumentFontBar.defaultFontFamilies,
            fontSizes: const [null, 16.0],
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButton<double?>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Default').last);
      await tester.pumpAndSettle();

      // No FontSizeAttribution present, so no remove requests generated.
      expect(requests.whereType<RemoveAttributionRequest>().isEmpty, isTrue);
    });

    // -----------------------------------------------------------------------
    // _applyAttribution removes existing before applying new
    // -----------------------------------------------------------------------

    // -----------------------------------------------------------------------
    // debugFillProperties
    // -----------------------------------------------------------------------

    testWidgets('debugFillProperties includes controller and requestHandler', (tester) async {
      final controller = _controllerNoSelection();
      addTearDown(controller.dispose);

      final widget = DocumentFontBar(
        controller: controller,
        requestHandler: (_) {},
      );

      final builder = DiagnosticPropertiesBuilder();
      widget.debugFillProperties(builder);
      final keys = builder.properties.map((p) => p.name).toList();

      expect(keys, containsAll(['controller', 'requestHandler', 'fontFamilies', 'fontSizes']));
    });
  });
}
