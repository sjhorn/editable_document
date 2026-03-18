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
  /// [nodeId] must match the corresponding [DocumentNode.id].
  /// [rowCount] and [columnCount] define the grid dimensions.
  /// [cells] is a [rowCount] × [columnCount] grid of [AttributedText] values.
  /// [textStyle] is the base [TextStyle] applied before attributions.
  /// [columnWidths] optionally specifies per-column widths in logical pixels;
  ///   `null` entries mean that column is auto-sized.  When the list itself is
  ///   `null`, all columns are auto-sized.
  /// [cellPadding] is the horizontal and vertical padding inside each cell.
  /// [borderWidth] is the stroke width of the grid lines.
  /// [borderColor] is the color of the grid lines.
  /// [selectionColor] is the background fill drawn behind selected text.
  /// [textDirection] controls the reading direction of all cells.
  /// [blockAlignment] and [textWrap] follow the same semantics as other block
  ///   types via [BlockLayoutMixin].
  /// [columnTextAligns] optionally specifies per-column [TextAlign]; `null`
  ///   entries (or a `null` list) default to [TextAlign.start].
  /// [rowVerticalAligns] optionally specifies per-row [TableVerticalAlignment];
  ///   `null` entries (or a `null` list) default to [TableVerticalAlignment.top].
  RenderTableBlock({
    required String nodeId,
    required int rowCount,
    required int columnCount,
    required List<List<AttributedText>> cells,
    required TextStyle textStyle,
    List<double?>? columnWidths,
    double cellPadding = 8.0,
    double borderWidth = 1.0,
    Color borderColor = const Color(0xFFCCCCCC),
    Color selectionColor = const Color(0x663399FF),
    TextDirection textDirection = TextDirection.ltr,
    BlockAlignment blockAlignment = BlockAlignment.stretch,
    double? requestedWidth,
    double? requestedHeight,
    TextWrapMode textWrap = TextWrapMode.none,
    List<TextAlign>? columnTextAligns,
    List<TableVerticalAlignment>? rowVerticalAligns,
  })  : _nodeId = nodeId,
        _rowCount = rowCount,
        _columnCount = columnCount,
        _cells = cells,
        _textStyle = textStyle,
        _columnWidths = columnWidths,
        _cellPadding = cellPadding,
        _borderWidth = borderWidth,
        _borderColor = borderColor,
        _selectionColor = selectionColor,
        _textDirection = textDirection,
        _columnTextAligns = columnTextAligns,
        _rowVerticalAligns = rowVerticalAligns {
    initBlockLayout(
      blockAlignment: blockAlignment,
      requestedWidth: requestedWidth,
      requestedHeight: requestedHeight,
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
  double _cellPadding;
  double _borderWidth;
  Color _borderColor;
  Color _selectionColor;
  TextDirection _textDirection;
  List<TextAlign>? _columnTextAligns;
  List<TableVerticalAlignment>? _rowVerticalAligns;
  DocumentSelection? _nodeSelection;
  double? _spaceBefore;
  double? _spaceAfter;

  /// Cache of per-cell layout results; rebuilt by [performLayout].
  List<List<_CellLayout>>? _cellLayouts;

  /// Cached column widths (after auto distribution); populated by
  /// [performLayout].
  List<double> _computedColumnWidths = const [];

  /// Cached row heights; populated by [performLayout].
  List<double> _computedRowHeights = const [];

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

  /// Sets [spaceBefore] and notifies the parent layout when the value changes.
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

  /// Sets [spaceAfter] and notifies the parent layout when the value changes.
  set spaceAfter(double? value) {
    if (_spaceAfter == value) return;
    _spaceAfter = value;
    if (parent is RenderObject) (parent!).markNeedsLayout();
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

  /// Per-column [TextAlign] overrides, or `null` when all columns use the
  /// default [TextAlign.start].
  // ignore: diagnostic_describe_all_properties
  List<TextAlign>? get columnTextAligns => _columnTextAligns;

  /// Sets the per-column text alignments and schedules a layout pass.
  set columnTextAligns(List<TextAlign>? value) {
    if (_columnTextAligns == value) return;
    _columnTextAligns = value;
    markNeedsLayout();
  }

  /// Per-row [TableVerticalAlignment] overrides, or `null` when all rows use
  /// the default [TableVerticalAlignment.top].
  // ignore: diagnostic_describe_all_properties
  List<TableVerticalAlignment>? get rowVerticalAligns => _rowVerticalAligns;

  /// Sets the per-row vertical alignments and schedules a layout pass.
  set rowVerticalAligns(List<TableVerticalAlignment>? value) {
    if (_rowVerticalAligns == value) return;
    _rowVerticalAligns = value;
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
          textAlign: _columnTextAligns != null && c < _columnTextAligns!.length
              ? _columnTextAligns![c]
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

    _computedRowHeights = rowHeights;

    // --- Phase 2: compute cell origin offsets and build _CellLayout grid ---
    final cellLayouts = List.generate(_rowCount, (_) => <_CellLayout>[]);

    // Compute cumulative y positions for rows.
    double y = _borderWidth;
    final rowTops = <double>[];
    for (int r = 0; r < _rowCount; r++) {
      rowTops.add(y);
      y += rowHeights[r] + _borderWidth;
    }

    // Compute cumulative x positions for columns.
    double x = _borderWidth;
    final colLefts = <double>[];
    for (int c = 0; c < _columnCount; c++) {
      colLefts.add(x);
      x += outerWidths[c] + _borderWidth;
    }

    for (int r = 0; r < _rowCount; r++) {
      final vertAlign = _rowVerticalAligns != null && r < _rowVerticalAligns!.length
          ? _rowVerticalAligns![r]
          : TableVerticalAlignment.top;

      for (int c = 0; c < _columnCount; c++) {
        final cellRect = Rect.fromLTWH(
          colLefts[c],
          rowTops[r],
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
          colLefts[c] + _cellPadding,
          rowTops[r] + _cellPadding + vOffset.clamp(0.0, double.infinity),
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
    final totalHeight = rowHeights.fold(0.0, (sum, h) => sum + h) + (_rowCount + 1) * _borderWidth;

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

    // --- Paint borders ---
    if (_borderWidth > 0) {
      final paint = Paint()
        ..color = _borderColor
        ..strokeWidth = _borderWidth
        ..style = PaintingStyle.stroke;
      for (int r = 0; r < _rowCount; r++) {
        for (int c = 0; c < _columnCount; c++) {
          final cell = layouts[r][c];
          context.canvas.drawRect(
            cell.cellRect.shift(offset).inflate(_borderWidth / 2),
            paint,
          );
        }
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
    properties.add(ColorProperty('selectionColor', _selectionColor));
    properties.add(
      EnumProperty<TextDirection>('textDirection', _textDirection),
    );
    properties.add(
      IterableProperty<double?>('columnWidths', _columnWidths, defaultValue: null),
    );
    properties.add(
      IterableProperty<TextAlign>('columnTextAligns', _columnTextAligns, defaultValue: null),
    );
    properties.add(
      IterableProperty<TableVerticalAlignment>('rowVerticalAligns', _rowVerticalAligns,
          defaultValue: null),
    );
    debugFillBlockLayoutProperties(properties);
    properties.add(IterableProperty<double>('computedColumnWidths', computedColumnWidths));
    properties.add(IterableProperty<double>('computedRowHeights', computedRowHeights));
    properties.add(DoubleProperty('spaceBefore', _spaceBefore, defaultValue: null));
    properties.add(DoubleProperty('spaceAfter', _spaceAfter, defaultValue: null));
  }
}
