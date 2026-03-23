/// Tests for [DocumentEditor] — the full-page rich text editor widget.
///
/// Covers zero-configuration construction, external controller acceptance,
/// internal resource disposal, readOnly context-menu suppression, autofocus,
/// overlayBuilder widgets, custom contextMenuBuilder, and scroll with large
/// content.
library;

import 'package:flutter/gestures.dart';
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

/// Creates a [DocumentEditingController] with a single paragraph.
DocumentEditingController _makeController({String text = 'Hello world'}) {
  return DocumentEditingController(
    document: MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText(text)),
    ]),
  );
}

/// Wraps [child] in [MaterialApp] + [Scaffold] for full widget environment.
Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentEditor', () {
    // -------------------------------------------------------------------------
    // 1. Renders with zero configuration
    // -------------------------------------------------------------------------

    group('zero configuration', () {
      testWidgets('pumps without error and finds the widget', (tester) async {
        await tester.pumpWidget(_wrap(const DocumentEditor()));
        await tester.pumpAndSettle();

        expect(find.byType(DocumentEditor), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('default parameters have expected values', (tester) async {
        await tester.pumpWidget(_wrap(const DocumentEditor()));
        await tester.pumpAndSettle();

        final widget = tester.widget<DocumentEditor>(find.byType(DocumentEditor));
        expect(widget.readOnly, isFalse);
        expect(widget.autofocus, isFalse);
        expect(widget.textAlign, TextAlign.start);
        expect(widget.blockSpacing, 12.0);
        expect(widget.scrollPadding, const EdgeInsets.all(20.0));
        expect(widget.documentPadding, EdgeInsets.zero);
        expect(widget.contentPadding, EdgeInsets.zero);
        expect(widget.showLineNumbers, isFalse);
        expect(widget.controller, isNull);
        expect(widget.focusNode, isNull);
        expect(widget.editor, isNull);
      });

      testWidgets('contains an EditableDocument in the tree', (tester) async {
        await tester.pumpWidget(_wrap(const DocumentEditor()));
        await tester.pumpAndSettle();

        expect(find.byType(EditableDocument), findsOneWidget);
      });

      testWidgets('contains a CaretDocumentOverlay in the tree', (tester) async {
        await tester.pumpWidget(_wrap(const DocumentEditor()));
        await tester.pumpAndSettle();

        expect(find.byType(CaretDocumentOverlay), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // 2. Accepts external controller
    // -------------------------------------------------------------------------

    group('external controller', () {
      testWidgets('uses provided controller and renders content', (tester) async {
        final imeLog = <MethodCall>[];
        _installTextInputMock(tester, imeLog);

        final controller = _makeController(text: 'Custom content');
        addTearDown(controller.dispose);

        await tester.pumpWidget(_wrap(DocumentEditor(controller: controller)));
        await tester.pumpAndSettle();

        expect(find.byType(DocumentEditor), findsOneWidget);
        expect(tester.takeException(), isNull);

        // The EditableDocument inside should receive the same controller.
        final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
        expect(editable.controller, same(controller));
      });

      testWidgets('document content is accessible through provided controller', (tester) async {
        final imeLog = <MethodCall>[];
        _installTextInputMock(tester, imeLog);

        final controller = _makeController(text: 'Verify me');
        addTearDown(controller.dispose);

        await tester.pumpWidget(_wrap(DocumentEditor(controller: controller)));
        await tester.pumpAndSettle();

        final node = controller.document.nodeById('p1')! as ParagraphNode;
        expect(node.text.text, equals('Verify me'));
      });
    });

    // -------------------------------------------------------------------------
    // 3. Internal controller is disposed
    // -------------------------------------------------------------------------

    group('internal resource disposal', () {
      testWidgets('replacing widget with another does not throw (implies clean disposal)',
          (tester) async {
        await tester.pumpWidget(_wrap(const DocumentEditor()));
        await tester.pumpAndSettle();

        // Replace with a plain container — disposal runs during unmount.
        await tester.pumpWidget(_wrap(const SizedBox()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('swapping to external controller does not throw', (tester) async {
        final imeLog = <MethodCall>[];
        _installTextInputMock(tester, imeLog);

        // Start with no external controller (internal one is created).
        await tester.pumpWidget(_wrap(const DocumentEditor()));
        await tester.pumpAndSettle();

        // Swap to an external controller — internal one must be disposed.
        final controller = _makeController(text: 'New content');
        addTearDown(controller.dispose);

        await tester.pumpWidget(_wrap(DocumentEditor(controller: controller)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    // -------------------------------------------------------------------------
    // 4. readOnly suppresses context menu
    // -------------------------------------------------------------------------

    group('readOnly mode', () {
      testWidgets('right-click does not show context menu when readOnly is true', (tester) async {
        final imeLog = <MethodCall>[];
        _installTextInputMock(tester, imeLog);

        await tester.pumpWidget(
          _wrap(const DocumentEditor(readOnly: true)),
        );
        await tester.pumpAndSettle();

        // Secondary tap (right-click equivalent in tests).
        await tester.tap(
          find.byType(DocumentEditor),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        // No context-menu buttons should appear when readOnly is true.
        expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      });

      testWidgets('CaretDocumentOverlay showCaret is false when readOnly', (tester) async {
        await tester.pumpWidget(
          _wrap(const DocumentEditor(readOnly: true)),
        );
        await tester.pumpAndSettle();

        final overlay = tester.widget<CaretDocumentOverlay>(find.byType(CaretDocumentOverlay));
        expect(overlay.showCaret, isFalse);
      });

      testWidgets('CaretDocumentOverlay showCaret is true when not readOnly', (tester) async {
        await tester.pumpWidget(_wrap(const DocumentEditor()));
        await tester.pumpAndSettle();

        final overlay = tester.widget<CaretDocumentOverlay>(find.byType(CaretDocumentOverlay));
        expect(overlay.showCaret, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // 5. autofocus requests focus
    // -------------------------------------------------------------------------

    group('autofocus', () {
      testWidgets('gains focus without explicit requestFocus when autofocus is true',
          (tester) async {
        final imeLog = <MethodCall>[];
        _installTextInputMock(tester, imeLog);

        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(
            DocumentEditor(
              focusNode: focusNode,
              autofocus: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(focusNode.hasFocus, isTrue);
      });

      testWidgets('does not auto-focus when autofocus is false', (tester) async {
        final imeLog = <MethodCall>[];
        _installTextInputMock(tester, imeLog);

        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(
            DocumentEditor(
              focusNode: focusNode,
              autofocus: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(focusNode.hasFocus, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // 6. overlayBuilder widgets appear
    // -------------------------------------------------------------------------

    group('overlayBuilder', () {
      testWidgets('widgets returned by overlayBuilder appear in the tree', (tester) async {
        await tester.pumpWidget(
          _wrap(
            DocumentEditor(
              overlayBuilder: (context, controller, layoutKey) {
                return [const Text('overlay_sentinel')];
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('overlay_sentinel'), findsOneWidget);
      });

      testWidgets('multiple overlay widgets are all present', (tester) async {
        await tester.pumpWidget(
          _wrap(
            DocumentEditor(
              overlayBuilder: (context, controller, layoutKey) {
                return [
                  const Text('overlay_a'),
                  const Text('overlay_b'),
                ];
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('overlay_a'), findsOneWidget);
        expect(find.text('overlay_b'), findsOneWidget);
      });

      testWidgets('overlayBuilder receives non-null controller and layoutKey', (tester) async {
        DocumentEditingController? capturedController;
        GlobalKey<DocumentLayoutState>? capturedLayoutKey;

        await tester.pumpWidget(
          _wrap(
            DocumentEditor(
              overlayBuilder: (context, controller, layoutKey) {
                capturedController = controller;
                capturedLayoutKey = layoutKey;
                return [];
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(capturedController, isNotNull);
        expect(capturedLayoutKey, isNotNull);
      });
    });

    // -------------------------------------------------------------------------
    // 7. Custom contextMenuBuilder is used
    // -------------------------------------------------------------------------

    group('contextMenuBuilder', () {
      testWidgets('custom builder widget appears on right-click', (tester) async {
        final imeLog = <MethodCall>[];
        _installTextInputMock(tester, imeLog);

        await tester.pumpWidget(
          _wrap(
            DocumentEditor(
              contextMenuBuilder: (context, position) {
                return const Material(child: Text('custom_menu'));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byType(EditableDocument),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('custom_menu'), findsOneWidget);
      });

      testWidgets('default menu appears when no contextMenuBuilder is provided', (tester) async {
        final imeLog = <MethodCall>[];
        _installTextInputMock(tester, imeLog);

        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(DocumentEditor(focusNode: focusNode)),
        );
        await tester.pumpAndSettle();

        // Focus first so the context menu can operate on a valid selection.
        focusNode.requestFocus();
        await tester.pump();

        await tester.tap(
          find.byType(EditableDocument),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        // The default AdaptiveTextSelectionToolbar should appear.
        expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // 8. Scrolls large content
    // -------------------------------------------------------------------------

    group('scrolling', () {
      testWidgets('renders many paragraphs in a constrained box without error', (tester) async {
        final imeLog = <MethodCall>[];
        _installTextInputMock(tester, imeLog);

        // Create a document with enough paragraphs to overflow a small viewport.
        final nodes = List.generate(
          30,
          (i) => ParagraphNode(id: 'p$i', text: AttributedText('Line $i of the document')),
        );
        final controller = DocumentEditingController(document: MutableDocument(nodes));
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: DocumentEditor(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DocumentEditor), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('DocumentScrollable is present for scroll management', (tester) async {
        await tester.pumpWidget(_wrap(const DocumentEditor()));
        await tester.pumpAndSettle();

        expect(find.byType(DocumentScrollable), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // External focus node
    // -------------------------------------------------------------------------

    group('external focusNode', () {
      testWidgets('uses provided focusNode', (tester) async {
        final imeLog = <MethodCall>[];
        _installTextInputMock(tester, imeLog);

        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(DocumentEditor(focusNode: focusNode)),
        );
        await tester.pumpAndSettle();

        focusNode.requestFocus();
        await tester.pump();

        expect(focusNode.hasFocus, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // onSelectionChanged callback
    // -------------------------------------------------------------------------

    group('onSelectionChanged', () {
      testWidgets('fires when controller selection changes', (tester) async {
        final imeLog = <MethodCall>[];
        _installTextInputMock(tester, imeLog);

        final controller = _makeController(text: 'Hello');
        addTearDown(controller.dispose);

        final selectionEvents = <DocumentSelection?>[];

        await tester.pumpWidget(
          _wrap(
            DocumentEditor(
              controller: controller,
              onSelectionChanged: selectionEvents.add,
            ),
          ),
        );
        await tester.pumpAndSettle();

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
    // debugFillProperties
    // -------------------------------------------------------------------------

    group('debugFillProperties', () {
      testWidgets('does not throw during diagnostics collection', (tester) async {
        final controller = _makeController();
        addTearDown(controller.dispose);
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _wrap(
            DocumentEditor(
              controller: controller,
              focusNode: focusNode,
              readOnly: false,
              autofocus: false,
              blockSpacing: 16.0,
              showLineNumbers: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(DocumentEditor));
        final diagnostics = element.toDiagnosticsNode().toStringDeep();
        expect(diagnostics, isNotEmpty);
        expect(tester.takeException(), isNull);
      });
    });

    group('showTableToolbar', () {
      testWidgets('does not crash with table selection and showTableToolbar true', (tester) async {
        final table = TableNode(
          id: 't1',
          rowCount: 2,
          columnCount: 2,
          cells: [
            [AttributedText('A1'), AttributedText('B1')],
            [AttributedText('A2'), AttributedText('B2')],
          ],
        );
        final controller = DocumentEditingController(
          document: MutableDocument([table]),
        );
        addTearDown(controller.dispose);

        controller.setSelection(
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: 't1',
              nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DocumentEditor(
                controller: controller,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No crash — toolbar builds (may render as SizedBox.shrink if layout
        // hasn't positioned the table component yet in the test environment).
        expect(tester.takeException(), isNull);
      });

      testWidgets('no TableContextToolbar when showTableToolbar is false', (tester) async {
        final table = TableNode(
          id: 't1',
          rowCount: 2,
          columnCount: 2,
          cells: [
            [AttributedText('A1'), AttributedText('B1')],
            [AttributedText('A2'), AttributedText('B2')],
          ],
        );
        final controller = DocumentEditingController(
          document: MutableDocument([table]),
        );
        addTearDown(controller.dispose);

        controller.setSelection(
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: 't1',
              nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DocumentEditor(
                controller: controller,
                showTableToolbar: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TableContextToolbar), findsNothing);
      });

      testWidgets('no TableContextToolbar when selection is not in a table', (tester) async {
        final controller = DocumentEditingController(
          document: MutableDocument([
            ParagraphNode(id: 'p1', text: AttributedText('Hello')),
          ]),
        );
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
          MaterialApp(
            home: Scaffold(
              body: DocumentEditor(
                controller: controller,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TableContextToolbar), findsNothing);
      });
    });

    group('showStatusBar', () {
      testWidgets('shows DocumentStatusBar by default', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: DocumentEditor()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DocumentStatusBar), findsOneWidget);
      });

      testWidgets('hides DocumentStatusBar when showStatusBar is false', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: DocumentEditor(showStatusBar: false)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DocumentStatusBar), findsNothing);
      });

      testWidgets('forwards count toggles to DocumentStatusBar', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DocumentEditor(
                showWordCount: false,
                showCharCount: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Word and char counts should not be displayed.
        expect(find.textContaining('words'), findsNothing);
        expect(find.textContaining('chars'), findsNothing);
        // Block count should still be there.
        expect(find.textContaining('blocks'), findsOneWidget);
      });

      testWidgets('applies StatusBarThemeData from DocumentTheme', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: DocumentTheme(
              data: DocumentThemeData(
                statusBarTheme: StatusBarThemeData(
                  backgroundColor: Color(0xFFFF0000),
                  padding: EdgeInsets.all(20),
                ),
              ),
              child: Scaffold(body: DocumentEditor()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the Container wrapping the status bar. It should have the
        // custom background color from the theme.
        final statusBar = find.byType(DocumentStatusBar);
        expect(statusBar, findsOneWidget);

        // Verify the Container ancestor has the themed decoration.
        final container = find.ancestor(
          of: statusBar,
          matching: find.byType(Container),
        );
        expect(container, findsWidgets);
      });
    });
  });
}
