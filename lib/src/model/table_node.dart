/// Table document node for the editable_document package.
///
/// Provides [TableNode], a block-level node that holds a 2D grid of
/// [AttributedText] cells. Cursor placement within a cell uses
/// [TableCellPosition].
library;

import 'package:flutter/foundation.dart';

import 'attributed_text.dart';
import 'block_alignment.dart';
import 'block_layout.dart';
import 'document_node.dart';
import 'node_position.dart';
import 'text_wrap_mode.dart';

/// A [DocumentNode] representing a block-level table.
///
/// [TableNode] stores a 2D grid of [AttributedText] cells identified by
/// zero-based [rowCount] × [columnCount] indices. Cells are accessed via
/// [cellAt]. The internal storage is made unmodifiable at construction time
/// so that callers cannot mutate node state directly; use [copyWith] to
/// derive a modified copy.
///
/// [columnWidths] is an optional per-column width list. A `null` entry in
/// the list means that column is auto-sized. When [columnWidths] itself is
/// `null`, all columns are auto-sized.
///
/// The [alignment], [textWrap], [width], and [height] fields implement
/// [HasBlockLayout] and follow the same semantics as [ImageNode] and
/// [CodeBlockNode].
///
/// ```dart
/// final table = TableNode(
///   id: generateNodeId(),
///   rowCount: 2,
///   columnCount: 3,
///   cells: [
///     [AttributedText('r0c0'), AttributedText('r0c1'), AttributedText('r0c2')],
///     [AttributedText('r1c0'), AttributedText('r1c1'), AttributedText('r1c2')],
///   ],
///   columnWidths: [120.0, null, 80.0],
///   alignment: BlockAlignment.stretch,
/// );
/// ```
class TableNode extends DocumentNode implements HasBlockLayout {
  /// Creates a [TableNode] from a [rowCount] × [columnCount] grid of [cells].
  ///
  /// [cells] must be a `List` of exactly [rowCount] inner lists, each containing
  /// exactly [columnCount] [AttributedText] values. The list is wrapped in
  /// [List.unmodifiable] layers at construction time so that external mutations
  /// do not affect the node.
  ///
  /// [columnWidths] is optional. When provided, its length must equal
  /// [columnCount]. A `null` entry means the corresponding column is auto-sized.
  ///
  /// [alignment] defaults to [BlockAlignment.stretch].
  /// [textWrap] defaults to [TextWrapMode.none].
  /// [width] and [height] default to `null` (use available / intrinsic size).
  TableNode({
    required super.id,
    required this.rowCount,
    required this.columnCount,
    required List<List<AttributedText>> cells,
    List<double?>? columnWidths,
    this.alignment = BlockAlignment.stretch,
    this.textWrap = TextWrapMode.none,
    this.width,
    this.height,
    super.metadata,
  })  : _cells = List<List<AttributedText>>.unmodifiable(
          cells.map((row) => List<AttributedText>.unmodifiable(row)),
        ),
        columnWidths = columnWidths != null ? List<double?>.unmodifiable(columnWidths) : null;

  /// Number of rows in the table.
  final int rowCount;

  /// Number of columns in the table.
  final int columnCount;

  /// Unmodifiable per-column width hints, or `null` when all columns are
  /// auto-sized.
  ///
  /// When non-null, the list has exactly [columnCount] entries. A `null` entry
  /// within the list means that column is auto-sized.
  final List<double?>? columnWidths;

  /// How the table block is horizontally aligned within the available layout width.
  ///
  /// Defaults to [BlockAlignment.stretch], which causes the table to fill the
  /// entire available width.
  @override
  final BlockAlignment alignment;

  /// How surrounding text interacts with this table.
  ///
  /// Defaults to [TextWrapMode.none], which causes the table to occupy a full
  /// vertical row.
  @override
  final TextWrapMode textWrap;

  /// Preferred display width in logical pixels, or `null` to fill available width.
  @override
  final double? width;

  /// Preferred display height in logical pixels, or `null` to use intrinsic height.
  @override
  final double? height;

  /// Internal unmodifiable storage of the 2D cell grid.
  final List<List<AttributedText>> _cells;

  /// Returns the [AttributedText] at the given zero-based [row] and [col].
  ///
  /// Throws a [RangeError] if [row] is not in `[0, rowCount)` or [col] is not
  /// in `[0, columnCount)`.
  AttributedText cellAt(int row, int col) => _cells[row][col];

  @override
  TableNode copyWith({
    String? id,
    int? rowCount,
    int? columnCount,
    List<List<AttributedText>>? cells,
    Object? columnWidths = _sentinel,
    BlockAlignment? alignment,
    TextWrapMode? textWrap,
    double? width,
    double? height,
    Map<String, dynamic>? metadata,
  }) {
    return TableNode(
      id: id ?? this.id,
      rowCount: rowCount ?? this.rowCount,
      columnCount: columnCount ?? this.columnCount,
      cells: cells ?? _cells,
      columnWidths:
          identical(columnWidths, _sentinel) ? this.columnWidths : columnWidths as List<double?>?,
      alignment: alignment ?? this.alignment,
      textWrap: textWrap ?? this.textWrap,
      width: width ?? this.width,
      height: height ?? this.height,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if (other is! TableNode) return false;
    if (other.id != id ||
        other.rowCount != rowCount ||
        other.columnCount != columnCount ||
        other.alignment != alignment ||
        other.textWrap != textWrap ||
        other.width != width ||
        other.height != height ||
        !mapEquals(other.metadata, metadata)) {
      return false;
    }
    // Compare columnWidths.
    if (!_listEquals(other.columnWidths, columnWidths)) return false;
    // Compare cells row by row.
    for (int r = 0; r < rowCount; r++) {
      for (int c = 0; c < columnCount; c++) {
        if (other._cells[r][c] != _cells[r][c]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    // Hash cells as a flat sequence.
    final cellHashes = <int>[];
    for (final row in _cells) {
      for (final cell in row) {
        cellHashes.add(cell.hashCode);
      }
    }
    return Object.hash(
      id,
      rowCount,
      columnCount,
      Object.hashAll(cellHashes),
      Object.hashAll(columnWidths ?? const <double?>[]),
      alignment,
      textWrap,
      width,
      height,
      Object.hashAll(metadata.entries.map((e) => e)),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('rowCount', rowCount));
    properties.add(IntProperty('columnCount', columnCount));
    properties.add(
      EnumProperty<BlockAlignment>('alignment', alignment, defaultValue: BlockAlignment.stretch),
    );
    properties.add(
      EnumProperty<TextWrapMode>('textWrap', textWrap, defaultValue: TextWrapMode.none),
    );
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DoubleProperty('height', height, defaultValue: null));
    properties.add(
      IterableProperty<double?>('columnWidths', columnWidths, defaultValue: null),
    );
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'TableNode(id: $id, rowCount: $rowCount, columnCount: $columnCount, '
      'alignment: ${alignment.name}, textWrap: $textWrap, '
      'width: $width, height: $height, metadata: $metadata)';
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Sentinel object used by [TableNode.copyWith] to distinguish "not provided"
/// from an explicit `null` for [columnWidths].
const Object _sentinel = Object();

/// Null-safe shallow equality for nullable lists.
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
