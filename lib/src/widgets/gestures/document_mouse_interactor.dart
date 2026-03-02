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

import '../../model/document.dart';
import '../../model/document_editing_controller.dart';
import '../../model/document_position.dart';
import '../../model/document_selection.dart';
import '../../model/node_position.dart';
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
  /// coordinate-space conversion in [_positionForOffset].
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
  // Multi-tap tracking
  // -------------------------------------------------------------------------

  /// Whether a double-tap was recently recorded and a triple-tap is pending.
  ///
  /// Set to `true` inside [_onDoubleTapDown] and automatically cleared after
  /// 300 ms by a [Timer].  Because [flutter_test] fakes [Timer], this flag
  /// works correctly in both production and test environments.
  bool _pendingTripleTap = false;

  /// Position of the most-recent double-tap, used to gate triple-tap
  /// distance check.
  Offset? _lastDoubleTapPosition;

  /// Timer that clears [_pendingTripleTap] after the triple-tap window.
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
  /// position and [_pendingTripleTap] is still set (i.e. the triple-tap
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
  /// Records the drag base position for primary-button presses.
  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    if (event.buttons & kPrimaryMouseButton == 0 && event.kind != PointerDeviceKind.touch) {
      // Non-primary-button mouse press — ignore.
      return;
    }
    // Request focus so clicking the document steals focus from other widgets.
    widget.focusNode?.requestFocus();
    _dragBasePosition = _positionForOffset(event.localPosition);
    _isDragging = true;
  }

  /// Handles raw pointer-move events.
  ///
  /// Extends the selection from the base to the current position when
  /// the primary button is held.
  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.enabled) return;
    if (!_isDragging) return;
    final base = _dragBasePosition;
    if (base == null) return;
    final extent = _positionForOffset(event.localPosition);
    if (extent == null) return;
    widget.controller.setSelection(DocumentSelection(base: base, extent: extent));
  }

  /// Handles raw pointer-up events.
  ///
  /// Clears the drag state.
  void _onPointerUp(PointerUpEvent event) {
    _isDragging = false;
  }

  /// Handles raw pointer-cancel events.
  void _onPointerCancel(PointerCancelEvent event) {
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
      // Plain tap — collapse to tapped position.
      widget.controller.setSelection(DocumentSelection.collapsed(position: pos));
    }
  }

  /// Handles a double-tap down event (word selection).
  ///
  /// If a third tap follows quickly (within 300 ms and 20 logical pixels),
  /// it is treated as a triple-tap that selects the entire block.
  void _onDoubleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;

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
          child: widget.child,
        ),
      ),
    );
  }
}
