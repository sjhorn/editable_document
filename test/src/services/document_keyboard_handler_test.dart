/// Tests for [DocumentKeyboardHandler].
///
/// Each test group covers a key or modifier combination handled by the
/// keyboard handler. Pattern:
///
/// 1. Build a minimal [MutableDocument] + [DocumentEditingController].
/// 2. Collect dispatched [EditRequest]s via a local list.
/// 3. Invoke [DocumentKeyboardHandler.onKeyEvent] with a simulated key.
/// 4. Assert the controller selection and/or collected requests.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

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

/// Creates a [DocumentKeyboardHandler] backed by [doc] + [controller],
/// collecting dispatched requests into [requests].
DocumentKeyboardHandler _makeHandler(
  MutableDocument doc,
  DocumentEditingController controller,
  List<EditRequest> requests,
) {
  return DocumentKeyboardHandler(
    document: doc,
    controller: controller,
    requestHandler: requests.add,
  );
}

/// Synthesises a [KeyDownEvent] for [logicalKey].
KeyDownEvent _keyDown(LogicalKeyboardKey logicalKey) {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: logicalKey,
    timeStamp: Duration.zero,
  );
}

/// Synthesises a [KeyRepeatEvent] for [logicalKey].
KeyRepeatEvent _keyRepeat(LogicalKeyboardKey logicalKey) {
  return KeyRepeatEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: logicalKey,
    timeStamp: Duration.zero,
  );
}

/// Synthesises a [KeyUpEvent] for [logicalKey].
KeyUpEvent _keyUp(LogicalKeyboardKey logicalKey) {
  return KeyUpEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: logicalKey,
    timeStamp: Duration.zero,
  );
}

/// Returns a minimal widget tree that attaches [handler] to a focused
/// [Focus] node. Used in [testWidgets] modifier-key tests.
Widget _testScaffold(DocumentKeyboardHandler handler) {
  return _FocusedHandlerWidget(handler: handler);
}

// ---------------------------------------------------------------------------
// Small widget that owns a focused FocusNode wired to the handler.
// ---------------------------------------------------------------------------

class _FocusedHandlerWidget extends StatefulWidget {
  const _FocusedHandlerWidget({required this.handler});

  final DocumentKeyboardHandler handler;

  @override
  State<_FocusedHandlerWidget> createState() => _FocusedHandlerWidgetState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DocumentKeyboardHandler>('handler', handler));
  }
}

class _FocusedHandlerWidgetState extends State<_FocusedHandlerWidget> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (node, event) =>
          widget.handler.onKeyEvent(event) ? KeyEventResult.handled : KeyEventResult.ignored,
      child: const SizedBox.expand(),
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  // =========================================================================
  // KeyUpEvent is always ignored
  // =========================================================================

  group('KeyUpEvent', () {
    test('is always ignored regardless of key', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: _collapsed('p1', 3),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyUp(LogicalKeyboardKey.arrowLeft));

      expect(result, false);
      expect(requests, isEmpty);
      expect(controller.selection, _collapsed('p1', 3));
    });
  });

  // =========================================================================
  // No selection — most keys return ignored
  // =========================================================================

  group('no selection', () {
    test('arrow left with null selection returns ignored', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowLeft)),
        false,
      );
    });

    test('arrow right with null selection returns ignored', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowRight)),
        false,
      );
    });

    test('arrow up with null selection returns ignored', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowUp)),
        false,
      );
    });

    test('arrow down with null selection returns ignored', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowDown)),
        false,
      );
    });

    test('home with null selection returns ignored', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.home)),
        false,
      );
    });

    test('end with null selection returns ignored', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.end)),
        false,
      );
    });

    test('escape with null selection returns ignored', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.escape)),
        false,
      );
    });

    test('delete with null selection returns ignored', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.delete)),
        false,
      );
    });

    test('backspace with null selection returns ignored', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.backspace)),
        false,
      );
    });

    test('tab with null selection returns ignored', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.tab)),
        false,
      );
    });
  });

  // =========================================================================
  // Escape
  // =========================================================================

  group('Escape', () {
    test('collapses expanded selection to the extent', () {
      final doc = _singleParagraph('Hello world');
      final expandedSel = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );
      final controller = DocumentEditingController(document: doc, selection: expandedSel);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.escape));

      expect(result, true);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
    });

    test('returns ignored when selection is already collapsed', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.escape));

      expect(result, false);
      expect(controller.selection, _collapsed('p1', 3));
    });
  });

  // =========================================================================
  // Arrow Left — character navigation
  // =========================================================================

  group('ArrowLeft (character)', () {
    test('moves caret one character left', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowLeft));

      expect(result, true);
      expect(controller.selection, _collapsed('p1', 2));
    });

    test('wraps to end of previous node at offset 0', () {
      final doc = _twoParagraphs(firstText: 'Hi', secondText: 'There');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowLeft));

      expect(result, true);
      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(2),
      );
    });

    test('stays at offset 0 when there is no previous node', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowLeft));

      expect(result, true);
      expect(controller.selection, _collapsed('p1', 0));
    });

    test('collapses expanded selection to upstream end', () {
      final doc = _singleParagraph('Hello world');
      final expandedSel = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );
      final controller = DocumentEditingController(document: doc, selection: expandedSel);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowLeft));

      expect(result, true);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
    });

    test('KeyRepeatEvent also moves caret', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyRepeat(LogicalKeyboardKey.arrowLeft));

      expect(result, true);
      expect(controller.selection, _collapsed('p1', 2));
    });
  });

  // =========================================================================
  // Arrow Right — character navigation
  // =========================================================================

  group('ArrowRight (character)', () {
    test('moves caret one character right', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowRight));

      expect(result, true);
      expect(controller.selection, _collapsed('p1', 3));
    });

    test('wraps to start of next node at end of text', () {
      final doc = _twoParagraphs(firstText: 'Hi', secondText: 'There');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowRight));

      expect(result, true);
      expect(controller.selection!.extent.nodeId, equals('p2'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
    });

    test('stays at end when there is no next node', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 5));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowRight));

      expect(result, true);
      expect(controller.selection, _collapsed('p1', 5));
    });

    test('collapses expanded selection to downstream end', () {
      final doc = _singleParagraph('Hello world');
      final expandedSel = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );
      final controller = DocumentEditingController(document: doc, selection: expandedSel);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowRight));

      expect(result, true);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
    });

    test('returns ignored for ArrowRight when extent node not found', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'nonexistent',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowRight)),
        false,
      );
    });
  });

  group('ArrowLeft (node not found)', () {
    test('returns ignored for ArrowLeft when extent node not found', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'nonexistent',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowLeft)),
        false,
      );
    });
  });

  group('ArrowUp/Down (node not found)', () {
    test('returns ignored for ArrowUp when extent node not found', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'nonexistent',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowUp)),
        false,
      );
    });

    test('returns ignored for ArrowDown when extent node not found', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'nonexistent',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowDown)),
        false,
      );
    });
  });

  // =========================================================================
  // Arrow Up — block navigation
  // =========================================================================

  group('ArrowUp (block)', () {
    test('moves to start of previous node', () {
      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowUp));

      expect(result, true);
      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
    });

    test('moves to start of current node when already at first node', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowUp));

      expect(result, true);
      expect(controller.selection, _collapsed('p1', 0));
    });
  });

  // =========================================================================
  // Arrow Down — block navigation
  // =========================================================================

  group('ArrowDown (block)', () {
    test('moves to start of next node', () {
      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowDown));

      expect(result, true);
      expect(controller.selection!.extent.nodeId, equals('p2'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
    });

    test('moves to end of current node when already at last node', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowDown));

      expect(result, true);
      expect(controller.selection, _collapsed('p1', 5));
    });
  });

  // =========================================================================
  // Home / End
  // =========================================================================

  group('Home', () {
    test('moves to start of current node', () {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 6));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.home));

      expect(result, true);
      expect(controller.selection, _collapsed('p1', 0));
    });

    test('returns ignored when node not found', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'nonexistent',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.home));

      expect(result, false);
    });

    test('returns ignored when document is empty (Ctrl+Home)', () {
      // We cannot truly test Ctrl+Home without a real binding, but we can
      // verify the empty-document guard by using a ghost node ID with an
      // empty document — the primaryModifier branch hits nodes.isEmpty.
      // This is covered more completely in the Ctrl/Cmd+Home testWidgets group.
      final doc = MutableDocument();
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'ghost',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      // Without Ctrl pressed the non-primaryModifier path runs.
      // The node 'ghost' doesn't exist so nodeById returns null → ignored.
      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.home));
      expect(result, false);
    });

    test('returns ignored for end key when node not found', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'nonexistent',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.end));

      expect(result, false);
    });
  });

  group('End', () {
    test('moves to end of current node', () {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.end));

      expect(result, true);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(11),
      );
    });
  });

  // =========================================================================
  // Delete (forward)
  // =========================================================================

  group('Delete (forward)', () {
    test('dispatches DeleteContentRequest for one character forward', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.delete));

      expect(result, true);
      expect(requests, hasLength(1));
      final req = requests.first as DeleteContentRequest;
      expect(
        (req.selection.base.nodePosition as TextNodePosition).offset,
        equals(2),
      );
      expect(
        (req.selection.extent.nodePosition as TextNodePosition).offset,
        equals(3),
      );
    });

    test('dispatches DeleteContentRequest for expanded selection', () {
      final doc = _singleParagraph('Hello world');
      final expandedSel = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );
      final controller = DocumentEditingController(document: doc, selection: expandedSel);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.delete));

      expect(result, true);
      expect(requests, hasLength(1));
      expect(requests.first, isA<DeleteContentRequest>());
    });

    test('dispatches MergeNodeRequest when at end of text node', () {
      final doc = _twoParagraphs(firstText: 'Hi', secondText: 'There');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.delete));

      expect(result, true);
      expect(requests, hasLength(1));
      final req = requests.first as MergeNodeRequest;
      expect(req.firstNodeId, equals('p1'));
      expect(req.secondNodeId, equals('p2'));
    });

    test('returns ignored when at end of last node with no next node', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 5));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.delete));

      expect(result, false);
      expect(requests, isEmpty);
    });

    test('dispatches DeleteContentRequest for non-text node', () {
      final doc = MutableDocument([HorizontalRuleNode(id: 'hr1')]);
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.delete));

      expect(result, true);
      expect(requests, hasLength(1));
      expect(requests.first, isA<DeleteContentRequest>());
    });

    test('returns ignored when node is not found', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'nonexistent',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.delete));

      expect(result, false);
      expect(requests, isEmpty);
    });
  });

  // =========================================================================
  // Backspace (fallback)
  // =========================================================================

  group('Backspace (fallback)', () {
    test('dispatches DeleteContentRequest for one character backward', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.backspace));

      expect(result, true);
      expect(requests, hasLength(1));
      final req = requests.first as DeleteContentRequest;
      expect(
        (req.selection.base.nodePosition as TextNodePosition).offset,
        equals(2),
      );
      expect(
        (req.selection.extent.nodePosition as TextNodePosition).offset,
        equals(3),
      );
    });

    test('dispatches DeleteContentRequest for expanded selection', () {
      final doc = _singleParagraph('Hello world');
      final expandedSel = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );
      final controller = DocumentEditingController(document: doc, selection: expandedSel);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.backspace));

      expect(result, true);
      expect(requests, hasLength(1));
      expect(requests.first, isA<DeleteContentRequest>());
    });

    test('dispatches MergeNodeRequest when at start of text node', () {
      final doc = _twoParagraphs(firstText: 'Hi', secondText: 'There');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.backspace));

      expect(result, true);
      expect(requests, hasLength(1));
      final req = requests.first as MergeNodeRequest;
      expect(req.firstNodeId, equals('p1'));
      expect(req.secondNodeId, equals('p2'));
    });

    test('returns ignored at start of first node', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.backspace));

      expect(result, false);
      expect(requests, isEmpty);
    });

    test('dispatches DeleteContentRequest for non-text node', () {
      final doc = MutableDocument([HorizontalRuleNode(id: 'hr1')]);
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.backspace));

      expect(result, true);
      expect(requests, hasLength(1));
      expect(requests.first, isA<DeleteContentRequest>());
    });

    test('returns ignored when node is not found', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'nonexistent',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.backspace));

      expect(result, false);
      expect(requests, isEmpty);
    });
  });

  // =========================================================================
  // Tab — list item indent
  // =========================================================================

  group('Tab', () {
    test('dispatches IndentListItemRequest when cursor is in a ListItemNode', () {
      final doc = MutableDocument([
        ListItemNode(id: 'li1', text: AttributedText('Item one')),
      ]);
      final controller = DocumentEditingController(document: doc, selection: _collapsed('li1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.tab));

      expect(result, true);
      expect(requests, hasLength(1));
      final req = requests.first as IndentListItemRequest;
      expect(req.nodeId, equals('li1'));
    });

    test('returns ignored when cursor is NOT in a ListItemNode', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.tab));

      expect(result, false);
      expect(requests, isEmpty);
    });

    test('returns ignored when selection is null', () {
      final doc = MutableDocument([
        ListItemNode(id: 'li1', text: AttributedText('Item one')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.tab));

      expect(result, false);
    });
  });

  // =========================================================================
  // Shift+Tab — list item unindent (widget tests for real Shift state)
  // =========================================================================

  group('Shift+Tab', () {
    testWidgets('dispatches UnindentListItemRequest when cursor is in a ListItemNode',
        (tester) async {
      final doc = MutableDocument([
        ListItemNode(id: 'li1', text: AttributedText('Item one')),
      ]);
      final controller = DocumentEditingController(document: doc, selection: _collapsed('li1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(requests, hasLength(1));
      final req = requests.first as UnindentListItemRequest;
      expect(req.nodeId, equals('li1'));
    });

    testWidgets('returns ignored for non-list-item', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(requests, isEmpty);
    });

    testWidgets('returns ignored when selection is null', (tester) async {
      final doc = MutableDocument([
        ListItemNode(id: 'li1', text: AttributedText('Item one')),
      ]);
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(requests, isEmpty);
    });
  });

  // =========================================================================
  // Unknown keys
  // =========================================================================

  group('Unknown keys', () {
    test('returns ignored for letter keys (handled by IME)', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final event = const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      );

      expect(handler.onKeyEvent(event), false);
      expect(requests, isEmpty);
    });

    test('returns ignored for F1', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.f1)),
        false,
      );
    });

    test('returns ignored for Enter (handled by IME)', () {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      expect(
        handler.onKeyEvent(_keyDown(LogicalKeyboardKey.enter)),
        false,
      );
    });
  });

  // =========================================================================
  // Shift + Arrow — extend selection (widget tests for real Shift state)
  // =========================================================================

  group('Shift+Arrow extends selection', () {
    testWidgets('Shift+ArrowRight extends selection one character right', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(controller.selection!.base.nodeId, equals('p1'));
      expect(
        (controller.selection!.base.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(1),
      );
    });

    testWidgets('Shift+ArrowLeft extends selection one character left', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 5));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(4),
      );
    });

    testWidgets('Shift+ArrowDown extends selection to next block', (tester) async {
      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(controller.selection!.base.nodeId, equals('p1'));
      expect(controller.selection!.extent.nodeId, equals('p2'));
    });

    testWidgets('Shift+ArrowUp extends selection to previous block', (tester) async {
      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(controller.selection!.base.nodeId, equals('p2'));
      expect(controller.selection!.extent.nodeId, equals('p1'));
    });
  });

  // =========================================================================
  // Ctrl/Cmd + Arrow — word navigation (word modifier)
  // =========================================================================

  group('Word modifier + Arrow (Ctrl on Linux/Windows, Option/Alt on macOS)', () {
    testWidgets('Ctrl+ArrowRight moves to word end on Linux', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // From offset 0: skip no whitespace, skip 'Hello' → offset 5.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+ArrowLeft moves to word start on Linux', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 11));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // From offset 11: skip no whitespace, skip 'world' → offset 6.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(6),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Option+ArrowRight moves to word end on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      // From offset 0: skip 'Hello' → offset 5.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Option+ArrowLeft moves to word start on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 11));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      // From offset 11: skip 'world' → offset 6.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(6),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Option+ArrowRight extends selection to word end on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.base.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Option+ArrowLeft extends selection to word start on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 11));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(6),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+ArrowUp moves to node start on Linux (word modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Word modifier + Up → start of current node (p2).
      expect(controller.selection!.extent.nodeId, equals('p2'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+ArrowDown moves to node end on Linux (word modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Word modifier + Down → end of current node (p1 = 'Hello' → offset 5).
      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+ArrowUp stays at node start when already at node start on Linux',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Word modifier + Up on p1,3 → node start of p1 → offset 0.
      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+ArrowDown stays at node end when already last node on Linux', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Word modifier + Down → end of current node → offset 5.
      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Option+ArrowUp moves to node start on macOS (word modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      // Option+Up → start of current node (p2).
      expect(controller.selection!.extent.nodeId, equals('p2'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Option+ArrowDown moves to node end on macOS (word modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      // Option+Down → end of current node (p1 = 'Hello' → offset 5).
      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // =========================================================================
  // Line modifier + Arrow — line/document navigation
  // (Cmd/Meta on macOS/iOS, Alt on Linux/Windows)
  // =========================================================================

  group('Line modifier + Arrow (Cmd on macOS, Alt on Linux/Windows)', () {
    testWidgets('Cmd+ArrowRight moves to node end on macOS (line modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      // Cmd+Right → node end (line end) → offset 11 ('Hello world'.length).
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(11),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Cmd+ArrowLeft moves to node start on macOS (line modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 11));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      // Cmd+Left → node start (line start) → offset 0.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Cmd+ArrowRight extends selection to node end on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.base.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(11),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Cmd+ArrowLeft extends selection to node start on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 11));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Cmd+ArrowUp moves to document start on macOS (line modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      // Cmd+Up → document start → p1, offset 0.
      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Cmd+ArrowDown moves to document end on macOS (line modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      // Cmd+Down → document end → p2, offset 5 ('World'.length).
      expect(controller.selection!.extent.nodeId, equals('p2'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Cmd+ArrowUp extends selection to document start on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(controller.selection!.base.nodeId, equals('p2'));
      expect(controller.selection!.extent.nodeId, equals('p1'));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Cmd+ArrowDown extends selection to document end on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(controller.selection!.base.nodeId, equals('p1'));
      expect(controller.selection!.extent.nodeId, equals('p2'));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Alt+ArrowRight moves to node end on Linux (line modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      // Alt+Right on Linux → node end (line end) → offset 11.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(11),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Alt+ArrowLeft moves to node start on Linux (line modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 11));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      // Alt+Left on Linux → node start (line start) → offset 0.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Alt+ArrowUp moves to document start on Linux (line modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      // Alt+Up on Linux → document start → p1, offset 0.
      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Alt+ArrowDown moves to document end on Linux (line modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      // Alt+Down on Linux → document end → p2, offset 5 ('World'.length).
      expect(controller.selection!.extent.nodeId, equals('p2'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Alt+ArrowRight on Windows moves to node end (line modifier)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      // Alt+Right on Windows → node end → offset 11.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(11),
      );
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // =========================================================================
  // macOS Emacs bindings (Ctrl+A/E/F/B/N/P)
  // =========================================================================

  group('macOS Emacs bindings (Ctrl+A/E/F/B/N/P)', () {
    testWidgets('Ctrl+A moves to node start on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 6));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+E moves to node end on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(11),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+F moves one character right on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(3),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+B moves one character left on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(2),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+N moves to next block on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(controller.selection!.extent.nodeId, equals('p2'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+P moves to previous block on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Ctrl+A extends selection to node start on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 6));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.base.nodePosition as TextNodePosition).offset,
        equals(6),
      );
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Ctrl+E extends selection to node end on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(11),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Ctrl+F extends selection one character right on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(3),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Ctrl+B extends selection one character left on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(2),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Ctrl+N extends selection to next block on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(controller.selection!.base.nodeId, equals('p1'));
      expect(controller.selection!.extent.nodeId, equals('p2'));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Shift+Ctrl+P extends selection to previous block on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(controller.selection!.isExpanded, isTrue);
      expect(controller.selection!.base.nodeId, equals('p2'));
      expect(controller.selection!.extent.nodeId, equals('p1'));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Emacs bindings do NOT fire on Linux (Ctrl+A on Linux is not Emacs)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 6));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // On Linux, Ctrl+A is not an Emacs binding → no navigation → selection unchanged.
      expect(controller.selection, _collapsed('p1', 6));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+N at last block on macOS stays at document end (Emacs)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 2));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Ctrl+N on last block → end of last node.
      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+P at first block on macOS stays at document start (Emacs)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Ctrl+P on first block → start of first node.
      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+A with null selection returns ignored on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(controller.selection, isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // =========================================================================
  // Ctrl/Cmd + Home/End — document start/end
  // =========================================================================

  group('Ctrl/Cmd + Home/End', () {
    testWidgets('Ctrl+Home moves to very start of document on Linux', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p2', 3));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.home);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.home);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(controller.selection!.extent.nodeId, equals('p1'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(0),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+End moves to very end of document on Linux', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _twoParagraphs(firstText: 'Hello', secondText: 'World');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.end);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.end);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(controller.selection!.extent.nodeId, equals('p2'));
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+Home on empty document returns ignored on Linux', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = MutableDocument();
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'ghost',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.home);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.home);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Should not throw and should not change selection.
      expect(requests, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+End on empty document returns ignored on Linux', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = MutableDocument();
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'ghost',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.end);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.end);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(requests, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // =========================================================================
  // Platform modifier detection
  // =========================================================================

  group('Platform modifier detection', () {
    testWidgets('macOS: Ctrl+Right triggers Emacs char-forward (not word nav, not line nav)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Ctrl+ArrowRight on macOS: Ctrl is neither word nor line modifier.
      // Falls through to plain char-right → offset 1.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(1),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('macOS: Option is word modifier — Alt+Right moves to word end', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      // Alt (Option) is the word modifier on macOS → word end → offset 5.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('macOS: Cmd is line modifier — Meta+Right moves to line end', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      // Meta (Cmd) is the line modifier on macOS → node/line end → offset 11.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(11),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Linux: Ctrl is word modifier — Ctrl+Right moves to word end', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Ctrl is the word modifier on Linux → word end → offset 5.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Linux: Alt is line modifier — Alt+Right moves to line end', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      // Alt is the line modifier on Linux → node/line end → offset 11.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(11),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Linux: Meta+Right does NOT trigger word or line nav', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      // Meta is neither word nor line modifier on Linux → char move only → offset 1.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(1),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Windows: Ctrl is word modifier — Ctrl+Right moves to word end', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Ctrl is the word modifier on Windows → word end → offset 5 ('Hello').
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android: Ctrl is word modifier — Ctrl+Right moves to word end', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc, selection: _collapsed('p1', 0));
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Ctrl is the word modifier on Android → word end → offset 5.
      expect(
        (controller.selection!.extent.nodePosition as TextNodePosition).offset,
        equals(5),
      );
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // =========================================================================
  // Word navigation — non-text node edge cases
  // =========================================================================

  group('Word navigation non-text node edge cases', () {
    test('_moveToWordStart on non-TextNode returns start of node', () {
      final doc = MutableDocument([HorizontalRuleNode(id: 'hr1')]);
      // We test this path indirectly: ArrowLeft with ctrl-equivalent pressed.
      // Since we cannot press ctrl in a pure unit test, we rely on coverage
      // from the widget-test group above. Here we verify ArrowLeft without
      // modifier on a non-text node still works gracefully.
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      // For a non-text node the character-left path falls through to `return pos`.
      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowLeft));
      expect(result, true);
    });

    test('_moveToWordEnd on non-TextNode returns end of node (via widget test)', () {
      // Non-text node ArrowRight falls through gracefully.
      final doc = MutableDocument([HorizontalRuleNode(id: 'hr1')]);
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      final result = handler.onKeyEvent(_keyDown(LogicalKeyboardKey.arrowRight));
      expect(result, true);
    });

    testWidgets('Ctrl+ArrowRight on non-text node moves to downstream end (Linux)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = MutableDocument([HorizontalRuleNode(id: 'hr1')]);
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // _moveToWordEnd on non-TextNode returns _endOfNode → downstream.
      expect(controller.selection!.extent.nodeId, equals('hr1'));
      expect(
        (controller.selection!.extent.nodePosition as BinaryNodePosition).type,
        equals(BinaryNodePositionType.downstream),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+ArrowLeft on non-text node moves to upstream start (Linux)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final doc = MutableDocument([HorizontalRuleNode(id: 'hr1')]);
      final controller = DocumentEditingController(
        document: doc,
        selection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: BinaryNodePosition.downstream(),
          ),
        ),
      );
      final requests = <EditRequest>[];
      final handler = _makeHandler(doc, controller, requests);

      await tester.pumpWidget(_testScaffold(handler));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // _moveToWordStart on non-TextNode returns _startOfNode → upstream.
      expect(controller.selection!.extent.nodeId, equals('hr1'));
      expect(
        (controller.selection!.extent.nodePosition as BinaryNodePosition).type,
        equals(BinaryNodePositionType.upstream),
      );
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
