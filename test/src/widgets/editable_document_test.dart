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
        ImageNode(id: 'img1', imageUrl: 'test.png', height: 200),
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
        ImageNode(id: 'img1', imageUrl: 'test.png', height: 200),
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
}
