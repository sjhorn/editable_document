/// Selection overlay widget for the editable_document package.
///
/// [DocumentSelectionOverlay] is the widget-layer coordinator for all
/// visual selection feedback in a document editor:
///
/// - A selection-highlight layer ([DocumentSelectionPainter]) that draws
///   cross-block selection rectangles behind the document content.
/// - A caret layer ([DocumentCaretPainter]) that draws the blinking cursor.
/// - Two [CompositedTransformTarget] anchors for the start and end selection
///   handles, mirroring [TextSelectionOverlay]'s [LayerLink] approach.
///
/// Geometry is recomputed by calling
/// [DocumentSelectionOverlayState.update] (or automatically when the
/// [controller] notifies listeners) via
/// [DocumentLayoutState.rectForDocumentPosition].
///
/// ## Blink animation
///
/// This widget does **not** implement blink animation — that is the
/// responsibility of [CaretDocumentOverlay] (Phase 6.2).  The [visible]
/// flag on the [DocumentCaretPainter] is always `true` here.
///
/// ## Build tree
///
/// ```dart
/// Stack(
///   children: [
///     child,                         // DocumentLayout (document content)
///     CustomPaint(selectionPainter), // selection highlight behind text
///     CustomPaint(caretPainter),     // blinking caret
///     CompositedTransformTarget(startHandleLayerLink),
///     CompositedTransformTarget(endHandleLayerLink),
///   ],
/// )
/// ```
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../model/document_editing_controller.dart';
import '../model/document_selection.dart';
import '../rendering/document_caret_painter.dart';
import '../rendering/document_selection_painter.dart';
import 'document_layout.dart';

// ---------------------------------------------------------------------------
// DocumentSelectionOverlay
// ---------------------------------------------------------------------------

/// A widget that paints selection highlights and a caret over a
/// [DocumentLayout].
///
/// [DocumentSelectionOverlay] listens to [controller] and repaints
/// whenever the selection changes.  Geometry is obtained by querying
/// [layoutKey] after each selection update.
///
/// ### LayerLink positioning
///
/// Two [CompositedTransformTarget] widgets are placed at the selection
/// start ([startHandleLayerLink]) and end ([endHandleLayerLink]).  Platform
/// gesture controllers (Phase 6.3–6.5) attach
/// [CompositedTransformFollower] widgets to these links so that handles and
/// the magnifier track the document layout during scroll without expensive
/// rebuilds.
///
/// ### Minimal example
///
/// ```dart
/// final layoutKey = GlobalKey<DocumentLayoutState>();
///
/// DocumentSelectionOverlay(
///   controller: myController,
///   layoutKey: layoutKey,
///   startHandleLayerLink: LayerLink(),
///   endHandleLayerLink: LayerLink(),
///   child: DocumentLayout(
///     key: layoutKey,
///     document: myController.document,
///     controller: myController,
///     componentBuilders: defaultComponentBuilders,
///   ),
/// )
/// ```
class DocumentSelectionOverlay extends StatefulWidget {
  /// Creates a [DocumentSelectionOverlay].
  ///
  /// [controller] is the source of truth for the document selection.
  /// [layoutKey] is used to query [DocumentLayoutState] for geometry.
  /// [startHandleLayerLink] and [endHandleLayerLink] are the [LayerLink]s
  /// used to position selection handles / toolbar via
  /// [CompositedTransformFollower].
  ///
  /// [selectionColor] and [caretColor] default to semi-transparent blue and
  /// opaque black respectively.
  ///
  /// Set [showCaret] to `false` to suppress the caret painter (e.g. in
  /// read-only mode).  Set [showSelection] to `false` to suppress the
  /// selection-highlight painter.  [showHandles] is `false` by default and
  /// is enabled by platform gesture controllers in Phase 6.3–6.5.
  const DocumentSelectionOverlay({
    super.key,
    required this.controller,
    required this.layoutKey,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    required this.child,
    this.selectionColor = const Color(0x663399FF),
    this.caretColor = const Color(0xFF000000),
    this.showCaret = true,
    this.showSelection = true,
    this.showHandles = false,
  });

  /// The document editing controller that provides selection state.
  final DocumentEditingController controller;

  /// A [GlobalKey] into the [DocumentLayoutState] used for geometry queries.
  ///
  /// The key must be attached to the [DocumentLayout] that is the [child]
  /// (or a descendant of [child]) so that layout has completed before
  /// geometry is queried.
  final GlobalKey<DocumentLayoutState> layoutKey;

  /// [LayerLink] for the selection-start handle.
  ///
  /// Attach a [CompositedTransformFollower] with this link to any widget that
  /// should track the start of the selection (e.g. the left drag handle).
  final LayerLink startHandleLayerLink;

  /// [LayerLink] for the selection-end handle.
  ///
  /// Attach a [CompositedTransformFollower] with this link to any widget that
  /// should track the end of the selection (e.g. the right drag handle).
  final LayerLink endHandleLayerLink;

  /// The document content widget (typically a [DocumentLayout]).
  final Widget child;

  /// The colour used to fill selection-highlight rectangles.
  ///
  /// Defaults to `Color(0x663399FF)` (semi-transparent blue).
  final Color selectionColor;

  /// The colour used to draw the text cursor.
  ///
  /// Defaults to `Color(0xFF000000)` (opaque black).
  final Color caretColor;

  /// Whether to paint the caret.
  ///
  /// Set to `false` in read-only mode or when a blinking caret overlay
  /// (Phase 6.2) manages its own painting.  Defaults to `true`.
  final bool showCaret;

  /// Whether to paint selection-highlight rectangles.
  ///
  /// Set to `false` when no selection highlight is desired.
  /// Defaults to `true`.
  final bool showSelection;

  /// Whether drag handles are shown.
  ///
  /// This flag is `false` by default.  Platform gesture controllers
  /// (Phase 6.3–6.5) set it to `true` once long-press or drag is detected.
  final bool showHandles;

  @override
  State<DocumentSelectionOverlay> createState() => DocumentSelectionOverlayState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DocumentEditingController>('controller', controller));
    properties.add(DiagnosticsProperty<GlobalKey<DocumentLayoutState>>('layoutKey', layoutKey));
    properties.add(DiagnosticsProperty<LayerLink>('startHandleLayerLink', startHandleLayerLink));
    properties.add(DiagnosticsProperty<LayerLink>('endHandleLayerLink', endHandleLayerLink));
    properties.add(ColorProperty('selectionColor', selectionColor));
    properties.add(ColorProperty('caretColor', caretColor));
    properties.add(FlagProperty('showCaret', value: showCaret, ifTrue: 'showCaret'));
    properties.add(FlagProperty('showSelection', value: showSelection, ifTrue: 'showSelection'));
    properties.add(FlagProperty('showHandles', value: showHandles, ifTrue: 'showHandles'));
  }
}

// ---------------------------------------------------------------------------
// DocumentSelectionOverlayState
// ---------------------------------------------------------------------------

/// State object for [DocumentSelectionOverlay].
///
/// Listens to [DocumentSelectionOverlay.controller] for selection changes
/// and recomputes painter data by querying [DocumentLayoutState] geometry.
///
/// Call [update] to manually push a new [DocumentSelection] (useful when
/// platform gesture controllers compute a new selection independently of the
/// controller notifier).
class DocumentSelectionOverlayState extends State<DocumentSelectionOverlay> {
  // ---------------------------------------------------------------------------
  // Painter state
  // ---------------------------------------------------------------------------

  /// The bounding rectangle for the caret in [DocumentLayout] local coords.
  Rect? _caretRect;

  /// The selection-highlight rectangles in [DocumentLayout] local coords.
  List<Rect> _selectionRects = const [];

  /// The local offset of the selection-start point (for the [LayerLink]).
  Offset _startOffset = Offset.zero;

  /// The local offset of the selection-end point (for the [LayerLink]).
  Offset _endOffset = Offset.zero;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(DocumentSelectionOverlay oldWidget) {
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
  // Geometry update
  // ---------------------------------------------------------------------------

  void _onControllerChanged() {
    update(widget.controller.selection);
  }

  /// Recomputes caret and selection geometry from [DocumentLayoutState].
  ///
  /// When [selection] is `null`, all painters are reset to their empty states.
  /// When [selection] is collapsed, only the caret rect is computed.
  /// When [selection] is expanded, both the caret and selection rects are
  /// computed.
  ///
  /// This method calls [setState] to trigger a repaint.  It is safe to call
  /// from outside the widget (e.g. from a gesture controller).
  void update(DocumentSelection? selection) {
    if (selection == null) {
      setState(() {
        _caretRect = null;
        _selectionRects = const [];
        _startOffset = Offset.zero;
        _endOffset = Offset.zero;
      });
      return;
    }

    final layoutState = widget.layoutKey.currentState;
    if (layoutState == null) {
      // Layout has not been built yet — reset and wait for the next update.
      setState(() {
        _caretRect = null;
        _selectionRects = const [];
        _startOffset = Offset.zero;
        _endOffset = Offset.zero;
      });
      return;
    }

    // Caret position: always at the extent of the selection.
    final extentRect = layoutState.rectForDocumentPosition(selection.extent);

    // Selection highlight rects: only meaningful when expanded.
    final selRects = _computeSelectionRects(selection, layoutState);

    // Handle anchor positions.
    final baseRect = layoutState.rectForDocumentPosition(selection.base);
    final startRect = selection.isCollapsed ? extentRect : baseRect;

    setState(() {
      _caretRect = extentRect;
      _selectionRects = selRects;
      _startOffset = startRect != null ? Offset(startRect.left, startRect.top) : Offset.zero;
      _endOffset = extentRect != null ? Offset(extentRect.left, extentRect.bottom) : Offset.zero;
    });
  }

  /// Computes selection-highlight rectangles by querying each node between
  /// [selection.base] and [selection.extent].
  ///
  /// For a collapsed selection (caret only) returns an empty list.
  /// For an expanded single-node selection, returns the rect spanning the
  /// selection within that node.
  /// For multi-node selections, returns one rect per node (full-width for
  /// intermediate nodes).
  List<Rect> _computeSelectionRects(
    DocumentSelection selection,
    DocumentLayoutState layoutState,
  ) {
    if (selection.isCollapsed) return const [];

    // Obtain the bounding rects at both endpoints.
    final baseRect = layoutState.rectForDocumentPosition(selection.base);
    final extentRect = layoutState.rectForDocumentPosition(selection.extent);

    if (baseRect == null || extentRect == null) return const [];

    // Determine which is the upstream (top) and which is downstream (bottom).
    final topRect = baseRect.top <= extentRect.top ? baseRect : extentRect;
    final bottomRect = baseRect.top <= extentRect.top ? extentRect : baseRect;

    // Single-line selection: one rect from top-left to bottom-right.
    if ((topRect.top - bottomRect.top).abs() < 1.0) {
      // Same line — build one rect spanning the full selection.
      final left = topRect.left < bottomRect.right ? topRect.left : bottomRect.left;
      final right = topRect.right > bottomRect.left ? topRect.right : bottomRect.right;
      return [Rect.fromLTRB(left, topRect.top, right, topRect.bottom)];
    }

    // Multi-line selection: three rects (top partial, middle full, bottom
    // partial), collapsed when the selection spans only two lines.
    final rects = <Rect>[];

    // Top line: from the upstream endpoint to the right edge of the layout.
    rects.add(Rect.fromLTRB(topRect.left, topRect.top, double.infinity, topRect.bottom));

    // Intermediate lines: full-width rows between top and bottom.
    // (Geometry for intermediate nodes would be added here in Phase 6.x;
    //  for now we emit just the top and bottom rects.)

    // Bottom line: from left edge to the downstream endpoint.
    rects.add(Rect.fromLTRB(0, bottomRect.top, bottomRect.right, bottomRect.bottom));

    return rects;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Build the selection painter.
    final selectionPainter = DocumentSelectionPainter(
      selectionRects: widget.showSelection ? _selectionRects : const [],
      selectionColor: widget.selectionColor,
    );

    // Build the caret painter.
    final caretPainter = DocumentCaretPainter(
      caretRect: widget.showCaret ? _caretRect : null,
      color: widget.caretColor,
    );

    return Stack(
      children: [
        // 1. Document content (DocumentLayout).
        widget.child,

        // 2. Selection highlight — behind the text.
        Positioned.fill(
          child: CustomPaint(painter: selectionPainter),
        ),

        // 3. Caret — drawn on top of the selection highlight.
        Positioned.fill(
          child: CustomPaint(painter: caretPainter),
        ),

        // 4. CompositedTransformTarget for the selection-start handle.
        Positioned(
          left: _startOffset.dx,
          top: _startOffset.dy,
          child: CompositedTransformTarget(
            link: widget.startHandleLayerLink,
            child: const SizedBox.shrink(),
          ),
        ),

        // 5. CompositedTransformTarget for the selection-end handle.
        Positioned(
          left: _endOffset.dx,
          top: _endOffset.dy,
          child: CompositedTransformTarget(
            link: widget.endHandleLayerLink,
            child: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Rect?>('caretRect', _caretRect, defaultValue: null));
    properties.add(IntProperty('selectionRectCount', _selectionRects.length, defaultValue: 0));
    properties.add(DiagnosticsProperty<Offset>('startOffset', _startOffset));
    properties.add(DiagnosticsProperty<Offset>('endOffset', _endOffset));
  }
}
