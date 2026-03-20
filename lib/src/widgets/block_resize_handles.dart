/// Block selection border with resize handles for the editable_document package.
///
/// When a single [HasBlockLayout] block is fully selected,
/// [BlockResizeHandles] draws a selection border and eight drag handles
/// (four corners + four edge midpoints) that allow the user to resize
/// the block by dragging. For stretch-aligned blocks, dragging a handle
/// automatically switches the alignment to [BlockAlignment.start].
library;

import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../model/block_alignment.dart';
import '../model/block_layout.dart';
import '../model/document.dart';
import '../model/document_editing_controller.dart';
import '../model/document_node.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/edit_request.dart';
import '../model/image_node.dart';
import '../model/table_node.dart';
import '../model/node_position.dart';
import '../model/text_node.dart';
import '../rendering/render_block_resize_border.dart';
import 'document_layout.dart';
import 'document_viewport_scope.dart';

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
/// fully-selected [HasBlockLayout] block node.
///
/// [BlockResizeHandles] is an overlay widget: it does not occupy space in the
/// document flow. It watches [controller] for selection changes and shows
/// handles only when:
///
/// * [onResize] is non-null (handles are disabled without a resize callback),
/// * a single block node is fully selected (base at upstream, extent at
///   downstream),
/// * and the node implements [HasBlockLayout].
///
/// Handles are shown for all [BlockAlignment] values, including
/// [BlockAlignment.stretch]. When the user drags a handle on a stretch-aligned
/// block, [createResizeRequest] automatically switches the alignment to
/// [BlockAlignment.start] so the explicit dimensions take visual effect.
///
/// During drag the [onResize] callback fires on every pointer-move for
/// real-time feedback, and once more on pointer-up for the final value.
/// The caller is responsible for submitting the corresponding [EditRequest]
/// (e.g. via [createResizeRequest]).
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
    this.onResetImageSize,
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

  /// Called during and at the end of a resize drag.
  ///
  /// Fires on every pointer-move for real-time feedback (the document model
  /// updates as the user drags) and once more on pointer-up for the final
  /// value. Receives the [nodeId] of the resized block along with the new
  /// [width] and [height] in logical pixels. A `null` dimension means
  /// "preserve the current value".
  ///
  /// When `null`, no handles are drawn.
  final BlockResizeCallback? onResize;

  /// Called when the user taps the "1:1" reset button on a selected
  /// [ImageNode].
  ///
  /// Receives the [nodeId] of the image whose size should be reset to its
  /// intrinsic dimensions (i.e. [ImageNode.width] and [ImageNode.height]
  /// set to `null`). The button only appears when the selected node is an
  /// [ImageNode] and this callback is non-null.
  final ValueChanged<String>? onResetImageSize;

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
      ObjectFlagProperty<ValueChanged<String>?>.has(
        'onResetImageSize',
        onResetImageSize,
      ),
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

  /// Accumulated drag delta since the last baseline resync.
  Offset _dragDelta = Offset.zero;

  /// The size of the block at the last baseline resync (initially set at drag
  /// start, then updated each time [_blockRect] catches up to the model).
  Size? _dragStartSize;

  /// The node id captured at drag start, so it survives selection changes.
  String? _dragNodeId;

  /// Whether the active drag should maintain the block's aspect ratio.
  ///
  /// Captured from [ImageNode.lockAspect] at drag start. Defaults to `true`
  /// for non-[ImageNode] nodes (aspect-ratio-preserving is the safe default).
  bool _lockAspect = true;

  /// The pointer id currently being tracked for a drag, or `null`.
  int? _activePointer;

  /// Whether a post-frame geometry update is already scheduled.
  bool _geometryUpdateScheduled = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depend on DocumentViewportScope so we re-query block geometry
    // when the viewport width changes (e.g. window resize).
    DocumentViewportScope.maybeOf(context);
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
    _scheduleGeometryUpdate();
  }

  // ---------------------------------------------------------------------------
  // Geometry query
  // ---------------------------------------------------------------------------

  /// Schedules a post-frame callback to query the render block geometry.
  ///
  /// This must be deferred to after layout so that [RenderDocumentBlock.size]
  /// and [RenderDocumentBlock.localToGlobal] are valid.
  ///
  /// Multiple calls within a single frame are coalesced — only one callback
  /// is registered per frame.
  void _scheduleGeometryUpdate() {
    if (_geometryUpdateScheduled) return;
    _geometryUpdateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _geometryUpdateScheduled = false;
      if (!mounted) return;
      _updateBlockRect();
    });
  }

  void _updateBlockRect() {
    // During drag, use the captured node id so geometry tracking survives
    // selection changes made by the mouse interactor.
    final nodeId = _activePointer != null ? _dragNodeId : _selectedNodeId();
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
      setState(() {
        _blockRect = newRect;
        // During drag, resync the baseline so that _previewRect and
        // _computeNewSize stay correct after the model catches up.
        if (_activePointer != null) {
          _dragStartSize = newRect.size;
          _dragDelta = Offset.zero;
        }
      });
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

  /// Returns `true` when the selection border should be shown.
  ///
  /// The border is shown for any fully-selected [HasBlockLayout] node,
  /// regardless of alignment. Resize handles are conditionally added on
  /// top by [_shouldShowResizeHandles].
  bool _shouldShowBorder() {
    // During an active resize drag, keep showing even though the selection
    // may have been changed by the mouse interactor.
    if (_activePointer != null) return _blockRect != null;

    final nodeId = _selectedNodeId();
    if (nodeId == null) return false;

    final node = widget.document.nodeById(nodeId);
    if (node == null) return false;
    if (node is! HasBlockLayout) return false;
    // Tables use TableDividerResizeHandles for column/row resizing.
    if (node is TableNode) return false;

    return _blockRect != null;
  }

  /// Returns `true` when resize handles should be shown on top of the border.
  ///
  /// Requires [onResize] to be non-null and the selected node to implement
  /// [HasBlockLayout]. Handles are shown for all alignment modes, including
  /// stretch — dragging a stretch block's handle will auto-switch alignment
  /// to [BlockAlignment.start] via [createResizeRequest].
  ///
  /// [TableNode]s are excluded because they use [TableDividerResizeHandles]
  /// for column and row resizing instead.
  bool _shouldShowResizeHandles() {
    if (widget.onResize == null) return false;
    if (_activePointer != null) return true;

    final nodeId = _selectedNodeId();
    if (nodeId == null) return false;
    final node = widget.document.nodeById(nodeId);
    if (node == null || node is! HasBlockLayout) return false;
    if (node is TableNode) return false;
    return true;
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
    final node = _dragNodeId != null ? widget.document.nodeById(_dragNodeId!) : null;
    _lockAspect = node is ImageNode ? node.lockAspect : true;
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
    _emitResize();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _finishDrag();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _finishDrag();
  }

  /// Fires the [BlockResizeHandles.onResize] callback with the current
  /// drag dimensions. Called on every pointer-move for real-time feedback
  /// and once more on drag end for the final value.
  void _emitResize() {
    final handle = _dragHandlePosition;
    final startSize = _dragStartSize;
    final nodeId = _dragNodeId;
    if (handle == null || startSize == null || nodeId == null) return;

    final result = _computeNewSize(handle, startSize, _dragDelta, lockAspect: _lockAspect);
    final newWidth = result.$1 != null ? result.$1!.clamp(widget.minWidth, double.infinity) : null;
    final newHeight =
        result.$2 != null ? result.$2!.clamp(widget.minHeight, double.infinity) : null;
    widget.onResize?.call(nodeId, newWidth, newHeight);
  }

  void _finishDrag() {
    _emitResize();

    // Re-select the node so it remains visually selected after the drag.
    final nodeId = _dragNodeId;
    if (nodeId != null) {
      _reselectBlock(nodeId);
    }

    _activePointer = null;
    _dragNodeId = null;
    _lockAspect = true;
    BlockResizeHandles.isDragging = false;
    setState(() {
      _dragHandlePosition = null;
      _dragDelta = Offset.zero;
      _dragStartSize = null;
    });
  }

  /// Re-selects [nodeId] with a full-node selection so that the block
  /// remains visually selected after a resize drag completes.
  ///
  /// For binary nodes ([ImageNode], [HorizontalRuleNode]) this sets an
  /// upstream → downstream [BinaryNodePosition] selection.  For text-based
  /// block nodes ([CodeBlockNode], [BlockquoteNode]) it selects from offset 0
  /// to the end of the text.
  ///
  /// Mirrors the [BlockDragOverlay._selectBlock] pattern — same principle,
  /// applied at drag-resize completion rather than block-move drop.
  void _reselectBlock(String nodeId) {
    final node = widget.document.nodeById(nodeId);
    if (node == null) return;

    final DocumentSelection selection;
    if (node is TextNode) {
      selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: nodeId,
          nodePosition: const TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: nodeId,
          nodePosition: TextNodePosition(offset: node.text.text.length),
        ),
      );
    } else {
      selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: nodeId,
          nodePosition: const BinaryNodePosition.upstream(),
        ),
        extent: DocumentPosition(
          nodeId: nodeId,
          nodePosition: const BinaryNodePosition.downstream(),
        ),
      );
    }
    widget.controller.setSelection(selection);
  }

  /// Computes the new (width, height) from [original] size and [delta].
  ///
  /// Returns a record of `(newWidth, newHeight)`. A `null` component means
  /// "do not change this dimension".
  ///
  /// When [lockAspect] is `true`:
  /// - Corner handles: the dominant axis drives, the other adjusts proportionally
  ///   (existing behaviour).
  /// - Edge handles: the dragged dimension drives, the orthogonal dimension
  ///   adjusts proportionally (new behaviour).
  ///
  /// When [lockAspect] is `false`:
  /// - Corner handles: width and height resize independently.
  /// - Edge handles: only the dragged dimension changes (existing behaviour).
  (double?, double?) _computeNewSize(
    ResizeHandlePosition handle,
    Size original,
    Offset delta, {
    bool lockAspect = true,
  }) {
    double? newWidth;
    double? newHeight;

    final aspect = original.width / original.height;

    switch (handle) {
      case ResizeHandlePosition.topLeft:
      case ResizeHandlePosition.topRight:
      case ResizeHandlePosition.bottomLeft:
      case ResizeHandlePosition.bottomRight:
        final dxSign = switch (handle) {
          ResizeHandlePosition.topLeft || ResizeHandlePosition.bottomLeft => -1.0,
          _ => 1.0,
        };
        final dySign = switch (handle) {
          ResizeHandlePosition.topLeft || ResizeHandlePosition.topRight => -1.0,
          _ => 1.0,
        };
        final rawW = original.width + delta.dx * dxSign;
        final rawH = original.height + delta.dy * dySign;
        if (lockAspect) {
          // Aspect-ratio-preserving: dominant axis drives both dimensions.
          if ((delta.dx.abs()) >= (delta.dy.abs())) {
            newWidth = rawW;
            newHeight = rawW / aspect;
          } else {
            newHeight = rawH;
            newWidth = rawH * aspect;
          }
        } else {
          // Free resize: each axis is independent.
          newWidth = rawW;
          newHeight = rawH;
        }
      case ResizeHandlePosition.topCenter:
        newHeight = original.height - delta.dy;
        if (lockAspect) {
          newWidth = newHeight * aspect;
        }
      case ResizeHandlePosition.middleLeft:
        newWidth = original.width - delta.dx;
        if (lockAspect) {
          newHeight = newWidth / aspect;
        }
      case ResizeHandlePosition.middleRight:
        newWidth = original.width + delta.dx;
        if (lockAspect) {
          newHeight = newWidth / aspect;
        }
      case ResizeHandlePosition.bottomCenter:
        newHeight = original.height + delta.dy;
        if (lockAspect) {
          newWidth = newHeight * aspect;
        }
    }

    return (newWidth, newHeight);
  }

  // ---------------------------------------------------------------------------
  // Preview rect during drag
  // ---------------------------------------------------------------------------

  /// Returns the visual preview [Rect] to display during a drag.
  ///
  /// Uses [_computeNewSize] so the preview matches the actual resize
  /// dimensions (including aspect-ratio locking for corner handles).
  Rect _previewRect(Rect base) {
    final handle = _dragHandlePosition;
    final startSize = _dragStartSize;
    if (handle == null || startSize == null || _dragDelta == Offset.zero) {
      return base;
    }

    final (rawW, rawH) = _computeNewSize(handle, startSize, _dragDelta, lockAspect: _lockAspect);
    final newW = rawW?.clamp(widget.minWidth, double.infinity) ?? base.width;
    final newH = rawH?.clamp(widget.minHeight, double.infinity) ?? base.height;

    // Anchor the preview to the correct edge/corner.
    final bool anchorRight = handle == ResizeHandlePosition.topLeft ||
        handle == ResizeHandlePosition.middleLeft ||
        handle == ResizeHandlePosition.bottomLeft;
    final bool anchorBottom = handle == ResizeHandlePosition.topLeft ||
        handle == ResizeHandlePosition.topCenter ||
        handle == ResizeHandlePosition.topRight;

    final left = anchorRight ? base.right - newW : base.left;
    final top = anchorBottom ? base.bottom - newH : base.top;

    return Rect.fromLTWH(left, top, newW, newH);
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

  /// The touch target size around each handle for easier grabbing.
  static const double _handleHitPadding = 8.0;

  Widget _buildHandle(ResizeHandlePosition pos, Rect blockRect) {
    final hitSize = widget.handleSize + _handleHitPadding * 2;
    final hitHalf = hitSize / 2.0;

    double cx;
    double cy;

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

    // Clamp the hit-target centre so the Positioned widget never gets negative
    // coordinates or extends beyond the overlay bounds. Without clamping, a
    // block at the edge of the document layout (e.g. top: 0, left: 0 for a
    // stretch-aligned image) would produce negative left/top values that are
    // silently clipped by the parent Stack.
    final layoutSize = widget.layoutKey.currentState?.renderObject?.size;
    if (layoutSize != null) {
      cx = cx.clamp(hitHalf, max(hitHalf, layoutSize.width - hitHalf));
      cy = cy.clamp(hitHalf, max(hitHalf, layoutSize.height - hitHalf));
    }

    return Positioned(
      left: cx - hitHalf,
      top: cy - hitHalf,
      width: hitSize,
      height: hitSize,
      child: MouseRegion(
        cursor: _cursorForHandle(pos),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _onPointerDown(pos, e),
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          // Transparent hit target — visuals are painted by
          // _BlockResizeBorderRenderWidget in the Stack beneath.
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reset button
  // ---------------------------------------------------------------------------

  /// Height of the "1:1" reset button.
  static const double _resetButtonHeight = 22.0;

  /// Vertical gap between the reset button and the block border.
  static const double _resetButtonGap = 4.0;

  Widget _buildResetButton(Rect blockRect, String nodeId) {
    const buttonWidth = 46.0;

    // Clamp the reset button's top position so it stays within the overlay
    // bounds. When the selected block is at the very top of the document
    // layout, the unclamped value would be negative (above the Stack), making
    // the button invisible. Clamp to [0, layoutSize.height - buttonHeight].
    final rawTop = blockRect.top - _resetButtonHeight - _resetButtonGap;
    final layoutSize = widget.layoutKey.currentState?.renderObject?.size;
    final clampedTop =
        layoutSize != null ? rawTop.clamp(0.0, layoutSize.height - _resetButtonHeight) : rawTop;

    return Positioned(
      left: blockRect.center.dx - buttonWidth / 2,
      top: clampedTop,
      width: buttonWidth,
      height: _resetButtonHeight,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onResetImageSize?.call(nodeId),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.borderColor,
              borderRadius: BorderRadius.circular(3.0),
            ),
            child: const Center(
              child: Text(
                'Reset',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
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
    if (!_shouldShowBorder()) {
      return const SizedBox.shrink();
    }

    final blockRect = _previewRect(_blockRect!);
    final showHandles = _shouldShowResizeHandles();

    // Check if the selected node is an ImageNode with custom dimensions
    // for the reset button. Only show when the image has been resized
    // (width or height is non-null), no resize drag is in progress, and
    // the explicit dimensions do not already match the decoded image's
    // intrinsic size (within 1.0 pixel tolerance).
    final nodeId = _activePointer != null ? _dragNodeId : _selectedNodeId();
    final node = nodeId != null ? widget.document.nodeById(nodeId) : null;

    final component =
        nodeId != null ? widget.layoutKey.currentState?.componentForNode(nodeId) : null;
    final intrinsicSize = component?.intrinsicContentSize;
    final imageNode = node is ImageNode ? node : null;
    final atIntrinsicSize = intrinsicSize != null &&
        imageNode != null &&
        imageNode.width != null &&
        imageNode.height != null &&
        (imageNode.width! - intrinsicSize.width).abs() < 1.0 &&
        (imageNode.height! - intrinsicSize.height).abs() < 1.0;

    final showReset = widget.onResetImageSize != null &&
        node is ImageNode &&
        (node.width != null || node.height != null) &&
        !atIntrinsicSize &&
        _activePointer == null;

    return Stack(
      children: [
        // Paint-time border + handles — no one-frame lag during viewport resize.
        Positioned.fill(
          child: _BlockResizeBorderRenderWidget(
            layoutKey: widget.layoutKey,
            selectedNodeId: nodeId,
            borderColor: widget.borderColor,
            handleColor: widget.handleColor,
            handleSize: widget.handleSize,
            showHandles: showHandles,
            dragPreviewRect: _activePointer != null ? _previewRect(_blockRect!) : null,
          ),
        ),
        // Transparent hit-target Listeners for drag interaction.
        if (showHandles)
          for (final pos in ResizeHandlePosition.values) _buildHandle(pos, blockRect),
        // "Reset" button — shown for ImageNode with custom dimensions only.
        if (showReset) _buildResetButton(blockRect, nodeId!),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _BlockResizeBorderRenderWidget
// ---------------------------------------------------------------------------

/// A [LeafRenderObjectWidget] that creates and updates a
/// [RenderBlockResizeBorder].
///
/// Geometry is resolved at paint time by [RenderBlockResizeBorder] querying
/// the [RenderDocumentLayout] obtained from [layoutKey]. This eliminates the
/// one-frame lag that would occur when the block's position changes due to a
/// viewport resize (e.g. window drag), because the render object reads fresh
/// layout information every paint rather than relying on pre-computed widget
/// state.
///
/// During an active resize drag, [dragPreviewRect] is supplied so the border
/// tracks the pointer in real time without waiting for a layout pass.
class _BlockResizeBorderRenderWidget extends LeafRenderObjectWidget {
  const _BlockResizeBorderRenderWidget({
    required this.layoutKey,
    required this.selectedNodeId,
    required this.borderColor,
    required this.handleColor,
    required this.handleSize,
    required this.showHandles,
    this.dragPreviewRect,
  });

  final GlobalKey<DocumentLayoutState> layoutKey;
  final String? selectedNodeId;
  final Color borderColor;
  final Color handleColor;
  final double handleSize;
  final bool showHandles;
  final Rect? dragPreviewRect;

  @override
  RenderBlockResizeBorder createRenderObject(BuildContext context) {
    return RenderBlockResizeBorder(
      documentLayout: layoutKey.currentState?.renderObject,
      selectedNodeId: selectedNodeId,
      borderColor: borderColor,
      handleColor: handleColor,
      handleSize: handleSize,
      showHandles: showHandles,
      dragPreviewRect: dragPreviewRect,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderBlockResizeBorder renderObject) {
    renderObject
      ..documentLayout = layoutKey.currentState?.renderObject
      ..selectedNodeId = selectedNodeId
      ..borderColor = borderColor
      ..handleColor = handleColor
      ..handleSize = handleSize
      ..showHandles = showHandles
      ..dragPreviewRect = dragPreviewRect;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<GlobalKey<DocumentLayoutState>>('layoutKey', layoutKey),
    );
    properties.add(StringProperty('selectedNodeId', selectedNodeId, defaultValue: null));
    properties.add(ColorProperty('borderColor', borderColor));
    properties.add(ColorProperty('handleColor', handleColor));
    properties.add(DoubleProperty('handleSize', handleSize));
    properties.add(DiagnosticsProperty<bool>('showHandles', showHandles));
    properties.add(
      DiagnosticsProperty<Rect?>('dragPreviewRect', dragPreviewRect, defaultValue: null),
    );
  }
}

// ---------------------------------------------------------------------------
// createResizeRequest
// ---------------------------------------------------------------------------

/// Creates a [ReplaceNodeRequest] that updates [node]'s [width] and/or
/// [height].
///
/// Delegates to [HasBlockLayout.copyWithSize] so no type-dispatch is needed.
/// Returns `null` for node types that do not implement [HasBlockLayout]
/// (e.g. [ParagraphNode]).
///
/// A `null` [width] or [height] argument preserves the node's current value
/// for that dimension. Pass a non-null value to update it.
///
/// When the node's current [HasBlockLayout.alignment] is
/// [BlockAlignment.stretch], this helper automatically passes
/// [BlockAlignment.start] to [HasBlockLayout.copyWithSize] so that the
/// explicit dimensions take visual effect. Non-stretch alignments are
/// preserved unchanged.
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
  if (node is! HasBlockLayout) return null;
  final blockNode = node as HasBlockLayout;
  // When resizing a stretch block, switch to start alignment so the
  // explicit dimensions take visual effect.
  final alignment = blockNode.alignment == BlockAlignment.stretch
      ? BlockAlignment.start
      : null; // null preserves current alignment
  return ReplaceNodeRequest(
    nodeId: node.id,
    newNode: blockNode.copyWithSize(
      width: width,
      height: height,
      alignment: alignment,
    ),
  );
}

// ---------------------------------------------------------------------------
// createResetImageSizeRequest
// ---------------------------------------------------------------------------

/// Creates a [ReplaceNodeRequest] that resets an [ImageNode]'s [width] and
/// [height] to `null`, restoring the image to its intrinsic dimensions.
///
/// Returns `null` if [node] is not an [ImageNode].
///
/// Because [ImageNode.copyWith] cannot set dimensions to `null` (it uses
/// `??` semantics), this helper constructs a fresh [ImageNode] with all
/// fields preserved except [width] and [height].
///
/// Example:
/// ```dart
/// final node = document.nodeById('img-1')!;
/// final req = createResetImageSizeRequest(node);
/// if (req != null) editor.submit(req);
/// ```
EditRequest? createResetImageSizeRequest(DocumentNode node) {
  if (node is! ImageNode) return null;
  return ReplaceNodeRequest(
    nodeId: node.id,
    newNode: ImageNode(
      id: node.id,
      imageUrl: node.imageUrl,
      altText: node.altText,
      // width and height intentionally null → intrinsic size.
      alignment: node.alignment,
      textWrap: node.textWrap,
      lockAspect: node.lockAspect,
      metadata: node.metadata,
    ),
  );
}
