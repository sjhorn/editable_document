/// Tests for table-structural [EditCommand] implementations.
///
/// Tests cover [InsertTableRowCommand], [InsertTableColumnCommand],
/// [DeleteTableRowCommand], [DeleteTableColumnCommand], [ResizeTableCommand],
/// [ChangeTableCellAlignCommand], and [ChangeTableCellVerticalAlignCommand].
library;

import 'dart:ui' show TextAlign;

import 'package:editable_document/editable_document.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a 2×3 [TableNode] with known cell content.
///
/// Row 0: 'r0c0', 'r0c1', 'r0c2'
/// Row 1: 'r1c0', 'r1c1', 'r1c2'
TableNode _makeTable2x3({String id = 'tbl'}) => TableNode(
      id: id,
      rowCount: 2,
      columnCount: 3,
      cells: [
        [AttributedText('r0c0'), AttributedText('r0c1'), AttributedText('r0c2')],
        [AttributedText('r1c0'), AttributedText('r1c1'), AttributedText('r1c2')],
      ],
    );

/// Creates a 1×1 [TableNode].
TableNode _makeTable1x1({String id = 'tbl'}) => TableNode(
      id: id,
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('only')]
      ],
    );

/// Builds an [EditContext] wrapping [doc] with a controller whose initial
/// selection is set to cell ([row], [col]) offset 0 of node [tableId].
EditContext _ctxWithTableSel(
  MutableDocument doc, {
  required String tableId,
  required int row,
  required int col,
}) {
  final controller = DocumentEditingController(document: doc);
  controller.setSelection(
    DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: tableId,
        nodePosition: TableCellPosition(row: row, col: col, offset: 0),
      ),
    ),
  );
  return EditContext(document: doc, controller: controller);
}

/// Builds an [EditContext] wrapping [doc] with no initial selection.
EditContext _ctx(MutableDocument doc) => EditContext(
      document: doc,
      controller: DocumentEditingController(document: doc),
    );

// ---------------------------------------------------------------------------
// InsertTableRowCommand
// ---------------------------------------------------------------------------

void main() {
  group('InsertTableRowCommand', () {
    test('1. inserts a row before rowIndex=0', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 1, col: 0);

      final cmd = const InsertTableRowCommand(nodeId: 'tbl', rowIndex: 0, insertBefore: true);
      final events = cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowCount, 3);
      // New row at index 0 should be empty.
      expect(updated.cellAt(0, 0).text, '');
      // Old row 0 is now at index 1.
      expect(updated.cellAt(1, 0).text, 'r0c0');
      expect(events, [const NodeChangeEvent(nodeId: 'tbl')]);
    });

    test('2. inserts a row after rowIndex=0 (insertBefore: false)', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 0, col: 0);

      final cmd = const InsertTableRowCommand(nodeId: 'tbl', rowIndex: 0, insertBefore: false);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowCount, 3);
      expect(updated.cellAt(0, 0).text, 'r0c0');
      expect(updated.cellAt(1, 0).text, ''); // new row
      expect(updated.cellAt(2, 0).text, 'r1c0');
    });

    test('3. appends a row after last index', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 0, col: 0);

      final cmd = const InsertTableRowCommand(nodeId: 'tbl', rowIndex: 1, insertBefore: false);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowCount, 3);
      expect(updated.cellAt(2, 0).text, '');
    });

    test('4. shifts cursor row +1 when cursor is at or below insertion point', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      // Cursor at row=1; inserting a row before row=0 should shift cursor to row=2.
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 1, col: 2);

      final cmd = const InsertTableRowCommand(nodeId: 'tbl', rowIndex: 0, insertBefore: true);
      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      expect(sel, isNotNull);
      final pos = sel!.base.nodePosition as TableCellPosition;
      expect(pos.row, 2);
      expect(pos.col, 2);
    });

    test('5. does not shift cursor row when cursor is above insertion point', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      // Cursor at row=0; inserting after row=1 should not shift cursor.
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 0, col: 1);

      final cmd = const InsertTableRowCommand(nodeId: 'tbl', rowIndex: 1, insertBefore: false);
      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      final pos = sel!.base.nodePosition as TableCellPosition;
      expect(pos.row, 0);
    });

    test('6. extends cellVerticalAligns when non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')],
          [AttributedText('c'), AttributedText('d')],
        ],
        cellVerticalAligns: [
          [TableVerticalAlignment.top, TableVerticalAlignment.top],
          [TableVerticalAlignment.bottom, TableVerticalAlignment.bottom],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const InsertTableRowCommand(nodeId: 'tbl', rowIndex: 1, insertBefore: true);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellVerticalAligns, hasLength(3));
      // Row 0 unchanged.
      expect(updated.cellVerticalAligns![0][0], TableVerticalAlignment.top);
      expect(updated.cellVerticalAligns![0][1], TableVerticalAlignment.top);
      // New row at index 1 filled with top defaults.
      expect(updated.cellVerticalAligns![1][0], TableVerticalAlignment.top);
      expect(updated.cellVerticalAligns![1][1], TableVerticalAlignment.top);
      // Old row 1 shifted to index 2.
      expect(updated.cellVerticalAligns![2][0], TableVerticalAlignment.bottom);
      expect(updated.cellVerticalAligns![2][1], TableVerticalAlignment.bottom);
    });

    test('7. extends cellTextAligns when non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')],
          [AttributedText('c'), AttributedText('d')],
        ],
        cellTextAligns: [
          [TextAlign.left, TextAlign.right],
          [TextAlign.center, TextAlign.start],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const InsertTableRowCommand(nodeId: 'tbl', rowIndex: 1, insertBefore: true);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellTextAligns, hasLength(3));
      // Row 0 unchanged.
      expect(updated.cellTextAligns![0][0], TextAlign.left);
      expect(updated.cellTextAligns![0][1], TextAlign.right);
      // New row at index 1 filled with start defaults.
      expect(updated.cellTextAligns![1][0], TextAlign.start);
      expect(updated.cellTextAligns![1][1], TextAlign.start);
      // Old row 1 shifted to index 2.
      expect(updated.cellTextAligns![2][0], TextAlign.center);
      expect(updated.cellTextAligns![2][1], TextAlign.start);
    });

    test('8. leaves cellVerticalAligns null when originally null', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const InsertTableRowCommand(nodeId: 'tbl', rowIndex: 0, insertBefore: true);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellVerticalAligns, isNull);
    });

    test('9. leaves cellTextAligns null when originally null', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const InsertTableRowCommand(nodeId: 'tbl', rowIndex: 0, insertBefore: true);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellTextAligns, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // InsertTableColumnCommand
  // ---------------------------------------------------------------------------

  group('InsertTableColumnCommand', () {
    test('1. inserts a column before colIndex=0', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const InsertTableColumnCommand(nodeId: 'tbl', colIndex: 0, insertBefore: true);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnCount, 4);
      expect(updated.cellAt(0, 0).text, ''); // new column
      expect(updated.cellAt(0, 1).text, 'r0c0');
      expect(updated.cellAt(1, 1).text, 'r1c0');
    });

    test('2. inserts a column after colIndex=1 (insertBefore: false)', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const InsertTableColumnCommand(nodeId: 'tbl', colIndex: 1, insertBefore: false);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnCount, 4);
      expect(updated.cellAt(0, 1).text, 'r0c1');
      expect(updated.cellAt(0, 2).text, ''); // new column
      expect(updated.cellAt(0, 3).text, 'r0c2');
    });

    test('3. shifts cursor col +1 when cursor is at or right of insertion point', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      // Cursor at col=2; inserting before col=1 should shift cursor to col=3.
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 0, col: 2);

      final cmd = const InsertTableColumnCommand(nodeId: 'tbl', colIndex: 1, insertBefore: true);
      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      final pos = sel!.base.nodePosition as TableCellPosition;
      expect(pos.col, 3);
    });

    test('4. does not shift cursor col when cursor is left of insertion point', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      // Cursor at col=0; inserting after col=1 should not shift cursor.
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 0, col: 0);

      final cmd = const InsertTableColumnCommand(nodeId: 'tbl', colIndex: 1, insertBefore: false);
      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      final pos = sel!.base.nodePosition as TableCellPosition;
      expect(pos.col, 0);
    });

    test('5. extends columnWidths with null when non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 1,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')]
        ],
        columnWidths: [100.0, 200.0],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const InsertTableColumnCommand(nodeId: 'tbl', colIndex: 1, insertBefore: true);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnWidths, hasLength(3));
      expect(updated.columnWidths![0], 100.0);
      expect(updated.columnWidths![1], isNull); // new column
      expect(updated.columnWidths![2], 200.0);
    });

    test('6. extends cellTextAligns with TextAlign.start column when non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')],
          [AttributedText('c'), AttributedText('d')],
        ],
        cellTextAligns: [
          [TextAlign.left, TextAlign.right],
          [TextAlign.center, TextAlign.start],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const InsertTableColumnCommand(nodeId: 'tbl', colIndex: 1, insertBefore: true);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellTextAligns![0], hasLength(3));
      expect(updated.cellTextAligns![0][0], TextAlign.left);
      expect(updated.cellTextAligns![0][1], TextAlign.start); // new column default
      expect(updated.cellTextAligns![0][2], TextAlign.right);
      expect(updated.cellTextAligns![1][0], TextAlign.center);
      expect(updated.cellTextAligns![1][1], TextAlign.start); // new column default
      expect(updated.cellTextAligns![1][2], TextAlign.start);
    });

    test('7. extends cellVerticalAligns with TableVerticalAlignment.top column when non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')],
          [AttributedText('c'), AttributedText('d')],
        ],
        cellVerticalAligns: [
          [TableVerticalAlignment.top, TableVerticalAlignment.bottom],
          [TableVerticalAlignment.middle, TableVerticalAlignment.top],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const InsertTableColumnCommand(nodeId: 'tbl', colIndex: 1, insertBefore: true);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellVerticalAligns![0], hasLength(3));
      expect(updated.cellVerticalAligns![0][0], TableVerticalAlignment.top);
      expect(updated.cellVerticalAligns![0][1], TableVerticalAlignment.top); // new default
      expect(updated.cellVerticalAligns![0][2], TableVerticalAlignment.bottom);
      expect(updated.cellVerticalAligns![1][0], TableVerticalAlignment.middle);
      expect(updated.cellVerticalAligns![1][1], TableVerticalAlignment.top); // new default
      expect(updated.cellVerticalAligns![1][2], TableVerticalAlignment.top);
    });

    test('8. leaves columnWidths null when originally null', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const InsertTableColumnCommand(nodeId: 'tbl', colIndex: 0, insertBefore: true);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnWidths, isNull);
    });

    test('9. returns NodeChangeEvent', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const InsertTableColumnCommand(nodeId: 'tbl', colIndex: 0, insertBefore: true);
      final events = cmd.execute(ctx);

      expect(events, [const NodeChangeEvent(nodeId: 'tbl')]);
    });
  });

  // ---------------------------------------------------------------------------
  // DeleteTableRowCommand
  // ---------------------------------------------------------------------------

  group('DeleteTableRowCommand', () {
    test('1. deletes middle row', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 3,
        columnCount: 2,
        cells: [
          [AttributedText('r0c0'), AttributedText('r0c1')],
          [AttributedText('r1c0'), AttributedText('r1c1')],
          [AttributedText('r2c0'), AttributedText('r2c1')],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 2, col: 0);

      final cmd = const DeleteTableRowCommand(nodeId: 'tbl', rowIndex: 1);
      final events = cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowCount, 2);
      expect(updated.cellAt(0, 0).text, 'r0c0');
      expect(updated.cellAt(1, 0).text, 'r2c0');
      expect(events, [const NodeChangeEvent(nodeId: 'tbl')]);
    });

    test('2. deletes last remaining row — deletes entire table node', () {
      final table = _makeTable1x1();
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('before')),
        table,
      ]);
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 0, col: 0);

      final cmd = const DeleteTableRowCommand(nodeId: 'tbl', rowIndex: 0);
      cmd.execute(ctx);

      expect(doc.nodeById('tbl'), isNull);
    });

    test('3. adjusts cursor to previous row when deleting cursor row', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      // Cursor at row=1; deleting row=1 should move cursor to row=0.
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 1, col: 2);

      final cmd = const DeleteTableRowCommand(nodeId: 'tbl', rowIndex: 1);
      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      final pos = sel!.base.nodePosition as TableCellPosition;
      expect(pos.row, 0);
    });

    test('4. adjusts cursor to row 0 when deleting row 0 and cursor is there', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 3,
        columnCount: 1,
        cells: [
          [AttributedText('a')],
          [AttributedText('b')],
          [AttributedText('c')],
        ],
      );
      final doc = MutableDocument([table]);
      // Cursor at row=0; deleting row=0 should keep cursor at row=0.
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 0, col: 0);

      final cmd = const DeleteTableRowCommand(nodeId: 'tbl', rowIndex: 0);
      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      final pos = sel!.base.nodePosition as TableCellPosition;
      expect(pos.row, 0);
    });

    test('5. trims cellVerticalAligns row when non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 3,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')],
          [AttributedText('c'), AttributedText('d')],
          [AttributedText('e'), AttributedText('f')],
        ],
        cellVerticalAligns: [
          [TableVerticalAlignment.top, TableVerticalAlignment.top],
          [TableVerticalAlignment.middle, TableVerticalAlignment.middle],
          [TableVerticalAlignment.bottom, TableVerticalAlignment.bottom],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const DeleteTableRowCommand(nodeId: 'tbl', rowIndex: 1);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellVerticalAligns, hasLength(2));
      expect(updated.cellVerticalAligns![0][0], TableVerticalAlignment.top);
      expect(updated.cellVerticalAligns![0][1], TableVerticalAlignment.top);
      expect(updated.cellVerticalAligns![1][0], TableVerticalAlignment.bottom);
      expect(updated.cellVerticalAligns![1][1], TableVerticalAlignment.bottom);
    });

    test('6. trims cellTextAligns row when non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 3,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')],
          [AttributedText('c'), AttributedText('d')],
          [AttributedText('e'), AttributedText('f')],
        ],
        cellTextAligns: [
          [TextAlign.left, TextAlign.right],
          [TextAlign.center, TextAlign.start],
          [TextAlign.end, TextAlign.justify],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const DeleteTableRowCommand(nodeId: 'tbl', rowIndex: 1);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellTextAligns, hasLength(2));
      expect(updated.cellTextAligns![0][0], TextAlign.left);
      expect(updated.cellTextAligns![0][1], TextAlign.right);
      expect(updated.cellTextAligns![1][0], TextAlign.end);
      expect(updated.cellTextAligns![1][1], TextAlign.justify);
    });
  });

  // ---------------------------------------------------------------------------
  // DeleteTableColumnCommand
  // ---------------------------------------------------------------------------

  group('DeleteTableColumnCommand', () {
    test('1. deletes middle column', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const DeleteTableColumnCommand(nodeId: 'tbl', colIndex: 1);
      final events = cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnCount, 2);
      expect(updated.cellAt(0, 0).text, 'r0c0');
      expect(updated.cellAt(0, 1).text, 'r0c2');
      expect(events, [const NodeChangeEvent(nodeId: 'tbl')]);
    });

    test('2. deletes last remaining column — deletes entire table node', () {
      final table = _makeTable1x1();
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('before')),
        table,
      ]);
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 0, col: 0);

      final cmd = const DeleteTableColumnCommand(nodeId: 'tbl', colIndex: 0);
      cmd.execute(ctx);

      expect(doc.nodeById('tbl'), isNull);
    });

    test('3. adjusts cursor col when deleting cursor col (shifts to col-1)', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      // Cursor at col=2; deleting col=2 should move cursor to col=1.
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 0, col: 2);

      final cmd = const DeleteTableColumnCommand(nodeId: 'tbl', colIndex: 2);
      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      final pos = sel!.base.nodePosition as TableCellPosition;
      expect(pos.col, 1);
    });

    test('4. adjusts cursor col=0 when deleting col=0 (stays at 0)', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      // Cursor at col=0; deleting col=0 should keep cursor at col=0.
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 0, col: 0);

      final cmd = const DeleteTableColumnCommand(nodeId: 'tbl', colIndex: 0);
      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      final pos = sel!.base.nodePosition as TableCellPosition;
      expect(pos.col, 0);
    });

    test('5. trims columnWidths when non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 1,
        columnCount: 3,
        cells: [
          [AttributedText('a'), AttributedText('b'), AttributedText('c')]
        ],
        columnWidths: [100.0, 200.0, 300.0],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const DeleteTableColumnCommand(nodeId: 'tbl', colIndex: 1);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnWidths, hasLength(2));
      expect(updated.columnWidths![0], 100.0);
      expect(updated.columnWidths![1], 300.0);
    });

    test('6. trims cellTextAligns column when non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 3,
        cells: [
          [AttributedText('a'), AttributedText('b'), AttributedText('c')],
          [AttributedText('d'), AttributedText('e'), AttributedText('f')],
        ],
        cellTextAligns: [
          [TextAlign.left, TextAlign.center, TextAlign.right],
          [TextAlign.start, TextAlign.end, TextAlign.justify],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const DeleteTableColumnCommand(nodeId: 'tbl', colIndex: 1);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellTextAligns![0], hasLength(2));
      expect(updated.cellTextAligns![0][0], TextAlign.left);
      expect(updated.cellTextAligns![0][1], TextAlign.right);
      expect(updated.cellTextAligns![1][0], TextAlign.start);
      expect(updated.cellTextAligns![1][1], TextAlign.justify);
    });

    test('7. trims cellVerticalAligns column when non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 3,
        cells: [
          [AttributedText('a'), AttributedText('b'), AttributedText('c')],
          [AttributedText('d'), AttributedText('e'), AttributedText('f')],
        ],
        cellVerticalAligns: [
          [
            TableVerticalAlignment.top,
            TableVerticalAlignment.middle,
            TableVerticalAlignment.bottom
          ],
          [
            TableVerticalAlignment.bottom,
            TableVerticalAlignment.top,
            TableVerticalAlignment.middle
          ],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const DeleteTableColumnCommand(nodeId: 'tbl', colIndex: 1);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellVerticalAligns![0], hasLength(2));
      expect(updated.cellVerticalAligns![0][0], TableVerticalAlignment.top);
      expect(updated.cellVerticalAligns![0][1], TableVerticalAlignment.bottom);
      expect(updated.cellVerticalAligns![1][0], TableVerticalAlignment.bottom);
      expect(updated.cellVerticalAligns![1][1], TableVerticalAlignment.middle);
    });
  });

  // ---------------------------------------------------------------------------
  // ResizeTableCommand
  // ---------------------------------------------------------------------------

  group('ResizeTableCommand', () {
    test('1. grows rows and columns with empty cells', () {
      final table = _makeTable1x1();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ResizeTableCommand(nodeId: 'tbl', newRowCount: 3, newColumnCount: 2);
      final events = cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowCount, 3);
      expect(updated.columnCount, 2);
      expect(updated.cellAt(0, 0).text, 'only'); // original preserved
      expect(updated.cellAt(0, 1).text, ''); // new cell
      expect(updated.cellAt(1, 0).text, ''); // new row
      expect(updated.cellAt(2, 1).text, ''); // new row+col
      expect(events, [const NodeChangeEvent(nodeId: 'tbl')]);
    });

    test('2. shrinks rows and columns — truncates grid', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ResizeTableCommand(nodeId: 'tbl', newRowCount: 1, newColumnCount: 2);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowCount, 1);
      expect(updated.columnCount, 2);
      expect(updated.cellAt(0, 0).text, 'r0c0');
      expect(updated.cellAt(0, 1).text, 'r0c1');
    });

    test('3. clamps cursor when out of bounds after shrink', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      // Cursor at row=1, col=2 — both will be out of bounds after 1×2 resize.
      final ctx = _ctxWithTableSel(doc, tableId: 'tbl', row: 1, col: 2);

      final cmd = const ResizeTableCommand(nodeId: 'tbl', newRowCount: 1, newColumnCount: 2);
      cmd.execute(ctx);

      final sel = ctx.controller.selection;
      final pos = sel!.base.nodePosition as TableCellPosition;
      expect(pos.row, 0); // clamped from 1 to 0
      expect(pos.col, 1); // clamped from 2 to 1
    });

    test('4. truncates columnWidths when shrinking columns', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 1,
        columnCount: 3,
        cells: [
          [AttributedText('a'), AttributedText('b'), AttributedText('c')]
        ],
        columnWidths: [100.0, 200.0, 300.0],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ResizeTableCommand(nodeId: 'tbl', newRowCount: 1, newColumnCount: 2);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnWidths, hasLength(2));
      expect(updated.columnWidths![0], 100.0);
      expect(updated.columnWidths![1], 200.0);
    });

    test('5. truncates cellVerticalAligns 2D grid when shrinking', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 3,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')],
          [AttributedText('c'), AttributedText('d')],
          [AttributedText('e'), AttributedText('f')],
        ],
        cellVerticalAligns: [
          [TableVerticalAlignment.top, TableVerticalAlignment.top],
          [TableVerticalAlignment.middle, TableVerticalAlignment.middle],
          [TableVerticalAlignment.bottom, TableVerticalAlignment.bottom],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ResizeTableCommand(nodeId: 'tbl', newRowCount: 2, newColumnCount: 1);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellVerticalAligns, hasLength(2));
      expect(updated.cellVerticalAligns![0], hasLength(1));
      expect(updated.cellVerticalAligns![0][0], TableVerticalAlignment.top);
      expect(updated.cellVerticalAligns![1][0], TableVerticalAlignment.middle);
    });

    test('6. extends cellTextAligns 2D grid when growing', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 1,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')]
        ],
        cellTextAligns: [
          [TextAlign.left, TextAlign.right],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ResizeTableCommand(nodeId: 'tbl', newRowCount: 2, newColumnCount: 4);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellTextAligns, hasLength(2));
      expect(updated.cellTextAligns![0], hasLength(4));
      expect(updated.cellTextAligns![0][0], TextAlign.left);
      expect(updated.cellTextAligns![0][1], TextAlign.right);
      expect(updated.cellTextAligns![0][2], TextAlign.start); // new column
      expect(updated.cellTextAligns![0][3], TextAlign.start); // new column
      expect(updated.cellTextAligns![1][0], TextAlign.start); // new row
      expect(updated.cellTextAligns![1][1], TextAlign.start); // new row
    });

    test('7. extends cellVerticalAligns 2D grid when growing', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        cellVerticalAligns: [
          [TableVerticalAlignment.bottom],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ResizeTableCommand(nodeId: 'tbl', newRowCount: 2, newColumnCount: 2);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellVerticalAligns, hasLength(2));
      expect(updated.cellVerticalAligns![0], hasLength(2));
      expect(updated.cellVerticalAligns![0][0], TableVerticalAlignment.bottom);
      expect(updated.cellVerticalAligns![0][1], TableVerticalAlignment.top); // new
      expect(updated.cellVerticalAligns![1][0], TableVerticalAlignment.top); // new row
      expect(updated.cellVerticalAligns![1][1], TableVerticalAlignment.top); // new row
    });

    test('8. leaves null alignment lists null after resize', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ResizeTableCommand(nodeId: 'tbl', newRowCount: 3, newColumnCount: 4);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnWidths, isNull);
      expect(updated.cellTextAligns, isNull);
      expect(updated.cellVerticalAligns, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ChangeTableCellAlignCommand
  // ---------------------------------------------------------------------------

  group('ChangeTableCellAlignCommand', () {
    test('1. sets cell alignment when cellTextAligns is non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 3,
        cells: [
          [AttributedText('a'), AttributedText('b'), AttributedText('c')],
          [AttributedText('d'), AttributedText('e'), AttributedText('f')],
        ],
        cellTextAligns: [
          [TextAlign.start, TextAlign.start, TextAlign.start],
          [TextAlign.start, TextAlign.start, TextAlign.start],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableCellAlignCommand(
        nodeId: 'tbl',
        row: 1,
        col: 1,
        textAlign: TextAlign.center,
      );
      final events = cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellTextAligns![1][1], TextAlign.center);
      // Other cells unchanged.
      expect(updated.cellTextAligns![0][0], TextAlign.start);
      expect(updated.cellTextAligns![1][0], TextAlign.start);
      expect(events, [const NodeChangeEvent(nodeId: 'tbl')]);
    });

    test('2. initialises cellTextAligns from null and sets the entry', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableCellAlignCommand(
        nodeId: 'tbl',
        row: 1,
        col: 2,
        textAlign: TextAlign.right,
      );
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellTextAligns, isNotNull);
      expect(updated.cellTextAligns, hasLength(2));
      expect(updated.cellTextAligns![0], hasLength(3));
      // Only [1][2] is set; others default to start.
      expect(updated.cellTextAligns![0][0], TextAlign.start);
      expect(updated.cellTextAligns![1][2], TextAlign.right);
    });

    test('3. replaces existing cell alignment', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 1,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')]
        ],
        cellTextAligns: [
          [TextAlign.left, TextAlign.right],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableCellAlignCommand(
        nodeId: 'tbl',
        row: 0,
        col: 0,
        textAlign: TextAlign.center,
      );
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellTextAligns![0][0], TextAlign.center);
      expect(updated.cellTextAligns![0][1], TextAlign.right); // unchanged
    });
  });

  // ---------------------------------------------------------------------------
  // ChangeTableCellVerticalAlignCommand
  // ---------------------------------------------------------------------------

  group('ChangeTableCellVerticalAlignCommand', () {
    test('1. sets cell vertical alignment when cellVerticalAligns is non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 3,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')],
          [AttributedText('c'), AttributedText('d')],
          [AttributedText('e'), AttributedText('f')],
        ],
        cellVerticalAligns: [
          [TableVerticalAlignment.top, TableVerticalAlignment.top],
          [TableVerticalAlignment.top, TableVerticalAlignment.top],
          [TableVerticalAlignment.top, TableVerticalAlignment.top],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableCellVerticalAlignCommand(
        nodeId: 'tbl',
        row: 1,
        col: 0,
        verticalAlign: TableVerticalAlignment.middle,
      );
      final events = cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellVerticalAligns![1][0], TableVerticalAlignment.middle);
      // Other cells unchanged.
      expect(updated.cellVerticalAligns![0][0], TableVerticalAlignment.top);
      expect(updated.cellVerticalAligns![1][1], TableVerticalAlignment.top);
      expect(events, [const NodeChangeEvent(nodeId: 'tbl')]);
    });

    test('2. initialises cellVerticalAligns from null and sets the entry', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableCellVerticalAlignCommand(
        nodeId: 'tbl',
        row: 1,
        col: 2,
        verticalAlign: TableVerticalAlignment.bottom,
      );
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellVerticalAligns, isNotNull);
      expect(updated.cellVerticalAligns, hasLength(2));
      expect(updated.cellVerticalAligns![0], hasLength(3));
      // All cells default to top except [1][2].
      expect(updated.cellVerticalAligns![0][0], TableVerticalAlignment.top);
      expect(updated.cellVerticalAligns![1][2], TableVerticalAlignment.bottom);
    });

    test('3. replaces existing cell vertical alignment', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')],
          [AttributedText('c'), AttributedText('d')],
        ],
        cellVerticalAligns: [
          [TableVerticalAlignment.middle, TableVerticalAlignment.top],
          [TableVerticalAlignment.top, TableVerticalAlignment.bottom],
        ],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableCellVerticalAlignCommand(
        nodeId: 'tbl',
        row: 0,
        col: 0,
        verticalAlign: TableVerticalAlignment.bottom,
      );
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellVerticalAligns![0][0], TableVerticalAlignment.bottom);
      expect(updated.cellVerticalAligns![0][1], TableVerticalAlignment.top); // unchanged
      expect(updated.cellVerticalAligns![1][0], TableVerticalAlignment.top); // unchanged
    });
  });

  // ---------------------------------------------------------------------------
  // Request equality and toString tests
  // ---------------------------------------------------------------------------

  group('New request equality and toString', () {
    test('InsertTableRowRequest equality', () {
      const a = InsertTableRowRequest(nodeId: 'tbl', rowIndex: 1, insertBefore: true);
      const b = InsertTableRowRequest(nodeId: 'tbl', rowIndex: 1, insertBefore: true);
      const c = InsertTableRowRequest(nodeId: 'tbl', rowIndex: 2, insertBefore: true);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('tbl'));
    });

    test('InsertTableColumnRequest equality', () {
      const a = InsertTableColumnRequest(nodeId: 'tbl', colIndex: 0, insertBefore: false);
      const b = InsertTableColumnRequest(nodeId: 'tbl', colIndex: 0, insertBefore: false);
      const c = InsertTableColumnRequest(nodeId: 'tbl', colIndex: 1, insertBefore: false);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('tbl'));
    });

    test('DeleteTableRowRequest equality', () {
      const a = DeleteTableRowRequest(nodeId: 'tbl', rowIndex: 1);
      const b = DeleteTableRowRequest(nodeId: 'tbl', rowIndex: 1);
      const c = DeleteTableRowRequest(nodeId: 'tbl', rowIndex: 0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('tbl'));
    });

    test('DeleteTableColumnRequest equality', () {
      const a = DeleteTableColumnRequest(nodeId: 'tbl', colIndex: 2);
      const b = DeleteTableColumnRequest(nodeId: 'tbl', colIndex: 2);
      const c = DeleteTableColumnRequest(nodeId: 'tbl', colIndex: 0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('tbl'));
    });

    test('ResizeTableRequest equality', () {
      const a = ResizeTableRequest(nodeId: 'tbl', newRowCount: 3, newColumnCount: 4);
      const b = ResizeTableRequest(nodeId: 'tbl', newRowCount: 3, newColumnCount: 4);
      const c = ResizeTableRequest(nodeId: 'tbl', newRowCount: 2, newColumnCount: 4);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('tbl'));
    });

    test('ChangeTableCellAlignRequest equality', () {
      const a = ChangeTableCellAlignRequest(
        nodeId: 'tbl',
        row: 0,
        col: 1,
        textAlign: TextAlign.center,
      );
      const b = ChangeTableCellAlignRequest(
        nodeId: 'tbl',
        row: 0,
        col: 1,
        textAlign: TextAlign.center,
      );
      const c = ChangeTableCellAlignRequest(
        nodeId: 'tbl',
        row: 0,
        col: 1,
        textAlign: TextAlign.right,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('tbl'));
    });

    test('ChangeTableCellVerticalAlignRequest equality', () {
      const a = ChangeTableCellVerticalAlignRequest(
        nodeId: 'tbl',
        row: 0,
        col: 1,
        verticalAlign: TableVerticalAlignment.middle,
      );
      const b = ChangeTableCellVerticalAlignRequest(
        nodeId: 'tbl',
        row: 0,
        col: 1,
        verticalAlign: TableVerticalAlignment.middle,
      );
      const c = ChangeTableCellVerticalAlignRequest(
        nodeId: 'tbl',
        row: 0,
        col: 1,
        verticalAlign: TableVerticalAlignment.bottom,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('tbl'));
    });

    test('ChangeTableColumnWidthRequest equality', () {
      const a = ChangeTableColumnWidthRequest(nodeId: 'tbl', colIndex: 1, newWidth: 120.0);
      const b = ChangeTableColumnWidthRequest(nodeId: 'tbl', colIndex: 1, newWidth: 120.0);
      const c = ChangeTableColumnWidthRequest(nodeId: 'tbl', colIndex: 1, newWidth: 200.0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      // hashCode consistent with equality.
      expect(a.hashCode, b.hashCode);
    });

    test('ChangeTableColumnWidthRequest with null newWidth equality', () {
      const a = ChangeTableColumnWidthRequest(nodeId: 'tbl', colIndex: 0, newWidth: null);
      const b = ChangeTableColumnWidthRequest(nodeId: 'tbl', colIndex: 0, newWidth: null);
      const c = ChangeTableColumnWidthRequest(nodeId: 'tbl', colIndex: 0, newWidth: 80.0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('ChangeTableRowHeightRequest equality', () {
      const a = ChangeTableRowHeightRequest(nodeId: 'tbl', rowIndex: 0, newHeight: 60.0);
      const b = ChangeTableRowHeightRequest(nodeId: 'tbl', rowIndex: 0, newHeight: 60.0);
      const c = ChangeTableRowHeightRequest(nodeId: 'tbl', rowIndex: 1, newHeight: 60.0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      // hashCode consistent with equality.
      expect(a.hashCode, b.hashCode);
    });

    test('ChangeTableRowHeightRequest with null newHeight equality', () {
      const a = ChangeTableRowHeightRequest(nodeId: 'tbl', rowIndex: 2, newHeight: null);
      const b = ChangeTableRowHeightRequest(nodeId: 'tbl', rowIndex: 2, newHeight: null);
      const c = ChangeTableRowHeightRequest(nodeId: 'tbl', rowIndex: 2, newHeight: 50.0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // Editor wiring — Editor.submit dispatches to the correct command
  // ---------------------------------------------------------------------------

  group('Editor wiring', () {
    test('Editor dispatches InsertTableRowRequest', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final ctx = EditContext(document: doc, controller: controller);
      final editor = Editor(editContext: ctx);

      editor.submit(const InsertTableRowRequest(nodeId: 'tbl', rowIndex: 0));

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowCount, 3);
      editor.dispose();
    });

    test('Editor dispatches InsertTableColumnRequest', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final ctx = EditContext(document: doc, controller: controller);
      final editor = Editor(editContext: ctx);

      editor.submit(const InsertTableColumnRequest(nodeId: 'tbl', colIndex: 0));

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnCount, 4);
      editor.dispose();
    });

    test('Editor dispatches DeleteTableRowRequest', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final ctx = EditContext(document: doc, controller: controller);
      final editor = Editor(editContext: ctx);

      editor.submit(const DeleteTableRowRequest(nodeId: 'tbl', rowIndex: 0));

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowCount, 1);
      editor.dispose();
    });

    test('Editor dispatches DeleteTableColumnRequest', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final ctx = EditContext(document: doc, controller: controller);
      final editor = Editor(editContext: ctx);

      editor.submit(const DeleteTableColumnRequest(nodeId: 'tbl', colIndex: 0));

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnCount, 2);
      editor.dispose();
    });

    test('Editor dispatches ResizeTableRequest', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final ctx = EditContext(document: doc, controller: controller);
      final editor = Editor(editContext: ctx);

      editor.submit(const ResizeTableRequest(nodeId: 'tbl', newRowCount: 4, newColumnCount: 4));

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowCount, 4);
      expect(updated.columnCount, 4);
      editor.dispose();
    });

    test('Editor dispatches ChangeTableCellAlignRequest', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final ctx = EditContext(document: doc, controller: controller);
      final editor = Editor(editContext: ctx);

      editor.submit(
        const ChangeTableCellAlignRequest(
          nodeId: 'tbl',
          row: 0,
          col: 0,
          textAlign: TextAlign.center,
        ),
      );

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellTextAligns![0][0], TextAlign.center);
      editor.dispose();
    });

    test('Editor dispatches ChangeTableCellVerticalAlignRequest', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final ctx = EditContext(document: doc, controller: controller);
      final editor = Editor(editContext: ctx);

      editor.submit(
        const ChangeTableCellVerticalAlignRequest(
          nodeId: 'tbl',
          row: 0,
          col: 1,
          verticalAlign: TableVerticalAlignment.bottom,
        ),
      );

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.cellVerticalAligns![0][1], TableVerticalAlignment.bottom);
      editor.dispose();
    });

    test('Editor dispatches ChangeTableColumnWidthRequest', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 3,
        cells: [
          [AttributedText('r0c0'), AttributedText('r0c1'), AttributedText('r0c2')],
          [AttributedText('r1c0'), AttributedText('r1c1'), AttributedText('r1c2')],
        ],
      );
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final ctx = EditContext(document: doc, controller: controller);
      final editor = Editor(editContext: ctx);

      editor.submit(
        const ChangeTableColumnWidthRequest(nodeId: 'tbl', colIndex: 1, newWidth: 150.0),
      );

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnWidths, isNotNull);
      expect(updated.columnWidths![1], 150.0);
      editor.dispose();
    });

    test('Editor dispatches ChangeTableRowHeightRequest', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 3,
        cells: [
          [AttributedText('r0c0'), AttributedText('r0c1'), AttributedText('r0c2')],
          [AttributedText('r1c0'), AttributedText('r1c1'), AttributedText('r1c2')],
        ],
      );
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final ctx = EditContext(document: doc, controller: controller);
      final editor = Editor(editContext: ctx);

      editor.submit(
        const ChangeTableRowHeightRequest(nodeId: 'tbl', rowIndex: 0, newHeight: 80.0),
      );

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowHeights, isNotNull);
      expect(updated.rowHeights![0], 80.0);
      editor.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // ChangeTableColumnWidthCommand
  // ---------------------------------------------------------------------------

  group('ChangeTableColumnWidthCommand', () {
    test('1. sets column width when columnWidths is already non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 1,
        columnCount: 3,
        cells: [
          [AttributedText('a'), AttributedText('b'), AttributedText('c')]
        ],
        columnWidths: [100.0, 200.0, 300.0],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableColumnWidthCommand(
        nodeId: 'tbl',
        colIndex: 1,
        newWidth: 250.0,
      );
      final events = cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnWidths![0], 100.0); // unchanged
      expect(updated.columnWidths![1], 250.0); // updated
      expect(updated.columnWidths![2], 300.0); // unchanged
      expect(events, [const NodeChangeEvent(nodeId: 'tbl')]);
    });

    test('2. creates columnWidths from null when none existed', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableColumnWidthCommand(
        nodeId: 'tbl',
        colIndex: 2,
        newWidth: 180.0,
      );
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnWidths, isNotNull);
      expect(updated.columnWidths, hasLength(3));
      expect(updated.columnWidths![0], isNull); // auto
      expect(updated.columnWidths![1], isNull); // auto
      expect(updated.columnWidths![2], 180.0); // set
    });

    test('3. sets column width to null to revert to auto-sizing', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 1,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')]
        ],
        columnWidths: [120.0, 240.0],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableColumnWidthCommand(
        nodeId: 'tbl',
        colIndex: 0,
        newWidth: null,
      );
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.columnWidths![0], isNull);
      expect(updated.columnWidths![1], 240.0); // unchanged
    });
  });

  // ---------------------------------------------------------------------------
  // ChangeTableRowHeightCommand
  // ---------------------------------------------------------------------------

  group('ChangeTableRowHeightCommand', () {
    test('1. sets row height when rowHeights is already non-null', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 3,
        columnCount: 1,
        cells: [
          [AttributedText('a')],
          [AttributedText('b')],
          [AttributedText('c')],
        ],
        rowHeights: [40.0, 50.0, 60.0],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableRowHeightCommand(
        nodeId: 'tbl',
        rowIndex: 1,
        newHeight: 99.0,
      );
      final events = cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowHeights![0], 40.0); // unchanged
      expect(updated.rowHeights![1], 99.0); // updated
      expect(updated.rowHeights![2], 60.0); // unchanged
      expect(events, [const NodeChangeEvent(nodeId: 'tbl')]);
    });

    test('2. creates rowHeights from null when none existed', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableRowHeightCommand(
        nodeId: 'tbl',
        rowIndex: 0,
        newHeight: 70.0,
      );
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowHeights, isNotNull);
      expect(updated.rowHeights, hasLength(2));
      expect(updated.rowHeights![0], 70.0); // set
      expect(updated.rowHeights![1], isNull); // auto
    });

    test('3. sets row height to null to revert to auto-sizing', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 1,
        cells: [
          [AttributedText('a')],
          [AttributedText('b')],
        ],
        rowHeights: [80.0, 90.0],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      final cmd = const ChangeTableRowHeightCommand(
        nodeId: 'tbl',
        rowIndex: 1,
        newHeight: null,
      );
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowHeights![0], 80.0); // unchanged
      expect(updated.rowHeights![1], isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ResizeTableCommand preserves rowHeights
  // ---------------------------------------------------------------------------

  group('ResizeTableCommand rowHeights preservation', () {
    test('9. truncates rowHeights when shrinking rows', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 3,
        columnCount: 1,
        cells: [
          [AttributedText('a')],
          [AttributedText('b')],
          [AttributedText('c')],
        ],
        rowHeights: [40.0, 50.0, 60.0],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      const cmd = ResizeTableCommand(nodeId: 'tbl', newRowCount: 2, newColumnCount: 1);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowHeights, hasLength(2));
      expect(updated.rowHeights![0], 40.0);
      expect(updated.rowHeights![1], 50.0);
    });

    test('10. extends rowHeights with null when growing rows', () {
      final table = TableNode(
        id: 'tbl',
        rowCount: 2,
        columnCount: 1,
        cells: [
          [AttributedText('a')],
          [AttributedText('b')],
        ],
        rowHeights: [40.0, null],
      );
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      const cmd = ResizeTableCommand(nodeId: 'tbl', newRowCount: 4, newColumnCount: 1);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowHeights, hasLength(4));
      expect(updated.rowHeights![0], 40.0);
      expect(updated.rowHeights![1], isNull);
      expect(updated.rowHeights![2], isNull); // new
      expect(updated.rowHeights![3], isNull); // new
    });

    test('11. leaves null rowHeights null after resize', () {
      final table = _makeTable2x3();
      final doc = MutableDocument([table]);
      final ctx = _ctx(doc);

      const cmd = ResizeTableCommand(nodeId: 'tbl', newRowCount: 3, newColumnCount: 4);
      cmd.execute(ctx);

      final updated = doc.nodeById('tbl') as TableNode;
      expect(updated.rowHeights, isNull);
    });
  });
}
