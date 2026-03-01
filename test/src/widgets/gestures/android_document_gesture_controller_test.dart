/// Tests for [AndroidDocumentGestureController].
///
/// Covers tap (collapse selection), double-tap (word select), and
/// enabled:false behaviour.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

/// Wraps the gesture controller + layout in a [MaterialApp] / [Scaffold].
Widget _buildController(
  AndroidDocumentGestureController controller, {
  double width = 600,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: SingleChildScrollView(child: controller),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // 1. Tap collapses selection
  // =========================================================================

  group('AndroidDocumentGestureController — tap', () {
    testWidgets('tap places a collapsed selection', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildController(
          AndroidDocumentGestureController(
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

      final rect = tester.getRect(find.byType(AndroidDocumentGestureController));
      await tester.tapAt(rect.centerLeft + const Offset(10, 0));
      await tester.pump(_tapSettleDuration);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
    });

    testWidgets('tap updates controller selection', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      expect(controller.selection, isNull);

      await tester.pumpWidget(
        _buildController(
          AndroidDocumentGestureController(
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

      final rect = tester.getRect(find.byType(AndroidDocumentGestureController));
      await tester.tapAt(rect.center);
      await tester.pump(_tapSettleDuration);

      expect(controller.selection, isNotNull);
      expect(controller.selection!.base.nodeId, 'p1');
    });
  });

  // =========================================================================
  // 2. Double-tap selects word
  // =========================================================================

  group('AndroidDocumentGestureController — double-tap', () {
    testWidgets('double-tap selects the word under tap', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildController(
          AndroidDocumentGestureController(
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

      final rect = tester.getRect(find.byType(AndroidDocumentGestureController));
      final tapPos = rect.centerLeft + const Offset(10, 0);

      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection, isNotNull);
      expect(controller.selection!.base.nodeId, 'p1');
      expect(controller.selection!.extent.nodeId, 'p1');
    });

    testWidgets('double-tap produces expanded selection', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildController(
          AndroidDocumentGestureController(
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

      final rect = tester.getRect(find.byType(AndroidDocumentGestureController));
      final tapPos = rect.centerLeft + const Offset(10, 0);

      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isExpanded, isTrue);
    });
  });

  // =========================================================================
  // 3. enabled:false ignores gestures
  // =========================================================================

  group('AndroidDocumentGestureController — enabled flag', () {
    testWidgets('enabled:false ignores tap', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildController(
          AndroidDocumentGestureController(
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

      final rect = tester.getRect(find.byType(AndroidDocumentGestureController));
      await tester.tapAt(rect.center);
      await tester.pump(_tapSettleDuration);

      expect(controller.selection, isNull);
    });

    testWidgets('enabled:false ignores double-tap', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildController(
          AndroidDocumentGestureController(
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

      final rect = tester.getRect(find.byType(AndroidDocumentGestureController));
      final tapPos = rect.centerLeft + const Offset(10, 0);

      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection, isNull);
    });
  });

  // =========================================================================
  // 4. Long-press shows magnifier and places caret
  // =========================================================================

  group('AndroidDocumentGestureController — long-press', () {
    testWidgets('long-press places a collapsed selection', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildController(
          AndroidDocumentGestureController(
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

      final rect = tester.getRect(find.byType(AndroidDocumentGestureController));
      final gesture = await tester.startGesture(rect.centerLeft + const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
    });

    testWidgets('long-press shows AndroidDocumentMagnifier', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildController(
          AndroidDocumentGestureController(
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

      final rect = tester.getRect(find.byType(AndroidDocumentGestureController));
      final gesture = await tester.startGesture(rect.centerLeft + const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(AndroidDocumentMagnifier), findsOneWidget);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('magnifier disappears after long-press up', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildController(
          AndroidDocumentGestureController(
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

      final rect = tester.getRect(find.byType(AndroidDocumentGestureController));
      final gesture = await tester.startGesture(rect.centerLeft + const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(AndroidDocumentMagnifier), findsOneWidget);

      await gesture.up();
      await tester.pump();

      expect(find.byType(AndroidDocumentMagnifier), findsNothing);
    });
  });

  // =========================================================================
  // 5. debugFillProperties
  // =========================================================================

  group('AndroidDocumentGestureController — diagnostics', () {
    testWidgets('debugFillProperties does not throw', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      final widget = AndroidDocumentGestureController(
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

      // Verify a 'enabled' flag property exists.
      expect(
        props.properties.any((p) => p.name == 'enabled'),
        isTrue,
      );
    });
  });
}
