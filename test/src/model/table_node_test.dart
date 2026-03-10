/// Tests for [TableNode] and [TableCellPosition].
library;

import 'dart:ui' show TextAffinity;

import 'package:editable_document/src/model/attributed_text.dart';
import 'package:editable_document/src/model/block_alignment.dart';
import 'package:editable_document/src/model/block_layout.dart';
import 'package:editable_document/src/model/document_node.dart';
import 'package:editable_document/src/model/node_position.dart';
import 'package:editable_document/src/model/table_node.dart';
import 'package:editable_document/src/model/text_wrap_mode.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a 2-row × 3-column grid of AttributedText cells with known content.
///
/// Row 0: 'r0c0', 'r0c1', 'r0c2'
/// Row 1: 'r1c0', 'r1c1', 'r1c2'
List<List<AttributedText>> _makeGrid2x3() => [
      [AttributedText('r0c0'), AttributedText('r0c1'), AttributedText('r0c2')],
      [AttributedText('r1c0'), AttributedText('r1c1'), AttributedText('r1c2')],
    ];

void main() {
  // ---------------------------------------------------------------------------
  // TableNode — construction
  // ---------------------------------------------------------------------------
  group('TableNode construction', () {
    test('stores rowCount and columnCount', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 2,
        columnCount: 3,
        cells: _makeGrid2x3(),
      );
      expect(node.rowCount, 2);
      expect(node.columnCount, 3);
    });

    test('cellAt returns correct AttributedText for each cell', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 2,
        columnCount: 3,
        cells: _makeGrid2x3(),
      );
      expect(node.cellAt(0, 0).text, 'r0c0');
      expect(node.cellAt(0, 1).text, 'r0c1');
      expect(node.cellAt(0, 2).text, 'r0c2');
      expect(node.cellAt(1, 0).text, 'r1c0');
      expect(node.cellAt(1, 1).text, 'r1c1');
      expect(node.cellAt(1, 2).text, 'r1c2');
    });

    test('1x1 single-cell table works', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('only')]
        ],
      );
      expect(node.rowCount, 1);
      expect(node.columnCount, 1);
      expect(node.cellAt(0, 0).text, 'only');
    });

    test('alignment defaults to BlockAlignment.stretch', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      expect(node.alignment, BlockAlignment.stretch);
    });

    test('textWrap defaults to TextWrapMode.none', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      expect(node.textWrap, TextWrapMode.none);
    });

    test('width defaults to null', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      expect(node.width, isNull);
    });

    test('height defaults to null', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      expect(node.height, isNull);
    });

    test('columnWidths defaults to null (auto)', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      expect(node.columnWidths, isNull);
    });

    test('accepts explicit alignment, textWrap, width, height', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
        width: 640.0,
        height: 300.0,
      );
      expect(node.alignment, BlockAlignment.center);
      expect(node.textWrap, TextWrapMode.wrap);
      expect(node.width, 640.0);
      expect(node.height, 300.0);
    });

    test('accepts columnWidths list', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 3,
        cells: [
          [AttributedText('a'), AttributedText('b'), AttributedText('c')]
        ],
        columnWidths: [100.0, null, 200.0],
      );
      expect(node.columnWidths, isNotNull);
      expect(node.columnWidths![0], 100.0);
      expect(node.columnWidths![1], isNull);
      expect(node.columnWidths![2], 200.0);
    });

    test('accepts metadata', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        metadata: {'border': 'thin'},
      );
      expect(node.metadata['border'], 'thin');
    });

    test('large table — 5x4 stores all cells', () {
      final cells = List.generate(
        5,
        (r) => List.generate(4, (c) => AttributedText('$r,$c')),
      );
      final node = TableNode(
        id: 'tbl-big',
        rowCount: 5,
        columnCount: 4,
        cells: cells,
      );
      for (int r = 0; r < 5; r++) {
        for (int c = 0; c < 4; c++) {
          expect(node.cellAt(r, c).text, '$r,$c');
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // TableNode — cells are unmodifiable
  // ---------------------------------------------------------------------------
  group('TableNode cells immutability', () {
    test('cellAt returns the stored text without allowing row mutation', () {
      final originalCells = _makeGrid2x3();
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 2,
        columnCount: 3,
        cells: originalCells,
      );
      // Mutating the original list should NOT affect the node.
      originalCells[0][0] = AttributedText('mutated');
      expect(node.cellAt(0, 0).text, 'r0c0');
    });
  });

  // ---------------------------------------------------------------------------
  // TableNode — HasBlockLayout
  // ---------------------------------------------------------------------------
  group('TableNode HasBlockLayout', () {
    test('implements HasBlockLayout', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('x')]
        ],
      );
      expect(node, isA<HasBlockLayout>());
    });

    test('HasBlockLayout alignment getter matches field', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('x')]
        ],
        alignment: BlockAlignment.end,
      );
      final HasBlockLayout layout = node;
      expect(layout.alignment, BlockAlignment.end);
    });

    test('HasBlockLayout textWrap getter matches field', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('x')]
        ],
        textWrap: TextWrapMode.wrap,
      );
      final HasBlockLayout layout = node;
      expect(layout.textWrap, TextWrapMode.wrap);
    });

    test('HasBlockLayout width getter matches field', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('x')]
        ],
        width: 500.0,
      );
      final HasBlockLayout layout = node;
      expect(layout.width, 500.0);
    });

    test('HasBlockLayout height getter matches field', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('x')]
        ],
        height: 250.0,
      );
      final HasBlockLayout layout = node;
      expect(layout.height, 250.0);
    });
  });

  // ---------------------------------------------------------------------------
  // TableNode — copyWith
  // ---------------------------------------------------------------------------
  group('TableNode copyWith', () {
    test('copyWith replaces id', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      final copy = node.copyWith(id: 'tbl-2');
      expect(copy.id, 'tbl-2');
    });

    test('copyWith replaces rowCount and columnCount with new cells', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 2,
        columnCount: 3,
        cells: _makeGrid2x3(),
      );
      final newCells = [
        [AttributedText('new')]
      ];
      final copy = node.copyWith(rowCount: 1, columnCount: 1, cells: newCells);
      expect(copy.rowCount, 1);
      expect(copy.columnCount, 1);
      expect(copy.cellAt(0, 0).text, 'new');
    });

    test('copyWith replaces alignment', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        alignment: BlockAlignment.start,
      );
      final copy = node.copyWith(alignment: BlockAlignment.end);
      expect(copy.alignment, BlockAlignment.end);
    });

    test('copyWith replaces textWrap', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        textWrap: TextWrapMode.none,
      );
      final copy = node.copyWith(textWrap: TextWrapMode.wrap);
      expect(copy.textWrap, TextWrapMode.wrap);
    });

    test('copyWith replaces width', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        width: 100.0,
      );
      final copy = node.copyWith(width: 200.0);
      expect(copy.width, 200.0);
    });

    test('copyWith replaces height', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        height: 50.0,
      );
      final copy = node.copyWith(height: 150.0);
      expect(copy.height, 150.0);
    });

    test('copyWith replaces columnWidths', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')]
        ],
        columnWidths: [100.0, 200.0],
      );
      final copy = node.copyWith(columnWidths: [50.0, 150.0]);
      expect(copy.columnWidths, [50.0, 150.0]);
    });

    test('copyWith replaces metadata', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      final copy = node.copyWith(metadata: {'style': 'bordered'});
      expect(copy.metadata['style'], 'bordered');
    });

    test('copyWith preserves id when not specified', () {
      final node = TableNode(
        id: 'keep-me',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      final copy = node.copyWith(width: 100.0);
      expect(copy.id, 'keep-me');
    });

    test('copyWith preserves cells when not specified', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 2,
        columnCount: 3,
        cells: _makeGrid2x3(),
      );
      final copy = node.copyWith(id: 'tbl-2');
      expect(copy.cellAt(1, 2).text, 'r1c2');
    });

    test('copyWith preserves alignment when not specified', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        alignment: BlockAlignment.center,
      );
      final copy = node.copyWith(id: 'tbl-2');
      expect(copy.alignment, BlockAlignment.center);
    });

    test('copyWith preserves columnWidths when not specified', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')]
        ],
        columnWidths: [80.0, null],
      );
      final copy = node.copyWith(id: 'tbl-2');
      expect(copy.columnWidths, [80.0, null]);
    });
  });

  // ---------------------------------------------------------------------------
  // TableNode — equality
  // ---------------------------------------------------------------------------
  group('TableNode equality', () {
    test('equal when all fields match', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('hello')]
        ],
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
        width: 400.0,
        height: 200.0,
      );
      final b = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('hello')]
        ],
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
        width: 400.0,
        height: 200.0,
      );
      expect(a, equals(b));
    });

    test('unequal when id differs', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      final b = TableNode(
        id: 'tbl-2',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when cells differ', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('hello')]
        ],
      );
      final b = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('world')]
        ],
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when rowCount differs', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      final b = TableNode(
        id: 'tbl-1',
        rowCount: 2,
        columnCount: 1,
        cells: [
          [AttributedText('a')],
          [AttributedText('b')]
        ],
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when columnCount differs', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      final b = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 2,
        cells: [
          [AttributedText('a'), AttributedText('b')]
        ],
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when alignment differs', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        alignment: BlockAlignment.start,
      );
      final b = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        alignment: BlockAlignment.end,
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when textWrap differs', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        textWrap: TextWrapMode.none,
      );
      final b = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        textWrap: TextWrapMode.wrap,
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when width differs', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        width: 100.0,
      );
      final b = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        width: 200.0,
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when height differs', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        height: 50.0,
      );
      final b = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        height: 100.0,
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when columnWidths differ', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        columnWidths: [100.0],
      );
      final b = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        columnWidths: [200.0],
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when metadata differs', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        metadata: {'k': 'v1'},
      );
      final b = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
        metadata: {'k': 'v2'},
      );
      expect(a, isNot(equals(b)));
    });

    test('identical instance equals itself', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      expect(node, equals(node));
    });

    test('not equal to a different runtimeType', () {
      final tbl = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      // An object of a different type should never be equal.
      expect(tbl, isNot(equals('tbl-1')));
    });
  });

  // ---------------------------------------------------------------------------
  // TableNode — hashCode
  // ---------------------------------------------------------------------------
  group('TableNode hashCode', () {
    test('equal nodes have equal hash codes', () {
      final a = TableNode(
        id: 'tbl-1',
        rowCount: 2,
        columnCount: 3,
        cells: _makeGrid2x3(),
        alignment: BlockAlignment.center,
      );
      final b = TableNode(
        id: 'tbl-1',
        rowCount: 2,
        columnCount: 3,
        cells: _makeGrid2x3(),
        alignment: BlockAlignment.center,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode is consistent on the same instance', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      expect(node.hashCode, node.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // TableNode — toString
  // ---------------------------------------------------------------------------
  group('TableNode toString', () {
    test('toString includes id', () {
      final node = TableNode(
        id: 'tbl-unique',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      expect(node.toString(), contains('tbl-unique'));
    });

    test('toString includes rowCount', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 3,
        columnCount: 1,
        cells: [
          [AttributedText('a')],
          [AttributedText('b')],
          [AttributedText('c')],
        ],
      );
      expect(node.toString(), contains('3'));
    });

    test('toString includes columnCount', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 4,
        cells: [
          [
            AttributedText('a'),
            AttributedText('b'),
            AttributedText('c'),
            AttributedText('d'),
          ],
        ],
      );
      expect(node.toString(), contains('4'));
    });

    test('toString mentions TableNode type', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      expect(node.toString(), contains('TableNode'));
    });
  });

  // ---------------------------------------------------------------------------
  // TableNode — debugFillProperties
  // ---------------------------------------------------------------------------
  group('TableNode debugFillProperties', () {
    test('is a DocumentNode', () {
      final node = TableNode(
        id: 'tbl-1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('a')]
        ],
      );
      expect(node, isA<DocumentNode>());
    });
  });

  // ---------------------------------------------------------------------------
  // TableCellPosition — construction
  // ---------------------------------------------------------------------------
  group('TableCellPosition construction', () {
    test('stores row, col, offset', () {
      const pos = TableCellPosition(row: 1, col: 2, offset: 5);
      expect(pos.row, 1);
      expect(pos.col, 2);
      expect(pos.offset, 5);
    });

    test('affinity defaults to downstream', () {
      const pos = TableCellPosition(row: 0, col: 0, offset: 0);
      expect(pos.affinity, TextAffinity.downstream);
    });

    test('accepts explicit upstream affinity', () {
      const pos = TableCellPosition(
        row: 0,
        col: 0,
        offset: 3,
        affinity: TextAffinity.upstream,
      );
      expect(pos.affinity, TextAffinity.upstream);
    });

    test('is a NodePosition', () {
      const NodePosition pos = TableCellPosition(row: 0, col: 0, offset: 0);
      expect(pos, isA<NodePosition>());
    });
  });

  // ---------------------------------------------------------------------------
  // TableCellPosition — copyWith
  // ---------------------------------------------------------------------------
  group('TableCellPosition copyWith', () {
    test('copyWith replaces row', () {
      const original = TableCellPosition(row: 1, col: 2, offset: 3);
      final copy = original.copyWith(row: 10);
      expect(copy.row, 10);
      expect(copy.col, 2);
      expect(copy.offset, 3);
    });

    test('copyWith replaces col', () {
      const original = TableCellPosition(row: 1, col: 2, offset: 3);
      final copy = original.copyWith(col: 20);
      expect(copy.row, 1);
      expect(copy.col, 20);
      expect(copy.offset, 3);
    });

    test('copyWith replaces offset', () {
      const original = TableCellPosition(row: 1, col: 2, offset: 3);
      final copy = original.copyWith(offset: 99);
      expect(copy.row, 1);
      expect(copy.col, 2);
      expect(copy.offset, 99);
    });

    test('copyWith replaces affinity', () {
      const original = TableCellPosition(row: 0, col: 0, offset: 0);
      final copy = original.copyWith(affinity: TextAffinity.upstream);
      expect(copy.affinity, TextAffinity.upstream);
    });

    test('copyWith with no args preserves all fields', () {
      const original = TableCellPosition(
        row: 2,
        col: 3,
        offset: 7,
        affinity: TextAffinity.upstream,
      );
      final copy = original.copyWith();
      expect(copy.row, 2);
      expect(copy.col, 3);
      expect(copy.offset, 7);
      expect(copy.affinity, TextAffinity.upstream);
    });
  });

  // ---------------------------------------------------------------------------
  // TableCellPosition — equality
  // ---------------------------------------------------------------------------
  group('TableCellPosition equality', () {
    test('equal when all fields match', () {
      const a = TableCellPosition(row: 1, col: 2, offset: 5, affinity: TextAffinity.upstream);
      const b = TableCellPosition(row: 1, col: 2, offset: 5, affinity: TextAffinity.upstream);
      expect(a, equals(b));
    });

    test('unequal when row differs', () {
      const a = TableCellPosition(row: 1, col: 2, offset: 5);
      const b = TableCellPosition(row: 0, col: 2, offset: 5);
      expect(a, isNot(equals(b)));
    });

    test('unequal when col differs', () {
      const a = TableCellPosition(row: 1, col: 2, offset: 5);
      const b = TableCellPosition(row: 1, col: 3, offset: 5);
      expect(a, isNot(equals(b)));
    });

    test('unequal when offset differs', () {
      const a = TableCellPosition(row: 1, col: 2, offset: 5);
      const b = TableCellPosition(row: 1, col: 2, offset: 6);
      expect(a, isNot(equals(b)));
    });

    test('unequal when affinity differs', () {
      const a = TableCellPosition(row: 0, col: 0, offset: 0, affinity: TextAffinity.downstream);
      const b = TableCellPosition(row: 0, col: 0, offset: 0, affinity: TextAffinity.upstream);
      expect(a, isNot(equals(b)));
    });

    test('identical instance equals itself', () {
      const pos = TableCellPosition(row: 1, col: 1, offset: 4);
      expect(pos, equals(pos));
    });
  });

  // ---------------------------------------------------------------------------
  // TableCellPosition — hashCode
  // ---------------------------------------------------------------------------
  group('TableCellPosition hashCode', () {
    test('equal positions have equal hash codes', () {
      const a = TableCellPosition(row: 1, col: 2, offset: 5, affinity: TextAffinity.upstream);
      const b = TableCellPosition(row: 1, col: 2, offset: 5, affinity: TextAffinity.upstream);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode is consistent on the same instance', () {
      const pos = TableCellPosition(row: 3, col: 4, offset: 10);
      expect(pos.hashCode, pos.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // TableCellPosition — toString
  // ---------------------------------------------------------------------------
  group('TableCellPosition toString', () {
    test('toString contains row', () {
      const pos = TableCellPosition(row: 7, col: 0, offset: 0);
      expect(pos.toString(), contains('7'));
    });

    test('toString contains col', () {
      const pos = TableCellPosition(row: 0, col: 9, offset: 0);
      expect(pos.toString(), contains('9'));
    });

    test('toString contains offset', () {
      const pos = TableCellPosition(row: 0, col: 0, offset: 42);
      expect(pos.toString(), contains('42'));
    });

    test('toString contains affinity', () {
      const pos = TableCellPosition(row: 0, col: 0, offset: 0, affinity: TextAffinity.upstream);
      expect(pos.toString(), contains('upstream'));
    });

    test('toString mentions TableCellPosition type', () {
      const pos = TableCellPosition(row: 0, col: 0, offset: 0);
      expect(pos.toString(), contains('TableCellPosition'));
    });
  });

  // ---------------------------------------------------------------------------
  // NodePosition polymorphism
  // ---------------------------------------------------------------------------
  group('TableCellPosition polymorphism', () {
    test('can be stored in a NodePosition list alongside other position types', () {
      final List<NodePosition> positions = [
        const TableCellPosition(row: 0, col: 0, offset: 0),
        const TextNodePosition(offset: 5),
        const BinaryNodePosition.downstream(),
        const TableCellPosition(row: 1, col: 2, offset: 3, affinity: TextAffinity.upstream),
      ];
      expect(positions, hasLength(4));
      expect(positions[0], isA<TableCellPosition>());
      expect(positions[1], isA<TextNodePosition>());
      expect(positions[2], isA<BinaryNodePosition>());
      expect(positions[3], isA<TableCellPosition>());
    });
  });
}
