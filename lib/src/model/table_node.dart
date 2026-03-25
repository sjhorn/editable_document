/// Table document node for the editable_document package.
///
/// Provides [TableNode], a block-level node that holds a 2D grid of
/// [AttributedText] cells. Cursor placement within a cell uses
/// [TableCellPosition].
library;

import 'dart:ui' show Color, TextAlign;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show ColorProperty;

import 'attributed_text.dart';
import 'block_alignment.dart';
import 'block_border.dart';
import 'block_dimension.dart';
import 'block_layout.dart';
import 'document_node.dart';
import 'node_position.dart';
import 'table_vertical_alignment.dart';
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
/// [rowHeights] is an optional per-row minimum height list. A `null` entry
/// means that row is auto-sized (content determines the height). A specified
/// value is the minimum outer height in logical pixels; content may exceed it.
/// When [rowHeights] itself is `null`, all rows are auto-sized.
///
/// [cellTextAligns] is an optional rowCount × columnCount 2D grid of
/// [TextAlign] values. When `null`, all cells inherit the default text
/// alignment. Each inner list corresponds to one row.
///
/// [cellVerticalAligns] is an optional rowCount × columnCount 2D grid of
/// [TableVerticalAlignment] values. When `null`, all cells use
/// [TableVerticalAlignment.top]. Each inner list corresponds to one row.
///
/// The [alignment], [textWrap], `width`, and `height` fields implement
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
///   rowHeights: [null, 60.0],
///   cellTextAligns: [
///     [TextAlign.left, TextAlign.center, TextAlign.right],
///     [TextAlign.start, TextAlign.start, TextAlign.start],
///   ],
///   cellVerticalAligns: [
///     [TableVerticalAlignment.top, TableVerticalAlignment.top, TableVerticalAlignment.top],
///     [TableVerticalAlignment.middle, TableVerticalAlignment.top, TableVerticalAlignment.top],
///   ],
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
  /// [rowHeights] is optional. When provided, its length must equal [rowCount].
  /// A `null` entry means the corresponding row is auto-sized.
  ///
  /// [cellTextAligns] is optional. When provided, it must be a rowCount ×
  /// columnCount 2D grid of [TextAlign] values. Both the outer list and each
  /// inner list are wrapped in [List.unmodifiable].
  ///
  /// [cellVerticalAligns] is optional. When provided, it must be a rowCount ×
  /// columnCount 2D grid of [TableVerticalAlignment] values. Both the outer
  /// list and each inner list are wrapped in [List.unmodifiable].
  ///
  /// [alignment] defaults to [BlockAlignment.stretch].
  /// [textWrap] defaults to [TextWrapMode.none].
  /// `width` and `height` default to `null` (use available / intrinsic size).
  /// `spaceBefore` and `spaceAfter` default to `null` (use document-level
  /// default spacing).
  /// [border] defaults to `null` (no border drawn).
  TableNode({
    required super.id,
    required this.rowCount,
    required this.columnCount,
    required List<List<AttributedText>> cells,
    List<double?>? columnWidths,
    List<double?>? rowHeights,
    List<List<TextAlign>>? cellTextAligns,
    List<List<TableVerticalAlignment>>? cellVerticalAligns,
    this.alignment = BlockAlignment.stretch,
    this.textWrap = TextWrapMode.none,
    this.width,
    this.height,
    this.spaceBefore,
    this.spaceAfter,
    this.border,
    this.gridBorderWidth = 1.0,
    this.gridBorderColor,
    this.showHorizontalGridLines = true,
    this.showVerticalGridLines = true,
    super.metadata,
  })  : _cells = List<List<AttributedText>>.unmodifiable(
          cells.map((row) => List<AttributedText>.unmodifiable(row)),
        ),
        columnWidths = columnWidths != null ? List<double?>.unmodifiable(columnWidths) : null,
        rowHeights = rowHeights != null ? List<double?>.unmodifiable(rowHeights) : null,
        cellTextAligns = cellTextAligns != null
            ? List<List<TextAlign>>.unmodifiable(
                cellTextAligns.map((row) => List<TextAlign>.unmodifiable(row)),
              )
            : null,
        cellVerticalAligns = cellVerticalAligns != null
            ? List<List<TableVerticalAlignment>>.unmodifiable(
                cellVerticalAligns.map(
                  (row) => List<TableVerticalAlignment>.unmodifiable(row),
                ),
              )
            : null;

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

  /// Unmodifiable per-row minimum height hints, or `null` when all rows are
  /// auto-sized.
  ///
  /// When non-null, the list has exactly [rowCount] entries. A `null` entry
  /// within the list means that row is auto-sized (content determines height).
  /// A specified value is the minimum outer height in logical pixels; cell
  /// content may exceed it.
  final List<double?>? rowHeights;

  /// Unmodifiable rowCount × columnCount 2D grid of horizontal text alignments,
  /// or `null` to use the document default for all cells.
  ///
  /// When non-null, the outer list has exactly [rowCount] entries and each inner
  /// list has exactly [columnCount] entries. Both the outer and inner lists are
  /// unmodifiable.
  final List<List<TextAlign>>? cellTextAligns;

  /// Unmodifiable rowCount × columnCount 2D grid of vertical alignments, or
  /// `null` to use [TableVerticalAlignment.top] for all cells.
  ///
  /// When non-null, the outer list has exactly [rowCount] entries and each inner
  /// list has exactly [columnCount] entries. Both the outer and inner lists are
  /// unmodifiable.
  final List<List<TableVerticalAlignment>>? cellVerticalAligns;

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

  /// Preferred display block dimension for width, or `null` to fill available width.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel width or
  /// [BlockDimension.percent] for a fraction of the document width.
  @override
  final BlockDimension? width;

  /// Preferred display block dimension for height, or `null` to use intrinsic height.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel height or
  /// [BlockDimension.percent] for a fraction of the viewport height.
  @override
  final BlockDimension? height;

  /// Extra space before this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceBefore;

  /// Extra space after this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceAfter;

  /// The outside border drawn around this block, or `null` for no border.
  final BlockBorder? border;

  /// Stroke width of the internal cell grid lines in logical pixels.
  /// Defaults to `1.0`.
  final double gridBorderWidth;

  /// Color of the internal cell grid lines.
  /// When `null`, defaults to grey (`0xFFCCCCCC`) at render time.
  final Color? gridBorderColor;

  /// Whether horizontal grid lines are drawn between rows. Defaults to `true`.
  final bool showHorizontalGridLines;

  /// Whether vertical grid lines are drawn between columns. Defaults to `true`.
  final bool showVerticalGridLines;

  /// Internal unmodifiable storage of the 2D cell grid.
  final List<List<AttributedText>> _cells;

  /// Returns the [AttributedText] at the given zero-based [row] and [col].
  ///
  /// Throws a [RangeError] if [row] is not in `[0, rowCount)` or [col] is not
  /// in `[0, columnCount)`.
  AttributedText cellAt(int row, int col) => _cells[row][col];

  @override
  bool get isDraggable => true;

  @override
  bool get isResizable => alignment != BlockAlignment.stretch;

  @override
  DocumentNode copyWithSize({
    BlockDimension? width,
    BlockDimension? height,
    BlockAlignment? alignment,
  }) =>
      copyWith(
        width: width ?? this.width,
        height: height ?? this.height,
        alignment: alignment ?? this.alignment,
      );

  @override
  TableNode copyWith({
    String? id,
    int? rowCount,
    int? columnCount,
    List<List<AttributedText>>? cells,
    Object? columnWidths = _sentinel,
    Object? rowHeights = _sentinel,
    Object? cellTextAligns = _sentinel,
    Object? cellVerticalAligns = _sentinel,
    BlockAlignment? alignment,
    TextWrapMode? textWrap,
    BlockDimension? width,
    BlockDimension? height,
    double? spaceBefore,
    double? spaceAfter,
    Object? border = _sentinel,
    double? gridBorderWidth,
    Object? gridBorderColor = _sentinel,
    bool? showHorizontalGridLines,
    bool? showVerticalGridLines,
    Map<String, dynamic>? metadata,
  }) {
    return TableNode(
      id: id ?? this.id,
      rowCount: rowCount ?? this.rowCount,
      columnCount: columnCount ?? this.columnCount,
      cells: cells ?? _cells,
      columnWidths:
          identical(columnWidths, _sentinel) ? this.columnWidths : columnWidths as List<double?>?,
      rowHeights: identical(rowHeights, _sentinel) ? this.rowHeights : rowHeights as List<double?>?,
      cellTextAligns: identical(cellTextAligns, _sentinel)
          ? this.cellTextAligns
          : cellTextAligns as List<List<TextAlign>>?,
      cellVerticalAligns: identical(cellVerticalAligns, _sentinel)
          ? this.cellVerticalAligns
          : cellVerticalAligns as List<List<TableVerticalAlignment>>?,
      alignment: alignment ?? this.alignment,
      textWrap: textWrap ?? this.textWrap,
      width: width ?? this.width,
      height: height ?? this.height,
      spaceBefore: spaceBefore ?? this.spaceBefore,
      spaceAfter: spaceAfter ?? this.spaceAfter,
      border: identical(border, _sentinel) ? this.border : border as BlockBorder?,
      gridBorderWidth: gridBorderWidth ?? this.gridBorderWidth,
      gridBorderColor:
          identical(gridBorderColor, _sentinel) ? this.gridBorderColor : gridBorderColor as Color?,
      showHorizontalGridLines: showHorizontalGridLines ?? this.showHorizontalGridLines,
      showVerticalGridLines: showVerticalGridLines ?? this.showVerticalGridLines,
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
        other.spaceBefore != spaceBefore ||
        other.spaceAfter != spaceAfter ||
        other.border != border ||
        other.gridBorderWidth != gridBorderWidth ||
        other.gridBorderColor != gridBorderColor ||
        other.showHorizontalGridLines != showHorizontalGridLines ||
        other.showVerticalGridLines != showVerticalGridLines ||
        !mapEquals(other.metadata, metadata)) {
      return false;
    }
    // Compare columnWidths.
    if (!_listEquals(other.columnWidths, columnWidths)) return false;
    // Compare rowHeights.
    if (!_listEquals(other.rowHeights, rowHeights)) return false;
    // Compare cellTextAligns row by row.
    if ((other.cellTextAligns == null) != (cellTextAligns == null)) return false;
    if (cellTextAligns != null) {
      for (int r = 0; r < rowCount; r++) {
        if (!_listEquals(other.cellTextAligns![r], cellTextAligns![r])) return false;
      }
    }
    // Compare cellVerticalAligns row by row.
    if ((other.cellVerticalAligns == null) != (cellVerticalAligns == null)) return false;
    if (cellVerticalAligns != null) {
      for (int r = 0; r < rowCount; r++) {
        if (!_listEquals(other.cellVerticalAligns![r], cellVerticalAligns![r])) return false;
      }
    }
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
    // Hash cellTextAligns as a flat sequence.
    final textAlignHashes = <int>[];
    if (cellTextAligns != null) {
      for (final row in cellTextAligns!) {
        for (final align in row) {
          textAlignHashes.add(align.hashCode);
        }
      }
    }
    // Hash cellVerticalAligns as a flat sequence.
    final verticalAlignHashes = <int>[];
    if (cellVerticalAligns != null) {
      for (final row in cellVerticalAligns!) {
        for (final align in row) {
          verticalAlignHashes.add(align.hashCode);
        }
      }
    }
    return Object.hash(
      id,
      rowCount,
      columnCount,
      Object.hashAll(cellHashes),
      Object.hashAll(columnWidths ?? const <double?>[]),
      Object.hashAll(rowHeights ?? const <double?>[]),
      Object.hashAll(textAlignHashes),
      Object.hashAll(verticalAlignHashes),
      alignment,
      textWrap,
      width,
      height,
      spaceBefore,
      spaceAfter,
      border,
      gridBorderWidth,
      gridBorderColor,
      showHorizontalGridLines,
      showVerticalGridLines,
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
    properties.add(DiagnosticsProperty<BlockDimension?>('width', width, defaultValue: null));
    properties.add(DiagnosticsProperty<BlockDimension?>('height', height, defaultValue: null));
    properties.add(
      IterableProperty<double?>('columnWidths', columnWidths, defaultValue: null),
    );
    properties.add(
      IterableProperty<double?>('rowHeights', rowHeights, defaultValue: null),
    );
    properties.add(DiagnosticsProperty<List<List<TextAlign>>?>(
      'cellTextAligns',
      cellTextAligns,
      defaultValue: null,
    ));
    properties.add(DiagnosticsProperty<List<List<TableVerticalAlignment>>?>(
      'cellVerticalAligns',
      cellVerticalAligns,
      defaultValue: null,
    ));
    properties.add(DoubleProperty('spaceBefore', spaceBefore, defaultValue: null));
    properties.add(DoubleProperty('spaceAfter', spaceAfter, defaultValue: null));
    properties.add(DiagnosticsProperty<BlockBorder?>('border', border, defaultValue: null));
    properties.add(DoubleProperty('gridBorderWidth', gridBorderWidth, defaultValue: 1.0));
    properties.add(ColorProperty('gridBorderColor', gridBorderColor, defaultValue: null));
    properties.add(
      FlagProperty(
        'showHorizontalGridLines',
        value: showHorizontalGridLines,
        ifTrue: 'showHorizontalGridLines',
        ifFalse: 'hideHorizontalGridLines',
        defaultValue: true,
      ),
    );
    properties.add(
      FlagProperty(
        'showVerticalGridLines',
        value: showVerticalGridLines,
        ifTrue: 'showVerticalGridLines',
        ifFalse: 'hideVerticalGridLines',
        defaultValue: true,
      ),
    );
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'TableNode(id: $id, rowCount: $rowCount, columnCount: $columnCount, '
      'alignment: ${alignment.name}, textWrap: $textWrap, '
      'width: $width, height: $height, '
      'columnWidths: $columnWidths, rowHeights: $rowHeights, '
      'cellTextAligns: $cellTextAligns, cellVerticalAligns: $cellVerticalAligns, '
      'spaceBefore: $spaceBefore, spaceAfter: $spaceAfter, border: $border, metadata: $metadata)';
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Sentinel object used by [TableNode.copyWith] to distinguish "not provided"
/// from an explicit `null` for nullable fields: [TableNode.columnWidths],
/// [TableNode.rowHeights], [TableNode.cellTextAligns],
/// [TableNode.cellVerticalAligns], [TableNode.border], and
/// [TableNode.gridBorderColor].
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
