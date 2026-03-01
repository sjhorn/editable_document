/// Tests for iOS gesture handling widgets — Phase 6.4.
///
/// Covers:
/// - [IosDocumentGestureController]: tap, double-tap, enabled flag
/// - [IOSCollapsedHandle]: renders, drag callbacks
/// - [IOSSelectionHandle]: renders left/right types, drag callbacks
/// - [IOSDocumentMagnifier]: renders at focal point, default magnification
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [MutableDocument] with a single [ParagraphNode].
MutableDocument _singleParagraph(String text) =>
    MutableDocument([ParagraphNode(id: 'p1', text: AttributedText(text))]);

/// Builds a widget tree containing an [IosDocumentGestureController] wrapping
/// a [DocumentLayout].
Widget _buildIosInteractor({
  required DocumentEditingController controller,
  required GlobalKey<DocumentLayoutState> layoutKey,
  required MutableDocument doc,
  bool enabled = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: IosDocumentGestureController(
            controller: controller,
            layoutKey: layoutKey,
            document: doc,
            enabled: enabled,
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // IosDocumentGestureController — tap places caret
  // =========================================================================

  group('IosDocumentGestureController — tap', () {
    testWidgets('tap places a collapsed selection', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildIosInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(IosDocumentGestureController));
      await tester.tapAt(rect.centerLeft + const Offset(10, 0));
      // Allow long-press timer to settle before asserting.
      await tester.pump(const Duration(milliseconds: 600));

      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isTrue);
    });

    testWidgets('tap updates controller selection', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      expect(controller.selection, isNull);

      await tester.pumpWidget(
        _buildIosInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(IosDocumentGestureController));
      await tester.tapAt(rect.center);
      await tester.pump(const Duration(milliseconds: 600));

      expect(controller.selection, isNotNull);
    });
  });

  // =========================================================================
  // IosDocumentGestureController — double-tap selects word
  // =========================================================================

  group('IosDocumentGestureController — double-tap', () {
    testWidgets('double-tap selects word', (tester) async {
      final doc = _singleParagraph('Hello world');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildIosInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(IosDocumentGestureController));
      final tapPos = rect.centerLeft + const Offset(10, 0);

      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPos);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection, isNotNull);
      expect(controller.selection!.base.nodeId, 'p1');
      expect(controller.selection!.extent.nodeId, 'p1');
    });
  });

  // =========================================================================
  // IosDocumentGestureController — enabled: false ignores gestures
  // =========================================================================

  group('IosDocumentGestureController — enabled flag', () {
    testWidgets('enabled:false ignores tap gestures', (tester) async {
      final doc = _singleParagraph('Hello');
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildIosInteractor(
          controller: controller,
          layoutKey: layoutKey,
          doc: doc,
          enabled: false,
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(IosDocumentGestureController));
      await tester.tapAt(rect.center);
      await tester.pump(const Duration(milliseconds: 600));

      expect(controller.selection, isNull);
    });
  });

  // =========================================================================
  // IOSCollapsedHandle — renders and drag callbacks fire
  // =========================================================================

  group('IOSCollapsedHandle', () {
    testWidgets('renders without error', (tester) async {
      final layerLink = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: layerLink,
              child: IOSCollapsedHandle(
                layerLink: layerLink,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(IOSCollapsedHandle), findsOneWidget);
    });

    testWidgets('onDragStart callback fires on drag start', (tester) async {
      final layerLink = LayerLink();
      var dragStarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: layerLink,
              child: IOSCollapsedHandle(
                layerLink: layerLink,
                color: Colors.blue,
                onDragStart: () {
                  dragStarted = true;
                },
              ),
            ),
          ),
        ),
      );

      // Start a drag gesture on the handle.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IOSCollapsedHandle)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(dragStarted, isTrue);
    });

    testWidgets('onDragUpdate callback fires during drag', (tester) async {
      final layerLink = LayerLink();
      var updateCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: layerLink,
              child: IOSCollapsedHandle(
                layerLink: layerLink,
                color: Colors.blue,
                onDragUpdate: (_) {
                  updateCount++;
                },
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IOSCollapsedHandle)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(updateCount, greaterThan(0));
    });

    testWidgets('onDragEnd callback fires on drag end', (tester) async {
      final layerLink = LayerLink();
      var dragEnded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: layerLink,
              child: IOSCollapsedHandle(
                layerLink: layerLink,
                color: Colors.blue,
                onDragEnd: () {
                  dragEnded = true;
                },
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IOSCollapsedHandle)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(dragEnded, isTrue);
    });
  });

  // =========================================================================
  // IOSSelectionHandle — renders left/right, drag callbacks
  // =========================================================================

  group('IOSSelectionHandle', () {
    testWidgets('renders left handle without error', (tester) async {
      final layerLink = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: layerLink,
              child: IOSSelectionHandle(
                layerLink: layerLink,
                type: HandleType.left,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(IOSSelectionHandle), findsOneWidget);
    });

    testWidgets('renders right handle without error', (tester) async {
      final layerLink = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: layerLink,
              child: IOSSelectionHandle(
                layerLink: layerLink,
                type: HandleType.right,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(IOSSelectionHandle), findsOneWidget);
    });

    testWidgets('onDragStart fires on drag', (tester) async {
      final layerLink = LayerLink();
      var dragStarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: layerLink,
              child: IOSSelectionHandle(
                layerLink: layerLink,
                type: HandleType.left,
                color: Colors.blue,
                onDragStart: () {
                  dragStarted = true;
                },
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IOSSelectionHandle)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(dragStarted, isTrue);
    });

    testWidgets('onDragUpdate fires during drag', (tester) async {
      final layerLink = LayerLink();
      var updateCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: layerLink,
              child: IOSSelectionHandle(
                layerLink: layerLink,
                type: HandleType.right,
                color: Colors.blue,
                onDragUpdate: (_) {
                  updateCount++;
                },
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IOSSelectionHandle)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(updateCount, greaterThan(0));
    });

    testWidgets('onDragEnd fires when drag ends', (tester) async {
      final layerLink = LayerLink();
      var dragEnded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: layerLink,
              child: IOSSelectionHandle(
                layerLink: layerLink,
                type: HandleType.left,
                color: Colors.blue,
                onDragEnd: () {
                  dragEnded = true;
                },
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IOSSelectionHandle)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(dragEnded, isTrue);
    });
  });

  // =========================================================================
  // IOSDocumentMagnifier — renders at focal point
  // =========================================================================

  group('IOSDocumentMagnifier', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: IOSDocumentMagnifier(
                focalPoint: Offset(100, 100),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(IOSDocumentMagnifier), findsOneWidget);
    });

    testWidgets('renders with default magnification 1.5', (tester) async {
      const magnifier = IOSDocumentMagnifier(focalPoint: Offset(50, 50));

      expect(magnifier.magnification, 1.5);
    });

    testWidgets('renders with default diameter 80', (tester) async {
      const magnifier = IOSDocumentMagnifier(focalPoint: Offset(50, 50));

      expect(magnifier.diameter, 80.0);
    });

    testWidgets('renders with custom magnification', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: IOSDocumentMagnifier(
                focalPoint: Offset(100, 100),
                magnification: 2.0,
                diameter: 100,
              ),
            ),
          ),
        ),
      );

      final widget = tester.widget<IOSDocumentMagnifier>(
        find.byType(IOSDocumentMagnifier),
      );
      expect(widget.magnification, 2.0);
      expect(widget.diameter, 100.0);
    });

    testWidgets('focalPoint is set correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: IOSDocumentMagnifier(
                focalPoint: Offset(200, 150),
              ),
            ),
          ),
        ),
      );

      final widget = tester.widget<IOSDocumentMagnifier>(
        find.byType(IOSDocumentMagnifier),
      );
      expect(widget.focalPoint, const Offset(200, 150));
    });
  });
}
