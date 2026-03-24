/// Contextual toolbar for table editing operations.
///
/// Provides [TableContextToolbar], a compact row of buttons for alignment,
/// row/column insertion, deletion, and table resize. It is designed to be
/// positioned above a [TableNode] in the document's scrollable content stack.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/block_border.dart';
import '../../model/document_editing_controller.dart';
import '../../model/edit_request.dart';
import '../../model/table_vertical_alignment.dart';
import 'document_format_toggle.dart';
import 'table_size_picker.dart';

// ---------------------------------------------------------------------------
// TableContextToolbar
// ---------------------------------------------------------------------------

/// A contextual toolbar shown when a table cell is selected.
///
/// Provides buttons for:
/// - Cell text alignment (left / center / right)
/// - Row vertical alignment (top / middle / bottom)
/// - Row insertion above / below
/// - Column insertion left / right
/// - Row deletion
/// - Column deletion
/// - Table deletion
/// - Table resize via [TableSizePicker]
///
/// All edit operations are submitted via [requestHandler].
///
/// ```dart
/// Stack(
///   children: [
///     Positioned(
///       left: tableOffset.dx,
///       top: tableOffset.dy - 36,
///       child: TableContextToolbar(
///         controller: controller,
///         requestHandler: editor.submit,
///         nodeId: node.id,
///         minRow: minRow, maxRow: maxRow,
///         minCol: minCol, maxCol: maxCol,
///         cellTextAligns: node.cellTextAligns,
///         cellVerticalAligns: node.cellVerticalAligns,
///         rowCount: node.rowCount,
///         columnCount: node.columnCount,
///       ),
///     ),
///   ],
/// )
/// ```
class TableContextToolbar extends StatelessWidget {
  /// Creates a [TableContextToolbar].
  const TableContextToolbar({
    super.key,
    required this.controller,
    required this.requestHandler,
    required this.nodeId,
    required this.minRow,
    required this.maxRow,
    required this.minCol,
    required this.maxCol,
    required this.cellTextAligns,
    required this.cellVerticalAligns,
    required this.rowCount,
    required this.columnCount,
    this.border,
    this.gridBorderStyle = BlockBorderStyle.solid,
    this.onBorderOptionSelected,
  });

  /// The document editing controller; used to read selection state.
  final DocumentEditingController controller;

  /// Callback that receives [EditRequest]s for table mutations.
  final void Function(EditRequest) requestHandler;

  /// The ID of the [TableNode] this toolbar controls.
  final String nodeId;

  /// The first selected row index (zero-based, inclusive).
  final int minRow;

  /// The last selected row index (zero-based, inclusive).
  final int maxRow;

  /// The first selected column index (zero-based, inclusive).
  final int minCol;

  /// The last selected column index (zero-based, inclusive).
  final int maxCol;

  /// Per-cell text alignment grid from the table node, or `null` for defaults.
  final List<List<TextAlign>>? cellTextAligns;

  /// Per-cell vertical alignment grid from the table node, or `null` for defaults.
  final List<List<TableVerticalAlignment>>? cellVerticalAligns;

  /// Total number of rows in the table.
  final int rowCount;

  /// Total number of columns in the table.
  final int columnCount;

  /// The current outer border of the table, or `null` for no border.
  final BlockBorder? border;

  /// The current visual style of the internal grid lines.
  ///
  /// Defaults to [BlockBorderStyle.solid]. Set to [BlockBorderStyle.none] to
  /// indicate that grid lines are hidden.
  final BlockBorderStyle gridBorderStyle;

  /// Called when the user selects a border option from the dropdown.
  ///
  /// The [TableBorderOption] identifies which borders to change.
  final ValueChanged<TableBorderOption>? onBorderOptionSelected;

  // -------------------------------------------------------------------------
  // Shared alignment helpers
  // -------------------------------------------------------------------------

  /// Returns the [TextAlign] shared by all selected cells, or `null` if mixed.
  TextAlign? _sharedCellAlign() {
    TextAlign? shared;
    for (int r = minRow; r <= maxRow; r++) {
      for (int c = minCol; c <= maxCol; c++) {
        final align =
            cellTextAligns != null && r < cellTextAligns!.length && c < cellTextAligns![r].length
                ? cellTextAligns![r][c]
                : TextAlign.start;
        if (shared == null) {
          shared = align;
        } else if (shared != align) {
          return null;
        }
      }
    }
    return shared;
  }

  /// Returns the [TableVerticalAlignment] shared by all selected cells, or `null` if mixed.
  TableVerticalAlignment? _sharedCellVAlign() {
    TableVerticalAlignment? shared;
    for (int r = minRow; r <= maxRow; r++) {
      for (int c = minCol; c <= maxCol; c++) {
        final align = cellVerticalAligns != null &&
                r < cellVerticalAligns!.length &&
                c < cellVerticalAligns![r].length
            ? cellVerticalAligns![r][c]
            : TableVerticalAlignment.top;
        if (shared == null) {
          shared = align;
        } else if (shared != align) {
          return null;
        }
      }
    }
    return shared;
  }

  // -------------------------------------------------------------------------
  // Request helpers
  // -------------------------------------------------------------------------

  void _setCellAlign(TextAlign align) {
    for (int r = minRow; r <= maxRow; r++) {
      for (int c = minCol; c <= maxCol; c++) {
        requestHandler(
          ChangeTableCellAlignRequest(nodeId: nodeId, row: r, col: c, textAlign: align),
        );
      }
    }
  }

  void _setCellVAlign(TableVerticalAlignment align) {
    for (int r = minRow; r <= maxRow; r++) {
      for (int c = minCol; c <= maxCol; c++) {
        requestHandler(
          ChangeTableCellVerticalAlignRequest(
            nodeId: nodeId,
            row: r,
            col: c,
            verticalAlign: align,
          ),
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const iconSize = 16.0;
    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size(28, 28),
      padding: const EdgeInsets.all(2),
    );

    Widget divider() => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: SizedBox(height: 20, child: VerticalDivider(width: 1)),
        );

    final colAlign = _sharedCellAlign();
    final rowVAlign = _sharedCellVAlign();
    final deleteColor = colorScheme.error;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Resize
            TableSizePicker(
              icon: Icons.grid_on,
              tooltip: 'Resize table',
              onSelect: (rows, cols) => requestHandler(
                ResizeTableRequest(nodeId: nodeId, newRowCount: rows, newColumnCount: cols),
              ),
            ),
            divider(),
            // Column text alignment
            DocumentFormatToggle(
              icon: Icons.format_align_left,
              tooltip: 'Align column left',
              isActive: colAlign == TextAlign.start,
              onPressed: () => _setCellAlign(TextAlign.start),
            ),
            DocumentFormatToggle(
              icon: Icons.format_align_center,
              tooltip: 'Align column center',
              isActive: colAlign == TextAlign.center,
              onPressed: () => _setCellAlign(TextAlign.center),
            ),
            DocumentFormatToggle(
              icon: Icons.format_align_right,
              tooltip: 'Align column right',
              isActive: colAlign == TextAlign.right,
              onPressed: () => _setCellAlign(TextAlign.right),
            ),
            divider(),
            // Row vertical alignment
            DocumentFormatToggle(
              icon: Icons.vertical_align_top,
              tooltip: 'Align row top',
              isActive: rowVAlign == TableVerticalAlignment.top,
              onPressed: () => _setCellVAlign(TableVerticalAlignment.top),
            ),
            DocumentFormatToggle(
              icon: Icons.vertical_align_center,
              tooltip: 'Align row middle',
              isActive: rowVAlign == TableVerticalAlignment.middle,
              onPressed: () => _setCellVAlign(TableVerticalAlignment.middle),
            ),
            DocumentFormatToggle(
              icon: Icons.vertical_align_bottom,
              tooltip: 'Align row bottom',
              isActive: rowVAlign == TableVerticalAlignment.bottom,
              onPressed: () => _setCellVAlign(TableVerticalAlignment.bottom),
            ),
            divider(),
            // Insert row
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: iconSize),
              tooltip: 'Insert row above',
              style: buttonStyle,
              onPressed: () => requestHandler(
                InsertTableRowRequest(nodeId: nodeId, rowIndex: minRow, insertBefore: true),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: iconSize),
              tooltip: 'Insert row below',
              style: buttonStyle,
              onPressed: () => requestHandler(
                InsertTableRowRequest(nodeId: nodeId, rowIndex: maxRow, insertBefore: false),
              ),
            ),
            divider(),
            // Insert column
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_left, size: iconSize),
              tooltip: 'Insert column left',
              style: buttonStyle,
              onPressed: () => requestHandler(
                InsertTableColumnRequest(nodeId: nodeId, colIndex: minCol, insertBefore: true),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_right, size: iconSize),
              tooltip: 'Insert column right',
              style: buttonStyle,
              onPressed: () => requestHandler(
                InsertTableColumnRequest(nodeId: nodeId, colIndex: maxCol, insertBefore: false),
              ),
            ),
            divider(),
            // Border dropdown
            _TableBorderDropdown(
              border: border,
              gridBorderStyle: gridBorderStyle,
              onSelected: onBorderOptionSelected,
            ),
            divider(),
            // Delete row / column / table
            IconButton(
              icon: Icon(Icons.table_rows_outlined, size: iconSize, color: deleteColor),
              tooltip: 'Delete row',
              style: buttonStyle,
              onPressed: () {
                for (int r = maxRow; r >= minRow; r--) {
                  requestHandler(DeleteTableRowRequest(nodeId: nodeId, rowIndex: r));
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.view_column_outlined, size: iconSize, color: deleteColor),
              tooltip: 'Delete column',
              style: buttonStyle,
              onPressed: () {
                for (int c = maxCol; c >= minCol; c--) {
                  requestHandler(DeleteTableColumnRequest(nodeId: nodeId, colIndex: c));
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: iconSize, color: deleteColor),
              tooltip: 'Delete table',
              style: buttonStyle,
              onPressed: () => requestHandler(DeleteTableRequest(nodeId: nodeId)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController>('controller', controller),
    );
    properties.add(
      ObjectFlagProperty<void Function(EditRequest)>.has('requestHandler', requestHandler),
    );
    properties.add(StringProperty('nodeId', nodeId));
    properties.add(IntProperty('minRow', minRow));
    properties.add(IntProperty('maxRow', maxRow));
    properties.add(IntProperty('minCol', minCol));
    properties.add(IntProperty('maxCol', maxCol));
    properties.add(IntProperty('rowCount', rowCount));
    properties.add(IntProperty('columnCount', columnCount));
    properties.add(IterableProperty<List<TextAlign>>('cellTextAligns', cellTextAligns));
    properties.add(
        IterableProperty<List<TableVerticalAlignment>>('cellVerticalAligns', cellVerticalAligns));
    properties.add(DiagnosticsProperty<BlockBorder?>('border', border, defaultValue: null));
    properties.add(EnumProperty<BlockBorderStyle>('gridBorderStyle', gridBorderStyle));
    properties.add(
      ObjectFlagProperty<ValueChanged<TableBorderOption>?>.has(
        'onBorderOptionSelected',
        onBorderOptionSelected,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TableBorderOption — identifies which borders to change
// ---------------------------------------------------------------------------

/// Options for the table border dropdown menu.
enum TableBorderOption {
  /// Remove all borders (outer and inner).
  noBorder,

  /// Apply borders everywhere (outer and inner).
  allBorders,

  /// Apply only the outside border (keep inner as-is).
  outsideBorders,

  /// Apply only the inside grid lines (keep outer as-is).
  insideBorders,
}

// ---------------------------------------------------------------------------
// _TableBorderDropdown — border option picker
// ---------------------------------------------------------------------------

class _TableBorderDropdown extends StatelessWidget {
  const _TableBorderDropdown({
    required this.border,
    required this.gridBorderStyle,
    required this.onSelected,
  });

  final BlockBorder? border;
  final BlockBorderStyle gridBorderStyle;
  final ValueChanged<TableBorderOption>? onSelected;

  bool get _hasOutside => border != null;
  bool get _hasInside => gridBorderStyle != BlockBorderStyle.none;
  bool get _hasAll => _hasOutside && _hasInside;

  /// Returns the icon that best represents the current state.
  IconData get _currentIcon {
    if (_hasAll) return Icons.border_all;
    if (_hasOutside) return Icons.border_outer;
    if (_hasInside) return Icons.border_inner;
    return Icons.border_clear;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<TableBorderOption>(
      tooltip: 'Borders',
      enabled: onSelected != null,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        _item(
          TableBorderOption.noBorder,
          Icons.border_clear,
          'No Border',
          !_hasOutside && !_hasInside,
          colorScheme,
        ),
        _item(
          TableBorderOption.allBorders,
          Icons.border_all,
          'All Borders',
          _hasAll,
          colorScheme,
        ),
        _item(
          TableBorderOption.outsideBorders,
          Icons.border_outer,
          'Outside Borders',
          _hasOutside && !_hasInside,
          colorScheme,
        ),
        _item(
          TableBorderOption.insideBorders,
          Icons.border_inner,
          'Inside Borders',
          !_hasOutside && _hasInside,
          colorScheme,
        ),
      ],
      child: Container(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          _currentIcon,
          size: 18,
          color: onSelected != null
              ? colorScheme.onSurface
              : colorScheme.onSurface.withValues(alpha: 0.38),
        ),
      ),
    );
  }

  PopupMenuItem<TableBorderOption> _item(
    TableBorderOption value,
    IconData icon,
    String label,
    bool isActive,
    ColorScheme colorScheme,
  ) {
    return PopupMenuItem<TableBorderOption>(
      value: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Icon(Icons.check, size: 16, color: colorScheme.primary)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BlockBorder?>('border', border, defaultValue: null));
    properties.add(EnumProperty<BlockBorderStyle>('gridBorderStyle', gridBorderStyle));
    properties.add(
      ObjectFlagProperty<ValueChanged<TableBorderOption>?>.has('onSelected', onSelected),
    );
  }
}
