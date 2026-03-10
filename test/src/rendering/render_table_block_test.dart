/// Tests for [RenderTableBlock].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lays out [block] with the given [maxWidth] and returns it ready for queries.
RenderTableBlock _layoutBlock(RenderTableBlock block, {double maxWidth = 400.0}) {
  block.layout(BoxConstraints(maxWidth: maxWidth), parentUsesSize: true);
  return block;
}

/// Creates a simple [RenderTableBlock] with [rowCount] × [columnCount] cells
/// whose text is `"r{row}c{col}"`.
RenderTableBlock _makeTable({
  required int rowCount,
  required int columnCount,
  List<double?>? columnWidths,
  double cellPadding = 8.0,
  double borderWidth = 1.0,
}) {
  final cells = List.generate(
    rowCount,
    (r) => List.generate(
      columnCount,
      (c) => AttributedText('r${r}c$c'),
    ),
  );
  return RenderTableBlock(
    nodeId: 'table1',
    rowCount: rowCount,
    columnCount: columnCount,
    cells: cells,
    textStyle: const TextStyle(fontSize: 16),
    columnWidths: columnWidths,
    cellPadding: cellPadding,
    borderWidth: borderWidth,
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // 1. Basic layout
  // ---------------------------------------------------------------------------
  group('RenderTableBlock basic layout', () {
    test('2×2 table has positive size', () {
      final block = _layoutBlock(_makeTable(rowCount: 2, columnCount: 2));
      expect(block.size.width, greaterThan(0));
      expect(block.size.height, greaterThan(0));
    });

    test('2×2 table fills the available width', () {
      final block = _layoutBlock(_makeTable(rowCount: 2, columnCount: 2));
      expect(block.size.width, 400.0);
    });

    test('table height is positive for 1×1', () {
      final block = _layoutBlock(_makeTable(rowCount: 1, columnCount: 1));
      expect(block.size.height, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Column width distribution
  // ---------------------------------------------------------------------------
  group('RenderTableBlock column width distribution', () {
    test('auto columns share available width equally', () {
      // 2 columns, no fixed widths — each gets half the available space (minus
      // borders and padding).  We just check the layout succeeds and that the
      // reported column widths are equal.
      final block = _layoutBlock(
        _makeTable(rowCount: 2, columnCount: 2, borderWidth: 0, cellPadding: 0),
        maxWidth: 200,
      );
      final widths = block.computedColumnWidths;
      expect(widths.length, 2);
      expect(widths[0], closeTo(widths[1], 0.5));
    });

    test('4 auto columns divide width equally', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 1, columnCount: 4, borderWidth: 0, cellPadding: 0),
        maxWidth: 400,
      );
      final widths = block.computedColumnWidths;
      for (final w in widths) {
        expect(w, closeTo(100.0, 0.5));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Fixed column widths
  // ---------------------------------------------------------------------------
  group('RenderTableBlock fixed column widths', () {
    test('fixed column width is respected', () {
      final block = _layoutBlock(
        RenderTableBlock(
          nodeId: 'table1',
          rowCount: 1,
          columnCount: 2,
          cells: [
            [AttributedText('A'), AttributedText('B')],
          ],
          textStyle: const TextStyle(fontSize: 16),
          columnWidths: [100.0, null],
          cellPadding: 0,
          borderWidth: 0,
        ),
        maxWidth: 400,
      );
      final widths = block.computedColumnWidths;
      expect(widths[0], closeTo(100.0, 0.5));
      // Second column takes remaining width.
      expect(widths[1], closeTo(300.0, 0.5));
    });

    test('two fixed columns use exactly those widths', () {
      final block = _layoutBlock(
        RenderTableBlock(
          nodeId: 'table1',
          rowCount: 1,
          columnCount: 2,
          cells: [
            [AttributedText('A'), AttributedText('B')],
          ],
          textStyle: const TextStyle(fontSize: 16),
          columnWidths: [120.0, 80.0],
          cellPadding: 0,
          borderWidth: 0,
        ),
        maxWidth: 400,
      );
      final widths = block.computedColumnWidths;
      expect(widths[0], closeTo(120.0, 0.5));
      expect(widths[1], closeTo(80.0, 0.5));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Row height
  // ---------------------------------------------------------------------------
  group('RenderTableBlock row height', () {
    test('row height is at least one line height', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 1, columnCount: 2, cellPadding: 0, borderWidth: 0),
      );
      final heights = block.computedRowHeights;
      expect(heights.length, 1);
      expect(heights[0], greaterThan(0));
    });

    test('row heights accumulate to total block height (no border/padding)', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 3, columnCount: 2, cellPadding: 0, borderWidth: 0),
      );
      final totalH = block.computedRowHeights.fold(0.0, (sum, h) => sum + h);
      expect(block.size.height, closeTo(totalH, 1.0));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Hit testing
  // ---------------------------------------------------------------------------
  group('RenderTableBlock hit testing', () {
    test('getPositionAtOffset returns TableCellPosition', () {
      final block = _layoutBlock(_makeTable(rowCount: 2, columnCount: 2));
      final pos = block.getPositionAtOffset(const Offset(10, 10));
      expect(pos, isA<TableCellPosition>());
    });

    test('tap in first cell returns row=0, col=0', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 2, columnCount: 2, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      final pos = block.getPositionAtOffset(const Offset(10, 5)) as TableCellPosition;
      expect(pos.row, 0);
      expect(pos.col, 0);
    });

    test('tap in second column returns col=1', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 2, columnCount: 2, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      // Second column starts at x≈100 (half of 200).
      final pos = block.getPositionAtOffset(const Offset(150, 5)) as TableCellPosition;
      expect(pos.col, 1);
    });

    test('tap in second row returns row=1', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 2, columnCount: 2, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      final firstRowH = block.computedRowHeights[0];
      final pos = block.getPositionAtOffset(Offset(10, firstRowH + 2)) as TableCellPosition;
      expect(pos.row, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Position to rect
  // ---------------------------------------------------------------------------
  group('RenderTableBlock getLocalRectForPosition', () {
    test('returns non-empty Rect for position in first cell', () {
      final block = _layoutBlock(_makeTable(rowCount: 2, columnCount: 2));
      final rect = block.getLocalRectForPosition(
        const TableCellPosition(row: 0, col: 0, offset: 0),
      );
      expect(rect, isA<Rect>());
      expect(rect.height, greaterThan(0));
    });

    test('position in second column has larger left than first column', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 1, columnCount: 2, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      final r0 = block.getLocalRectForPosition(
        const TableCellPosition(row: 0, col: 0, offset: 0),
      );
      final r1 = block.getLocalRectForPosition(
        const TableCellPosition(row: 0, col: 1, offset: 0),
      );
      expect(r1.left, greaterThan(r0.left));
    });

    test('position in second row has larger top than first row', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 2, columnCount: 1, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      final r0 = block.getLocalRectForPosition(
        const TableCellPosition(row: 0, col: 0, offset: 0),
      );
      final r1 = block.getLocalRectForPosition(
        const TableCellPosition(row: 1, col: 0, offset: 0),
      );
      expect(r1.top, greaterThan(r0.top));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Selection endpoints
  // ---------------------------------------------------------------------------
  group('RenderTableBlock getEndpointsForSelection', () {
    test('selection within single cell returns non-empty rects', () {
      final block = _layoutBlock(_makeTable(rowCount: 2, columnCount: 2));
      final rects = block.getEndpointsForSelection(
        const TableCellPosition(row: 0, col: 0, offset: 0),
        const TableCellPosition(row: 0, col: 0, offset: 3),
      );
      expect(rects, isNotEmpty);
      for (final r in rects) {
        expect(r.width, greaterThan(0));
        expect(r.height, greaterThan(0));
      }
    });

    test('collapsed selection returns empty list', () {
      final block = _layoutBlock(_makeTable(rowCount: 2, columnCount: 2));
      final rects = block.getEndpointsForSelection(
        const TableCellPosition(row: 0, col: 0, offset: 2),
        const TableCellPosition(row: 0, col: 0, offset: 2),
      );
      expect(rects, isEmpty);
    });

    test('cross-cell selection returns rects covering both cells', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 1, columnCount: 2, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      // Select from start of col 0 to start of col 1
      final rects = block.getEndpointsForSelection(
        const TableCellPosition(row: 0, col: 0, offset: 0),
        const TableCellPosition(row: 0, col: 1, offset: 0),
      );
      // At minimum the first cell should be highlighted.
      expect(rects, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Empty cells
  // ---------------------------------------------------------------------------
  group('RenderTableBlock empty cells', () {
    test('empty cell still lays out without error', () {
      final block = _layoutBlock(
        RenderTableBlock(
          nodeId: 'table1',
          rowCount: 2,
          columnCount: 2,
          cells: [
            [AttributedText(''), AttributedText('text')],
            [AttributedText('other'), AttributedText('')],
          ],
          textStyle: const TextStyle(fontSize: 16),
        ),
      );
      expect(block.size.height, greaterThan(0));
    });

    test('getPositionAtOffset on empty cell returns valid position', () {
      final block = _layoutBlock(
        RenderTableBlock(
          nodeId: 'table1',
          rowCount: 1,
          columnCount: 1,
          cells: [
            [AttributedText('')],
          ],
          textStyle: const TextStyle(fontSize: 16),
          cellPadding: 0,
          borderWidth: 0,
        ),
      );
      final pos = block.getPositionAtOffset(const Offset(5, 5));
      expect(pos, isA<TableCellPosition>());
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Single cell table
  // ---------------------------------------------------------------------------
  group('RenderTableBlock 1×1 table', () {
    test('1×1 table lays out and reports correct cell', () {
      final block = _layoutBlock(
        RenderTableBlock(
          nodeId: 'single',
          rowCount: 1,
          columnCount: 1,
          cells: [
            [AttributedText('Hello')],
          ],
          textStyle: const TextStyle(fontSize: 16),
          cellPadding: 0,
          borderWidth: 0,
        ),
        maxWidth: 200,
      );
      expect(block.size.width, 200.0);
      expect(block.size.height, greaterThan(0));

      final pos = block.getPositionAtOffset(const Offset(5, 5)) as TableCellPosition;
      expect(pos.row, 0);
      expect(pos.col, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Large table
  // ---------------------------------------------------------------------------
  group('RenderTableBlock large table', () {
    test('10×10 table lays out without errors', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 10, columnCount: 10),
        maxWidth: 800,
      );
      expect(block.size.width, 800.0);
      expect(block.size.height, greaterThan(0));
      expect(block.computedColumnWidths.length, 10);
      expect(block.computedRowHeights.length, 10);
    });
  });

  // ---------------------------------------------------------------------------
  // 11. nodeId / nodeSelection mutations
  // ---------------------------------------------------------------------------
  group('RenderTableBlock property mutations', () {
    test('nodeId setter updates without error', () {
      final block = _layoutBlock(_makeTable(rowCount: 1, columnCount: 1));
      block.nodeId = 'new_id';
      expect(block.nodeId, 'new_id');
    });

    test('nodeSelection setter updates without error', () {
      final block = _layoutBlock(_makeTable(rowCount: 1, columnCount: 1));
      // Just verify it doesn't throw.
      block.nodeSelection = null;
      expect(block.nodeSelection, isNull);
    });
  });
}
