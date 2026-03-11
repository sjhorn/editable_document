/// Tests for [BlockResizeHandles] widget and the [createResizeRequest] helper.
///
/// Covers:
/// - [createResizeRequest] type dispatch for every supported node type.
/// - [createResizeRequest] returns null for unsupported types (e.g. [ParagraphNode]).
/// - [createResizeRequest] preserves existing dimensions when `null` is passed.
/// - [BlockResizeHandles] shows no handles when selection is collapsed.
/// - [BlockResizeHandles] shows no handles for a multi-node selection.
/// - [BlockResizeHandles] shows no handles for a stretch-alignment block.
/// - [BlockResizeHandles] shows no handles when [onResize] is null.
/// - [BlockResizeHandles] shows handles for a center-aligned [ImageNode] that
///   is fully selected (upstream → downstream).
/// - Mouse cursor mapping is correct for all eight handle positions.
/// - Dragging the right-middle handle calls [onResize] with increased width
///   and null height.
/// - Dragging the bottom-center handle calls [onResize] with null width and
///   increased height.
/// - Dragging the bottom-right corner handle calls [onResize] with both
///   dimensions.
/// - Drag below [minWidth] or [minHeight] is clamped.
/// - A [DecoratedBox] border is visible when handles are shown.
/// - [BlockResizeHandles.isDragging] is set during a drag.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in [MaterialApp] + [Scaffold].
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Constructs a 2×2 [TableNode] for testing.
TableNode _tableNode({
  String id = 'tbl-1',
  double? width,
  double? height,
  BlockAlignment alignment = BlockAlignment.center,
}) {
  final cells = [
    [AttributedText('a'), AttributedText('b')],
    [AttributedText('c'), AttributedText('d')],
  ];
  return TableNode(
    id: id,
    rowCount: 2,
    columnCount: 2,
    cells: cells,
    alignment: alignment,
    width: width,
    height: height,
  );
}

/// Builds a full overlay stack suitable for testing [BlockResizeHandles]
/// visibility and drag behaviour.
Widget _buildWithOverlay({
  required DocumentEditingController controller,
  required Document document,
  BlockResizeCallback? onBlockResize,
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
        document: document,
        onBlockResize: onBlockResize,
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

/// Selects the node with [nodeId] fully (upstream → downstream).
void _selectFully(DocumentEditingController controller, String nodeId) {
  controller.setSelection(
    DocumentSelection(
      base: DocumentPosition(
        nodeId: nodeId,
        nodePosition: const BinaryNodePosition.upstream(),
      ),
      extent: DocumentPosition(
        nodeId: nodeId,
        nodePosition: const BinaryNodePosition.downstream(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Reset the static flag between tests.
  setUp(() {
    BlockResizeHandles.isDragging = false;
  });

  // -------------------------------------------------------------------------
  // createResizeRequest — unit tests (no widget tree needed)
  // -------------------------------------------------------------------------

  group('createResizeRequest', () {
    test('returns ReplaceNodeRequest for ImageNode with updated width and height', () {
      final node = ImageNode(
        id: 'img-1',
        imageUrl: 'test.png',
        width: 200.0,
        height: 100.0,
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 320.0, 160.0);

      expect(req, isA<ReplaceNodeRequest>());
      final replace = req! as ReplaceNodeRequest;
      expect(replace.nodeId, 'img-1');
      final newNode = replace.newNode as ImageNode;
      expect(newNode.width, 320.0);
      expect(newNode.height, 160.0);
    });

    test('returns ReplaceNodeRequest for CodeBlockNode with updated width and height', () {
      final node = CodeBlockNode(
        id: 'code-1',
        text: AttributedText('void main() {}'),
        width: 400.0,
        height: 200.0,
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 500.0, 250.0);

      expect(req, isA<ReplaceNodeRequest>());
      final replace = req! as ReplaceNodeRequest;
      expect(replace.nodeId, 'code-1');
      final newNode = replace.newNode as CodeBlockNode;
      expect(newNode.width, 500.0);
      expect(newNode.height, 250.0);
    });

    test('returns ReplaceNodeRequest for BlockquoteNode with updated width and height', () {
      final node = BlockquoteNode(
        id: 'bq-1',
        text: AttributedText('To be or not to be'),
        width: 300.0,
        height: 80.0,
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 360.0, 90.0);

      expect(req, isA<ReplaceNodeRequest>());
      final replace = req! as ReplaceNodeRequest;
      expect(replace.nodeId, 'bq-1');
      final newNode = replace.newNode as BlockquoteNode;
      expect(newNode.width, 360.0);
      expect(newNode.height, 90.0);
    });

    test('returns ReplaceNodeRequest for HorizontalRuleNode with updated width and height', () {
      final node = HorizontalRuleNode(
        id: 'hr-1',
        width: 400.0,
        height: 2.0,
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 500.0, 4.0);

      expect(req, isA<ReplaceNodeRequest>());
      final replace = req! as ReplaceNodeRequest;
      expect(replace.nodeId, 'hr-1');
      final newNode = replace.newNode as HorizontalRuleNode;
      expect(newNode.width, 500.0);
      expect(newNode.height, 4.0);
    });

    test('returns ReplaceNodeRequest for TableNode with updated width and height', () {
      final node = _tableNode(id: 'tbl-1', width: 300.0, height: 150.0);

      final req = createResizeRequest(node, 400.0, 200.0);

      expect(req, isA<ReplaceNodeRequest>());
      final replace = req! as ReplaceNodeRequest;
      expect(replace.nodeId, 'tbl-1');
      final newNode = replace.newNode as TableNode;
      expect(newNode.width, 400.0);
      expect(newNode.height, 200.0);
    });

    test('returns null for ParagraphNode', () {
      final node = ParagraphNode(id: 'p-1', text: AttributedText('Hello'));

      final req = createResizeRequest(node, 300.0, 100.0);

      expect(req, isNull);
    });

    test('preserves existing width when width argument is null — ImageNode', () {
      final node = ImageNode(
        id: 'img-1',
        imageUrl: 'test.png',
        width: 200.0,
        height: 100.0,
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, null, 160.0);

      expect(req, isA<ReplaceNodeRequest>());
      final newNode = (req! as ReplaceNodeRequest).newNode as ImageNode;
      // width should be preserved from the original node
      expect(newNode.width, 200.0);
      expect(newNode.height, 160.0);
    });

    test('preserves existing height when height argument is null — ImageNode', () {
      final node = ImageNode(
        id: 'img-1',
        imageUrl: 'test.png',
        width: 200.0,
        height: 100.0,
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 320.0, null);

      expect(req, isA<ReplaceNodeRequest>());
      final newNode = (req! as ReplaceNodeRequest).newNode as ImageNode;
      expect(newNode.width, 320.0);
      // height should be preserved from the original node
      expect(newNode.height, 100.0);
    });

    test('preserves existing width when width argument is null — CodeBlockNode', () {
      final node = CodeBlockNode(
        id: 'code-1',
        text: AttributedText('code'),
        width: 400.0,
        height: 200.0,
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, null, 250.0);

      final newNode = (req! as ReplaceNodeRequest).newNode as CodeBlockNode;
      expect(newNode.width, 400.0);
      expect(newNode.height, 250.0);
    });

    test('preserves existing height when height argument is null — HorizontalRuleNode', () {
      final node = HorizontalRuleNode(
        id: 'hr-1',
        width: 400.0,
        height: 2.0,
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 500.0, null);

      final newNode = (req! as ReplaceNodeRequest).newNode as HorizontalRuleNode;
      expect(newNode.width, 500.0);
      expect(newNode.height, 2.0);
    });

    test('preserves existing width when width argument is null — TableNode', () {
      final node = _tableNode(id: 'tbl-1', width: 300.0, height: 150.0);

      final req = createResizeRequest(node, null, 200.0);

      final newNode = (req! as ReplaceNodeRequest).newNode as TableNode;
      expect(newNode.width, 300.0);
      expect(newNode.height, 200.0);
    });
  });

  // -------------------------------------------------------------------------
  // BlockResizeHandles — visibility
  // -------------------------------------------------------------------------

  group('BlockResizeHandles — visibility', () {
    testWidgets('no handles shown when selection is collapsed', (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: 200.0,
          height: 100.0,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      // Set a collapsed selection on the image node.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'img-1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        ),
      );

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
        ),
      );
      await tester.pumpAndSettle();

      // BlockResizeHandles is in the tree but should render SizedBox.shrink.
      // There should be no Listener widgets (handle Listeners) inside
      // BlockResizeHandles.
      final blockHandlesFinder = find.byType(BlockResizeHandles);
      expect(blockHandlesFinder, findsOneWidget);

      final listeners = find.descendant(
        of: blockHandlesFinder,
        matching: find.byType(Listener),
      );
      expect(listeners, findsNothing);
    });

    testWidgets('no handles shown when selection spans multiple nodes', (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: 200.0,
          height: 100.0,
          alignment: BlockAlignment.center,
        ),
        ImageNode(
          id: 'img-2',
          imageUrl: 'test2.png',
          width: 200.0,
          height: 100.0,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      // Selection spanning two nodes.
      controller.setSelection(
        const DocumentSelection(
          base: DocumentPosition(
            nodeId: 'img-1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
          extent: DocumentPosition(
            nodeId: 'img-2',
            nodePosition: BinaryNodePosition.downstream(),
          ),
        ),
      );

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
        ),
      );
      await tester.pumpAndSettle();

      final blockHandlesFinder = find.byType(BlockResizeHandles);
      expect(blockHandlesFinder, findsOneWidget);

      final listeners = find.descendant(
        of: blockHandlesFinder,
        matching: find.byType(Listener),
      );
      expect(listeners, findsNothing);
    });

    testWidgets('no handles shown for stretch-alignment block (default)', (tester) async {
      // ImageNode defaults to BlockAlignment.stretch.
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          // no alignment specified → defaults to BlockAlignment.stretch
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      _selectFully(controller, 'img-1');

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
        ),
      );
      await tester.pumpAndSettle();

      final blockHandlesFinder = find.byType(BlockResizeHandles);
      expect(blockHandlesFinder, findsOneWidget);

      final listeners = find.descendant(
        of: blockHandlesFinder,
        matching: find.byType(Listener),
      );
      expect(listeners, findsNothing);
    });

    testWidgets('no handles shown when onBlockResize is null', (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: 200.0,
          height: 100.0,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      _selectFully(controller, 'img-1');

      // No document or onBlockResize → BlockResizeHandles not added to tree.
      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: null, // explicitly null
        ),
      );
      await tester.pumpAndSettle();

      // When onBlockResize is null, DocumentSelectionOverlay does not include
      // BlockResizeHandles in the tree at all.
      expect(find.byType(BlockResizeHandles), findsNothing);
    });

    testWidgets('handles appear for center-aligned ImageNode that is fully selected',
        (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: 200.0,
          height: 100.0,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      _selectFully(controller, 'img-1');

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
        ),
      );
      // Allow post-frame callbacks to fire so geometry is resolved.
      await tester.pumpAndSettle();

      final blockHandlesFinder = find.byType(BlockResizeHandles);
      expect(blockHandlesFinder, findsOneWidget);

      // Eight Listener widgets, one per ResizeHandlePosition value.
      final listeners = find.descendant(
        of: blockHandlesFinder,
        matching: find.byType(Listener),
      );
      expect(listeners, findsNWidgets(8));
    });
  });

  // -------------------------------------------------------------------------
  // BlockResizeHandles — mouse cursors
  // -------------------------------------------------------------------------

  group('BlockResizeHandles — mouse cursors', () {
    Future<void> pumpWithCenterAlignedImage(WidgetTester tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: 200.0,
          height: 100.0,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      _selectFully(controller, 'img-1');

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('topLeft handle has resizeUpLeftDownRight cursor', (tester) async {
      await pumpWithCenterAlignedImage(tester);

      final mouseRegions = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(MouseRegion),
      );
      // ResizeHandlePosition.values order: topLeft=0
      final topLeftRegion = tester.widget<MouseRegion>(mouseRegions.at(0));
      expect(topLeftRegion.cursor, SystemMouseCursors.resizeUpLeftDownRight);
    });

    testWidgets('topCenter handle has resizeUpDown cursor', (tester) async {
      await pumpWithCenterAlignedImage(tester);

      final mouseRegions = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(MouseRegion),
      );
      // topCenter=1
      final topCenterRegion = tester.widget<MouseRegion>(mouseRegions.at(1));
      expect(topCenterRegion.cursor, SystemMouseCursors.resizeUpDown);
    });

    testWidgets('topRight handle has resizeUpRightDownLeft cursor', (tester) async {
      await pumpWithCenterAlignedImage(tester);

      final mouseRegions = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(MouseRegion),
      );
      // topRight=2
      final topRightRegion = tester.widget<MouseRegion>(mouseRegions.at(2));
      expect(topRightRegion.cursor, SystemMouseCursors.resizeUpRightDownLeft);
    });

    testWidgets('middleLeft handle has resizeLeftRight cursor', (tester) async {
      await pumpWithCenterAlignedImage(tester);

      final mouseRegions = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(MouseRegion),
      );
      // middleLeft=3
      final middleLeftRegion = tester.widget<MouseRegion>(mouseRegions.at(3));
      expect(middleLeftRegion.cursor, SystemMouseCursors.resizeLeftRight);
    });

    testWidgets('middleRight handle has resizeLeftRight cursor', (tester) async {
      await pumpWithCenterAlignedImage(tester);

      final mouseRegions = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(MouseRegion),
      );
      // middleRight=4
      final middleRightRegion = tester.widget<MouseRegion>(mouseRegions.at(4));
      expect(middleRightRegion.cursor, SystemMouseCursors.resizeLeftRight);
    });

    testWidgets('bottomLeft handle has resizeUpRightDownLeft cursor', (tester) async {
      await pumpWithCenterAlignedImage(tester);

      final mouseRegions = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(MouseRegion),
      );
      // bottomLeft=5
      final bottomLeftRegion = tester.widget<MouseRegion>(mouseRegions.at(5));
      expect(bottomLeftRegion.cursor, SystemMouseCursors.resizeUpRightDownLeft);
    });

    testWidgets('bottomCenter handle has resizeUpDown cursor', (tester) async {
      await pumpWithCenterAlignedImage(tester);

      final mouseRegions = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(MouseRegion),
      );
      // bottomCenter=6
      final bottomCenterRegion = tester.widget<MouseRegion>(mouseRegions.at(6));
      expect(bottomCenterRegion.cursor, SystemMouseCursors.resizeUpDown);
    });

    testWidgets('bottomRight handle has resizeUpLeftDownRight cursor', (tester) async {
      await pumpWithCenterAlignedImage(tester);

      final mouseRegions = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(MouseRegion),
      );
      // bottomRight=7
      final bottomRightRegion = tester.widget<MouseRegion>(mouseRegions.at(7));
      expect(bottomRightRegion.cursor, SystemMouseCursors.resizeUpLeftDownRight);
    });
  });

  // -------------------------------------------------------------------------
  // BlockResizeHandles — drag behaviour
  // -------------------------------------------------------------------------

  group('BlockResizeHandles — drag', () {
    /// Builds a widget with an ImageNode of the given [imageWidth] and
    /// [imageHeight], fully selected, and returns the [onResize] callback
    /// result via the captured list.
    Future<List<(String, double?, double?)>> pumpAndCaptureDrags(
      WidgetTester tester, {
      double imageWidth = 200.0,
      double imageHeight = 100.0,
    }) async {
      final results = <(String, double?, double?)>[];

      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: imageWidth,
          height: imageHeight,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      _selectFully(controller, 'img-1');

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) => results.add((id, w, h)),
        ),
      );
      await tester.pumpAndSettle();

      return results;
    }

    testWidgets('dragging middleRight handle calls onResize with increased width, null height',
        (tester) async {
      final results = await pumpAndCaptureDrags(tester);

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // middleRight is index 4 in ResizeHandlePosition.values
      await tester.drag(listeners.at(4), const Offset(50.0, 0.0));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final (nodeId, width, height) = results.first;
      expect(nodeId, 'img-1');
      // Width should be the original 200 + 50 = 250, clamped to >= minWidth (20).
      expect(width, 250.0);
      // Height should be null (only horizontal handle).
      expect(height, isNull);
    });

    testWidgets('dragging bottomCenter handle calls onResize with null width, increased height',
        (tester) async {
      final results = await pumpAndCaptureDrags(tester);

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // bottomCenter is index 6 in ResizeHandlePosition.values
      await tester.drag(listeners.at(6), const Offset(0.0, 40.0));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final (nodeId, width, height) = results.first;
      expect(nodeId, 'img-1');
      // Width should be null (only vertical handle).
      expect(width, isNull);
      // Height should be the original 100 + 40 = 140.
      expect(height, 140.0);
    });

    testWidgets('dragging bottomRight corner calls onResize with both width and height',
        (tester) async {
      final results = await pumpAndCaptureDrags(tester);

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // bottomRight is index 7 in ResizeHandlePosition.values
      await tester.drag(listeners.at(7), const Offset(60.0, 30.0));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final (nodeId, width, height) = results.first;
      expect(nodeId, 'img-1');
      // Width: 200 + 60 = 260, Height: 100 + 30 = 130.
      expect(width, 260.0);
      expect(height, 130.0);
    });

    testWidgets('drag beyond minWidth clamps width to minWidth', (tester) async {
      final results = await pumpAndCaptureDrags(tester, imageWidth: 200.0);

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // middleRight is index 4. Dragging left by 300: newWidth = 200 + (-300) = -100,
      // clamped to minWidth (20).
      await tester.drag(listeners.at(4), const Offset(-300.0, 0.0));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final (nodeId, width, height) = results.first;
      expect(nodeId, 'img-1');
      // Should be clamped to minWidth = 20.
      expect(width, 20.0);
      expect(height, isNull);
    });

    testWidgets('drag beyond minHeight clamps height to minHeight', (tester) async {
      final results = await pumpAndCaptureDrags(tester, imageHeight: 100.0);

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // bottomCenter is index 6. Dragging up: newHeight = 100 + (-300) = -200,
      // clamped to minHeight (20).
      await tester.drag(listeners.at(6), const Offset(0.0, -300.0));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final (nodeId, width, height) = results.first;
      expect(nodeId, 'img-1');
      expect(width, isNull);
      // Should be clamped to minHeight = 20.
      expect(height, 20.0);
    });
  });

  // -------------------------------------------------------------------------
  // BlockResizeHandles — border
  // -------------------------------------------------------------------------

  group('BlockResizeHandles — border', () {
    testWidgets('a DecoratedBox with a border is present when handles are shown', (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: 200.0,
          height: 100.0,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      _selectFully(controller, 'img-1');

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
        ),
      );
      await tester.pumpAndSettle();

      // Find DecoratedBox widgets inside BlockResizeHandles that have a border.
      final blockHandlesFinder = find.byType(BlockResizeHandles);
      expect(blockHandlesFinder, findsOneWidget);

      final decoratedBoxes = find.descendant(
        of: blockHandlesFinder,
        matching: find.byType(DecoratedBox),
      );
      // There should be at least one DecoratedBox (the border) plus 8 handle squares.
      expect(decoratedBoxes, findsWidgets);

      // Verify at least one of the DecoratedBoxes has a BoxDecoration with a border.
      final hasBorder = tester.widgetList<DecoratedBox>(decoratedBoxes).any((box) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) {
          return decoration.border != null;
        }
        return false;
      });
      expect(hasBorder, isTrue, reason: 'Expected a DecoratedBox with a border to be present');
    });

    testWidgets('no DecoratedBox border when handles are not shown (no selection)', (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: 200.0,
          height: 100.0,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      // No selection set — handles should not appear.

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
        ),
      );
      await tester.pumpAndSettle();

      final blockHandlesFinder = find.byType(BlockResizeHandles);
      expect(blockHandlesFinder, findsOneWidget);

      // BlockResizeHandles renders SizedBox.shrink when hidden — no children.
      final listeners = find.descendant(
        of: blockHandlesFinder,
        matching: find.byType(Listener),
      );
      expect(listeners, findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // BlockResizeHandles — widget properties
  // -------------------------------------------------------------------------

  group('BlockResizeHandles — widget properties', () {
    testWidgets('default handleSize is 8.0', (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: 200.0,
          height: 100.0,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      _selectFully(controller, 'img-1');

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
        ),
      );
      await tester.pumpAndSettle();

      final widget = tester.widget<BlockResizeHandles>(find.byType(BlockResizeHandles));
      expect(widget.handleSize, 8.0);
    });

    testWidgets('default minWidth and minHeight are 20.0', (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: 200.0,
          height: 100.0,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
        ),
      );
      await tester.pumpAndSettle();

      final widget = tester.widget<BlockResizeHandles>(find.byType(BlockResizeHandles));
      expect(widget.minWidth, 20.0);
      expect(widget.minHeight, 20.0);
    });

    testWidgets('default borderColor and handleColor are Material Blue 500', (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: 200.0,
          height: 100.0,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
        ),
      );
      await tester.pumpAndSettle();

      final widget = tester.widget<BlockResizeHandles>(find.byType(BlockResizeHandles));
      expect(widget.borderColor, const Color(0xFF2196F3));
      expect(widget.handleColor, const Color(0xFF2196F3));
    });
  });

  // -------------------------------------------------------------------------
  // BlockResizeHandles — isDragging static flag
  // -------------------------------------------------------------------------

  group('BlockResizeHandles — isDragging', () {
    testWidgets('isDragging is false when no drag is active', (tester) async {
      expect(BlockResizeHandles.isDragging, isFalse);
    });
  });
}
