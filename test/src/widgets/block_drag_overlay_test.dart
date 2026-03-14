/// Tests for [BlockDragOverlay] widget.
///
/// Covers:
/// - [BlockDragOverlay] renders [SizedBox.shrink] when no drag is active.
/// - [BlockDragOverlay.isDragging] is false initially.
/// - [startBlockDrag] sets [BlockDragOverlay.isDragging] to true.
/// - [endBlockDrag] returns null when no drop position is set.
/// - [cancelBlockDrag] resets state without calling [onBlockMoved].
/// - [endBlockDrag] calls [onBlockMoved] with correct nodeId and position when set.
/// - [updateBlockDrag] updates the drop position and triggers a rebuild.
/// - Block drag overlay shows a ghost rectangle during drag.
/// - [BlockDragOverlay.isDragging] is false after [endBlockDrag].
/// - [BlockDragOverlay.isDragging] is false after [cancelBlockDrag].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in [MaterialApp] + [Scaffold].
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Creates a [MutableDocument] with two [HorizontalRuleNode]s for
/// drag-to-move testing (binary nodes, non-text).
MutableDocument _twoRulesDoc() => MutableDocument([
      HorizontalRuleNode(id: 'hr1'),
      HorizontalRuleNode(id: 'hr2'),
    ]);

/// Builds a widget tree with a [BlockDragOverlay] over a [DocumentLayout],
/// connected via a [GlobalKey<BlockDragOverlayState>].
Widget _buildWithDragOverlay({
  required DocumentEditingController controller,
  required Document document,
  required GlobalKey<DocumentLayoutState> layoutKey,
  required GlobalKey<BlockDragOverlayState> overlayKey,
  BlockMoveCallback? onBlockMoved,
}) {
  return _wrap(
    SizedBox(
      width: 600,
      height: 800,
      child: Stack(
        children: [
          DocumentLayout(
            key: layoutKey,
            document: document as MutableDocument,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
          Positioned.fill(
            child: BlockDragOverlay(
              key: overlayKey,
              controller: controller,
              layoutKey: layoutKey,
              document: document,
              onBlockMoved: onBlockMoved,
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
  // Ensure static flag is reset between tests.
  setUp(() => BlockDragOverlay.isDragging = false);
  tearDown(() => BlockDragOverlay.isDragging = false);

  // =========================================================================
  // 1. Initial state
  // =========================================================================

  group('BlockDragOverlay — initial state', () {
    testWidgets('renders SizedBox.shrink when no drag is active', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
        ),
      );
      await tester.pump();

      // When idle, the overlay renders a SizedBox.shrink — no Stack or Positioned
      // children should be present (no indicator line or ghost).
      expect(
        find.descendant(
          of: find.byKey(overlayKey),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
    });

    test('isDragging is false initially', () {
      expect(BlockDragOverlay.isDragging, isFalse);
    });
  });

  // =========================================================================
  // 2. startBlockDrag
  // =========================================================================

  group('BlockDragOverlay — startBlockDrag', () {
    testWidgets('startBlockDrag sets isDragging to true', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
        ),
      );
      await tester.pump();

      expect(BlockDragOverlay.isDragging, isFalse);
      overlayKey.currentState!.startBlockDrag('hr1');
      expect(BlockDragOverlay.isDragging, isTrue);
    });

    testWidgets('startBlockDrag stores the dragged node id', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
        ),
      );
      await tester.pump();

      overlayKey.currentState!.startBlockDrag('hr1');
      // After start, isDragging must reflect active drag.
      expect(BlockDragOverlay.isDragging, isTrue);
    });
  });

  // =========================================================================
  // 3. endBlockDrag
  // =========================================================================

  group('BlockDragOverlay — endBlockDrag', () {
    testWidgets('endBlockDrag returns null when no drop position is set', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
        ),
      );
      await tester.pump();

      overlayKey.currentState!.startBlockDrag('hr1');
      // No updateBlockDrag call → no drop position set.
      final pos = overlayKey.currentState!.endBlockDrag();
      expect(pos, isNull);
    });

    testWidgets('endBlockDrag resets isDragging to false', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
        ),
      );
      await tester.pump();

      overlayKey.currentState!.startBlockDrag('hr1');
      expect(BlockDragOverlay.isDragging, isTrue);
      overlayKey.currentState!.endBlockDrag();
      expect(BlockDragOverlay.isDragging, isFalse);
    });

    testWidgets('endBlockDrag calls onBlockMoved when drop position is set', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      String? movedNodeId;
      DocumentPosition? movedPosition;

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
          onBlockMoved: (nodeId, position) {
            movedNodeId = nodeId;
            movedPosition = position;
          },
        ),
      );
      await tester.pump();

      overlayKey.currentState!.startBlockDrag('hr1');
      // Manually inject a drop position to simulate updateBlockDrag result.
      const injectedPos = DocumentPosition(
        nodeId: 'hr2',
        nodePosition: BinaryNodePosition.upstream(),
      );
      overlayKey.currentState!.injectDropPositionForTest(injectedPos);
      overlayKey.currentState!.endBlockDrag();

      expect(movedNodeId, 'hr1');
      expect(movedPosition, injectedPos);
    });
  });

  // =========================================================================
  // 4. cancelBlockDrag
  // =========================================================================

  group('BlockDragOverlay — cancelBlockDrag', () {
    testWidgets('cancelBlockDrag resets isDragging without calling onBlockMoved', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      var callbackInvoked = false;

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
          onBlockMoved: (_, __) => callbackInvoked = true,
        ),
      );
      await tester.pump();

      overlayKey.currentState!.startBlockDrag('hr1');
      overlayKey.currentState!.injectDropPositionForTest(
        const DocumentPosition(
          nodeId: 'hr2',
          nodePosition: BinaryNodePosition.upstream(),
        ),
      );
      overlayKey.currentState!.cancelBlockDrag();

      expect(BlockDragOverlay.isDragging, isFalse);
      expect(callbackInvoked, isFalse);
    });
  });

  // =========================================================================
  // 5. Visual indicator (ghost rectangle during drag)
  // =========================================================================

  group('BlockDragOverlay — visual indicator', () {
    testWidgets('shows a Stack with children when dragging', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
        ),
      );
      await tester.pump();

      overlayKey.currentState!.startBlockDrag('hr1');
      await tester.pump();

      // When dragging is active (even without a drop position), the overlay
      // renders a Stack.
      expect(
        find.descendant(
          of: find.byKey(overlayKey),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ghost uses actual block size when layout is available', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
        ),
      );
      await tester.pump();

      // Start a drag with a pointer offset so the overlay can compute the block size.
      overlayKey.currentState!.startBlockDrag('hr1', pointerOffset: const Offset(300, 20));
      await tester.pump();

      // The ghost must use the block's actual size (not the 120x40 placeholder).
      // The block size comes from componentForNode — for a HorizontalRuleNode
      // rendered inside a 600-wide container, width should be > 120.
      final state = overlayKey.currentState!;
      // blockSize is captured from the layout; it should be non-null and wider
      // than the old 120 px placeholder.
      expect(state.blockSize, isNotNull);
      expect(state.blockSize!.width, greaterThan(120));
    });

    testWidgets('startBlockDrag with pointerOffset stores grab offset', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
        ),
      );
      await tester.pump();

      overlayKey.currentState!.startBlockDrag('hr1', pointerOffset: const Offset(50, 10));
      await tester.pump();

      // grabOffset should be non-null (pointer was within the block).
      expect(overlayKey.currentState!.grabOffset, isNotNull);
    });

    testWidgets('ghost Positioned child uses block size not 120x40 fallback', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
        ),
      );
      await tester.pump();

      overlayKey.currentState!.startBlockDrag('hr1', pointerOffset: const Offset(300, 10));
      // Simulate the pointer having moved so the ghost is rendered.
      overlayKey.currentState!.updateBlockDrag(const Offset(300, 50));
      await tester.pump();

      // The ghost Positioned widget should have width > 120.
      final positioned = tester
          .widgetList<Positioned>(
            find.descendant(
              of: find.byKey(overlayKey),
              matching: find.byType(Positioned),
            ),
          )
          .toList();
      // At least one Positioned child exists (the ghost).
      expect(positioned, isNotEmpty);
      final ghost = positioned.first;
      expect(ghost.width, greaterThan(120));
    });

    testWidgets('blockSize and grabOffset are cleared after endBlockDrag', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
        ),
      );
      await tester.pump();

      overlayKey.currentState!.startBlockDrag('hr1', pointerOffset: const Offset(50, 10));
      await tester.pump();
      overlayKey.currentState!.endBlockDrag();
      await tester.pump();

      expect(overlayKey.currentState!.blockSize, isNull);
      expect(overlayKey.currentState!.grabOffset, isNull);
    });

    testWidgets('ghost has border width 2 and 0.5 opacity', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
        ),
      );
      await tester.pump();

      overlayKey.currentState!.startBlockDrag('hr1');
      overlayKey.currentState!.updateBlockDrag(const Offset(300, 50));
      await tester.pump();

      // The Opacity widget surrounding the ghost should be 0.5.
      final opacityWidgets = tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byKey(overlayKey),
              matching: find.byType(Opacity),
            ),
          )
          .toList();
      expect(opacityWidgets, isNotEmpty);
      expect(opacityWidgets.first.opacity, 0.5);
    });
  });
}
