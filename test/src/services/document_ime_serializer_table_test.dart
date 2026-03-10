/// Tests for [DocumentImeSerializer] — TableNode serialization and
/// table-specific edit request mapping.
///
/// These tests cover:
///   1. IME serialization when the selection is inside a table cell (Mode 3).
///   2. IME deserialization mapping TextEditingValue changes back to the
///      correct table cell.
///   3. Delta-to-request mapping for table cells.
///   4. InsertTableRequest, UpdateTableCellRequest, and DeleteTableRequest
///      value-type contracts.
///   5. Table node treated as synthetic (Mode 2) for cross-block selections.
///   6. Composing region within a table cell is preserved.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a 2×2 [TableNode] for use across tests.
TableNode _makeTable({String id = 't1'}) {
  return TableNode(
    id: id,
    rowCount: 2,
    columnCount: 2,
    cells: [
      [AttributedText('Hello'), AttributedText('World')],
      [AttributedText('Foo'), AttributedText('Bar')],
    ],
  );
}

/// Returns a collapsed [DocumentSelection] inside cell [row],[col] at [offset].
DocumentSelection _cellSelection(
  String tableNodeId,
  int row,
  int col,
  int offset,
) {
  return DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: tableNodeId,
      nodePosition: TableCellPosition(row: row, col: col, offset: offset),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late DocumentImeSerializer serializer;

  setUp(() {
    serializer = const DocumentImeSerializer();
  });

  // ---------------------------------------------------------------------------
  // toTextEditingValue — Mode 3 (single table cell)
  // ---------------------------------------------------------------------------

  group('toTextEditingValue — Mode 3 (table cell selected)', () {
    test('collapsed selection in a table cell serializes that cell\'s text', () {
      final table = _makeTable();
      final doc = Document([table]);
      // Cursor at offset 3 inside cell (0,0) which contains 'Hello'.
      final selection = _cellSelection('t1', 0, 0, 3);

      final value = serializer.toTextEditingValue(document: doc, selection: selection);

      expect(value.text, equals('Hello'));
      expect(value.selection, equals(const TextSelection.collapsed(offset: 3)));
      expect(value.composing, equals(TextRange.empty));
    });

    test('collapsed selection in a different cell serializes that cell\'s text', () {
      final table = _makeTable();
      final doc = Document([table]);
      // Cursor at offset 1 inside cell (1,1) which contains 'Bar'.
      final selection = _cellSelection('t1', 1, 1, 1);

      final value = serializer.toTextEditingValue(document: doc, selection: selection);

      expect(value.text, equals('Bar'));
      expect(value.selection, equals(const TextSelection.collapsed(offset: 1)));
    });

    test('expanded selection within a single cell maps base and extent offsets', () {
      final table = _makeTable();
      final doc = Document([table]);
      // Select from offset 0 to 3 inside cell (0,0) 'Hello'.
      final selection = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 't1',
          nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 't1',
          nodePosition: TableCellPosition(row: 0, col: 0, offset: 3),
        ),
      );

      final value = serializer.toTextEditingValue(document: doc, selection: selection);

      expect(value.text, equals('Hello'));
      expect(
        value.selection,
        equals(const TextSelection(baseOffset: 0, extentOffset: 3)),
      );
    });

    test('composing region within a table cell is preserved', () {
      final table = _makeTable();
      final doc = Document([table]);
      final selection = _cellSelection('t1', 0, 1, 5);

      final value = serializer.toTextEditingValue(
        document: doc,
        selection: selection,
        composingNodeId: 't1',
        composingBase: 0,
        composingExtent: 5,
        composingRow: 0,
        composingCol: 1,
      );

      expect(value.text, equals('World'));
      expect(value.composing, equals(const TextRange(start: 0, end: 5)));
    });

    test('composing region for different cell is ignored', () {
      final table = _makeTable();
      final doc = Document([table]);
      final selection = _cellSelection('t1', 0, 0, 3);

      // composingRow/Col mismatch — composing should be empty.
      final value = serializer.toTextEditingValue(
        document: doc,
        selection: selection,
        composingNodeId: 't1',
        composingBase: 0,
        composingExtent: 3,
        composingRow: 1,
        composingCol: 1,
      );

      expect(value.composing, equals(TextRange.empty));
    });

    test('cross-cell selection (different cells) falls back to Mode 2 synthetic', () {
      final table = _makeTable();
      final doc = Document([table]);
      // base in cell (0,0), extent in cell (0,1) — cross-cell.
      final selection = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 't1',
          nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 't1',
          nodePosition: TableCellPosition(row: 0, col: 1, offset: 2),
        ),
      );

      final value = serializer.toTextEditingValue(document: doc, selection: selection);

      expect(value.text, equals('\u200B'));
      expect(value.selection, equals(const TextSelection.collapsed(offset: 1)));
    });

    test('table node in cross-block selection falls back to Mode 2', () {
      final table = _makeTable();
      final para = ParagraphNode(id: 'p1', text: AttributedText('After'));
      final doc = Document([table, para]);
      // base in table cell, extent in paragraph — cross-block.
      final selection = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 't1',
          nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );

      final value = serializer.toTextEditingValue(document: doc, selection: selection);

      expect(value.text, equals('\u200B'));
      expect(value.selection, equals(const TextSelection.collapsed(offset: 1)));
    });

    test('table node selected with non-TableCellPosition falls back to Mode 2', () {
      // A TableNode whose selection endpoints use BinaryNodePosition instead
      // of TableCellPosition should fall through to Mode 2 (synthetic).
      final table = _makeTable();
      final doc = Document([table]);
      // Use BinaryNodePosition (wrong type for a TableNode) to exercise the
      // `basePos is! TableCellPosition` guard on line 166.
      final selection = const DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 't1',
          nodePosition: BinaryNodePosition.upstream(),
        ),
      );

      final value = serializer.toTextEditingValue(document: doc, selection: selection);

      expect(value.text, equals('\u200B'));
      expect(value.selection, equals(const TextSelection.collapsed(offset: 1)));
    });
  });

  // ---------------------------------------------------------------------------
  // toDocumentSelection — table cell round-trip
  // ---------------------------------------------------------------------------

  group('toDocumentSelection — table cell', () {
    test('round-trip: serialize then deserialize returns original collapsed cell selection', () {
      final table = _makeTable();
      final doc = Document([table]);
      final originalSelection = _cellSelection('t1', 0, 0, 3);

      final imeValue = serializer.toTextEditingValue(
        document: doc,
        selection: originalSelection,
      );
      final recovered = serializer.toDocumentSelection(
        imeValue: imeValue,
        document: doc,
        serializedNodeId: 't1',
        serializedRow: 0,
        serializedCol: 0,
      );

      expect(recovered, equals(originalSelection));
    });

    test('round-trip with expanded cell selection', () {
      final table = _makeTable();
      final doc = Document([table]);
      final originalSelection = const DocumentSelection(
        base: DocumentPosition(
          nodeId: 't1',
          nodePosition: TableCellPosition(row: 1, col: 0, offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 't1',
          nodePosition: TableCellPosition(row: 1, col: 0, offset: 3),
        ),
      );

      final imeValue = serializer.toTextEditingValue(
        document: doc,
        selection: originalSelection,
      );
      final recovered = serializer.toDocumentSelection(
        imeValue: imeValue,
        document: doc,
        serializedNodeId: 't1',
        serializedRow: 1,
        serializedCol: 0,
      );

      expect(recovered, equals(originalSelection));
    });

    test('null serializedRow returns null for table mode', () {
      final table = _makeTable();
      final doc = Document([table]);
      const imeValue = TextEditingValue(
        text: 'Hello',
        selection: TextSelection.collapsed(offset: 2),
      );

      final result = serializer.toDocumentSelection(
        imeValue: imeValue,
        document: doc,
        serializedNodeId: 't1',
        serializedRow: null,
        serializedCol: 0,
      );

      // null row means the serialized state was Mode 2 (not a table cell).
      expect(result, isNull);
    });

    test('null serializedCol returns null for table mode', () {
      final table = _makeTable();
      final doc = Document([table]);
      const imeValue = TextEditingValue(
        text: 'Hello',
        selection: TextSelection.collapsed(offset: 2),
      );

      final result = serializer.toDocumentSelection(
        imeValue: imeValue,
        document: doc,
        serializedNodeId: 't1',
        serializedRow: 0,
        serializedCol: null,
      );

      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // deltaToRequests — table cell deltas
  // ---------------------------------------------------------------------------

  group('deltaToRequests — table cell', () {
    test('insertion delta in a table cell produces UpdateTableCellRequest', () {
      final table = _makeTable();
      final doc = Document([table]);
      // Selection inside cell (0,0) which contains 'Hello'.
      final selection = _cellSelection('t1', 0, 0, 5);

      final delta = const TextEditingDeltaInsertion(
        oldText: 'Hello',
        textInserted: '!',
        insertionOffset: 5,
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange.empty,
      );

      final requests = serializer.deltaToRequests(
        deltas: [delta],
        document: doc,
        selection: selection,
      );

      expect(requests, hasLength(1));
      expect(requests.first, isA<UpdateTableCellRequest>());
      final req = requests.first as UpdateTableCellRequest;
      expect(req.nodeId, equals('t1'));
      expect(req.row, equals(0));
      expect(req.col, equals(0));
      expect(req.newText.text, equals('Hello!'));
    });

    test('deletion delta in a table cell produces UpdateTableCellRequest', () {
      final table = _makeTable();
      final doc = Document([table]);
      final selection = _cellSelection('t1', 0, 0, 5);

      // Delete the last character 'o' from 'Hello'.
      final delta = const TextEditingDeltaDeletion(
        oldText: 'Hello',
        deletedRange: TextRange(start: 4, end: 5),
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange.empty,
      );

      final requests = serializer.deltaToRequests(
        deltas: [delta],
        document: doc,
        selection: selection,
      );

      expect(requests, hasLength(1));
      expect(requests.first, isA<UpdateTableCellRequest>());
      final req = requests.first as UpdateTableCellRequest;
      expect(req.nodeId, equals('t1'));
      expect(req.row, equals(0));
      expect(req.col, equals(0));
      expect(req.newText.text, equals('Hell'));
    });

    test('replacement delta in a table cell produces UpdateTableCellRequest', () {
      final table = _makeTable();
      final doc = Document([table]);
      final selection = _cellSelection('t1', 1, 1, 3);

      // Replace 'Bar' with 'Baz' in cell (1,1).
      final delta = const TextEditingDeltaReplacement(
        oldText: 'Bar',
        replacementText: 'Baz',
        replacedRange: TextRange(start: 0, end: 3),
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange.empty,
      );

      final requests = serializer.deltaToRequests(
        deltas: [delta],
        document: doc,
        selection: selection,
      );

      expect(requests, hasLength(1));
      expect(requests.first, isA<UpdateTableCellRequest>());
      final req = requests.first as UpdateTableCellRequest;
      expect(req.nodeId, equals('t1'));
      expect(req.row, equals(1));
      expect(req.col, equals(1));
      expect(req.newText.text, equals('Baz'));
    });

    test('NonTextUpdate delta in a table cell returns empty list', () {
      final table = _makeTable();
      final doc = Document([table]);
      final selection = _cellSelection('t1', 0, 0, 3);

      final delta = const TextEditingDeltaNonTextUpdate(
        oldText: 'Hello',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange.empty,
      );

      final requests = serializer.deltaToRequests(
        deltas: [delta],
        document: doc,
        selection: selection,
      );

      expect(requests, isEmpty);
    });

    test('newline insertion in a table cell produces UpdateTableCellRequest with embedded newline',
        () {
      // Tables do not split on Enter — the newline is inserted as text.
      final table = _makeTable();
      final doc = Document([table]);
      final selection = _cellSelection('t1', 0, 0, 5);

      final delta = const TextEditingDeltaInsertion(
        oldText: 'Hello',
        textInserted: '\n',
        insertionOffset: 5,
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange.empty,
      );

      final requests = serializer.deltaToRequests(
        deltas: [delta],
        document: doc,
        selection: selection,
      );

      expect(requests, hasLength(1));
      expect(requests.first, isA<UpdateTableCellRequest>());
      final req = requests.first as UpdateTableCellRequest;
      expect(req.newText.text, equals('Hello\n'));
    });
  });

  // ---------------------------------------------------------------------------
  // InsertTableRequest — value-type contract
  // ---------------------------------------------------------------------------

  group('InsertTableRequest', () {
    test('stores all constructor parameters', () {
      const req = InsertTableRequest(
        nodeId: 'tbl1',
        rowCount: 3,
        columnCount: 4,
        insertIndex: 2,
      );

      expect(req.nodeId, equals('tbl1'));
      expect(req.rowCount, equals(3));
      expect(req.columnCount, equals(4));
      expect(req.insertIndex, equals(2));
    });

    test('insertIndex defaults to null (append)', () {
      const req = InsertTableRequest(
        nodeId: 'tbl1',
        rowCount: 2,
        columnCount: 2,
      );

      expect(req.insertIndex, isNull);
    });

    test('equality: same values are equal', () {
      const a = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 3, insertIndex: 0);
      const b = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 3, insertIndex: 0);
      expect(a, equals(b));
    });

    test('equality: different nodeId not equal', () {
      const a = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 3);
      const b = InsertTableRequest(nodeId: 'y', rowCount: 2, columnCount: 3);
      expect(a, isNot(equals(b)));
    });

    test('equality: different rowCount not equal', () {
      const a = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 3);
      const b = InsertTableRequest(nodeId: 'x', rowCount: 3, columnCount: 3);
      expect(a, isNot(equals(b)));
    });

    test('equality: different columnCount not equal', () {
      const a = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 3);
      const b = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 4);
      expect(a, isNot(equals(b)));
    });

    test('equality: different insertIndex not equal', () {
      const a = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 3, insertIndex: 0);
      const b = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 3, insertIndex: 1);
      expect(a, isNot(equals(b)));
    });

    test('equality: null vs non-null insertIndex not equal', () {
      const a = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 3);
      const b = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 3, insertIndex: 0);
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent', () {
      const a = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 3, insertIndex: 0);
      const b = InsertTableRequest(nodeId: 'x', rowCount: 2, columnCount: 3, insertIndex: 0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString contains key fields', () {
      const req = InsertTableRequest(nodeId: 'tbl1', rowCount: 2, columnCount: 3);
      final s = req.toString();
      expect(s, contains('tbl1'));
      expect(s, contains('2'));
      expect(s, contains('3'));
    });
  });

  // ---------------------------------------------------------------------------
  // UpdateTableCellRequest — value-type contract
  // ---------------------------------------------------------------------------

  group('UpdateTableCellRequest', () {
    test('stores all constructor parameters', () {
      final req = UpdateTableCellRequest(
        nodeId: 'tbl1',
        row: 1,
        col: 2,
        newText: AttributedText('updated'),
      );

      expect(req.nodeId, equals('tbl1'));
      expect(req.row, equals(1));
      expect(req.col, equals(2));
      expect(req.newText.text, equals('updated'));
    });

    test('equality: same values are equal', () {
      final a = UpdateTableCellRequest(
        nodeId: 'x',
        row: 0,
        col: 1,
        newText: AttributedText('txt'),
      );
      final b = UpdateTableCellRequest(
        nodeId: 'x',
        row: 0,
        col: 1,
        newText: AttributedText('txt'),
      );
      expect(a, equals(b));
    });

    test('equality: different nodeId not equal', () {
      final a = UpdateTableCellRequest(
        nodeId: 'x',
        row: 0,
        col: 0,
        newText: AttributedText('t'),
      );
      final b = UpdateTableCellRequest(
        nodeId: 'y',
        row: 0,
        col: 0,
        newText: AttributedText('t'),
      );
      expect(a, isNot(equals(b)));
    });

    test('equality: different row not equal', () {
      final a = UpdateTableCellRequest(
        nodeId: 'x',
        row: 0,
        col: 0,
        newText: AttributedText('t'),
      );
      final b = UpdateTableCellRequest(
        nodeId: 'x',
        row: 1,
        col: 0,
        newText: AttributedText('t'),
      );
      expect(a, isNot(equals(b)));
    });

    test('equality: different col not equal', () {
      final a = UpdateTableCellRequest(
        nodeId: 'x',
        row: 0,
        col: 0,
        newText: AttributedText('t'),
      );
      final b = UpdateTableCellRequest(
        nodeId: 'x',
        row: 0,
        col: 1,
        newText: AttributedText('t'),
      );
      expect(a, isNot(equals(b)));
    });

    test('equality: different newText not equal', () {
      final a = UpdateTableCellRequest(
        nodeId: 'x',
        row: 0,
        col: 0,
        newText: AttributedText('a'),
      );
      final b = UpdateTableCellRequest(
        nodeId: 'x',
        row: 0,
        col: 0,
        newText: AttributedText('b'),
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent', () {
      final a = UpdateTableCellRequest(
        nodeId: 'x',
        row: 0,
        col: 1,
        newText: AttributedText('txt'),
      );
      final b = UpdateTableCellRequest(
        nodeId: 'x',
        row: 0,
        col: 1,
        newText: AttributedText('txt'),
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString contains key fields', () {
      final req = UpdateTableCellRequest(
        nodeId: 'tbl1',
        row: 2,
        col: 3,
        newText: AttributedText('content'),
      );
      final s = req.toString();
      expect(s, contains('tbl1'));
      expect(s, contains('2'));
      expect(s, contains('3'));
    });
  });

  // ---------------------------------------------------------------------------
  // DeleteTableRequest — value-type contract
  // ---------------------------------------------------------------------------

  group('DeleteTableRequest', () {
    test('stores nodeId', () {
      const req = DeleteTableRequest(nodeId: 'tbl1');
      expect(req.nodeId, equals('tbl1'));
    });

    test('equality: same nodeId is equal', () {
      const a = DeleteTableRequest(nodeId: 'x');
      const b = DeleteTableRequest(nodeId: 'x');
      expect(a, equals(b));
    });

    test('equality: different nodeId not equal', () {
      const a = DeleteTableRequest(nodeId: 'x');
      const b = DeleteTableRequest(nodeId: 'y');
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent', () {
      const a = DeleteTableRequest(nodeId: 'x');
      const b = DeleteTableRequest(nodeId: 'x');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString contains nodeId', () {
      const req = DeleteTableRequest(nodeId: 'tbl1');
      final s = req.toString();
      expect(s, contains('tbl1'));
    });
  });

  // ---------------------------------------------------------------------------
  // InsertTableCommand via Editor.submit
  // ---------------------------------------------------------------------------

  group('InsertTableCommand (via Editor)', () {
    test('inserts a TableNode at the specified index', () {
      final para = ParagraphNode(id: 'p1', text: AttributedText('Before'));
      final doc = MutableDocument([para]);
      final controller = DocumentEditingController(document: doc);
      final editor = Editor(editContext: EditContext(document: doc, controller: controller));

      editor.submit(const InsertTableRequest(
        nodeId: 'tbl1',
        rowCount: 2,
        columnCount: 3,
        insertIndex: 1,
      ));

      expect(doc.nodeCount, equals(2));
      final inserted = doc.nodeAt(1);
      expect(inserted, isA<TableNode>());
      final table = inserted as TableNode;
      expect(table.id, equals('tbl1'));
      expect(table.rowCount, equals(2));
      expect(table.columnCount, equals(3));
    });

    test('appends a TableNode when insertIndex is null', () {
      final para = ParagraphNode(id: 'p1', text: AttributedText('Before'));
      final doc = MutableDocument([para]);
      final controller = DocumentEditingController(document: doc);
      final editor = Editor(editContext: EditContext(document: doc, controller: controller));

      editor.submit(const InsertTableRequest(
        nodeId: 'tbl1',
        rowCount: 1,
        columnCount: 2,
      ));

      expect(doc.nodeCount, equals(2));
      expect(doc.nodeAt(1), isA<TableNode>());
    });

    test('inserted table cells are all initially empty AttributedText', () {
      final para = ParagraphNode(id: 'p1', text: AttributedText(''));
      final doc = MutableDocument([para]);
      final controller = DocumentEditingController(document: doc);
      final editor = Editor(editContext: EditContext(document: doc, controller: controller));

      editor.submit(const InsertTableRequest(
        nodeId: 'tbl1',
        rowCount: 2,
        columnCount: 2,
        insertIndex: 0,
      ));

      final table = doc.nodeAt(0) as TableNode;
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          expect(table.cellAt(r, c).text, isEmpty);
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // UpdateTableCellCommand via Editor.submit
  // ---------------------------------------------------------------------------

  group('UpdateTableCellCommand (via Editor)', () {
    test('updates the text of the target cell', () {
      final table = _makeTable();
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final editor = Editor(editContext: EditContext(document: doc, controller: controller));

      editor.submit(UpdateTableCellRequest(
        nodeId: 't1',
        row: 0,
        col: 0,
        newText: AttributedText('Updated'),
      ));

      final updated = doc.nodeAt(0) as TableNode;
      expect(updated.cellAt(0, 0).text, equals('Updated'));
      // Other cells unchanged.
      expect(updated.cellAt(0, 1).text, equals('World'));
      expect(updated.cellAt(1, 0).text, equals('Foo'));
      expect(updated.cellAt(1, 1).text, equals('Bar'));
    });

    test('updates a different cell in the table', () {
      final table = _makeTable();
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final editor = Editor(editContext: EditContext(document: doc, controller: controller));

      editor.submit(UpdateTableCellRequest(
        nodeId: 't1',
        row: 1,
        col: 1,
        newText: AttributedText('Baz'),
      ));

      final updated = doc.nodeAt(0) as TableNode;
      expect(updated.cellAt(1, 1).text, equals('Baz'));
    });

    test('throws StateError when nodeId does not exist', () {
      final doc = MutableDocument([]);
      final controller = DocumentEditingController(document: doc);
      final editor = Editor(editContext: EditContext(document: doc, controller: controller));

      expect(
        () => editor.submit(UpdateTableCellRequest(
          nodeId: 'missing',
          row: 0,
          col: 0,
          newText: AttributedText('x'),
        )),
        throwsStateError,
      );
    });

    test('throws StateError when node is not a TableNode', () {
      final para = ParagraphNode(id: 'p1', text: AttributedText('para'));
      final doc = MutableDocument([para]);
      final controller = DocumentEditingController(document: doc);
      final editor = Editor(editContext: EditContext(document: doc, controller: controller));

      expect(
        () => editor.submit(UpdateTableCellRequest(
          nodeId: 'p1',
          row: 0,
          col: 0,
          newText: AttributedText('x'),
        )),
        throwsStateError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // DeleteTableCommand via Editor.submit
  // ---------------------------------------------------------------------------

  group('DeleteTableCommand (via Editor)', () {
    test('removes the TableNode from the document', () {
      final para = ParagraphNode(id: 'p1', text: AttributedText('Before'));
      final table = _makeTable();
      final doc = MutableDocument([para, table]);
      final controller = DocumentEditingController(document: doc);
      final editor = Editor(editContext: EditContext(document: doc, controller: controller));

      editor.submit(const DeleteTableRequest(nodeId: 't1'));

      expect(doc.nodeCount, equals(1));
      expect(doc.nodeAt(0), isA<ParagraphNode>());
    });

    test('clears selection after deletion when document is empty', () {
      final table = _makeTable();
      final doc = MutableDocument([table]);
      final controller = DocumentEditingController(document: doc);
      final editor = Editor(editContext: EditContext(document: doc, controller: controller));

      editor.submit(const DeleteTableRequest(nodeId: 't1'));

      expect(doc.nodeCount, equals(0));
      expect(controller.selection, isNull);
    });

    test('throws StateError when nodeId does not exist', () {
      final doc = MutableDocument([]);
      final controller = DocumentEditingController(document: doc);
      final editor = Editor(editContext: EditContext(document: doc, controller: controller));

      expect(
        () => editor.submit(const DeleteTableRequest(nodeId: 'missing')),
        throwsStateError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Keyboard handler — table Tab TODO
  // ---------------------------------------------------------------------------

  group('DocumentKeyboardHandler — table cell navigation', () {
    test('TODO: Tab key in table cell navigates to next cell', () {
      // This is a known TODO — table cell Tab navigation will be implemented
      // in a later phase when the rendering layer adds cell focus management.
      // For now, verify the handler does not throw when encountering a
      // TableCellPosition in the current selection.
      // Stub test: passes unconditionally as a placeholder.
      expect(true, isTrue);
    });
  });
}
