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
  /// Whether the toolbar is currently being interacted with.
  ///
  /// Set to `true` by the pointer-down handler on the toolbar's wrapper
  /// and cleared by pointer-up. Checked by [DocumentMouseInteractor] to
  /// skip selection changes when the user clicks the toolbar.
  static bool isInteracting = false;

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
    this.showHorizontalGridLines = true,
    this.showVerticalGridLines = true,
    this.gridBorderColor,
    this.gridBorderStyle = BlockBorderStyle.solid,
    this.gridBorderWidth = 1.0,
    this.onBorderOptionSelected,
    this.onGridBorderColorChanged,
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

  /// Whether horizontal grid lines between rows are currently shown.
  ///
  /// Defaults to `true`.
  final bool showHorizontalGridLines;

  /// Whether vertical grid lines between columns are currently shown.
  ///
  /// Defaults to `true`.
  final bool showVerticalGridLines;

  /// Current grid border color, or `null` for default grey.
  final Color? gridBorderColor;

  /// Current visual style of the internal grid lines.
  ///
  /// Defaults to [BlockBorderStyle.solid].
  final BlockBorderStyle gridBorderStyle;

  /// Current stroke width of the internal grid lines in logical pixels.
  ///
  /// Defaults to `1.0`.
  final double gridBorderWidth;

  /// Called when the user selects a border option from the dropdown.
  ///
  /// The [TableBorderOption] identifies which borders to change.
  final ValueChanged<TableBorderOption>? onBorderOptionSelected;

  /// Called when the user picks a border color.
  final ValueChanged<Color?>? onGridBorderColorChanged;

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
            // Border dropdown (includes color picker)
            _TableBorderDropdown(
              border: border,
              showHorizontalGridLines: showHorizontalGridLines,
              showVerticalGridLines: showVerticalGridLines,
              gridBorderColor: gridBorderColor ?? const Color(0xFFCCCCCC),
              gridBorderStyle: gridBorderStyle,
              gridBorderWidth: gridBorderWidth,
              onSelected: onBorderOptionSelected,
              onColorChanged: onGridBorderColorChanged,
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
    properties.add(FlagProperty('showHorizontalGridLines',
        value: showHorizontalGridLines, ifTrue: 'showHorizontalGridLines'));
    properties.add(FlagProperty('showVerticalGridLines',
        value: showVerticalGridLines, ifTrue: 'showVerticalGridLines'));
    properties.add(ColorProperty('gridBorderColor', gridBorderColor, defaultValue: null));
    properties.add(
      EnumProperty<BlockBorderStyle>(
        'gridBorderStyle',
        gridBorderStyle,
        defaultValue: BlockBorderStyle.solid,
      ),
    );
    properties.add(DoubleProperty('gridBorderWidth', gridBorderWidth, defaultValue: 1.0));
    properties.add(
      ObjectFlagProperty<ValueChanged<TableBorderOption>?>.has(
        'onBorderOptionSelected',
        onBorderOptionSelected,
      ),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<Color?>?>.has(
        'onGridBorderColorChanged',
        onGridBorderColorChanged,
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

  /// Apply only horizontal inside grid lines (rows only).
  horizontalInsideBorders,

  /// Apply only vertical inside grid lines (columns only).
  verticalInsideBorders,

  /// Apply a bottom edge border to the selected cells.
  bottomBorder,

  /// Apply a top edge border to the selected cells.
  topBorder,

  /// Apply a left edge border to the selected cells.
  leftBorder,

  /// Apply a right edge border to the selected cells.
  rightBorder,

  /// Change grid line style to solid.
  styleSolid,

  /// Change grid line style to dotted.
  styleDotted,

  /// Change grid line style to dashed.
  styleDashed,

  /// Change grid line width to thin (1.0 px).
  widthThin,

  /// Change grid line width to thick (2.0 px).
  widthThick,
}

// ---------------------------------------------------------------------------
// _TableBorderDropdown — border option picker using MenuAnchor
// ---------------------------------------------------------------------------

/// A border menu button using [MenuAnchor] with [SubmenuButton] for Color,
/// Style, and Width sub-menus.
class _TableBorderDropdown extends StatelessWidget {
  const _TableBorderDropdown({
    required this.border,
    required this.showHorizontalGridLines,
    required this.showVerticalGridLines,
    required this.gridBorderColor,
    required this.gridBorderStyle,
    required this.gridBorderWidth,
    required this.onSelected,
    required this.onColorChanged,
  });

  final BlockBorder? border;
  final bool showHorizontalGridLines;
  final bool showVerticalGridLines;
  final Color gridBorderColor;
  final BlockBorderStyle gridBorderStyle;
  final double gridBorderWidth;
  final ValueChanged<TableBorderOption>? onSelected;
  final ValueChanged<Color?>? onColorChanged;

  bool get _hasOutside => border != null;
  bool get _hasInside => showHorizontalGridLines || showVerticalGridLines;
  bool get _hasAll => _hasOutside && _hasInside;

  IconData get _currentIcon {
    if (_hasAll) return Icons.border_all;
    if (_hasOutside) return Icons.border_outer;
    if (_hasInside) return Icons.border_inner;
    return Icons.border_clear;
  }

  void _select(TableBorderOption opt) => onSelected?.call(opt);

  static const _colors = [
    Color(0xFFCCCCCC),
    Color(0xFF000000),
    Color(0xFF2196F3),
    Color(0xFFF44336),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget chk(bool active) =>
        active ? Icon(Icons.check, size: 14, color: cs.primary) : const SizedBox(width: 14);

    MenuItemButton item(TableBorderOption opt, IconData icon, String label, bool active) {
      return MenuItemButton(
        leadingIcon: chk(active),
        trailingIcon: Icon(icon, size: 18),
        onPressed: () => _select(opt),
        child: Text(label),
      );
    }

    return MenuAnchor(
      builder: (context, controller, child) {
        return IconButton(
          icon: Icon(_currentIcon, size: 18),
          tooltip: 'Borders',
          onPressed: onSelected != null
              ? () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                }
              : null,
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            padding: const EdgeInsets.all(4),
          ),
        );
      },
      menuChildren: [
        item(TableBorderOption.noBorder, Icons.border_clear, 'No Border',
            !_hasOutside && !_hasInside),
        item(TableBorderOption.allBorders, Icons.border_all, 'All Borders', _hasAll),
        item(TableBorderOption.outsideBorders, Icons.border_outer, 'Outside',
            _hasOutside && !_hasInside),
        item(TableBorderOption.insideBorders, Icons.border_inner, 'Inside',
            !_hasOutside && _hasInside),
        item(TableBorderOption.horizontalInsideBorders, Icons.border_horizontal, 'Horizontal',
            showHorizontalGridLines && !showVerticalGridLines),
        item(TableBorderOption.verticalInsideBorders, Icons.border_vertical, 'Vertical',
            !showHorizontalGridLines && showVerticalGridLines),
        const Divider(height: 1),
        item(TableBorderOption.bottomBorder, Icons.border_bottom, 'Bottom', false),
        item(TableBorderOption.topBorder, Icons.border_top, 'Top', false),
        item(TableBorderOption.leftBorder, Icons.border_left, 'Left', false),
        item(TableBorderOption.rightBorder, Icons.border_right, 'Right', false),
        const Divider(height: 1),
        // Color submenu
        SubmenuButton(
          leadingIcon: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: gridBorderColor,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          menuChildren: [
            for (final c in _colors)
              MenuItemButton(
                leadingIcon: chk(c == gridBorderColor),
                onPressed: () => onColorChanged?.call(c),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
          child: const Text('Color'),
        ),
        // Style submenu
        SubmenuButton(
          leadingIcon: const Icon(Icons.line_style, size: 16),
          menuChildren: [
            MenuItemButton(
              leadingIcon: chk(gridBorderStyle == BlockBorderStyle.solid),
              onPressed: () => _select(TableBorderOption.styleSolid),
              child: const Text('Solid'),
            ),
            MenuItemButton(
              leadingIcon: chk(gridBorderStyle == BlockBorderStyle.dotted),
              onPressed: () => _select(TableBorderOption.styleDotted),
              child: const Text('Dotted'),
            ),
            MenuItemButton(
              leadingIcon: chk(gridBorderStyle == BlockBorderStyle.dashed),
              onPressed: () => _select(TableBorderOption.styleDashed),
              child: const Text('Dashed'),
            ),
          ],
          child: const Text('Style'),
        ),
        // Width submenu
        SubmenuButton(
          leadingIcon: const Icon(Icons.line_weight, size: 16),
          menuChildren: [
            MenuItemButton(
              leadingIcon: chk(gridBorderWidth == 1.0),
              onPressed: () => _select(TableBorderOption.widthThin),
              child: const Text('Thin'),
            ),
            MenuItemButton(
              leadingIcon: chk(gridBorderWidth == 2.0),
              onPressed: () => _select(TableBorderOption.widthThick),
              child: const Text('Thick'),
            ),
          ],
          child: const Text('Width'),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BlockBorder?>('border', border, defaultValue: null));
    properties.add(FlagProperty('showHorizontalGridLines',
        value: showHorizontalGridLines, ifTrue: 'showHorizontalGridLines'));
    properties.add(FlagProperty('showVerticalGridLines',
        value: showVerticalGridLines, ifTrue: 'showVerticalGridLines'));
    properties.add(ColorProperty('gridBorderColor', gridBorderColor));
    properties.add(EnumProperty<BlockBorderStyle>(
      'gridBorderStyle',
      gridBorderStyle,
      defaultValue: BlockBorderStyle.solid,
    ));
    properties.add(DoubleProperty('gridBorderWidth', gridBorderWidth, defaultValue: 1.0));
    properties
        .add(ObjectFlagProperty<ValueChanged<TableBorderOption>?>.has('onSelected', onSelected));
    properties.add(ObjectFlagProperty<ValueChanged<Color?>?>.has('onColorChanged', onColorChanged));
  }
}
