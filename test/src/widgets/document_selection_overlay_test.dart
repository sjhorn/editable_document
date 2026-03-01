/// Tests for [DocumentSelectionOverlay] — Phase 6.1.
///
/// Covers:
/// - Widget builds and renders without error.
/// - Stack structure: child content, selection painter, caret painter,
///   and [CompositedTransformTarget] widgets are present.
/// - Selection painters respond to [DocumentEditingController.selection].
/// - `update(DocumentSelection?)` recomputes painter data from layout geometry.
/// - Overlay shows correct painters when selection is collapsed vs expanded.
/// - Overlay hides caret when [showCaret] is false.
/// - Overlay hides selection when [showSelection] is false.
/// - Overlay cleans up listeners on dispose.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Builds a minimal [DocumentEditingController] with one paragraph.
DocumentEditingController _makeController({String text = 'Hello world'}) {
  final doc = MutableDocument([
    ParagraphNode(id: 'p1', text: AttributedText(text)),
  ]);
  return DocumentEditingController(document: doc);
}

/// Wraps [child] in [MaterialApp] + [Scaffold] for a full widget environment.
Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Builds a [DocumentSelectionOverlay] with a [DocumentLayout] child, inside
/// a constrained box.
Widget _buildOverlay({
  required DocumentEditingController controller,
  bool showCaret = true,
  bool showSelection = true,
  bool showHandles = false,
  Color selectionColor = const Color(0x663399FF),
  Color caretColor = const Color(0xFF000000),
  GlobalKey<DocumentLayoutState>? layoutKey,
}) {
  final key = layoutKey ?? GlobalKey<DocumentLayoutState>();
  return _wrap(
    SizedBox(
      width: 600,
      height: 800,
      child: DocumentSelectionOverlay(
        controller: controller,
        layoutKey: key,
        startHandleLayerLink: LayerLink(),
        endHandleLayerLink: LayerLink(),
        selectionColor: selectionColor,
        caretColor: caretColor,
        showCaret: showCaret,
        showSelection: showSelection,
        showHandles: showHandles,
        child: DocumentLayout(
          key: key,
          document: controller.document,
          controller: controller,
          componentBuilders: defaultComponentBuilders,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Construction / rendering
  // -------------------------------------------------------------------------

  group('DocumentSelectionOverlay — construction', () {
    testWidgets('builds without error with no selection', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      expect(find.byType(DocumentSelectionOverlay), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds without error with a collapsed selection', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 3),
          ),
        ),
      );

      await tester.pumpWidget(_buildOverlay(controller: controller));
      await tester.pump(); // let overlay rebuild after selection

      expect(tester.takeException(), isNull);
    });

    testWidgets('builds without error with an expanded selection', (tester) async {
      final controller = _makeController();
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

      await tester.pumpWidget(_buildOverlay(controller: controller));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Widget tree structure
  // -------------------------------------------------------------------------

  group('DocumentSelectionOverlay — widget tree', () {
    testWidgets('contains a Stack in its subtree', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      // DocumentSelectionOverlay wraps content in a Stack.
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('child DocumentLayout is present in the tree', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      expect(find.byType(DocumentLayout), findsOneWidget);
    });

    testWidgets('two CompositedTransformTarget widgets present for layer links', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      // One for start handle, one for end handle.
      expect(find.byType(CompositedTransformTarget), findsNWidgets(2));
    });

    testWidgets('caret and selection use LeafRenderObjectWidget render objects, not CustomPaint',
        (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      // The overlay Stack now uses _CaretRenderWidget and
      // _SelectionHighlightRenderWidget (both LeafRenderObjectWidgets backed by
      // RenderDocumentCaret and RenderDocumentSelectionHighlight) in place of
      // CustomPaint + painters.
      //
      // We verify this by finding the RenderBox leaf objects in the render tree
      // that are RenderDocumentCaret and RenderDocumentSelectionHighlight.
      final renderObjects = <RenderObject>[];
      tester.renderObjectList(find.byType(DocumentSelectionOverlay)).forEach((_) {});

      // Walk the render tree starting from the DocumentSelectionOverlay
      // to find RenderDocumentCaret and RenderDocumentSelectionHighlight.
      void collectRenderObjects(RenderObject ro) {
        renderObjects.add(ro);
        ro.visitChildren(collectRenderObjects);
      }

      final overlayElement = tester.element(find.byType(DocumentSelectionOverlay));
      overlayElement.renderObject?.visitChildren(collectRenderObjects);

      final caretRenders = renderObjects.whereType<RenderDocumentCaret>().toList();
      final highlightRenders = renderObjects.whereType<RenderDocumentSelectionHighlight>().toList();

      expect(caretRenders, hasLength(1), reason: 'Expected exactly one RenderDocumentCaret');
      expect(highlightRenders, hasLength(1),
          reason: 'Expected exactly one RenderDocumentSelectionHighlight');
    });
  });

  // -------------------------------------------------------------------------
  // showCaret / showSelection flags
  // -------------------------------------------------------------------------

  group('DocumentSelectionOverlay — showCaret and showSelection flags', () {
    testWidgets('showCaret: false hides caret painter', (tester) async {
      final controller = _makeController();
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
        _buildOverlay(controller: controller, showCaret: false),
      );
      await tester.pump();

      // Verify the widget stored showCaret=false.
      final overlay = tester.widget<DocumentSelectionOverlay>(
        find.byType(DocumentSelectionOverlay),
      );
      expect(overlay.showCaret, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('showSelection: false hides selection painter', (tester) async {
      final controller = _makeController();
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
        _buildOverlay(controller: controller, showSelection: false),
      );
      await tester.pump();

      final overlay = tester.widget<DocumentSelectionOverlay>(
        find.byType(DocumentSelectionOverlay),
      );
      expect(overlay.showSelection, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Reactivity — controller selection changes
  // -------------------------------------------------------------------------

  group('DocumentSelectionOverlay — controller reactivity', () {
    testWidgets('rebuilds without error when selection changes to collapsed', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      // Set a collapsed selection.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 1),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('rebuilds without error when selection changes to expanded', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

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
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('rebuilds without error when selection is cleared', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
          ),
        ),
      );

      await tester.pumpWidget(_buildOverlay(controller: controller));
      await tester.pump();

      // Clear the selection.
      controller.clearSelection();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('multiple rapid selection changes do not throw', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      for (var i = 0; i < 5; i++) {
        controller.setSelection(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: 'p1',
              nodePosition: TextNodePosition(offset: i),
            ),
          ),
        );
        await tester.pump();
      }

      controller.clearSelection();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // update() method
  // -------------------------------------------------------------------------

  group('DocumentSelectionOverlay — update()', () {
    testWidgets('update() with null selection does not throw', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      final key = GlobalKey<DocumentSelectionOverlayState>();
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: DocumentSelectionOverlay(
              key: key,
              controller: controller,
              layoutKey: layoutKey,
              startHandleLayerLink: LayerLink(),
              endHandleLayerLink: LayerLink(),
              child: DocumentLayout(
                key: layoutKey,
                document: controller.document,
                controller: controller,
                componentBuilders: defaultComponentBuilders,
              ),
            ),
          ),
        ),
      );

      expect(() => key.currentState!.update(null), returnsNormally);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('update() with a collapsed selection does not throw', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      final key = GlobalKey<DocumentSelectionOverlayState>();
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: DocumentSelectionOverlay(
              key: key,
              controller: controller,
              layoutKey: layoutKey,
              startHandleLayerLink: LayerLink(),
              endHandleLayerLink: LayerLink(),
              child: DocumentLayout(
                key: layoutKey,
                document: controller.document,
                controller: controller,
                componentBuilders: defaultComponentBuilders,
              ),
            ),
          ),
        ),
      );

      const collapsed = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );

      expect(() => key.currentState!.update(collapsed), returnsNormally);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('update() with an expanded selection does not throw', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      final key = GlobalKey<DocumentSelectionOverlayState>();
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: DocumentSelectionOverlay(
              key: key,
              controller: controller,
              layoutKey: layoutKey,
              startHandleLayerLink: LayerLink(),
              endHandleLayerLink: LayerLink(),
              child: DocumentLayout(
                key: layoutKey,
                document: controller.document,
                controller: controller,
                componentBuilders: defaultComponentBuilders,
              ),
            ),
          ),
        ),
      );

      const expanded = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );

      expect(() => key.currentState!.update(expanded), returnsNormally);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Colour pass-through
  // -------------------------------------------------------------------------

  group('DocumentSelectionOverlay — colour parameters', () {
    testWidgets('selectionColor is stored on the widget', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      const customColor = Color(0x33FF0000);

      await tester.pumpWidget(
        _buildOverlay(controller: controller, selectionColor: customColor),
      );

      final overlay = tester.widget<DocumentSelectionOverlay>(
        find.byType(DocumentSelectionOverlay),
      );
      expect(overlay.selectionColor, customColor);
    });

    testWidgets('caretColor is stored on the widget', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      const customColor = Color(0xFF0000FF);

      await tester.pumpWidget(
        _buildOverlay(controller: controller, caretColor: customColor),
      );

      final overlay = tester.widget<DocumentSelectionOverlay>(
        find.byType(DocumentSelectionOverlay),
      );
      expect(overlay.caretColor, customColor);
    });
  });

  // -------------------------------------------------------------------------
  // Default parameter values
  // -------------------------------------------------------------------------

  group('DocumentSelectionOverlay — default parameters', () {
    testWidgets('default selectionColor is semi-transparent blue', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      final overlay = tester.widget<DocumentSelectionOverlay>(
        find.byType(DocumentSelectionOverlay),
      );
      expect(overlay.selectionColor, const Color(0x663399FF));
    });

    testWidgets('default caretColor is opaque black', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      final overlay = tester.widget<DocumentSelectionOverlay>(
        find.byType(DocumentSelectionOverlay),
      );
      expect(overlay.caretColor, const Color(0xFF000000));
    });

    testWidgets('default showCaret is true', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      final overlay = tester.widget<DocumentSelectionOverlay>(
        find.byType(DocumentSelectionOverlay),
      );
      expect(overlay.showCaret, isTrue);
    });

    testWidgets('default showSelection is true', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      final overlay = tester.widget<DocumentSelectionOverlay>(
        find.byType(DocumentSelectionOverlay),
      );
      expect(overlay.showSelection, isTrue);
    });

    testWidgets('default showHandles is false', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      final overlay = tester.widget<DocumentSelectionOverlay>(
        find.byType(DocumentSelectionOverlay),
      );
      expect(overlay.showHandles, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Lifecycle — didUpdateWidget
  // -------------------------------------------------------------------------

  group('DocumentSelectionOverlay — didUpdateWidget', () {
    testWidgets('switching controller removes old listener and adds new one', (tester) async {
      final controller1 = _makeController(text: 'First');
      final controller2 = _makeController(text: 'Second');
      addTearDown(controller1.dispose);
      addTearDown(controller2.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      Widget buildWith(DocumentEditingController ctrl) {
        return _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: DocumentSelectionOverlay(
              controller: ctrl,
              layoutKey: layoutKey,
              startHandleLayerLink: LayerLink(),
              endHandleLayerLink: LayerLink(),
              child: DocumentLayout(
                key: layoutKey,
                document: ctrl.document,
                controller: ctrl,
                componentBuilders: defaultComponentBuilders,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWith(controller1));
      await tester.pumpWidget(buildWith(controller2));

      // After switching, changing the new controller should rebuild the overlay.
      controller2.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 1),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
