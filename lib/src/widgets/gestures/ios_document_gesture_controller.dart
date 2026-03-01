/// iOS gesture handler for the editable_document package.
///
/// [IosDocumentGestureController] wraps its [child] in gesture detectors
/// for iOS-style touch interactions and translates them into
/// [DocumentSelection] updates on the supplied [DocumentEditingController].
///
/// Supported gestures:
/// - **Tap** — collapses the selection to the tapped position.
/// - **Double-tap** — selects the word under the pointer.
/// - **Long-press** — places caret at the pressed position.
///
/// Set [enabled] to `false` to suppress all gesture handling while keeping
/// the widget in the tree (useful for read-only modes).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../model/document.dart';
import '../../model/document_editing_controller.dart';
import '../../model/document_position.dart';
import '../../model/document_selection.dart';
import '../../model/node_position.dart';
import '../../model/text_node.dart';
import '../document_layout.dart';

// ---------------------------------------------------------------------------
// IosDocumentGestureController
// ---------------------------------------------------------------------------

/// A [StatefulWidget] that handles iOS-style touch gestures for a document
/// editor.
///
/// Wrap a [DocumentLayout] (or any [child] containing the document rendering)
/// with this widget to get tap, double-tap, and long-press selection behaviour
/// driven by touch events.
///
/// ```dart
/// final layoutKey = GlobalKey<DocumentLayoutState>();
///
/// IosDocumentGestureController(
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
class IosDocumentGestureController extends StatefulWidget {
  /// Creates an [IosDocumentGestureController].
  ///
  /// [controller] is updated whenever a gesture produces a selection change.
  /// [layoutKey] must point to the [DocumentLayoutState] that performs
  /// document-position hit-testing.
  /// [document] is used for word boundary detection during double-tap.
  /// [child] is the document content widget to wrap.
  /// [enabled] defaults to `true`; set to `false` to suppress all gestures.
  const IosDocumentGestureController({
    super.key,
    required this.controller,
    required this.layoutKey,
    required this.document,
    required this.child,
    this.enabled = true,
  });

  /// The controller whose [DocumentEditingController.selection] is updated
  /// by gestures.
  final DocumentEditingController controller;

  /// A [GlobalKey] pointing to the [DocumentLayoutState] that provides
  /// geometry queries such as [DocumentLayoutState.documentPositionNearestToOffset].
  final GlobalKey<DocumentLayoutState> layoutKey;

  /// The document being edited; used for word boundary detection on double-tap.
  final Document document;

  /// The document content widget to wrap.
  final Widget child;

  /// Whether touch gestures are active.
  ///
  /// When `false` all tap/drag callbacks are no-ops. Defaults to `true`.
  final bool enabled;

  @override
  State<IosDocumentGestureController> createState() => _IosDocumentGestureControllerState();

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
// _IosDocumentGestureControllerState
// ---------------------------------------------------------------------------

class _IosDocumentGestureControllerState extends State<IosDocumentGestureController> {
  // -------------------------------------------------------------------------
  // Keys
  // -------------------------------------------------------------------------

  /// Key on the inner [GestureDetector] for coordinate conversion.
  final _gestureKey = GlobalKey();

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  DocumentLayoutState? get _layout => widget.layoutKey.currentState;

  /// Returns whether [char] should be treated as a word boundary.
  bool _isWordBreak(String char) => char == ' ' || char == '\n' || char == '\t';

  /// Finds the [start, end) character range of the word that contains
  /// [offset] within [text].
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

  /// Converts a gesture-local [offset] to a [DocumentPosition].
  ///
  /// Returns `null` when the layout is not yet attached.
  DocumentPosition? _positionForOffset(Offset offset) {
    final layout = _layout;
    if (layout == null) return null;

    final layoutBox = widget.layoutKey.currentContext?.findRenderObject() as RenderBox?;
    if (layoutBox == null) return null;

    final gestureBox = _gestureKey.currentContext?.findRenderObject() as RenderBox?;
    if (gestureBox == null) {
      return layout.documentPositionNearestToOffset(offset);
    }

    final globalOffset = gestureBox.localToGlobal(offset);
    final layoutLocal = layoutBox.globalToLocal(globalOffset);
    return layout.documentPositionNearestToOffset(layoutLocal);
  }

  // -------------------------------------------------------------------------
  // Gesture handlers
  // -------------------------------------------------------------------------

  void _onTapDown(TapDownDetails details) {
    if (!widget.enabled) return;

    final pos = _positionForOffset(details.localPosition);
    if (pos == null) return;

    widget.controller.setSelection(DocumentSelection.collapsed(position: pos));
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

    final pos = _positionForOffset(details.localPosition);
    if (pos == null) return;

    widget.controller.setSelection(DocumentSelection.collapsed(position: pos));
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _gestureKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? _onTapDown : null,
      onDoubleTapDown: widget.enabled ? _onDoubleTapDown : null,
      onLongPressStart: widget.enabled ? _onLongPressStart : null,
      child: widget.child,
    );
  }
}
