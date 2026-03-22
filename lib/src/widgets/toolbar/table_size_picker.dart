/// A toolbar button that shows an interactive grid for selecting table dimensions.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// TableSizePicker
// ---------------------------------------------------------------------------

/// A toolbar button that shows an interactive grid for selecting table dimensions.
///
/// On tap, opens an [OverlayEntry] anchored below the button showing an
/// [maxRows] × [maxCols] grid. Hovering highlights cells to preview the
/// selection. Tapping a cell calls [onSelect] with the chosen row and column
/// counts and closes the overlay.
///
/// ```dart
/// TableSizePicker(
///   onSelect: (rows, cols) {
///     requestHandler(InsertTableIntent(rows: rows, columns: cols));
///   },
/// )
/// ```
class TableSizePicker extends StatefulWidget {
  /// Creates a [TableSizePicker].
  const TableSizePicker({
    super.key,
    this.enabled = true,
    required this.onSelect,
    this.maxRows = 8,
    this.maxCols = 8,
    this.icon,
    this.tooltip,
  });

  /// Whether the button is interactive.
  ///
  /// When `false`, tapping does not open the grid.
  final bool enabled;

  /// Called with the chosen (rows, cols) when the user taps a cell.
  final void Function(int rows, int cols) onSelect;

  /// Maximum number of rows in the grid. Defaults to `8`.
  final int maxRows;

  /// Maximum number of columns in the grid. Defaults to `8`.
  final int maxCols;

  /// Optional custom icon. Defaults to [Icons.table_chart_outlined].
  final IconData? icon;

  /// Optional tooltip text. Defaults to `'Insert table'`.
  final String? tooltip;

  @override
  State<TableSizePicker> createState() => _TableSizePickerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('enabled', value: enabled, ifTrue: 'enabled'));
    properties.add(ObjectFlagProperty<void Function(int, int)>.has('onSelect', onSelect));
    properties.add(IntProperty('maxRows', maxRows, defaultValue: 8));
    properties.add(IntProperty('maxCols', maxCols, defaultValue: 8));
    properties.add(DiagnosticsProperty<IconData>('icon', icon, defaultValue: null));
    properties.add(StringProperty('tooltip', tooltip, defaultValue: null));
  }
}

class _TableSizePickerState extends State<TableSizePicker> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _showPicker() {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => _TableSizePickerOverlay(
        layerLink: _layerLink,
        maxRows: widget.maxRows,
        maxCols: widget.maxCols,
        onSelect: (rows, cols) {
          _hideOverlay();
          widget.onSelect(rows, cols);
        },
        onDismiss: _hideOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        icon: Icon(widget.icon ?? Icons.table_chart_outlined, size: 18),
        onPressed: widget.enabled ? _showPicker : null,
        tooltip: widget.tooltip ?? 'Insert table',
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          padding: const EdgeInsets.all(4),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TableSizePickerOverlay
// ---------------------------------------------------------------------------

/// Overlay popup that shows the row/column grid.
class _TableSizePickerOverlay extends StatefulWidget {
  const _TableSizePickerOverlay({
    required this.layerLink,
    required this.maxRows,
    required this.maxCols,
    required this.onSelect,
    required this.onDismiss,
  });

  final LayerLink layerLink;
  final int maxRows;
  final int maxCols;
  final void Function(int rows, int cols) onSelect;
  final VoidCallback onDismiss;

  @override
  State<_TableSizePickerOverlay> createState() => _TableSizePickerOverlayState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LayerLink>('layerLink', layerLink));
    properties.add(IntProperty('maxRows', maxRows));
    properties.add(IntProperty('maxCols', maxCols));
    properties.add(ObjectFlagProperty<void Function(int, int)>.has('onSelect', onSelect));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onDismiss', onDismiss));
  }
}

class _TableSizePickerOverlayState extends State<_TableSizePickerOverlay> {
  static const double _cellSize = 24.0;
  static const double _cellSpacing = 2.0;

  int _hoverRow = 0;
  int _hoverCol = 0;

  void _onHover(Offset localPosition) {
    final col =
        (localPosition.dx / (_cellSize + _cellSpacing)).floor().clamp(0, widget.maxCols - 1);
    final row =
        (localPosition.dy / (_cellSize + _cellSpacing)).floor().clamp(0, widget.maxRows - 1);
    if (row != _hoverRow || col != _hoverCol) {
      setState(() {
        _hoverRow = row;
        _hoverCol = col;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gridWidth = widget.maxCols * (_cellSize + _cellSpacing) - _cellSpacing;
    final gridHeight = widget.maxRows * (_cellSize + _cellSpacing) - _cellSpacing;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Full-screen transparent layer to catch outside taps.
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        // Popup anchored below the button.
        CompositedTransformFollower(
          link: widget.layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MouseRegion(
                    onHover: (event) => _onHover(event.localPosition),
                    child: GestureDetector(
                      onTapUp: (_) => widget.onSelect(_hoverRow + 1, _hoverCol + 1),
                      child: SizedBox(
                        width: gridWidth,
                        height: gridHeight,
                        child: CustomPaint(
                          painter: _GridPainter(
                            maxRows: widget.maxRows,
                            maxCols: widget.maxCols,
                            cellSize: _cellSize,
                            cellSpacing: _cellSpacing,
                            selectedRows: _hoverRow + 1,
                            selectedCols: _hoverCol + 1,
                            highlightColor: colorScheme.primary.withValues(alpha: 0.3),
                            borderColor: colorScheme.outline.withValues(alpha: 0.3),
                            selectedBorderColor: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_hoverRow + 1} \u00d7 ${_hoverCol + 1}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _GridPainter
// ---------------------------------------------------------------------------

/// [CustomPainter] that draws the table size picker grid.
///
/// Cells within the highlighted range (0..[selectedRows) × 0..[selectedCols))
/// are filled with [highlightColor] and outlined with [selectedBorderColor].
/// All other cells are outlined with [borderColor] only.
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.maxRows,
    required this.maxCols,
    required this.cellSize,
    required this.cellSpacing,
    required this.selectedRows,
    required this.selectedCols,
    required this.highlightColor,
    required this.borderColor,
    required this.selectedBorderColor,
  });

  final int maxRows;
  final int maxCols;
  final double cellSize;
  final double cellSpacing;
  final int selectedRows;
  final int selectedCols;
  final Color highlightColor;
  final Color borderColor;
  final Color selectedBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(3);
    final fillPaint = Paint()..color = highlightColor;
    final selectedStroke = Paint()
      ..color = selectedBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final normalStroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int r = 0; r < maxRows; r++) {
      for (int c = 0; c < maxCols; c++) {
        final rect = Rect.fromLTWH(
          c * (cellSize + cellSpacing),
          r * (cellSize + cellSpacing),
          cellSize,
          cellSize,
        );
        final rrect = RRect.fromRectAndRadius(rect, radius);
        final isSelected = r < selectedRows && c < selectedCols;

        if (isSelected) {
          canvas.drawRRect(rrect, fillPaint);
        }
        canvas.drawRRect(rrect, isSelected ? selectedStroke : normalStroke);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.selectedRows != selectedRows ||
      old.selectedCols != selectedCols ||
      old.highlightColor != highlightColor ||
      old.borderColor != borderColor ||
      old.selectedBorderColor != selectedBorderColor;
}
