/// Tests for [DocumentColorBar].
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

const _presets = {0xFFFF0000: 'Red', 0xFF0000FF: 'Blue'};

/// Builds a controller with an expanded selection spanning the full [text].
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
  group('DocumentColorBar', () {
    // -----------------------------------------------------------------------
    // Rendering
    // -----------------------------------------------------------------------

    testWidgets('renders two DocumentColorPicker widgets', (tester) async {
      final controller = _controllerNoSelection();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentColorBar(
            controller: controller,
            requestHandler: (_) {},
            colorPresets: _presets,
          ),
        ),
      );

      expect(find.byType(DocumentColorPicker), findsNWidgets(2));
    });

    testWidgets('both pickers disabled when no selection', (tester) async {
      final controller = _controllerNoSelection();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentColorBar(
            controller: controller,
            requestHandler: (_) {},
            colorPresets: _presets,
          ),
        ),
      );

      final pickers = tester.widgetList<DocumentColorPicker>(find.byType(DocumentColorPicker));
      for (final picker in pickers) {
        expect(picker.enabled, isFalse);
      }
    });

    testWidgets('both pickers enabled when selection is expanded', (tester) async {
      final controller = _controllerWithExpanded(text: 'Hello', start: 0, end: 5);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentColorBar(
            controller: controller,
            requestHandler: (_) {},
            colorPresets: _presets,
          ),
        ),
      );

      final pickers = tester.widgetList<DocumentColorPicker>(find.byType(DocumentColorPicker));
      for (final picker in pickers) {
        expect(picker.enabled, isTrue);
      }
    });

    testWidgets('rebuilds when controller selection changes', (tester) async {
      final doc = MutableDocument([ParagraphNode(id: 'p1', text: AttributedText('Hello'))]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentColorBar(
            controller: controller,
            requestHandler: (_) {},
            colorPresets: _presets,
          ),
        ),
      );

      // Initially all pickers disabled.
      for (final picker
          in tester.widgetList<DocumentColorPicker>(find.byType(DocumentColorPicker))) {
        expect(picker.enabled, isFalse);
      }

      // Give it an expanded selection.
      controller.setSelection(const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      ));
      await tester.pump();

      for (final picker
          in tester.widgetList<DocumentColorPicker>(find.byType(DocumentColorPicker))) {
        expect(picker.enabled, isTrue);
      }
    });

    // -----------------------------------------------------------------------
    // _applyAttribution — text color
    // -----------------------------------------------------------------------

    testWidgets(
        'onSelected with non-null value from text-color picker emits ApplyAttributionRequest',
        (tester) async {
      final controller = _controllerWithExpanded(text: 'Hello', start: 0, end: 5);
      addTearDown(controller.dispose);

      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentColorBar(
            controller: controller,
            requestHandler: requests.add,
            colorPresets: _presets,
          ),
        ),
      );

      // Invoke the first picker's onSelected directly by finding it.
      final firstPicker =
          tester.widgetList<DocumentColorPicker>(find.byType(DocumentColorPicker)).first;

      firstPicker.onSelected(0xFFFF0000);

      expect(requests.any((r) => r is ApplyAttributionRequest), isTrue);
      final apply = requests.whereType<ApplyAttributionRequest>().first;
      expect(apply.attribution, isA<TextColorAttribution>());
      expect((apply.attribution as TextColorAttribution).colorValue, 0xFFFF0000);
    });

    testWidgets('onSelected with null from text-color picker emits nothing when no attribution',
        (tester) async {
      final controller = _controllerWithExpanded(text: 'Hello', start: 0, end: 5);
      addTearDown(controller.dispose);

      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentColorBar(
            controller: controller,
            requestHandler: requests.add,
            colorPresets: _presets,
          ),
        ),
      );

      final firstPicker =
          tester.widgetList<DocumentColorPicker>(find.byType(DocumentColorPicker)).first;

      // null means "clear" — no TextColorAttribution present, so no requests.
      firstPicker.onSelected(null);
      expect(requests.whereType<RemoveAttributionRequest>().isEmpty, isTrue);
    });

    // -----------------------------------------------------------------------
    // _applyAttribution — background color
    // -----------------------------------------------------------------------

    testWidgets('onSelected with non-null from bg-color picker emits ApplyAttributionRequest',
        (tester) async {
      final controller = _controllerWithExpanded(text: 'Hello', start: 0, end: 5);
      addTearDown(controller.dispose);

      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentColorBar(
            controller: controller,
            requestHandler: requests.add,
            colorPresets: _presets,
          ),
        ),
      );

      final secondPicker =
          tester.widgetList<DocumentColorPicker>(find.byType(DocumentColorPicker)).elementAt(1);

      secondPicker.onSelected(0xFF0000FF);

      expect(requests.any((r) => r is ApplyAttributionRequest), isTrue);
      final apply = requests.whereType<ApplyAttributionRequest>().first;
      expect(apply.attribution, isA<BackgroundColorAttribution>());
      expect((apply.attribution as BackgroundColorAttribution).colorValue, 0xFF0000FF);
    });

    testWidgets('onSelected with null from bg-color picker calls _clearAttribution',
        (tester) async {
      final controller = _controllerWithExpanded(text: 'Hello', start: 0, end: 5);
      addTearDown(controller.dispose);

      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentColorBar(
            controller: controller,
            requestHandler: requests.add,
            colorPresets: _presets,
          ),
        ),
      );

      final secondPicker =
          tester.widgetList<DocumentColorPicker>(find.byType(DocumentColorPicker)).elementAt(1);

      // No BackgroundColorAttribution present — clear generates no requests.
      secondPicker.onSelected(null);
      expect(requests.whereType<RemoveAttributionRequest>().isEmpty, isTrue);
    });

    // -----------------------------------------------------------------------
    // Remove existing before applying new
    // -----------------------------------------------------------------------

    testWidgets('applying text color removes existing TextColorAttribution first', (tester) async {
      final existing = AttributedText(
        'Hello',
        [
          const SpanMarker(
            attribution: TextColorAttribution(0xFFFF0000),
            offset: 0,
            markerType: SpanMarkerType.start,
          ),
          const SpanMarker(
            attribution: TextColorAttribution(0xFFFF0000),
            offset: 4,
            markerType: SpanMarkerType.end,
          ),
        ],
      );
      final doc = MutableDocument([ParagraphNode(id: 'p1', text: existing)]);
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );
      addTearDown(controller.dispose);

      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentColorBar(
            controller: controller,
            requestHandler: requests.add,
            colorPresets: _presets,
          ),
        ),
      );

      final firstPicker =
          tester.widgetList<DocumentColorPicker>(find.byType(DocumentColorPicker)).first;

      firstPicker.onSelected(0xFF0000FF);

      expect(requests.whereType<RemoveAttributionRequest>().isNotEmpty, isTrue);
      expect(requests.whereType<ApplyAttributionRequest>().isNotEmpty, isTrue);
    });

    testWidgets('clearing text color removes existing TextColorAttribution', (tester) async {
      final existing = AttributedText(
        'Hello',
        [
          const SpanMarker(
            attribution: TextColorAttribution(0xFFFF0000),
            offset: 0,
            markerType: SpanMarkerType.start,
          ),
          const SpanMarker(
            attribution: TextColorAttribution(0xFFFF0000),
            offset: 4,
            markerType: SpanMarkerType.end,
          ),
        ],
      );
      final doc = MutableDocument([ParagraphNode(id: 'p1', text: existing)]);
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );
      addTearDown(controller.dispose);

      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          DocumentColorBar(
            controller: controller,
            requestHandler: requests.add,
            colorPresets: _presets,
          ),
        ),
      );

      final firstPicker =
          tester.widgetList<DocumentColorPicker>(find.byType(DocumentColorPicker)).first;

      firstPicker.onSelected(null);

      expect(requests.whereType<RemoveAttributionRequest>().isNotEmpty, isTrue);
    });

    // -----------------------------------------------------------------------
    // debugFillProperties
    // -----------------------------------------------------------------------

    testWidgets('debugFillProperties includes controller, requestHandler, colorPresets',
        (tester) async {
      final controller = _controllerNoSelection();
      addTearDown(controller.dispose);

      final widget = DocumentColorBar(
        controller: controller,
        requestHandler: (_) {},
        colorPresets: _presets,
      );

      final builder = DiagnosticPropertiesBuilder();
      widget.debugFillProperties(builder);
      final keys = builder.properties.map((p) => p.name).toList();

      expect(keys, containsAll(['controller', 'requestHandler', 'colorPresets']));
    });
  });
}
