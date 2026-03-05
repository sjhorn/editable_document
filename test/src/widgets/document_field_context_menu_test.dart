/// Tests for [DocumentField] context menu support.
///
/// Verifies that right-clicking shows a context menu with Cut/Copy/Paste/
/// Select All actions, that each action performs the correct document mutation,
/// and that the menu is dismissed at appropriate times.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Clipboard mock helpers (same pattern as document_clipboard_test.dart)
// ---------------------------------------------------------------------------

String? _clipboardData;

void _installClipboardMock(TestWidgetsFlutterBinding binding) {
  _clipboardData = null;
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
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

void _removeClipboardMock(TestWidgetsFlutterBinding binding) {
  binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
  _clipboardData = null;
}

// ---------------------------------------------------------------------------
// Widget helpers
// ---------------------------------------------------------------------------

/// Creates a [DocumentEditingController] with a single paragraph of [text].
DocumentEditingController _makeController({String text = 'Hello world'}) {
  return DocumentEditingController(
    document: MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText(text)),
    ]),
  );
}

/// Wraps [child] in [MaterialApp] + [Scaffold] for a full widget environment.
Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Simulates a right-click (secondary tap) at [position].
Future<void> _rightClick(WidgetTester tester, Offset position) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await gesture.addPointer(location: position);
  addTearDown(gesture.removePointer);
  await gesture.down(position);
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Returns the plain text of all [TextNode]s in [document] concatenated.
String _documentText(Document doc) {
  final buf = StringBuffer();
  for (final node in doc.nodes) {
    if (node is TextNode) buf.write(node.text.text);
  }
  return buf.toString();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // right-click shows context menu
  // -------------------------------------------------------------------------

  group('DocumentField context menu — visibility', () {
    testWidgets('right-click shows AdaptiveTextSelectionToolbar', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    });

    testWidgets('Select All button always visible on right-click', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      expect(find.text('Select All'), findsOneWidget);
    });

    testWidgets('Paste button visible when field is writable', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      expect(find.text('Paste'), findsOneWidget);
    });

    testWidgets('Cut button hidden when selection is collapsed', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      expect(find.text('Cut'), findsNothing);
    });

    testWidgets('Copy button hidden when selection is collapsed', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('Cut and Copy buttons visible when expanded selection exists', (tester) async {
      final controller = _makeController(text: 'Hello world');
      addTearDown(controller.dispose);

      // Pre-set an expanded selection so right-clicking in the selection area
      // preserves it.
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      // Right-click inside the existing selection (center of field should
      // be within the selected area for a short text rendered at the start).
      // We use the field's top-left area to stay in the selection.
      final fieldRect = tester.getRect(find.byType(DocumentField));
      // Use a position near the start of the text.
      final tapPos = fieldRect.topLeft + const Offset(20, 20);
      await _rightClick(tester, tapPos);

      expect(find.text('Cut'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('Cut button hidden in readOnly mode', (tester) async {
      final controller = _makeController(text: 'Hello world');
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller, readOnly: true)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      expect(find.text('Cut'), findsNothing);
    });

    testWidgets('Paste button hidden when field is readOnly', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller, readOnly: true)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      expect(find.text('Paste'), findsNothing);
    });

    testWidgets('Cut and Paste buttons hidden when field is disabled', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller, enabled: false)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      // Disabled fields should not show a context menu at all.
      await _rightClick(tester, center);

      // The menu should not appear when disabled (onSecondaryTapDown is null).
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Select All
  // -------------------------------------------------------------------------

  group('DocumentField context menu — Select All', () {
    testWidgets('Select All selects the entire document', (tester) async {
      final controller = _makeController(text: 'Hello world');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      await tester.tap(find.text('Select All'));
      await tester.pump();

      final sel = controller.selection;
      expect(sel, isNotNull);
      expect(sel!.isExpanded, isTrue);
      expect(sel.base.nodeId, 'p1');
      expect(sel.extent.nodeId, 'p1');
      expect((sel.base.nodePosition as TextNodePosition).offset, 0);
      expect((sel.extent.nodePosition as TextNodePosition).offset, 11);
    });

    testWidgets('Select All on multi-node document spans all nodes', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('First')),
        ParagraphNode(id: 'p2', text: AttributedText('Second')),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      await tester.tap(find.text('Select All'));
      await tester.pump();

      final sel = controller.selection;
      expect(sel, isNotNull);
      expect(sel!.base.nodeId, 'p1');
      expect(sel.extent.nodeId, 'p2');
    });

    testWidgets('menu is dismissed after tapping Select All', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);

      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();

      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Copy
  // -------------------------------------------------------------------------

  group('DocumentField context menu — Copy', () {
    testWidgets('Copy places selected text on clipboard', (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      _installClipboardMock(binding);
      addTearDown(() => _removeClipboardMock(binding));

      final controller = _makeController(text: 'Hello world');
      addTearDown(controller.dispose);

      // Pre-set expanded selection: "Hello".
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      // Right-click inside the selection to preserve it.
      final fieldRect = tester.getRect(find.byType(DocumentField));
      final tapPos = fieldRect.topLeft + const Offset(20, 20);
      await _rightClick(tester, tapPos);

      await tester.tap(find.text('Copy'));
      await tester.pump();
      // Wait for the async clipboard write.
      await tester.pumpAndSettle();

      expect(_clipboardData, 'Hello');
    });

    testWidgets('Copy does not modify the document', (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      _installClipboardMock(binding);
      addTearDown(() => _removeClipboardMock(binding));

      final controller = _makeController(text: 'Hello world');
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final fieldRect = tester.getRect(find.byType(DocumentField));
      final tapPos = fieldRect.topLeft + const Offset(20, 20);
      await _rightClick(tester, tapPos);

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(_documentText(controller.document), 'Hello world');
    });
  });

  // -------------------------------------------------------------------------
  // Cut
  // -------------------------------------------------------------------------

  group('DocumentField context menu — Cut', () {
    testWidgets('Cut places selected text on clipboard', (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      _installClipboardMock(binding);
      addTearDown(() => _removeClipboardMock(binding));

      final controller = _makeController(text: 'Hello world');
      addTearDown(controller.dispose);

      // Pre-set expanded selection: "Hello".
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final fieldRect = tester.getRect(find.byType(DocumentField));
      final tapPos = fieldRect.topLeft + const Offset(20, 20);
      await _rightClick(tester, tapPos);

      await tester.tap(find.text('Cut'));
      await tester.pumpAndSettle();

      expect(_clipboardData, 'Hello');
    });

    testWidgets('Cut removes selected text from document', (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      _installClipboardMock(binding);
      addTearDown(() => _removeClipboardMock(binding));

      final controller = _makeController(text: 'Hello world');
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
        ),
      );

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final fieldRect = tester.getRect(find.byType(DocumentField));
      final tapPos = fieldRect.topLeft + const Offset(20, 20);
      await _rightClick(tester, tapPos);

      await tester.tap(find.text('Cut'));
      await tester.pumpAndSettle();

      expect(_documentText(controller.document), ' world');
    });
  });

  // -------------------------------------------------------------------------
  // Paste
  // -------------------------------------------------------------------------

  group('DocumentField context menu — Paste', () {
    testWidgets('Paste inserts clipboard text at the right-click position', (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      _installClipboardMock(binding);
      addTearDown(() => _removeClipboardMock(binding));

      // Pre-populate clipboard.
      _clipboardData = 'Pasted';

      final controller = _makeController(text: 'Hello');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      // Right-click at the center of the field — the secondary tap will place
      // the caret there and then paste inserts the clipboard text.
      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      // The clipboard text should appear somewhere inside the document text.
      final docText = _documentText(controller.document);
      expect(docText.contains('Pasted'), isTrue);
      // Total length should be original + pasted.
      expect(docText.length, 'Hello'.length + 'Pasted'.length);
    });

    testWidgets('menu is dismissed after tapping Paste', (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      _installClipboardMock(binding);
      addTearDown(() => _removeClipboardMock(binding));

      _clipboardData = 'Pasted';

      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(DocumentField(controller: controller)),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);

      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Menu dismissal
  // -------------------------------------------------------------------------

  group('DocumentField context menu — dismissal', () {
    testWidgets('menu dismissed when focus is lost', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              DocumentField(controller: controller, focusNode: focusNode),
              const TextField(),
            ],
          ),
        ),
      );

      final fieldCenter = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, fieldCenter);

      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);

      // Steal focus away. The context menu overlay may be covering the
      // TextField hit region, so suppress the miss warning.
      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Custom contextMenuBuilder
  // -------------------------------------------------------------------------

  group('DocumentField context menu — custom builder', () {
    testWidgets('custom contextMenuBuilder is used when provided', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      bool builderCalled = false;

      await tester.pumpWidget(
        _wrap(
          DocumentField(
            controller: controller,
            contextMenuBuilder: (context, anchor) {
              builderCalled = true;
              return Material(
                child: Container(
                  key: const Key('custom_menu'),
                  width: 100,
                  height: 40,
                  color: Colors.red,
                  child: const Text('Custom Menu'),
                ),
              );
            },
          ),
        ),
      );

      final center = tester.getCenter(find.byType(DocumentField));
      await _rightClick(tester, center);

      expect(builderCalled, isTrue);
      expect(find.byKey(const Key('custom_menu')), findsOneWidget);
      expect(find.text('Custom Menu'), findsOneWidget);
      // Default toolbar should NOT appear.
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    });
  });
}
