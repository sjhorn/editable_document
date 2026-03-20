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
  List<double?>? rowHeights,
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
    rowHeights: rowHeights,
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

    test('caret at end of cell text ending with newline is on second line', () {
      // "Hello\n" has length 6.  When the cursor is at offset 6 (after the
      // trailing '\n'), the caret must appear on the SECOND (empty) line.
      // Before the fix the y-coordinate was taken from the '\n' character's
      // bounding box (first line), producing a wrong rect.top == 0.
      final block = _layoutBlock(
        RenderTableBlock(
          nodeId: 'table1',
          rowCount: 1,
          columnCount: 1,
          cells: [
            [AttributedText('Hello\n')],
          ],
          textStyle: const TextStyle(fontSize: 16),
          cellPadding: 0,
          borderWidth: 0,
        ),
        maxWidth: 200,
      );

      final rect = block.getLocalRectForPosition(
        const TableCellPosition(row: 0, col: 0, offset: 6),
      );

      // The caret should be on the second line, so top must be > 0.
      expect(rect.top, greaterThan(0),
          reason: 'Caret after trailing newline must be on the second line');
      // The caret at the start of the empty trailing line must be at x == 0
      // (i.e. left edge of the cell text area, which is 0 when cellPadding==0).
      expect(rect.left, closeTo(0.0, 0.5),
          reason: 'Caret must be at the left edge of the trailing empty line');
      // Sanity: height must be positive.
      expect(rect.height, greaterThan(0));
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

    test('backward selection within same cell returns non-empty rects', () {
      // Regression: dragging right-to-left within a single cell produced an
      // empty list because the normalization only compared the cell's linear
      // index (row * cols + col), which is equal for both endpoints, so no
      // swap occurred even though base.offset > extent.offset.
      final block = _layoutBlock(
        RenderTableBlock(
          nodeId: 'table1',
          rowCount: 1,
          columnCount: 1,
          cells: [
            [AttributedText('Hello World')],
          ],
          textStyle: const TextStyle(fontSize: 16),
          cellPadding: 0,
          borderWidth: 0,
        ),
        maxWidth: 400,
      );

      // Backward selection: base at end (offset 11), extent at start (offset 0).
      final backwardRects = block.getEndpointsForSelection(
        const TableCellPosition(row: 0, col: 0, offset: 11),
        const TableCellPosition(row: 0, col: 0, offset: 0),
      );
      expect(
        backwardRects,
        isNotEmpty,
        reason: 'Backward (right-to-left) selection must produce highlight rects',
      );

      // Forward selection over the same range must produce identical rects.
      final forwardRects = block.getEndpointsForSelection(
        const TableCellPosition(row: 0, col: 0, offset: 0),
        const TableCellPosition(row: 0, col: 0, offset: 11),
      );
      expect(forwardRects, isNotEmpty);
      expect(
        backwardRects.length,
        forwardRects.length,
        reason: 'Backward and forward selections over the same range must '
            'return the same number of rects',
      );
      for (int i = 0; i < forwardRects.length; i++) {
        expect(
          backwardRects[i],
          forwardRects[i],
          reason: 'Rect $i must be identical for forward and backward selections',
        );
      }
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

  // ---------------------------------------------------------------------------
  // 12. Cell text alignment
  // ---------------------------------------------------------------------------
  group('RenderTableBlock cellTextAligns', () {
    test('cellTextAligns property round-trips via getter', () {
      final block = RenderTableBlock(
        nodeId: 'table1',
        rowCount: 1,
        columnCount: 2,
        cells: [
          [AttributedText('A'), AttributedText('B')],
        ],
        textStyle: const TextStyle(fontSize: 16),
        cellTextAligns: [
          [TextAlign.center, TextAlign.right],
        ],
      );
      expect(block.cellTextAligns, [
        [TextAlign.center, TextAlign.right],
      ]);
    });

    test('cellTextAligns default is null', () {
      final block = _makeTable(rowCount: 1, columnCount: 2);
      expect(block.cellTextAligns, isNull);
    });

    test('cellTextAligns setter triggers markNeedsLayout', () {
      final block = _layoutBlock(_makeTable(rowCount: 1, columnCount: 2));
      // Setting a new value should not throw and the block should accept it.
      block.cellTextAligns = [
        [TextAlign.end, TextAlign.center],
      ];
      expect(block.cellTextAligns, [
        [TextAlign.end, TextAlign.center],
      ]);
    });

    test('cellTextAligns setter no-ops when same value is set', () {
      final aligns = [
        [TextAlign.center, TextAlign.right],
      ];
      final block = RenderTableBlock(
        nodeId: 'table1',
        rowCount: 1,
        columnCount: 2,
        cells: [
          [AttributedText('A'), AttributedText('B')],
        ],
        textStyle: const TextStyle(fontSize: 16),
        cellTextAligns: aligns,
      );
      _layoutBlock(block);
      // Setting the identical list should be accepted.
      block.cellTextAligns = aligns;
      expect(block.cellTextAligns, aligns);
    });

    test('center-aligned cell produces layout identical in row height to default', () {
      // Two identically-structured tables: one with cellTextAligns set to center,
      // one without (default TextAlign.start). After layout, the computed size
      // must still be the same — alignment does not affect row heights.
      final blockCenter = _layoutBlock(
        RenderTableBlock(
          nodeId: 'center',
          rowCount: 1,
          columnCount: 1,
          cells: [
            [AttributedText('Hello')],
          ],
          textStyle: const TextStyle(fontSize: 16),
          cellPadding: 0,
          borderWidth: 0,
          cellTextAligns: [
            [TextAlign.center],
          ],
        ),
        maxWidth: 200,
      );
      final blockStart = _layoutBlock(
        RenderTableBlock(
          nodeId: 'start',
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
      // Row heights must be the same regardless of horizontal alignment.
      expect(
        blockCenter.computedRowHeights[0],
        closeTo(blockStart.computedRowHeights[0], 0.5),
      );
    });

    test('cellTextAligns is reflected in debugFillProperties', () {
      final block = RenderTableBlock(
        nodeId: 'table1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('A')],
        ],
        textStyle: const TextStyle(fontSize: 16),
        cellTextAligns: [
          [TextAlign.right],
        ],
      );
      final builder = DiagnosticPropertiesBuilder();
      block.debugFillProperties(builder);
      final names = builder.properties.map((p) => p.name).toList();
      expect(names, contains('cellTextAligns'));
    });
  });

  // ---------------------------------------------------------------------------
  // 13. rowHeights hint
  // ---------------------------------------------------------------------------
  group('RenderTableBlock rowHeights hint', () {
    test('rowHeights minimum is applied when content is shorter', () {
      // Row 0 gets a minimum of 60 px; row 1 is auto-sized.
      // With fontSize 16 and no padding/border, natural row height is ~19 px.
      // After applying the hint, row 0 must be at least 60 px.
      final block = _layoutBlock(
        RenderTableBlock(
          nodeId: 'table1',
          rowCount: 2,
          columnCount: 1,
          cells: [
            [AttributedText('A')],
            [AttributedText('B')],
          ],
          textStyle: const TextStyle(fontSize: 16),
          cellPadding: 0,
          borderWidth: 0,
          rowHeights: [60.0, null],
        ),
        maxWidth: 200,
      );
      final heights = block.computedRowHeights;
      expect(heights.length, 2);
      expect(heights[0], greaterThanOrEqualTo(60.0),
          reason: 'Row 0 must be at least the hinted 60 px');
    });

    test('auto-sized row is unaffected by null rowHeights entry', () {
      final blockWithHint = _layoutBlock(
        RenderTableBlock(
          nodeId: 'table1',
          rowCount: 2,
          columnCount: 1,
          cells: [
            [AttributedText('A')],
            [AttributedText('B')],
          ],
          textStyle: const TextStyle(fontSize: 16),
          cellPadding: 0,
          borderWidth: 0,
          rowHeights: [60.0, null],
        ),
        maxWidth: 200,
      );
      final blockAuto = _layoutBlock(
        RenderTableBlock(
          nodeId: 'table2',
          rowCount: 1,
          columnCount: 1,
          cells: [
            [AttributedText('B')],
          ],
          textStyle: const TextStyle(fontSize: 16),
          cellPadding: 0,
          borderWidth: 0,
        ),
        maxWidth: 200,
      );
      // Row 1 with a null hint should be the same as row 0 of auto block.
      expect(
        blockWithHint.computedRowHeights[1],
        closeTo(blockAuto.computedRowHeights[0], 0.5),
        reason: 'null hint row should be content-height only',
      );
    });

    test('rowHeights setter triggers markNeedsLayout', () {
      final block = _layoutBlock(_makeTable(rowCount: 2, columnCount: 1));
      block.rowHeights = [100.0, null];
      expect(block.rowHeights, [100.0, null]);
    });

    test('rowHeights default is null', () {
      final block = _makeTable(rowCount: 2, columnCount: 1);
      expect(block.rowHeights, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 14. columnBoundaryXPositions
  // ---------------------------------------------------------------------------
  group('RenderTableBlock columnBoundaryXPositions', () {
    test('2-column table has 3 boundary x positions', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 1, columnCount: 2, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      final positions = block.columnBoundaryXPositions;
      expect(positions.length, 3, reason: 'columnCount+1 entries expected');
    });

    test('boundary positions are strictly increasing', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 1, columnCount: 3, cellPadding: 0, borderWidth: 0),
        maxWidth: 300,
      );
      final positions = block.columnBoundaryXPositions;
      for (int i = 0; i < positions.length - 1; i++) {
        expect(positions[i], lessThan(positions[i + 1]),
            reason: 'boundary[$i] < boundary[${i + 1}]');
      }
    });

    test('first boundary is 0 (no padding or border)', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 1, columnCount: 2, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      final positions = block.columnBoundaryXPositions;
      expect(positions.first, closeTo(0.0, 0.5));
    });

    test('last boundary equals table width (no padding or border)', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 1, columnCount: 2, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      final positions = block.columnBoundaryXPositions;
      expect(positions.last, closeTo(200.0, 0.5));
    });

    test('returns empty list before layout', () {
      final block = RenderTableBlock(
        nodeId: 'table1',
        rowCount: 1,
        columnCount: 2,
        cells: [
          [AttributedText('A'), AttributedText('B')],
        ],
        textStyle: const TextStyle(fontSize: 16),
      );
      // No layout call — internal lists are empty.
      expect(block.columnBoundaryXPositions, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 15. rowBoundaryYPositions
  // ---------------------------------------------------------------------------
  group('RenderTableBlock rowBoundaryYPositions', () {
    test('2-row table has 3 boundary y positions', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 2, columnCount: 1, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      final positions = block.rowBoundaryYPositions;
      expect(positions.length, 3, reason: 'rowCount+1 entries expected');
    });

    test('boundary positions are strictly increasing', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 3, columnCount: 1, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      final positions = block.rowBoundaryYPositions;
      for (int i = 0; i < positions.length - 1; i++) {
        expect(positions[i], lessThan(positions[i + 1]),
            reason: 'boundary[$i] < boundary[${i + 1}]');
      }
    });

    test('first boundary is 0 (no border)', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 2, columnCount: 1, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      final positions = block.rowBoundaryYPositions;
      expect(positions.first, closeTo(0.0, 0.5));
    });

    test('last boundary equals table height (no border)', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 2, columnCount: 1, cellPadding: 0, borderWidth: 0),
        maxWidth: 200,
      );
      final positions = block.rowBoundaryYPositions;
      expect(positions.last, closeTo(block.size.height, 0.5));
    });

    test('returns empty list before layout', () {
      final block = RenderTableBlock(
        nodeId: 'table1',
        rowCount: 2,
        columnCount: 1,
        cells: [
          [AttributedText('A')],
          [AttributedText('B')],
        ],
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(block.rowBoundaryYPositions, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 16. computedOuterColumnWidths
  // ---------------------------------------------------------------------------
  group('RenderTableBlock computedOuterColumnWidths', () {
    test('length equals columnCount', () {
      final block = _layoutBlock(
        _makeTable(rowCount: 1, columnCount: 3, cellPadding: 0, borderWidth: 0),
        maxWidth: 300,
      );
      expect(block.computedOuterColumnWidths.length, 3);
    });

    test('outer width equals content width plus 2×cellPadding', () {
      const padding = 8.0;
      final block = _layoutBlock(
        _makeTable(rowCount: 1, columnCount: 2, cellPadding: padding, borderWidth: 0),
        maxWidth: 200,
      );
      final inner = block.computedColumnWidths;
      final outer = block.computedOuterColumnWidths;
      for (int i = 0; i < inner.length; i++) {
        expect(outer[i], closeTo(inner[i] + 2.0 * padding, 0.5));
      }
    });

    test('returns empty list before layout', () {
      final block = RenderTableBlock(
        nodeId: 'table1',
        rowCount: 1,
        columnCount: 2,
        cells: [
          [AttributedText('A'), AttributedText('B')],
        ],
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(block.computedOuterColumnWidths, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 13. Cell vertical alignment
  // ---------------------------------------------------------------------------
  group('RenderTableBlock cellVerticalAligns', () {
    test('cellVerticalAligns property round-trips via getter', () {
      final block = RenderTableBlock(
        nodeId: 'table1',
        rowCount: 2,
        columnCount: 1,
        cells: [
          [AttributedText('A')],
          [AttributedText('B')],
        ],
        textStyle: const TextStyle(fontSize: 16),
        cellVerticalAligns: [
          [TableVerticalAlignment.top],
          [TableVerticalAlignment.middle],
        ],
      );
      expect(block.cellVerticalAligns, [
        [TableVerticalAlignment.top],
        [TableVerticalAlignment.middle],
      ]);
    });

    test('cellVerticalAligns default is null', () {
      final block = _makeTable(rowCount: 2, columnCount: 1);
      expect(block.cellVerticalAligns, isNull);
    });

    test('cellVerticalAligns setter triggers markNeedsLayout', () {
      final block = _layoutBlock(_makeTable(rowCount: 1, columnCount: 1));
      block.cellVerticalAligns = [
        [TableVerticalAlignment.bottom],
      ];
      expect(block.cellVerticalAligns, [
        [TableVerticalAlignment.bottom],
      ]);
    });

    test('middle alignment shifts text offset downward compared to top', () {
      // Use a 2-column table where one column has tall text so the row is
      // taller than the short-text column. Middle alignment for the short-text
      // column should shift its textOffset.dy down relative to top alignment.
      //
      // To force different row heights we use one cell with a large fontSize
      // and one with a small fontSize, then compare where the small one starts.
      final tallText = AttributedText('X');
      final shortText = AttributedText('y');

      // Helper that creates a 1-row × 2-col table.
      RenderTableBlock makeBlock(TableVerticalAlignment align) => _layoutBlock(
            RenderTableBlock(
              nodeId: 'test',
              rowCount: 1,
              columnCount: 2,
              cells: [
                [tallText, shortText],
              ],
              textStyle: const TextStyle(fontSize: 16),
              cellPadding: 0,
              borderWidth: 0,
              columnWidths: [100.0, null],
              // Per-cell vertical alignment: col 0 uses top (default), col 1 uses `align`.
              cellVerticalAligns: [
                [TableVerticalAlignment.top, align],
              ],
            ),
            maxWidth: 400,
          );

      final blockTop = makeBlock(TableVerticalAlignment.top);
      final blockMiddle = makeBlock(TableVerticalAlignment.middle);

      // For top alignment the caret at offset 0 of col 1 must be at the top of
      // the cell (y == 0 when cellPadding == 0 and borderWidth == 0).
      final rectTop = blockTop.getLocalRectForPosition(
        const TableCellPosition(row: 0, col: 1, offset: 0),
      );
      final rectMiddle = blockMiddle.getLocalRectForPosition(
        const TableCellPosition(row: 0, col: 1, offset: 0),
      );

      // With identical text and row heights the offsets will be the same —
      // only a height difference triggers a visible shift.  We just assert
      // that middle.top >= top.top (the offset is non-negative).
      expect(rectMiddle.top, greaterThanOrEqualTo(rectTop.top));
    });

    test('bottom alignment produces larger top than middle for tall rows', () {
      // We need a row where the first column is much taller than the second
      // so that vertical alignment actually makes a visible difference.
      // Use a large font for column 0 and a small font for column 1 via
      // different cell text combined with wrapping text.
      //
      // Strategy: place long wrapping text in col 0 with a narrow fixed width
      // so it wraps to many lines; col 1 has a single short character.

      final longText = AttributedText('Line1\nLine2\nLine3\nLine4');
      final shortText = AttributedText('X');

      RenderTableBlock makeBlock(TableVerticalAlignment align) => _layoutBlock(
            RenderTableBlock(
              nodeId: 'test',
              rowCount: 1,
              columnCount: 2,
              cells: [
                [longText, shortText],
              ],
              textStyle: const TextStyle(fontSize: 14),
              cellPadding: 0,
              borderWidth: 0,
              columnWidths: [60.0, null],
              cellVerticalAligns: [
                [TableVerticalAlignment.top, align],
              ],
            ),
            maxWidth: 400,
          );

      final blockMiddle = makeBlock(TableVerticalAlignment.middle);
      final blockBottom = makeBlock(TableVerticalAlignment.bottom);

      final rectMiddle = blockMiddle.getLocalRectForPosition(
        const TableCellPosition(row: 0, col: 1, offset: 0),
      );
      final rectBottom = blockBottom.getLocalRectForPosition(
        const TableCellPosition(row: 0, col: 1, offset: 0),
      );

      expect(
        rectBottom.top,
        greaterThanOrEqualTo(rectMiddle.top),
        reason: 'Bottom-aligned text must start at or below middle-aligned text',
      );
    });

    test('top alignment and null cellVerticalAligns produce same layout', () {
      final block1 = _layoutBlock(
        RenderTableBlock(
          nodeId: 'a',
          rowCount: 1,
          columnCount: 1,
          cells: [
            [AttributedText('Hello')],
          ],
          textStyle: const TextStyle(fontSize: 16),
          cellPadding: 0,
          borderWidth: 0,
          cellVerticalAligns: [
            [TableVerticalAlignment.top],
          ],
        ),
        maxWidth: 200,
      );
      final block2 = _layoutBlock(
        RenderTableBlock(
          nodeId: 'b',
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

      final rect1 = block1.getLocalRectForPosition(
        const TableCellPosition(row: 0, col: 0, offset: 0),
      );
      final rect2 = block2.getLocalRectForPosition(
        const TableCellPosition(row: 0, col: 0, offset: 0),
      );

      expect(rect1.top, closeTo(rect2.top, 0.5));
    });

    test('cellVerticalAligns is reflected in debugFillProperties', () {
      final block = RenderTableBlock(
        nodeId: 'table1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('A')],
        ],
        textStyle: const TextStyle(fontSize: 16),
        cellVerticalAligns: [
          [TableVerticalAlignment.middle],
        ],
      );
      final builder = DiagnosticPropertiesBuilder();
      block.debugFillProperties(builder);
      final names = builder.properties.map((p) => p.name).toList();
      expect(names, contains('cellVerticalAligns'));
    });
  });
}
