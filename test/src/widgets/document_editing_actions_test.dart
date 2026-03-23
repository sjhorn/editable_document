/// Tests for document editing Actions wired into [EditableDocument].
///
/// These tests verify the Shortcuts/Actions pipeline for navigation, editing,
/// and formatting operations.
///
/// Each test group corresponds to a logical operation category:
/// - Navigation (arrow keys, Home/End, Page Up/Down)
/// - Editing (Delete, Backspace, Tab, Enter)
/// - Clipboard (Copy, Cut, Paste, Select All)
/// - Collapse selection (Escape)
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';
import 'package:editable_document/src/widgets/document_editing_actions.dart'
    show createDocumentEditingActions;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a single-paragraph [MutableDocument] with [text].
MutableDocument _singleParagraph(String text, {String id = 'p1'}) {
  return MutableDocument([ParagraphNode(id: id, text: AttributedText(text))]);
}

/// Builds a [MutableDocument] with two paragraphs.
MutableDocument _twoParagraphs({
  String firstText = 'Hello',
  String secondText = 'World',
  String firstId = 'p1',
  String secondId = 'p2',
}) {
  return MutableDocument([
    ParagraphNode(id: firstId, text: AttributedText(firstText)),
    ParagraphNode(id: secondId, text: AttributedText(secondText)),
  ]);
}

/// Creates a collapsed [DocumentSelection] at [offset] in node [nodeId].
DocumentSelection _collapsed(String nodeId, int offset) {
  return DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: nodeId,
      nodePosition: TextNodePosition(offset: offset),
    ),
  );
}

/// Pumps an [EditableDocument] inside a [MaterialApp]+[Scaffold].
///
/// Returns the [EditableDocumentState] for state-level assertions.
Future<EditableDocumentState> _pumpDocument(
  WidgetTester tester, {
  required DocumentEditingController controller,
  required FocusNode focusNode,
  bool readOnly = false,
  Editor? editor,
}) async {
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
  return tester.state<EditableDocumentState>(find.byType(EditableDocument));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // collapseSelection — Escape key / CollapseSelectionIntent
  // =========================================================================

  group('CollapseSelectionIntent', () {
    testWidgets('collapses expanded selection to its extent', (tester) async {
      final doc = _twoParagraphs();
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
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
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.collapseSelection();
      await tester.pump();

      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        5,
      );
    });

    testWidgets('no-op when selection is already collapsed', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 3),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.collapseSelection();
      await tester.pump();

      expect(controller.selection, _collapsed('p1', 3));
    });

    testWidgets('Escape key collapses selection via Shortcuts pipeline', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
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
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(tester, controller: controller, focusNode: focusNode);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(controller.selection!.isCollapsed, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // =========================================================================
  // moveByCharacter — Left/Right arrow
  // =========================================================================

  group('moveByCharacter', () {
    testWidgets('moves caret right one character', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 2),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveByCharacter(forward: true, extend: false);
      await tester.pump();

      expect(controller.selection, _collapsed('p1', 3));
    });

    testWidgets('moves caret left one character', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 2),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveByCharacter(forward: false, extend: false);
      await tester.pump();

      expect(controller.selection, _collapsed('p1', 1));
    });

    testWidgets('right-arrow on expanded selection collapses to extent', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
          base: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 3),
          ),
        ),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveByCharacter(forward: true, extend: false);
      await tester.pump();

      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        3,
      );
    });

    testWidgets('left-arrow on expanded selection collapses to base', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
          base: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 3),
          ),
        ),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveByCharacter(forward: false, extend: false);
      await tester.pump();

      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        0,
      );
    });

    testWidgets('extend: true extends selection', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 2),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveByCharacter(forward: true, extend: true);
      await tester.pump();

      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.base.nodePosition as TextNodePosition).offset,
        2,
      );
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        3,
      );
    });

    testWidgets('right arrow key moves caret via Shortcuts pipeline', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 0),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(controller.selection, _collapsed('p1', 1));
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // =========================================================================
  // moveByWord — word-modifier + Left/Right
  // =========================================================================

  group('moveByWord', () {
    testWidgets('moves to word end (forward)', (tester) async {
      final doc = _singleParagraph('hello world');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 0),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveByWord(forward: true, extend: false);
      await tester.pump();

      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        5,
      );
    });

    testWidgets('moves to word start (backward)', (tester) async {
      final doc = _singleParagraph('hello world');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 11),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveByWord(forward: false, extend: false);
      await tester.pump();

      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        6,
      );
    });
  });

  // =========================================================================
  // moveToLineStartOrEnd — line-modifier + Left/Right
  // =========================================================================

  group('moveToLineStartOrEnd', () {
    testWidgets('moves to start of node when no line resolver (backward)', (tester) async {
      final doc = _singleParagraph('Hello World');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 5),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveToLineStartOrEnd(forward: false, extend: false);
      await tester.pump();

      expect(controller.selection, _collapsed('p1', 0));
    });

    testWidgets('moves to end of node when no line resolver (forward)', (tester) async {
      final doc = _singleParagraph('Hello World');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 3),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveToLineStartOrEnd(forward: true, extend: false);
      await tester.pump();

      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        11,
      );
    });
  });

  // =========================================================================
  // moveVertically — Up/Down arrow
  // =========================================================================

  group('moveVertically', () {
    testWidgets('down without resolver moves to next node start', (tester) async {
      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 2),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveVertically(forward: true, extend: false);
      await tester.pump();

      // No layout available in unit test, falls back to next node start.
      expect(controller.selection!.extent.nodeId, 'p2');
    });

    testWidgets('up without resolver moves to previous node start', (tester) async {
      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p2', 2),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveVertically(forward: false, extend: false);
      await tester.pump();

      expect(controller.selection!.extent.nodeId, 'p1');
    });
  });

  // =========================================================================
  // moveToDocumentStartOrEnd
  // =========================================================================

  group('moveToDocumentStartOrEnd', () {
    testWidgets('moves to document start', (tester) async {
      final doc = _twoParagraphs();
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p2', 3),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveToDocumentStartOrEnd(forward: false, extend: false);
      await tester.pump();

      expect(controller.selection!.extent.nodeId, 'p1');
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        0,
      );
    });

    testWidgets('moves to document end', (tester) async {
      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 0),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveToDocumentStartOrEnd(forward: true, extend: false);
      await tester.pump();

      expect(controller.selection!.extent.nodeId, 'p2');
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        5,
      );
    });
  });

  // =========================================================================
  // moveToNodeStartOrEnd
  // =========================================================================

  group('moveToNodeStartOrEnd', () {
    testWidgets('moves to start of current node', (tester) async {
      final doc = _singleParagraph('Hello World');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 5),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveToNodeStartOrEnd(forward: false, extend: false);
      await tester.pump();

      expect(controller.selection, _collapsed('p1', 0));
    });

    testWidgets('moves to end of current node', (tester) async {
      final doc = _singleParagraph('Hello World');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 5),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveToNodeStartOrEnd(forward: true, extend: false);
      await tester.pump();

      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        11,
      );
    });
  });

  // =========================================================================
  // moveHome / moveEnd
  // =========================================================================

  group('moveHome and moveEnd', () {
    testWidgets('moveHome moves to node start', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 3),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveHome(extend: false);
      await tester.pump();

      expect(controller.selection, _collapsed('p1', 0));
    });

    testWidgets('moveEnd moves to node end', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 0),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveEnd(extend: false);
      await tester.pump();

      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        5,
      );
    });
  });

  // =========================================================================
  // deleteForward / deleteBackward
  // =========================================================================

  group('deleteForward', () {
    testWidgets('deletes the character at the caret', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 1),
      );
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        editor: editor,
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteForward();
      await tester.pump();

      expect((doc.nodeById('p1') as ParagraphNode).text.text, 'Hllo');
    });

    testWidgets('no-op when readOnly', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 1),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        readOnly: true,
      );
      state.deleteForward();
      await tester.pump();

      // Text unchanged.
      expect((doc.nodeById('p1') as ParagraphNode).text.text, 'Hello');
    });
  });

  group('deleteBackward', () {
    testWidgets('deletes the character before the caret', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 2),
      );
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        editor: editor,
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.deleteBackward();
      await tester.pump();

      expect((doc.nodeById('p1') as ParagraphNode).text.text, 'Hllo');
    });
  });

  // =========================================================================
  // handleTab
  // =========================================================================

  group('handleTab', () {
    testWidgets('inserts tab character in text node', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 5),
      );
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        editor: editor,
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleTab();
      await tester.pump();

      expect((doc.nodeById('p1') as ParagraphNode).text.text, 'Hello\t');
    });

    testWidgets('no-op when readOnly', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 5),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        readOnly: true,
      );
      state.handleTab();
      await tester.pump();

      // Text unchanged.
      expect((doc.nodeById('p1') as ParagraphNode).text.text, 'Hello');
    });
  });

  // =========================================================================
  // handleEnter
  // =========================================================================

  group('handleEnter', () {
    testWidgets('converts empty list item to paragraph (with editor)', (tester) async {
      final doc = MutableDocument([
        ListItemNode(id: 'li1', text: AttributedText(''), type: ListItemType.unordered),
      ]);
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'li1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        editor: editor,
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.handleEnter();
      await tester.pump();

      // After conversion the node at 'li1' is now a ParagraphNode.
      expect(doc.nodeById('li1'), isA<ParagraphNode>());
    });

    testWidgets('no-op when readOnly — does not throw', (tester) async {
      final doc = MutableDocument([
        ListItemNode(id: 'li1', text: AttributedText(''), type: ListItemType.unordered),
      ]);
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'li1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        readOnly: true,
      );
      expect(() => state.handleEnter(), returnsNormally);
    });
  });

  // =========================================================================
  // selectAll
  // =========================================================================

  group('selectAll', () {
    testWidgets('selects all content', (tester) async {
      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 0),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.selectAll();
      await tester.pump();

      expect(controller.selection!.isExpanded, isTrue);
      expect(controller.selection!.base.nodeId, 'p1');
      expect(controller.selection!.extent.nodeId, 'p2');
    });

    testWidgets('no-op when document is empty', (tester) async {
      final doc = MutableDocument([]);
      final controller = DocumentEditingController(document: doc);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.selectAll();
      await tester.pump();

      expect(controller.selection, isNull);
    });
  });

  // =========================================================================
  // copySelection / cutSelection / pasteClipboard
  // =========================================================================

  group('copySelection', () {
    testWidgets('no-op when selection is collapsed — does not throw', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 2),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      expect(() => state.copySelection(), returnsNormally);
    });
  });

  group('cutSelection', () {
    testWidgets('no-op when readOnly', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
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
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        readOnly: true,
      );
      state.cutSelection();
      await tester.pump();

      // Text unchanged.
      expect((doc.nodeById('p1') as ParagraphNode).text.text, 'Hello');
    });
  });

  group('pasteClipboard', () {
    testWidgets('no-op when readOnly — does not throw', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 5),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        readOnly: true,
      );
      expect(() => state.pasteClipboard(), returnsNormally);
    });
  });

  // =========================================================================
  // toggleAttribution
  // =========================================================================

  group('toggleAttribution', () {
    testWidgets('applies bold to expanded selection', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
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
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        editor: editor,
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.toggleAttribution(NamedAttribution.bold);
      await tester.pump();

      final node = doc.nodeById('p1') as ParagraphNode;
      expect(node.text.hasAttributionAt(0, NamedAttribution.bold), isTrue);
    });

    testWidgets('removes bold when already fully applied', (tester) async {
      final boldText = AttributedText(
        'Hello',
        const [
          SpanMarker(
            attribution: NamedAttribution.bold,
            offset: 0,
            markerType: SpanMarkerType.start,
          ),
          SpanMarker(
            attribution: NamedAttribution.bold,
            offset: 4,
            markerType: SpanMarkerType.end,
          ),
        ],
      );
      final doc = MutableDocument([ParagraphNode(id: 'p1', text: boldText)]);
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
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
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        editor: editor,
      );

      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      state.toggleAttribution(NamedAttribution.bold);
      await tester.pump();

      final node = doc.nodeById('p1') as ParagraphNode;
      // Bold should be removed.
      expect(node.text.hasAttributionAt(0, NamedAttribution.bold), isFalse);
    });

    testWidgets('toggles composer preferences when selection is collapsed', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 3),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);

      expect(controller.preferences.isActive(NamedAttribution.bold), isFalse);
      state.toggleAttribution(NamedAttribution.bold);
      await tester.pump();

      expect(controller.preferences.isActive(NamedAttribution.bold), isTrue);
    });
  });

  // =========================================================================
  // DefaultDocumentEditingShortcuts — shortcut-to-Action wiring
  // =========================================================================

  group('DefaultDocumentEditingShortcuts', () {
    testWidgets('widget is present in build tree inside EditableDocument', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 0),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(tester, controller: controller, focusNode: focusNode);

      expect(find.byType(DefaultDocumentEditingShortcuts), findsOneWidget);
    });

    testWidgets('Escape key collapses selection (macOS)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
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
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(controller.selection!.isCollapsed, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Cmd+B on macOS applies bold to expanded selection', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
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
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        editor: editor,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      final node = doc.nodeById('p1') as ParagraphNode;
      expect(node.text.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+B on Linux applies bold to expanded selection', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection(
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
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        editor: editor,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final node = doc.nodeById('p1') as ParagraphNode;
      expect(node.text.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // =========================================================================
  // moveByPage — Page Up/Down
  // =========================================================================

  group('moveByPage', () {
    testWidgets('moveByPage forward moves to document end when no layout', (tester) async {
      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 0),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveByPage(forward: true, extend: false);
      await tester.pump();

      // Falls back to document end without layout.
      expect(controller.selection!.extent.nodeId, 'p2');
    });

    testWidgets('moveByPage backward moves to document start when no layout', (tester) async {
      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p2', 3),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(tester, controller: controller, focusNode: focusNode);
      state.moveByPage(forward: false, extend: false);
      await tester.pump();

      expect(controller.selection!.extent.nodeId, 'p1');
    });
  });

  // =========================================================================
  // handleShiftEnter
  // =========================================================================

  group('handleShiftEnter', () {
    testWidgets('no-op when readOnly — does not throw', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 5),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        readOnly: true,
      );
      expect(() => state.handleShiftEnter(), returnsNormally);
    });

    testWidgets('handleShiftEnter with editor does not throw', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 5),
      );
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        editor: editor,
      );
      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      expect(() => state.handleShiftEnter(), returnsNormally);
    });
  });

  // =========================================================================
  // handleShiftTab
  // =========================================================================

  group('handleShiftTab', () {
    testWidgets('no-op when readOnly — does not throw', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 5),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final state = await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        readOnly: true,
      );
      expect(() => state.handleShiftTab(), returnsNormally);
    });

    testWidgets('handleShiftTab with editor does not throw', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 5),
      );
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        editor: editor,
      );
      final state = tester.state<EditableDocumentState>(find.byType(EditableDocument));
      expect(() => state.handleShiftTab(), returnsNormally);
    });
  });

  // =========================================================================
  // isSelectionFullyAttributed helper
  // =========================================================================

  group('isSelectionFullyAttributed', () {
    test('returns false for collapsed selection', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final sel = _collapsed('p1', 2);
      expect(isSelectionFullyAttributed(sel, NamedAttribution.bold, doc), isFalse);
    });

    test('returns false for multi-node selection', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
        ParagraphNode(id: 'p2', text: AttributedText('World')),
      ]);
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p2', nodePosition: TextNodePosition(offset: 5)),
      );
      expect(isSelectionFullyAttributed(sel, NamedAttribution.bold, doc), isFalse);
    });

    test('returns false when node does not exist', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'missing', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'missing', nodePosition: TextNodePosition(offset: 3)),
      );
      expect(isSelectionFullyAttributed(sel, NamedAttribution.bold, doc), isFalse);
    });

    test('returns false when selection is not fully attributed', () {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      // No attributions — should return false.
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );
      expect(isSelectionFullyAttributed(sel, NamedAttribution.bold, doc), isFalse);
    });

    test('returns true when entire selection is attributed', () {
      final boldText = AttributedText(
        'Hello',
        const [
          SpanMarker(
            attribution: NamedAttribution.bold,
            offset: 0,
            markerType: SpanMarkerType.start,
          ),
          SpanMarker(
            attribution: NamedAttribution.bold,
            offset: 4,
            markerType: SpanMarkerType.end,
          ),
        ],
      );
      final doc = MutableDocument([ParagraphNode(id: 'p1', text: boldText)]);
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );
      expect(isSelectionFullyAttributed(sel, NamedAttribution.bold, doc), isTrue);
    });

    test('returns true with reversed base/extent', () {
      final boldText = AttributedText(
        'Hello',
        const [
          SpanMarker(
            attribution: NamedAttribution.bold,
            offset: 0,
            markerType: SpanMarkerType.start,
          ),
          SpanMarker(
            attribution: NamedAttribution.bold,
            offset: 4,
            markerType: SpanMarkerType.end,
          ),
        ],
      );
      final doc = MutableDocument([ParagraphNode(id: 'p1', text: boldText)]);
      // extent before base (reversed selection).
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
      );
      expect(isSelectionFullyAttributed(sel, NamedAttribution.bold, doc), isTrue);
    });
  });

  // =========================================================================
  // createDocumentEditingActions — verifies all actions are present
  // =========================================================================

  group('createDocumentEditingActions', () {
    test('returns a map containing all expected action types', () {
      // Minimal stub delegate — we only need the factory to run.
      final actions = createDocumentEditingActions(() => _NoOpDelegate());

      expect(actions.containsKey(ExtendSelectionByCharacterIntent), isTrue);
      expect(actions.containsKey(ExtendSelectionToNextWordBoundaryIntent), isTrue);
      expect(actions.containsKey(ExtendSelectionToLineBreakIntent), isTrue);
      expect(actions.containsKey(ExtendSelectionVerticallyToAdjacentLineIntent), isTrue);
      expect(actions.containsKey(ExtendSelectionToDocumentBoundaryIntent), isTrue);
      expect(actions.containsKey(ExtendSelectionToNextWordBoundaryOrCaretLocationIntent), isTrue);
      expect(actions.containsKey(DeleteCharacterIntent), isTrue);
      expect(actions.containsKey(DeleteToNextWordBoundaryIntent), isTrue);
      expect(actions.containsKey(DeleteToLineBreakIntent), isTrue);
      expect(actions.containsKey(ExtendSelectionVerticallyToAdjacentPageIntent), isTrue);
      expect(actions.containsKey(CopySelectionTextIntent), isTrue);
      expect(actions.containsKey(PasteTextIntent), isTrue);
      expect(actions.containsKey(SelectAllTextIntent), isTrue);
      expect(actions.containsKey(CollapseSelectionIntent), isTrue);
      expect(actions.containsKey(ToggleAttributionIntent), isTrue);
      expect(actions.containsKey(MoveToNodeBoundaryIntent), isTrue);
      expect(actions.containsKey(MoveToAdjacentTableCellIntent), isTrue);
      expect(actions.containsKey(DocumentTabIntent), isTrue);
      expect(actions.containsKey(DocumentShiftTabIntent), isTrue);
      expect(actions.containsKey(DocumentEnterIntent), isTrue);
      expect(actions.containsKey(DocumentShiftEnterIntent), isTrue);
      expect(actions.containsKey(IndentListItemIntent), isTrue);
      expect(actions.containsKey(UnindentListItemIntent), isTrue);
    });
  });

  // =========================================================================
  // Document-specific intents via key shortcuts
  // =========================================================================

  group('DocumentTabIntent via Tab key', () {
    testWidgets('Tab key fires DocumentTabIntent and calls handleTab', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 5),
      );
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await _pumpDocument(
        tester,
        controller: controller,
        focusNode: focusNode,
        editor: editor,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Tab should have inserted a tab character.
      expect((doc.nodeById('p1') as ParagraphNode).text.text, 'Hello\t');
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('DocumentEnterIntent via Enter key', () {});
}

// ---------------------------------------------------------------------------
// Stub delegate used by createDocumentEditingActions test
// ---------------------------------------------------------------------------

class _NoOpDelegate implements DocumentEditingDelegate {
  @override
  void moveByCharacter({required bool forward, required bool extend}) {}
  @override
  void moveByWord({required bool forward, required bool extend}) {}
  @override
  void moveToLineStartOrEnd({required bool forward, required bool extend}) {}
  @override
  void moveVertically({required bool forward, required bool extend}) {}
  @override
  void moveToDocumentStartOrEnd({required bool forward, required bool extend}) {}
  @override
  void moveToNodeStartOrEnd({required bool forward, required bool extend}) {}
  @override
  void moveByPage({required bool forward, required bool extend}) {}
  @override
  void moveHome({required bool extend}) {}
  @override
  void moveEnd({required bool extend}) {}
  @override
  void collapseSelection() {}
  @override
  void deleteForward() {}
  @override
  void deleteBackward() {}
  @override
  void handleTab() {}
  @override
  void handleShiftTab() {}
  @override
  void handleEnter() {}
  @override
  void handleShiftEnter() {}
  @override
  void copySelection() {}
  @override
  void cutSelection() {}
  @override
  void pasteClipboard() {}
  @override
  void selectAll() {}
  @override
  void toggleAttribution(Attribution attribution) {}
}
