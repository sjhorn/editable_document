/// Table block render object for the editable_document rendering layer.
///
/// Provides [RenderTableBlock], a [RenderDocumentBlock] that renders a
/// 2-D grid of [AttributedText] cells using a per-cell [TextPainter].
/// No child [RenderDocumentBlock]s are used; cell layout and painting are
/// performed directly inside this object.
library;

import 'dart:math' show max;
import 'dart:ui' as ui show BoxHeightStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../model/attributed_text.dart';
import '../model/attribution.dart';
import '../model/block_alignment.dart';
import '../model/block_border.dart';
import '../model/block_dimension.dart';
import '../model/document_selection.dart';
import '../model/node_position.dart';
import '../model/table_vertical_alignment.dart';
import '../model/text_wrap_mode.dart';
import 'block_layout_mixin.dart';
import 'render_document_block.dart';

// ---------------------------------------------------------------------------
// Internal cell layout record
// ---------------------------------------------------------------------------

/// Computed layout information for a single table cell.
///
/// Created during [RenderTableBlock.performLayout] and consumed by
/// [RenderTableBlock.paint] and the geometry-query methods.
class _CellLayout {
  /// Creates a [_CellLayout] from the given painter and cell origin.
  _CellLayout({
    required this.painter,
    required this.cellRect,
    required this.textOffset,
  });

  /// The [TextPainter] that has already been laid out for this cell.
  final TextPainter painter;

  /// The bounding rectangle of the cell (including padding) in table-local
  /// coordinates.
  final Rect cellRect;

  /// The origin offset at which [painter] should be painted, in table-local
  /// coordinates.  This is [cellRect.topLeft] shifted inward by the cell
  /// padding.
  final Offset textOffset;

  /// Releases [painter] resources.
  void dispose() => painter.dispose();
}

// ---------------------------------------------------------------------------
// RenderTableBlock
// ---------------------------------------------------------------------------

/// A [RenderDocumentBlock] that renders a [TableNode] as a bordered grid of
/// cells, each containing [AttributedText] laid out via [TextPainter].
///
/// ## Cell layout algorithm
///
/// 1. Column widths are computed from [columnWidths]:
///    - Fixed-width columns take their specified pixel width.
///    - Auto columns (`null` entries, or when [columnWidths] is `null`)
///      share the remaining available width equally.
///    - Border strokes and padding are subtracted before distributing auto
///      widths.
/// 2. For each cell a [TextPainter] is created and laid out at the column
///    width minus `2 * cellPadding`.
/// 3. Row height equals the tallest cell in that row plus `2 * cellPadding`.
/// 4. Total block height = sum of row heights + `(rowCount + 1) * borderWidth`.
///
/// ## Hit-testing
///
/// [getPositionAtOffset] finds the cell that contains the given offset and
/// delegates to that cell's [TextPainter.getPositionForOffset] to produce a
/// [TableCellPosition].
///
/// ## Selection
///
/// [getEndpointsForSelection] handles selections that span multiple cells by
/// returning the full text boxes for cells between [base] and [extent].
///
/// ## Ownership
///
/// All [TextPainter] instances created during layout are owned by this render
/// object and disposed in [dispose] and whenever [performLayout] discards the
/// old cell layout.
class RenderTableBlock extends RenderDocumentBlock with BlockLayoutMixin {
  /// Creates a [RenderTableBlock].
  ///
  /// `nodeId` must match the corresponding [DocumentNode.id].
  /// [rowCount] and [columnCount] define the grid dimensions.
  /// [cells] is a [rowCount] × [columnCount] grid of [AttributedText] values.
  /// [textStyle] is the base [TextStyle] applied before attributions.
  /// [columnWidths] optionally specifies per-column widths in logical pixels;
  ///   `null` entries mean that column is auto-sized.  When the list itself is
  ///   `null`, all columns are auto-sized.
  /// [rowHeights] optionally specifies per-row minimum heights in logical
  ///   pixels; `null` entries mean that row is auto-sized.  When the list
  ///   itself is `null`, all rows are auto-sized.
  /// [cellPadding] is the horizontal and vertical padding inside each cell.
  /// [borderWidth] is the stroke width of the grid lines.
  /// [borderColor] is the color of the grid lines.
  /// [selectionColor] is the background fill drawn behind selected text.
  /// [textDirection] controls the reading direction of all cells.
  /// [blockAlignment] and [textWrap] follow the same semantics as other block
  ///   types via [BlockLayoutMixin].
  /// [cellTextAligns] optionally specifies per-cell [TextAlign] as a 2-D grid
  ///   (rowCount × columnCount); out-of-bounds entries default to
  ///   [TextAlign.start].
  /// [cellVerticalAligns] optionally specifies per-cell
  ///   [TableVerticalAlignment] as a 2-D grid (rowCount × columnCount);
  ///   out-of-bounds entries default to [TableVerticalAlignment.top].
  RenderTableBlock({
    required String nodeId,
    required int rowCount,
    required int columnCount,
    required List<List<AttributedText>> cells,
    required TextStyle textStyle,
    List<double?>? columnWidths,
    List<double?>? rowHeights,
    double cellPadding = 8.0,
    double borderWidth = 1.0,
    Color borderColor = const Color(0xFFCCCCCC),
    BlockBorderStyle gridBorderStyle = BlockBorderStyle.solid,
    Color selectionColor = const Color(0x663399FF),
    TextDirection textDirection = TextDirection.ltr,
    BlockAlignment blockAlignment = BlockAlignment.stretch,
    BlockDimension? widthDimension,
    BlockDimension? heightDimension,
    double? requestedWidth,
    double? requestedHeight,
    TextWrapMode textWrap = TextWrapMode.none,
    List<List<TextAlign>>? cellTextAligns,
    List<List<TableVerticalAlignment>>? cellVerticalAligns,
  })  : _nodeId = nodeId,
        _rowCount = rowCount,
        _columnCount = columnCount,
        _cells = cells,
        _textStyle = textStyle,
        _columnWidths = columnWidths,
        _rowHeights = rowHeights,
        _cellPadding = cellPadding,
        _borderWidth = borderWidth,
        _borderColor = borderColor,
        _gridBorderStyle = gridBorderStyle,
        _selectionColor = selectionColor,
        _textDirection = textDirection,
        _cellTextAligns = cellTextAligns,
        _cellVerticalAligns = cellVerticalAligns {
    initBlockLayout(
      blockAlignment: blockAlignment,
      widthDimension:
          widthDimension ?? (requestedWidth != null ? BlockDimension.pixels(requestedWidth) : null),
      heightDimension: heightDimension ??
          (requestedHeight != null ? BlockDimension.pixels(requestedHeight) : null),
      textWrap: textWrap,
    );
  }

  // ---------------------------------------------------------------------------
  // Private state
  // ---------------------------------------------------------------------------

  String _nodeId;
  int _rowCount;
  int _columnCount;
  List<List<AttributedText>> _cells;
  TextStyle _textStyle;
  List<double?>? _columnWidths;
  List<double?>? _rowHeights;
  double _cellPadding;
  double _borderWidth;
  Color _borderColor;
  BlockBorderStyle _gridBorderStyle;
  Color _selectionColor;
  TextDirection _textDirection;
  List<List<TextAlign>>? _cellTextAligns;
  List<List<TableVerticalAlignment>>? _cellVerticalAligns;
  DocumentSelection? _nodeSelection;
  double? _spaceBefore;
  double? _spaceAfter;
  BlockBorder? _border;

  /// Cache of per-cell layout results; rebuilt by [performLayout].
  List<List<_CellLayout>>? _cellLayouts;

  /// Cached column widths (after auto distribution); populated by
  /// [performLayout].
  List<double> _computedColumnWidths = const [];

  /// Cached row heights; populated by [performLayout].
  List<double> _computedRowHeights = const [];

  /// Cached column left positions (left edge of each cell area); populated by
  /// [performLayout].
  List<double> _colLefts = const [];

  /// Cached row top positions (top edge of each cell area); populated by
  /// [performLayout].
  List<double> _rowTops = const [];

  // ---------------------------------------------------------------------------
  // RenderDocumentBlock — nodeId
  // ---------------------------------------------------------------------------

  @override
  String get nodeId => _nodeId;

  @override
  set nodeId(String value) {
    if (_nodeId == value) return;
    _nodeId = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // RenderDocumentBlock — nodeSelection
  // ---------------------------------------------------------------------------

  @override
  DocumentSelection? get nodeSelection => _nodeSelection;

  @override
  set nodeSelection(DocumentSelection? value) {
    if (_nodeSelection == value) return;
    _nodeSelection = value;
    markNeedsPaint();
  }

  /// Extra space before this block in logical pixels, or `null` for default.
  ///
  /// When non-null, [RenderDocumentLayout] uses this value instead of
  /// [RenderDocumentLayout.blockSpacing] for the gap above this block.
  @override
  // ignore: diagnostic_describe_all_properties
  double? get spaceBefore => _spaceBefore;

  /// Sets `spaceBefore` and notifies the parent layout when the value changes.
  set spaceBefore(double? value) {
    if (_spaceBefore == value) return;
    _spaceBefore = value;
    if (parent is RenderObject) (parent!).markNeedsLayout();
  }

  /// Extra space after this block in logical pixels, or `null` for default.
  ///
  /// When non-null, [RenderDocumentLayout] uses this value instead of
  /// [RenderDocumentLayout.blockSpacing] for the gap below this block.
  @override
  // ignore: diagnostic_describe_all_properties
  double? get spaceAfter => _spaceAfter;

  /// Sets `spaceAfter` and notifies the parent layout when the value changes.
  set spaceAfter(double? value) {
    if (_spaceAfter == value) return;
    _spaceAfter = value;
    if (parent is RenderObject) (parent!).markNeedsLayout();
  }

  /// The outside border drawn around this block, or `null` for no border.
  ///
  /// When non-null, [RenderDocumentLayout] draws a border around this block
  /// using the specified style, width, and color.
  @override
  // ignore: diagnostic_describe_all_properties
  BlockBorder? get border => _border;

  /// Sets [border] and triggers a repaint when the value changes.
  set border(BlockBorder? value) {
    if (_border == value) return;
    _border = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // Public properties
  // ---------------------------------------------------------------------------

  /// Number of rows in the table.
  // ignore: diagnostic_describe_all_properties
  int get rowCount => _rowCount;

  /// Sets the row count and schedules a layout pass.
  set rowCount(int value) {
    if (_rowCount == value) return;
    _rowCount = value;
    markNeedsLayout();
  }

  /// Number of columns in the table.
  // ignore: diagnostic_describe_all_properties
  int get columnCount => _columnCount;

  /// Sets the column count and schedules a layout pass.
  set columnCount(int value) {
    if (_columnCount == value) return;
    _columnCount = value;
    markNeedsLayout();
  }

  /// The 2-D grid of [AttributedText] cells.
  // ignore: diagnostic_describe_all_properties
  List<List<AttributedText>> get cells => _cells;

  /// Sets the cells and schedules a layout pass.
  set cells(List<List<AttributedText>> value) {
    _cells = value;
    markNeedsLayout();
  }

  /// The base [TextStyle] applied to all cell text before attributions.
  // ignore: diagnostic_describe_all_properties
  TextStyle get textStyle => _textStyle;

  /// Sets the base text style and schedules a layout pass.
  set textStyle(TextStyle value) {
    if (_textStyle == value) return;
    _textStyle = value;
    markNeedsLayout();
  }

  /// Per-column width hints, or `null` when all columns are auto-sized.
  // ignore: diagnostic_describe_all_properties
  List<double?>? get columnWidths => _columnWidths;

  /// Sets the column width hints and schedules a layout pass.
  set columnWidths(List<double?>? value) {
    _columnWidths = value;
    markNeedsLayout();
  }

  /// Per-row minimum height hints, or `null` when all rows are auto-sized.
  ///
  /// When non-null, the list has exactly [rowCount] entries. A `null` entry
  /// means the corresponding row is auto-sized. A specified value is the
  /// minimum outer height in logical pixels; cell content may exceed it.
  // ignore: diagnostic_describe_all_properties
  List<double?>? get rowHeights => _rowHeights;

  /// Sets the row height hints and schedules a layout pass.
  set rowHeights(List<double?>? value) {
    _rowHeights = value;
    markNeedsLayout();
  }

  /// Horizontal and vertical padding applied inside each cell.
  // ignore: diagnostic_describe_all_properties
  double get cellPadding => _cellPadding;

  /// Sets the cell padding and schedules a layout pass.
  set cellPadding(double value) {
    if (_cellPadding == value) return;
    _cellPadding = value;
    markNeedsLayout();
  }

  /// Stroke width of the grid lines.
  // ignore: diagnostic_describe_all_properties
  double get borderWidth => _borderWidth;

  /// Sets the border width and schedules a layout pass.
  set borderWidth(double value) {
    if (_borderWidth == value) return;
    _borderWidth = value;
    markNeedsLayout();
  }

  /// Color of the grid lines.
  // ignore: diagnostic_describe_all_properties
  Color get borderColor => _borderColor;

  /// Sets the border color and schedules a repaint.
  set borderColor(Color value) {
    if (_borderColor == value) return;
    _borderColor = value;
    markNeedsPaint();
  }

  /// The visual style of the internal grid lines.
  ///
  /// Set to [BlockBorderStyle.none] to hide all internal grid lines.
  // ignore: diagnostic_describe_all_properties
  BlockBorderStyle get gridBorderStyle => _gridBorderStyle;

  /// Sets the grid border style and schedules a repaint.
  set gridBorderStyle(BlockBorderStyle value) {
    if (_gridBorderStyle == value) return;
    _gridBorderStyle = value;
    markNeedsPaint();
  }

  /// Background fill color for selected text ranges.
  // ignore: diagnostic_describe_all_properties
  Color get selectionColor => _selectionColor;

  /// Sets the selection color and schedules a repaint.
  set selectionColor(Color value) {
    if (_selectionColor == value) return;
    _selectionColor = value;
    markNeedsPaint();
  }

  /// Reading direction for all cell text.
  // ignore: diagnostic_describe_all_properties
  TextDirection get textDirection => _textDirection;

  /// Sets the text direction and schedules a layout pass.
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// Per-cell [TextAlign] overrides as a 2-D grid (rowCount × columnCount),
  /// or `null` when all cells use the default [TextAlign.start].
  // ignore: diagnostic_describe_all_properties
  List<List<TextAlign>>? get cellTextAligns => _cellTextAligns;

  /// Sets the per-cell text alignments and schedules a layout pass.
  set cellTextAligns(List<List<TextAlign>>? value) {
    if (_cellTextAligns == value) return;
    _cellTextAligns = value;
    markNeedsLayout();
  }

  /// Per-cell [TableVerticalAlignment] overrides as a 2-D grid
  /// (rowCount × columnCount), or `null` when all cells use the default
  /// [TableVerticalAlignment.top].
  // ignore: diagnostic_describe_all_properties
  List<List<TableVerticalAlignment>>? get cellVerticalAligns => _cellVerticalAligns;

  /// Sets the per-cell vertical alignments and schedules a layout pass.
  set cellVerticalAligns(List<List<TableVerticalAlignment>>? value) {
    if (_cellVerticalAligns == value) return;
    _cellVerticalAligns = value;
    markNeedsLayout();
  }

  // ---------------------------------------------------------------------------
  // Computed layout results — exposed for tests
  // ---------------------------------------------------------------------------

  /// The computed column widths (in logical pixels) after the most recent
  /// [performLayout] call.
  ///
  /// Each entry corresponds to the content width of the column (the portion
  /// available to text, i.e. after subtracting [cellPadding] from each side).
  /// Tests use this to verify column distribution.
  ///
  /// Must only be called after layout.
  List<double> get computedColumnWidths => List.unmodifiable(_computedColumnWidths);

  /// The computed row heights (in logical pixels) after the most recent
  /// [performLayout] call.
  ///
  /// Each entry is the full row height including the [cellPadding] on both
  /// sides but excluding border strokes.  Tests use this to verify row sizing.
  ///
  /// Must only be called after layout.
  List<double> get computedRowHeights => List.unmodifiable(_computedRowHeights);

  /// X positions of the left edge of each column cell area (after border),
  /// plus a trailing value for the right edge of the last column.
  ///
  /// Length is `columnCount + 1`. Index 0 is the left edge of the first
  /// column cell area, index [columnCount] is the right edge of the last
  /// column cell area. These are in table-local coordinates.
  ///
  /// Returns an empty list before the first layout pass.
  // ignore: diagnostic_describe_all_properties
  List<double> get columnBoundaryXPositions {
    if (_colLefts.isEmpty) return const [];
    // _colLefts has columnCount entries (left edge of each cell area).
    // Add the right edge of the last column.
    final result = List<double>.of(_colLefts);
    if (_computedColumnWidths.isNotEmpty) {
      result.add(_colLefts.last + _computedColumnWidths.last + 2.0 * _cellPadding);
    }
    return result;
  }

  /// Y positions of the top edge of each row cell area (after border),
  /// plus a trailing value for the bottom edge of the last row.
  ///
  /// Length is `rowCount + 1`. Index 0 is the top edge of the first row
  /// cell area, index [rowCount] is the bottom edge of the last row cell
  /// area. These are in table-local coordinates.
  ///
  /// Returns an empty list before the first layout pass.
  // ignore: diagnostic_describe_all_properties
  List<double> get rowBoundaryYPositions {
    if (_rowTops.isEmpty) return const [];
    final result = List<double>.of(_rowTops);
    if (_computedRowHeights.isNotEmpty) {
      result.add(_rowTops.last + _computedRowHeights.last);
    }
    return result;
  }

  /// Computed outer column widths (content + 2×cellPadding) after layout.
  ///
  /// Length equals [columnCount]. Returns an empty list before the first
  /// layout pass.
  // ignore: diagnostic_describe_all_properties
  List<double> get computedOuterColumnWidths {
    if (_computedColumnWidths.isEmpty) return const [];
    return _computedColumnWidths.map((w) => w + 2.0 * _cellPadding).toList();
  }

  // ---------------------------------------------------------------------------
  // Layout helpers
  // ---------------------------------------------------------------------------

  /// Distributes [totalWidth] across [_columnCount] columns respecting any
  /// fixed widths in [_columnWidths].
  ///
  /// Returns a list of **content** widths (i.e. cell inner width available to
  /// the [TextPainter], which is the column width minus `2 * cellPadding`).
  List<double> _computeColumnContentWidths(double totalWidth) {
    // totalWidth is the full table width.  Border strokes occupy
    // (columnCount + 1) * borderWidth horizontal pixels.
    final totalBorderH = (_columnCount + 1) * _borderWidth;
    final availableForColumns = (totalWidth - totalBorderH).clamp(0.0, double.infinity);

    // Compute outer widths (column including padding, excluding border strokes).
    final outerWidths = List<double>.filled(_columnCount, 0.0);
    double fixedTotal = 0.0;
    int autoCount = 0;

    for (int c = 0; c < _columnCount; c++) {
      final hint = _columnWidths != null && c < _columnWidths!.length ? _columnWidths![c] : null;
      if (hint != null) {
        outerWidths[c] = hint;
        fixedTotal += hint;
      } else {
        autoCount++;
      }
    }

    final remainingForAuto = (availableForColumns - fixedTotal).clamp(0.0, double.infinity);
    final autoWidth = autoCount > 0 ? remainingForAuto / autoCount : 0.0;

    for (int c = 0; c < _columnCount; c++) {
      final hint = _columnWidths != null && c < _columnWidths!.length ? _columnWidths![c] : null;
      if (hint == null) {
        outerWidths[c] = autoWidth;
      }
    }

    // Convert outer widths to content widths.
    return outerWidths.map((w) => (w - 2.0 * _cellPadding).clamp(0.0, double.infinity)).toList();
  }

  /// Builds a [TextSpan] for the [AttributedText] at [cells[row][col]].
  TextSpan _buildTextSpanForCell(int row, int col) {
    final attributed = _cells[row][col];
    final rawText = attributed.text;

    if (rawText.isEmpty) {
      return TextSpan(text: '', style: _textStyle);
    }

    final spans = attributed.getAttributionSpansInRange(0, rawText.length - 1).toList();
    if (spans.isEmpty) {
      return TextSpan(text: rawText, style: _textStyle);
    }

    final boundaries = <int>{0, rawText.length};
    for (final span in spans) {
      boundaries.add(span.start);
      boundaries.add(span.end + 1);
    }
    final sortedBoundaries = boundaries.toList()..sort();

    final children = <InlineSpan>[];
    for (var i = 0; i < sortedBoundaries.length - 1; i++) {
      final start = sortedBoundaries[i];
      final end = sortedBoundaries[i + 1];
      if (start >= rawText.length) break;

      final activeAttributions = attributed.getAttributionsAt(start);
      final style = _buildStyleForAttributions(activeAttributions);
      children.add(TextSpan(text: rawText.substring(start, end), style: style));
    }

    return TextSpan(style: _textStyle, children: children);
  }

  /// Converts a set of [Attribution]s into a merged [TextStyle].
  TextStyle _buildStyleForAttributions(Set<Attribution> attributions) {
    var style = const TextStyle();
    final decorations = <TextDecoration>[];

    for (final attribution in attributions) {
      if (attribution == NamedAttribution.bold) {
        style = style.copyWith(fontWeight: FontWeight.bold);
      } else if (attribution == NamedAttribution.italics) {
        style = style.copyWith(fontStyle: FontStyle.italic);
      } else if (attribution == NamedAttribution.underline) {
        decorations.add(TextDecoration.underline);
      } else if (attribution == NamedAttribution.strikethrough) {
        decorations.add(TextDecoration.lineThrough);
      } else if (attribution == NamedAttribution.code) {
        style = style.copyWith(fontFamily: 'monospace');
      } else if (attribution is FontFamilyAttribution) {
        style = style.copyWith(fontFamily: attribution.fontFamily);
      } else if (attribution is FontSizeAttribution) {
        style = style.copyWith(fontSize: attribution.fontSize);
      } else if (attribution is TextColorAttribution) {
        style = style.copyWith(color: Color(attribution.colorValue));
      } else if (attribution is BackgroundColorAttribution) {
        style = style.copyWith(backgroundColor: Color(attribution.colorValue));
      }
    }

    if (decorations.isNotEmpty) {
      style = style.copyWith(decoration: TextDecoration.combine(decorations));
    }

    return style;
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    // Dispose old cell painters before rebuilding.
    _disposeCellLayouts();

    final tableWidth = (requestedWidth ?? constraints.maxWidth).clamp(
      constraints.minWidth,
      constraints.maxWidth,
    );

    final contentWidths = _computeColumnContentWidths(tableWidth);
    _computedColumnWidths = contentWidths;

    // Outer column widths (used to compute x-positions of cells).
    final outerWidths = contentWidths.map((w) => w + 2.0 * _cellPadding).toList();

    // --- Phase 1: layout all TextPainters and compute row heights ---
    final rowHeights = List<double>.filled(_rowCount, 0.0);
    final painters = List.generate(
      _rowCount,
      (r) => List<TextPainter>.filled(_columnCount, TextPainter(), growable: false),
    );

    for (int r = 0; r < _rowCount; r++) {
      for (int c = 0; c < _columnCount; c++) {
        final painter = TextPainter(
          textDirection: _textDirection,
          textAlign: _cellTextAligns != null &&
                  r < _cellTextAligns!.length &&
                  c < _cellTextAligns![r].length
              ? _cellTextAligns![r][c]
              : TextAlign.start,
        );
        // Clear first to force TextPainter to accept the new span even if
        // it is structurally equal (TextSpan.== ignores children changes).
        painter.text = null;
        painter.text = _buildTextSpanForCell(r, c);
        final maxW = contentWidths[c].clamp(0.0, double.infinity);
        painter.layout(minWidth: maxW, maxWidth: maxW);
        painters[r][c] = painter;

        final cellH = painter.height + 2.0 * _cellPadding;
        rowHeights[r] = max(rowHeights[r], cellH);
      }
    }

    // Apply rowHeights hints as minimums.
    if (_rowHeights != null) {
      for (int r = 0; r < _rowCount; r++) {
        if (r < _rowHeights!.length && _rowHeights![r] != null) {
          rowHeights[r] = max(rowHeights[r], _rowHeights![r]!);
        }
      }
    }

    _computedRowHeights = rowHeights;

    // --- Phase 2: compute cell origin offsets and build _CellLayout grid ---
    final cellLayouts = List.generate(_rowCount, (_) => <_CellLayout>[]);

    // Compute cumulative y positions for rows.
    double y = _borderWidth;
    _rowTops = <double>[];
    for (int r = 0; r < _rowCount; r++) {
      _rowTops.add(y);
      y += rowHeights[r] + _borderWidth;
    }

    // Compute cumulative x positions for columns.
    double x = _borderWidth;
    _colLefts = <double>[];
    for (int c = 0; c < _columnCount; c++) {
      _colLefts.add(x);
      x += outerWidths[c] + _borderWidth;
    }

    for (int r = 0; r < _rowCount; r++) {
      for (int c = 0; c < _columnCount; c++) {
        final vertAlign = _cellVerticalAligns != null &&
                r < _cellVerticalAligns!.length &&
                c < _cellVerticalAligns![r].length
            ? _cellVerticalAligns![r][c]
            : TableVerticalAlignment.top;

        final cellRect = Rect.fromLTWH(
          _colLefts[c],
          _rowTops[r],
          outerWidths[c],
          rowHeights[r],
        );

        final textHeight = painters[r][c].height;
        final availableHeight = rowHeights[r] - 2.0 * _cellPadding;
        final double vOffset;
        switch (vertAlign) {
          case TableVerticalAlignment.top:
            vOffset = 0.0;
          case TableVerticalAlignment.middle:
            vOffset = (availableHeight - textHeight) / 2.0;
          case TableVerticalAlignment.bottom:
            vOffset = availableHeight - textHeight;
        }

        final textOffset = Offset(
          _colLefts[c] + _cellPadding,
          _rowTops[r] + _cellPadding + vOffset.clamp(0.0, double.infinity),
        );
        cellLayouts[r].add(_CellLayout(
          painter: painters[r][c],
          cellRect: cellRect,
          textOffset: textOffset,
        ));
      }
    }

    _cellLayouts = cellLayouts;

    // Total height: sum of row heights + borders.
    final intrinsicTableHeight =
        rowHeights.fold(0.0, (sum, h) => sum + h) + (_rowCount + 1) * _borderWidth;
    // Min-height: requestedHeight is a lower bound on the final table height.
    final totalHeight = requestedHeight != null
        ? max(requestedHeight!, intrinsicTableHeight)
        : intrinsicTableHeight;

    size = Size(tableWidth, totalHeight);
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _disposeCellLayouts();
    super.dispose();
  }

  void _disposeCellLayouts() {
    final layouts = _cellLayouts;
    if (layouts == null) return;
    for (final row in layouts) {
      for (final cell in row) {
        cell.dispose();
      }
    }
    _cellLayouts = null;
  }

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final layouts = _cellLayouts;
    if (layouts == null) return;

    // --- Paint selection highlights (behind text) ---
    final sel = _nodeSelection;
    if (sel != null) {
      _paintSelectionHighlights(context.canvas, offset, layouts, sel);
    }

    // --- Paint cell text ---
    for (int r = 0; r < _rowCount; r++) {
      for (int c = 0; c < _columnCount; c++) {
        final cell = layouts[r][c];
        cell.painter.paint(context.canvas, offset + cell.textOffset);
      }
    }

    // --- Paint internal grid lines only (outer border is drawn by BlockBorder) ---
    if (_borderWidth > 0 && _gridBorderStyle != BlockBorderStyle.none) {
      final gridPaint = Paint()
        ..color = _borderColor
        ..strokeWidth = _borderWidth
        ..style = PaintingStyle.stroke;

      // Horizontal lines between rows (skip top of row 0 and bottom of last row).
      for (var r = 1; r < _rowCount; r++) {
        final y = layouts[r][0].cellRect.top;
        context.canvas.drawLine(
          Offset(layouts[r][0].cellRect.left, y) + offset,
          Offset(layouts[r][_columnCount - 1].cellRect.right, y) + offset,
          gridPaint,
        );
      }

      // Vertical lines between columns (skip left of col 0 and right of last col).
      for (var c = 1; c < _columnCount; c++) {
        final x = layouts[0][c].cellRect.left;
        context.canvas.drawLine(
          Offset(x, layouts[0][0].cellRect.top) + offset,
          Offset(x, layouts[_rowCount - 1][0].cellRect.bottom) + offset,
          gridPaint,
        );
      }
    }
  }

  void _paintSelectionHighlights(
    Canvas canvas,
    Offset offset,
    List<List<_CellLayout>> layouts,
    DocumentSelection sel,
  ) {
    final base = sel.base.nodePosition;
    final extent = sel.extent.nodePosition;
    if (base is! TableCellPosition || extent is! TableCellPosition) return;

    final rects = getEndpointsForSelection(base, extent);
    final paint = Paint()..color = _selectionColor;
    for (final r in rects) {
      canvas.drawRect(r.shift(offset), paint);
    }
  }

  // ---------------------------------------------------------------------------
  // Geometry queries
  // ---------------------------------------------------------------------------

  @override
  Rect getLocalRectForPosition(NodePosition position) {
    if (position is! TableCellPosition) {
      // Gracefully return a zero-rect when position type is unexpected
      // (e.g. BinaryNodePosition from cross-node selection).
      return Rect.fromLTWH(0, 0, 0, _cellLayouts?.first.first.painter.preferredLineHeight ?? 16);
    }
    final pos = position;
    final layouts = _cellLayouts;
    assert(layouts != null, 'getLocalRectForPosition called before layout');

    final cell = layouts![pos.row][pos.col];
    final textPos = TextPosition(offset: pos.offset, affinity: pos.affinity);
    final caretOffset = cell.painter.getOffsetForCaret(textPos, Rect.zero);

    // When the cursor is at the end of text that ends with '\n', TextPainter
    // places the caret on the empty trailing line (caretOffset.dy reflects
    // this correctly).  Querying getBoxesForSelection for the '\n' character
    // would return the box for the line CONTAINING '\n', not the trailing
    // empty line — producing a mismatch between caretOffset and box.top.
    final cellText = _cells[pos.row][pos.col].text;
    if (pos.offset >= cellText.length && cellText.endsWith('\n')) {
      return Rect.fromLTWH(
        cell.textOffset.dx + caretOffset.dx,
        cell.textOffset.dy + caretOffset.dy,
        0,
        cell.painter.preferredLineHeight,
      );
    }

    // Use a 1-character selection to get the actual line height.
    final textLength = cellText.length;
    if (textLength > 0) {
      final start = pos.offset >= textLength ? textLength - 1 : pos.offset;
      final boxes = cell.painter.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + 1),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      if (boxes.isNotEmpty) {
        final box = boxes.first.toRect();
        return Rect.fromLTWH(
          cell.textOffset.dx + caretOffset.dx,
          cell.textOffset.dy + box.top,
          0,
          box.height,
        );
      }
    }

    return Rect.fromLTWH(
      cell.textOffset.dx + caretOffset.dx,
      cell.textOffset.dy + caretOffset.dy,
      0,
      cell.painter.preferredLineHeight,
    );
  }

  @override
  NodePosition getPositionAtOffset(Offset localOffset) {
    final layouts = _cellLayouts;
    assert(layouts != null, 'getPositionAtOffset called before layout');

    // Find which cell contains the offset.
    for (int r = 0; r < _rowCount; r++) {
      for (int c = 0; c < _columnCount; c++) {
        final cell = layouts![r][c];
        if (cell.cellRect.contains(localOffset)) {
          // Map the offset to the cell's text coordinate space.
          final relativeOffset = localOffset - cell.textOffset;
          final clampedOffset = Offset(
            relativeOffset.dx.clamp(0.0, cell.painter.width),
            relativeOffset.dy.clamp(0.0, cell.painter.height),
          );
          final textPos = cell.painter.getPositionForOffset(clampedOffset);
          return TableCellPosition(
            row: r,
            col: c,
            offset: textPos.offset,
            affinity: textPos.affinity,
          );
        }
      }
    }

    // Fallback: clamp to the last cell.
    final lastRow = _rowCount - 1;
    final lastCol = _columnCount - 1;
    final lastCell = layouts![lastRow][lastCol];
    final textPos = lastCell.painter.getPositionForOffset(Offset.zero);
    return TableCellPosition(
      row: lastRow,
      col: lastCol,
      offset: textPos.offset,
      affinity: textPos.affinity,
    );
  }

  @override
  List<Rect> getEndpointsForSelection(NodePosition base, NodePosition extent) {
    if (base is! TableCellPosition || extent is! TableCellPosition) {
      // Gracefully return empty when positions are not TableCellPosition
      // (e.g. cross-node selection with BinaryNodePosition endpoints).
      return const [];
    }
    final from = base;
    final to = extent;
    final layouts = _cellLayouts;
    assert(layouts != null, 'getEndpointsForSelection called before layout');

    // Normalise so that normBase precedes normExtent both by cell position and
    // by within-cell character offset.  When the two positions are in different
    // cells only the linear index matters; when they are in the same cell the
    // character offset breaks the tie so that a backward (right-to-left) drag
    // within a single cell is handled correctly.
    final fromLinear = from.row * _columnCount + from.col;
    final toLinear = to.row * _columnCount + to.col;
    final bool swap = fromLinear > toLinear || (fromLinear == toLinear && from.offset > to.offset);
    final (normBase, normExtent) = swap ? (to, from) : (from, to);

    final result = <Rect>[];

    for (int r = 0; r < _rowCount; r++) {
      for (int c = 0; c < _columnCount; c++) {
        final linear = r * _columnCount + c;
        final baseLinear = normBase.row * _columnCount + normBase.col;
        final extentLinear = normExtent.row * _columnCount + normExtent.col;

        if (linear < baseLinear || linear > extentLinear) continue;

        final cell = layouts![r][c];
        final cellStart = (linear == baseLinear) ? normBase.offset : 0;
        final cellEnd = (linear == extentLinear) ? normExtent.offset : _cells[r][c].text.length;

        if (cellStart >= cellEnd) continue;

        final boxes = cell.painter.getBoxesForSelection(
          TextSelection(baseOffset: cellStart, extentOffset: cellEnd),
        );

        for (final box in boxes) {
          final boxRect = box.toRect();
          result.add(Rect.fromLTWH(
            cell.textOffset.dx + boxRect.left,
            cell.textOffset.dy + boxRect.top,
            boxRect.width,
            boxRect.height,
          ));
        }
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('rowCount', _rowCount));
    properties.add(IntProperty('columnCount', _columnCount));
    properties.add(DiagnosticsProperty<TextStyle>('textStyle', _textStyle));
    properties.add(DoubleProperty('cellPadding', _cellPadding));
    properties.add(DoubleProperty('borderWidth', _borderWidth));
    properties.add(ColorProperty('borderColor', _borderColor));
    properties.add(EnumProperty<BlockBorderStyle>('gridBorderStyle', _gridBorderStyle));
    properties.add(ColorProperty('selectionColor', _selectionColor));
    properties.add(
      EnumProperty<TextDirection>('textDirection', _textDirection),
    );
    properties.add(
      IterableProperty<double?>('columnWidths', _columnWidths, defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<List<List<TextAlign>>>('cellTextAligns', _cellTextAligns,
          defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<List<List<TableVerticalAlignment>>>(
          'cellVerticalAligns', _cellVerticalAligns,
          defaultValue: null),
    );
    debugFillBlockLayoutProperties(properties);
    properties.add(IterableProperty<double>('computedColumnWidths', computedColumnWidths));
    properties.add(IterableProperty<double>('computedRowHeights', computedRowHeights));
    properties.add(DoubleProperty('spaceBefore', _spaceBefore, defaultValue: null));
    properties.add(DoubleProperty('spaceAfter', _spaceAfter, defaultValue: null));
    properties.add(DiagnosticsProperty<BlockBorder?>('border', _border, defaultValue: null));
  }
}
