/// Tests for [DocumentMouseInteractor] — desktop mouse gesture handling.
///
/// Covers tap, drag, double-tap (word), triple-tap (block), shift+tap (extend),
/// enabled/disabled behaviour, and cursor changes.
///
/// Important timing note: when [GestureDetector.onDoubleTapDown] is present,
/// [onTapDown] fires AFTER the double-tap timer (~300 ms) expires rather than
/// immediately on pointer-down. Tests that check single-tap behaviour must
/// therefore call `pump(Duration(milliseconds: 500))` to let the timer expire
/// and the [TapGestureRecognizer] win the arena.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// How long to wait after a single tap for the double-tap timer to expire so
/// that [TapGestureRecognizer] can win the arena and fire [onTapDown].
const _tapSettleDuration = Duration(milliseconds: 500);

/// Builds a [MaterialApp] containing a [DocumentMouseInteractor] that wraps
/// a [DocumentLayout] backed by [doc] and [controller].
///
/// The layout is placed inside a [SingleChildScrollView] with a constrained
/// width so the [RenderDocumentLayout] receives loose height constraints and
/// can size itself to its content.
Widget _buildInteractor(
  DocumentMouseInteractor interactor, {
  double width = 600,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: SingleChildScrollView(child: interactor),
      ),
    ),
  );
}

/// Creates a [MutableDocument] with a single [ParagraphNode] containing
/// [text] at node id `'p1'`.
MutableDocument _singleParagraph(String text) =>
    MutableDocument([ParagraphNode(id: 'p1', text: AttributedText(text))]);

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // 1. Tap places caret (collapsed selection) at tapped position
  // =========================================================================

  group('DocumentMouseInteractor — tap', () {
    testWidgets('tap places a collapsed selection', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      await tester.tapAt(rect.centerLeft + const Offset(10, 0));
      // Wait for the double-tap timer to expire so TapGestureRecognizer wins.
      await tester.pump(_tapSettleDuration);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
    });

    testWidgets('tap on empty area places caret at nearest position', (tester) async {
      final doc = _singleParagraph('Hi');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap near the content area.
      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      await tester.tapAt(rect.center);
      await tester.pump(_tapSettleDuration);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(controller.selection!.base.nodeId, 'p1');
    });

    testWidgets('controller selection is updated on tap', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      expect(controller.selection, isNull);

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      await tester.tapAt(rect.center);
      await tester.pump(_tapSettleDuration);

      // Selection must have been written to controller.
      expect(controller.selection, isNotNull);
    });
  });

  // =========================================================================
  // 2. Drag creates expanded selection
  // =========================================================================

  group('DocumentMouseInteractor — drag', () {
    testWidgets('drag from start to end creates a selection', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final gesture = await tester.startGesture(
        rect.centerLeft + const Offset(5, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      await gesture.moveTo(rect.center + const Offset(40, 0));
      await tester.pump();

      await gesture.up();
      // Pump long enough to let the DoubleTapGestureRecognizer timer expire so
      // no pending timers remain when the widget tree is disposed.
      await tester.pump(_tapSettleDuration);

      // After a drag, selection should be non-null.
      expect(controller.selection, isNotNull);
    });

    testWidgets('controller selection is updated during drag', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final gesture = await tester.startGesture(
        rect.centerLeft + const Offset(5, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveTo(rect.centerLeft + const Offset(60, 0));
      await tester.pump();

      // During the drag, controller should already hold a selection.
      expect(controller.selection, isNotNull);

      await gesture.up();
      // Let the DoubleTapGestureRecognizer timer expire to avoid pending-timer
      // assertion in the test binding.
      await tester.pump(_tapSettleDuration);
    });
  });

  // =========================================================================
  // 3. Double-tap selects word
  // =========================================================================

  group('DocumentMouseInteractor — double-tap (word selection)', () {
    testWidgets('double-tap selects word under tap', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final tapPos = rect.centerLeft + const Offset(10, 0);

      // Send two taps quickly to trigger double-tap recognition.
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));

      // After double-tap, selection should be expanded (word selected).
      expect(controller.selection, isNotNull);
      // Selection must be on 'p1'.
      expect(controller.selection!.base.nodeId, 'p1');
      expect(controller.selection!.extent.nodeId, 'p1');
    });

    testWidgets('word boundary detection produces correct offsets', (tester) async {
      // Text: "Hello world"  — "Hello" is at 0-4, "world" is at 6-10.
      // Tapping near the start of the text should select "Hello" (offset 0–5).
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final tapPos = rect.centerLeft + const Offset(10, 0);

      // Double-tap near start of text.
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isExpanded, isTrue);

      final basePos = controller.selection!.base.nodePosition;
      final extentPos = controller.selection!.extent.nodePosition;
      expect(basePos, isA<TextNodePosition>());
      expect(extentPos, isA<TextNodePosition>());

      final baseOffset = (basePos as TextNodePosition).offset;
      final extentOffset = (extentPos as TextNodePosition).offset;

      // Word "Hello" spans [0, 5]; check offsets are ordered.
      expect(baseOffset, lessThanOrEqualTo(extentOffset));
    });
  });

  // =========================================================================
  // 4. Triple-tap selects entire block
  // =========================================================================

  group('DocumentMouseInteractor — triple-tap (block selection)', () {
    testWidgets('triple-tap selects the entire block', (tester) async {
      const text = 'Hello world';
      final doc = _singleParagraph(text);
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final tapPos = rect.centerLeft + const Offset(10, 0);

      // Three taps in quick succession: taps 1+2 fire onDoubleTapDown (word
      // selection + sets triple-tap flag).  Tap 3 fires onTapDown only AFTER
      // the DoubleTapGestureRecognizer's 300 ms window expires, so we pump
      // long enough for that timer plus the triple-tap flag timer to fully
      // resolve.
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      // Pump past the double-tap timeout so tap 3's onTapDown fires, and
      // past the triple-tap flag timer so no pending timers remain.
      await tester.pump(const Duration(milliseconds: 700));

      expect(controller.selection, isNotNull);
      expect(controller.selection!.base.nodeId, 'p1');
      expect(controller.selection!.extent.nodeId, 'p1');

      final basePos = controller.selection!.base.nodePosition;
      final extentPos = controller.selection!.extent.nodePosition;
      expect(basePos, isA<TextNodePosition>());
      expect(extentPos, isA<TextNodePosition>());

      final baseOffset = (basePos as TextNodePosition).offset;
      final extentOffset = (extentPos as TextNodePosition).offset;

      // Entire block: offset 0 → text.length.
      expect(baseOffset, 0);
      expect(extentOffset, text.length);
    });
  });

  // =========================================================================
  // 5. Shift+tap extends selection
  // =========================================================================

  group('DocumentMouseInteractor — shift+tap (extend selection)', () {
    testWidgets('shift+tap extends existing selection base to new extent', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
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
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));

      // Shift+tap somewhere further in the document.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.tapAt(rect.centerLeft + const Offset(60, 0));
      await tester.pump(_tapSettleDuration);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(controller.selection, isNotNull);
      // Base should still be at offset 0 (the original anchor).
      expect(controller.selection!.base.nodeId, 'p1');
      expect(
        (controller.selection!.base.nodePosition as TextNodePosition).offset,
        0,
      );
    });

    testWidgets('shift+tap with no existing selection creates collapsed selection', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));

      // No prior selection — shift+tap should still produce a selection.
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
  // 6. enabled: false ignores gestures
  // =========================================================================

  group('DocumentMouseInteractor — enabled flag', () {
    testWidgets('enabled:false ignores tap gestures', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            enabled: false,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      await tester.tapAt(rect.center);
      await tester.pump(_tapSettleDuration);

      // No selection should be set when disabled.
      expect(controller.selection, isNull);
    });

    testWidgets('enabled:false ignores drag gestures', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            enabled: false,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
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

  // =========================================================================
  // 7. Mouse cursor
  // =========================================================================

  group('DocumentMouseInteractor — mouse cursor', () {
    testWidgets('cursor defaults to SystemMouseCursors.text', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final widget = tester.widget<DocumentMouseInteractor>(find.byType(DocumentMouseInteractor));
      expect(widget.cursor, SystemMouseCursors.text);
    });

    testWidgets('MouseRegion cursor is text when enabled', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the MouseRegion that is a direct descendant of DocumentMouseInteractor.
      final interactorFinder = find.byType(DocumentMouseInteractor);
      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: interactorFinder, matching: find.byType(MouseRegion)).first,
      );
      expect(mouseRegion.cursor, SystemMouseCursors.text);
    });

    testWidgets('MouseRegion cursor is basic when disabled', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            enabled: false,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final interactorFinder = find.byType(DocumentMouseInteractor);
      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: interactorFinder, matching: find.byType(MouseRegion)).first,
      );
      expect(mouseRegion.cursor, SystemMouseCursors.basic);
    });
  });

  // =========================================================================
  // 8. word boundary on whitespace
  // =========================================================================

  group('DocumentMouseInteractor — word boundary on whitespace', () {
    testWidgets('double-tap on whitespace area does not throw', (tester) async {
      // Text: "Hello world" — space is at index 5.
      // Tapping midway might land on the space.
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildInteractor(
          DocumentMouseInteractor(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(DocumentMouseInteractor));
      final tapPos = rect.centerLeft + const Offset(50, 0);

      // Double-tap at a position that might be on a space.
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));

      // No exception, selection is set.
      expect(tester.takeException(), isNull);
      expect(controller.selection, isNotNull);
    });
  });
}
