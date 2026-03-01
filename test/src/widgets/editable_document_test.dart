/// Tests for [EditableDocument] — Phase 5.3.
///
/// Covers widget construction, focus/blur lifecycle, IME connection management,
/// readOnly mode, autofocus, keyboard routing, selection callbacks, and
/// pass-through of componentBuilders and blockSpacing.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Installs a no-op mock on [SystemChannels.textInput] that records calls.
void _installTextInputMock(WidgetTester tester, List<MethodCall> log) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.textInput,
    (MethodCall call) async {
      log.add(call);
      return null;
    },
  );
}

/// Builds a minimal [DocumentEditingController] with an optional paragraph.
DocumentEditingController _makeController({String text = 'Hello'}) {
  final doc = MutableDocument([
    ParagraphNode(id: 'p1', text: AttributedText(text)),
  ]);
  return DocumentEditingController(document: doc);
}

/// Wraps [child] in [MaterialApp] + [Scaffold] for full widget environment.
Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Construction / rendering
  // -------------------------------------------------------------------------

  group('EditableDocument — construction', () {
    testWidgets('builds without error with a paragraph node', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      expect(find.byType(EditableDocument), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds without error with an empty document', (tester) async {
      final doc = MutableDocument([]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('accepts all five default node types without error', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Paragraph')),
        ListItemNode(id: 'li1', text: AttributedText('Item')),
        ImageNode(id: 'img1', imageUrl: 'https://example.com/img.png'),
        CodeBlockNode(id: 'cb1', text: AttributedText('void main() {}')),
        HorizontalRuleNode(id: 'hr1'),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('default parameters are applied', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      final widget = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(widget.readOnly, isFalse);
      expect(widget.autofocus, isFalse);
      expect(widget.textAlign, TextAlign.start);
      expect(widget.blockSpacing, 12.0);
      expect(widget.textInputAction, TextInputAction.newline);
      expect(widget.keyboardType, TextInputType.multiline);
      expect(widget.componentBuilders, isNull); // null means use defaultComponentBuilders
    });
  });

  // -------------------------------------------------------------------------
  // Focus / IME lifecycle
  // -------------------------------------------------------------------------

  group('EditableDocument — focus and IME lifecycle', () {
    testWidgets('gaining focus opens IME connection (setClient called)', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      expect(log.map((c) => c.method), contains('TextInput.setClient'));
    });

    testWidgets('IME connection uses enableDeltaModel: true', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final setClient = log.firstWhere(
        (c) => c.method == 'TextInput.setClient',
        orElse: () => throw StateError('TextInput.setClient not called'),
      );
      final configMap = (setClient.arguments as List<dynamic>)[1] as Map<dynamic, dynamic>;
      expect(configMap['enableDeltaModel'], isTrue);
    });

    testWidgets('losing focus closes IME connection (clearClient called)', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNode = FocusNode();
      final otherFocus = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(otherFocus.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              EditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
              Focus(focusNode: otherFocus, child: const SizedBox(height: 50)),
            ],
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      log.clear();

      otherFocus.requestFocus();
      await tester.pump();

      expect(log.map((c) => c.method), contains('TextInput.clearClient'));
    });

    testWidgets('readOnly blocks IME connection on focus', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            readOnly: true,
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      expect(log.map((c) => c.method), isNot(contains('TextInput.setClient')));
    });

    testWidgets('autofocus gains focus without explicit requestFocus', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
          ),
        ),
      );

      // pumpAndSettle waits for the autofocus to take effect.
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Keyboard handling
  // -------------------------------------------------------------------------

  group('EditableDocument — keyboard handling', () {
    testWidgets('Escape collapses expanded selection when focused', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Set an expanded selection spanning characters 0-5.
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

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Send Escape key.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Selection should be collapsed after Escape.
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
    });

    testWidgets('arrow key moves selection when focused', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 3),
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      // Caret should have moved left from offset 3 to offset 2.
      expect(controller.selection, isNotNull);
      final pos = controller.selection!.extent.nodePosition as TextNodePosition;
      expect(pos.offset, 2);
    });

    testWidgets('keyboard events are ignored in readOnly mode', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

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

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            readOnly: true,
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Escape in readOnly should NOT collapse selection.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Selection should remain expanded (readOnly ignores keyboard handler).
      expect(controller.selection!.isCollapsed, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Selection callback
  // -------------------------------------------------------------------------

  group('EditableDocument — onSelectionChanged callback', () {
    testWidgets('fires when controller selection changes', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final selectionEvents = <DocumentSelection?>[];

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
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

    testWidgets('fires with null when selection is cleared', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Start with a selection.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 1),
          ),
        ),
      );

      final selectionEvents = <DocumentSelection?>[];

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            onSelectionChanged: selectionEvents.add,
          ),
        ),
      );

      controller.clearSelection();
      await tester.pump();

      expect(selectionEvents, hasLength(1));
      expect(selectionEvents.first, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // componentBuilders and blockSpacing pass-through
  // -------------------------------------------------------------------------

  group('EditableDocument — componentBuilders and blockSpacing', () {
    testWidgets('custom componentBuilders are passed to DocumentLayout', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final customBuilders = [
        const ParagraphComponentBuilder(),
      ];

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            componentBuilders: customBuilders,
          ),
        ),
      );

      final widget = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(widget.componentBuilders, same(customBuilders));
      expect(tester.takeException(), isNull);
    });

    testWidgets('blockSpacing is stored on the widget', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            blockSpacing: 24.0,
          ),
        ),
      );

      final widget = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(widget.blockSpacing, 24.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stylesheet is stored on the widget', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final sheet = {'body': const TextStyle(fontSize: 14)};

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            stylesheet: sheet,
          ),
        ),
      );

      final widget = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(widget.stylesheet, same(sheet));
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Editor integration
  // -------------------------------------------------------------------------

  group('EditableDocument — editor integration', () {
    testWidgets('editor parameter is accepted without error', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final context = EditContext(document: doc, controller: controller);
      final editor = Editor(editContext: context);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);
      addTearDown(editor.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            editor: editor,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // DocumentLayout is present in widget tree
  // -------------------------------------------------------------------------

  group('EditableDocument — widget tree', () {
    testWidgets('contains a DocumentLayout child', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      expect(find.byType(DocumentLayout), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Page Up / Page Down
  // -------------------------------------------------------------------------

  group('EditableDocument — Page Up/Down', () {
    testWidgets('Page Down moves selection to a later paragraph', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      // 20 paragraphs — enough to overflow a 200 px viewport.
      final nodes = List.generate(
        20,
        (i) => ParagraphNode(id: 'p$i', text: AttributedText('Line $i')),
      );
      final doc = MutableDocument(nodes);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Set selection at the very beginning of the document.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p0',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 200,
            child: SingleChildScrollView(
              child: EditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Send Page Down — the resolver should move selection one viewport height
      // down, landing in a later paragraph.
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();

      // The selection must have moved: extent should no longer be in 'p0'.
      expect(controller.selection, isNotNull);
      expect(
        controller.selection!.extent.nodeId,
        isNot('p0'),
        reason: 'Page Down should move selection out of the first paragraph',
      );
    });

    testWidgets('Page Up moves selection back toward start after Page Down', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final nodes = List.generate(
        20,
        (i) => ParagraphNode(id: 'p$i', text: AttributedText('Line $i')),
      );
      final doc = MutableDocument(nodes);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Start at paragraph 0.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p0',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 200,
            child: SingleChildScrollView(
              child: EditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Page Down to move selection forward.
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();

      final afterPageDown = controller.selection!.extent.nodeId;
      expect(afterPageDown, isNot('p0'));

      // Page Up should move back up — ending up earlier in the document than
      // where Page Down landed (ideally back at p0, but clamping is acceptable).
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();

      expect(controller.selection, isNotNull);
      // The node index after Page Up should be <= the node index after Page Down.
      final afterPageDownIndex = int.parse(afterPageDown.substring(1));
      final afterPageUpId = controller.selection!.extent.nodeId;
      final afterPageUpIndex = int.parse(afterPageUpId.substring(1));
      expect(
        afterPageUpIndex,
        lessThanOrEqualTo(afterPageDownIndex),
        reason: 'Page Up should move selection toward the start of the document',
      );
    });

    testWidgets('Page Down does nothing without a selection', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final nodes = List.generate(
        5,
        (i) => ParagraphNode(id: 'p$i', text: AttributedText('Line $i')),
      );
      final doc = MutableDocument(nodes);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // No selection set.
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 200,
            child: SingleChildScrollView(
              child: EditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();

      // Selection was null before and should remain null.
      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Auto-scroll to caret
  // -------------------------------------------------------------------------

  group('EditableDocument — auto-scroll to caret', () {
    testWidgets('scrolls to caret when selection changes beyond viewport', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      // Create a document with many paragraphs to overflow a small viewport.
      final nodes = List.generate(
        20,
        (i) => ParagraphNode(id: 'p$i', text: AttributedText('Line $i')),
      );
      final doc = MutableDocument(nodes);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      final scrollController = ScrollController();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 100,
            child: SingleChildScrollView(
              controller: scrollController,
              child: EditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );

      // Initially scroll should be at 0.
      expect(scrollController.offset, 0.0);

      // Set selection to the last paragraph.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p19',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      // Pump to trigger post-frame callback, then settle for animation.
      await tester.pumpAndSettle();

      // The viewport should have scrolled down.
      expect(scrollController.offset, greaterThan(0));
    });

    testWidgets('scrollPadding defaults to EdgeInsets.all(20.0)', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      final widget = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(widget.scrollPadding, const EdgeInsets.all(20.0));
    });

    testWidgets('custom scrollPadding is stored on the widget', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      const customPadding = EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            scrollPadding: customPadding,
          ),
        ),
      );

      final widget = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(widget.scrollPadding, customPadding);
    });
  });
}
