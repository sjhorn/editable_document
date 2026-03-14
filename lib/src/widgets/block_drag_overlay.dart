/// Block drag overlay for the editable_document package.
///
/// When a fully-selected non-text block is dragged, [BlockDragOverlay] shows
/// a semi-transparent ghost rectangle following the pointer and moves the
/// controller's caret to the nearest document position so the user sees
/// where the block will be inserted on drop.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../model/document.dart';
import '../model/document_editing_controller.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/image_node.dart';
import '_image_provider_stub.dart' if (dart.library.io) '_image_provider_io.dart';
import 'document_layout.dart';

// ---------------------------------------------------------------------------
// BlockMoveCallback
// ---------------------------------------------------------------------------

/// Callback invoked when the user drops a dragged block at a new position.
///
/// [nodeId] identifies the block that was dragged. [position] is the
/// [DocumentPosition] nearest to the pointer at the time of drop. The
/// caller is responsible for submitting the appropriate [EditRequest] (e.g.
/// [MoveNodeToPositionRequest] or [MoveNodeRequest]).
typedef BlockMoveCallback = void Function(String nodeId, DocumentPosition position);

// ---------------------------------------------------------------------------
// BlockDragOverlay
// ---------------------------------------------------------------------------

/// A visual overlay widget that shows a drag ghost and caret indicator while
/// a fully-selected non-text block is being dragged to a new position.
///
/// [BlockDragOverlay] is a pure visual widget — it does not capture pointer
/// events itself. Instead, it exposes methods via
/// [GlobalKey<BlockDragOverlayState>] that the hosting gesture handler (e.g.
/// [DocumentMouseInteractor]) calls to coordinate the drag lifecycle:
///
/// - [BlockDragOverlayState.startBlockDrag] — begins a drag for [nodeId].
/// - [BlockDragOverlayState.updateBlockDrag] — updates the caret position
///   and ghost location from the current pointer offset (in layout-local
///   coordinates).
/// - [BlockDragOverlayState.endBlockDrag] — finalises the drop. Returns the
///   [DocumentPosition] at the drop site, or `null` if no valid position was
///   established. Also calls [onBlockMoved] when a valid position exists.
/// - [BlockDragOverlayState.cancelBlockDrag] — cancels the drag without
///   moving the block.
///
/// The static [isDragging] flag mirrors [BlockResizeHandles.isDragging] and
/// is checked by [DocumentMouseInteractor] to suppress normal selection-drag
/// behaviour while a block drag is in progress.
///
/// ## Example
///
/// ```dart
/// final overlayKey = GlobalKey<BlockDragOverlayState>();
///
/// Stack(
///   children: [
///     DocumentLayout(key: layoutKey, ...),
///     Positioned.fill(
///       child: BlockDragOverlay(
///         key: overlayKey,
///         controller: myController,
///         layoutKey: layoutKey,
///         document: myDocument,
///         onBlockMoved: (nodeId, position) {
///           editor.submit(MoveNodeToPositionRequest(nodeId: nodeId, position: position));
///         },
///       ),
///     ),
///   ],
/// )
/// ```
class BlockDragOverlay extends StatefulWidget {
  /// Whether a block drag is currently in progress.
  ///
  /// [DocumentMouseInteractor] checks this flag in its pointer-down and
  /// pointer-move handlers to skip normal selection-drag logic while a
  /// block drag is active, mirroring the [BlockResizeHandles.isDragging]
  /// pattern.
  static bool isDragging = false;

  /// Creates a [BlockDragOverlay].
  ///
  /// [controller], [layoutKey], and [document] are required.
  /// [onBlockMoved] is called on a successful drop; if `null` no move
  /// callback is fired but the ghost still renders.
  const BlockDragOverlay({
    super.key,
    required this.controller,
    required this.layoutKey,
    required this.document,
    this.onBlockMoved,
    this.indicatorColor = const Color(0xFF2196F3),
    this.indicatorHeight = 2.0,
  });

  /// The document editing controller.
  ///
  /// [BlockDragOverlay] listens to this controller and rebuilds whenever
  /// the selection changes.
  final DocumentEditingController controller;

  /// A [GlobalKey] for the [DocumentLayoutState] that renders the document.
  ///
  /// Used to obtain the layout's [RenderBox] for coordinate-space conversion
  /// and to call [DocumentLayoutState.documentPositionNearestToOffset] during
  /// drag.
  final GlobalKey<DocumentLayoutState> layoutKey;

  /// The document whose nodes are inspected to determine drag eligibility.
  final Document document;

  /// Called when the user drops a dragged block at a new position.
  ///
  /// Receives the [nodeId] of the dragged block and the [DocumentPosition]
  /// nearest to the pointer at drop time. When `null`, no callback is fired.
  final BlockMoveCallback? onBlockMoved;

  /// The colour of the ghost border and caret indicator.
  ///
  /// Defaults to `Color(0xFF2196F3)` (Material Blue 500).
  final Color indicatorColor;

  /// The height of the caret indicator line in logical pixels.
  ///
  /// Defaults to `2.0`.
  final double indicatorHeight;

  @override
  State<BlockDragOverlay> createState() => BlockDragOverlayState();

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
      ObjectFlagProperty<BlockMoveCallback?>.has('onBlockMoved', onBlockMoved),
    );
    properties.add(ColorProperty('indicatorColor', indicatorColor));
    properties.add(DoubleProperty('indicatorHeight', indicatorHeight, defaultValue: 2.0));
  }
}

// ---------------------------------------------------------------------------
// BlockDragOverlayState
// ---------------------------------------------------------------------------

/// State for [BlockDragOverlay].
///
/// Exposes the [startBlockDrag], [updateBlockDrag], [endBlockDrag], and
/// [cancelBlockDrag] methods for the hosting gesture handler to call.
class BlockDragOverlayState extends State<BlockDragOverlay> {
  // ---------------------------------------------------------------------------
  // Drag state
  // ---------------------------------------------------------------------------

  /// The id of the block currently being dragged, or `null` when idle.
  String? _dragNodeId;

  /// The [DocumentPosition] nearest to the current pointer position, or `null`.
  DocumentPosition? _dropPosition;

  /// The saved selection before the drag started, restored on cancel.
  DocumentSelection? _savedSelection;

  /// The current ghost centre position in layout-local coordinates.
  Offset? _ghostCenter;

  /// Whether a post-frame geometry update is already scheduled.
  bool _geometryUpdateScheduled = false;

  /// The actual size of the block being dragged, captured at drag start.
  ///
  /// `null` when no drag is in progress or when the render object was not
  /// available at the time [startBlockDrag] was called.
  Size? _blockSize;

  /// The offset from the dragged block's top-left corner to the pointer
  /// position at drag start, in layout-local coordinates.
  ///
  /// Used to keep the grab point under the pointer as the ghost moves.
  /// `null` when no [pointerOffset] was supplied to [startBlockDrag].
  Offset? _grabOffset;

  /// The image URL of the dragged block, when it is an [ImageNode].
  ///
  /// When non-null, the drag ghost renders the actual image content instead
  /// of a plain coloured rectangle.
  String? _imageUrl;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(BlockDragOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Controller listener
  // ---------------------------------------------------------------------------

  void _onControllerChanged() {
    _scheduleGeometryUpdate();
  }

  // ---------------------------------------------------------------------------
  // Geometry scheduling
  // ---------------------------------------------------------------------------

  /// Schedules a post-frame callback to refresh overlay state.
  ///
  /// Coalesces multiple calls within a single frame to a single callback,
  /// mirroring the [BlockResizeHandles] pattern.
  void _scheduleGeometryUpdate() {
    if (_geometryUpdateScheduled) return;
    _geometryUpdateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _geometryUpdateScheduled = false;
      if (mounted) setState(() {});
    });
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// The size of the block currently being dragged, or `null` when idle.
  ///
  /// Captured from the rendered [RenderDocumentBlock] at the time
  /// [startBlockDrag] is called. Useful for tests and for external widgets
  /// that need to know the ghost dimensions.
  // ignore: diagnostic_describe_all_properties
  Size? get blockSize => _blockSize;

  /// The offset from the dragged block's top-left corner to the pointer
  /// at drag start, in layout-local coordinates.
  ///
  /// `null` when no [pointerOffset] was passed to [startBlockDrag] or when
  /// no drag is in progress.
  // ignore: diagnostic_describe_all_properties
  Offset? get grabOffset => _grabOffset;

  /// Begins a block drag for the block identified by [nodeId].
  ///
  /// Sets [BlockDragOverlay.isDragging] to `true` and records [nodeId] as the
  /// block being dragged. Saves the current selection to restore on cancel.
  /// The ghost is not shown until [updateBlockDrag] is called.
  ///
  /// When [pointerOffset] is supplied (in the layout's local coordinate space),
  /// the actual rendered size of the block is queried via
  /// [DocumentLayoutState.componentForNode] and stored as [blockSize]. The
  /// offset from the block's top-left corner to [pointerOffset] is stored as
  /// [grabOffset] so the ghost tracks the grab point rather than centering on
  /// the pointer.
  void startBlockDrag(String nodeId, {Offset? pointerOffset}) {
    BlockDragOverlay.isDragging = true;

    Size? blockSize;
    Offset? grabOffset;

    final renderBlock = widget.layoutKey.currentState?.componentForNode(nodeId);
    final layoutRO = widget.layoutKey.currentState?.renderObject;
    if (renderBlock != null && renderBlock.hasSize && layoutRO != null) {
      blockSize = renderBlock.size;
      if (pointerOffset != null) {
        // Compute pointer position relative to the block's top-left in
        // layout-local coordinates.
        final blockTopLeft = renderBlock.localToGlobal(Offset.zero, ancestor: layoutRO);
        grabOffset = pointerOffset - blockTopLeft;
      }
    }

    // Check if the dragged node is an image so the ghost can show the actual
    // image content instead of a plain rectangle.
    final node = widget.document.nodeById(nodeId);
    final imageUrl = node is ImageNode ? node.imageUrl : null;

    setState(() {
      _dragNodeId = nodeId;
      _dropPosition = null;
      _ghostCenter = null;
      _savedSelection = widget.controller.selection;
      _blockSize = blockSize;
      _grabOffset = grabOffset;
      _imageUrl = imageUrl;
    });
  }

  /// Updates the drop position and ghost location from a pointer offset in
  /// the layout's local coordinate space.
  ///
  /// Queries [DocumentLayoutState.documentPositionNearestToOffset] to obtain
  /// the nearest [DocumentPosition], then sets the controller's selection to
  /// a collapsed caret at that position so the user sees where the block will
  /// land. The ghost rectangle follows [layoutLocalOffset].
  ///
  /// Call this on every pointer-move event during a drag.
  void updateBlockDrag(Offset layoutLocalOffset) {
    final nodeId = _dragNodeId;
    if (nodeId == null) return;

    final layoutState = widget.layoutKey.currentState;
    final newPos = layoutState?.documentPositionNearestToOffset(layoutLocalOffset);

    if (newPos != null) {
      // Move the controller caret to show the insertion point.
      widget.controller.setSelection(DocumentSelection.collapsed(position: newPos));
    }

    if (newPos != _dropPosition || layoutLocalOffset != _ghostCenter) {
      setState(() {
        _dropPosition = newPos;
        _ghostCenter = layoutLocalOffset;
      });
    }
  }

  /// Finalises the drop and returns the [DocumentPosition] at the drop site.
  ///
  /// When a valid [DocumentPosition] was established via [updateBlockDrag],
  /// this method:
  /// 1. Calls [BlockDragOverlay.onBlockMoved] with the dragged [nodeId] and
  ///    [DocumentPosition].
  /// 2. Resets drag state.
  /// 3. Sets [BlockDragOverlay.isDragging] to `false`.
  ///
  /// Returns the [DocumentPosition] that was active at drop time, or `null`
  /// if no position had been established (i.e. [updateBlockDrag] was never
  /// called or the layout returned no position).
  DocumentPosition? endBlockDrag() {
    final pos = _dropPosition;
    final nodeId = _dragNodeId;

    _resetDragState();

    if (pos != null && nodeId != null) {
      widget.onBlockMoved?.call(nodeId, pos);
    }

    return pos;
  }

  /// Cancels the current drag without moving the block.
  ///
  /// Restores the selection to the state before [startBlockDrag] was called,
  /// resets drag state, and sets [BlockDragOverlay.isDragging] to `false`.
  /// [BlockDragOverlay.onBlockMoved] is **not** called.
  void cancelBlockDrag() {
    final saved = _savedSelection;
    _resetDragState();
    // Restore the pre-drag selection.
    widget.controller.setSelection(saved);
  }

  /// Injects a [DocumentPosition] directly, used only by tests to simulate
  /// the result of [updateBlockDrag] without requiring a real render layout.
  ///
  /// This method is exposed for testing purposes only and should not be called
  /// from production code.
  // ignore: use_setters_to_change_properties
  void injectDropPositionForTest(DocumentPosition position) {
    setState(() => _dropPosition = position);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _resetDragState() {
    BlockDragOverlay.isDragging = false;
    setState(() {
      _dragNodeId = null;
      _dropPosition = null;
      _ghostCenter = null;
      _savedSelection = null;
      _blockSize = null;
      _grabOffset = null;
      _imageUrl = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDraggingNow = _dragNodeId != null;

    if (!isDraggingNow) {
      return const SizedBox.shrink();
    }

    // Compute ghost rectangle if we have a pointer position.
    final ghostCenter = _ghostCenter;

    // Use the actual block size when available; fall back to a small placeholder
    // only when the render object was not yet available at drag start.
    final ghostSize = _blockSize ?? const Size(120.0, 40.0);

    // Convert ghost pointer position from layout-local to overlay-local
    // coordinates, then apply the grab offset so the pointer stays at the
    // same relative point on the ghost as it was when the drag started.
    double? ghostLeft;
    double? ghostTop;

    if (ghostCenter != null) {
      final layoutBox = widget.layoutKey.currentContext?.findRenderObject() as RenderBox?;
      final overlayBox = context.findRenderObject() as RenderBox?;
      double cx = ghostCenter.dx;
      double cy = ghostCenter.dy;
      if (layoutBox != null && overlayBox != null) {
        final globalPos = layoutBox.localToGlobal(ghostCenter);
        final localPos = overlayBox.globalToLocal(globalPos);
        cx = localPos.dx;
        cy = localPos.dy;
      }
      // Offset so the grab point tracks the pointer; fall back to centering.
      ghostLeft = cx - (_grabOffset?.dx ?? ghostSize.width / 2);
      ghostTop = cy - (_grabOffset?.dy ?? ghostSize.height / 2);
    }

    return Stack(
      children: [
        // Drag ghost — at the block's real size, following the pointer.
        if (ghostLeft != null && ghostTop != null)
          Positioned(
            left: ghostLeft,
            top: ghostTop,
            width: ghostSize.width,
            height: ghostSize.height,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.5,
                child: _buildGhostContent(),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the ghost content widget.
  ///
  /// When the dragged block is an [ImageNode], shows the actual image via
  /// Flutter's image cache. Otherwise falls back to a coloured rectangle.
  Widget _buildGhostContent() {
    final url = _imageUrl;
    if (url != null) {
      final ImageProvider? provider;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        provider = NetworkImage(url);
      } else {
        provider = createFileImageProvider(url);
      }
      if (provider != null) {
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: widget.indicatorColor, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image(
              image: provider,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _defaultGhostBox(),
            ),
          ),
        );
      }
    }
    return _defaultGhostBox();
  }

  /// The fallback ghost: a translucent blue rectangle with a border.
  Widget _defaultGhostBox() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x332196F3),
        border: Border.all(color: widget.indicatorColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('dragNodeId', _dragNodeId, defaultValue: null));
    properties.add(DiagnosticsProperty<DocumentPosition?>('dropPosition', _dropPosition));
    properties.add(DiagnosticsProperty<Size?>('blockSize', _blockSize, defaultValue: null));
    properties.add(DiagnosticsProperty<Offset?>('grabOffset', _grabOffset, defaultValue: null));
  }
}
