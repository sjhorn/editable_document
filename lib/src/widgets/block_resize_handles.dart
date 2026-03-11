/// Block selection border with resize handles for the editable_document package.
///
/// When a single non-stretch [HasBlockLayout] block is fully selected,
/// [BlockResizeHandles] draws a selection border and eight drag handles
/// (four corners + four edge midpoints) that allow the user to resize
/// the block by dragging.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../model/block_alignment.dart';
import '../model/block_layout.dart';
import '../model/blockquote_node.dart';
import '../model/code_block_node.dart';
import '../model/document.dart';
import '../model/document_editing_controller.dart';
import '../model/document_node.dart';
import '../model/edit_request.dart';
import '../model/horizontal_rule_node.dart';
import '../model/image_node.dart';
import '../model/node_position.dart';
import '../model/table_node.dart';
import 'document_layout.dart';

// ---------------------------------------------------------------------------
// BlockResizeCallback
// ---------------------------------------------------------------------------

/// Callback invoked when the user drags a resize handle on a block node.
///
/// [nodeId] identifies the block being resized. [width] and [height] are the
/// new desired dimensions in logical pixels. Either value may be `null`,
/// meaning "preserve the current value" for that dimension.
typedef BlockResizeCallback = void Function(
  String nodeId,
  double? width,
  double? height,
);

// ---------------------------------------------------------------------------
// ResizeHandlePosition
// ---------------------------------------------------------------------------

/// The position of a resize handle on the selection border of a block node.
///
/// Eight handles are provided: four corners and four edge midpoints.
enum ResizeHandlePosition {
  /// Top-left corner handle.
  topLeft,

  /// Top edge midpoint handle.
  topCenter,

  /// Top-right corner handle.
  topRight,

  /// Left edge midpoint handle.
  middleLeft,

  /// Right edge midpoint handle.
  middleRight,

  /// Bottom-left corner handle.
  bottomLeft,

  /// Bottom edge midpoint handle.
  bottomCenter,

  /// Bottom-right corner handle.
  bottomRight,
}

// ---------------------------------------------------------------------------
// BlockResizeHandles
// ---------------------------------------------------------------------------

/// A widget that draws a selection border and eight drag handles around a
/// fully-selected, non-stretch [HasBlockLayout] block node.
///
/// [BlockResizeHandles] is an overlay widget: it does not occupy space in the
/// document flow. It watches [controller] for selection changes and shows
/// handles only when:
///
/// * [onResize] is non-null (handles are disabled without a resize callback),
/// * a single block node is fully selected (base at upstream, extent at
///   downstream),
/// * and the node implements [HasBlockLayout] with
///   [HasBlockLayout.alignment] != [BlockAlignment.stretch].
///
/// On drag-end the [onResize] callback is invoked with the node id and the
/// new width/height values. The caller is responsible for submitting the
/// corresponding [EditRequest] (e.g. via [createResizeRequest]).
///
/// Example:
/// ```dart
/// BlockResizeHandles(
///   controller: myController,
///   layoutKey: myLayoutKey,
///   document: myDocument,
///   onResize: (nodeId, width, height) {
///     final node = myDocument.nodeById(nodeId);
///     if (node == null) return;
///     final req = createResizeRequest(node, width, height);
///     if (req != null) editor.submit(req);
///   },
/// )
/// ```
class BlockResizeHandles extends StatefulWidget {
  /// Whether a resize drag is currently in progress.
  ///
  /// [DocumentMouseInteractor] checks this to skip its own drag-selection
  /// logic when the user is dragging a resize handle.
  static bool isDragging = false;

  /// Creates a [BlockResizeHandles] widget.
  ///
  /// [controller] and [layoutKey] are required. [onResize] must be non-null
  /// for handles to appear.
  const BlockResizeHandles({
    super.key,
    required this.controller,
    required this.layoutKey,
    required this.document,
    this.onResize,
    this.handleSize = 8.0,
    this.borderColor = const Color(0xFF2196F3),
    this.handleColor = const Color(0xFF2196F3),
    this.minWidth = 20.0,
    this.minHeight = 20.0,
  });

  /// The document editing controller.
  ///
  /// [BlockResizeHandles] listens to this controller and rebuilds whenever
  /// the selection changes.
  final DocumentEditingController controller;

  /// A [GlobalKey] for the [DocumentLayoutState] that renders the document.
  ///
  /// Used to query the screen position and size of the selected block at
  /// build time via [DocumentLayoutState.componentForNode].
  final GlobalKey<DocumentLayoutState> layoutKey;

  /// The document whose nodes are inspected to determine if a selected node
  /// implements [HasBlockLayout].
  final Document document;

  /// Called when the user finishes a resize drag.
  ///
  /// Receives the [nodeId] of the resized block along with the new [width]
  /// and [height] in logical pixels. A `null` dimension means "preserve the
  /// current value".
  ///
  /// When `null`, no handles are drawn.
  final BlockResizeCallback? onResize;

  /// The side length of each square handle in logical pixels.
  ///
  /// Defaults to `8.0`.
  final double handleSize;

  /// The color of the selection border.
  ///
  /// Defaults to `Color(0xFF2196F3)` (Material Blue 500).
  final Color borderColor;

  /// The fill color of each resize handle square.
  ///
  /// Defaults to `Color(0xFF2196F3)` (Material Blue 500).
  final Color handleColor;

  /// The minimum width the block may be resized to, in logical pixels.
  ///
  /// Defaults to `20.0`.
  final double minWidth;

  /// The minimum height the block may be resized to, in logical pixels.
  ///
  /// Defaults to `20.0`.
  final double minHeight;

  @override
  State<BlockResizeHandles> createState() => _BlockResizeHandlesState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController>(
        'controller',
        controller,
      ),
    );
    properties.add(
      DiagnosticsProperty<GlobalKey<DocumentLayoutState>>(
        'layoutKey',
        layoutKey,
      ),
    );
    properties.add(DiagnosticsProperty<Document>('document', document));
    properties.add(
      ObjectFlagProperty<BlockResizeCallback?>.has('onResize', onResize),
    );
    properties.add(
      DoubleProperty('handleSize', handleSize, defaultValue: 8.0),
    );
    properties.add(ColorProperty('borderColor', borderColor));
    properties.add(ColorProperty('handleColor', handleColor));
    properties.add(
      DoubleProperty('minWidth', minWidth, defaultValue: 20.0),
    );
    properties.add(
      DoubleProperty('minHeight', minHeight, defaultValue: 20.0),
    );
  }
}

// ---------------------------------------------------------------------------
// _BlockResizeHandlesState
// ---------------------------------------------------------------------------

class _BlockResizeHandlesState extends State<BlockResizeHandles> {
  // The block rect in this widget's local coordinates, populated after layout.
  Rect? _blockRect;

  // --- Drag state ---

  /// Which handle is currently being dragged, or `null` when idle.
  ResizeHandlePosition? _dragHandlePosition;

  /// Accumulated drag delta since the drag started.
  Offset _dragDelta = Offset.zero;

  /// The size of the block at the moment the drag began.
  Size? _dragStartSize;

  /// The node id captured at drag start, so it survives selection changes.
  String? _dragNodeId;

  /// The pointer id currently being tracked for a drag, or `null`.
  int? _activePointer;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _scheduleGeometryUpdate();
  }

  @override
  void didUpdateWidget(BlockResizeHandles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    _scheduleGeometryUpdate();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Change listeners
  // ---------------------------------------------------------------------------

  void _onControllerChanged() {
    // Don't clear the block rect during an active drag — the interactor may
    // have changed the selection but we still need the rect for the preview.
    if (_activePointer != null) return;
    _scheduleGeometryUpdate();
  }

  // ---------------------------------------------------------------------------
  // Geometry query
  // ---------------------------------------------------------------------------

  /// Schedules a post-frame callback to query the render block geometry.
  ///
  /// This must be deferred to after layout so that [RenderDocumentBlock.size]
  /// and [RenderDocumentBlock.localToGlobal] are valid.
  void _scheduleGeometryUpdate() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateBlockRect();
    });
  }

  void _updateBlockRect() {
    final nodeId = _selectedNodeId();
    if (nodeId == null) {
      if (_blockRect != null) {
        setState(() => _blockRect = null);
      }
      return;
    }

    final renderBlock = widget.layoutKey.currentState?.componentForNode(nodeId);
    if (renderBlock == null || !renderBlock.hasSize) {
      if (_blockRect != null) {
        setState(() => _blockRect = null);
      }
      return;
    }

    final layoutRenderObject = widget.layoutKey.currentState?.renderObject;
    if (layoutRenderObject == null) {
      if (_blockRect != null) {
        setState(() => _blockRect = null);
      }
      return;
    }
    final blockOffset = renderBlock.localToGlobal(
      Offset.zero,
      ancestor: layoutRenderObject,
    );
    final newRect = blockOffset & renderBlock.size;

    if (newRect != _blockRect) {
      setState(() => _blockRect = newRect);
    }
  }

  // ---------------------------------------------------------------------------
  // Selection helpers
  // ---------------------------------------------------------------------------

  /// Returns the node id of the single fully-selected block, or `null`.
  String? _selectedNodeId() {
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) return null;
    if (selection.base.nodeId != selection.extent.nodeId) return null;

    final basePos = selection.base.nodePosition;
    final extentPos = selection.extent.nodePosition;

    // Must be upstream → downstream (fully selected binary node).
    if (basePos is! BinaryNodePosition || extentPos is! BinaryNodePosition) {
      return null;
    }
    if (basePos.type != BinaryNodePositionType.upstream) return null;
    if (extentPos.type != BinaryNodePositionType.downstream) return null;

    return selection.base.nodeId;
  }

  /// Returns `true` when handles should be shown.
  bool _shouldShowHandles() {
    if (widget.onResize == null) return false;

    // During an active drag, keep showing handles even though the selection
    // may have been changed by the mouse interactor.
    if (_activePointer != null) return _blockRect != null;

    final nodeId = _selectedNodeId();
    if (nodeId == null) return false;

    final node = widget.document.nodeById(nodeId);
    if (node == null) return false;
    if (node is! HasBlockLayout) return false;
    if ((node as HasBlockLayout).alignment == BlockAlignment.stretch) {
      return false;
    }

    return _blockRect != null;
  }

  // ---------------------------------------------------------------------------
  // Drag logic — raw pointer events via Listener
  // ---------------------------------------------------------------------------

  void _onPointerDown(
    ResizeHandlePosition handle,
    PointerDownEvent event,
  ) {
    _activePointer = event.pointer;
    _dragNodeId = _selectedNodeId();
    BlockResizeHandles.isDragging = true;
    setState(() {
      _dragHandlePosition = handle;
      _dragDelta = Offset.zero;
      _dragStartSize = _blockRect?.size;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    setState(() {
      _dragDelta += event.delta;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _finishDrag();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _finishDrag();
  }

  void _finishDrag() {
    final handle = _dragHandlePosition;
    final startSize = _dragStartSize;
    final nodeId = _dragNodeId;

    if (handle != null && startSize != null && nodeId != null) {
      final result = _computeNewSize(handle, startSize, _dragDelta);
      final newWidth =
          result.$1 != null ? result.$1!.clamp(widget.minWidth, double.infinity) : null;
      final newHeight =
          result.$2 != null ? result.$2!.clamp(widget.minHeight, double.infinity) : null;
      widget.onResize?.call(nodeId, newWidth, newHeight);
    }

    _activePointer = null;
    _dragNodeId = null;
    BlockResizeHandles.isDragging = false;
    setState(() {
      _dragHandlePosition = null;
      _dragDelta = Offset.zero;
      _dragStartSize = null;
    });
  }

  /// Computes the new (width, height) from [original] size and [delta].
  ///
  /// Returns a record of `(newWidth, newHeight)`. A `null` component means
  /// "do not change this dimension".
  (double?, double?) _computeNewSize(
    ResizeHandlePosition handle,
    Size original,
    Offset delta,
  ) {
    double? newWidth;
    double? newHeight;

    switch (handle) {
      case ResizeHandlePosition.topLeft:
        newWidth = original.width - delta.dx;
        newHeight = original.height - delta.dy;
      case ResizeHandlePosition.topCenter:
        newHeight = original.height - delta.dy;
      case ResizeHandlePosition.topRight:
        newWidth = original.width + delta.dx;
        newHeight = original.height - delta.dy;
      case ResizeHandlePosition.middleLeft:
        newWidth = original.width - delta.dx;
      case ResizeHandlePosition.middleRight:
        newWidth = original.width + delta.dx;
      case ResizeHandlePosition.bottomLeft:
        newWidth = original.width - delta.dx;
        newHeight = original.height + delta.dy;
      case ResizeHandlePosition.bottomCenter:
        newHeight = original.height + delta.dy;
      case ResizeHandlePosition.bottomRight:
        newWidth = original.width + delta.dx;
        newHeight = original.height + delta.dy;
    }

    return (newWidth, newHeight);
  }

  // ---------------------------------------------------------------------------
  // Preview rect during drag
  // ---------------------------------------------------------------------------

  /// Returns the visual preview [Rect] to display during a drag.
  ///
  /// The preview rect is derived from [_blockRect] adjusted by the current
  /// [_dragDelta] according to which handle is being dragged.
  Rect _previewRect(Rect base) {
    final handle = _dragHandlePosition;
    if (handle == null || _dragDelta == Offset.zero) return base;

    double left = base.left;
    double top = base.top;
    double right = base.right;
    double bottom = base.bottom;

    switch (handle) {
      case ResizeHandlePosition.topLeft:
        left += _dragDelta.dx;
        top += _dragDelta.dy;
      case ResizeHandlePosition.topCenter:
        top += _dragDelta.dy;
      case ResizeHandlePosition.topRight:
        right += _dragDelta.dx;
        top += _dragDelta.dy;
      case ResizeHandlePosition.middleLeft:
        left += _dragDelta.dx;
      case ResizeHandlePosition.middleRight:
        right += _dragDelta.dx;
      case ResizeHandlePosition.bottomLeft:
        left += _dragDelta.dx;
        bottom += _dragDelta.dy;
      case ResizeHandlePosition.bottomCenter:
        bottom += _dragDelta.dy;
      case ResizeHandlePosition.bottomRight:
        right += _dragDelta.dx;
        bottom += _dragDelta.dy;
    }

    // Clamp so rect doesn't invert.
    final minRight = left + widget.minWidth;
    final minBottom = top + widget.minHeight;
    return Rect.fromLTRB(
      left,
      top,
      right < minRight ? minRight : right,
      bottom < minBottom ? minBottom : bottom,
    );
  }

  // ---------------------------------------------------------------------------
  // Mouse cursor mapping
  // ---------------------------------------------------------------------------

  MouseCursor _cursorForHandle(ResizeHandlePosition pos) {
    return switch (pos) {
      ResizeHandlePosition.topLeft => SystemMouseCursors.resizeUpLeftDownRight,
      ResizeHandlePosition.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
      ResizeHandlePosition.topRight => SystemMouseCursors.resizeUpRightDownLeft,
      ResizeHandlePosition.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
      ResizeHandlePosition.topCenter => SystemMouseCursors.resizeUpDown,
      ResizeHandlePosition.bottomCenter => SystemMouseCursors.resizeUpDown,
      ResizeHandlePosition.middleLeft => SystemMouseCursors.resizeLeftRight,
      ResizeHandlePosition.middleRight => SystemMouseCursors.resizeLeftRight,
    };
  }

  // ---------------------------------------------------------------------------
  // Handle widget builder
  // ---------------------------------------------------------------------------

  Widget _buildHandle(ResizeHandlePosition pos, Rect blockRect) {
    final half = widget.handleSize / 2.0;

    final double cx;
    final double cy;

    switch (pos) {
      case ResizeHandlePosition.topLeft:
        cx = blockRect.left;
        cy = blockRect.top;
      case ResizeHandlePosition.topCenter:
        cx = blockRect.center.dx;
        cy = blockRect.top;
      case ResizeHandlePosition.topRight:
        cx = blockRect.right;
        cy = blockRect.top;
      case ResizeHandlePosition.middleLeft:
        cx = blockRect.left;
        cy = blockRect.center.dy;
      case ResizeHandlePosition.middleRight:
        cx = blockRect.right;
        cy = blockRect.center.dy;
      case ResizeHandlePosition.bottomLeft:
        cx = blockRect.left;
        cy = blockRect.bottom;
      case ResizeHandlePosition.bottomCenter:
        cx = blockRect.center.dx;
        cy = blockRect.bottom;
      case ResizeHandlePosition.bottomRight:
        cx = blockRect.right;
        cy = blockRect.bottom;
    }

    return Positioned(
      left: cx - half,
      top: cy - half,
      width: widget.handleSize,
      height: widget.handleSize,
      child: MouseRegion(
        cursor: _cursorForHandle(pos),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _onPointerDown(pos, e),
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.handleColor,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowHandles()) {
      return const SizedBox.shrink();
    }

    final blockRect = _previewRect(_blockRect!);

    return Stack(
      children: [
        // Selection border
        Positioned(
          left: blockRect.left,
          top: blockRect.top,
          width: blockRect.width,
          height: blockRect.height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: widget.borderColor),
              ),
            ),
          ),
        ),
        // Eight resize handles
        for (final pos in ResizeHandlePosition.values) _buildHandle(pos, blockRect),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// createResizeRequest
// ---------------------------------------------------------------------------

/// Creates a [ReplaceNodeRequest] that updates [node]'s [width] and/or
/// [height].
///
/// Type-dispatches [node.copyWith] for [ImageNode], [CodeBlockNode],
/// [BlockquoteNode], [HorizontalRuleNode], and [TableNode]. Returns `null`
/// for node types that do not support block layout (e.g. [ParagraphNode]).
///
/// A `null` [width] or [height] argument preserves the node's current value
/// for that dimension. Pass a non-null value to update it.
///
/// Example:
/// ```dart
/// final node = document.nodeById('img-1')!;
/// final req = createResizeRequest(node, 320.0, null);
/// if (req != null) editor.submit(req);
/// ```
EditRequest? createResizeRequest(
  DocumentNode node,
  double? width,
  double? height,
) {
  if (node is ImageNode) {
    return ReplaceNodeRequest(
      nodeId: node.id,
      newNode: node.copyWith(
        width: width ?? node.width,
        height: height ?? node.height,
      ),
    );
  }
  if (node is CodeBlockNode) {
    return ReplaceNodeRequest(
      nodeId: node.id,
      newNode: node.copyWith(
        width: width ?? node.width,
        height: height ?? node.height,
      ),
    );
  }
  if (node is BlockquoteNode) {
    return ReplaceNodeRequest(
      nodeId: node.id,
      newNode: node.copyWith(
        width: width ?? node.width,
        height: height ?? node.height,
      ),
    );
  }
  if (node is HorizontalRuleNode) {
    return ReplaceNodeRequest(
      nodeId: node.id,
      newNode: node.copyWith(
        width: width ?? node.width,
        height: height ?? node.height,
      ),
    );
  }
  if (node is TableNode) {
    return ReplaceNodeRequest(
      nodeId: node.id,
      newNode: node.copyWith(
        width: width ?? node.width,
        height: height ?? node.height,
      ),
    );
  }
  return null;
}
