/// Table divider resize handles overlay for the editable_document package.
///
/// When the pointer hovers near an interior column or row boundary of a
/// [TableNode], [TableDividerResizeHandles] changes the cursor to a resize
/// arrow and allows the user to drag the divider to resize that column or row.
///
/// This widget is an overlay (transparent, full-size) that sits above the
/// document content and intercepts pointer events. It does not itself submit
/// any [EditRequest] — instead it fires [onColumnResize] / [onRowResize]
/// callbacks that the caller (typically [DocumentSelectionOverlay]) wires to
/// the editor.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../model/document.dart';
import '../model/document_editing_controller.dart';
import '../model/table_node.dart';
import '../rendering/render_table_block.dart';
import 'document_layout.dart';

// ---------------------------------------------------------------------------
// Callback typedefs
// ---------------------------------------------------------------------------

/// Callback invoked when a table column divider is dragged.
///
/// [nodeId] identifies the target [TableNode]. [colIndex] is the zero-based
/// index of the column whose right edge was dragged. [newWidth] is the new
/// outer width (content + 2×cellPadding) in logical pixels.
typedef TableColumnResizeCallback = void Function(String nodeId, int colIndex, double newWidth);

/// Callback invoked when a table row divider is dragged.
///
/// [nodeId] identifies the target [TableNode]. [rowIndex] is the zero-based
/// index of the row whose bottom edge was dragged. [newHeight] is the new
/// outer height in logical pixels.
typedef TableRowResizeCallback = void Function(String nodeId, int rowIndex, double newHeight);

// ---------------------------------------------------------------------------
// _DragType
// ---------------------------------------------------------------------------

/// Indicates whether an active drag is resizing a column or a row.
enum _DragType {
  /// Dragging an interior vertical grid line (column boundary).
  column,

  /// Dragging an interior horizontal grid line (row boundary).
  row,
}

// ---------------------------------------------------------------------------
// TableDividerResizeHandles
// ---------------------------------------------------------------------------

/// A transparent, full-size overlay widget that enables drag-resizing of
/// table columns and rows.
///
/// [TableDividerResizeHandles] scans the document for [TableNode]s and, on
/// each pointer hover / pointer move, checks whether the cursor is within
/// [_kHitZone] logical pixels of an **interior** column or row boundary.
/// When a boundary is detected:
///
/// - The cursor changes to [SystemMouseCursors.resizeLeftRight] (column) or
///   [SystemMouseCursors.resizeUpDown] (row).
/// - A subsequent pointer-down starts a drag. On each pointer-move the
///   [onColumnResize] or [onRowResize] callback is called with the updated
///   dimension.
///
/// The left and top outer edges (index 0) are skipped — dragging those would
/// imply moving the table. The right and bottom outer edges trigger a resize
/// of the last column or row respectively.
///
/// [isDragging] is a static flag that [DocumentMouseInteractor] checks to
/// suppress normal selection-drag behaviour while a divider drag is in
/// progress.
///
/// ```dart
/// Positioned.fill(
///   child: TableDividerResizeHandles(
///     controller: controller,
///     layoutKey: layoutKey,
///     document: document,
///     onColumnResize: (nodeId, colIndex, newWidth) {
///       editor.submit(ChangeTableColumnWidthRequest(
///         nodeId: nodeId,
///         colIndex: colIndex,
///         newWidth: newWidth,
///       ));
///     },
///     onRowResize: (nodeId, rowIndex, newHeight) {
///       editor.submit(ChangeTableRowHeightRequest(
///         nodeId: nodeId,
///         rowIndex: rowIndex,
///         newHeight: newHeight,
///       ));
///     },
///   ),
/// )
/// ```
class TableDividerResizeHandles extends StatefulWidget {
  /// Whether a table-divider drag is currently in progress.
  ///
  /// [DocumentMouseInteractor] checks this flag (alongside
  /// [BlockResizeHandles.isDragging]) to suppress normal selection-drag
  /// behaviour while the user is dragging a table divider.
  static bool isDragging = false;

  /// Creates a [TableDividerResizeHandles] widget.
  ///
  /// [controller] and [layoutKey] are required. At least one of
  /// [onColumnResize] or [onRowResize] should be non-null for the widget to
  /// have any effect.
  const TableDividerResizeHandles({
    super.key,
    required this.controller,
    required this.layoutKey,
    required this.document,
    this.onColumnResize,
    this.onRowResize,
  });

  /// The document editing controller (used for listening to selection changes).
  final DocumentEditingController controller;

  /// A [GlobalKey] for the [DocumentLayoutState] that renders the document.
  ///
  /// Used to obtain [RenderTableBlock] instances via
  /// [DocumentLayoutState.componentForNode].
  final GlobalKey<DocumentLayoutState> layoutKey;

  /// The document whose nodes are scanned for [TableNode]s.
  final Document document;

  /// Called during and at the end of a column-divider drag.
  ///
  /// [nodeId] is the [TableNode.id]. [colIndex] is the zero-based column
  /// index whose right boundary was dragged. [newWidth] is the new outer
  /// column width (content + 2×cellPadding) in logical pixels.
  ///
  /// When `null`, column dividers are not interactive.
  final TableColumnResizeCallback? onColumnResize;

  /// Called during and at the end of a row-divider drag.
  ///
  /// [nodeId] is the [TableNode.id]. [rowIndex] is the zero-based row index
  /// whose bottom boundary was dragged. [newHeight] is the new outer row
  /// height in logical pixels.
  ///
  /// When `null`, row dividers are not interactive.
  final TableRowResizeCallback? onRowResize;

  @override
  State<TableDividerResizeHandles> createState() => _TableDividerResizeHandlesState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController>('controller', controller),
    );
    properties.add(
      DiagnosticsProperty<GlobalKey<DocumentLayoutState>>('layoutKey', layoutKey),
    );
    properties.add(DiagnosticsProperty<Document>('document', document));
    properties.add(
      ObjectFlagProperty<TableColumnResizeCallback?>.has('onColumnResize', onColumnResize),
    );
    properties.add(
      ObjectFlagProperty<TableRowResizeCallback?>.has('onRowResize', onRowResize),
    );
  }
}

// ---------------------------------------------------------------------------
// _TableDividerResizeHandlesState
// ---------------------------------------------------------------------------

/// Hit-zone half-width in logical pixels. The pointer must be within this
/// distance of a boundary line to trigger a resize cursor or drag.
const double _kHitZone = 4.0;

class _TableDividerResizeHandlesState extends State<TableDividerResizeHandles> {
  // ---------------------------------------------------------------------------
  // Hover / cursor state
  // ---------------------------------------------------------------------------

  /// The mouse cursor to display.
  ///
  /// [MouseCursor.defer] when not hovering over a divider; a resize cursor
  /// when hovering over a column or row boundary.
  MouseCursor _currentCursor = MouseCursor.defer;

  // ---------------------------------------------------------------------------
  // Drag state
  // ---------------------------------------------------------------------------

  /// Whether dragging a column or row, or `null` when idle.
  _DragType? _dragType;

  /// Node id of the [TableNode] being resized.
  String? _dragNodeId;

  /// Zero-based index of the column or row being resized.
  int? _dragIndex;

  /// The global pointer position recorded at drag start.
  Offset? _dragStartPosition;

  /// The column width or row height at drag start.
  double? _dragStartDimension;

  /// The cell padding captured from the render object at drag start.
  double _dragCellPadding = 8.0;

  // ---------------------------------------------------------------------------
  // Hover helper
  // ---------------------------------------------------------------------------

  /// Checks [globalPosition] against every table in the document and returns
  /// a record describing the nearest interior boundary, or `null` if none is
  /// within [_kHitZone].
  ///
  /// The returned record is `(type, nodeId, index, startDimension, cellPadding)`.
  ({_DragType type, String nodeId, int index, double startDimension, double cellPadding})?
      _hitTestDivider(Offset globalPosition) {
    final layoutState = widget.layoutKey.currentState;
    if (layoutState == null) return null;

    for (final node in widget.document.nodes) {
      if (node is! TableNode) continue;
      final renderBlock = layoutState.componentForNode(node.id);
      if (renderBlock is! RenderTableBlock) continue;
      if (!renderBlock.hasSize) continue;

      final localPos = renderBlock.globalToLocal(globalPosition);

      // --- Column boundaries ---
      if (widget.onColumnResize != null) {
        final xPositions = renderBlock.columnBoundaryXPositions;
        // Skip index 0 (left outer edge). Include the right outer edge
        // (last index) — dragging it resizes the last column.
        for (var i = 1; i < xPositions.length; i++) {
          if ((localPos.dx - xPositions[i]).abs() <= _kHitZone) {
            // i is the boundary between column i-1 and column i.
            // The column being resized is column i-1 (zero-based).
            final colIndex = i - 1;
            final outerWidths = renderBlock.computedOuterColumnWidths;
            if (colIndex >= outerWidths.length) continue;
            return (
              type: _DragType.column,
              nodeId: node.id,
              index: colIndex,
              startDimension: outerWidths[colIndex],
              cellPadding: renderBlock.cellPadding,
            );
          }
        }
      }

      // --- Row boundaries ---
      if (widget.onRowResize != null) {
        final yPositions = renderBlock.rowBoundaryYPositions;
        // Skip index 0 (top outer edge). Include the bottom outer edge
        // (last index) — dragging it resizes the last row.
        for (var i = 1; i < yPositions.length; i++) {
          if ((localPos.dy - yPositions[i]).abs() <= _kHitZone) {
            // i is the boundary between row i-1 and row i.
            final rowIndex = i - 1;
            final rowHeights = renderBlock.computedRowHeights;
            if (rowIndex >= rowHeights.length) continue;
            return (
              type: _DragType.row,
              nodeId: node.id,
              index: rowIndex,
              startDimension: rowHeights[rowIndex],
              cellPadding: renderBlock.cellPadding,
            );
          }
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Pointer event handlers
  // ---------------------------------------------------------------------------

  void _onPointerHover(PointerHoverEvent event) {
    final hit = _hitTestDivider(event.position);
    final newCursor = hit == null
        ? MouseCursor.defer
        : hit.type == _DragType.column
            ? SystemMouseCursors.resizeLeftRight
            : SystemMouseCursors.resizeUpDown;

    if (newCursor != _currentCursor) {
      setState(() => _currentCursor = newCursor);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    final hit = _hitTestDivider(event.position);
    if (hit == null) return;

    setState(() {
      _dragType = hit.type;
      _dragNodeId = hit.nodeId;
      _dragIndex = hit.index;
      _dragStartPosition = event.position;
      _dragStartDimension = hit.startDimension;
      _dragCellPadding = hit.cellPadding;
      _currentCursor = hit.type == _DragType.column
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.resizeUpDown;
    });
    TableDividerResizeHandles.isDragging = true;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragType == null) return;
    final startPos = _dragStartPosition;
    final startDim = _dragStartDimension;
    final nodeId = _dragNodeId;
    final index = _dragIndex;
    if (startPos == null || startDim == null || nodeId == null || index == null) return;

    final minDimension = 2.0 * _dragCellPadding + 1.0;

    if (_dragType == _DragType.column) {
      final deltaX = event.position.dx - startPos.dx;
      final newWidth = (startDim + deltaX).clamp(minDimension, double.infinity);
      widget.onColumnResize?.call(nodeId, index, newWidth);
    } else {
      final deltaY = event.position.dy - startPos.dy;
      final newHeight = (startDim + deltaY).clamp(minDimension, double.infinity);
      widget.onRowResize?.call(nodeId, index, newHeight);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _endDrag();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _endDrag();
  }

  void _endDrag() {
    if (_dragType == null) return;
    setState(() {
      _dragType = null;
      _dragNodeId = null;
      _dragIndex = null;
      _dragStartPosition = null;
      _dragStartDimension = null;
      _currentCursor = MouseCursor.defer;
    });
    TableDividerResizeHandles.isDragging = false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _currentCursor,
      hitTestBehavior: HitTestBehavior.translucent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        onPointerHover: _onPointerHover,
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MouseCursor>('currentCursor', _currentCursor));
    properties.add(EnumProperty<_DragType?>('dragType', _dragType, defaultValue: null));
    properties.add(StringProperty('dragNodeId', _dragNodeId, defaultValue: null));
    properties.add(IntProperty('dragIndex', _dragIndex, defaultValue: null));
    properties.add(
        DiagnosticsProperty<Offset?>('dragStartPosition', _dragStartPosition, defaultValue: null));
    properties.add(DoubleProperty('dragStartDimension', _dragStartDimension, defaultValue: null));
    properties.add(DoubleProperty('dragCellPadding', _dragCellPadding, defaultValue: 8.0));
  }
}
