/// Desktop mouse gesture handler for the editable_document package.
///
/// [DocumentMouseInteractor] wraps its [child] in a [MouseRegion] (for
/// cursor management), a [Listener] (for raw pointer/mouse drag events),
/// and a [GestureDetector] (for tap/double-tap recognition) and translates
/// pointer events into [DocumentSelection] updates on the supplied
/// [DocumentEditingController].
///
/// Supported gestures:
/// - **Tap** — collapses the selection to the tapped position.
/// - **Drag (mouse or touch)** — extends a selection from the drag-start
///   base to the current pointer position.
/// - **Double-tap** — selects the word under the pointer (simple whitespace
///   boundary detection).
/// - **Triple-tap** — selects the entire block (node) under the pointer.
/// - **Shift+tap** — extends the existing selection's [base] to the tapped
///   position; falls back to a collapsed selection when no prior selection
///   exists.
/// - **Secondary tap (right-click)** — optionally invokes
///   [DocumentMouseInteractor.onSecondaryTapDown] with the global tap
///   position, after requesting focus and optionally collapsing the caret.
///
/// ## Timing note
///
/// When [GestureDetector.onDoubleTapDown] is registered, the
/// [TapGestureRecognizer] fires [onTapDown] only after the double-tap
/// window (~300 ms) expires, not immediately on pointer-down. Tests that
/// verify single-tap behaviour must therefore call
/// `pump(Duration(milliseconds: 500))` after sending a tap so the arena
/// resolves before the assertion.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kPrimaryMouseButton, PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../model/block_layout.dart';
import '../../model/document.dart';
import '../../model/document_editing_controller.dart';
import '../../model/document_position.dart';
import '../../model/document_selection.dart';
import '../../model/node_position.dart';
import '../block_drag_overlay.dart';
import '../block_resize_handles.dart';
import '../table_divider_resize_handles.dart';
import '../toolbar/table_context_toolbar.dart';
import '../../model/table_node.dart';
import '../../model/text_node.dart';
import '../document_layout.dart';

// ---------------------------------------------------------------------------
// DocumentMouseInteractor
// ---------------------------------------------------------------------------

/// A [StatefulWidget] that handles desktop mouse gestures for a document
/// editor.
///
/// Wrap your [DocumentLayout] (or whatever [child] holds the document
/// rendering) with this widget to get tap, drag, double-tap, triple-tap, and
/// shift+tap selection behaviour driven by mouse events.
///
/// ```dart
/// final layoutKey = GlobalKey<DocumentLayoutState>();
///
/// DocumentMouseInteractor(
///   controller: controller,
///   layoutKey: layoutKey,
///   document: document,
///   child: DocumentLayout(
///     key: layoutKey,
///     document: document,
///     controller: controller,
///     componentBuilders: defaultComponentBuilders,
///   ),
/// )
/// ```
///
/// Set [enabled] to `false` to suppress all gesture handling while keeping
/// the widget in the tree (useful for read-only modes).
class DocumentMouseInteractor extends StatefulWidget {
  /// Creates a [DocumentMouseInteractor].
  ///
  /// [controller] is updated whenever a gesture produces a selection change.
  /// [layoutKey] must point to the [DocumentLayoutState] that performs
  /// document-position hit-testing.
  /// [document] is used for word/block boundary detection during
  /// double-tap and triple-tap.
  /// [child] is the document content widget to wrap.
  const DocumentMouseInteractor({
    super.key,
    required this.controller,
    required this.layoutKey,
    required this.document,
    required this.child,
    this.focusNode,
    this.enabled = true,
    this.cursor = SystemMouseCursors.text,
    this.onSecondaryTapDown,
    this.blockDragOverlayKey,
  });

  /// The controller whose [DocumentEditingController.selection] is updated
  /// by mouse gestures.
  final DocumentEditingController controller;

  /// A [GlobalKey] pointing to the [DocumentLayoutState] that provides
  /// geometry queries such as [DocumentLayoutState.documentPositionNearestToOffset].
  final GlobalKey<DocumentLayoutState> layoutKey;

  /// The document being edited; used for word and block boundary detection.
  final Document document;

  /// The document content widget to wrap.
  final Widget child;

  /// An optional [FocusNode] to request focus on when the user taps.
  ///
  /// When non-null, [FocusNode.requestFocus] is called on every primary
  /// pointer-down event so that clicking inside the document steals focus
  /// from other focusable widgets (e.g. [DocumentField]).
  final FocusNode? focusNode;

  /// Whether mouse gestures are active.
  ///
  /// When `false` all tap/drag callbacks are no-ops and the mouse cursor
  /// falls back to [SystemMouseCursors.basic].  Defaults to `true`.
  final bool enabled;

  /// The mouse cursor to display when the pointer is inside the interactor
  /// and [enabled] is `true`.
  ///
  /// Defaults to [SystemMouseCursors.text].
  final MouseCursor cursor;

  /// Optional callback invoked when a secondary (right-click) tap is detected.
  ///
  /// The callback receives the global position of the tap, which can be used
  /// to show a context menu. Before the callback is invoked:
  /// 1. Focus is requested (if [focusNode] is non-null).
  /// 2. If the tap position is outside the current selection, the caret is
  ///    moved to the tapped position (matching [TextField] behaviour).
  ///
  /// When `null`, secondary taps are ignored.
  final ValueChanged<Offset>? onSecondaryTapDown;

  /// An optional [GlobalKey] for [BlockDragOverlayState].
  ///
  /// When non-null, the interactor detects when the user drags a
  /// fully-selected binary block and delegates to the overlay via
  /// [BlockDragOverlayState.startBlockDrag], [BlockDragOverlayState.updateBlockDrag],
  /// and [BlockDragOverlayState.endBlockDrag].
  ///
  /// The interactor also checks [BlockDragOverlay.isDragging] alongside
  /// [BlockResizeHandles.isDragging] in its pointer-down and pointer-move
  /// handlers to suppress normal selection-drag behaviour while a block drag
  /// is in progress.
  final GlobalKey<BlockDragOverlayState>? blockDragOverlayKey;

  @override
  State<DocumentMouseInteractor> createState() => DocumentMouseInteractorState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DocumentEditingController>('controller', controller));
    properties.add(DiagnosticsProperty<GlobalKey<DocumentLayoutState>>('layoutKey', layoutKey));
    properties.add(DiagnosticsProperty<Document>('document', document));
    properties.add(DiagnosticsProperty<FocusNode?>('focusNode', focusNode, defaultValue: null));
    properties.add(FlagProperty('enabled', value: enabled, ifTrue: 'enabled', ifFalse: 'disabled'));
    properties.add(DiagnosticsProperty<MouseCursor>('cursor', cursor));
    properties.add(
      ObjectFlagProperty<ValueChanged<Offset>?>.has('onSecondaryTapDown', onSecondaryTapDown),
    );
    properties.add(
      DiagnosticsProperty<GlobalKey<BlockDragOverlayState>?>(
        'blockDragOverlayKey',
        blockDragOverlayKey,
        defaultValue: null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DocumentMouseInteractorState
// ---------------------------------------------------------------------------

/// State for [DocumentMouseInteractor].
///
/// Tracks drag base position, double-tap timing, and triple-tap detection.
class DocumentMouseInteractorState extends State<DocumentMouseInteractor> {
  // -------------------------------------------------------------------------
  // Keys
  // -------------------------------------------------------------------------

  /// A key on the [Listener] widget so its [RenderBox] can be used for
  /// coordinate-space conversion in `_positionForOffset`.
  final _listenerKey = GlobalKey();

  // -------------------------------------------------------------------------
  // Drag state
  // -------------------------------------------------------------------------

  /// The document position recorded when a primary-button press begins,
  /// used as the base of a drag selection.
  DocumentPosition? _dragBasePosition;

  /// Whether the pointer is currently pressed (primary button held down).
  bool _isDragging = false;

  // -------------------------------------------------------------------------
  // Block drag state
  // -------------------------------------------------------------------------

  /// The id of the binary block node that may be dragged, or `null`.
  ///
  /// Set on pointer-down when a fully-selected binary block is detected.
  /// Cleared on pointer-up or pointer-cancel.
  String? _blockDragNodeId;

  /// The pointer position at which a potential block drag began.
  Offset? _blockDragStartOffset;

  /// Whether a block drag (as opposed to a normal selection drag) is active.
  bool _isBlockDragging = false;

  // -------------------------------------------------------------------------
  // Multi-tap tracking
  // -------------------------------------------------------------------------

  /// Whether a double-tap was recently recorded and a triple-tap is pending.
  ///
  /// Set to `true` inside `_onDoubleTapDown` and automatically cleared after
  /// 300 ms by a [Timer].  Because [flutter_test] fakes [Timer], this flag
  /// works correctly in both production and test environments.
  bool _pendingTripleTap = false;

  /// Position of the most-recent double-tap, used to gate triple-tap
  /// distance check.
  Offset? _lastDoubleTapPosition;

  /// Timer that clears `_pendingTripleTap` after the triple-tap window.
  Timer? _tripleTapTimer;

  // -------------------------------------------------------------------------
  // Private helpers — layout key accessor
  // -------------------------------------------------------------------------

  DocumentLayoutState? get _layout => widget.layoutKey.currentState;

  // -------------------------------------------------------------------------
  // Private helpers — word boundary detection
  // -------------------------------------------------------------------------

  /// Returns whether [char] should be treated as a word boundary.
  bool _isWordBreak(String char) => char == ' ' || char == '\n' || char == '\t';

  /// Finds the [start, end) character range of the word that contains
  /// [offset] within [text].
  ///
  /// Uses simple whitespace boundary detection (no ICU / locale awareness).
  /// If [offset] falls on whitespace, the returned range may be zero-length.
  (int start, int end) _wordBoundaryAt(String text, int offset) {
    offset = offset.clamp(0, text.length);
    var start = offset;
    while (start > 0 && !_isWordBreak(text[start - 1])) {
      start--;
    }
    var end = offset;
    while (end < text.length && !_isWordBreak(text[end])) {
      end++;
    }
    return (start, end);
  }

  // -------------------------------------------------------------------------
  // Private helpers — convert local offset to document position
  // -------------------------------------------------------------------------

  /// Converts a gesture-local [offset] (in the coordinate space of the
  /// [Listener] wrapping the [DocumentLayout]) to a [DocumentPosition].
  ///
  /// Uses [DocumentLayoutState.documentPositionNearestToOffset] so that taps
  /// outside content are clamped to the nearest valid position.
  ///
  /// Returns `null` when the layout is not yet attached.
  DocumentPosition? _positionForOffset(Offset offset) {
    final layout = _layout;
    if (layout == null) return null;
    final layoutBox = widget.layoutKey.currentContext?.findRenderObject() as RenderBox?;
    if (layoutBox == null) return null;
    final listenerBox = _listenerKey.currentContext?.findRenderObject() as RenderBox?;
    if (listenerBox == null) {
      // Fallback: coordinates are likely the same.
      return layout.documentPositionNearestToOffset(offset);
    }
    // Convert from the listener's local coordinate space to global, then to
    // the layout's local coordinate space, to handle any intermediate transforms.
    final globalOffset = listenerBox.localToGlobal(offset);
    final layoutLocal = layoutBox.globalToLocal(globalOffset);
    return layout.documentPositionNearestToOffset(layoutLocal);
  }

  // -------------------------------------------------------------------------
  // Private helpers — keyboard modifier state
  // -------------------------------------------------------------------------

  bool get _isShiftPressed =>
      HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shift) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void dispose() {
    _tripleTapTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Triple-tap detection
  // -------------------------------------------------------------------------

  /// Returns `true` if [position] is close enough to the recorded double-tap
  /// position and `_pendingTripleTap` is still set (i.e. the triple-tap
  /// window has not expired).
  bool _isTripleTap(Offset position) {
    if (!_pendingTripleTap) return false;
    final lastPos = _lastDoubleTapPosition;
    if (lastPos == null) return false;
    return (position - lastPos).distance <= 20.0;
  }

  // -------------------------------------------------------------------------
  // Raw pointer event handlers (Listener) — handles mouse drag
  // -------------------------------------------------------------------------

  /// Handles raw pointer-down events.
  ///
  /// Records the drag base position for primary-button presses. Also detects
  /// whether the press lands on a fully-selected binary block that can be
  /// dragged to a new position via [BlockDragOverlay].
  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    if (event.buttons & kPrimaryMouseButton == 0 && event.kind != PointerDeviceKind.touch) {
      // Non-primary-button mouse press — ignore.
      return;
    }
    // Skip drag-selection when a block resize handle, block drag, or
    // table toolbar is active.
    if (BlockResizeHandles.isDragging) return;
    if (TableDividerResizeHandles.isDragging) return;
    if (BlockDragOverlay.isDragging) return;
    if (TableContextToolbar.isInteracting) return;

    // Check whether the pointer is on a fully-selected draggable block node
    // that could be dragged to a new position.
    if (widget.blockDragOverlayKey != null) {
      // Always record the pointer-down position so that late detection in
      // _onPointerMove (via _tryDetectBlockDragCandidate) has the correct
      // drag start offset, even when the selection isn't set yet due to the
      // GestureDetector double-tap window delay.
      _blockDragStartOffset = event.localPosition;

      final selection = widget.controller.selection;
      if (selection != null &&
          !selection.isCollapsed &&
          selection.base.nodeId == selection.extent.nodeId) {
        final nodeId = selection.base.nodeId;
        final node = widget.document.nodeById(nodeId);
        if (node is HasBlockLayout && (node as HasBlockLayout).isDraggable) {
          if (_isFullySelected(node, selection)) {
            _blockDragNodeId = nodeId;
          }
        }
      }
    }

    _dragBasePosition = _positionForOffset(event.localPosition);
    _isDragging = true;
  }

  /// Handles raw pointer-move events.
  ///
  /// When a potential block drag was detected in [_onPointerDown] and the
  /// pointer has moved past the drag threshold (4 logical pixels), the move
  /// event is routed to [BlockDragOverlayState] instead of the normal
  /// selection-drag logic.
  ///
  /// Otherwise, extends the selection from the base to the current position.
  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.enabled) return;
    if (!_isDragging) return;
    if (BlockResizeHandles.isDragging) return;
    if (TableDividerResizeHandles.isDragging) return;

    // Route active block drags before the isDragging guard — the interactor
    // itself sets BlockDragOverlay.isDragging, so the guard must not block
    // the interactor's own drag updates.
    if (_isBlockDragging) {
      _updateBlockDrag(event);
      return;
    }

    // Another component owns the block drag — skip selection logic.
    if (BlockDragOverlay.isDragging) return;

    // Late detection: if _onPointerDown ran before the selection was set
    // (e.g. the GestureDetector's tap handler set the selection between
    // pointer-down and this pointer-move), try to detect a block drag
    // candidate now.
    if (_blockDragNodeId == null && widget.blockDragOverlayKey != null) {
      _tryDetectBlockDragCandidate(event.localPosition);
    }

    // Check for block drag threshold.
    if (_blockDragNodeId != null) {
      final startOffset = _blockDragStartOffset;
      if (startOffset != null) {
        final delta = event.localPosition - startOffset;
        if (delta.distance > 4.0) {
          // Crossed threshold — begin a block drag.
          _isBlockDragging = true;
          BlockDragOverlay.isDragging = true;
          // Compute the pointer position in layout-local coordinates so the
          // overlay can capture the block size and grab offset.
          final layoutBox = widget.layoutKey.currentContext?.findRenderObject() as RenderBox?;
          final listenerBox = _listenerKey.currentContext?.findRenderObject() as RenderBox?;
          Offset? pointerOffset;
          if (layoutBox != null && listenerBox != null) {
            final globalStart = listenerBox.localToGlobal(startOffset);
            pointerOffset = layoutBox.globalToLocal(globalStart);
          }
          widget.blockDragOverlayKey?.currentState?.startBlockDrag(
            _blockDragNodeId!,
            pointerOffset: pointerOffset,
          );
          _updateBlockDrag(event);
        }
      }
      // Don't fall through to selection-drag while a block drag is pending
      // — that would change the selection and deselect the image.
      return;
    }

    final base = _dragBasePosition;
    if (base == null) return;
    final extent = _positionForOffset(event.localPosition);
    if (extent == null) return;
    widget.controller.setSelection(DocumentSelection(base: base, extent: extent));
  }

  /// Converts listener-local coordinates to layout-local and forwards to
  /// the [BlockDragOverlayState].
  void _updateBlockDrag(PointerMoveEvent event) {
    final layoutBox = widget.layoutKey.currentContext?.findRenderObject() as RenderBox?;
    final listenerBox = _listenerKey.currentContext?.findRenderObject() as RenderBox?;
    if (layoutBox != null && listenerBox != null) {
      final globalOffset = listenerBox.localToGlobal(event.localPosition);
      final layoutLocal = layoutBox.globalToLocal(globalOffset);
      widget.blockDragOverlayKey?.currentState?.updateBlockDrag(layoutLocal);
    }
  }

  /// Returns `true` when [node] is fully selected in [selection].
  ///
  /// For binary nodes ([HasBlockLayout] but not [TextNode]), "fully selected"
  /// means upstream → downstream. For text-based [HasBlockLayout] nodes (e.g.
  /// [CodeBlockNode], [BlockquoteNode]), "fully selected" means offset 0 →
  /// text.length.
  bool _isFullySelected(dynamic node, DocumentSelection selection) {
    final basePos = selection.base.nodePosition;
    final extentPos = selection.extent.nodePosition;
    if (node is TextNode) {
      // Text-based HasBlockLayout: fully selected = 0 to text.length.
      if (basePos is! TextNodePosition || extentPos is! TextNodePosition) {
        return false;
      }
      return basePos.offset == 0 && extentPos.offset == node.text.text.length;
    }
    // Binary node: fully selected = upstream to downstream.
    if (basePos is! BinaryNodePosition || extentPos is! BinaryNodePosition) {
      return false;
    }
    return basePos.type == BinaryNodePositionType.upstream &&
        extentPos.type == BinaryNodePositionType.downstream;
  }

  /// Checks whether the current selection has become a fully-selected draggable
  /// block since [_onPointerDown] ran.
  ///
  /// This handles the timing gap where [_onTapDown] or [_onDoubleTapDown]
  /// sets the selection after the pointer-down event (due to the double-tap
  /// window delay).
  void _tryDetectBlockDragCandidate(Offset currentPosition) {
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) return;
    if (selection.base.nodeId != selection.extent.nodeId) return;

    final nodeId = selection.base.nodeId;
    final node = widget.document.nodeById(nodeId);
    if (node is! HasBlockLayout || !(node as HasBlockLayout).isDraggable) return;
    if (!_isFullySelected(node, selection)) return;

    // Verify the pointer is actually over the selected block.
    final pos = _positionForOffset(currentPosition);
    if (pos == null || pos.nodeId != nodeId) return;

    _blockDragNodeId = nodeId;
    // Use the original pointer-down position if we recorded one, otherwise
    // use the current position as the drag start.
    _blockDragStartOffset ??= currentPosition;
  }

  /// Handles raw pointer-up events.
  ///
  /// When a block drag is active, delegates to [BlockDragOverlayState.endBlockDrag]
  /// and clears block drag state. Otherwise clears the normal drag state.
  void _onPointerUp(PointerUpEvent event) {
    if (_isBlockDragging) {
      widget.blockDragOverlayKey?.currentState?.endBlockDrag();
      _isBlockDragging = false;
      _blockDragNodeId = null;
      _blockDragStartOffset = null;
      BlockDragOverlay.isDragging = false;
      _isDragging = false;
      return;
    }
    _blockDragNodeId = null;
    _blockDragStartOffset = null;
    _isDragging = false;
  }

  /// Handles raw pointer-cancel events.
  ///
  /// When a block drag is active, delegates to
  /// [BlockDragOverlayState.cancelBlockDrag]. Otherwise clears the normal
  /// drag state.
  void _onPointerCancel(PointerCancelEvent event) {
    if (_isBlockDragging) {
      widget.blockDragOverlayKey?.currentState?.cancelBlockDrag();
      _isBlockDragging = false;
      _blockDragNodeId = null;
      _blockDragStartOffset = null;
      BlockDragOverlay.isDragging = false;
    }
    _blockDragNodeId = null;
    _blockDragStartOffset = null;
    _isDragging = false;
  }

  // -------------------------------------------------------------------------
  // GestureDetector callbacks — tap and double-tap
  // -------------------------------------------------------------------------

  /// Handles a single-tap down event.
  ///
  /// When a triple-tap is pending (i.e. a double-tap was recently detected and
  /// the triple-tap window has not yet expired), this tap is treated as the
  /// third in the sequence and triggers full-block selection instead.
  void _onTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    if (TableContextToolbar.isInteracting) return;

    // Request focus so clicking the document steals focus from other widgets.
    widget.focusNode?.requestFocus();

    // Triple-tap: the 3rd tap arrives as a plain single-tap because the
    // DoubleTapGestureRecognizer already consumed taps 1 and 2 and has since
    // reset.  If the triple-tap window is still open, promote to block select.
    if (_isTripleTap(details.localPosition)) {
      _selectBlock(details.localPosition);
      _pendingTripleTap = false;
      _tripleTapTimer?.cancel();
      _tripleTapTimer = null;
      _lastDoubleTapPosition = null;
      return;
    }

    final pos = _positionForOffset(details.localPosition);
    if (pos == null) return;

    if (_isShiftPressed && widget.controller.selection != null) {
      // Shift+tap — keep existing base, move extent to new position.
      widget.controller.setSelection(
        DocumentSelection(
          base: widget.controller.selection!.base,
          extent: pos,
        ),
      );
    } else {
      // Plain tap — for non-text nodes (images, HRs), select the whole block
      // so the highlight is visible and delete/backspace work immediately.
      final node = widget.document.nodeById(pos.nodeId);
      if (node is! TextNode && node is! TableNode) {
        widget.controller.setSelection(
          DocumentSelection(
            base: DocumentPosition(
              nodeId: pos.nodeId,
              nodePosition: const BinaryNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: pos.nodeId,
              nodePosition: const BinaryNodePosition.downstream(),
            ),
          ),
        );
      } else {
        widget.controller.setSelection(DocumentSelection.collapsed(position: pos));
      }
    }
  }

  /// Handles a double-tap down event (word selection).
  ///
  /// If a third tap follows quickly (within 300 ms and 20 logical pixels),
  /// it is treated as a triple-tap that selects the entire block.
  void _onDoubleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;

    widget.focusNode?.requestFocus();

    if (_isTripleTap(details.localPosition)) {
      // This is actually the third tap — do block selection.
      _selectBlock(details.localPosition);
      // Reset tracking so subsequent taps start fresh.
      _pendingTripleTap = false;
      _tripleTapTimer?.cancel();
      _tripleTapTimer = null;
      _lastDoubleTapPosition = null;
      return;
    }

    // Record for potential triple-tap detection.  The window is 600 ms so
    // that the flag is still alive when the third tap's onTapDown fires after
    // the double-tap recognizer's own 300 ms countdown expires.
    _pendingTripleTap = true;
    _lastDoubleTapPosition = details.localPosition;
    _tripleTapTimer?.cancel();
    _tripleTapTimer = Timer(const Duration(milliseconds: 600), () {
      _pendingTripleTap = false;
      _lastDoubleTapPosition = null;
      _tripleTapTimer = null;
    });

    final pos = _positionForOffset(details.localPosition);
    if (pos == null) return;

    final node = widget.document.nodeById(pos.nodeId);
    if (node is TextNode) {
      final text = node.text.text;
      final nodePos = pos.nodePosition;
      final charOffset = nodePos is TextNodePosition ? nodePos.offset : 0;
      final (start, end) = _wordBoundaryAt(text, charOffset);
      widget.controller.setSelection(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: pos.nodeId,
            nodePosition: TextNodePosition(offset: start),
          ),
          extent: DocumentPosition(
            nodeId: pos.nodeId,
            nodePosition: TextNodePosition(offset: end),
          ),
        ),
      );
    } else if (node is TableNode) {
      // Table cell — word selection within the tapped cell.
      final cellPos = pos.nodePosition;
      if (cellPos is TableCellPosition) {
        final cellText = node.cellAt(cellPos.row, cellPos.col).text;
        final (start, end) = _wordBoundaryAt(cellText, cellPos.offset);
        widget.controller.setSelection(
          DocumentSelection(
            base: DocumentPosition(
              nodeId: pos.nodeId,
              nodePosition: TableCellPosition(row: cellPos.row, col: cellPos.col, offset: start),
            ),
            extent: DocumentPosition(
              nodeId: pos.nodeId,
              nodePosition: TableCellPosition(row: cellPos.row, col: cellPos.col, offset: end),
            ),
          ),
        );
      }
    } else {
      // Non-text node — select the whole thing.
      widget.controller.setSelection(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: pos.nodeId,
            nodePosition: const BinaryNodePosition.upstream(),
          ),
          extent: DocumentPosition(
            nodeId: pos.nodeId,
            nodePosition: const BinaryNodePosition.downstream(),
          ),
        ),
      );
    }
  }

  /// Handles secondary (right-click) tap down events.
  ///
  /// 1. Requests focus.
  /// 2. If the tap position is outside the current expanded selection,
  ///    collapses the caret to the tapped position.
  /// 3. Invokes [DocumentMouseInteractor.onSecondaryTapDown] with the
  ///    global position.
  void _onSecondaryTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    if (widget.onSecondaryTapDown == null) return;

    // Request focus.
    widget.focusNode?.requestFocus();

    final tapPos = _positionForOffset(details.localPosition);
    if (tapPos == null) return;

    // If tap is outside current selection, collapse to tapped position.
    final selection = widget.controller.selection;
    if (selection == null ||
        selection.isCollapsed ||
        !_isPositionInsideSelection(tapPos, selection)) {
      widget.controller.setSelection(DocumentSelection.collapsed(position: tapPos));
    }

    widget.onSecondaryTapDown!(details.globalPosition);
  }

  /// Returns `true` when [position] falls within the normalized [selection].
  ///
  /// For an expanded selection, checks whether [position] is between the
  /// normalized base and extent in document order. For a collapsed selection,
  /// always returns `false`.
  bool _isPositionInsideSelection(DocumentPosition position, DocumentSelection selection) {
    if (selection.isCollapsed) return false;

    final normalised = selection.normalize(widget.document);

    final baseIndex = widget.document.getNodeIndexById(normalised.base.nodeId);
    final extentIndex = widget.document.getNodeIndexById(normalised.extent.nodeId);
    final posIndex = widget.document.getNodeIndexById(position.nodeId);

    if (posIndex < 0 || baseIndex < 0 || extentIndex < 0) return false;

    if (posIndex < baseIndex || posIndex > extentIndex) return false;

    // Position is in a middle node — definitely inside.
    if (posIndex > baseIndex && posIndex < extentIndex) return true;

    // Position is in the same node as base and/or extent.
    final nodePos = position.nodePosition;

    if (posIndex == baseIndex && posIndex == extentIndex) {
      // Single-node selection.
      if (nodePos is TextNodePosition) {
        final baseOffset = (normalised.base.nodePosition as TextNodePosition).offset;
        final extentOffset = (normalised.extent.nodePosition as TextNodePosition).offset;
        return nodePos.offset >= baseOffset && nodePos.offset <= extentOffset;
      }
      // Binary node — if in the same node, it's inside.
      return true;
    }

    if (posIndex == baseIndex) {
      // At the first node — check if at or after the base offset.
      if (nodePos is TextNodePosition && normalised.base.nodePosition is TextNodePosition) {
        return nodePos.offset >= (normalised.base.nodePosition as TextNodePosition).offset;
      }
      return true;
    }

    if (posIndex == extentIndex) {
      // At the last node — check if at or before the extent offset.
      if (nodePos is TextNodePosition && normalised.extent.nodePosition is TextNodePosition) {
        return nodePos.offset <= (normalised.extent.nodePosition as TextNodePosition).offset;
      }
      return true;
    }

    return false;
  }

  /// Selects the entire block (node) that contains [localOffset].
  void _selectBlock(Offset localOffset) {
    final pos = _positionForOffset(localOffset);
    if (pos == null) return;

    final node = widget.document.nodeById(pos.nodeId);
    if (node is TextNode) {
      final length = node.text.text.length;
      widget.controller.setSelection(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: pos.nodeId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: pos.nodeId,
            nodePosition: TextNodePosition(offset: length),
          ),
        ),
      );
    } else {
      widget.controller.setSelection(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: pos.nodeId,
            nodePosition: const BinaryNodePosition.upstream(),
          ),
          extent: DocumentPosition(
            nodeId: pos.nodeId,
            nodePosition: const BinaryNodePosition.downstream(),
          ),
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final effectiveCursor = widget.enabled ? widget.cursor : SystemMouseCursors.basic;

    return MouseRegion(
      cursor: effectiveCursor,
      child: Listener(
        key: _listenerKey,
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: widget.enabled ? _onTapDown : null,
          onDoubleTapDown: widget.enabled ? _onDoubleTapDown : null,
          onSecondaryTapDown: widget.enabled ? _onSecondaryTapDown : null,
          child: widget.child,
        ),
      ),
    );
  }
}
