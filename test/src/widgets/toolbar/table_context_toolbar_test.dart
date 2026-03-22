/// Tests for [TableContextToolbar].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

TableNode _makeTable({int rows = 3, int cols = 3}) => TableNode(
      id: 'table1',
      rowCount: rows,
      columnCount: cols,
      cells: List.generate(
        rows,
        (r) => List.generate(cols, (c) => AttributedText('r${r}c$c')),
      ),
    );

DocumentEditingController _makeController(TableNode table) {
  final doc = MutableDocument([table]);
  final sel = DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: table.id,
      nodePosition: const TableCellPosition(row: 0, col: 0, offset: 0),
    ),
  );
  return DocumentEditingController(document: doc, selection: sel);
}

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TableContextToolbar', () {
    testWidgets('renders without crashing', (tester) async {
      final table = _makeTable();
      final controller = _makeController(table);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: requests.add,
            nodeId: table.id,
            minRow: 0,
            maxRow: 0,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
          ),
        ),
      );

      expect(find.byType(TableContextToolbar), findsOneWidget);
    });

    testWidgets('insert row above button fires InsertTableRowRequest insertBefore=true',
        (tester) async {
      final table = _makeTable();
      final controller = _makeController(table);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: requests.add,
            nodeId: table.id,
            minRow: 1,
            maxRow: 1,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Insert row above'));
      await tester.pump();

      expect(requests, hasLength(1));
      final req = requests.first as InsertTableRowRequest;
      expect(req.nodeId, 'table1');
      expect(req.rowIndex, 1);
      expect(req.insertBefore, isTrue);
    });

    testWidgets('insert row below button fires InsertTableRowRequest insertBefore=false',
        (tester) async {
      final table = _makeTable();
      final controller = _makeController(table);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: requests.add,
            nodeId: table.id,
            minRow: 1,
            maxRow: 1,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Insert row below'));
      await tester.pump();

      expect(requests, hasLength(1));
      final req = requests.first as InsertTableRowRequest;
      expect(req.nodeId, 'table1');
      expect(req.rowIndex, 1);
      expect(req.insertBefore, isFalse);
    });

    testWidgets('insert column left fires InsertTableColumnRequest insertBefore=true',
        (tester) async {
      final table = _makeTable();
      final controller = _makeController(table);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: requests.add,
            nodeId: table.id,
            minRow: 0,
            maxRow: 0,
            minCol: 2,
            maxCol: 2,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Insert column left'));
      await tester.pump();

      expect(requests, hasLength(1));
      final req = requests.first as InsertTableColumnRequest;
      expect(req.nodeId, 'table1');
      expect(req.colIndex, 2);
      expect(req.insertBefore, isTrue);
    });

    testWidgets('insert column right fires InsertTableColumnRequest insertBefore=false',
        (tester) async {
      final table = _makeTable();
      final controller = _makeController(table);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: requests.add,
            nodeId: table.id,
            minRow: 0,
            maxRow: 0,
            minCol: 2,
            maxCol: 2,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Insert column right'));
      await tester.pump();

      expect(requests, hasLength(1));
      final req = requests.first as InsertTableColumnRequest;
      expect(req.nodeId, 'table1');
      expect(req.colIndex, 2);
      expect(req.insertBefore, isFalse);
    });

    testWidgets('delete row button fires DeleteTableRowRequest', (tester) async {
      final table = _makeTable();
      final controller = _makeController(table);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: requests.add,
            nodeId: table.id,
            minRow: 1,
            maxRow: 1,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Delete row'));
      await tester.pump();

      expect(requests, hasLength(1));
      final req = requests.first as DeleteTableRowRequest;
      expect(req.nodeId, 'table1');
      expect(req.rowIndex, 1);
    });

    testWidgets('delete column button fires DeleteTableColumnRequest', (tester) async {
      final table = _makeTable();
      final controller = _makeController(table);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: requests.add,
            nodeId: table.id,
            minRow: 0,
            maxRow: 0,
            minCol: 2,
            maxCol: 2,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Delete column'));
      await tester.pump();

      expect(requests, hasLength(1));
      final req = requests.first as DeleteTableColumnRequest;
      expect(req.nodeId, 'table1');
      expect(req.colIndex, 2);
    });

    testWidgets('delete table button fires DeleteTableRequest', (tester) async {
      final table = _makeTable();
      final controller = _makeController(table);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: requests.add,
            nodeId: table.id,
            minRow: 0,
            maxRow: 0,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Delete table'));
      await tester.pump();

      expect(requests, hasLength(1));
      final req = requests.first as DeleteTableRequest;
      expect(req.nodeId, 'table1');
    });

    testWidgets('cell align left button fires ChangeTableCellAlignRequest', (tester) async {
      final table = _makeTable();
      final controller = _makeController(table);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: requests.add,
            nodeId: table.id,
            minRow: 0,
            maxRow: 0,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Align column left'));
      await tester.pump();

      expect(requests, hasLength(1));
      final req = requests.first as ChangeTableCellAlignRequest;
      expect(req.nodeId, 'table1');
      expect(req.textAlign, TextAlign.start);
    });

    testWidgets('cell align center button fires ChangeTableCellAlignRequest', (tester) async {
      final table = _makeTable();
      final controller = _makeController(table);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: requests.add,
            nodeId: table.id,
            minRow: 0,
            maxRow: 0,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Align column center'));
      await tester.pump();

      expect(requests, hasLength(1));
      final req = requests.first as ChangeTableCellAlignRequest;
      expect(req.nodeId, 'table1');
      expect(req.textAlign, TextAlign.center);
    });

    testWidgets('row valign top button fires ChangeTableCellVerticalAlignRequest', (tester) async {
      final table = _makeTable();
      final controller = _makeController(table);
      final requests = <EditRequest>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: requests.add,
            nodeId: table.id,
            minRow: 0,
            maxRow: 0,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Align row top'));
      await tester.pump();

      expect(requests, hasLength(1));
      final req = requests.first as ChangeTableCellVerticalAlignRequest;
      expect(req.nodeId, 'table1');
      expect(req.verticalAlign, TableVerticalAlignment.top);
    });
  });
}
