/// Android gesture controller for the editable_document package.
///
/// [AndroidDocumentGestureController] handles all touch-based document
/// gestures on Android:
///
/// - **Tap** — collapses the selection to the tapped position.
/// - **Double-tap** — selects the word under the tap (whitespace boundary).
/// - **Long-press** — shows the [AndroidDocumentMagnifier] and places the
///   caret at the pressed position.
/// - **Drag after long-press** — moves the caret with a magnifier following
///   the finger.
///
/// When [enabled] is `false` all gesture handling is suppressed.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../model/document.dart';
import '../../model/document_editing_controller.dart';
import '../../model/document_position.dart';
import '../../model/document_selection.dart';
import '../../model/node_position.dart';
import '../../model/table_node.dart';
import '../../model/text_node.dart';
import '../document_layout.dart';
import 'android_document_magnifier.dart';

// ---------------------------------------------------------------------------
// AndroidDocumentGestureController
// ---------------------------------------------------------------------------

/// A [StatefulWidget] that handles Android touch gestures for a document
/// editor.
///
/// Wrap your [DocumentLayout] (or any other [child]) with this widget to get
/// tap, double-tap, long-press, and drag selection behaviour appropriate for
/// Android, including the animated [AndroidDocumentMagnifier] during
/// long-press and drag.
///
/// ```dart
/// final layoutKey = GlobalKey<DocumentLayoutState>();
///
/// AndroidDocumentGestureController(
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
/// Set [enabled] to `false` to suppress all gesture handling (useful in
/// read-only mode).
class AndroidDocumentGestureController extends StatefulWidget {
  /// Creates an [AndroidDocumentGestureController].
  ///
  /// [controller] is updated whenever a gesture produces a selection change.
  /// [layoutKey] points to the [DocumentLayoutState] used for position
  /// hit-testing. [document] is used for word-boundary detection.
  /// [child] is the document content widget to wrap.
  const AndroidDocumentGestureController({
    super.key,
    required this.controller,
    required this.layoutKey,
    required this.document,
    required this.child,
    this.enabled = true,
  });

  /// The controller whose [DocumentEditingController.selection] is updated by
  /// gestures.
  final DocumentEditingController controller;

  /// A [GlobalKey] pointing to the [DocumentLayoutState] that provides
  /// geometry queries such as
  /// [DocumentLayoutState.documentPositionNearestToOffset].
  final GlobalKey<DocumentLayoutState> layoutKey;

  /// The document being edited; used for word-boundary detection on
  /// double-tap.
  final Document document;

  /// The document content widget to wrap.
  final Widget child;

  /// Whether touch gestures are active.
  ///
  /// When `false`, all tap / double-tap / long-press callbacks are no-ops.
  /// Defaults to `true`.
  final bool enabled;

  @override
  State<AndroidDocumentGestureController> createState() => AndroidDocumentGestureControllerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DocumentEditingController>('controller', controller));
    properties.add(
      DiagnosticsProperty<GlobalKey<DocumentLayoutState>>('layoutKey', layoutKey),
    );
    properties.add(DiagnosticsProperty<Document>('document', document));
    properties.add(FlagProperty('enabled', value: enabled, ifTrue: 'enabled', ifFalse: 'disabled'));
  }
}

// ---------------------------------------------------------------------------
// AndroidDocumentGestureControllerState
// ---------------------------------------------------------------------------

/// State for [AndroidDocumentGestureController].
///
/// Manages the long-press detection timer, the magnifier visibility, and the
/// drag position tracking.
class AndroidDocumentGestureControllerState extends State<AndroidDocumentGestureController> {
  /// Whether the magnifier is currently visible.
  bool _showMagnifier = false;

  /// The current focal point of the magnifier in local coordinates.
  Offset _magnifierFocalPoint = Offset.zero;

  /// A key on the inner [Listener] used for coordinate-space conversion.
  final _listenerKey = GlobalKey();

  // ---------------------------------------------------------------------------
  // Private helpers — layout
  // ---------------------------------------------------------------------------

  DocumentLayoutState? get _layout => widget.layoutKey.currentState;

  /// Converts a [Listener]-local [offset] to a [DocumentPosition].
  DocumentPosition? _positionForOffset(Offset offset) {
    final layout = _layout;
    if (layout == null) return null;
    final layoutBox = widget.layoutKey.currentContext?.findRenderObject() as RenderBox?;
    if (layoutBox == null) return null;
    final listenerBox = _listenerKey.currentContext?.findRenderObject() as RenderBox?;
    if (listenerBox == null) {
      return layout.documentPositionNearestToOffset(offset);
    }
    final globalOffset = listenerBox.localToGlobal(offset);
    final layoutLocal = layoutBox.globalToLocal(globalOffset);
    return layout.documentPositionNearestToOffset(layoutLocal);
  }

  // ---------------------------------------------------------------------------
  // Private helpers — word boundaries
  // ---------------------------------------------------------------------------

  bool _isWordBreak(String char) => char == ' ' || char == '\n' || char == '\t';

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

  // ---------------------------------------------------------------------------
  // Gesture callbacks
  // ---------------------------------------------------------------------------

  void _onTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    final pos = _positionForOffset(details.localPosition);
    if (pos == null) return;
    // For non-text nodes (images, HRs), select the whole block so the
    // highlight is visible and delete/backspace work immediately.
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

  void _onDoubleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
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

  void _onLongPressStart(LongPressStartDetails details) {
    if (!widget.enabled) return;

    // Place caret at long-press position.
    final pos = _positionForOffset(details.localPosition);
    if (pos != null) {
      widget.controller.setSelection(DocumentSelection.collapsed(position: pos));
    }

    // Show magnifier.
    setState(() {
      _showMagnifier = true;
      _magnifierFocalPoint = details.localPosition;
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!widget.enabled) return;

    // Update caret position as finger moves.
    final pos = _positionForOffset(details.localPosition);
    if (pos != null) {
      widget.controller.setSelection(DocumentSelection.collapsed(position: pos));
    }

    setState(() {
      _magnifierFocalPoint = details.localPosition;
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!widget.enabled) return;

    setState(() {
      _showMagnifier = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? _onTapDown : null,
      onDoubleTapDown: widget.enabled ? _onDoubleTapDown : null,
      onLongPressStart: widget.enabled ? _onLongPressStart : null,
      onLongPressMoveUpdate: widget.enabled ? _onLongPressMoveUpdate : null,
      onLongPressEnd: widget.enabled ? _onLongPressEnd : null,
      child: Stack(
        children: [
          Listener(
            key: _listenerKey,
            behavior: HitTestBehavior.translucent,
            child: widget.child,
          ),
          if (_showMagnifier)
            Positioned(
              left: _magnifierFocalPoint.dx - 50,
              top: _magnifierFocalPoint.dy - 56,
              child: AndroidDocumentMagnifier(focalPoint: _magnifierFocalPoint),
            ),
        ],
      ),
    );
  }
}
