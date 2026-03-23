/// Tests for [EditableDocument] — Phase 5.3.
///
/// Covers widget construction, focus/blur lifecycle, IME connection management,
/// readOnly mode, autofocus, keyboard routing, selection callbacks, and
/// pass-through of componentBuilders and blockSpacing.
library;

import 'package:flutter/foundation.dart';
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
          SingleChildScrollView(
            child: EditableDocument(
              controller: controller,
              focusNode: focusNode,
            ),
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

  // -------------------------------------------------------------------------
  // Visual-line Up/Down navigation
  // -------------------------------------------------------------------------

  group('visual-line Up/Down navigation', () {
    // Long text that wraps at 200 px. Repeated enough to guarantee at least
    // two visual lines within a single paragraph block.
    const wrappingText = 'The quick brown fox jumps over the lazy dog. '
        'The quick brown fox jumps over the lazy dog. '
        'The quick brown fox jumps over the lazy dog. ';

    /// Builds an [EditableDocument] inside a 200-px-wide container.
    Widget _buildNarrow(DocumentEditingController controller, FocusNode focusNode) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: EditableDocument(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      );
    }

    // -----------------------------------------------------------------------
    // Test 1: Down stays within the same block on a wrapped paragraph.
    //
    // Document: [longParagraph p1, shortParagraph p2]
    // Caret: offset 0 of p1 (first visual line of a multi-line paragraph).
    // Without visual-line resolver, Down jumps to p2 (block-level fallback).
    // With visual-line resolver, Down moves within p1 to the second visual
    // line (p1 extent, offset > 0 and nodeId == 'p1').
    // -----------------------------------------------------------------------
    testWidgets('Down arrow moves within wrapped lines of same block', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText(wrappingText)),
        ParagraphNode(id: 'p2', text: AttributedText('Second paragraph')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Place caret at offset 0 (first visual line of multi-line p1).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      await tester.pumpWidget(_buildNarrow(controller, focusNode));
      await tester.pump();

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // With visual-line resolver: caret stays in p1 (not p2).
      // Without resolver (block-jump): caret would move to p2.
      expect(controller.selection, isNotNull);
      final sel = controller.selection!;
      expect(
        sel.extent.nodeId,
        'p1',
        reason: 'Down from first visual line of a wrapped block should stay in the same block',
      );
      final offset = (sel.extent.nodePosition as TextNodePosition).offset;
      expect(offset, greaterThan(0), reason: 'Caret must have moved to the second visual line');
    });

    // -----------------------------------------------------------------------
    // Test 2: Up stays within the same block on a wrapped paragraph.
    //
    // Document: [shortParagraph p1, longParagraph p2]
    // Caret: end of p2 (last visual line of multi-line paragraph).
    // Without resolver, Up jumps to p1 (block-level fallback).
    // With resolver, Up moves within p2 to the second-to-last visual line.
    // -----------------------------------------------------------------------
    testWidgets('Up arrow moves within wrapped lines of same block', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('First paragraph')),
        ParagraphNode(id: 'p2', text: AttributedText(wrappingText)),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Place caret at end of p2 (last visual line of multi-line paragraph).
      final endOffset = wrappingText.length;
      controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p2',
            nodePosition: TextNodePosition(offset: endOffset),
          ),
        ),
      );

      await tester.pumpWidget(_buildNarrow(controller, focusNode));
      await tester.pump();

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      // With visual-line resolver: caret stays in p2 (not p1).
      // Without resolver (block-jump): caret would move to p1.
      expect(controller.selection, isNotNull);
      final sel = controller.selection!;
      expect(
        sel.extent.nodeId,
        'p2',
        reason: 'Up from last visual line of a wrapped block should stay in the same block',
      );
      final offset = (sel.extent.nodePosition as TextNodePosition).offset;
      expect(
        offset,
        lessThan(endOffset),
        reason: 'Caret must have moved up from the last visual line',
      );
    });

    // -----------------------------------------------------------------------
    // Test 3: Down crosses block boundary from the last visual line.
    //
    // Two short paragraphs (one visual line each).
    // Caret at start of p1. Down should move into p2.
    // Both resolver and block-jump agree here, so this is a smoke test.
    // -----------------------------------------------------------------------
    testWidgets('Down arrow crosses block boundary from last visual line', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('First')),
        ParagraphNode(id: 'p2', text: AttributedText('Second')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      await tester.pumpWidget(_buildNarrow(controller, focusNode));
      await tester.pump();

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(
        controller.selection!.extent.nodeId,
        'p2',
        reason: 'Down from the only visual line of p1 should move into p2',
      );
    });

    // -----------------------------------------------------------------------
    // Test 4: Up crosses block boundary from the first visual line.
    //
    // Two short paragraphs (one visual line each).
    // Caret at start of p2. Up should move into p1.
    // -----------------------------------------------------------------------
    testWidgets('Up arrow crosses block boundary from first visual line', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('First')),
        ParagraphNode(id: 'p2', text: AttributedText('Second')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p2',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      await tester.pumpWidget(_buildNarrow(controller, focusNode));
      await tester.pump();

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(
        controller.selection!.extent.nodeId,
        'p1',
        reason: 'Up from the only visual line of p2 should move into p1',
      );
    });

    // -----------------------------------------------------------------------
    // Test 5: Down at document bottom keeps caret in place.
    //
    // Single paragraph, caret at end. Down should not change selection.
    // Both resolver (returns null → stays) and block-jump (_endOfNode → same
    // position) agree here.
    // -----------------------------------------------------------------------
    testWidgets('Down at document bottom keeps caret in place', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Only line')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      const endOffset = 9; // 'Only line'.length
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: endOffset),
          ),
        ),
      );

      await tester.pumpWidget(_buildNarrow(controller, focusNode));
      await tester.pump();

      focusNode.requestFocus();
      await tester.pump();

      final selectionBefore = controller.selection;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(controller.selection, equals(selectionBefore));
    });

    // -----------------------------------------------------------------------
    // Test 6: Up at document top keeps caret in place.
    //
    // Single paragraph, caret at offset 0. Up should not change selection.
    // -----------------------------------------------------------------------
    testWidgets('Up at document top keeps caret in place', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Only line')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      await tester.pumpWidget(_buildNarrow(controller, focusNode));
      await tester.pump();

      focusNode.requestFocus();
      await tester.pump();

      final selectionBefore = controller.selection;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(controller.selection, equals(selectionBefore));
    });

    // -----------------------------------------------------------------------
    // Test 7: Down from code block end crosses into next node.
    //
    // Document: [CodeBlockNode 'c1' with short text, ParagraphNode 'p1']
    // Caret: end of c1 text. The half-line overshoot can land inside the code
    // block's bottom padding, resolving back to c1. The fallback probe past
    // the node boundary must push the caret into p1.
    // -----------------------------------------------------------------------
    testWidgets('Down from code block end crosses into next node', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        CodeBlockNode(id: 'c1', text: AttributedText('print("hello");')),
        ParagraphNode(id: 'p1', text: AttributedText('After code')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      const endOffset = 15; // 'print("hello");'.length
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'c1',
            nodePosition: TextNodePosition(offset: endOffset),
          ),
        ),
      );

      await tester.pumpWidget(_buildNarrow(controller, focusNode));
      await tester.pump();

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(
        controller.selection!.extent.nodeId,
        'p1',
        reason: 'Down from code block end should cross into the next node',
      );
    });

    // -----------------------------------------------------------------------
    // Test 8: Down from image does not skip blocks.
    //
    // Document: [ImageNode 'img1' (200px tall), ParagraphNode 'p1']
    // Caret: upstream on img1. Without the clamp, halfLine would be ~100px,
    // causing the probe to overshoot far past p1. With the clamp (24px),
    // the caret moves directly into p1.
    // -----------------------------------------------------------------------
    testWidgets('Down from image does not skip blocks', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ImageNode(id: 'img1', imageUrl: 'test.png', height: const BlockDimension.pixels(200)),
        ParagraphNode(id: 'p1', text: AttributedText('After image')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'img1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        ),
      );

      await tester.pumpWidget(_buildNarrow(controller, focusNode));
      await tester.pump();

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(
        controller.selection!.extent.nodeId,
        'p1',
        reason: 'Down from image should land in the immediately next block, not skip',
      );
    });

    // -----------------------------------------------------------------------
    // Test 9: Up from paragraph after image moves into image.
    //
    // Document: [ImageNode 'img1' (200px tall), ParagraphNode 'p1']
    // Caret: start of p1. Up should move into img1.
    // -----------------------------------------------------------------------
    testWidgets('Up from paragraph after image moves into image', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ImageNode(id: 'img1', imageUrl: 'test.png', height: const BlockDimension.pixels(200)),
        ParagraphNode(id: 'p1', text: AttributedText('After image')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      await tester.pumpWidget(_buildNarrow(controller, focusNode));
      await tester.pump();

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(
        controller.selection!.extent.nodeId,
        'img1',
        reason: 'Up from paragraph after image should move into the image',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Line-move resolver (Cmd+Left/Right — visual line boundary)
  // -------------------------------------------------------------------------

  group('line-move resolver (Cmd+Left/Right)', () {
    // Long text that wraps at 200 px. Repeated enough to guarantee at least
    // two visual lines within a single paragraph block.
    const wrappingText = 'The quick brown fox jumps over the lazy dog. '
        'The quick brown fox jumps over the lazy dog. '
        'The quick brown fox jumps over the lazy dog. ';

    /// Builds an [EditableDocument] inside a 200-px-wide container on macOS.
    Widget _buildNarrow(DocumentEditingController controller, FocusNode focusNode) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: EditableDocument(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      );
    }

    // -----------------------------------------------------------------------
    // Test 1: Cmd+Left moves to visual line start (not node start).
    //
    // Document: [long paragraph p1 that wraps]
    // Caret: some offset in the middle of the second visual line.
    // Cmd+Left should move to the START of the second visual line (not
    // offset 0, which would be the node start).
    // -----------------------------------------------------------------------
    testWidgets('Cmd+Left moves to visual line start, not node start', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText(wrappingText)),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();

      // Place the caret in the middle of the second visual line.
      // wrappingText is 135 characters; at 200 px width, the first line
      // wraps somewhere around offset 25-35. Placing at offset 50 ensures
      // we are on the second visual line.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 50),
          ),
        ),
      );

      await tester.pumpWidget(_buildNarrow(controller, focusNode));
      await tester.pump();

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(controller.selection, isNotNull);
      final offset = (controller.selection!.extent.nodePosition as TextNodePosition).offset;

      // The visual line boundary resolver should move to the start of the
      // current visual line — which is NOT offset 0 (node start) since
      // we started on a wrapped second line.
      expect(
        offset,
        greaterThan(0),
        reason: 'Cmd+Left from the middle of the second visual line should '
            'move to the START of that line, not to node start (offset 0)',
      );

      controller.dispose();
      focusNode.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    // -----------------------------------------------------------------------
    // Test 2: Cmd+Right moves to visual line end (not node end).
    //
    // Document: [long paragraph p1 that wraps]
    // Caret: at offset 0 (start of the first visual line).
    // Cmd+Right should move to the END of the first visual line (not to
    // wrappingText.length, which would be the node end).
    // -----------------------------------------------------------------------
    testWidgets('Cmd+Right moves to visual line end, not node end', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText(wrappingText)),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();

      // Place the caret at the very start of the node (first visual line).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      await tester.pumpWidget(_buildNarrow(controller, focusNode));
      await tester.pump();

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(controller.selection, isNotNull);
      final pos = controller.selection!.extent.nodePosition as TextNodePosition;

      // The visual line boundary resolver should move to the end of the
      // first visual line — which is NOT wrappingText.length (node end)
      // since the text wraps at 200 px.
      expect(
        pos.offset,
        lessThan(wrappingText.length),
        reason: 'Cmd+Right from start of first visual line should move to '
            'the END of that line, not to node end (offset ${wrappingText.length})',
      );
      expect(
        pos.offset,
        greaterThan(0),
        reason: 'Cmd+Right must move forward from offset 0',
      );
      // At a soft wrap, upstream affinity places the caret at the trailing
      // edge of the current line rather than the leading edge of the next.
      expect(
        pos.affinity,
        TextAffinity.upstream,
        reason: 'Cmd+Right should use upstream affinity so the caret '
            'renders at the end of the current visual line',
      );

      controller.dispose();
      focusNode.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // -------------------------------------------------------------------------
  // Clipboard operations (Cmd/Ctrl+C/X/V/A)
  // -------------------------------------------------------------------------

  group('EditableDocument — clipboard operations', () {
    // -----------------------------------------------------------------------
    // Clipboard mock (re-uses the same pattern as document_clipboard_test.dart)
    // -----------------------------------------------------------------------

    String? _clipboardData;

    void installClipboardMock(WidgetTester tester) {
      _clipboardData = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            _clipboardData = (call.arguments as Map<String, dynamic>)['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            if (_clipboardData == null) return null;
            return <String, dynamic>{'text': _clipboardData};
          }
          return null;
        },
      );
    }

    void removeClipboardMock(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      _clipboardData = null;
    }

    // -----------------------------------------------------------------------
    // Helper: build a focused EditableDocument with an Editor so that
    // DeleteContentRequest and InsertTextRequest are actually executed.
    // -----------------------------------------------------------------------
    Future<({DocumentEditingController controller, FocusNode focusNode})> _buildFocused(
      WidgetTester tester, {
      String text = 'Hello world',
      bool readOnly = false,
    }) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText(text)),
      ]);
      final controller = DocumentEditingController(document: doc);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              editor: editor,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      return (controller: controller, focusNode: focusNode);
    }

    // -----------------------------------------------------------------------
    // Test 1: Cmd+C copies selected text to clipboard (macOS)
    // -----------------------------------------------------------------------
    testWidgets('Cmd+C copies selected text to clipboard', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      installClipboardMock(tester);

      final (:controller, :focusNode) = await _buildFocused(tester, text: 'Hello world');
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Select 'Hello' (offset 0..5)
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(_clipboardData, equals('Hello'));

      removeClipboardMock(tester);
      debugDefaultTargetPlatformOverride = null;
    });

    // -----------------------------------------------------------------------
    // Test 2: Cmd+X cuts text in editable mode (macOS)
    // -----------------------------------------------------------------------
    testWidgets('Cmd+X cuts text in editable mode', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      installClipboardMock(tester);

      final (:controller, :focusNode) = await _buildFocused(tester, text: 'Hello world');
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Select 'Hello' (offset 0..5)
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      // Settle for the async cut operation.
      await tester.pumpAndSettle();

      expect(_clipboardData, equals('Hello'));

      removeClipboardMock(tester);
      debugDefaultTargetPlatformOverride = null;
    });

    // -----------------------------------------------------------------------
    // Test 3: Cmd+V pastes text at caret (macOS)
    // -----------------------------------------------------------------------
    testWidgets('Cmd+V pastes text at caret', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      installClipboardMock(tester);

      final (:controller, :focusNode) = await _buildFocused(tester, text: 'world');
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Pre-fill clipboard after building the widget.
      _clipboardData = 'pasted';

      // Collapsed caret at offset 0.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, equals('pastedworld'));

      removeClipboardMock(tester);
      debugDefaultTargetPlatformOverride = null;
    });

    // -----------------------------------------------------------------------
    // Test 4: Cmd+A selects all content (macOS)
    // -----------------------------------------------------------------------
    testWidgets('Cmd+A selects all content', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('First')),
        ParagraphNode(id: 'p2', text: AttributedText('Second')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(controller: controller, focusNode: focusNode),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Set any non-null starting selection.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isFalse);
      expect(controller.selection!.base.nodeId, 'p1');
      expect(controller.selection!.extent.nodeId, 'p2');
      expect(
        (controller.selection!.base.nodePosition as TextNodePosition).offset,
        0,
      );
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        6, // 'Second'.length
      );

      debugDefaultTargetPlatformOverride = null;
    });

    // -----------------------------------------------------------------------
    // Test 5: Cmd+X is no-op in readOnly mode (macOS)
    // -----------------------------------------------------------------------
    testWidgets('Cmd+X is no-op in readOnly mode', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      installClipboardMock(tester);

      final (:controller, :focusNode) =
          await _buildFocused(tester, text: 'Hello world', readOnly: true);
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      // Clipboard should remain empty — readOnly blocks the cut.
      expect(_clipboardData, isNull);
      // Document text should be unchanged.
      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, equals('Hello world'));

      removeClipboardMock(tester);
      debugDefaultTargetPlatformOverride = null;
    });

    // -----------------------------------------------------------------------
    // Test 6: Cmd+V is no-op in readOnly mode (macOS)
    // -----------------------------------------------------------------------
    testWidgets('Cmd+V is no-op in readOnly mode', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      installClipboardMock(tester);

      _clipboardData = 'pasted';

      final (:controller, :focusNode) =
          await _buildFocused(tester, text: 'Hello world', readOnly: true);
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      // Document should be unchanged — readOnly blocks the paste.
      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, equals('Hello world'));

      removeClipboardMock(tester);
      debugDefaultTargetPlatformOverride = null;
    });

    // -----------------------------------------------------------------------
    // Test 7: Ctrl+C copies on Linux
    // -----------------------------------------------------------------------
    testWidgets('Ctrl+C works on Linux', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      installClipboardMock(tester);

      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello world')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(controller: controller, focusNode: focusNode),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Select 'Hello' (offset 0..5)
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(_clipboardData, equals('Hello'));

      removeClipboardMock(tester);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // -------------------------------------------------------------------------
  // Autofill support
  // -------------------------------------------------------------------------

  group('EditableDocument — autofill', () {
    testWidgets('IME connection includes autofill config when hints set on controller',
        (tester) async {
      final imeLog = <MethodCall>[];
      _installTextInputMock(tester, imeLog);

      final controller = _makeController();
      // Set hints directly on the controller — no widget parameter.
      controller.autofillHints = ['email'];
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          AutofillGroup(
            child: EditableDocument(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      );

      // Focus to trigger IME connection.
      focusNode.requestFocus();
      await tester.pump();

      final setClient = imeLog.firstWhere(
        (c) => c.method == 'TextInput.setClient',
        orElse: () => throw StateError('TextInput.setClient not called'),
      );
      final configMap = (setClient.arguments as List<dynamic>)[1] as Map<dynamic, dynamic>;
      // When autofill hints are set on the controller and the widget is inside
      // an AutofillGroup, the IME config should contain autofill info.
      expect(configMap.containsKey('autofill'), isTrue);
    });

    testWidgets('IME connection has no autofill config when hints are null', (tester) async {
      final imeLog = <MethodCall>[];
      _installTextInputMock(tester, imeLog);

      final controller = _makeController();
      // No hints set — controller.autofillHints defaults to null.
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

      final setClient = imeLog.firstWhere(
        (c) => c.method == 'TextInput.setClient',
        orElse: () => throw StateError('TextInput.setClient not called'),
      );
      final configMap = (setClient.arguments as List<dynamic>)[1] as Map<dynamic, dynamic>;
      // No autofill configuration when hints are null — the key should be
      // absent or null.
      expect(configMap['autofill'], isNull);
    });
  });

  // -------------------------------------------------------------------------
  // documentPadding / line-number pass-through to DocumentLayout
  // -------------------------------------------------------------------------

  group('EditableDocument — documentPadding and line-number pass-through', () {
    testWidgets('default documentPadding is EdgeInsets.zero', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final widget = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(widget.documentPadding, EdgeInsets.zero);
    });

    testWidgets('default showLineNumbers is false', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final widget = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(widget.showLineNumbers, isFalse);
    });

    testWidgets('default lineNumberWidth is 0.0', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final widget = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(widget.lineNumberWidth, 0.0);
    });

    testWidgets('default lineNumberTextStyle is null', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final widget = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(widget.lineNumberTextStyle, isNull);
    });

    testWidgets('default lineNumberBackgroundColor is null', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final widget = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(widget.lineNumberBackgroundColor, isNull);
    });

    testWidgets('documentPadding is forwarded through to RenderDocumentLayout', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      final layoutKey = GlobalKey<DocumentLayoutState>();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);
      const padding = EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            layoutKey: layoutKey,
            documentPadding: padding,
          ),
        ),
      );

      final ro = layoutKey.currentState!.renderObject!;
      expect(ro.documentPadding, padding);
    });

    testWidgets('showLineNumbers is forwarded through to RenderDocumentLayout', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      final layoutKey = GlobalKey<DocumentLayoutState>();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            layoutKey: layoutKey,
            showLineNumbers: true,
          ),
        ),
      );

      final ro = layoutKey.currentState!.renderObject!;
      expect(ro.showLineNumbers, isTrue);
    });

    testWidgets('lineNumberWidth is forwarded through to RenderDocumentLayout', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      final layoutKey = GlobalKey<DocumentLayoutState>();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            layoutKey: layoutKey,
            showLineNumbers: true,
            lineNumberWidth: 52.0,
          ),
        ),
      );

      final ro = layoutKey.currentState!.renderObject!;
      expect(ro.lineNumberWidth, 52.0);
    });

    testWidgets('lineNumberTextStyle is forwarded through to RenderDocumentLayout', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      final layoutKey = GlobalKey<DocumentLayoutState>();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);
      const style = TextStyle(fontSize: 11, color: Color(0xFF777777));

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            layoutKey: layoutKey,
            showLineNumbers: true,
            lineNumberTextStyle: style,
          ),
        ),
      );

      final ro = layoutKey.currentState!.renderObject!;
      expect(ro.lineNumberTextStyle, style);
    });

    testWidgets('lineNumberBackgroundColor is forwarded through to RenderDocumentLayout',
        (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      final layoutKey = GlobalKey<DocumentLayoutState>();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);
      const color = Color(0xFFF5F5F5);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            layoutKey: layoutKey,
            showLineNumbers: true,
            lineNumberBackgroundColor: color,
          ),
        ),
      );

      final ro = layoutKey.currentState!.renderObject!;
      expect(ro.lineNumberBackgroundColor, color);
    });

    testWidgets('all five properties reach RenderDocumentLayout together', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      final layoutKey = GlobalKey<DocumentLayoutState>();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);
      const padding = EdgeInsets.all(20.0);
      const style = TextStyle(fontSize: 12);
      const color = Color(0xFFEEEEEE);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            layoutKey: layoutKey,
            documentPadding: padding,
            showLineNumbers: true,
            lineNumberWidth: 44.0,
            lineNumberTextStyle: style,
            lineNumberBackgroundColor: color,
          ),
        ),
      );

      final ro = layoutKey.currentState!.renderObject!;
      expect(ro.documentPadding, padding);
      expect(ro.showLineNumbers, isTrue);
      expect(ro.lineNumberWidth, 44.0);
      expect(ro.lineNumberTextStyle, style);
      expect(ro.lineNumberBackgroundColor, color);
    });

    testWidgets('default lineNumberAlignment is LineNumberAlignment.top', (tester) async {
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
      expect(widget.lineNumberAlignment, LineNumberAlignment.top);
    });

    testWidgets('lineNumberAlignment is forwarded through to RenderDocumentLayout', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      final layoutKey = GlobalKey<DocumentLayoutState>();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            layoutKey: layoutKey,
            showLineNumbers: true,
            lineNumberAlignment: LineNumberAlignment.bottom,
          ),
        ),
      );

      final ro = layoutKey.currentState!.renderObject!;
      expect(ro.lineNumberAlignment, LineNumberAlignment.bottom);
    });
  });

  // -------------------------------------------------------------------------
  // didUpdateWidget — controller swap
  // -------------------------------------------------------------------------

  group('EditableDocument — didUpdateWidget controller swap', () {
    testWidgets('swapping controller does not crash', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controllerA = _makeController(text: 'Controller A');
      final controllerB = _makeController(text: 'Controller B');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controllerA.dispose);
      addTearDown(controllerB.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controllerA,
            focusNode: focusNode,
          ),
        ),
      );

      // Rebuild with a different controller instance.
      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controllerB,
            focusNode: focusNode,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('onSelectionChanged fires from new controller after swap', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controllerA = _makeController(text: 'Controller A');
      final controllerB = _makeController(text: 'Controller B');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controllerA.dispose);
      addTearDown(controllerB.dispose);

      final events = <DocumentSelection?>[];

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controllerA,
            focusNode: focusNode,
            onSelectionChanged: events.add,
          ),
        ),
      );

      // Rebuild with controllerB.
      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controllerB,
            focusNode: focusNode,
            onSelectionChanged: events.add,
          ),
        ),
      );

      // A selection change on the OLD controller should NOT fire the callback.
      final countBefore = events.length;
      controllerA.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 1),
          ),
        ),
      );
      await tester.pump();
      expect(events.length, countBefore, reason: 'Old controller should not fire callback');

      // A selection change on the NEW controller should fire the callback.
      controllerB.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
          ),
        ),
      );
      await tester.pump();
      expect(events.length, countBefore + 1, reason: 'New controller should fire callback');
    });
  });

  // -------------------------------------------------------------------------
  // didUpdateWidget — focus node swap
  // -------------------------------------------------------------------------

  group('EditableDocument — didUpdateWidget focus node swap', () {
    testWidgets('swapping focus node does not crash', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNodeA = FocusNode();
      final focusNodeB = FocusNode();
      addTearDown(focusNodeA.dispose);
      addTearDown(focusNodeB.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNodeA,
          ),
        ),
      );

      // Rebuild with a different focus node.
      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNodeB,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('new focus node opens IME after swap', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNodeA = FocusNode();
      final focusNodeB = FocusNode();
      addTearDown(focusNodeA.dispose);
      addTearDown(focusNodeB.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNodeA,
          ),
        ),
      );

      // Swap to the new focus node.
      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNodeB,
          ),
        ),
      );

      log.clear();

      // The NEW focus node should trigger IME open.
      focusNodeB.requestFocus();
      await tester.pump();

      expect(log.map((c) => c.method), contains('TextInput.setClient'));
    });

    testWidgets('old focus node no longer triggers IME after swap', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController();
      final focusNodeA = FocusNode();
      final focusNodeB = FocusNode();
      addTearDown(focusNodeA.dispose);
      addTearDown(focusNodeB.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNodeA,
          ),
        ),
      );

      // Focus the old node while it is still connected.
      focusNodeA.requestFocus();
      await tester.pump();
      log.clear();

      // Swap to new focus node — old node loses its listener.
      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNodeB,
          ),
        ),
      );

      // focusNodeA retains focus from before the swap; losing it now should
      // not trigger IME open through the widget's _onFocusChanged.
      log.clear();
      focusNodeB.requestFocus(); // shifts focus away from A without touching widget
      await tester.pump();

      // Only the new node's focus event should appear, not a duplicate open
      // triggered by the old node.
      final setClientCount = log.where((c) => c.method == 'TextInput.setClient').length;
      expect(setClientCount, lessThanOrEqualTo(1));
    });
  });

  // -------------------------------------------------------------------------
  // collapseSelection edge cases
  // -------------------------------------------------------------------------

  group('EditableDocument — collapseSelection', () {
    testWidgets('collapseSelection is no-op when readOnly', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
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

      // Drive collapseSelection directly via the state.
      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.collapseSelection();

      // Selection must remain expanded.
      expect(controller.selection!.isCollapsed, isFalse);
    });

    testWidgets('collapseSelection is no-op when selection is already collapsed', (tester) async {
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
            nodePosition: TextNodePosition(offset: 2),
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

      final selectionBefore = controller.selection;

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.collapseSelection();

      // Selection reference should be unchanged.
      expect(controller.selection, equals(selectionBefore));
    });

    testWidgets('collapseSelection is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
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

      // No selection set — should not crash.
      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.collapseSelection();

      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // selectAll with binary nodes
  // -------------------------------------------------------------------------

  group('EditableDocument — selectAll with non-text nodes', () {
    testWidgets('selectAll spans from image to paragraph', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ImageNode(id: 'img1', imageUrl: 'test.png'),
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Set a minimal selection so selectAll has somewhere to start.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.selectAll();

      expect(controller.selection, isNotNull);
      expect(controller.selection!.base.nodeId, 'img1');
      expect(controller.selection!.extent.nodeId, 'p1');
      // First node is binary — base should be upstream.
      expect(
        controller.selection!.base.nodePosition,
        const BinaryNodePosition.upstream(),
      );
      // Last node is text — extent should be at end of text.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        5, // 'Hello'.length
      );
    });

    testWidgets('selectAll is no-op on empty document', (tester) async {
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.selectAll();

      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // moveVertically — collapse expanded selection before moving
  // -------------------------------------------------------------------------

  group('EditableDocument — moveVertically collapses before moving', () {
    testWidgets('Down collapses expanded selection to extent before moving', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('First')),
        ParagraphNode(id: 'p2', text: AttributedText('Second')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Expanded selection: base=p1:0, extent=p1:5.
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
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

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // After Down on an expanded selection, the selection should be
      // collapsed (no longer expanded).
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
    });

    testWidgets('Up collapses expanded selection to base before moving', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('First')),
        ParagraphNode(id: 'p2', text: AttributedText('Second')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Expanded selection: base=p1:0, extent=p1:5.
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
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

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      // After Up on an expanded selection, the selection should be collapsed.
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // moveByCharacter — collapse expanded selection before moving
  // -------------------------------------------------------------------------

  group('EditableDocument — moveByCharacter collapses expanded selection', () {
    testWidgets('Right on expanded selection collapses to normalised extent', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Expanded forward selection: base=0, extent=3.
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 3)),
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

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // Right on expanded selection should collapse to the extent (offset 3).
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        3,
      );
    });

    testWidgets('Left on expanded selection collapses to normalised base', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Expanded forward selection: base=0, extent=3.
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 3)),
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

      // Left on expanded selection should collapse to the base (offset 0).
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        0,
      );
    });
  });

  // -------------------------------------------------------------------------
  // autofillId getter
  // -------------------------------------------------------------------------

  group('EditableDocument — autofillId', () {
    testWidgets('autofillId is a non-empty string', (tester) async {
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      expect(state.autofillId, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // moveToDocumentStartOrEnd
  // -------------------------------------------------------------------------

  group('EditableDocument — moveToDocumentStartOrEnd', () {
    testWidgets('Cmd+Up moves to document start on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('First')),
        ParagraphNode(id: 'p2', text: AttributedText('Second')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Start at the end of the document.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p2',
            nodePosition: TextNodePosition(offset: 6),
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

      // Cmd+Up on macOS maps to ExtendSelectionToDocumentBoundaryIntent(forward:false).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(controller.selection!.extent.nodeId, 'p1');
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        0,
      );

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Cmd+Down moves to document end on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('First')),
        ParagraphNode(id: 'p2', text: AttributedText('Second')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      // Start at the beginning of the document.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
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

      // Cmd+Down on macOS maps to ExtendSelectionToDocumentBoundaryIntent(forward:true).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(controller.selection!.extent.nodeId, 'p2');
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        6, // 'Second'.length
      );

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('moveToDocumentStartOrEnd is no-op when selection is null', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
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

      // No selection.
      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveToDocumentStartOrEnd(forward: true, extend: false);

      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // moveToNodeStartOrEnd (called directly on state)
  // -------------------------------------------------------------------------

  group('EditableDocument — moveToNodeStartOrEnd', () {
    testWidgets('moveToNodeStartOrEnd(backward) moves to node start', (tester) async {
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveToNodeStartOrEnd(forward: false, extend: false);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        0,
      );
    });

    testWidgets('moveToNodeStartOrEnd(forward) moves to node end', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveToNodeStartOrEnd(forward: true, extend: false);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        5, // 'Hello'.length
      );
    });

    testWidgets('moveToNodeStartOrEnd extends selection when extend is true', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveToNodeStartOrEnd(forward: true, extend: true);

      expect(controller.selection, isNotNull);
      // Should be expanded since we extended.
      expect(controller.selection!.isExpanded, isTrue);
      expect(controller.selection!.base.nodePosition, const TextNodePosition(offset: 2));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        5, // 'Hello'.length
      );
    });

    testWidgets('moveToNodeStartOrEnd is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveToNodeStartOrEnd(forward: true, extend: false);

      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // moveByWord
  // -------------------------------------------------------------------------

  group('EditableDocument — moveByWord', () {
    testWidgets('Alt+Right moves forward to next word boundary on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controller = _makeController(text: 'Hello world');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
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

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();

      expect(controller.selection, isNotNull);
      final offset = (controller.selection!.extent.nodePosition as TextNodePosition).offset;
      // Moving right from 0 should jump past 'Hello' to offset 5 or 6.
      expect(offset, greaterThan(0));

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('moveByWord is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByWord(forward: true, extend: false);

      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // moveByCharacter edge cases
  // -------------------------------------------------------------------------

  group('EditableDocument — moveByCharacter edge cases', () {
    testWidgets('moveByCharacter is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: true, extend: false);

      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Shift+Right extends selection by one character', (tester) async {
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
            nodePosition: TextNodePosition(offset: 0),
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

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        1,
      );
    });
  });

  // -------------------------------------------------------------------------
  // deleteForward — various node-type paths
  // -------------------------------------------------------------------------

  group('EditableDocument — deleteForward', () {
    Future<({DocumentEditingController controller, FocusNode focusNode})> _buildFocusedEditor(
      WidgetTester tester, {
      required List<DocumentNode> nodes,
    }) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument(nodes);
      final controller = DocumentEditingController(document: doc);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
              editor: editor,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      return (controller: controller, focusNode: focusNode);
    }

    testWidgets('deleteForward is no-op when readOnly', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteForward();

      // Text should be unchanged — readOnly blocks delete.
      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, 'Hello');
    });

    testWidgets('deleteForward is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteForward();

      expect(tester.takeException(), isNull);
    });

    testWidgets('deleteForward on expanded selection deletes selection', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [ParagraphNode(id: 'p1', text: AttributedText('Hello world'))],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Select 'Hello' — expanded selection.
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteForward();
      await tester.pump();

      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, ' world');
    });

    testWidgets('deleteForward at end of text merges with next node', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [
          ParagraphNode(id: 'p1', text: AttributedText('Hello')),
          ParagraphNode(id: 'p2', text: AttributedText('World')),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Place caret at end of p1.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteForward();
      await tester.pump();

      // p1 and p2 should be merged.
      expect(controller.document.nodes.length, 1);
      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, 'HelloWorld');
    });

    testWidgets('deleteForward at end of last text node is no-op', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [ParagraphNode(id: 'p1', text: AttributedText('Hello'))],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteForward();
      await tester.pump();

      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, 'Hello');
    });

    testWidgets('deleteForward on binary node deletes the node', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [
          ImageNode(id: 'img1', imageUrl: 'test.png'),
          ParagraphNode(id: 'p1', text: AttributedText('After')),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'img1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteForward();
      await tester.pump();

      // Image node should be deleted.
      expect(controller.document.nodeById('img1'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // deleteBackward — complex paths
  // -------------------------------------------------------------------------

  group('EditableDocument — deleteBackward', () {
    Future<({DocumentEditingController controller, FocusNode focusNode})> _buildFocusedEditor(
      WidgetTester tester, {
      required List<DocumentNode> nodes,
    }) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument(nodes);
      final controller = DocumentEditingController(document: doc);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
              editor: editor,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      return (controller: controller, focusNode: focusNode);
    }

    testWidgets('deleteBackward is no-op when readOnly', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();

      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, 'Hello');
    });

    testWidgets('deleteBackward is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();

      expect(tester.takeException(), isNull);
    });

    testWidgets('deleteBackward on expanded selection deletes selection', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [ParagraphNode(id: 'p1', text: AttributedText('Hello world'))],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();
      await tester.pump();

      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, ' world');
    });

    testWidgets('deleteBackward at offset 0 of empty list item converts to paragraph',
        (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [ListItemNode(id: 'li1', text: AttributedText(''))],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'li1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();
      await tester.pump();

      // The list item should be converted to a paragraph node.
      expect(controller.document.nodeById('li1'), isA<ParagraphNode>());
    });

    testWidgets('deleteBackward at offset 0 of empty blockquote converts to paragraph',
        (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [
          ParagraphNode(
            id: 'bq1',
            text: AttributedText(''),
            blockType: ParagraphBlockType.blockquote,
          ),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'bq1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();
      await tester.pump();

      // The blockquote should be converted to a normal paragraph.
      final node = controller.document.nodeById('bq1')! as ParagraphNode;
      expect(node.blockType, ParagraphBlockType.paragraph);
    });

    testWidgets('deleteBackward at offset 0 merges with preceding text node', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [
          ParagraphNode(id: 'p1', text: AttributedText('Hello')),
          ParagraphNode(id: 'p2', text: AttributedText('World')),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Place caret at start of p2.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p2',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();
      await tester.pump();

      // p1 and p2 should be merged.
      expect(controller.document.nodes.length, 1);
      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, 'HelloWorld');
    });

    testWidgets('deleteBackward at offset 0 with preceding binary node deletes binary node',
        (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [
          ImageNode(id: 'img1', imageUrl: 'test.png'),
          ParagraphNode(id: 'p1', text: AttributedText('After')),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Place caret at start of p1.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();
      await tester.pump();

      // The preceding image node should be deleted.
      expect(controller.document.nodeById('img1'), isNull);
    });

    testWidgets('deleteBackward at offset 0 of first node is no-op', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [ParagraphNode(id: 'p1', text: AttributedText('Hello'))],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();
      await tester.pump();

      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, 'Hello');
    });

    testWidgets('deleteBackward on binary node at caret position deletes the node', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [
          ParagraphNode(id: 'p1', text: AttributedText('Before')),
          ImageNode(id: 'img1', imageUrl: 'test.png'),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'img1',
            nodePosition: BinaryNodePosition.downstream(),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();
      await tester.pump();

      expect(controller.document.nodeById('img1'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // handleEnter — various node-type paths
  // -------------------------------------------------------------------------

  group('EditableDocument — handleEnter', () {
    Future<({DocumentEditingController controller, FocusNode focusNode})> _buildFocusedEditor(
      WidgetTester tester, {
      required List<DocumentNode> nodes,
    }) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument(nodes);
      final controller = DocumentEditingController(document: doc);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
              editor: editor,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      return (controller: controller, focusNode: focusNode);
    }

    testWidgets('handleEnter is no-op when readOnly', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleEnter();

      expect(tester.takeException(), isNull);
    });

    testWidgets('handleEnter is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleEnter();

      expect(tester.takeException(), isNull);
    });

    testWidgets('handleEnter on empty list item converts to paragraph', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [ListItemNode(id: 'li1', text: AttributedText(''))],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'li1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleEnter();
      await tester.pump();

      // Empty list item on Enter should become a paragraph.
      expect(controller.document.nodeById('li1'), isA<ParagraphNode>());
    });

    testWidgets('handleEnter on empty blockquote paragraph converts to normal paragraph',
        (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [
          ParagraphNode(
            id: 'bq1',
            text: AttributedText(''),
            blockType: ParagraphBlockType.blockquote,
          ),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'bq1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleEnter();
      await tester.pump();

      final node = controller.document.nodeById('bq1')! as ParagraphNode;
      expect(node.blockType, ParagraphBlockType.paragraph);
    });

    testWidgets('handleEnter in non-empty code block inserts newline', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [CodeBlockNode(id: 'cb1', text: AttributedText('code'))],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'cb1',
            nodePosition: TextNodePosition(offset: 4),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleEnter();
      await tester.pump();

      final node = controller.document.nodeById('cb1')! as CodeBlockNode;
      expect(node.text.text, 'code\n');
    });

    testWidgets('handleEnter in empty code block converts it to a paragraph in place',
        (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [CodeBlockNode(id: 'cb1', text: AttributedText(''))],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'cb1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleEnter();
      await tester.pump();

      // ExitCodeBlockCommand with empty text replaces the node in-place with a
      // ParagraphNode — the same id is preserved.
      expect(controller.document.nodeById('cb1'), isA<ParagraphNode>());
    });

    testWidgets('handleEnter in blockquote with trailing newline exits blockquote', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedEditor(
        tester,
        nodes: [BlockquoteNode(id: 'bq1', text: AttributedText('line\n'))],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'bq1',
            nodePosition: TextNodePosition(offset: 5), // end of 'line\n'
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleEnter();
      await tester.pump();

      // ExitBlockquoteCommand with removeTrailingNewline truncates 'bq1' to
      // 'line' and inserts a new ParagraphNode after it — so bq1 still exists
      // but now contains only 'line', and a new paragraph has been appended.
      final bq = controller.document.nodeById('bq1')! as BlockquoteNode;
      expect(bq.text.text, 'line');
      // A new paragraph should have been inserted after the blockquote.
      expect(controller.document.nodes.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  // handleShiftEnter
  // -------------------------------------------------------------------------

  group('EditableDocument — handleShiftEnter', () {
    testWidgets('handleShiftEnter is no-op when readOnly', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([CodeBlockNode(id: 'cb1', text: AttributedText('code'))]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'cb1',
            nodePosition: TextNodePosition(offset: 4),
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleShiftEnter();

      expect(tester.takeException(), isNull);
    });

    testWidgets('handleShiftEnter on code block exits code block', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([CodeBlockNode(id: 'cb1', text: AttributedText('code'))]);
      final controller = DocumentEditingController(document: doc);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);
      addTearDown(editor.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'cb1',
            nodePosition: TextNodePosition(offset: 4),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
              editor: editor,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleShiftEnter();
      await tester.pump();

      // Code block should be exited — it will be split or replaced by a paragraph.
      expect(tester.takeException(), isNull);
    });

    testWidgets('handleShiftEnter is no-op for paragraph node', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleShiftEnter();

      // Paragraph node — no-op, no exception.
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // handleTab / handleShiftTab
  // -------------------------------------------------------------------------

  group('EditableDocument — handleTab', () {
    testWidgets('handleTab is no-op when readOnly', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleTab();

      expect(tester.takeException(), isNull);
    });

    testWidgets('handleTab indents list item', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([ListItemNode(id: 'li1', text: AttributedText('Item'))]);
      final controller = DocumentEditingController(document: doc);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);
      addTearDown(editor.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'li1',
            nodePosition: TextNodePosition(offset: 4),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
              editor: editor,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final stateBefore = controller.document.nodeById('li1')! as ListItemNode;
      final indentBefore = stateBefore.indent;

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleTab();
      await tester.pump();

      final stateAfter = controller.document.nodeById('li1')! as ListItemNode;
      expect(stateAfter.indent, greaterThan(indentBefore));
    });

    testWidgets('handleShiftTab is no-op when readOnly', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([ListItemNode(id: 'li1', text: AttributedText('Item'))]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'li1',
            nodePosition: TextNodePosition(offset: 4),
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleShiftTab();

      expect(tester.takeException(), isNull);
    });

    testWidgets('handleShiftTab unindents list item', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc =
          MutableDocument([ListItemNode(id: 'li1', text: AttributedText('Item'), indent: 1)]);
      final controller = DocumentEditingController(document: doc);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);
      addTearDown(editor.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'li1',
            nodePosition: TextNodePosition(offset: 4),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
              editor: editor,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleShiftTab();
      await tester.pump();

      final stateAfter = controller.document.nodeById('li1')! as ListItemNode;
      expect(stateAfter.indent, 0);
    });
  });

  // -------------------------------------------------------------------------
  // moveHome / moveEnd
  // -------------------------------------------------------------------------

  group('EditableDocument — moveHome and moveEnd', () {
    testWidgets('moveHome is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveHome(extend: false);

      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('moveHome moves to start of text node', (tester) async {
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
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveHome(extend: false);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        0,
      );
    });

    testWidgets('moveEnd is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveEnd(extend: false);

      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('moveEnd moves to end of text node', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveEnd(extend: false);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        5, // 'Hello'.length
      );
    });

    testWidgets('moveHome extends selection when extend is true', (tester) async {
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
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveHome(extend: true);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        0,
      );
    });
  });

  // -------------------------------------------------------------------------
  // toggleAttribution
  // -------------------------------------------------------------------------

  group('EditableDocument — toggleAttribution', () {
    testWidgets('toggleAttribution is no-op when readOnly', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.toggleAttribution(NamedAttribution.bold);

      // No exception, text unchanged.
      expect(tester.takeException(), isNull);
    });

    testWidgets('toggleAttribution is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.toggleAttribution(NamedAttribution.bold);

      expect(tester.takeException(), isNull);
    });

    testWidgets('toggleAttribution on collapsed selection updates composer preferences',
        (tester) async {
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
            nodePosition: TextNodePosition(offset: 2),
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));

      // Before toggle, bold should not be active.
      expect(controller.preferences.isActive(NamedAttribution.bold), isFalse);

      state.toggleAttribution(NamedAttribution.bold);

      // After toggle, bold should be active in preferences.
      expect(controller.preferences.isActive(NamedAttribution.bold), isTrue);
    });

    testWidgets('toggleAttribution on expanded selection applies bold via editor', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);
      addTearDown(editor.dispose);

      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
              editor: editor,
            ),
          ),
        ),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.toggleAttribution(NamedAttribution.bold);
      await tester.pump();

      // Bold should be applied to 'Hello'.
      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(
        node.text.hasAttributionAt(0, NamedAttribution.bold),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  // copySelection / cutSelection no-op when null or collapsed
  // -------------------------------------------------------------------------

  group('EditableDocument — copySelection and cutSelection no-ops', () {
    testWidgets('copySelection is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.copySelection();

      expect(tester.takeException(), isNull);
    });

    testWidgets('copySelection is no-op when selection is collapsed', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.copySelection();

      expect(tester.takeException(), isNull);
    });

    testWidgets('cutSelection is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.cutSelection();

      expect(tester.takeException(), isNull);
    });

    testWidgets('cutSelection is no-op when selection is collapsed', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.cutSelection();

      expect(tester.takeException(), isNull);
    });

    testWidgets('cutSelection is no-op when readOnly', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.cutSelection();

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // moveByPage no-op paths
  // -------------------------------------------------------------------------

  group('EditableDocument — moveByPage', () {
    testWidgets('moveByPage is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByPage(forward: true, extend: false);

      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // moveVertically no-op when selection is null
  // -------------------------------------------------------------------------

  group('EditableDocument — moveVertically null-selection', () {
    testWidgets('moveVertically is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveVertically(forward: true, extend: false);

      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // moveToLineStartOrEnd no-op when selection is null
  // -------------------------------------------------------------------------

  group('EditableDocument — moveToLineStartOrEnd', () {
    testWidgets('moveToLineStartOrEnd is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveToLineStartOrEnd(forward: true, extend: false);

      expect(controller.selection, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('moveToLineStartOrEnd falls back to node end for binary node', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final doc = MutableDocument([
        ImageNode(id: 'img1', imageUrl: 'test.png'),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'img1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveToLineStartOrEnd(forward: true, extend: false);

      // For a binary node, should move to downstream position.
      expect(controller.selection, isNotNull);
      expect(
        controller.selection!.extent.nodePosition,
        const BinaryNodePosition.downstream(),
      );
    });
  });

  // -------------------------------------------------------------------------
  // pasteClipboard — no-op paths
  // -------------------------------------------------------------------------

  group('EditableDocument — pasteClipboard no-ops', () {
    testWidgets('pasteClipboard is no-op when readOnly', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
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

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.pasteClipboard();

      expect(tester.takeException(), isNull);
    });

    testWidgets('pasteClipboard is no-op when selection is null', (tester) async {
      final controller = _makeController(text: 'Hello');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(EditableDocument(controller: controller, focusNode: focusNode)),
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.pasteClipboard();

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // didUpdateWidget — controller swap re-registers with autofill scope
  // -------------------------------------------------------------------------

  group('EditableDocument — didUpdateWidget with autofill scope', () {
    testWidgets('controller swap inside AutofillGroup does not crash', (tester) async {
      final log = <MethodCall>[];
      _installTextInputMock(tester, log);

      final controllerA = _makeController(text: 'A');
      final controllerB = _makeController(text: 'B');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controllerA.dispose);
      addTearDown(controllerB.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AutofillGroup(
              child: EditableDocument(
                controller: controllerA,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );

      // Swap controller inside the same AutofillGroup.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AutofillGroup(
              child: EditableDocument(
                controller: controllerB,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // TableNode operations — moveHome/moveEnd, deleteForward/Backward,
  // handleTab/handleShiftTab, moveByCharacter, moveByWord
  // -------------------------------------------------------------------------

  /// Creates a focused [EditableDocument] with an [UndoableEditor] wired to a
  /// [MutableDocument] that contains [nodes]. Returns the controller and focus
  /// node via a record.
  Future<({DocumentEditingController controller, FocusNode focusNode})> _buildFocusedWithNodes(
    WidgetTester tester, {
    required List<DocumentNode> nodes,
  }) async {
    final log = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (MethodCall call) async {
        log.add(call);
        return null;
      },
    );

    final doc = MutableDocument(nodes);
    final controller = DocumentEditingController(document: doc);
    final editor = UndoableEditor(
      editContext: EditContext(document: doc, controller: controller),
    );
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableDocument(
            controller: controller,
            focusNode: focusNode,
            editor: editor,
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    return (controller: controller, focusNode: focusNode);
  }

  /// Builds a minimal [TableNode] with [rowCount] × [colCount] cells.
  ///
  /// Cell text is generated as `r{row}c{col}` (e.g., `r0c0`, `r0c1`).
  TableNode _makeTable({
    String id = 't1',
    required int rowCount,
    required int colCount,
  }) {
    final cells = List.generate(
      rowCount,
      (r) => List.generate(colCount, (c) => AttributedText('r${r}c$c')),
    );
    return TableNode(
      id: id,
      rowCount: rowCount,
      columnCount: colCount,
      cells: cells,
    );
  }

  group('EditableDocument — TableNode moveHome/moveEnd', () {
    testWidgets('moveHome in a table cell moves to offset 0 of that cell', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Place caret at end of cell (0,0) — text is 'r0c0' (4 chars).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 4),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveHome(extend: false);
      await tester.pump();

      expect(controller.selection, isNotNull);
      final pos = controller.selection!.extent.nodePosition as TableCellPosition;
      expect(pos.row, 0);
      expect(pos.col, 0);
      expect(pos.offset, 0);
    });

    testWidgets('moveEnd in a table cell moves to end offset of that cell', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Place caret at offset 0 of cell (1,1) — text is 'r1c1' (4 chars).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 1, col: 1, offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveEnd(extend: false);
      await tester.pump();

      expect(controller.selection, isNotNull);
      final pos = controller.selection!.extent.nodePosition as TableCellPosition;
      expect(pos.row, 1);
      expect(pos.col, 1);
      expect(pos.offset, 4); // 'r1c1'.length
    });
  });

  group('EditableDocument — TableNode deleteForward', () {
    testWidgets('deleteForward in table cell removes character at offset', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at offset 1 of cell (0,0) ('r0c0' → deletes '0').
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 1),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteForward();
      await tester.pump();

      final node = controller.document.nodeById('t1')! as TableNode;
      expect(node.cellAt(0, 0).text, 'rc0'); // 'r0c0' with '0' at index 1 removed
    });

    testWidgets('deleteForward at end of table cell is no-op', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at end of cell (0,0) ('r0c0' is 4 chars).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 4),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteForward();
      await tester.pump();

      final node = controller.document.nodeById('t1')! as TableNode;
      expect(node.cellAt(0, 0).text, 'r0c0'); // unchanged
      expect(tester.takeException(), isNull);
    });
  });

  group('EditableDocument — TableNode deleteBackward', () {
    testWidgets('deleteBackward in table cell removes character before offset', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at offset 2 of cell (0,0) ('r0c0' → deletes '0' at index 1).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 2),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();
      await tester.pump();

      final node = controller.document.nodeById('t1')! as TableNode;
      expect(node.cellAt(0, 0).text, 'rc0'); // 'r0c0' with '0' at index 1 removed
    });

    testWidgets('deleteBackward at offset 0 of table cell is no-op', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at offset 0 of cell (0,0).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();
      await tester.pump();

      final node = controller.document.nodeById('t1')! as TableNode;
      expect(node.cellAt(0, 0).text, 'r0c0'); // unchanged
      expect(tester.takeException(), isNull);
    });
  });

  group('EditableDocument — TableNode handleTab/handleShiftTab', () {
    testWidgets('Tab in last column of a row advances to next row first column', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at last column of first row.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 1, offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleTab();
      await tester.pump();

      expect(controller.selection, isNotNull);
      final pos = controller.selection!.extent.nodePosition as TableCellPosition;
      expect(pos.row, 1);
      expect(pos.col, 0);
    });

    testWidgets('Tab in last row last column is no-op (no next row)', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at last cell of table.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 1, col: 1, offset: 0),
          ),
        ),
      );
      await tester.pump();

      final selectionBefore = controller.selection;

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleTab();
      await tester.pump();

      // Selection should be unchanged — no cell beyond the last.
      expect(controller.selection, equals(selectionBefore));
    });

    testWidgets('Shift+Tab in first column of a row goes to previous row last column',
        (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at first column of second row.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 1, col: 0, offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleShiftTab();
      await tester.pump();

      expect(controller.selection, isNotNull);
      final pos = controller.selection!.extent.nodePosition as TableCellPosition;
      expect(pos.row, 0);
      expect(pos.col, 1); // last column
    });

    testWidgets('Shift+Tab at row 0 col 0 is no-op', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at first cell.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
          ),
        ),
      );
      await tester.pump();

      final selectionBefore = controller.selection;

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleShiftTab();
      await tester.pump();

      expect(controller.selection, equals(selectionBefore));
    });
  });

  group('EditableDocument — TableNode moveByCharacter', () {
    testWidgets('arrowRight in table cell advances offset by one', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at offset 1 in cell (0,0).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 1),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: true, extend: false);
      await tester.pump();

      final pos = controller.selection!.extent.nodePosition as TableCellPosition;
      expect(pos.offset, 2);
    });

    testWidgets('arrowRight at end of table cell wraps to next cell', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at end of cell (0,0) — 'r0c0' has length 4.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 4),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: true, extend: false);
      await tester.pump();

      final pos = controller.selection!.extent.nodePosition as TableCellPosition;
      // Should have moved to cell (0,1) offset 0.
      expect(pos.row, 0);
      expect(pos.col, 1);
      expect(pos.offset, 0);
    });

    testWidgets('arrowRight from last cell of last row wraps to next node', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [
          _makeTable(rowCount: 1, colCount: 1),
          ParagraphNode(id: 'p1', text: AttributedText('Next')),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at end of only cell — 'r0c0' has length 4.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 4),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: true, extend: false);
      await tester.pump();

      // Should have moved to the paragraph node.
      expect(controller.selection!.extent.nodeId, 'p1');
    });

    testWidgets('arrowLeft in table cell decrements offset by one', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at offset 3 in cell (0,0).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 3),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: false, extend: false);
      await tester.pump();

      final pos = controller.selection!.extent.nodePosition as TableCellPosition;
      expect(pos.offset, 2);
    });

    testWidgets('arrowLeft at offset 0 of cell wraps to end of previous cell', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at offset 0 of cell (0,1).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 1, offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: false, extend: false);
      await tester.pump();

      final pos = controller.selection!.extent.nodePosition as TableCellPosition;
      expect(pos.row, 0);
      expect(pos.col, 0);
      expect(pos.offset, 4); // end of 'r0c0'
    });

    testWidgets('arrowLeft at offset 0 of first table cell wraps to prev node', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [
          ParagraphNode(id: 'p1', text: AttributedText('Before')),
          _makeTable(rowCount: 1, colCount: 1),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at offset 0 of first (and only) cell.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: false, extend: false);
      await tester.pump();

      expect(controller.selection!.extent.nodeId, 'p1');
    });

    testWidgets('arrowLeft at col 0 of non-first row wraps to last col of prev row',
        (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [_makeTable(rowCount: 2, colCount: 2)],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at offset 0 of cell (1,0).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 1, col: 0, offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: false, extend: false);
      await tester.pump();

      final pos = controller.selection!.extent.nodePosition as TableCellPosition;
      expect(pos.row, 0);
      expect(pos.col, 1); // last column
      expect(pos.offset, 4); // end of 'r0c1'
    });

    testWidgets('arrowRight at end of last row last col wraps to next node', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [
          _makeTable(rowCount: 2, colCount: 2),
          ParagraphNode(id: 'p1', text: AttributedText('After')),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      // Caret at end of cell (1,1) — 'r1c1' has length 4.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 1, col: 1, offset: 4),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: true, extend: false);
      await tester.pump();

      expect(controller.selection!.extent.nodeId, 'p1');
    });
  });

  group('EditableDocument — BinaryNodePosition character movement', () {
    testWidgets('arrowRight from upstream binary position moves to downstream', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [
          HorizontalRuleNode(id: 'hr1'),
          ParagraphNode(id: 'p1', text: AttributedText('After')),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: true, extend: false);
      await tester.pump();

      final pos = controller.selection!.extent.nodePosition as BinaryNodePosition;
      expect(pos.type, BinaryNodePositionType.downstream);
    });

    testWidgets('arrowRight from downstream binary position wraps to next node', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [
          HorizontalRuleNode(id: 'hr1'),
          ParagraphNode(id: 'p1', text: AttributedText('After')),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: BinaryNodePosition.downstream(),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: true, extend: false);
      await tester.pump();

      expect(controller.selection!.extent.nodeId, 'p1');
    });

    testWidgets('arrowLeft from downstream binary position moves to upstream', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [
          ParagraphNode(id: 'p1', text: AttributedText('Before')),
          HorizontalRuleNode(id: 'hr1'),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: BinaryNodePosition.downstream(),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: false, extend: false);
      await tester.pump();

      final pos = controller.selection!.extent.nodePosition as BinaryNodePosition;
      expect(pos.type, BinaryNodePositionType.upstream);
    });

    testWidgets('arrowLeft from upstream binary position wraps to previous node', (tester) async {
      final (:controller, :focusNode) = await _buildFocusedWithNodes(
        tester,
        nodes: [
          ParagraphNode(id: 'p1', text: AttributedText('Before')),
          HorizontalRuleNode(id: 'hr1'),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByCharacter(forward: false, extend: false);
      await tester.pump();

      expect(controller.selection!.extent.nodeId, 'p1');
    });
  });

  group('EditableDocument — TableNode moveByWord', () {
    testWidgets('moveByWord forward in table cell moves to end of word', (tester) async {
      // Use a table with multi-word text so word navigation is meaningful.
      final cells = [
        [AttributedText('hello world')],
      ];
      final doc = MutableDocument([
        TableNode(id: 't1', rowCount: 1, columnCount: 1, cells: cells),
      ]);
      final controller = DocumentEditingController(document: doc);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (MethodCall call) async => null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
              editor: editor,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Caret at offset 0 — word end of 'hello' should be at offset 5.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByWord(forward: true, extend: false);
      await tester.pump();

      final pos = controller.selection!.extent.nodePosition as TableCellPosition;
      expect(pos.offset, 5); // end of 'hello'
    });

    testWidgets('moveByWord backward in table cell moves to start of word', (tester) async {
      final cells = [
        [AttributedText('hello world')],
      ];
      final doc = MutableDocument([
        TableNode(id: 't1', rowCount: 1, columnCount: 1, cells: cells),
      ]);
      final controller = DocumentEditingController(document: doc);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (MethodCall call) async => null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
              editor: editor,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Caret at offset 11 (end of 'hello world'); backward should stop at
      // start of 'world' (offset 6).
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 't1',
            nodePosition: TableCellPosition(row: 0, col: 0, offset: 11),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.moveByWord(forward: false, extend: false);
      await tester.pump();

      final pos = controller.selection!.extent.nodePosition as TableCellPosition;
      expect(pos.offset, 6); // start of 'world'
    });
  });

  group('EditableDocument — pasteClipboard with expanded selection', () {
    testWidgets('paste over expanded selection deletes selection then inserts clipboard',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      String? clipboardData;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardData = (call.arguments as Map<String, dynamic>)['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            if (clipboardData == null) return null;
            return <String, dynamic>{'text': clipboardData};
          }
          return null;
        },
      );

      // Pre-fill clipboard.
      clipboardData = 'REPLACED';

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (MethodCall call) async => null,
      );

      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello world')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
              editor: editor,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Expanded selection over 'Hello' (0..5).
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );
      await tester.pump();

      // Trigger paste via Cmd+V.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      // The expanded selection 'Hello' should have been replaced by 'REPLACED'.
      final node = controller.document.nodeById('p1')! as ParagraphNode;
      expect(node.text.text, 'REPLACED world');

      controller.dispose();
      focusNode.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('EditableDocument — moveToLineStartOrEnd fallback for binary node', () {
    testWidgets('Cmd+Left on an image node moves to upstream position', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (MethodCall call) async => null,
      );

      final doc = MutableDocument([
        ImageNode(id: 'img1', imageUrl: 'test.png'),
      ]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'img1',
            nodePosition: BinaryNodePosition.downstream(),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableDocument(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Cmd+Left on an image — resolver returns null (not a text block),
      // so fallback _startOfNode produces upstream BinaryNodePosition.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(controller.selection, isNotNull);
      final pos = controller.selection!.extent.nodePosition as BinaryNodePosition;
      expect(pos.type, BinaryNodePositionType.upstream);

      controller.dispose();
      focusNode.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
