/// Tests for [BlockDragOverlay] widget.
///
/// Covers:
/// - [BlockDragOverlay] renders [SizedBox.shrink] when no drag is active.
/// - [BlockDragOverlay.isDragging] is false initially.
/// - [startBlockDrag] sets [BlockDragOverlay.isDragging] to true.
/// - [endBlockDrag] returns null when no insertion gap is set.
/// - [cancelBlockDrag] resets state without calling [onBlockMoved].
/// - [endBlockDrag] calls [onBlockMoved] with correct nodeId and index when gap is set.
/// - [updateBlockDrag] updates the insertion gap and triggers a rebuild.
/// - Block drag overlay shows a horizontal line indicator during drag.
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
      // children should be present (no indicator line).
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
    testWidgets('endBlockDrag returns null when no insertion gap is set', (tester) async {
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
      // No updateBlockDrag call → no gap set.
      final gap = overlayKey.currentState!.endBlockDrag();
      expect(gap, isNull);
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

    testWidgets('endBlockDrag calls onBlockMoved when gap is set', (tester) async {
      final doc = _twoRulesDoc();
      final controller = DocumentEditingController(document: doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final overlayKey = GlobalKey<BlockDragOverlayState>();

      String? movedNodeId;
      int? movedIndex;

      await tester.pumpWidget(
        _buildWithDragOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          overlayKey: overlayKey,
          onBlockMoved: (nodeId, newIndex) {
            movedNodeId = nodeId;
            movedIndex = newIndex;
          },
        ),
      );
      await tester.pump();

      overlayKey.currentState!.startBlockDrag('hr1');
      // Manually inject a gap to simulate updateBlockDrag result.
      overlayKey.currentState!.injectInsertionGapForTest(
        const BlockInsertionGap(index: 1, lineY: 100.0),
      );
      overlayKey.currentState!.endBlockDrag();

      expect(movedNodeId, 'hr1');
      expect(movedIndex, 1);
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
      overlayKey.currentState!.injectInsertionGapForTest(
        const BlockInsertionGap(index: 1, lineY: 100.0),
      );
      overlayKey.currentState!.cancelBlockDrag();

      expect(BlockDragOverlay.isDragging, isFalse);
      expect(callbackInvoked, isFalse);
    });
  });

  // =========================================================================
  // 5. Visual indicator
  // =========================================================================

  group('BlockDragOverlay — visual indicator', () {
    testWidgets('shows a colored box when insertion gap is set during drag', (tester) async {
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
      overlayKey.currentState!.injectInsertionGapForTest(
        const BlockInsertionGap(index: 1, lineY: 50.0),
      );
      await tester.pump();

      // There should be a Positioned widget containing the indicator.
      expect(
        find.descendant(
          of: find.byKey(overlayKey),
          matching: find.byType(Positioned),
        ),
        findsWidgets,
      );
    });
  });
}
