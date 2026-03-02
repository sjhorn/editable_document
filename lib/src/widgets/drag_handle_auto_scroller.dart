/// [DragHandleAutoScroller] — document-aware auto-scroll widget.
///
/// Provides frame-based auto-scrolling for descendant handle widgets during
/// drag operations. When a drag position moves into the auto-scroll zone
/// (within [autoScrollAreaExtent] pixels of the viewport top or bottom edge),
/// a [Ticker]-driven loop scrolls the attached [ScrollController] at a velocity
/// proportional to how deeply the drag is inside the zone.
///
/// ## Usage
///
/// Wrap the document viewport with [DragHandleAutoScroller] and obtain the
/// state from any descendant handle widget:
///
/// ```dart
/// final scroller = DragHandleAutoScroller.of(context);
/// // In a drag update callback:
/// scroller?.updateAutoScroll(dragGlobalPosition);
/// // On drag end:
/// scroller?.stopAutoScroll();
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// DragHandleAutoScroller
// ---------------------------------------------------------------------------

/// A widget that provides auto-scroll behaviour for descendant drag handles.
///
/// Place this widget as an ancestor of any iOS or Android drag handles.
/// Handles call [DragHandleAutoScroller.of] to retrieve the
/// [DragHandleAutoScrollerState] and drive auto-scrolling via
/// [DragHandleAutoScrollerState.startAutoScroll],
/// [DragHandleAutoScrollerState.updateAutoScroll], and
/// [DragHandleAutoScrollerState.stopAutoScroll].
///
/// Auto-scroll activates when the drag position (in global coordinates) moves
/// within [autoScrollAreaExtent] pixels of the top or bottom edge of this
/// widget's render box. The scroll velocity is linearly proportional to how
/// deeply inside the zone the position is — zero at the zone boundary,
/// maximum at the edge of the viewport.
///
/// ```dart
/// SingleChildScrollView(
///   controller: _scrollController,
///   child: DragHandleAutoScroller(
///     scrollController: _scrollController,
///     child: DocumentLayout(...),
///   ),
/// )
/// ```
class DragHandleAutoScroller extends StatefulWidget {
  /// Creates a [DragHandleAutoScroller].
  ///
  /// [scrollController] is the controller of the nearest [Scrollable] ancestor
  /// that should be driven during auto-scroll.
  ///
  /// [autoScrollAreaExtent] is the pixel distance from the viewport top and
  /// bottom edges within which auto-scroll activates. Defaults to `50.0`.
  ///
  /// [child] is the subtree that contains the draggable handles.
  const DragHandleAutoScroller({
    super.key,
    required this.scrollController,
    this.autoScrollAreaExtent = 50.0,
    required this.child,
  });

  /// The [ScrollController] to drive when auto-scrolling.
  final ScrollController scrollController;

  /// The pixel distance from the viewport edge that defines the auto-scroll zone.
  ///
  /// When the drag position is within this distance of the top or bottom of
  /// this widget's bounds, the ticker begins advancing the scroll position.
  /// Defaults to `50.0`.
  final double autoScrollAreaExtent;

  /// The subtree that contains draggable handle widgets.
  final Widget child;

  /// Returns the nearest [DragHandleAutoScrollerState] ancestor, or `null`
  /// if no [DragHandleAutoScroller] is present in the ancestry.
  ///
  /// Handle widgets call this to obtain access to auto-scroll callbacks:
  ///
  /// ```dart
  /// final autoScroller = DragHandleAutoScroller.of(context);
  /// autoScroller?.updateAutoScroll(globalDragPosition);
  /// ```
  static DragHandleAutoScrollerState? of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DragHandleAutoScrollerScope>();
    return scope?.state;
  }

  @override
  State<DragHandleAutoScroller> createState() => DragHandleAutoScrollerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ScrollController>('scrollController', scrollController));
    properties.add(DoubleProperty('autoScrollAreaExtent', autoScrollAreaExtent));
  }
}

// ---------------------------------------------------------------------------
// DragHandleAutoScrollerState
// ---------------------------------------------------------------------------

/// State for [DragHandleAutoScroller].
///
/// Manages the [Ticker] that drives frame-by-frame auto-scrolling. Call
/// [startAutoScroll] when a drag begins, [updateAutoScroll] on each drag
/// update to recalculate velocity, and [stopAutoScroll] when the drag ends.
class DragHandleAutoScrollerState extends State<DragHandleAutoScroller>
    with TickerProviderStateMixin {
  // -------------------------------------------------------------------------
  // Internal state
  // -------------------------------------------------------------------------

  /// The ticker used to advance the scroll position every frame.
  Ticker? _ticker;

  /// The current per-frame scroll delta in pixels.
  ///
  /// Positive values scroll downward; negative values scroll upward.
  double _scrollDelta = 0.0;

  /// The last known global drag position.
  Offset? _dragPosition;

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Begins auto-scroll tracking at [globalPosition].
  ///
  /// Starts the [Ticker] and performs an initial velocity calculation. Must be
  /// paired with a later call to [stopAutoScroll].
  void startAutoScroll(Offset globalPosition) {
    _dragPosition = globalPosition;
    _recalculateVelocity();
    _ensureTickerRunning();
  }

  /// Updates the auto-scroll velocity based on [globalPosition].
  ///
  /// Call this on each drag-update event. When [globalPosition] is outside
  /// the auto-scroll zones, the velocity is set to zero and the ticker pauses.
  void updateAutoScroll(Offset globalPosition) {
    _dragPosition = globalPosition;
    _recalculateVelocity();
    if (_scrollDelta != 0.0) {
      _ensureTickerRunning();
    } else {
      _stopTicker();
    }
  }

  /// Stops auto-scrolling immediately.
  ///
  /// Call this when the drag gesture ends. It is safe to call even if
  /// auto-scroll was not active.
  void stopAutoScroll() {
    _stopTicker();
    _dragPosition = null;
    _scrollDelta = 0.0;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// The maximum pixels scrolled per frame at maximum zone depth.
  ///
  /// At 60 fps, 8 px/frame ≈ 480 px/s — fast enough for comfortable handle
  /// dragging without overshooting.
  static const double _kMaxScrollPerFrame = 8.0;

  /// Recalculates [_scrollDelta] from the current [_dragPosition].
  ///
  /// The velocity is linear:
  /// - 0 at the zone boundary (edge of auto-scroll area)
  /// - [_kMaxScrollPerFrame] at the viewport edge (top or bottom)
  void _recalculateVelocity() {
    final pos = _dragPosition;
    if (pos == null) {
      _scrollDelta = 0.0;
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _scrollDelta = 0.0;
      return;
    }

    final globalTopLeft = box.localToGlobal(Offset.zero);
    final globalTop = globalTopLeft.dy;
    final globalBottom = globalTop + box.size.height;
    final extent = widget.autoScrollAreaExtent;

    final topZoneBottom = globalTop + extent;
    final bottomZoneTop = globalBottom - extent;

    if (pos.dy < topZoneBottom && pos.dy > globalTop) {
      // Inside the top auto-scroll zone. The closer to the top edge, the faster.
      // depth fraction: 1.0 at globalTop, 0.0 at topZoneBottom.
      final depth = (topZoneBottom - pos.dy) / extent;
      _scrollDelta = -depth * _kMaxScrollPerFrame;
    } else if (pos.dy > bottomZoneTop && pos.dy < globalBottom) {
      // Inside the bottom auto-scroll zone. The closer to the bottom edge, the faster.
      // depth fraction: 1.0 at globalBottom, 0.0 at bottomZoneTop.
      final depth = (pos.dy - bottomZoneTop) / extent;
      _scrollDelta = depth * _kMaxScrollPerFrame;
    } else {
      _scrollDelta = 0.0;
    }
  }

  /// Starts the ticker if it is not already running.
  void _ensureTickerRunning() {
    if (_ticker != null && _ticker!.isActive) return;

    _ticker?.dispose();
    _ticker = createTicker(_onTick)..start();
  }

  /// Stops the ticker without disposing it.
  void _stopTicker() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  /// Called every animation frame by the [Ticker].
  ///
  /// Advances the [ScrollController.offset] by [_scrollDelta], clamped to the
  /// valid scroll range.
  void _onTick(Duration elapsed) {
    if (_scrollDelta == 0.0) {
      _stopTicker();
      return;
    }

    final sc = widget.scrollController;
    if (!sc.hasClients) return;

    final newOffset = (sc.offset + _scrollDelta).clamp(
      sc.position.minScrollExtent,
      sc.position.maxScrollExtent,
    );
    sc.jumpTo(newOffset);
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return _DragHandleAutoScrollerScope(
      state: this,
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// _DragHandleAutoScrollerScope
// ---------------------------------------------------------------------------

/// An [InheritedWidget] that exposes [DragHandleAutoScrollerState] to
/// descendants via [DragHandleAutoScroller.of].
class _DragHandleAutoScrollerScope extends InheritedWidget {
  /// Creates the inherited scope.
  const _DragHandleAutoScrollerScope({
    required this.state,
    required super.child,
  });

  /// The [DragHandleAutoScrollerState] to expose to descendants.
  final DragHandleAutoScrollerState state;

  @override
  bool updateShouldNotify(_DragHandleAutoScrollerScope oldWidget) {
    return !identical(state, oldWidget.state);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DragHandleAutoScrollerState>('state', state));
  }
}
