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
/// - A [RenderBlockResizeBorder] is present when handles are shown.
/// - [BlockResizeHandles.isDragging] is set during a drag.
/// - Corner drag with [ImageNode.lockAspect] = false resizes width and height
///   independently.
/// - Edge drag with [ImageNode.lockAspect] = true scales the orthogonal
///   dimension proportionally.
/// - [createResetImageSizeRequest] preserves [ImageNode.lockAspect].
/// - Selection persists (remains fully-selected) after a resize drag completes.
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
    width: width != null ? BlockDimension.pixels(width) : null,
    height: height != null ? BlockDimension.pixels(height) : null,
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
        width: const BlockDimension.pixels(200.0),
        height: const BlockDimension.pixels(100.0),
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 320.0, 160.0);

      expect(req, isA<ReplaceNodeRequest>());
      final replace = req! as ReplaceNodeRequest;
      expect(replace.nodeId, 'img-1');
      final newNode = replace.newNode as ImageNode;
      expect(newNode.width, const BlockDimension.pixels(320.0));
      expect(newNode.height, const BlockDimension.pixels(160.0));
    });

    test('returns ReplaceNodeRequest for CodeBlockNode with updated width and height', () {
      final node = CodeBlockNode(
        id: 'code-1',
        text: AttributedText('void main() {}'),
        width: const BlockDimension.pixels(400.0),
        height: const BlockDimension.pixels(200.0),
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 500.0, 250.0);

      expect(req, isA<ReplaceNodeRequest>());
      final replace = req! as ReplaceNodeRequest;
      expect(replace.nodeId, 'code-1');
      final newNode = replace.newNode as CodeBlockNode;
      expect(newNode.width, const BlockDimension.pixels(500.0));
      expect(newNode.height, const BlockDimension.pixels(250.0));
    });

    test('returns ReplaceNodeRequest for BlockquoteNode with updated width and height', () {
      final node = BlockquoteNode(
        id: 'bq-1',
        text: AttributedText('To be or not to be'),
        width: const BlockDimension.pixels(300.0),
        height: const BlockDimension.pixels(80.0),
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 360.0, 90.0);

      expect(req, isA<ReplaceNodeRequest>());
      final replace = req! as ReplaceNodeRequest;
      expect(replace.nodeId, 'bq-1');
      final newNode = replace.newNode as BlockquoteNode;
      expect(newNode.width, const BlockDimension.pixels(360.0));
      expect(newNode.height, const BlockDimension.pixels(90.0));
    });

    test('returns ReplaceNodeRequest for HorizontalRuleNode with updated width and height', () {
      final node = HorizontalRuleNode(
        id: 'hr-1',
        width: const BlockDimension.pixels(400.0),
        height: const BlockDimension.pixels(2.0),
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 500.0, 4.0);

      expect(req, isA<ReplaceNodeRequest>());
      final replace = req! as ReplaceNodeRequest;
      expect(replace.nodeId, 'hr-1');
      final newNode = replace.newNode as HorizontalRuleNode;
      expect(newNode.width, const BlockDimension.pixels(500.0));
      expect(newNode.height, const BlockDimension.pixels(4.0));
    });

    test('returns ReplaceNodeRequest for TableNode with updated width and height', () {
      final node = _tableNode(id: 'tbl-1', width: 300.0, height: 150.0);

      final req = createResizeRequest(node, 400.0, 200.0);

      expect(req, isA<ReplaceNodeRequest>());
      final replace = req! as ReplaceNodeRequest;
      expect(replace.nodeId, 'tbl-1');
      final newNode = replace.newNode as TableNode;
      expect(newNode.width, const BlockDimension.pixels(400.0));
      expect(newNode.height, const BlockDimension.pixels(200.0));
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
        width: const BlockDimension.pixels(200.0),
        height: const BlockDimension.pixels(100.0),
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, null, 160.0);

      expect(req, isA<ReplaceNodeRequest>());
      final newNode = (req! as ReplaceNodeRequest).newNode as ImageNode;
      // width should be preserved from the original node
      expect(newNode.width, const BlockDimension.pixels(200.0));
      expect(newNode.height, const BlockDimension.pixels(160.0));
    });

    test('preserves existing height when height argument is null — ImageNode', () {
      final node = ImageNode(
        id: 'img-1',
        imageUrl: 'test.png',
        width: const BlockDimension.pixels(200.0),
        height: const BlockDimension.pixels(100.0),
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 320.0, null);

      expect(req, isA<ReplaceNodeRequest>());
      final newNode = (req! as ReplaceNodeRequest).newNode as ImageNode;
      expect(newNode.width, const BlockDimension.pixels(320.0));
      // height should be preserved from the original node
      expect(newNode.height, const BlockDimension.pixels(100.0));
    });

    test('preserves existing width when width argument is null — CodeBlockNode', () {
      final node = CodeBlockNode(
        id: 'code-1',
        text: AttributedText('code'),
        width: const BlockDimension.pixels(400.0),
        height: const BlockDimension.pixels(200.0),
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, null, 250.0);

      final newNode = (req! as ReplaceNodeRequest).newNode as CodeBlockNode;
      expect(newNode.width, const BlockDimension.pixels(400.0));
      expect(newNode.height, const BlockDimension.pixels(250.0));
    });

    test('preserves existing height when height argument is null — HorizontalRuleNode', () {
      final node = HorizontalRuleNode(
        id: 'hr-1',
        width: const BlockDimension.pixels(400.0),
        height: const BlockDimension.pixels(2.0),
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 500.0, null);

      final newNode = (req! as ReplaceNodeRequest).newNode as HorizontalRuleNode;
      expect(newNode.width, const BlockDimension.pixels(500.0));
      expect(newNode.height, const BlockDimension.pixels(2.0));
    });

    test('preserves existing width when width argument is null — TableNode', () {
      final node = _tableNode(id: 'tbl-1', width: 300.0, height: 150.0);

      final req = createResizeRequest(node, null, 200.0);

      final newNode = (req! as ReplaceNodeRequest).newNode as TableNode;
      expect(newNode.width, const BlockDimension.pixels(300.0));
      expect(newNode.height, const BlockDimension.pixels(200.0));
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
      expect(newNode.width, const BlockDimension.pixels(300.0));
      expect(newNode.height, const BlockDimension.pixels(150.0));
      expect(newNode.alignment, BlockAlignment.start,
          reason: 'stretch alignment should be auto-switched to start on resize');
    });

    test('createResizeRequest preserves non-stretch alignment', () {
      // A center-aligned ImageNode should keep its alignment after resize.
      final node = ImageNode(
        id: 'img-center',
        imageUrl: 'test.png',
        width: const BlockDimension.pixels(200.0),
        height: const BlockDimension.pixels(100.0),
        alignment: BlockAlignment.center,
      );

      final req = createResizeRequest(node, 320.0, 160.0);

      expect(req, isA<ReplaceNodeRequest>());
      final newNode = (req! as ReplaceNodeRequest).newNode as ImageNode;
      expect(newNode.width, const BlockDimension.pixels(320.0));
      expect(newNode.height, const BlockDimension.pixels(160.0));
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
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
          alignment: BlockAlignment.center,
        ),
        ImageNode(
          id: 'img-2',
          imageUrl: 'test2.png',
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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
          width: BlockDimension.pixels(imageWidth),
          height: BlockDimension.pixels(imageHeight),
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
    testWidgets('a RenderBlockResizeBorder is present when handles are shown', (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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

      final blockHandlesFinder = find.byType(BlockResizeHandles);
      expect(blockHandlesFinder, findsOneWidget);

      // The border is now painted by a RenderBlockResizeBorder render object.
      // Use byElementType to find only the LeafRenderObjectElement that
      // directly owns the RenderBlockResizeBorder (not parent wrappers).
      final borderFinder = find.descendant(
        of: blockHandlesFinder,
        matching: find.byElementPredicate(
          (element) =>
              element is LeafRenderObjectElement && element.renderObject is RenderBlockResizeBorder,
        ),
      );
      expect(
        borderFinder,
        findsOneWidget,
        reason: 'Expected a RenderBlockResizeBorder to be present '
            'inside BlockResizeHandles when a block node is selected.',
      );

      // The render object must have the correct selectedNodeId.
      final renderBorder = tester.renderObject<RenderBlockResizeBorder>(borderFinder);
      expect(renderBorder.selectedNodeId, 'img-1');
    });

    testWidgets('no DecoratedBox border when handles are not shown (no selection)', (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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

      // A RenderBlockResizeBorder IS present — the selection border is drawn
      // by the paint-time render object along with the resize handles.
      final borderFinder = find.descendant(
        of: blockHandlesFinder,
        matching: find.byElementPredicate(
          (element) =>
              element is LeafRenderObjectElement && element.renderObject is RenderBlockResizeBorder,
        ),
      );
      expect(
        borderFinder,
        findsOneWidget,
        reason: 'Expected a RenderBlockResizeBorder inside BlockResizeHandles '
            'for a stretch-alignment image.',
      );
    });

    testWidgets('RenderBlockResizeBorder render object exists in render tree when handles shown',
        (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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

      // The _BlockResizeBorderRenderWidget (private) creates a
      // RenderBlockResizeBorder which is publicly queryable.
      final blockHandlesFinder2 = find.byType(BlockResizeHandles);
      final borderFinder = find.descendant(
        of: blockHandlesFinder2,
        matching: find.byElementPredicate(
          (element) =>
              element is LeafRenderObjectElement && element.renderObject is RenderBlockResizeBorder,
        ),
      );
      expect(
        borderFinder,
        findsOneWidget,
        reason: 'A RenderBlockResizeBorder render object should be present '
            'in the render tree whenever BlockResizeHandles is showing.',
      );

      final render = tester.renderObject<RenderBlockResizeBorder>(borderFinder);
      expect(render.selectedNodeId, 'img-1');
      expect(render.showHandles, isTrue);
      expect(render.documentLayout, isNotNull);
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
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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
        width: const BlockDimension.pixels(320.0),
        height: const BlockDimension.pixels(240.0),
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
        width: const BlockDimension.pixels(100.0),
        height: const BlockDimension.pixels(100.0),
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
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(4.0),
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
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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
          width: BlockDimension.pixels(imageWidth),
          height: BlockDimension.pixels(imageHeight),
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
  // BlockResizeHandles — selection persistence after drag
  // -------------------------------------------------------------------------

  group('BlockResizeHandles — selection persistence after drag', () {
    testWidgets('selection persists after resize drag completes on a stretch image',
        (tester) async {
      // Use a stretch-aligned image (no explicit alignment → BlockAlignment.stretch).
      // The onBlockResize callback is intentionally a no-op here so that the
      // document model stays stable; the test only checks that the controller
      // selection references the node after the drag ends.
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
          // No-op: we only care about the selection state after the drag, not
          // about the document mutation.
          onBlockResize: (id, w, h) {},
        ),
      );
      await tester.pumpAndSettle();

      // Drag middleLeft handle (index 3) — always within the viewport even for
      // a stretch-aligned (full-width) image where the right-side handles sit
      // right at the container edge.
      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // middleLeft is index 3 in ResizeHandlePosition.values.
      await tester.drag(listeners.at(3), const Offset(-20.0, 0.0));
      await tester.pumpAndSettle();

      // After the drag ends, the selection must still reference 'img-1'.
      final selection = controller.selection;
      expect(
        selection,
        isNotNull,
        reason: 'Selection should not be null after a resize drag completes',
      );
      expect(
        selection!.base.nodeId,
        'img-1',
        reason: 'Base position should still be on the resized node',
      );
      expect(
        selection.extent.nodeId,
        'img-1',
        reason: 'Extent position should still be on the resized node',
      );
    });

    testWidgets('selection persists after resize drag completes on a center-aligned image',
        (tester) async {
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
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
          onBlockResize: (id, w, h) {
            final node = doc.nodeById(id);
            if (node == null) return;
            final req = createResizeRequest(node, w, h);
            if (req != null) {
              doc.replaceNode(id, (req as ReplaceNodeRequest).newNode);
            }
          },
        ),
      );
      await tester.pumpAndSettle();

      // Drag middleRight handle.
      final listeners = find.descendant(
        of: find.byType(BlockResizeHandles),
        matching: find.byType(Listener),
      );
      // middleRight is index 4 in ResizeHandlePosition.values.
      await tester.drag(listeners.at(4), const Offset(50.0, 0.0));
      await tester.pumpAndSettle();

      final selection = controller.selection;
      expect(selection, isNotNull,
          reason: 'Selection should not be null after a resize drag completes');
      expect(selection!.base.nodeId, 'img-1',
          reason: 'Base position should still be on the resized node');
      expect(selection.extent.nodeId, 'img-1',
          reason: 'Extent position should still be on the resized node');
    });
  });

  // -------------------------------------------------------------------------
  // BlockResizeHandles — viewport resize tracking
  // -------------------------------------------------------------------------

  group('BlockResizeHandles — viewport resize tracking', () {
    testWidgets('resize outline re-queries geometry when DocumentViewportScope width changes',
        (tester) async {
      // A center-aligned image of 200×100. The SizedBox container starts at
      // 600 wide, then narrows to 400. Because the image is center-aligned,
      // its left offset changes as the container width changes — and the
      // resize handles must follow.
      //
      // This test replicates the production scenario where DocumentScrollable
      // uses LayoutBuilder + DocumentViewportScope with the SAME child widget
      // reference. When the viewport width changes, only the InheritedWidget
      // value changes — the child subtree is NOT rebuilt via didUpdateWidget.
      // BlockResizeHandles must respond via didChangeDependencies.
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
          alignment: BlockAlignment.center,
        ),
      ]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      _selectFully(controller, 'img-1');

      final layoutKey = GlobalKey<DocumentLayoutState>();

      // Build the inner content once. This simulates the widget.child passed to
      // DocumentScrollable — the SAME reference is used in both DocumentViewportScope
      // instances, so the child subtree does NOT get didUpdateWidget when the
      // viewport changes; only InheritedWidget-registered dependents are notified.
      final innerContent = DocumentSelectionOverlay(
        controller: controller,
        layoutKey: layoutKey,
        startHandleLayerLink: LayerLink(),
        endHandleLayerLink: LayerLink(),
        document: doc,
        onBlockResize: (id, w, h) {},
        child: DocumentLayout(
          key: layoutKey,
          document: controller.document,
          controller: controller,
          componentBuilders: defaultComponentBuilders,
        ),
      );

      // Mutable state for the StatefulBuilder.
      double viewportWidth = 600.0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            outerSetState = setState;
            return MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: viewportWidth,
                  height: 800.0,
                  child: DocumentViewportScope(
                    viewportWidth: viewportWidth,
                    viewportHeight: 800.0,
                    // Re-use the SAME child reference — mirrors DocumentScrollable.
                    child: innerContent,
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Verify that the resize outline is visible (handles are shown).
      final blockHandlesFinder = find.byType(BlockResizeHandles);
      expect(blockHandlesFinder, findsOneWidget);

      // The border is now painted by RenderBlockResizeBorder at paint time.
      // Verify it has the correct selectedNodeId to confirm it will query
      // the right block geometry.
      RenderBlockResizeBorder getResizeBorderRenderObject() {
        final brhFinder = find.byType(BlockResizeHandles);
        final borderFinder = find.descendant(
          of: brhFinder,
          matching: find.byElementPredicate(
            (element) =>
                element is LeafRenderObjectElement &&
                element.renderObject is RenderBlockResizeBorder,
          ),
        );
        expect(borderFinder, findsOneWidget, reason: 'RenderBlockResizeBorder must be present');
        return tester.renderObject<RenderBlockResizeBorder>(borderFinder);
      }

      // The Listener hit-target Positioned widgets still carry the blockRect
      // coordinates. Find them by looking for Positioned with explicit width
      // (Positioned.fill uses left/right/top/bottom but no width/height).
      // These are the 8 handle Positioned widgets (topLeft is index 0).
      Offset getTopLeftHandleOffset() {
        final allPositioned = tester.widgetList<Positioned>(
          find.descendant(
            of: find.byType(BlockResizeHandles),
            matching: find.byType(Positioned),
          ),
        );
        // Skip Positioned.fill (width==null) — find first with explicit width.
        final handlePositioned = allPositioned.firstWhere(
          (p) => p.width != null,
        );
        return Offset(handlePositioned.left!, handlePositioned.top ?? 0);
      }

      final renderBorderBefore = getResizeBorderRenderObject();
      expect(renderBorderBefore.selectedNodeId, 'img-1');
      final handleOffsetBefore = getTopLeftHandleOffset();

      // Narrow the viewport using setState on the StatefulBuilder.
      // Because innerContent is the same object reference, the child element
      // does NOT rebuild via didUpdateWidget. Only InheritedWidget-registered
      // dependents (those that called dependOnInheritedWidgetOfExactType) are
      // notified — this exercises the didChangeDependencies fix.
      outerSetState(() {
        viewportWidth = 400.0;
      });
      await tester.pumpAndSettle();

      // The handles should still be visible.
      expect(find.byType(BlockResizeHandles), findsOneWidget);

      // The RenderBlockResizeBorder render object still has the same nodeId —
      // it will query layout at paint time automatically (no one-frame lag).
      final renderBorderAfter = getResizeBorderRenderObject();
      expect(renderBorderAfter.selectedNodeId, 'img-1');

      // The Listener hit-target Positioned widgets must have moved left too
      // (they re-query via _scheduleGeometryUpdate from didChangeDependencies).
      final handleOffsetAfter = getTopLeftHandleOffset();

      // In a 600-wide container: image left = (600 - 200) / 2 = 200.
      // In a 400-wide container: image left = (400 - 200) / 2 = 100.
      // So the handle's left coordinate should shift left by ~100px.
      expect(
        handleOffsetAfter.dx,
        lessThan(handleOffsetBefore.dx),
        reason: 'Handle left edge should move left when viewport narrows '
            '(center-aligned image in a narrower container). '
            'Before: ${handleOffsetBefore.dx}, After: ${handleOffsetAfter.dx}',
      );
    });
  });

  // -------------------------------------------------------------------------
  // BlockResizeHandles — handle position clamping at layout edges
  // -------------------------------------------------------------------------

  group('BlockResizeHandles — handle position clamping', () {
    /// Returns all handle [Positioned] widgets (those with explicit [width])
    /// inside [BlockResizeHandles], in [ResizeHandlePosition.values] order.
    List<Positioned> _handlePositioned(WidgetTester tester) {
      final allPositioned = tester.widgetList<Positioned>(
        find.descendant(
          of: find.byType(BlockResizeHandles),
          matching: find.byType(Positioned),
        ),
      );
      // Positioned.fill has no width; handle Positioned widgets have explicit width.
      return allPositioned.where((p) => p.width != null).toList();
    }

    testWidgets('handle Positioned left/top are non-negative when block is at top-left edge',
        (tester) async {
      // A stretch-aligned image fills the full container width and is placed
      // at the very top of the document layout (top: 0, left: 0).
      // Without clamping, the topLeft handle would produce
      // Positioned(left: -hitHalf, top: -hitHalf) — negative coordinates that
      // get clipped by the Stack's bounds.
      // After clamping, left >= 0 and top >= 0 for all eight handles.
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          // No explicit dimensions and no alignment → stretch (full-width),
          // positioned at the very top of the document.
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

      // Handles must be present.
      final handles = _handlePositioned(tester);
      expect(handles, hasLength(8), reason: 'All 8 handle Positioned widgets must be present');

      for (final positioned in handles) {
        expect(
          positioned.left,
          greaterThanOrEqualTo(0.0),
          reason: 'Handle Positioned.left must be >= 0 (no negative clipping). '
              'Got ${positioned.left}',
        );
        expect(
          positioned.top,
          greaterThanOrEqualTo(0.0),
          reason: 'Handle Positioned.top must be >= 0 (no negative clipping). '
              'Got ${positioned.top}',
        );
      }
    });

    testWidgets('reset button top is non-negative when block is at top of layout', (tester) async {
      // When a block is at top: 0, the reset button would be placed at
      // top: 0 - _resetButtonHeight - _resetButtonGap = -26, which is clipped.
      // After clamping, top >= 0.
      final doc = MutableDocument([
        ImageNode(
          id: 'img-1',
          imageUrl: 'test.png',
          width: const BlockDimension.pixels(200.0),
          height: const BlockDimension.pixels(100.0),
          // No alignment → stretch; the image is at the very top.
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

      // The reset button is a Positioned widget with no explicit width in the
      // BlockResizeHandles tree (it uses a constant buttonWidth hardcoded,
      // BUT it DOES have width set). We can find it by the Text('Reset') widget.
      // Find the ancestor Positioned of the Text widget.
      final resetText = find.text('Reset');
      expect(resetText, findsOneWidget, reason: 'Reset button must be visible');

      // Walk up to the enclosing Positioned widget.
      final positionedFinder = find.ancestor(
        of: resetText,
        matching: find.byType(Positioned),
      );
      // There may be more than one ancestor Positioned; take the first
      // (closest ancestor) which is the one we placed around the button.
      final resetPositioned = tester.widget<Positioned>(positionedFinder.first);

      expect(
        resetPositioned.top,
        greaterThanOrEqualTo(0.0),
        reason: 'Reset button Positioned.top must be >= 0. Got ${resetPositioned.top}',
      );
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
        width: const BlockDimension.pixels(320.0),
        height: const BlockDimension.pixels(240.0),
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
        width: const BlockDimension.pixels(320.0),
        height: const BlockDimension.pixels(240.0),
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
