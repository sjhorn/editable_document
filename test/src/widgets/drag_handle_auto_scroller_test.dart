/// Tests for [DragHandleAutoScroller] — Phase 7.
///
/// Covers:
/// - [DragHandleAutoScroller.of] returns state from descendant
/// - auto-scroll activates when drag position is near the viewport edge
/// - auto-scroll stops when [DragHandleAutoScrollerState.stopAutoScroll] is called
/// - scroll velocity is proportional to how deep the drag is into the auto-scroll zone
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in a constrained [MaterialApp] + [Scaffold].
Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        height: 400,
        child: child,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // DragHandleAutoScroller.of — lookup
  // =========================================================================

  group('DragHandleAutoScroller.of', () {
    testWidgets('returns null when no ancestor is present', (tester) async {
      DragHandleAutoScrollerState? found;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              found = DragHandleAutoScroller.of(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(found, isNull);
    });

    testWidgets('returns non-null from a direct descendant', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      DragHandleAutoScrollerState? found;

      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: scrollController,
            child: DragHandleAutoScroller(
              scrollController: scrollController,
              child: Builder(
                builder: (ctx) {
                  found = DragHandleAutoScroller.of(ctx);
                  return const SizedBox(height: 2000);
                },
              ),
            ),
          ),
        ),
      );

      expect(found, isNotNull);
    });

    testWidgets('returns non-null from a deeply nested descendant', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      DragHandleAutoScrollerState? found;

      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: scrollController,
            child: DragHandleAutoScroller(
              scrollController: scrollController,
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  Builder(
                    builder: (ctx) {
                      found = DragHandleAutoScroller.of(ctx);
                      return const SizedBox(height: 100);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(found, isNotNull);
    });
  });

  // =========================================================================
  // DragHandleAutoScroller — construction
  // =========================================================================

  group('DragHandleAutoScroller — construction', () {
    testWidgets('renders child without error', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: scrollController,
            child: DragHandleAutoScroller(
              scrollController: scrollController,
              child: const SizedBox(height: 2000, child: Placeholder()),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DragHandleAutoScroller), findsOneWidget);
    });

    testWidgets('default autoScrollAreaExtent is 50.0', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: scrollController,
            child: DragHandleAutoScroller(
              scrollController: scrollController,
              child: const SizedBox(height: 2000),
            ),
          ),
        ),
      );

      final widget = tester.widget<DragHandleAutoScroller>(
        find.byType(DragHandleAutoScroller),
      );
      expect(widget.autoScrollAreaExtent, 50.0);
    });

    testWidgets('custom autoScrollAreaExtent is stored', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: scrollController,
            child: DragHandleAutoScroller(
              scrollController: scrollController,
              autoScrollAreaExtent: 80.0,
              child: const SizedBox(height: 2000),
            ),
          ),
        ),
      );

      final widget = tester.widget<DragHandleAutoScroller>(
        find.byType(DragHandleAutoScroller),
      );
      expect(widget.autoScrollAreaExtent, 80.0);
    });
  });

  // =========================================================================
  // DragHandleAutoScroller — stopAutoScroll stops scrolling
  // =========================================================================

  group('DragHandleAutoScroller — stopAutoScroll', () {
    testWidgets('stopAutoScroll can be called without error when not scrolling', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      DragHandleAutoScrollerState? state;

      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: scrollController,
            child: DragHandleAutoScroller(
              scrollController: scrollController,
              child: Builder(
                builder: (ctx) {
                  state = DragHandleAutoScroller.of(ctx);
                  return const SizedBox(height: 2000);
                },
              ),
            ),
          ),
        ),
      );

      expect(() => state!.stopAutoScroll(), returnsNormally);
    });

    testWidgets('after stopAutoScroll scroll offset does not change on pump', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      DragHandleAutoScrollerState? state;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SingleChildScrollView(
                controller: scrollController,
                child: DragHandleAutoScroller(
                  scrollController: scrollController,
                  autoScrollAreaExtent: 50.0,
                  child: Builder(
                    builder: (ctx) {
                      state = DragHandleAutoScroller.of(ctx);
                      return const SizedBox(height: 2000);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Position near bottom edge of 400px viewport: y = 380 (into bottom zone)
      // The widget is positioned at the top of the screen, so global y ≈ local y.
      final box = tester.renderObject<RenderBox>(find.byType(DragHandleAutoScroller));
      final globalTopLeft = box.localToGlobal(Offset.zero);
      final globalBottomEdge = globalTopLeft.dy + box.size.height;
      final nearBottom = Offset(globalTopLeft.dx + 100, globalBottomEdge - 20);

      // Start and immediately stop.
      state!.startAutoScroll(nearBottom);
      state!.stopAutoScroll();

      final offsetBefore = scrollController.offset;
      await tester.pump(const Duration(milliseconds: 200));
      final offsetAfter = scrollController.offset;

      expect(offsetAfter, equals(offsetBefore));
    });
  });

  // =========================================================================
  // DragHandleAutoScroller — updateAutoScroll / velocity
  // =========================================================================

  group('DragHandleAutoScroller — updateAutoScroll', () {
    testWidgets('updateAutoScroll outside zone does not scroll', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      DragHandleAutoScrollerState? state;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SingleChildScrollView(
                controller: scrollController,
                child: DragHandleAutoScroller(
                  scrollController: scrollController,
                  autoScrollAreaExtent: 50.0,
                  child: Builder(
                    builder: (ctx) {
                      state = DragHandleAutoScroller.of(ctx);
                      return const SizedBox(height: 2000);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Center of a 400px viewport — well outside the 50px auto-scroll zones.
      final box = tester.renderObject<RenderBox>(find.byType(DragHandleAutoScroller));
      final globalCenter = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));

      state!.startAutoScroll(globalCenter);
      state!.updateAutoScroll(globalCenter);

      final offsetBefore = scrollController.offset;
      await tester.pump(const Duration(milliseconds: 100));
      final offsetAfter = scrollController.offset;

      state!.stopAutoScroll();
      expect(offsetAfter, equals(offsetBefore));
    });

    testWidgets('scroll offset increases when dragging near bottom edge', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      DragHandleAutoScrollerState? state;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SingleChildScrollView(
                controller: scrollController,
                child: DragHandleAutoScroller(
                  scrollController: scrollController,
                  autoScrollAreaExtent: 50.0,
                  child: Builder(
                    builder: (ctx) {
                      state = DragHandleAutoScroller.of(ctx);
                      return const SizedBox(height: 2000);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final box = tester.renderObject<RenderBox>(find.byType(DragHandleAutoScroller));
      final globalTopLeft = box.localToGlobal(Offset.zero);
      final globalBottomEdge = globalTopLeft.dy + box.size.height;
      // Place the drag position 10 pixels above the bottom edge (deep in zone).
      final nearBottom = Offset(globalTopLeft.dx + 100, globalBottomEdge - 10);

      state!.startAutoScroll(nearBottom);
      state!.updateAutoScroll(nearBottom);

      // Pump several frames so the ticker advances.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      state!.stopAutoScroll();

      expect(scrollController.offset, greaterThan(0.0));
    });

    testWidgets('scroll offset decreases when dragging near top edge', (tester) async {
      final scrollController = ScrollController(initialScrollOffset: 500.0);
      addTearDown(scrollController.dispose);

      DragHandleAutoScrollerState? state;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SingleChildScrollView(
                controller: scrollController,
                child: DragHandleAutoScroller(
                  scrollController: scrollController,
                  autoScrollAreaExtent: 50.0,
                  child: Builder(
                    builder: (ctx) {
                      state = DragHandleAutoScroller.of(ctx);
                      return const SizedBox(height: 2000);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Ensure initial scroll position is applied.
      await tester.pump();

      final box = tester.renderObject<RenderBox>(find.byType(DragHandleAutoScroller));
      final globalTopLeft = box.localToGlobal(Offset.zero);
      // Place the drag position 10 pixels below the top edge (deep in top zone).
      final nearTop = Offset(globalTopLeft.dx + 100, globalTopLeft.dy + 10);

      state!.startAutoScroll(nearTop);
      state!.updateAutoScroll(nearTop);

      final offsetBefore = scrollController.offset;

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      state!.stopAutoScroll();

      expect(scrollController.offset, lessThan(offsetBefore));
    });

    testWidgets('deeper into zone produces faster scroll than edge of zone', (tester) async {
      final scrollControllerShallow = ScrollController();
      final scrollControllerDeep = ScrollController();
      addTearDown(scrollControllerShallow.dispose);
      addTearDown(scrollControllerDeep.dispose);

      DragHandleAutoScrollerState? stateShallow;
      DragHandleAutoScrollerState? stateDeep;

      // Build the shallow-zone test widget.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SingleChildScrollView(
                controller: scrollControllerShallow,
                child: DragHandleAutoScroller(
                  scrollController: scrollControllerShallow,
                  autoScrollAreaExtent: 50.0,
                  child: Builder(
                    builder: (ctx) {
                      stateShallow = DragHandleAutoScroller.of(ctx);
                      return const SizedBox(height: 2000);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final boxShallow = tester.renderObject<RenderBox>(find.byType(DragHandleAutoScroller));
      final globalTopLeftShallow = boxShallow.localToGlobal(Offset.zero);
      final globalBottomEdgeShallow = globalTopLeftShallow.dy + boxShallow.size.height;

      // Shallow: 40px from the bottom edge — just inside the 50px zone.
      final shallowPos = Offset(
        globalTopLeftShallow.dx + 100,
        globalBottomEdgeShallow - 40,
      );

      stateShallow!.startAutoScroll(shallowPos);
      stateShallow!.updateAutoScroll(shallowPos);

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      stateShallow!.stopAutoScroll();
      final shallowOffset = scrollControllerShallow.offset;

      // Build the deep-zone test widget.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SingleChildScrollView(
                controller: scrollControllerDeep,
                child: DragHandleAutoScroller(
                  scrollController: scrollControllerDeep,
                  autoScrollAreaExtent: 50.0,
                  child: Builder(
                    builder: (ctx) {
                      stateDeep = DragHandleAutoScroller.of(ctx);
                      return const SizedBox(height: 2000);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final boxDeep = tester.renderObject<RenderBox>(find.byType(DragHandleAutoScroller));
      final globalTopLeftDeep = boxDeep.localToGlobal(Offset.zero);
      final globalBottomEdgeDeep = globalTopLeftDeep.dy + boxDeep.size.height;

      // Deep: 5px from the bottom edge — deep into the 50px zone.
      final deepPos = Offset(
        globalTopLeftDeep.dx + 100,
        globalBottomEdgeDeep - 5,
      );

      stateDeep!.startAutoScroll(deepPos);
      stateDeep!.updateAutoScroll(deepPos);

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      stateDeep!.stopAutoScroll();
      final deepOffset = scrollControllerDeep.offset;

      // The position deeper in the zone should have scrolled more.
      expect(deepOffset, greaterThan(shallowOffset));
    });
  });

  // =========================================================================
  // DragHandleAutoScroller — debugFillProperties
  // =========================================================================

  group('DragHandleAutoScroller — diagnostics', () {
    testWidgets('debugFillProperties includes scrollController and autoScrollAreaExtent',
        (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: scrollController,
            child: DragHandleAutoScroller(
              scrollController: scrollController,
              autoScrollAreaExtent: 75.0,
              child: const SizedBox(height: 2000),
            ),
          ),
        ),
      );

      final widget = tester.widget<DragHandleAutoScroller>(
        find.byType(DragHandleAutoScroller),
      );

      final builder = DiagnosticPropertiesBuilder();
      widget.debugFillProperties(builder);

      final names = builder.properties.map((p) => p.name).toList();
      expect(names, contains('scrollController'));
      expect(names, contains('autoScrollAreaExtent'));
    });
  });
}
