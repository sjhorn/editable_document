/// Tests for [DocumentScrollable] — Phase 7.
///
/// Covers scroll controller management, bringDocumentPositionIntoView,
/// selection-change auto-scroll, scroll padding, and external controller usage.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [MutableDocument] with [count] paragraphs, each containing
/// enough text to produce a block with meaningful height.
MutableDocument _makeDocument({int count = 1, String prefix = 'Paragraph'}) {
  return MutableDocument([
    for (int i = 0; i < count; i++) ParagraphNode(id: 'p$i', text: AttributedText('$prefix $i')),
  ]);
}

/// Creates a [DocumentEditingController] wrapping [doc].
DocumentEditingController _makeController(MutableDocument doc) =>
    DocumentEditingController(document: doc);

/// Wraps [child] in a [MaterialApp] + [Scaffold] constrained to [width] x
/// [height] to simulate a viewport smaller than document content.
Widget _wrap(Widget child, {double width = 600, double height = 300}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: width, height: height, child: child),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Construction
  // -------------------------------------------------------------------------

  group('DocumentScrollable — construction', () {
    testWidgets('builds without error with minimal parameters', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      expect(find.byType(DocumentScrollable), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a SingleChildScrollView', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('renders child widget', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      expect(find.byType(DocumentLayout), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // ScrollController management
  // -------------------------------------------------------------------------

  group('DocumentScrollable — ScrollController management', () {
    testWidgets('creates internal ScrollController when none provided', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final scrollableKey = GlobalKey<DocumentScrollableState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            key: scrollableKey,
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      expect(scrollableKey.currentState!.effectiveScrollController, isNotNull);
    });

    testWidgets('uses external ScrollController when provided', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final scrollableKey = GlobalKey<DocumentScrollableState>();
      final externalScrollController = ScrollController();
      addTearDown(externalScrollController.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            key: scrollableKey,
            controller: controller,
            layoutKey: layoutKey,
            scrollController: externalScrollController,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      expect(
        scrollableKey.currentState!.effectiveScrollController,
        same(externalScrollController),
      );
    });

    testWidgets('disposes internal ScrollController on widget disposal', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final scrollableKey = GlobalKey<DocumentScrollableState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            key: scrollableKey,
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      // Capture the internal controller before disposal.
      final internalController = scrollableKey.currentState!.effectiveScrollController;

      // Unmount the widget.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // The internal controller should have been disposed — using it will throw
      // an AssertionError (in debug mode) because the ChangeNotifier is disposed.
      expect(() => internalController.offset, throwsA(isA<AssertionError>()));
    });

    testWidgets('does not dispose external ScrollController on widget disposal', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final externalScrollController = ScrollController();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller,
            layoutKey: layoutKey,
            scrollController: externalScrollController,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      // Unmount the widget.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // External controller should still be usable — hasClients is false
      // because it is detached, but it should NOT be disposed (no throw on
      // hasClients or hasListeners).
      expect(externalScrollController.hasClients, isFalse);
      // Calling dispose() should not throw (double-dispose would).
      externalScrollController.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // scrollDirection and physics
  // -------------------------------------------------------------------------

  group('DocumentScrollable — scrollDirection and physics', () {
    testWidgets('defaults to vertical scroll direction', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.scrollDirection, Axis.vertical);
    });

    testWidgets('passes scrollDirection to SingleChildScrollView', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      // Use a simple SizedBox child rather than DocumentLayout because
      // RenderDocumentLayout does not handle unbounded width constraints
      // from horizontal scrolling.
      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller,
            layoutKey: layoutKey,
            scrollDirection: Axis.horizontal,
            child: const SizedBox(width: 1000, height: 300),
          ),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.scrollDirection, Axis.horizontal);
    });

    testWidgets('passes custom physics to SingleChildScrollView', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      const physics = BouncingScrollPhysics();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller,
            layoutKey: layoutKey,
            physics: physics,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.physics, isA<BouncingScrollPhysics>());
    });
  });

  // -------------------------------------------------------------------------
  // bringDocumentPositionIntoView
  // -------------------------------------------------------------------------

  group('DocumentScrollable — bringDocumentPositionIntoView', () {
    testWidgets('jumpTo scrolls when animate is false', (tester) async {
      // Create a document with many paragraphs so content is taller than
      // the 200px viewport.
      final doc = _makeDocument(count: 20);
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final scrollableKey = GlobalKey<DocumentScrollableState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            key: scrollableKey,
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
          height: 200,
        ),
      );

      // Verify we can scroll to the last paragraph without animate.
      final lastPosition = const DocumentPosition(
        nodeId: 'p19',
        nodePosition: TextNodePosition(offset: 0),
      );

      scrollableKey.currentState!.bringDocumentPositionIntoView(
        lastPosition,
        animate: false,
      );
      await tester.pump();

      // Scroll offset should have changed from zero.
      expect(scrollableKey.currentState!.effectiveScrollController.offset, greaterThan(0.0));
    });

    testWidgets('animateTo scrolls when animate is true', (tester) async {
      final doc = _makeDocument(count: 20);
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final scrollableKey = GlobalKey<DocumentScrollableState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            key: scrollableKey,
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
          height: 200,
        ),
      );

      final lastPosition = const DocumentPosition(
        nodeId: 'p19',
        nodePosition: TextNodePosition(offset: 0),
      );

      scrollableKey.currentState!.bringDocumentPositionIntoView(
        lastPosition,
        animate: true,
      );
      // Pump enough frames to complete the animation.
      await tester.pumpAndSettle();

      expect(scrollableKey.currentState!.effectiveScrollController.offset, greaterThan(0.0));
    });

    testWidgets('no-ops gracefully when layoutKey has no state', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      // A layout key that is never attached to any widget.
      final detachedLayoutKey = GlobalKey<DocumentLayoutState>();
      final scrollableKey = GlobalKey<DocumentScrollableState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            key: scrollableKey,
            controller: controller,
            layoutKey: detachedLayoutKey,
            child: const SizedBox(height: 1000),
          ),
        ),
      );

      // Should not throw even though layoutKey has no state.
      expect(
        () => scrollableKey.currentState!.bringDocumentPositionIntoView(
          const DocumentPosition(
            nodeId: 'p0',
            nodePosition: TextNodePosition(offset: 0),
          ),
          animate: false,
        ),
        returnsNormally,
      );
    });

    testWidgets('position already in view does not scroll unnecessarily', (tester) async {
      final doc = _makeDocument(count: 3);
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final scrollableKey = GlobalKey<DocumentScrollableState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            key: scrollableKey,
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
          height: 600,
        ),
      );

      // First paragraph is already in view (viewport is 600px tall).
      scrollableKey.currentState!.bringDocumentPositionIntoView(
        const DocumentPosition(
          nodeId: 'p0',
          nodePosition: TextNodePosition(offset: 0),
        ),
        animate: false,
      );
      await tester.pump();

      // Offset should remain at (or near) 0.
      expect(
        scrollableKey.currentState!.effectiveScrollController.offset,
        lessThanOrEqualTo(0.0),
      );
    });
  });

  // -------------------------------------------------------------------------
  // scrollPadding
  // -------------------------------------------------------------------------

  group('DocumentScrollable — scrollPadding', () {
    testWidgets('default scrollPadding is EdgeInsets.all(20)', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      final scrollable = tester.widget<DocumentScrollable>(
        find.byType(DocumentScrollable),
      );
      expect(scrollable.scrollPadding, const EdgeInsets.all(20.0));
    });

    testWidgets('custom scrollPadding stored on widget', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      const padding = EdgeInsets.all(40.0);

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller,
            layoutKey: layoutKey,
            scrollPadding: padding,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      final scrollable = tester.widget<DocumentScrollable>(
        find.byType(DocumentScrollable),
      );
      expect(scrollable.scrollPadding, padding);
    });

    testWidgets('larger scrollPadding causes greater scroll offset for caret near edge',
        (tester) async {
      // Build two side-by-side versions: small padding vs large padding.
      // After scrolling to the last position, larger padding should produce
      // a larger (or equal) offset because it pulls more content into view.
      final doc = _makeDocument(count: 20);
      final controller1 = _makeController(doc);
      final controller2 = _makeController(doc);
      addTearDown(controller1.dispose);
      addTearDown(controller2.dispose);

      final layoutKey1 = GlobalKey<DocumentLayoutState>();
      final layoutKey2 = GlobalKey<DocumentLayoutState>();
      final scrollableKey1 = GlobalKey<DocumentScrollableState>();
      final scrollableKey2 = GlobalKey<DocumentScrollableState>();

      // Small padding version.
      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            key: scrollableKey1,
            controller: controller1,
            layoutKey: layoutKey1,
            scrollPadding: EdgeInsets.zero,
            child: DocumentLayout(
              key: layoutKey1,
              document: doc,
              controller: controller1,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
          height: 200,
        ),
      );

      final lastPosition = const DocumentPosition(
        nodeId: 'p19',
        nodePosition: TextNodePosition(offset: 0),
      );

      scrollableKey1.currentState!.bringDocumentPositionIntoView(lastPosition, animate: false);
      await tester.pump();
      final offsetWithSmallPadding = scrollableKey1.currentState!.effectiveScrollController.offset;

      // Large padding version.
      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            key: scrollableKey2,
            controller: controller2,
            layoutKey: layoutKey2,
            scrollPadding: const EdgeInsets.all(50.0),
            child: DocumentLayout(
              key: layoutKey2,
              document: doc,
              controller: controller2,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
          height: 200,
        ),
      );

      scrollableKey2.currentState!.bringDocumentPositionIntoView(lastPosition, animate: false);
      await tester.pump();
      final offsetWithLargePadding = scrollableKey2.currentState!.effectiveScrollController.offset;

      // Larger padding means we need to scroll further.
      expect(offsetWithLargePadding, greaterThanOrEqualTo(offsetWithSmallPadding));
    });
  });

  // -------------------------------------------------------------------------
  // Selection-change auto-scroll
  // -------------------------------------------------------------------------

  group('DocumentScrollable — selection-change auto-scroll', () {
    testWidgets('scrolls when selection changes to position below viewport', (tester) async {
      final doc = _makeDocument(count: 20);
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final scrollableKey = GlobalKey<DocumentScrollableState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            key: scrollableKey,
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
          height: 200,
        ),
      );

      // Confirm we start at top.
      expect(scrollableKey.currentState!.effectiveScrollController.offset, 0.0);

      // Move selection to the last paragraph.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p19',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      // Wait for post-frame callback to fire.
      await tester.pumpAndSettle();

      expect(scrollableKey.currentState!.effectiveScrollController.offset, greaterThan(0.0));
    });

    testWidgets('does not scroll when selection is null', (tester) async {
      final doc = _makeDocument(count: 20);
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      final scrollableKey = GlobalKey<DocumentScrollableState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            key: scrollableKey,
            controller: controller,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
          height: 200,
        ),
      );

      // Set selection then clear it — offset should not jump.
      controller.setSelection(null);
      await tester.pumpAndSettle();

      expect(scrollableKey.currentState!.effectiveScrollController.offset, 0.0);
    });

    testWidgets('unsubscribes from controller on didUpdateWidget', (tester) async {
      final doc = _makeDocument(count: 5);
      final controller1 = _makeController(doc);
      final controller2 = _makeController(doc);
      addTearDown(controller1.dispose);
      addTearDown(controller2.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller1,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller1,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      // Swap to controller2.
      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller2,
            layoutKey: layoutKey,
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller2,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      // Notifying controller1 after swap should not throw.
      expect(() => controller1.setSelection(null), returnsNormally);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // debugFillProperties
  // -------------------------------------------------------------------------

  group('DocumentScrollable — debugFillProperties', () {
    testWidgets('widget has expected diagnostics', (tester) async {
      final doc = _makeDocument();
      final controller = _makeController(doc);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          DocumentScrollable(
            controller: controller,
            layoutKey: layoutKey,
            scrollPadding: const EdgeInsets.all(10.0),
            child: DocumentLayout(
              key: layoutKey,
              document: doc,
              controller: controller,
              componentBuilders: defaultComponentBuilders,
            ),
          ),
        ),
      );

      final element = tester.element(find.byType(DocumentScrollable));
      final widget = element.widget as DocumentScrollable;

      // The widget should carry the expected property values.
      expect(widget.scrollPadding, const EdgeInsets.all(10.0));
      expect(widget.scrollDirection, Axis.vertical);
    });
  });
}
