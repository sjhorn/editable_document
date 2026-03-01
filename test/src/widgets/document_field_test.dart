/// Tests for [DocumentField] — Phase 5.4.
///
/// Covers widget construction, InputDecorator integration, focus/label
/// animation, error state, counter display, enabled/disabled state, and
/// delegation to [EditableDocument].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [MutableDocument] with a single paragraph of [text].
MutableDocument _makeDocument({String text = 'Hello'}) {
  return MutableDocument([
    ParagraphNode(id: 'p1', text: AttributedText(text)),
  ]);
}

/// Creates a [DocumentEditingController] with a single paragraph of [text].
DocumentEditingController _makeController({String text = 'Hello'}) {
  return DocumentEditingController(document: _makeDocument(text: text));
}

/// Wraps [child] in [MaterialApp] + [Scaffold] for a full widget environment.
Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Construction / basic rendering
  // -------------------------------------------------------------------------

  group('DocumentField — construction', () {
    testWidgets('builds without error with default parameters', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(DocumentField(controller: controller)));

      expect(find.byType(DocumentField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds without error when no controller is provided', (tester) async {
      await tester.pumpWidget(_wrap(const DocumentField()));

      expect(find.byType(DocumentField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds without error when no focusNode is provided', (tester) async {
      await tester.pumpWidget(_wrap(const DocumentField()));

      expect(find.byType(DocumentField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an InputDecorator in the tree', (tester) async {
      await tester.pumpWidget(_wrap(const DocumentField()));

      expect(find.byType(InputDecorator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an EditableDocument in the tree', (tester) async {
      await tester.pumpWidget(_wrap(const DocumentField()));

      expect(find.byType(EditableDocument), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('default parameters are correct', (tester) async {
      await tester.pumpWidget(_wrap(const DocumentField()));

      final widget = tester.widget<DocumentField>(find.byType(DocumentField));
      expect(widget.readOnly, isFalse);
      expect(widget.autofocus, isFalse);
      expect(widget.enabled, isTrue);
      expect(widget.textAlign, TextAlign.start);
      expect(widget.blockSpacing, 12.0);
      expect(widget.maxLength, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // InputDecoration rendering
  // -------------------------------------------------------------------------

  group('DocumentField — InputDecoration', () {
    testWidgets('shows label text when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DocumentField(
            decoration: InputDecoration(labelText: 'Title'),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows hint text when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DocumentField(
            decoration: InputDecoration(hintText: 'Enter text here'),
          ),
        ),
      );

      expect(find.text('Enter text here'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows error text when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DocumentField(
            decoration: InputDecoration(errorText: 'Required field'),
          ),
        ),
      );

      expect(find.text('Required field'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows helper text when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DocumentField(
            decoration: InputDecoration(helperText: 'Optional'),
          ),
        ),
      );

      expect(find.text('Optional'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('decoration is null gives default InputDecoration behavior', (tester) async {
      await tester.pumpWidget(
        _wrap(const DocumentField(decoration: null)),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('prefix text shown when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DocumentField(
            decoration: InputDecoration(prefixText: '\$'),
          ),
        ),
      );

      expect(find.text('\$'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('suffix text shown when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DocumentField(
            decoration: InputDecoration(suffixText: 'kg'),
          ),
        ),
      );

      expect(find.text('kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Focus / label animation
  // -------------------------------------------------------------------------

  group('DocumentField — focus', () {
    testWidgets('focuses when tapped', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentField(focusNode: focusNode),
        ),
      );

      expect(focusNode.hasFocus, isFalse);

      await tester.tap(find.byType(DocumentField));
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('external focusNode gains focus when requestFocus called', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(focusNode: focusNode)),
      );

      focusNode.requestFocus();
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('label floats when field is focused', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentField(
            focusNode: focusNode,
            decoration: const InputDecoration(labelText: 'My Label'),
          ),
        ),
      );

      // Before focus — label is not floating.
      InputDecorator decorator = tester.widget(find.byType(InputDecorator));
      expect(decorator.isFocused, isFalse);

      focusNode.requestFocus();
      await tester.pump();

      // After focus — label should be floating.
      decorator = tester.widget(find.byType(InputDecorator));
      expect(decorator.isFocused, isTrue);
    });

    testWidgets('autofocus gains focus on mount', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(focusNode: focusNode, autofocus: true)),
      );
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // isEmpty tracking
  // -------------------------------------------------------------------------

  group('DocumentField — isEmpty', () {
    testWidgets('isEmpty is true when document has no text content', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('')),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(DocumentField(controller: controller)));

      final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(decorator.isEmpty, isTrue);
    });

    testWidgets('isEmpty is false when document has text content', (tester) async {
      final controller = _makeController(text: 'Hello');
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(DocumentField(controller: controller)));

      final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(decorator.isEmpty, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // enabled / disabled state
  // -------------------------------------------------------------------------

  group('DocumentField — enabled', () {
    testWidgets('enabled:false sets InputDecorator to disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(const DocumentField(enabled: false)),
      );

      final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(decorator.decoration.enabled, isFalse);
    });

    testWidgets('enabled:false sets readOnly on EditableDocument', (tester) async {
      await tester.pumpWidget(
        _wrap(const DocumentField(enabled: false)),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.readOnly, isTrue);
    });

    testWidgets('enabled:true keeps EditableDocument writable', (tester) async {
      await tester.pumpWidget(
        _wrap(const DocumentField()),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.readOnly, isFalse);
    });

    testWidgets('readOnly:true is passed to EditableDocument even when enabled', (tester) async {
      await tester.pumpWidget(
        _wrap(const DocumentField(readOnly: true)),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.readOnly, isTrue);
    });

    testWidgets('enabled:false prevents gaining focus when tapped', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(focusNode: focusNode, enabled: false)),
      );

      await tester.tap(find.byType(DocumentField), warnIfMissed: false);
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // maxLength counter
  // -------------------------------------------------------------------------

  group('DocumentField — maxLength counter', () {
    testWidgets('counter is not shown when maxLength is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      // The counter widget should not be present.
      expect(find.text('5'), findsNothing);
    });

    testWidgets('counter shows current/maxLength when maxLength is set', (tester) async {
      final controller = _makeController(text: 'Hello');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller, maxLength: 100)),
      );

      // Counter should display "5 / 100".
      expect(find.text('5 / 100'), findsOneWidget);
    });

    testWidgets('counter counts all text characters across multiple nodes', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hi')),
        ParagraphNode(id: 'p2', text: AttributedText('World')),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller, maxLength: 50)),
      );

      // 'Hi' (2) + 'World' (5) = 7 characters.
      expect(find.text('7 / 50'), findsOneWidget);
    });

    testWidgets('counter shows 0 for empty document', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('')),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller, maxLength: 100)),
      );

      expect(find.text('0 / 100'), findsOneWidget);
    });

    testWidgets('counter shows 0 for empty document with no nodes', (tester) async {
      final doc = MutableDocument([]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller, maxLength: 100)),
      );

      expect(find.text('0 / 100'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Parameter delegation to EditableDocument
  // -------------------------------------------------------------------------

  group('DocumentField — parameter delegation', () {
    testWidgets('blockSpacing is passed to EditableDocument', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller, blockSpacing: 24.0)),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.blockSpacing, 24.0);
    });

    testWidgets('textAlign is passed to EditableDocument', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentField(
            controller: controller,
            textAlign: TextAlign.center,
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.textAlign, TextAlign.center);
    });

    testWidgets('componentBuilders are passed to EditableDocument', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      final builders = [const ParagraphComponentBuilder()];

      await tester.pumpWidget(
        _wrap(
          DocumentField(
            controller: controller,
            componentBuilders: builders,
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.componentBuilders, same(builders));
    });

    testWidgets('stylesheet is passed to EditableDocument', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      final sheet = {'body': const TextStyle(fontSize: 14)};

      await tester.pumpWidget(
        _wrap(
          DocumentField(
            controller: controller,
            stylesheet: sheet,
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.stylesheet, same(sheet));
    });

    testWidgets('onSelectionChanged callback fires when selection changes', (tester) async {
      final controller = _makeController(text: 'Hello');
      addTearDown(controller.dispose);

      final selectionEvents = <DocumentSelection?>[];

      await tester.pumpWidget(
        _wrap(
          DocumentField(
            controller: controller,
            onSelectionChanged: selectionEvents.add,
          ),
        ),
      );

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
          ),
        ),
      );
      await tester.pump();

      expect(selectionEvents, hasLength(1));
      expect(selectionEvents.first, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Controller ownership
  // -------------------------------------------------------------------------

  group('DocumentField — controller ownership', () {
    testWidgets('creates internal controller when none provided', (tester) async {
      await tester.pumpWidget(_wrap(const DocumentField()));

      // Should not throw — internal controller is created.
      expect(find.byType(EditableDocument), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses provided controller', (tester) async {
      final controller = _makeController(text: 'Custom text');
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(DocumentField(controller: controller)));

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.controller, same(controller));
    });
  });

  // -------------------------------------------------------------------------
  // debugFillProperties
  // -------------------------------------------------------------------------

  group('DocumentField — debugFillProperties', () {
    testWidgets('does not throw during diagnostics collection', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Test'),
            maxLength: 200,
            enabled: true,
            readOnly: false,
            blockSpacing: 16.0,
          ),
        ),
      );

      final element = tester.element(find.byType(DocumentField));
      final diagnostics = element.toDiagnosticsNode().toStringDeep();
      expect(diagnostics, isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
