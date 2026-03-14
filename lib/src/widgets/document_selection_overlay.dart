/// Selection overlay widget for the editable_document package.
///
/// [DocumentSelectionOverlay] is the widget-layer coordinator for all
/// visual selection feedback in a document editor:
///
/// - A selection-highlight layer ([RenderDocumentSelectionHighlight]) that draws
///   cross-block selection rectangles behind the document content.  Geometry is
///   computed at paint time by querying [RenderDocumentLayout] directly —
///   no post-frame callback is needed for the highlight itself.
/// - A caret layer ([RenderDocumentCaret]) that draws the cursor.  Like the
///   highlight, geometry is resolved at paint time.
/// - Two [CompositedTransformTarget] anchors for the start and end selection
///   handles, mirroring [TextSelectionOverlay]'s [LayerLink] approach.  Their
///   positions are still computed via a post-frame callback because they depend
///   on the widget-tree position of the anchors, not on paint-time geometry.
///
/// ## LeafRenderObjectWidget approach
///
/// Both the caret and selection highlight are now backed by
/// [LeafRenderObjectWidget]s (`_CaretRenderWidget` and
/// `_SelectionHighlightRenderWidget`) that create [RenderDocumentCaret] and
/// [RenderDocumentSelectionHighlight] render objects respectively.  This
/// eliminates the need for a post-frame callback to update caret/selection
/// geometry — geometry is queried from [RenderDocumentLayout] at paint time.
///
/// ## Blink animation
///
/// This widget does **not** implement blink animation — that is the
/// responsibility of [CaretDocumentOverlay] (Phase 6.2).  The [visible]
/// flag on the [RenderDocumentCaret] is always `true` here.
///
/// ## Build tree
///
/// ```dart
/// Stack(
///   children: [
///     child,                                   // DocumentLayout (document content)
///     _SelectionHighlightRenderWidget(...),     // selection highlight behind text
///     _CaretRenderWidget(...),                  // blinking caret
///     CompositedTransformTarget(startHandleLayerLink),
///     CompositedTransformTarget(endHandleLayerLink),
///   ],
/// )
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../model/document.dart';
import '../model/document_editing_controller.dart';
import '../model/document_selection.dart';
import '../rendering/render_document_caret.dart';
import '../rendering/render_document_selection_highlight.dart';
import 'block_drag_overlay.dart';
import 'block_resize_handles.dart';
import 'document_layout.dart';

// ---------------------------------------------------------------------------
// DocumentSelectionOverlay
// ---------------------------------------------------------------------------

/// A widget that paints selection highlights and a caret over a
/// [DocumentLayout].
///
/// [DocumentSelectionOverlay] listens to [controller] and repaints
/// whenever the selection changes.  Caret and selection geometry is computed
/// at paint time by querying [RenderDocumentLayout] directly via
/// `_CaretRenderWidget` and `_SelectionHighlightRenderWidget`.
///
/// Handle anchor positions (for [startHandleLayerLink] and
/// [endHandleLayerLink]) are still computed via a post-frame callback so that
/// [DocumentLayout] has completed its build before the geometry is queried.
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
  /// [layoutKey] is used to query [DocumentLayoutState] for handle anchor
  /// geometry and to obtain [RenderDocumentLayout] for paint-time queries.
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
    this.document,
    this.onBlockResize,
    this.onResetImageSize,
    this.onBlockMoved,
    this.blockDragOverlayKey,
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

  /// The document, required for block resize handles.
  ///
  /// When both [document] and [onBlockResize] are provided, a
  /// [BlockResizeHandles] overlay is added to the widget tree.
  final Document? document;

  /// Called when the user finishes resizing a block via drag handles.
  ///
  /// When both this and [document] are non-null, [BlockResizeHandles] is
  /// shown for fully-selected non-stretch blocks.
  final BlockResizeCallback? onBlockResize;

  /// Called when the user taps the "1:1" reset button on a selected image.
  ///
  /// Receives the node id of the [ImageNode] to reset to intrinsic size.
  /// The button only appears when this is non-null.
  final ValueChanged<String>? onResetImageSize;

  /// Called when the user drops a dragged block at a new position.
  ///
  /// When both [document] and this callback are provided, a [BlockDragOverlay]
  /// is added to the overlay stack.
  final BlockMoveCallback? onBlockMoved;

  /// An optional [GlobalKey] for the [BlockDragOverlay] child.
  ///
  /// When provided, [DocumentSelectionOverlay] uses this key for the
  /// [BlockDragOverlay] so that [DocumentMouseInteractor] can call
  /// [BlockDragOverlayState] methods directly. When `null`, an internal key
  /// is created if [onBlockMoved] and [document] are both non-null.
  final GlobalKey<BlockDragOverlayState>? blockDragOverlayKey;

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
    properties.add(DiagnosticsProperty<Document?>('document', document, defaultValue: null));
    properties.add(
      ObjectFlagProperty<BlockResizeCallback?>.has('onBlockResize', onBlockResize),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<String>?>.has(
        'onResetImageSize',
        onResetImageSize,
      ),
    );
    properties.add(
      ObjectFlagProperty<BlockMoveCallback?>.has('onBlockMoved', onBlockMoved),
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
// DocumentSelectionOverlayState
// ---------------------------------------------------------------------------

/// State object for [DocumentSelectionOverlay].
///
/// Listens to [DocumentSelectionOverlay.controller] for selection changes
/// and triggers a rebuild so the `_CaretRenderWidget` and
/// `_SelectionHighlightRenderWidget` receive updated selection data.
///
/// Handle anchor offsets (`_startOffset`, `_endOffset`) are still computed
/// via a post-frame callback because they depend on [DocumentLayoutState]
/// geometry queries that require the widget tree to have rebuilt first.
///
/// Call [update] to manually push a new [DocumentSelection] (useful when
/// platform gesture controllers compute a new selection independently of the
/// controller notifier).
class DocumentSelectionOverlayState extends State<DocumentSelectionOverlay> {
  // ---------------------------------------------------------------------------
  // Block drag overlay key
  // ---------------------------------------------------------------------------

  /// Internal [GlobalKey] for the [BlockDragOverlay] child.
  ///
  /// Used when [DocumentSelectionOverlay.blockDragOverlayKey] is `null` and
  /// a [BlockDragOverlay] is created automatically because [document] and
  /// [onBlockMoved] are both non-null.
  final _internalBlockDragOverlayKey = GlobalKey<BlockDragOverlayState>();

  /// Returns the effective [GlobalKey] for the [BlockDragOverlay].
  ///
  /// Prefers [DocumentSelectionOverlay.blockDragOverlayKey] when provided;
  /// falls back to [_internalBlockDragOverlayKey] otherwise. Returns `null`
  /// when neither [document] nor [onBlockMoved] is set.
  GlobalKey<BlockDragOverlayState>? get blockDragOverlayKey {
    if (widget.document == null || widget.onBlockMoved == null) return null;
    return widget.blockDragOverlayKey ?? _internalBlockDragOverlayKey;
  }

  // ---------------------------------------------------------------------------
  // Handle anchor offsets
  // ---------------------------------------------------------------------------

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
  // Controller listener
  // ---------------------------------------------------------------------------

  void _onControllerChanged() {
    // Trigger a rebuild so the render objects see the new selection.
    setState(() {});
    // Defer handle-anchor positioning to a post-frame callback so the
    // DocumentLayout has rebuilt with any new text before we query geometry.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateHandleOffsets(widget.controller.selection);
    });
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Updates handle anchor positions for the given [selection].
  ///
  /// Caret and selection-highlight geometry is now computed at paint time by
  /// the underlying render objects, so [update] only needs to reposition the
  /// [CompositedTransformTarget] anchors.
  ///
  /// This method calls [setState] to trigger a rebuild.  It is safe to call
  /// from outside the widget (e.g. from a gesture controller).
  void update(DocumentSelection? selection) {
    _updateHandleOffsets(selection);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Computes handle anchor offsets from [DocumentLayoutState] geometry and
  /// calls [setState] to rebuild the [CompositedTransformTarget] positions.
  void _updateHandleOffsets(DocumentSelection? selection) {
    if (selection == null) {
      setState(() {
        _startOffset = Offset.zero;
        _endOffset = Offset.zero;
      });
      return;
    }

    final layoutState = widget.layoutKey.currentState;
    if (layoutState == null) {
      setState(() {
        _startOffset = Offset.zero;
        _endOffset = Offset.zero;
      });
      return;
    }

    final extentRect = layoutState.rectForDocumentPosition(selection.extent);
    final baseRect = layoutState.rectForDocumentPosition(selection.base);
    final startRect = selection.isCollapsed ? extentRect : baseRect;

    setState(() {
      _startOffset = startRect != null ? Offset(startRect.left, startRect.top) : Offset.zero;
      _endOffset = extentRect != null ? Offset(extentRect.left, extentRect.bottom) : Offset.zero;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final selection = widget.controller.selection;

    return Stack(
      children: [
        // 1. Document content (DocumentLayout).
        widget.child,

        // 2. Selection highlight — behind the text.
        if (widget.showSelection)
          Positioned.fill(
            child: _SelectionHighlightRenderWidget(
              layoutKey: widget.layoutKey,
              selection: selection,
              selectionColor: widget.selectionColor,
            ),
          ),

        // 3. Caret — drawn on top of the selection highlight.
        if (widget.showCaret)
          Positioned.fill(
            child: _CaretRenderWidget(
              layoutKey: widget.layoutKey,
              selection: selection,
              color: widget.caretColor,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
          ),

        // 4. Block resize handles — shown for non-stretch block selection.
        if (widget.document != null && widget.onBlockResize != null)
          Positioned.fill(
            child: BlockResizeHandles(
              controller: widget.controller,
              layoutKey: widget.layoutKey,
              document: widget.document!,
              onResize: widget.onBlockResize,
              onResetImageSize: widget.onResetImageSize,
            ),
          ),

        // 5. Block drag overlay — shown while dragging blocks to new positions.
        if (widget.document != null && widget.onBlockMoved != null)
          Positioned.fill(
            child: BlockDragOverlay(
              key: blockDragOverlayKey,
              controller: widget.controller,
              layoutKey: widget.layoutKey,
              document: widget.document!,
              onBlockMoved: widget.onBlockMoved,
            ),
          ),

        // 6. CompositedTransformTarget for the selection-start handle.
        Positioned(
          left: _startOffset.dx,
          top: _startOffset.dy,
          child: CompositedTransformTarget(
            link: widget.startHandleLayerLink,
            child: const SizedBox.shrink(),
          ),
        ),

        // 7. CompositedTransformTarget for the selection-end handle.
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
    properties.add(DiagnosticsProperty<Offset>('startOffset', _startOffset));
    properties.add(DiagnosticsProperty<Offset>('endOffset', _endOffset));
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
// _SelectionHighlightRenderWidget
// ---------------------------------------------------------------------------

/// A [LeafRenderObjectWidget] that creates and updates a
/// [RenderDocumentSelectionHighlight].
///
/// Geometry is computed at paint time by [RenderDocumentSelectionHighlight]
/// querying the [RenderDocumentLayout] obtained from [layoutKey].
class _SelectionHighlightRenderWidget extends LeafRenderObjectWidget {
  const _SelectionHighlightRenderWidget({
    required this.layoutKey,
    required this.selection,
    required this.selectionColor,
  });

  final GlobalKey<DocumentLayoutState> layoutKey;
  final DocumentSelection? selection;
  final Color selectionColor;

  @override
  RenderDocumentSelectionHighlight createRenderObject(BuildContext context) {
    return RenderDocumentSelectionHighlight(
      documentLayout: layoutKey.currentState?.renderObject,
      selection: selection,
      selectionColor: selectionColor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderDocumentSelectionHighlight renderObject,
  ) {
    renderObject
      ..documentLayout = layoutKey.currentState?.renderObject
      ..selection = selection
      ..selectionColor = selectionColor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<GlobalKey<DocumentLayoutState>>('layoutKey', layoutKey));
    properties.add(DiagnosticsProperty<DocumentSelection?>('selection', selection));
    properties.add(ColorProperty('selectionColor', selectionColor));
  }
}

// ---------------------------------------------------------------------------
// _CaretRenderWidget
// ---------------------------------------------------------------------------

/// A [LeafRenderObjectWidget] that creates and updates a
/// [RenderDocumentCaret].
///
/// Geometry is computed at paint time by [RenderDocumentCaret] querying the
/// [RenderDocumentLayout] obtained from [layoutKey].
class _CaretRenderWidget extends LeafRenderObjectWidget {
  const _CaretRenderWidget({
    required this.layoutKey,
    required this.selection,
    required this.color,
    required this.devicePixelRatio,
  });

  final GlobalKey<DocumentLayoutState> layoutKey;
  final DocumentSelection? selection;
  final Color color;
  final double devicePixelRatio;

  @override
  RenderDocumentCaret createRenderObject(BuildContext context) {
    return RenderDocumentCaret(
      documentLayout: layoutKey.currentState?.renderObject,
      selection: selection,
      color: color,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderDocumentCaret renderObject,
  ) {
    renderObject
      ..documentLayout = layoutKey.currentState?.renderObject
      ..selection = selection
      ..color = color
      ..devicePixelRatio = devicePixelRatio;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<GlobalKey<DocumentLayoutState>>('layoutKey', layoutKey));
    properties.add(DiagnosticsProperty<DocumentSelection?>('selection', selection));
    properties.add(ColorProperty('color', color));
    properties.add(DoubleProperty('devicePixelRatio', devicePixelRatio));
  }
}
