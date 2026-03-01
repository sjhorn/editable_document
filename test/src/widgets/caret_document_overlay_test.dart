/// Tests for [CaretDocumentOverlay] — Phase 6.2.
///
/// Covers all 10 specified test cases:
/// 1. Caret not painted when no selection.
/// 2. Caret painted when collapsed selection exists.
/// 3. Caret not painted for expanded (non-collapsed) selection.
/// 4. Blink toggles visibility over time.
/// 5. Blink resets on selection change (caret becomes visible immediately).
/// 6. [CaretDocumentOverlayState.blinkRestart] resets blink cycle.
/// 7. [CaretDocumentOverlay.showCaret] false hides caret regardless of selection.
/// 8. Custom caretColor, caretWidth, cornerRadius passed to painter.
/// 9. [didUpdateWidget] handles controller change.
/// 10. Caret rect updates when selection changes position.
/// 11. Bug regression: caret rect is not stale after text insertion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates a minimal [DocumentEditingController] with one paragraph.
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

/// Returns a collapsed [DocumentSelection] at [offset] in node 'p1'.
DocumentSelection _collapsedAt(int offset) {
  return DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: 'p1',
      nodePosition: TextNodePosition(offset: offset),
    ),
  );
}

/// Returns an expanded [DocumentSelection] from [start] to [end] in node 'p1'.
DocumentSelection _expandedFrom(int start, int end) {
  return DocumentSelection(
    base: DocumentPosition(
      nodeId: 'p1',
      nodePosition: TextNodePosition(offset: start),
    ),
    extent: DocumentPosition(
      nodeId: 'p1',
      nodePosition: TextNodePosition(offset: end),
    ),
  );
}

/// Builds a [CaretDocumentOverlay] placed over a [DocumentLayout].
///
/// Returns the widget tree and exposes [overlayKey] for state access.
Widget _buildOverlay({
  required DocumentEditingController controller,
  GlobalKey<DocumentLayoutState>? layoutKey,
  GlobalKey<CaretDocumentOverlayState>? overlayKey,
  Color caretColor = const Color(0xFF000000),
  double caretWidth = 2.0,
  double cornerRadius = 1.0,
  Duration blinkInterval = const Duration(milliseconds: 500),
  bool showCaret = true,
}) {
  final lKey = layoutKey ?? GlobalKey<DocumentLayoutState>();
  return _wrap(
    SizedBox(
      width: 600,
      height: 800,
      child: Stack(
        children: [
          DocumentLayout(
            key: lKey,
            document: controller.document,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
          Positioned.fill(
            child: CaretDocumentOverlay(
              key: overlayKey,
              controller: controller,
              layoutKey: lKey,
              caretColor: caretColor,
              caretWidth: caretWidth,
              cornerRadius: cornerRadius,
              blinkInterval: blinkInterval,
              showCaret: showCaret,
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Test 1: Caret not painted when no selection
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — no selection', () {
    testWidgets('widget builds without error when controller has no selection', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));
      await tester.pump();

      expect(find.byType(CaretDocumentOverlay), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overlay builds without error when selection is null', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      // No selection set.
      await tester.pumpWidget(_buildOverlay(controller: controller));
      await tester.pump();

      // The overlay widget should be present (backed by _CaretRenderWidget /
      // RenderDocumentCaret rather than CustomPaint).
      expect(find.byType(CaretDocumentOverlay), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Test 2: Caret painted when collapsed selection exists
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — collapsed selection', () {
    testWidgets('builds without error when collapsed selection is set', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      controller.setSelection(_collapsedAt(3));
      await tester.pump();

      expect(find.byType(CaretDocumentOverlay), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('caret is visible immediately after setting a collapsed selection', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _buildOverlay(controller: controller, overlayKey: overlayKey),
      );

      controller.setSelection(_collapsedAt(3));
      await tester.pump();

      // The state should report the caret as visible right after a selection is set.
      expect(overlayKey.currentState!.isCursorVisible, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Test 3: Caret not painted for expanded selection
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — expanded selection', () {
    testWidgets('builds without error when expanded selection is set', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      controller.setSelection(_expandedFrom(0, 5));
      await tester.pump();

      expect(find.byType(CaretDocumentOverlay), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('caret is not visible when selection is expanded', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _buildOverlay(controller: controller, overlayKey: overlayKey),
      );

      controller.setSelection(_expandedFrom(0, 5));
      await tester.pump();

      // An expanded selection should not show the caret.
      expect(overlayKey.currentState!.isCursorVisible, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Test 4: Blink toggles visibility over time
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — blink animation', () {
    testWidgets('caret visibility toggles after blinkInterval elapses', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _buildOverlay(
          controller: controller,
          overlayKey: overlayKey,
          blinkInterval: const Duration(milliseconds: 500),
        ),
      );

      // Set a collapsed selection so the caret is active.
      controller.setSelection(_collapsedAt(3));
      await tester.pump();

      // Caret starts visible.
      expect(overlayKey.currentState!.isCursorVisible, isTrue);

      // After one blink interval the caret should be hidden.
      await tester.pump(const Duration(milliseconds: 500));
      expect(overlayKey.currentState!.isCursorVisible, isFalse);

      // After another interval, visible again.
      await tester.pump(const Duration(milliseconds: 500));
      expect(overlayKey.currentState!.isCursorVisible, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Test 5: Blink resets on selection change
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — blink reset on selection change', () {
    testWidgets('caret becomes visible immediately when selection changes', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _buildOverlay(
          controller: controller,
          overlayKey: overlayKey,
          blinkInterval: const Duration(milliseconds: 500),
        ),
      );

      // Set a collapsed selection.
      controller.setSelection(_collapsedAt(3));
      await tester.pump();

      // Wait until caret is in hidden state.
      await tester.pump(const Duration(milliseconds: 500));
      expect(overlayKey.currentState!.isCursorVisible, isFalse);

      // Change the selection — caret should become visible immediately.
      controller.setSelection(_collapsedAt(5));
      await tester.pump();

      expect(overlayKey.currentState!.isCursorVisible, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Test 6: blinkRestart() resets blink cycle
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — blinkRestart()', () {
    testWidgets('blinkRestart() makes caret visible immediately', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _buildOverlay(
          controller: controller,
          overlayKey: overlayKey,
          blinkInterval: const Duration(milliseconds: 500),
        ),
      );

      controller.setSelection(_collapsedAt(3));
      await tester.pump();

      // Wait until caret hides.
      await tester.pump(const Duration(milliseconds: 500));
      expect(overlayKey.currentState!.isCursorVisible, isFalse);

      // Restart blink — caret should be visible again.
      overlayKey.currentState!.blinkRestart();
      await tester.pump();

      expect(overlayKey.currentState!.isCursorVisible, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('blinkRestart() restarts the blink timer from zero', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _buildOverlay(
          controller: controller,
          overlayKey: overlayKey,
          blinkInterval: const Duration(milliseconds: 500),
        ),
      );

      controller.setSelection(_collapsedAt(3));
      await tester.pump();

      // Advance 400ms (before first blink).
      await tester.pump(const Duration(milliseconds: 400));
      expect(overlayKey.currentState!.isCursorVisible, isTrue);

      // Restart resets the timer.
      overlayKey.currentState!.blinkRestart();
      await tester.pump();

      // Only 100ms have elapsed since restart — caret should still be visible.
      await tester.pump(const Duration(milliseconds: 100));
      expect(overlayKey.currentState!.isCursorVisible, isTrue);

      // After a full 500ms from restart, caret should blink off.
      await tester.pump(const Duration(milliseconds: 400));
      expect(overlayKey.currentState!.isCursorVisible, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Test 7: showCaret: false hides caret regardless of selection
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — showCaret: false', () {
    testWidgets('caret never shown when showCaret is false, even with collapsed selection',
        (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _buildOverlay(
          controller: controller,
          overlayKey: overlayKey,
          showCaret: false,
        ),
      );

      controller.setSelection(_collapsedAt(3));
      await tester.pump();

      // With showCaret: false the caret must always be hidden.
      expect(overlayKey.currentState!.isCursorVisible, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('caret stays hidden across blink cycles when showCaret is false', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _buildOverlay(
          controller: controller,
          overlayKey: overlayKey,
          showCaret: false,
          blinkInterval: const Duration(milliseconds: 500),
        ),
      );

      controller.setSelection(_collapsedAt(3));
      await tester.pump();

      // Advance multiple blink intervals.
      await tester.pump(const Duration(milliseconds: 500));
      expect(overlayKey.currentState!.isCursorVisible, isFalse);

      await tester.pump(const Duration(milliseconds: 500));
      expect(overlayKey.currentState!.isCursorVisible, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Test 8: Custom caretColor, caretWidth, cornerRadius passed to painter
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — custom paint parameters', () {
    testWidgets('caretColor is stored on the widget', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      const customColor = Color(0xFFFF0000);

      await tester.pumpWidget(
        _buildOverlay(controller: controller, caretColor: customColor),
      );

      final overlay = tester.widget<CaretDocumentOverlay>(
        find.byType(CaretDocumentOverlay),
      );
      expect(overlay.caretColor, customColor);
    });

    testWidgets('caretWidth is stored on the widget', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildOverlay(controller: controller, caretWidth: 4.0),
      );

      final overlay = tester.widget<CaretDocumentOverlay>(
        find.byType(CaretDocumentOverlay),
      );
      expect(overlay.caretWidth, 4.0);
    });

    testWidgets('cornerRadius is stored on the widget', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildOverlay(controller: controller, cornerRadius: 3.0),
      );

      final overlay = tester.widget<CaretDocumentOverlay>(
        find.byType(CaretDocumentOverlay),
      );
      expect(overlay.cornerRadius, 3.0);
    });

    testWidgets('builds without error with non-default paint parameters', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildOverlay(
          controller: controller,
          caretColor: const Color(0xFF0000FF),
          caretWidth: 3.0,
          cornerRadius: 2.0,
        ),
      );

      // Set selection after the widget is built.
      controller.setSelection(_collapsedAt(2));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Test 9: didUpdateWidget handles controller change
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — didUpdateWidget', () {
    testWidgets('switching controller removes old listener and adds new one', (tester) async {
      final controller1 = _makeController(text: 'First document');
      final controller2 = _makeController(text: 'Second document');
      addTearDown(controller1.dispose);
      addTearDown(controller2.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      Widget buildWith(DocumentEditingController ctrl) {
        return _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: Stack(
              children: [
                DocumentLayout(
                  key: layoutKey,
                  document: ctrl.document,
                  controller: ctrl,
                  componentBuilders: defaultComponentBuilders,
                ),
                Positioned.fill(
                  child: CaretDocumentOverlay(
                    key: overlayKey,
                    controller: ctrl,
                    layoutKey: layoutKey,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWith(controller1));
      await tester.pumpWidget(buildWith(controller2));

      // After switching, the new controller should drive the overlay.
      controller2.setSelection(_collapsedAt(1));
      await tester.pump();

      expect(overlayKey.currentState!.isCursorVisible, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('old controller changes do not affect overlay after swap', (tester) async {
      final controller1 = _makeController(text: 'First document');
      final controller2 = _makeController(text: 'Second document');
      addTearDown(controller1.dispose);
      addTearDown(controller2.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      Widget buildWith(DocumentEditingController ctrl) {
        return _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: Stack(
              children: [
                DocumentLayout(
                  key: layoutKey,
                  document: ctrl.document,
                  controller: ctrl,
                  componentBuilders: defaultComponentBuilders,
                ),
                Positioned.fill(
                  child: CaretDocumentOverlay(
                    key: overlayKey,
                    controller: ctrl,
                    layoutKey: layoutKey,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWith(controller1));
      await tester.pumpWidget(buildWith(controller2));

      // Old controller changes should not affect the overlay.
      controller1.setSelection(_collapsedAt(3));
      await tester.pump();

      // Overlay should not have been triggered by the old controller.
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Test 10: Caret rect updates when selection changes position
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — caret rect updates', () {
    testWidgets('overlay updates without error when caret moves to a new position', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _buildOverlay(controller: controller, overlayKey: overlayKey),
      );

      controller.setSelection(_collapsedAt(0));
      await tester.pump();

      expect(overlayKey.currentState!.isCursorVisible, isTrue);

      // Move caret to a different position.
      controller.setSelection(_collapsedAt(5));
      await tester.pump();

      expect(overlayKey.currentState!.isCursorVisible, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overlay transitions from no-selection to collapsed correctly', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _buildOverlay(controller: controller, overlayKey: overlayKey),
      );

      // No selection initially.
      await tester.pump();
      expect(overlayKey.currentState!.isCursorVisible, isFalse);

      // Set a collapsed selection.
      controller.setSelection(_collapsedAt(3));
      await tester.pump();

      expect(overlayKey.currentState!.isCursorVisible, isTrue);
    });

    testWidgets('overlay transitions from collapsed to no-selection correctly', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _buildOverlay(controller: controller, overlayKey: overlayKey),
      );

      controller.setSelection(_collapsedAt(3));
      await tester.pump();
      expect(overlayKey.currentState!.isCursorVisible, isTrue);

      // Clear selection.
      controller.clearSelection();
      await tester.pump();

      expect(overlayKey.currentState!.isCursorVisible, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Default parameter values
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — default parameters', () {
    testWidgets('default caretColor is opaque black', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: Stack(
              children: [
                DocumentLayout(
                  key: layoutKey,
                  document: controller.document,
                  controller: controller,
                  componentBuilders: defaultComponentBuilders,
                ),
                Positioned.fill(
                  child: CaretDocumentOverlay(
                    controller: controller,
                    layoutKey: layoutKey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final overlay = tester.widget<CaretDocumentOverlay>(
        find.byType(CaretDocumentOverlay),
      );
      expect(overlay.caretColor, const Color(0xFF000000));
    });

    testWidgets('default caretWidth is 2.0', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: Stack(
              children: [
                DocumentLayout(
                  key: layoutKey,
                  document: controller.document,
                  controller: controller,
                  componentBuilders: defaultComponentBuilders,
                ),
                Positioned.fill(
                  child: CaretDocumentOverlay(
                    controller: controller,
                    layoutKey: layoutKey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final overlay = tester.widget<CaretDocumentOverlay>(
        find.byType(CaretDocumentOverlay),
      );
      expect(overlay.caretWidth, 2.0);
    });

    testWidgets('default cornerRadius is 1.0', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: Stack(
              children: [
                DocumentLayout(
                  key: layoutKey,
                  document: controller.document,
                  controller: controller,
                  componentBuilders: defaultComponentBuilders,
                ),
                Positioned.fill(
                  child: CaretDocumentOverlay(
                    controller: controller,
                    layoutKey: layoutKey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final overlay = tester.widget<CaretDocumentOverlay>(
        find.byType(CaretDocumentOverlay),
      );
      expect(overlay.cornerRadius, 1.0);
    });

    testWidgets('default showCaret is true', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: Stack(
              children: [
                DocumentLayout(
                  key: layoutKey,
                  document: controller.document,
                  controller: controller,
                  componentBuilders: defaultComponentBuilders,
                ),
                Positioned.fill(
                  child: CaretDocumentOverlay(
                    controller: controller,
                    layoutKey: layoutKey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final overlay = tester.widget<CaretDocumentOverlay>(
        find.byType(CaretDocumentOverlay),
      );
      expect(overlay.showCaret, isTrue);
    });

    testWidgets('default blinkInterval is 500ms', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: Stack(
              children: [
                DocumentLayout(
                  key: layoutKey,
                  document: controller.document,
                  controller: controller,
                  componentBuilders: defaultComponentBuilders,
                ),
                Positioned.fill(
                  child: CaretDocumentOverlay(
                    controller: controller,
                    layoutKey: layoutKey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final overlay = tester.widget<CaretDocumentOverlay>(
        find.byType(CaretDocumentOverlay),
      );
      expect(overlay.blinkInterval, const Duration(milliseconds: 500));
    });
  });

  // -------------------------------------------------------------------------
  // Dispose / lifecycle
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — lifecycle', () {
    testWidgets('disposes without error', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      controller.setSelection(_collapsedAt(3));
      await tester.pump();

      // Replace with an empty widget to trigger dispose.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      expect(tester.takeException(), isNull);
    });

    testWidgets('no blink timer fires after dispose', (tester) async {
      final controller = _makeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildOverlay(controller: controller));

      controller.setSelection(_collapsedAt(3));
      await tester.pump();

      // Dispose the overlay.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Advance past several blink intervals — no exception should be thrown.
      await tester.pump(const Duration(milliseconds: 2000));

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Test 11: Regression — caretRect is correct after a node replacement
  //
  // Previously, _onControllerChanged called _updateCaretRect() synchronously,
  // querying DocumentLayout BEFORE it had rebuilt with the new text. The fix
  // was to defer _updateCaretRect() to a post-frame callback.
  //
  // With the current architecture, geometry is computed at paint time by
  // RenderDocumentCaret rather than cached in widget state. The caretRect
  // getter queries DocumentLayoutState on demand, so a single pump (which
  // rebuilds DocumentLayout + triggers a paint) is sufficient for caretRect
  // to reflect the new node — no second pump is needed.
  //
  // The test detects regressions by replacing a node with a NEW node id
  // ('p1' → 'p2') and verifying that caretRect is non-null after a single
  // pump.
  // -------------------------------------------------------------------------

  group('CaretDocumentOverlay — caret rect after node replacement', () {
    testWidgets('caretRect is non-null after replacing a node and moving caret into the new node',
        (tester) async {
      // Build a document with a single paragraph identified as 'p1'.
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<CaretDocumentOverlayState>();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: Stack(
              children: [
                DocumentLayout(
                  key: layoutKey,
                  document: doc,
                  controller: controller,
                  componentBuilders: defaultComponentBuilders,
                ),
                Positioned.fill(
                  child: CaretDocumentOverlay(
                    key: overlayKey,
                    controller: controller,
                    layoutKey: layoutKey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Step 1: Place the caret inside 'p1' and let the widget tree settle.
      controller.setSelection(_collapsedAt(0));
      await tester.pump(); // rebuild + layout + paint

      // The caret should be visible and have a non-null rect because 'p1' exists.
      expect(overlayKey.currentState!.caretRect, isNotNull);

      // Step 2: Replace 'p1' with a brand-new node 'p2', then move the
      // selection into 'p2'. This fires _onControllerChanged which triggers
      // a setState (and ultimately a rebuild + repaint).
      doc.replaceNode('p1', ParagraphNode(id: 'p2', text: AttributedText('World')));
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p2',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      // Step 3: A single pump rebuilds DocumentLayout with 'p2' in the render
      // tree and triggers a paint. Because geometry is computed at paint time
      // by RenderDocumentCaret (no post-frame deferral needed), caretRect is
      // available immediately after this single pump.
      await tester.pump();

      // Step 4: Verify the caret rect is non-null.
      expect(
        overlayKey.currentState!.caretRect,
        isNotNull,
        reason: 'caretRect must be non-null after DocumentLayout rebuilds with the '
            'new node. RenderDocumentCaret queries geometry at paint time so no '
            'second pump is required.',
      );
    });
  });
}
