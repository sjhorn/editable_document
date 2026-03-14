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
/// - Corner drag with [ImageNode.lockAspect] = false resizes width and height
///   independently.
/// - Edge drag with [ImageNode.lockAspect] = true scales the orthogonal
///   dimension proportionally.
/// - [createResetImageSizeRequest] preserves [ImageNode.lockAspect].
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
  ValueChanged<String>? onResetImageSize,
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
        onResetImageSize: onResetImageSize,
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

    test('createResizeRequest switches stretch alignment to start', () {
      // A stretch ImageNode (default alignment) should be auto-switched to
      // BlockAlignment.start when resized so the explicit dimensions take effect.
      final node = ImageNode(
        id: 'img-stretch',
        imageUrl: 'test.png',
        // no alignment → defaults to BlockAlignment.stretch
      );

      final req = createResizeRequest(node, 300.0, 150.0);

      expect(req, isA<ReplaceNodeRequest>());
      final newNode = (req! as ReplaceNodeRequest).newNode as ImageNode;
      expect(newNode.width, 300.0);
      expect(newNode.height, 150.0);
      expect(newNode.alignment, BlockAlignment.start,
          reason: 'stretch alignment should be auto-switched to start on resize');
    });

    test('createResizeRequest preserves non-stretch alignment', () {
      // A center-aligned ImageNode should keep its alignment after resize.
      final node = ImageNode(
        id: 'img-center',
        imageUrl: 'test.png',
        width: 200.0,
        height: 100.0,
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 320.0, 160.0);

      expect(req, isA<ReplaceNodeRequest>());
      final newNode = (req! as ReplaceNodeRequest).newNode as ImageNode;
      expect(newNode.width, 320.0);
      expect(newNode.height, 160.0);
      expect(newNode.alignment, BlockAlignment.center,
          reason: 'non-stretch alignment should be preserved on resize');
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

    testWidgets('handles shown for stretch-alignment block', (tester) async {
      // ImageNode defaults to BlockAlignment.stretch.
      // Resize handles should now appear for stretch-alignment blocks too,
      // and dragging will auto-switch the alignment to start.
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

      // Eight Listener widgets — handles are shown for stretch-alignment blocks.
      final listeners = find.descendant(
        of: blockHandlesFinder,
        matching: find.byType(Listener),
      );
      expect(listeners, findsNWidgets(8));
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

    testWidgets(
        'dragging middleRight handle calls onResize with increased width '
        'and proportional height (lockAspect=true default)', (tester) async {
      // Image is 200×100 → aspect 2:1. Default lockAspect=true.
      final results = await pumpAndCaptureDrags(tester);

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // middleRight is index 4 in ResizeHandlePosition.values
      await tester.drag(listeners.at(4), const Offset(50.0, 0.0));
      await tester.pumpAndSettle();

      // onResize fires on every pointer-move (real-time), check the last call.
      expect(results, isNotEmpty);
      final (nodeId, width, height) = results.last;
      expect(nodeId, 'img-1');
      // Width: 200 + 50 = 250.
      expect(width, 250.0);
      // Height is proportionally scaled: 250 / 2 = 125 (lockAspect=true).
      expect(height, 125.0);
    });

    testWidgets(
        'dragging bottomCenter handle calls onResize with increased height '
        'and proportional width (lockAspect=true default)', (tester) async {
      // Image is 200×100 → aspect 2:1. Default lockAspect=true.
      final results = await pumpAndCaptureDrags(tester);

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // bottomCenter is index 6 in ResizeHandlePosition.values
      await tester.drag(listeners.at(6), const Offset(0.0, 40.0));
      await tester.pumpAndSettle();

      // onResize fires on every pointer-move (real-time), check the last call.
      expect(results, isNotEmpty);
      final (nodeId, width, height) = results.last;
      expect(nodeId, 'img-1');
      // Height: 100 + 40 = 140.
      expect(height, 140.0);
      // Width is proportionally scaled: 140 * 2 = 280 (lockAspect=true).
      expect(width, 280.0);
    });

    testWidgets('dragging bottomRight corner calls onResize with aspect-ratio-locked dimensions',
        (tester) async {
      // Image is 200×100 → aspect ratio 2:1.
      final results = await pumpAndCaptureDrags(tester);

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // bottomRight is index 7. Drag mostly horizontal (60,30) → width drives.
      await tester.drag(listeners.at(7), const Offset(60.0, 30.0));
      await tester.pumpAndSettle();

      expect(results, isNotEmpty);
      final (nodeId, width, height) = results.last;
      expect(nodeId, 'img-1');
      // Width: 200 + 60 = 260, Height locked to 260 / 2 = 130.
      expect(width, 260.0);
      expect(height, 130.0);
    });

    testWidgets('drag beyond minWidth clamps width to minWidth', (tester) async {
      // Image is 200×100 → aspect 2:1. Default lockAspect=true.
      final results = await pumpAndCaptureDrags(tester, imageWidth: 200.0);

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // middleRight is index 4. Dragging left by 300: newWidth = 200 + (-300) = -100,
      // clamped to minWidth (20). With lockAspect=true, height = -100 / 2 = -50,
      // also clamped to minHeight (20).
      await tester.drag(listeners.at(4), const Offset(-300.0, 0.0));
      await tester.pumpAndSettle();

      // onResize fires on every pointer-move (real-time), check the last call.
      expect(results, isNotEmpty);
      final (nodeId, width, height) = results.last;
      expect(nodeId, 'img-1');
      // Should be clamped to minWidth = 20.
      expect(width, 20.0);
      // lockAspect=true: height is also clamped to minHeight = 20.
      expect(height, 20.0);
    });

    testWidgets('drag beyond minHeight clamps height to minHeight', (tester) async {
      // Image is 200×100 → aspect 2:1. Default lockAspect=true.
      final results = await pumpAndCaptureDrags(tester, imageHeight: 100.0);

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // bottomCenter is index 6. Dragging up: newHeight = 100 + (-300) = -200,
      // clamped to minHeight (20). With lockAspect=true, width = -200 * 2 = -400,
      // also clamped to minWidth (20).
      await tester.drag(listeners.at(6), const Offset(0.0, -300.0));
      await tester.pumpAndSettle();

      // onResize fires on every pointer-move (real-time), check the last call.
      expect(results, isNotEmpty);
      final (nodeId, width, height) = results.last;
      expect(nodeId, 'img-1');
      // lockAspect=true: width is also clamped to minWidth = 20.
      expect(width, 20.0);
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

    testWidgets('border IS shown for stretch-alignment image when selected', (tester) async {
      // ImageNode with no explicit alignment defaults to BlockAlignment.stretch.
      // Both the selection border and resize handles should appear; dragging a
      // handle will auto-switch alignment from stretch to start.
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          // no alignment → defaults to BlockAlignment.stretch
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

      // BlockResizeHandles must be present in the tree.
      final blockHandlesFinder = find.byType(BlockResizeHandles);
      expect(blockHandlesFinder, findsOneWidget);

      // Eight Listener widgets (resize handles) — stretch blocks now show handles.
      final listeners = find.descendant(
        of: blockHandlesFinder,
        matching: find.byType(Listener),
      );
      expect(listeners, findsNWidgets(8));

      // At least one DecoratedBox with a BoxDecoration.border IS present —
      // the selection border is drawn along with the resize handles.
      final decoratedBoxes = find.descendant(
        of: blockHandlesFinder,
        matching: find.byType(DecoratedBox),
      );
      final hasBorder = tester.widgetList<DecoratedBox>(decoratedBoxes).any((box) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) {
          return decoration.border != null;
        }
        return false;
      });
      expect(
        hasBorder,
        isTrue,
        reason: 'Expected a DecoratedBox with a border inside BlockResizeHandles '
            'for a stretch-alignment image.',
      );
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

  // -------------------------------------------------------------------------
  // createResetImageSizeRequest
  // -------------------------------------------------------------------------

  group('createResetImageSizeRequest', () {
    test('returns ReplaceNodeRequest with null width and height for ImageNode', () {
      final node = ImageNode(
        id: 'img-1',
        imageUrl: 'test.png',
        width: 320.0,
        height: 240.0,
        alignment: BlockAlignment.center,
      );

      final req = createResetImageSizeRequest(node);

      expect(req, isA<ReplaceNodeRequest>());
      final replace = req! as ReplaceNodeRequest;
      expect(replace.nodeId, 'img-1');
      final newNode = replace.newNode as ImageNode;
      expect(newNode.width, isNull);
      expect(newNode.height, isNull);
      // Other fields preserved.
      expect(newNode.imageUrl, 'test.png');
      expect(newNode.alignment, BlockAlignment.center);
    });

    test('preserves altText, textWrap, and metadata', () {
      final node = ImageNode(
        id: 'img-2',
        imageUrl: 'photo.jpg',
        altText: 'A photo',
        width: 100.0,
        height: 100.0,
        alignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
        metadata: {'key': 'value'},
      );

      final req = createResetImageSizeRequest(node);

      final newNode = (req! as ReplaceNodeRequest).newNode as ImageNode;
      expect(newNode.altText, 'A photo');
      expect(newNode.textWrap, TextWrapMode.wrap);
      expect(newNode.metadata, {'key': 'value'});
    });

    test('returns null for non-ImageNode', () {
      final node = ParagraphNode(id: 'p-1', text: AttributedText('Hello'));
      expect(createResetImageSizeRequest(node), isNull);
    });

    test('returns null for CodeBlockNode', () {
      final node = CodeBlockNode(
        id: 'code-1',
        text: AttributedText('code'),
        alignment: BlockAlignment.center,
      );
      expect(createResetImageSizeRequest(node), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // BlockResizeHandles — reset button
  // -------------------------------------------------------------------------

  group('BlockResizeHandles — reset button', () {
    testWidgets('reset button appears for selected ImageNode', (tester) async {
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
          onResetImageSize: (id) {},
        ),
      );
      await tester.pumpAndSettle();

      // The "1:1" text widget should be present.
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('reset button does NOT appear for HorizontalRuleNode', (tester) async {
      final doc = MutableDocument([
        HorizontalRuleNode(
          id: 'hr-1',
          width: 200.0,
          height: 4.0,
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      _selectFully(controller, 'hr-1');

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
          onResetImageSize: (id) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reset'), findsNothing);
    });

    testWidgets('reset button does NOT appear when image has default dimensions', (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          // width and height are null → intrinsic/default size
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
          onResetImageSize: (id) {},
        ),
      );
      await tester.pumpAndSettle();

      // Image has no custom dimensions → Reset button should not appear.
      expect(find.text('Reset'), findsNothing);
    });

    testWidgets('reset button does NOT appear when onResetImageSize is null', (tester) async {
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

      // _buildWithOverlay does not pass onResetImageSize, so it's null
      // on BlockResizeHandles. The button should not appear.
      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          onBlockResize: (id, w, h) {},
        ),
      );
      await tester.pumpAndSettle();

      // onResetImageSize is null → no button.
      // Note: _buildWithOverlay doesn't wire onResetImageSize through
      // DocumentSelectionOverlay, so BlockResizeHandles.onResetImageSize
      // is null.
      expect(find.text('Reset'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // BlockResizeHandles — lockAspect behaviour
  // -------------------------------------------------------------------------

  group('BlockResizeHandles — lockAspect', () {
    /// Builds the overlay stack with an [ImageNode] whose [lockAspect] is
    /// configurable. Returns the list of (nodeId, width, height) calls
    /// received by [onResize].
    Future<List<(String, double?, double?)>> pumpAndCaptureDragsWithLock(
      WidgetTester tester, {
      double imageWidth = 200.0,
      double imageHeight = 100.0,
      bool lockAspect = true,
    }) async {
      final results = <(String, double?, double?)>[];

      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: imageWidth,
          height: imageHeight,
          alignment: BlockAlignment.center,
          lockAspect: lockAspect,
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

    testWidgets('corner drag with lockAspect=false resizes width and height independently',
        (tester) async {
      // Image is 200×100. Drag bottomRight by (50, 30) with lockAspect=false.
      // Expected: width = 200+50 = 250, height = 100+30 = 130 (independent).
      final results = await pumpAndCaptureDragsWithLock(
        tester,
        imageWidth: 200.0,
        imageHeight: 100.0,
        lockAspect: false,
      );

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // bottomRight is index 7 in ResizeHandlePosition.values.
      await tester.drag(listeners.at(7), const Offset(50.0, 30.0));
      await tester.pumpAndSettle();

      expect(results, isNotEmpty);
      final (nodeId, width, height) = results.last;
      expect(nodeId, 'img-1');
      expect(width, 250.0, reason: 'width should increase by 50 independently');
      expect(height, 130.0, reason: 'height should increase by 30 independently');
    });

    testWidgets('edge drag with lockAspect=true scales orthogonal dimension proportionally',
        (tester) async {
      // Image is 200×100 → aspect 2:1. Drag middleRight by (50, 0) with lockAspect=true.
      // Expected: width = 200+50 = 250, height = 250/2 = 125 (proportional).
      final results = await pumpAndCaptureDragsWithLock(
        tester,
        imageWidth: 200.0,
        imageHeight: 100.0,
        lockAspect: true,
      );

      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // middleRight is index 4 in ResizeHandlePosition.values.
      await tester.drag(listeners.at(4), const Offset(50.0, 0.0));
      await tester.pumpAndSettle();

      expect(results, isNotEmpty);
      final (nodeId, width, height) = results.last;
      expect(nodeId, 'img-1');
      expect(width, 250.0, reason: 'width should increase by 50');
      expect(height, 125.0, reason: 'height should be proportionally scaled to 250/2 = 125');
    });
  });

  // -------------------------------------------------------------------------
  // createResetImageSizeRequest — lockAspect preservation
  // -------------------------------------------------------------------------

  group('createResetImageSizeRequest — lockAspect', () {
    test('preserves lockAspect=true through reset', () {
      final node = ImageNode(
        id: 'img-1',
        imageUrl: 'test.png',
        width: 320.0,
        height: 240.0,
        alignment: BlockAlignment.center,
        lockAspect: true,
      );

      final req = createResetImageSizeRequest(node);

      final newNode = (req! as ReplaceNodeRequest).newNode as ImageNode;
      expect(newNode.lockAspect, isTrue, reason: 'lockAspect should be preserved through reset');
    });

    test('preserves lockAspect=false through reset', () {
      final node = ImageNode(
        id: 'img-2',
        imageUrl: 'test.png',
        width: 320.0,
        height: 240.0,
        alignment: BlockAlignment.center,
        lockAspect: false,
      );

      final req = createResetImageSizeRequest(node);

      final newNode = (req! as ReplaceNodeRequest).newNode as ImageNode;
      expect(newNode.lockAspect, isFalse,
          reason: 'lockAspect=false should be preserved through reset');
    });
  });
}
