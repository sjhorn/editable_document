/// Tests for [TableDividerResizeHandles] widget.
///
/// Covers:
/// - Cursor changes to [SystemMouseCursors.resizeLeftRight] when hovering
///   over an interior column boundary.
/// - Cursor changes to [SystemMouseCursors.resizeUpDown] when hovering over
///   an interior row boundary.
/// - Cursor stays [MouseCursor.defer] when hovering over the outer table edges
///   (index 0 and last).
/// - Cursor returns to [MouseCursor.defer] when moving away from a boundary.
/// - Column drag calls [onColumnResize] with correct nodeId, colIndex, and a
///   width that equals startingWidth + deltaX.
/// - Row drag calls [onRowResize] with correct nodeId, rowIndex, and a height
///   that equals startingHeight + deltaY.
/// - [TableDividerResizeHandles.isDragging] is `true` during a drag and
///   `false` after pointer up.
/// - No resize cursor when hovering over a table but [onColumnResize] and
///   [onRowResize] are both `null`.
/// - [DocumentSelectionOverlay] auto-wires [TableDividerResizeHandles] when
///   [editor] and [document] are both provided.
library;

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in [MaterialApp] + [Scaffold].
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Builds a [TableNode] with [columnCount] columns and [rowCount] rows.
///
/// Optionally specifies [columnWidths] (per-column outer widths). Uses
/// [BlockAlignment.stretch] by default so the table fills the available width.
TableNode _tableNode({
  String id = 'tbl-1',
  int rowCount = 2,
  int columnCount = 3,
  List<double?>? columnWidths,
  List<double?>? rowHeights,
  BlockAlignment alignment = BlockAlignment.stretch,
}) {
  final cells = List.generate(
    rowCount,
    (r) => List.generate(columnCount, (c) => AttributedText('r${r}c$c')),
  );
  return TableNode(
    id: id,
    rowCount: rowCount,
    columnCount: columnCount,
    cells: cells,
    columnWidths: columnWidths,
    rowHeights: rowHeights,
    alignment: alignment,
  );
}

/// Builds a full overlay stack with a [TableDividerResizeHandles] layer.
///
/// [onColumnResize] and [onRowResize] are forwarded to
/// [DocumentSelectionOverlay]. [layoutKey] can be provided to obtain a
/// reference to the [DocumentLayoutState] for post-pump queries.
Widget _buildWithOverlay({
  required DocumentEditingController controller,
  required Document document,
  TableColumnResizeCallback? onColumnResize,
  TableRowResizeCallback? onRowResize,
  GlobalKey<DocumentLayoutState>? layoutKey,
  double viewportWidth = 600,
  double viewportHeight = 800,
}) {
  final key = layoutKey ?? GlobalKey<DocumentLayoutState>();
  return _wrap(
    SizedBox(
      width: viewportWidth,
      height: viewportHeight,
      child: DocumentSelectionOverlay(
        controller: controller,
        layoutKey: key,
        startHandleLayerLink: LayerLink(),
        endHandleLayerLink: LayerLink(),
        document: document,
        onTableColumnResize: onColumnResize,
        onTableRowResize: onRowResize,
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    TableDividerResizeHandles.isDragging = false;
  });

  // -------------------------------------------------------------------------
  // Cursor on column boundary hover
  // -------------------------------------------------------------------------

  group('TableDividerResizeHandles — column cursor', () {
    testWidgets('cursor becomes resizeLeftRight when hovering over interior column boundary',
        (tester) async {
      final layoutKey = GlobalKey<DocumentLayoutState>();
      // 3-column table: interior boundaries are at column-index 1 and 2.
      final table = _tableNode(id: 'tbl-1', columnCount: 3, rowCount: 2);
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          onColumnResize: (nodeId, colIndex, newWidth) {},
          onRowResize: (nodeId, rowIndex, newHeight) {},
        ),
      );
      await tester.pumpAndSettle();

      // Obtain the render block to find the x-position of the first interior
      // column boundary.
      final renderTable = layoutKey.currentState?.componentForNode('tbl-1') as RenderTableBlock?;
      expect(renderTable, isNotNull, reason: 'RenderTableBlock must be in tree');
      final xPositions = renderTable!.columnBoundaryXPositions;
      // Interior boundaries: index 1 (between col 0 and col 1).
      expect(xPositions.length, greaterThanOrEqualTo(3));

      // We need to convert the table-local x to global, then to
      // tester-local, to craft the pointer position.
      final tableGlobalOrigin = renderTable.localToGlobal(Offset.zero);
      final interiorX = tableGlobalOrigin.dx + xPositions[1];
      // Use the vertical midpoint of the first row.
      final yPositions = renderTable.rowBoundaryYPositions;
      final rowMidY = tableGlobalOrigin.dy +
          (yPositions.isNotEmpty ? yPositions[0] + renderTable.computedRowHeights[0] / 2 : 20.0);

      final handles = find.byType(TableDividerResizeHandles);
      expect(handles, findsOneWidget);

      // Simulate a hover at the interior column boundary.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset(interiorX, rowMidY));
      addTearDown(gesture.removePointer);
      await tester.pump();
      // moveTo fires a PointerHoverEvent (addPointer only fires PointerAddedEvent).
      await gesture.moveTo(Offset(interiorX, rowMidY));
      await tester.pump();

      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: handles, matching: find.byType(MouseRegion)),
      );
      expect(
        mouseRegion.cursor,
        SystemMouseCursors.resizeLeftRight,
        reason: 'hovering over interior column boundary should give resizeLeftRight cursor',
      );

      await gesture.removePointer();
    });

    testWidgets('cursor returns to defer after moving away from column boundary', (tester) async {
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final table = _tableNode(id: 'tbl-1', columnCount: 3, rowCount: 2);
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          onColumnResize: (nodeId, colIndex, newWidth) {},
        ),
      );
      await tester.pumpAndSettle();

      final renderTable = layoutKey.currentState?.componentForNode('tbl-1') as RenderTableBlock?;
      expect(renderTable, isNotNull);
      final xPositions = renderTable!.columnBoundaryXPositions;
      final tableGlobalOrigin = renderTable.localToGlobal(Offset.zero);
      final interiorX = tableGlobalOrigin.dx + xPositions[1];
      final midY = tableGlobalOrigin.dy + 20.0;

      final handles = find.byType(TableDividerResizeHandles);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      // First hover over the boundary.
      await gesture.addPointer(location: Offset(interiorX, midY));
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(Offset(interiorX, midY));
      await tester.pump();

      var mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: handles, matching: find.byType(MouseRegion)),
      );
      expect(mouseRegion.cursor, SystemMouseCursors.resizeLeftRight);

      // Move to the center of the first cell (well inside a cell, far from
      // any boundary).
      final firstCellCenterX = tableGlobalOrigin.dx + (xPositions[0] + xPositions[1]) / 2;
      await gesture.moveTo(Offset(firstCellCenterX, midY));
      await tester.pump();

      mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: handles, matching: find.byType(MouseRegion)),
      );
      expect(
        mouseRegion.cursor,
        MouseCursor.defer,
        reason: 'cursor should revert to defer when not near a boundary',
      );

      await gesture.removePointer();
    });
  });

  // -------------------------------------------------------------------------
  // Cursor on row boundary hover
  // -------------------------------------------------------------------------

  group('TableDividerResizeHandles — row cursor', () {
    testWidgets('cursor becomes resizeUpDown when hovering over interior row boundary',
        (tester) async {
      final layoutKey = GlobalKey<DocumentLayoutState>();
      // 3-row table: interior boundary between row 0 and row 1 (index 1).
      final table = _tableNode(id: 'tbl-1', rowCount: 3, columnCount: 2);
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          onRowResize: (nodeId, rowIndex, newHeight) {},
        ),
      );
      await tester.pumpAndSettle();

      final renderTable = layoutKey.currentState?.componentForNode('tbl-1') as RenderTableBlock?;
      expect(renderTable, isNotNull);
      final yPositions = renderTable!.rowBoundaryYPositions;
      expect(yPositions.length, greaterThanOrEqualTo(3));

      final tableGlobalOrigin = renderTable.localToGlobal(Offset.zero);
      // Interior row boundary at index 1 (between row 0 and row 1).
      final interiorY = tableGlobalOrigin.dy + yPositions[1];
      final xPositions = renderTable.columnBoundaryXPositions;
      final midX = tableGlobalOrigin.dx +
          (xPositions.isNotEmpty
              ? xPositions[0] + renderTable.computedOuterColumnWidths[0] / 2
              : 40.0);

      final handles = find.byType(TableDividerResizeHandles);
      expect(handles, findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset(midX, interiorY));
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(Offset(midX, interiorY));
      await tester.pump();

      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: handles, matching: find.byType(MouseRegion)),
      );
      expect(
        mouseRegion.cursor,
        SystemMouseCursors.resizeUpDown,
        reason: 'hovering over interior row boundary should give resizeUpDown cursor',
      );

      await gesture.removePointer();
    });
  });

  // -------------------------------------------------------------------------
  // No cursor change on outer edges
  // -------------------------------------------------------------------------

  group('TableDividerResizeHandles — outer edges', () {
    testWidgets('cursor stays defer when hovering on the outer left edge of table', (tester) async {
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final table = _tableNode(id: 'tbl-1', columnCount: 3, rowCount: 2);
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          onColumnResize: (nodeId, colIndex, newWidth) {},
        ),
      );
      await tester.pumpAndSettle();

      final renderTable = layoutKey.currentState?.componentForNode('tbl-1') as RenderTableBlock?;
      expect(renderTable, isNotNull);
      final xPositions = renderTable!.columnBoundaryXPositions;
      // Outer left edge: index 0.
      final tableGlobalOrigin = renderTable.localToGlobal(Offset.zero);
      final outerLeftX = tableGlobalOrigin.dx + xPositions[0];
      final midY = tableGlobalOrigin.dy + 20.0;

      final handles = find.byType(TableDividerResizeHandles);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset(outerLeftX, midY));
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(Offset(outerLeftX, midY));
      await tester.pump();

      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: handles, matching: find.byType(MouseRegion)),
      );
      expect(
        mouseRegion.cursor,
        MouseCursor.defer,
        reason: 'outer left edge should not trigger resize cursor',
      );

      await gesture.removePointer();
    });

    testWidgets('cursor becomes resizeLeftRight when hovering on the outer right edge',
        (tester) async {
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final table = _tableNode(id: 'tbl-1', columnCount: 3, rowCount: 2);
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          onColumnResize: (nodeId, colIndex, newWidth) {},
        ),
      );
      await tester.pumpAndSettle();

      final renderTable = layoutKey.currentState?.componentForNode('tbl-1') as RenderTableBlock?;
      expect(renderTable, isNotNull);
      final xPositions = renderTable!.columnBoundaryXPositions;
      // Outer right edge: last index.
      final tableGlobalOrigin = renderTable.localToGlobal(Offset.zero);
      final outerRightX = tableGlobalOrigin.dx + xPositions.last;
      final midY = tableGlobalOrigin.dy + 20.0;

      final handles = find.byType(TableDividerResizeHandles);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset(outerRightX, midY));
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(Offset(outerRightX, midY));
      await tester.pump();

      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: handles, matching: find.byType(MouseRegion)),
      );
      expect(
        mouseRegion.cursor,
        SystemMouseCursors.resizeLeftRight,
        reason: 'outer right edge should resize the last column',
      );

      await gesture.removePointer();
    });
  });

  // -------------------------------------------------------------------------
  // Column drag calls callback
  // -------------------------------------------------------------------------

  group('TableDividerResizeHandles — column drag', () {
    testWidgets('dragging column divider calls onColumnResize with nodeId, colIndex, and newWidth',
        (tester) async {
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final table = _tableNode(id: 'tbl-1', columnCount: 3, rowCount: 2);
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      final results = <(String, int, double)>[];

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          onColumnResize: (nodeId, colIndex, newWidth) {
            results.add((nodeId, colIndex, newWidth));
          },
        ),
      );
      await tester.pumpAndSettle();

      final renderTable = layoutKey.currentState?.componentForNode('tbl-1') as RenderTableBlock?;
      expect(renderTable, isNotNull);
      final xPositions = renderTable!.columnBoundaryXPositions;
      final outerWidths = renderTable.computedOuterColumnWidths;
      // Drag the first interior boundary (between col 0 and col 1).
      final colIndex = 0;
      final startingWidth = outerWidths[colIndex];
      final tableGlobalOrigin = renderTable.localToGlobal(Offset.zero);
      final dividerX = tableGlobalOrigin.dx + xPositions[1];
      final midY = tableGlobalOrigin.dy + 20.0;

      const dragDelta = 20.0;

      // Simulate pointer-down at divider, move right by dragDelta, then up.
      final gesture = await tester.startGesture(
        Offset(dividerX, midY),
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(dragDelta, 0.0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(results, isNotEmpty, reason: 'onColumnResize should have been called');
      final (nodeId, resizeColIndex, newWidth) = results.last;
      expect(nodeId, 'tbl-1');
      expect(resizeColIndex, colIndex);
      expect(
        newWidth,
        closeTo(startingWidth + dragDelta, 1.0),
        reason: 'newWidth should be startingWidth + dragDelta',
      );
    });

    testWidgets('column drag clamps newWidth to minimum (2*cellPadding + 1)', (tester) async {
      final layoutKey = GlobalKey<DocumentLayoutState>();
      // Fix the first column to a narrow width so we can drag it to minimum.
      final table = _tableNode(
        id: 'tbl-1',
        columnCount: 2,
        rowCount: 2,
        columnWidths: [30.0, null],
      );
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      final results = <(String, int, double)>[];

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          onColumnResize: (nodeId, colIndex, newWidth) {
            results.add((nodeId, colIndex, newWidth));
          },
        ),
      );
      await tester.pumpAndSettle();

      final renderTable = layoutKey.currentState?.componentForNode('tbl-1') as RenderTableBlock?;
      expect(renderTable, isNotNull);
      final xPositions = renderTable!.columnBoundaryXPositions;
      final tableGlobalOrigin = renderTable.localToGlobal(Offset.zero);
      final dividerX = tableGlobalOrigin.dx + xPositions[1];
      final midY = tableGlobalOrigin.dy + 20.0;
      final cellPadding = renderTable.cellPadding;
      final minWidth = 2.0 * cellPadding + 1.0;

      // Drag far to the left to exceed minimum.
      final gesture = await tester.startGesture(
        Offset(dividerX, midY),
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(-300.0, 0.0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(results, isNotEmpty);
      final (_, _, clampedWidth) = results.last;
      expect(
        clampedWidth,
        closeTo(minWidth, 0.01),
        reason: 'newWidth should be clamped to 2*cellPadding+1',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Row drag calls callback
  // -------------------------------------------------------------------------

  group('TableDividerResizeHandles — row drag', () {
    testWidgets('dragging row divider calls onRowResize with nodeId, rowIndex, and newHeight',
        (tester) async {
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final table = _tableNode(id: 'tbl-1', columnCount: 2, rowCount: 3);
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      final results = <(String, int, double)>[];

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          onRowResize: (nodeId, rowIndex, newHeight) {
            results.add((nodeId, rowIndex, newHeight));
          },
        ),
      );
      await tester.pumpAndSettle();

      final renderTable = layoutKey.currentState?.componentForNode('tbl-1') as RenderTableBlock?;
      expect(renderTable, isNotNull);
      final yPositions = renderTable!.rowBoundaryYPositions;
      final rowHeights = renderTable.computedRowHeights;
      // Drag the first interior row boundary (between row 0 and row 1).
      const rowIndex = 0;
      final startingHeight = rowHeights[rowIndex];
      final tableGlobalOrigin = renderTable.localToGlobal(Offset.zero);
      final dividerY = tableGlobalOrigin.dy + yPositions[1];
      final xPositions = renderTable.columnBoundaryXPositions;
      final midX = tableGlobalOrigin.dx +
          (xPositions.isNotEmpty
              ? xPositions[0] + renderTable.computedOuterColumnWidths[0] / 2
              : 40.0);

      const dragDelta = 15.0;

      final gesture = await tester.startGesture(
        Offset(midX, dividerY),
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0.0, dragDelta));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(results, isNotEmpty, reason: 'onRowResize should have been called');
      final (nodeId, resizeRowIndex, newHeight) = results.last;
      expect(nodeId, 'tbl-1');
      expect(resizeRowIndex, rowIndex);
      expect(
        newHeight,
        closeTo(startingHeight + dragDelta, 1.0),
        reason: 'newHeight should be startingHeight + dragDelta',
      );
    });

    testWidgets('row drag clamps newHeight to minimum (2*cellPadding + 1)', (tester) async {
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final table = _tableNode(
        id: 'tbl-1',
        columnCount: 2,
        rowCount: 2,
        rowHeights: [20.0, null],
      );
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      final results = <(String, int, double)>[];

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          onRowResize: (nodeId, rowIndex, newHeight) {
            results.add((nodeId, rowIndex, newHeight));
          },
        ),
      );
      await tester.pumpAndSettle();

      final renderTable = layoutKey.currentState?.componentForNode('tbl-1') as RenderTableBlock?;
      expect(renderTable, isNotNull);
      final yPositions = renderTable!.rowBoundaryYPositions;
      final tableGlobalOrigin = renderTable.localToGlobal(Offset.zero);
      final dividerY = tableGlobalOrigin.dy + yPositions[1];
      final xPositions = renderTable.columnBoundaryXPositions;
      final midX = tableGlobalOrigin.dx +
          (xPositions.isNotEmpty
              ? xPositions[0] + renderTable.computedOuterColumnWidths[0] / 2
              : 40.0);
      final cellPadding = renderTable.cellPadding;
      final minHeight = 2.0 * cellPadding + 1.0;

      // Drag far upward to exceed minimum.
      final gesture = await tester.startGesture(
        Offset(midX, dividerY),
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0.0, -300.0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(results, isNotEmpty);
      final (_, _, clampedHeight) = results.last;
      expect(
        clampedHeight,
        closeTo(minHeight, 0.01),
        reason: 'newHeight should be clamped to 2*cellPadding+1',
      );
    });
  });

  // -------------------------------------------------------------------------
  // isDragging flag
  // -------------------------------------------------------------------------

  group('TableDividerResizeHandles — isDragging flag', () {
    testWidgets('isDragging is true during drag and false after pointer up', (tester) async {
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final table = _tableNode(id: 'tbl-1', columnCount: 3, rowCount: 2);
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          onColumnResize: (nodeId, colIndex, newWidth) {},
        ),
      );
      await tester.pumpAndSettle();

      final renderTable = layoutKey.currentState?.componentForNode('tbl-1') as RenderTableBlock?;
      expect(renderTable, isNotNull);
      final xPositions = renderTable!.columnBoundaryXPositions;
      final tableGlobalOrigin = renderTable.localToGlobal(Offset.zero);
      final dividerX = tableGlobalOrigin.dx + xPositions[1];
      final midY = tableGlobalOrigin.dy + 20.0;

      expect(TableDividerResizeHandles.isDragging, isFalse, reason: 'idle before drag');

      final gesture = await tester.startGesture(
        Offset(dividerX, midY),
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await tester.pump();

      expect(TableDividerResizeHandles.isDragging, isTrue, reason: 'should be dragging');

      await gesture.up();
      await tester.pump();

      expect(TableDividerResizeHandles.isDragging, isFalse, reason: 'should be idle after up');
    });

    testWidgets('isDragging is false after pointer cancel', (tester) async {
      final layoutKey = GlobalKey<DocumentLayoutState>();
      final table = _tableNode(id: 'tbl-1', columnCount: 3, rowCount: 2);
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          layoutKey: layoutKey,
          onColumnResize: (nodeId, colIndex, newWidth) {},
        ),
      );
      await tester.pumpAndSettle();

      final renderTable = layoutKey.currentState?.componentForNode('tbl-1') as RenderTableBlock?;
      expect(renderTable, isNotNull);
      final xPositions = renderTable!.columnBoundaryXPositions;
      final tableGlobalOrigin = renderTable.localToGlobal(Offset.zero);
      final dividerX = tableGlobalOrigin.dx + xPositions[1];
      final midY = tableGlobalOrigin.dy + 20.0;

      final gesture = await tester.startGesture(
        Offset(dividerX, midY),
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await tester.pump();
      expect(TableDividerResizeHandles.isDragging, isTrue);

      await gesture.cancel();
      await tester.pump();

      expect(TableDividerResizeHandles.isDragging, isFalse, reason: 'should be idle after cancel');
    });
  });

  // -------------------------------------------------------------------------
  // No callback, no effect
  // -------------------------------------------------------------------------

  group('TableDividerResizeHandles — no-op when callbacks are null', () {
    testWidgets('TableDividerResizeHandles not in tree when both callbacks are null',
        (tester) async {
      final table = _tableNode(id: 'tbl-1', columnCount: 3, rowCount: 2);
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildWithOverlay(
          controller: controller,
          document: doc,
          // Both callbacks null → overlay should not be added.
          onColumnResize: null,
          onRowResize: null,
        ),
      );
      await tester.pumpAndSettle();

      // DocumentSelectionOverlay should not include TableDividerResizeHandles
      // when both callbacks are null and editor is also null.
      expect(find.byType(TableDividerResizeHandles), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // DocumentSelectionOverlay auto-wiring
  // -------------------------------------------------------------------------

  group('DocumentSelectionOverlay auto-wiring', () {
    testWidgets('auto-wires TableDividerResizeHandles when editor and document are provided',
        (tester) async {
      final table = _tableNode(id: 'tbl-1', columnCount: 3, rowCount: 2);
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      addTearDown(controller.dispose);
      final editor = UndoableEditor(
        editContext: EditContext(document: doc, controller: controller),
      );
      addTearDown(editor.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 600,
            height: 800,
            child: DocumentSelectionOverlay(
              controller: controller,
              layoutKey: layoutKey,
              startHandleLayerLink: LayerLink(),
              endHandleLayerLink: LayerLink(),
              document: doc,
              editor: editor,
              child: DocumentLayout(
                key: layoutKey,
                document: doc,
                controller: controller,
                componentBuilders: defaultComponentBuilders,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // With editor+document provided, TableDividerResizeHandles should be in
      // the tree (auto-wired callbacks for column AND row resize exist).
      expect(find.byType(TableDividerResizeHandles), findsOneWidget);
    });
  });
}
