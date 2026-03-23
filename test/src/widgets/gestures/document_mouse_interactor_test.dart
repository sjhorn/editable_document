/// Tests for [DocumentMouseInteractor].
///
/// Covers tap (collapse selection), double-tap (word select), triple-tap
/// (block select), shift+tap (extend selection), drag (range select),
/// enabled:false behaviour, focus stealing, diagnostics, and secondary
/// (right-click) tap handling.
library;

import 'package:flutter/gestures.dart' show kSecondaryMouseButton, PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// How long to wait after a single tap so that the double-tap timer expires
/// and the tap recogniser wins the arena.
const _tapSettleDuration = Duration(milliseconds: 500);

/// Creates a [MutableDocument] with a single [ParagraphNode].
MutableDocument _singleParagraph(String text) =>
    MutableDocument([ParagraphNode(id: 'p1', text: AttributedText(text))]);

/// Wraps a [DocumentMouseInteractor] + [DocumentLayout] in a [MaterialApp] /
/// [Scaffold] so all widget-test infrastructure (Localizations, MediaQuery,
/// Directionality) is available.
Widget _buildInteractor({
  required DocumentEditingController controller,
  required GlobalKey<DocumentLayoutState> layoutKey,
  required MutableDocument doc,
  FocusNode? focusNode,
  bool enabled = true,
  ValueChanged<Offset>? onSecondaryTapDown,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        child: DocumentMouseInteractor(
          controller: controller,
          layoutKey: layoutKey,
          document: doc,
          focusNode: focusNode,
          enabled: enabled,
          onSecondaryTapDown: onSecondaryTapDown,
          child: _maybeFocus(
            focusNode: focusNode,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Wraps [child] in a [Focus] widget when [focusNode] is non-null, so the
/// node is attached to the focus tree. When [focusNode] is null, returns
/// [child] directly (no Focus wrapper).
Widget _maybeFocus({required FocusNode? focusNode, required Widget child}) {
  if (focusNode == null) return child;
  return Focus(focusNode: focusNode, child: child);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // 1. Tap collapses selection
  // =========================================================================

  group('DocumentMouseInteractor — tap', () {
    testWidgets('tap places a collapsed selection', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(controller: controller, layoutKey: layoutKey, doc: doc),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      await tester.tapAt(rect.centerLeft + const Offset(10, 0));
      await tester.pump(_tapSettleDuration);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
    });

    testWidgets('tap updates controller selection node id', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      expect(controller.selection, isNull);

      await tester.pumpWidget(
        _buildInteractor(controller: controller, layoutKey: layoutKey, doc: doc),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      await tester.tapAt(rect.center);
      await tester.pump(_tapSettleDuration);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.base.nodeId, 'p1');
    });
  });

  // =========================================================================
  // 2. Double-tap selects word
  // =========================================================================

  group('DocumentMouseInteractor — double-tap', () {
    testWidgets('double-tap selects the word under tap', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(controller: controller, layoutKey: layoutKey, doc: doc),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final tapPos = rect.centerLeft + const Offset(10, 0);

      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isExpanded, isTrue);
      expect(controller.selection!.base.nodeId, 'p1');
      expect(controller.selection!.extent.nodeId, 'p1');
    });
  });

  // =========================================================================
  // 3. enabled:false ignores gestures
  // =========================================================================

  group('DocumentMouseInteractor — enabled flag', () {
    testWidgets('enabled:false ignores tap', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          enabled: false,
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      await tester.tapAt(rect.center);
      await tester.pump(_tapSettleDuration);

      expect(controller.selection, isNull);
    });

    testWidgets('enabled:false ignores double-tap', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          enabled: false,
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final tapPos = rect.centerLeft + const Offset(10, 0);

      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection, isNull);
    });
  });

  // =========================================================================
  // 4. Focus stealing — focusNode.requestFocus on pointer-down
  // =========================================================================

  group('DocumentMouseInteractor — focus', () {
    testWidgets('requests focus on pointer-down when focusNode is provided', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          focusNode: focusNode,
        ),
      );
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);

      // Tap on the document area.
      await tester.tap(find.byType(DocumentMouseInteractor));
      await tester.pump(const Duration(milliseconds: 500));

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('does not throw when focusNode is null', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        // focusNode omitted — defaults to null
        _buildInteractor(controller: controller, layoutKey: layoutKey, doc: doc),
      );
      await tester.pump();

      // Should not throw.
      await tester.tap(find.byType(DocumentMouseInteractor));
      await tester.pump(_tapSettleDuration);

      expect(controller.selection, isNotNull);
    });

    testWidgets('focus is not requested when enabled is false', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          focusNode: focusNode,
          enabled: false,
        ),
      );
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);

      await tester.tap(find.byType(DocumentMouseInteractor));
      await tester.pump(_tapSettleDuration);

      // enabled:false means _onPointerDown returns early before requestFocus.
      expect(focusNode.hasFocus, isFalse);
    });
  });

  // =========================================================================
  // 5. debugFillProperties
  // =========================================================================

  group('DocumentMouseInteractor — diagnostics', () {
    testWidgets('debugFillProperties includes focusNode property', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      final widget = DocumentMouseInteractor(
        controller: controller,
        layoutKey: layoutKey,
        document: doc,
        focusNode: focusNode,
        child: DocumentLayout(
          key: layoutKey,
          document: doc,
          controller: controller,
          componentBuilders: defaultComponentBuilders,
        ),
      );

      final props = DiagnosticPropertiesBuilder();
      widget.debugFillProperties(props);

      expect(props.properties.any((p) => p.name == 'focusNode'), isTrue);
      expect(props.properties.any((p) => p.name == 'enabled'), isTrue);
    });

    testWidgets('debugFillProperties does not throw without focusNode', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      final widget = DocumentMouseInteractor(
        controller: controller,
        layoutKey: layoutKey,
        document: doc,
        child: DocumentLayout(
          key: layoutKey,
          document: doc,
          controller: controller,
          componentBuilders: defaultComponentBuilders,
        ),
      );

      final props = DiagnosticPropertiesBuilder();
      widget.debugFillProperties(props);

      // Should not throw; focusNode property defaults to null.
      expect(props.properties.any((p) => p.name == 'focusNode'), isTrue);
    });

    testWidgets('debugFillProperties includes onSecondaryTapDown property', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      final widget = DocumentMouseInteractor(
        controller: controller,
        layoutKey: layoutKey,
        document: doc,
        onSecondaryTapDown: (_) {},
        child: DocumentLayout(
          key: layoutKey,
          document: doc,
          controller: controller,
          componentBuilders: defaultComponentBuilders,
        ),
      );

      final props = DiagnosticPropertiesBuilder();
      widget.debugFillProperties(props);

      expect(props.properties.any((p) => p.name == 'onSecondaryTapDown'), isTrue);
    });
  });

  // =========================================================================
  // 6. Secondary (right-click) tap
  // =========================================================================

  group('DocumentMouseInteractor — secondary tap (right-click)', () {
    /// Simulates a secondary (right-click) mouse button tap at [position].
    Future<void> rightClickAt(WidgetTester tester, Offset position) async {
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.addPointer(location: position);
      addTearDown(gesture.removePointer);
      await gesture.down(position);
      await gesture.up();
      await tester.pump();
    }

    testWidgets('right-click fires onSecondaryTapDown callback with global position', (
      tester,
    ) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      Offset? receivedPosition;
      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          onSecondaryTapDown: (pos) => receivedPosition = pos,
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final tapPos = rect.center;
      await rightClickAt(tester, tapPos);

      expect(receivedPosition, isNotNull);
    });

    testWidgets('right-click places caret when no selection exists', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      expect(controller.selection, isNull);

      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          onSecondaryTapDown: (_) {},
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      await rightClickAt(tester, rect.center);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(controller.selection!.base.nodeId, 'p1');
    });

    testWidgets('right-click preserves expanded selection when tap is inside it', (
      tester,
    ) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      // Select "Hello world" (entire paragraph).
      final expandedSelection = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 11),
        ),
      );

      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          onSecondaryTapDown: (_) {},
        ),
      );
      await tester.pump();

      // Set the expanded selection before right-clicking.
      controller.setSelection(expandedSelection);
      await tester.pump();

      // Right-click somewhere inside the paragraph.
      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      await rightClickAt(tester, rect.center);

      // Selection must remain expanded (not collapsed).
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isExpanded, isTrue);
    });

    testWidgets('right-click collapses selection when tap is outside it', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
        ParagraphNode(id: 'p2', text: AttributedText('world')),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          onSecondaryTapDown: (_) {},
        ),
      );
      await tester.pump();

      // Set a selection covering only p1.
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

      expect(controller.selection!.isExpanded, isTrue);

      // Right-click in p2 (which is outside the selection in p1).
      // Use the layout key to find the render box for p2.
      final p2Component = layoutKey.currentState!.componentForNode('p2')!;
      final p2Box = p2Component as RenderBox;
      final p2Global = p2Box.localToGlobal(Offset(p2Box.size.width / 2, p2Box.size.height / 2));
      await rightClickAt(tester, p2Global);

      // Selection must be collapsed (caret) at the new position.
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(controller.selection!.base.nodeId, 'p2');
    });

    testWidgets('right-click is no-op when enabled is false', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      var callbackCount = 0;
      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          enabled: false,
          onSecondaryTapDown: (_) => callbackCount++,
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      await rightClickAt(tester, rect.center);

      expect(callbackCount, 0);
      expect(controller.selection, isNull);
    });

    testWidgets('right-click is no-op when onSecondaryTapDown is null', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      // No onSecondaryTapDown callback provided.
      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      // Should not throw and should not change controller state.
      await rightClickAt(tester, rect.center);

      expect(controller.selection, isNull);
    });

    testWidgets('right-click requests focus when focusNode is provided', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          focusNode: focusNode,
          onSecondaryTapDown: (_) {},
        ),
      );
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      await rightClickAt(tester, rect.center);

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('right-click inside multi-node selection preserves expanded selection', (
      tester,
    ) async {
      // Two nodes; selection spans both.  Right-clicking inside the selection
      // should keep it expanded (exercises the multi-node branch of
      // _isPositionInsideSelection).
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
        ParagraphNode(id: 'p2', text: AttributedText('world')),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          onSecondaryTapDown: (_) {},
        ),
      );
      await tester.pump();

      // Select p1 offset 0 → p2 offset 5 (entire two-node range).
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'p2',
            nodePosition: TextNodePosition(offset: 5),
          ),
        ),
      );
      await tester.pump();

      // Right-click inside p1 (which is inside the selection).
      final p1Component = layoutKey.currentState!.componentForNode('p1')!;
      final p1Box = p1Component as RenderBox;
      final p1Global = p1Box.localToGlobal(Offset(p1Box.size.width / 2, p1Box.size.height / 2));
      await rightClickAt(tester, p1Global);

      // Selection must stay expanded.
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isExpanded, isTrue);
    });
  });

  // =========================================================================
  // 7. Triple-tap selects entire block
  // =========================================================================

  group('DocumentMouseInteractor — triple-tap', () {
    testWidgets('triple-tap selects the entire text block', (tester) async {
      const text = 'Hello world';
      final doc = _singleParagraph(text);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(controller: controller, layoutKey: layoutKey, doc: doc),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final tapPos = rect.centerLeft + const Offset(10, 0);

      // Three taps in quick succession.  Taps 1+2 fire onDoubleTapDown (word
      // selection + sets triple-tap flag).  Tap 3 arrives as onTapDown after
      // the DoubleTapGestureRecognizer's ~300 ms window expires.
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      // Pump past the double-tap timeout (300 ms) so tap 3's onTapDown fires,
      // and past the triple-tap flag timer (600 ms) so no pending timers remain.
      await tester.pump(const Duration(milliseconds: 700));

      expect(controller.selection, isNotNull);
      expect(controller.selection!.base.nodeId, 'p1');
      expect(controller.selection!.extent.nodeId, 'p1');

      final basePos = controller.selection!.base.nodePosition as TextNodePosition;
      final extentPos = controller.selection!.extent.nodePosition as TextNodePosition;
      expect(basePos.offset, 0);
      expect(extentPos.offset, text.length);
    });

    testWidgets('triple-tap timer expiry resets triple-tap state', (tester) async {
      // After two taps, wait longer than the triple-tap window (600 ms) before
      // the third tap so the flag is cleared.  The third tap should then just
      // collapse the selection rather than selecting the block.
      const text = 'Hello world';
      final doc = _singleParagraph(text);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(controller: controller, layoutKey: layoutKey, doc: doc),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final tapPos = rect.centerLeft + const Offset(10, 0);

      // Taps 1 + 2 — double-tap.
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      // Pump past the triple-tap window so the flag is cleared.
      await tester.pump(const Duration(milliseconds: 700));

      // Tap 3 — should NOT produce full-block selection.
      await tester.tapAt(tapPos);
      await tester.pump(_tapSettleDuration);

      // After the flag expired, the third tap is just a plain tap → collapsed.
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
    });
  });

  // =========================================================================
  // 8. Shift+tap extends selection
  // =========================================================================

  group('DocumentMouseInteractor — shift+tap', () {
    testWidgets('shift+tap extends existing selection base to new extent', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      // Pre-set a collapsed selection at offset 0.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      await tester.pumpWidget(
        _buildInteractor(controller: controller, layoutKey: layoutKey, doc: doc),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));

      // Hold Shift, tap somewhere to the right to extend the selection.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.tapAt(rect.centerLeft + const Offset(60, 0));
      await tester.pump(_tapSettleDuration);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(controller.selection, isNotNull);
      // Base should remain at offset 0 (the original anchor).
      expect(controller.selection!.base.nodeId, 'p1');
      expect(
        (controller.selection!.base.nodePosition as TextNodePosition).offset,
        0,
      );
      // Extent must be beyond the original position (selection is expanded).
      expect(controller.selection!.isExpanded, isTrue);
    });

    testWidgets('shift+tap with no prior selection creates collapsed selection', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(controller: controller, layoutKey: layoutKey, doc: doc),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));

      // No prior selection — shift+tap should produce a collapsed selection
      // (the _isShiftPressed branch falls back to collapsed when selection is null).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.tapAt(rect.centerLeft + const Offset(10, 0));
      await tester.pump(_tapSettleDuration);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
    });
  });

  // =========================================================================
  // 9. Mouse cursor
  // =========================================================================

  group('DocumentMouseInteractor — mouse cursor', () {
    testWidgets('MouseRegion cursor is SystemMouseCursors.text when enabled', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(controller: controller, layoutKey: layoutKey, doc: doc),
      );
      await tester.pump();

      final interactorFinder = find.byType(DocumentMouseInteractor);
      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: interactorFinder, matching: find.byType(MouseRegion)).first,
      );
      expect(mouseRegion.cursor, SystemMouseCursors.text);
    });

    testWidgets('MouseRegion cursor is SystemMouseCursors.basic when disabled', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          enabled: false,
        ),
      );
      await tester.pump();

      final interactorFinder = find.byType(DocumentMouseInteractor);
      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: interactorFinder, matching: find.byType(MouseRegion)).first,
      );
      expect(mouseRegion.cursor, SystemMouseCursors.basic);
    });

    testWidgets('custom cursor parameter is applied', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: DocumentMouseInteractor(
                controller: controller,
                layoutKey: layoutKey,
                document: doc,
                cursor: SystemMouseCursors.click,
                child: DocumentLayout(
                  key: layoutKey,
                  document: doc,
                  controller: controller,
                  componentBuilders: defaultComponentBuilders,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final interactorFinder = find.byType(DocumentMouseInteractor);
      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: interactorFinder, matching: find.byType(MouseRegion)).first,
      );
      expect(mouseRegion.cursor, SystemMouseCursors.click);
    });
  });

  // =========================================================================
  // 10. Pointer cancel clears drag state
  // =========================================================================

  group('DocumentMouseInteractor — pointer cancel', () {
    testWidgets('pointer cancel clears isDragging flag', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(controller: controller, layoutKey: layoutKey, doc: doc),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));

      // Start a drag gesture.
      final gesture = await tester.startGesture(
        rect.centerLeft + const Offset(5, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      // Move to establish a selection.
      await gesture.moveTo(rect.centerLeft + const Offset(50, 0));
      await tester.pump();

      expect(controller.selection, isNotNull);

      // Cancel rather than up — should not throw and should leave the widget
      // in a clean state (no pending drag).
      await gesture.cancel();
      await tester.pump(_tapSettleDuration);

      expect(tester.takeException(), isNull);
    });

    testWidgets('pointer cancel after no drag does not throw', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(controller: controller, layoutKey: layoutKey, doc: doc),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));

      // Touch-down then immediately cancel without moving.
      final gesture = await tester.startGesture(
        rect.center,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.cancel();
      await tester.pump(_tapSettleDuration);

      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // 11. Drag selection during disabled state
  // =========================================================================

  group('DocumentMouseInteractor — drag while disabled', () {
    testWidgets('drag when enabled:false produces no selection', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          enabled: false,
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final gesture = await tester.startGesture(
        rect.centerLeft + const Offset(5, 0),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(rect.center + const Offset(40, 0));
      await gesture.up();
      await tester.pump();

      expect(controller.selection, isNull);
    });
  });
}
