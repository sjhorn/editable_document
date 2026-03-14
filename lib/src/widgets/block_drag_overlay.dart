/// Block drag overlay for the editable_document package.
///
/// When a fully-selected non-text block is dragged, [BlockDragOverlay] shows
/// a horizontal insertion indicator at the nearest inter-block gap and fires
/// [onBlockMoved] on drop.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../model/document.dart';
import '../model/document_editing_controller.dart';
import '../rendering/render_document_layout.dart';
import 'document_layout.dart';

// ---------------------------------------------------------------------------
// BlockMoveCallback
// ---------------------------------------------------------------------------

/// Callback invoked when the user drops a dragged block at a new position.
///
/// [nodeId] identifies the block that was dragged. [newIndex] is the
/// zero-based post-removal insertion index in the document.
typedef BlockMoveCallback = void Function(String nodeId, int newIndex);

// ---------------------------------------------------------------------------
// BlockDragOverlay
// ---------------------------------------------------------------------------

/// A visual overlay widget that shows a horizontal insertion indicator while
/// a fully-selected non-text block is being dragged to a new position.
///
/// [BlockDragOverlay] is a pure visual widget — it does not capture pointer
/// events itself. Instead, it exposes methods via
/// [GlobalKey<BlockDragOverlayState>] that the hosting gesture handler (e.g.
/// [DocumentMouseInteractor]) calls to coordinate the drag lifecycle:
///
/// - [BlockDragOverlayState.startBlockDrag] — begins a drag for [nodeId].
/// - [BlockDragOverlayState.updateBlockDrag] — updates the insertion gap
///   indicator position from the current pointer offset (in layout-local
///   coordinates).
/// - [BlockDragOverlayState.endBlockDrag] — finalises the drop. Returns the
///   [BlockInsertionGap] at the drop site, or `null` if no valid gap was
///   established. Also calls [onBlockMoved] when a valid gap exists.
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
///         onBlockMoved: (nodeId, newIndex) {
///           editor.submit(MoveNodeRequest(nodeId: nodeId, newIndex: newIndex));
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
  /// callback is fired but the indicator still renders.
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
  /// Used to query [RenderDocumentLayout.getInsertionGapAtOffset] during drag
  /// and to obtain the layout's [RenderBox] for coordinate-space conversion.
  final GlobalKey<DocumentLayoutState> layoutKey;

  /// The document whose nodes are inspected to determine drag eligibility.
  final Document document;

  /// Called when the user drops a dragged block at a new position.
  ///
  /// Receives the [nodeId] of the dragged block and the [newIndex] (post-
  /// removal insertion index). When `null`, no callback is fired.
  final BlockMoveCallback? onBlockMoved;

  /// The colour of the horizontal insertion indicator line.
  ///
  /// Defaults to `Color(0xFF2196F3)` (Material Blue 500).
  final Color indicatorColor;

  /// The height of the horizontal insertion indicator line in logical pixels.
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

  /// The current insertion gap computed from the pointer position, or `null`.
  BlockInsertionGap? _insertionGap;

  /// Whether a post-frame geometry update is already scheduled.
  bool _geometryUpdateScheduled = false;

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

  /// Begins a block drag for the block identified by [nodeId].
  ///
  /// Sets [BlockDragOverlay.isDragging] to `true` and records [nodeId] as the
  /// block being dragged. The insertion indicator is not shown until
  /// [updateBlockDrag] is called with a pointer position.
  void startBlockDrag(String nodeId) {
    BlockDragOverlay.isDragging = true;
    setState(() {
      _dragNodeId = nodeId;
      _insertionGap = null;
    });
  }

  /// Updates the insertion gap indicator position from a pointer offset in
  /// the layout's local coordinate space.
  ///
  /// Queries [RenderDocumentLayout.getInsertionGapAtOffset] and rebuilds the
  /// overlay if the nearest gap changes. Call this on every pointer-move event
  /// during a drag.
  void updateBlockDrag(Offset layoutLocalOffset) {
    final nodeId = _dragNodeId;
    if (nodeId == null) return;

    final renderLayout = widget.layoutKey.currentState?.renderObject;
    final newGap = renderLayout?.getInsertionGapAtOffset(layoutLocalOffset, nodeId);
    if (newGap != _insertionGap) {
      setState(() => _insertionGap = newGap);
    }
  }

  /// Finalises the drop and returns the [BlockInsertionGap] at the drop site.
  ///
  /// When a valid [BlockInsertionGap] was established via [updateBlockDrag],
  /// this method:
  /// 1. Calls [BlockDragOverlay.onBlockMoved] with the dragged [nodeId] and
  ///    [BlockInsertionGap.index].
  /// 2. Resets drag state.
  /// 3. Sets [BlockDragOverlay.isDragging] to `false`.
  ///
  /// Returns the [BlockInsertionGap] that was active at drop time, or `null`
  /// if no gap had been established (i.e. [updateBlockDrag] was never called
  /// or the layout returned no gap).
  BlockInsertionGap? endBlockDrag() {
    final gap = _insertionGap;
    final nodeId = _dragNodeId;

    _resetDragState();

    if (gap != null && nodeId != null) {
      widget.onBlockMoved?.call(nodeId, gap.index);
    }

    return gap;
  }

  /// Cancels the current drag without moving the block.
  ///
  /// Resets drag state and sets [BlockDragOverlay.isDragging] to `false`.
  /// [BlockDragOverlay.onBlockMoved] is **not** called.
  void cancelBlockDrag() {
    _resetDragState();
  }

  /// Injects a [BlockInsertionGap] directly, used only by tests to simulate
  /// the result of [updateBlockDrag] without requiring a real render layout.
  ///
  /// This method is exposed for testing purposes only and should not be called
  /// from production code.
  // ignore: use_setters_to_change_properties
  void injectInsertionGapForTest(BlockInsertionGap gap) {
    setState(() => _insertionGap = gap);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _resetDragState() {
    BlockDragOverlay.isDragging = false;
    setState(() {
      _dragNodeId = null;
      _insertionGap = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final gap = _insertionGap;
    final isDraggingNow = _dragNodeId != null;

    if (!isDraggingNow || gap == null) {
      return const SizedBox.shrink();
    }

    // Obtain the layout's render box to compute the full width for the indicator.
    final layoutBox = widget.layoutKey.currentContext?.findRenderObject() as RenderBox?;
    final indicatorWidth = layoutBox?.size.width ?? MediaQuery.sizeOf(context).width;

    // Convert the gap's lineY from layout-local coordinates to overlay-local
    // coordinates. Both share the same ancestor so we use globalToLocal with
    // the overlay's render box.
    final overlayBox = context.findRenderObject() as RenderBox?;
    double lineY = gap.lineY;
    if (layoutBox != null && overlayBox != null) {
      final globalLineY = layoutBox.localToGlobal(Offset(0, gap.lineY));
      lineY = overlayBox.globalToLocal(globalLineY).dy;
    }

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: lineY - widget.indicatorHeight / 2,
          width: indicatorWidth,
          height: widget.indicatorHeight,
          child: ColoredBox(color: widget.indicatorColor),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('dragNodeId', _dragNodeId, defaultValue: null));
    properties.add(DiagnosticsProperty<BlockInsertionGap?>('insertionGap', _insertionGap));
  }
}
