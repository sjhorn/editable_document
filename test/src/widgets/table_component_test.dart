/// Tests for [TableComponentBuilder] and [TableComponentViewModel].
///
/// Covers:
/// - [TableComponentBuilder.createViewModel] returns the correct type for
///   [TableNode] and `null` for other node types.
/// - [TableComponentViewModel] equality and field forwarding.
/// - [TableComponentBuilder.createComponent] widget creation.
/// - Presence of [TableComponentBuilder] in [defaultComponentBuilders].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// A minimal [ComponentViewModel] for testing that [createComponent] correctly
/// rejects wrong view-model types.
class _OtherViewModel extends ComponentViewModel {
  const _OtherViewModel({required super.nodeId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _OtherViewModel && other.nodeId == nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

/// Constructs a minimal 2×2 [TableNode].
TableNode _table({
  String id = 't1',
  int rowCount = 2,
  int columnCount = 2,
  BlockAlignment alignment = BlockAlignment.stretch,
  TextWrapMode textWrap = TextWrapMode.none,
  double? width,
  double? height,
  List<double?>? columnWidths,
}) {
  final cells = List.generate(
    rowCount,
    (_) => List.generate(columnCount, (_) => AttributedText('cell')),
  );
  return TableNode(
    id: id,
    rowCount: rowCount,
    columnCount: columnCount,
    cells: cells,
    columnWidths: columnWidths,
    alignment: alignment,
    textWrap: textWrap,
    width: width != null ? BlockDimension.pixels(width) : null,
    height: height != null ? BlockDimension.pixels(height) : null,
  );
}

Document _doc(List<DocumentNode> nodes) => Document(nodes);

ComponentContext _ctx(Document doc) =>
    ComponentContext(document: doc, selection: null, stylesheet: null);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // TableComponentBuilder.createViewModel
  // -------------------------------------------------------------------------

  group('TableComponentBuilder.createViewModel', () {
    const builder = TableComponentBuilder();

    test('returns non-null TableComponentViewModel for TableNode', () {
      final node = _table();
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node);

      expect(vm, isNotNull);
      expect(vm, isA<TableComponentViewModel>());
    });

    test('returns null for ParagraphNode', () {
      final para = ParagraphNode(id: 'p1', text: AttributedText('Hello'));
      final doc = _doc([para]);
      final vm = builder.createViewModel(doc, para);

      expect(vm, isNull);
    });

    test('returns null for ImageNode', () {
      final img = ImageNode(id: 'img1', imageUrl: 'https://example.com/img.png');
      final doc = _doc([img]);
      final vm = builder.createViewModel(doc, img);

      expect(vm, isNull);
    });

    test('wires rowCount and columnCount from TableNode', () {
      final node = _table(rowCount: 3, columnCount: 4);
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as TableComponentViewModel;

      expect(vm.rowCount, 3);
      expect(vm.columnCount, 4);
    });

    test('wires alignment from TableNode', () {
      final node = _table(alignment: BlockAlignment.center);
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as TableComponentViewModel;

      expect(vm.alignment, BlockAlignment.center);
    });

    test('wires textWrap from TableNode', () {
      final node = _table(textWrap: TextWrapMode.wrap);
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as TableComponentViewModel;

      expect(vm.textWrap, TextWrapMode.wrap);
    });

    test('wires width from TableNode', () {
      final node = _table(width: 400.0);
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as TableComponentViewModel;

      expect(vm.requestedWidth, const BlockDimension.pixels(400.0));
    });

    test('wires height from TableNode', () {
      final node = _table(height: 200.0);
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as TableComponentViewModel;

      expect(vm.requestedHeight, const BlockDimension.pixels(200.0));
    });

    test('wires columnWidths from TableNode', () {
      final node = _table(columnWidths: [120.0, null]);
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as TableComponentViewModel;

      expect(vm.columnWidths, [120.0, null]);
    });

    test('columnWidths is null when TableNode has no columnWidths', () {
      final node = _table(); // no columnWidths
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as TableComponentViewModel;

      expect(vm.columnWidths, isNull);
    });

    test('cells grid dimensions match rowCount and columnCount', () {
      final node = _table(rowCount: 2, columnCount: 3);
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as TableComponentViewModel;

      expect(vm.cells.length, 2);
      expect(vm.cells[0].length, 3);
      expect(vm.cells[1].length, 3);
    });

    test('defaults for optional layout properties', () {
      final node = _table();
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as TableComponentViewModel;

      expect(vm.requestedWidth, isNull);
      expect(vm.requestedHeight, isNull);
      expect(vm.alignment, BlockAlignment.stretch);
      expect(vm.textWrap, TextWrapMode.none);
    });
  });

  // -------------------------------------------------------------------------
  // TableComponentViewModel equality
  // -------------------------------------------------------------------------

  group('TableComponentViewModel equality', () {
    final cells2x2 = [
      [AttributedText('a'), AttributedText('b')],
      [AttributedText('c'), AttributedText('d')],
    ];

    test('same fields are equal', () {
      final a = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        alignment: BlockAlignment.stretch,
        textWrap: TextWrapMode.none,
      );
      final b = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        alignment: BlockAlignment.stretch,
        textWrap: TextWrapMode.none,
      );
      expect(a, equals(b));
    });

    test('different nodeId are not equal', () {
      final a = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
      );
      final b = TableComponentViewModel(
        nodeId: 't2',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
      );
      expect(a, isNot(equals(b)));
    });

    test('different rowCount are not equal', () {
      final cells3x2 = [
        [AttributedText('a'), AttributedText('b')],
        [AttributedText('c'), AttributedText('d')],
        [AttributedText('e'), AttributedText('f')],
      ];
      final a = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
      );
      final b = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 3,
        columnCount: 2,
        cells: cells3x2,
      );
      expect(a, isNot(equals(b)));
    });

    test('different alignment are not equal', () {
      final a = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        alignment: BlockAlignment.center,
      );
      final b = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        alignment: BlockAlignment.stretch,
      );
      expect(a, isNot(equals(b)));
    });

    test('different textWrap are not equal', () {
      final a = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        textWrap: TextWrapMode.wrap,
      );
      final b = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        textWrap: TextWrapMode.none,
      );
      expect(a, isNot(equals(b)));
    });

    test('different requestedWidth are not equal', () {
      final a = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        requestedWidth: const BlockDimension.pixels(400.0),
      );
      final b = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        requestedWidth: const BlockDimension.pixels(500.0),
      );
      expect(a, isNot(equals(b)));
    });

    test('different requestedHeight are not equal', () {
      final a = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        requestedHeight: const BlockDimension.pixels(100.0),
      );
      final b = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        requestedHeight: const BlockDimension.pixels(200.0),
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode matches for equal view models', () {
      final a = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
        requestedWidth: const BlockDimension.pixels(400.0),
        requestedHeight: const BlockDimension.pixels(100.0),
      );
      final b = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells2x2,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
        requestedWidth: const BlockDimension.pixels(400.0),
        requestedHeight: const BlockDimension.pixels(100.0),
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // -------------------------------------------------------------------------
  // TableComponentBuilder.createComponent
  // -------------------------------------------------------------------------

  group('TableComponentBuilder.createComponent', () {
    const builder = TableComponentBuilder();

    test('returns non-null widget for TableComponentViewModel', () {
      final cells = [
        [AttributedText('a'), AttributedText('b')],
        [AttributedText('c'), AttributedText('d')],
      ];
      final vm = TableComponentViewModel(
        nodeId: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: cells,
      );
      final doc = _doc([]);
      final ctx = _ctx(doc);

      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNotNull);
    });

    test('returns null for non-TableComponentViewModel', () {
      const vm = _OtherViewModel(nodeId: 'other');
      final doc = _doc([]);
      final ctx = _ctx(doc);

      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNull);
    });

    test('returns null for ParagraphComponentViewModel', () {
      final vm = ParagraphComponentViewModel(
        nodeId: 'p1',
        text: AttributedText('Hello'),
        blockType: ParagraphBlockType.paragraph,
        textStyle: const TextStyle(),
      );
      final doc = _doc([]);
      final ctx = _ctx(doc);

      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNull);
    });

    testWidgets('created widget renders in a widget tree without error',
        (WidgetTester tester) async {
      final node = _table(rowCount: 2, columnCount: 2);
      final doc = _doc([node]);
      final vm =
          const TableComponentBuilder().createViewModel(doc, node) as TableComponentViewModel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const TableComponentBuilder().createComponent(vm, _ctx(doc))!,
          ),
        ),
      );
      // Should not throw.
    });
  });

  // -------------------------------------------------------------------------
  // defaultComponentBuilders includes TableComponentBuilder
  // -------------------------------------------------------------------------

  group('defaultComponentBuilders', () {
    test('contains TableComponentBuilder', () {
      final hasTable = defaultComponentBuilders.any((b) => b is TableComponentBuilder);
      expect(hasTable, isTrue);
    });

    test('TableComponentBuilder handles TableNode via resolveViewModel', () {
      final node = _table();
      final doc = _doc([node]);

      final vm = resolveViewModel(defaultComponentBuilders, doc, node);
      expect(vm, isNotNull);
      expect(vm, isA<TableComponentViewModel>());
    });
  });
}
