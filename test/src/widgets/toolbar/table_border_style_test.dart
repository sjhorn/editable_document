/// Tests for table border style and width controls.
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/foundation.dart';
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

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

// ---------------------------------------------------------------------------
// TableNode.gridBorderStyle tests
// ---------------------------------------------------------------------------

void main() {
  group('TableNode.gridBorderStyle', () {
    test('defaults to BlockBorderStyle.solid', () {
      final table = _makeTable();
      expect(table.gridBorderStyle, BlockBorderStyle.solid);
    });

    test('copyWith preserves gridBorderStyle when not provided', () {
      final table = _makeTable().copyWith(gridBorderWidth: 2.0);
      expect(table.gridBorderStyle, BlockBorderStyle.solid);
    });

    test('copyWith changes gridBorderStyle', () {
      final table = _makeTable().copyWith(gridBorderStyle: BlockBorderStyle.dashed);
      expect(table.gridBorderStyle, BlockBorderStyle.dashed);
    });

    test('equality includes gridBorderStyle', () {
      final a = TableNode(
        id: 'x',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('')]
        ],
        gridBorderStyle: BlockBorderStyle.dotted,
      );
      final b = TableNode(
        id: 'x',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('')]
        ],
        gridBorderStyle: BlockBorderStyle.solid,
      );
      expect(a == b, isFalse);
    });

    test('hashCode differs for different gridBorderStyle', () {
      final a = TableNode(
        id: 'x',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('')]
        ],
        gridBorderStyle: BlockBorderStyle.dotted,
      );
      final b = a.copyWith(gridBorderStyle: BlockBorderStyle.dashed);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('debugFillProperties includes gridBorderStyle', () {
      final table = TableNode(
        id: 'x',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('')]
        ],
        gridBorderStyle: BlockBorderStyle.dashed,
      );
      final builder = DiagnosticPropertiesBuilder();
      table.debugFillProperties(builder);
      final names = builder.properties.map((DiagnosticsNode p) => p.name).toList();
      expect(names, contains('gridBorderStyle'));
    });
  });

  // -------------------------------------------------------------------------
  // TableComponentViewModel.gridBorderStyle
  // -------------------------------------------------------------------------

  group('TableComponentViewModel.gridBorderStyle', () {
    test('defaults to BlockBorderStyle.solid', () {
      final vm = TableComponentViewModel(
        nodeId: 'n',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('')]
        ],
      );
      expect(vm.gridBorderStyle, BlockBorderStyle.solid);
    });

    test('equality includes gridBorderStyle', () {
      final vm1 = TableComponentViewModel(
        nodeId: 'n',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('')]
        ],
        gridBorderStyle: BlockBorderStyle.dotted,
      );
      final vm2 = TableComponentViewModel(
        nodeId: 'n',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('')]
        ],
        gridBorderStyle: BlockBorderStyle.solid,
      );
      expect(vm1 == vm2, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // TableComponentBuilder wires gridBorderStyle
  // -------------------------------------------------------------------------

  group('TableComponentBuilder.createViewModel wires gridBorderStyle', () {
    test('passes dotted style from node to view model', () {
      final doc = MutableDocument([
        TableNode(
          id: 't1',
          rowCount: 1,
          columnCount: 1,
          cells: [
            [AttributedText('')]
          ],
          gridBorderStyle: BlockBorderStyle.dotted,
        ),
      ]);
      const builder = TableComponentBuilder();
      final vm = builder.createViewModel(doc, doc.nodes.first) as TableComponentViewModel;
      expect(vm.gridBorderStyle, BlockBorderStyle.dotted);
    });
  });

  // -------------------------------------------------------------------------
  // Toolbar border style/width menu items
  // -------------------------------------------------------------------------

  group('TableBorderOption style and width values', () {
    test('styleSolid, styleDotted, styleDashed, widthThin, widthThick exist', () {
      expect(TableBorderOption.styleSolid, isNotNull);
      expect(TableBorderOption.styleDotted, isNotNull);
      expect(TableBorderOption.styleDashed, isNotNull);
      expect(TableBorderOption.widthThin, isNotNull);
      expect(TableBorderOption.widthThick, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // _TableBorderDropdown shows style/width items
  // -------------------------------------------------------------------------

  group('TableContextToolbar border dropdown', () {
    testWidgets('shows style section with solid, dotted, dashed items', (tester) async {
      final table = _makeTable();
      final doc = MutableDocument([table]);
      final sel = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: table.id,
          nodePosition: const TableCellPosition(row: 0, col: 0, offset: 0),
        ),
      );
      final controller = DocumentEditingController(document: doc, selection: sel);

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: (_) {},
            nodeId: table.id,
            minRow: 0,
            maxRow: 0,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
            gridBorderStyle: BlockBorderStyle.solid,
            gridBorderWidth: 1.0,
            onBorderOptionSelected: (_) {},
          ),
        ),
      );

      // Tap border dropdown button to open the menu.
      await tester.tap(find.byTooltip('Borders'));
      await tester.pumpAndSettle();

      expect(find.text('Solid'), findsOneWidget);
      expect(find.text('Dotted'), findsOneWidget);
      expect(find.text('Dashed'), findsOneWidget);
      expect(find.text('Thin (1px)'), findsOneWidget);
      expect(find.text('Thick (2px)'), findsOneWidget);
    });

    testWidgets('solid style item shows check mark when gridBorderStyle is solid', (tester) async {
      final table = TableNode(
        id: 'table1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('')]
        ],
        gridBorderStyle: BlockBorderStyle.solid,
      );
      final doc = MutableDocument([table]);
      final sel = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: table.id,
          nodePosition: const TableCellPosition(row: 0, col: 0, offset: 0),
        ),
      );
      final controller = DocumentEditingController(document: doc, selection: sel);
      final captured = <TableBorderOption>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: (_) {},
            nodeId: table.id,
            minRow: 0,
            maxRow: 0,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 1,
            columnCount: 1,
            gridBorderStyle: BlockBorderStyle.solid,
            gridBorderWidth: 1.0,
            onBorderOptionSelected: captured.add,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Borders'));
      await tester.pumpAndSettle();

      // Tap styleSolid menu item.
      await tester.tap(find.text('Solid'));
      await tester.pumpAndSettle();

      expect(captured, contains(TableBorderOption.styleSolid));
    });

    testWidgets('widthThick item emits widthThick option', (tester) async {
      final table = _makeTable();
      final doc = MutableDocument([table]);
      final sel = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: table.id,
          nodePosition: const TableCellPosition(row: 0, col: 0, offset: 0),
        ),
      );
      final controller = DocumentEditingController(document: doc, selection: sel);
      final captured = <TableBorderOption>[];

      await tester.pumpWidget(
        _wrap(
          TableContextToolbar(
            controller: controller,
            requestHandler: (_) {},
            nodeId: table.id,
            minRow: 0,
            maxRow: 0,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 3,
            columnCount: 3,
            gridBorderStyle: BlockBorderStyle.solid,
            gridBorderWidth: 1.0,
            onBorderOptionSelected: captured.add,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Borders'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thick (2px)'));
      await tester.pumpAndSettle();

      expect(captured, contains(TableBorderOption.widthThick));
    });
  });

  // -------------------------------------------------------------------------
  // DocumentEditor handles style/width options
  // -------------------------------------------------------------------------

  group('DocumentEditor handles border style and width options', () {
    testWidgets('styleDotted option changes gridBorderStyle on the table node', (tester) async {
      final table = TableNode(
        id: 'table1',
        rowCount: 2,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')],
          [AttributedText('c'), AttributedText('d')],
        ],
      );
      final doc = MutableDocument([table]);
      final sel = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: table.id,
          nodePosition: const TableCellPosition(row: 0, col: 0, offset: 0),
        ),
      );
      final controller = DocumentEditingController(document: doc, selection: sel);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: DocumentEditor(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the Borders dropdown (tooltip).
      await tester.tap(find.byTooltip('Borders'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dotted'));
      await tester.pumpAndSettle();

      final updated = doc.nodeById('table1') as TableNode;
      expect(updated.gridBorderStyle, BlockBorderStyle.dotted);
    });

    testWidgets('widthThick option changes gridBorderWidth to 2.0', (tester) async {
      final table = TableNode(
        id: 'table1',
        rowCount: 2,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')],
          [AttributedText('c'), AttributedText('d')],
        ],
      );
      final doc = MutableDocument([table]);
      final sel = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: table.id,
          nodePosition: const TableCellPosition(row: 0, col: 0, offset: 0),
        ),
      );
      final controller = DocumentEditingController(document: doc, selection: sel);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: DocumentEditor(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Borders'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thick (2px)'));
      await tester.pumpAndSettle();

      final updated = doc.nodeById('table1') as TableNode;
      expect(updated.gridBorderWidth, 2.0);
    });
  });
}
