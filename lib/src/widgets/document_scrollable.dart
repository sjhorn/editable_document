/// [DocumentScrollable] — scroll wrapper for [EditableDocument].
///
/// Wraps document content in a [SingleChildScrollView] and provides
/// document-aware auto-scrolling: when the [controller]'s selection changes,
/// the scroll position is adjusted to bring the selection extent's caret rect
/// into view, padded by [scrollPadding] on all sides.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../model/document_editing_controller.dart';
import '../model/document_position.dart';
import 'document_layout.dart';

// ---------------------------------------------------------------------------
// DocumentScrollable
// ---------------------------------------------------------------------------

/// A scrollable wrapper for a document layout that auto-scrolls the caret
/// into view whenever the [DocumentEditingController] selection changes.
///
/// [DocumentScrollable] wraps [child] (typically a [DocumentLayout]) in a
/// [SingleChildScrollView]. It listens to [controller] and, after each
/// selection change, calls [DocumentScrollableState.bringDocumentPositionIntoView]
/// with the selection extent to ensure the caret remains visible.
///
/// ## Example
///
/// ```dart
/// final layoutKey = GlobalKey<DocumentLayoutState>();
///
/// DocumentScrollable(
///   controller: myController,
///   layoutKey: layoutKey,
///   child: DocumentLayout(
///     key: layoutKey,
///     document: myController.document,
///     controller: myController,
///     componentBuilders: defaultComponentBuilders,
///   ),
/// )
/// ```
class DocumentScrollable extends StatefulWidget {
  /// Creates a [DocumentScrollable].
  ///
  /// [controller] and [layoutKey] are required. [child] is the document
  /// content to scroll. [scrollController], [scrollPadding], [scrollDirection],
  /// and [physics] are optional with sensible defaults.
  const DocumentScrollable({
    super.key,
    required this.controller,
    required this.layoutKey,
    required this.child,
    this.scrollController,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.scrollDirection = Axis.vertical,
    this.physics,
  });

  /// The document editing controller whose selection changes trigger
  /// auto-scrolling.
  ///
  /// [DocumentScrollable] adds a listener to this controller and removes it
  /// when the widget is disposed or when the controller is replaced via
  /// `didUpdateWidget`.
  final DocumentEditingController controller;

  /// The key for the [DocumentLayout] child, used to query caret geometry via
  /// [DocumentLayoutState.rectForDocumentPosition].
  ///
  /// When `layoutKey.currentState` is `null` (e.g. the layout has not been
  /// mounted), `bringDocumentPositionIntoView` is a no-op.
  final GlobalKey<DocumentLayoutState> layoutKey;

  /// The document content to display inside the [SingleChildScrollView].
  ///
  /// Typically a [DocumentLayout], but any widget is accepted.
  final Widget child;

  /// An optional external [ScrollController].
  ///
  /// When provided, this controller is used directly and is NOT disposed when
  /// the widget is unmounted (the caller owns it). When `null`, an internal
  /// [ScrollController] is created and disposed automatically.
  final ScrollController? scrollController;

  /// Padding around the caret rect applied before computing the target scroll
  /// offset.
  ///
  /// Defaults to `EdgeInsets.all(20.0)`, matching [EditableText.scrollPadding].
  final EdgeInsets scrollPadding;

  /// The axis along which the document scrolls.
  ///
  /// Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Optional scroll physics passed to the underlying [SingleChildScrollView].
  ///
  /// When `null`, platform-default physics are used.
  final ScrollPhysics? physics;

  /// Returns `true` when a [DocumentScrollable] ancestor is present in the
  /// widget tree above [context].
  ///
  /// Used by [EditableDocumentState] to skip its own `showOnScreen()` call
  /// when a [DocumentScrollable] ancestor is already managing auto-scroll.
  static bool handlesAutoScroll(BuildContext context) {
    return _DocumentScrollableScope.isActive(context);
  }

  @override
  State<DocumentScrollable> createState() => DocumentScrollableState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController>('controller', controller),
    );
    properties.add(
      DiagnosticsProperty<GlobalKey<DocumentLayoutState>>('layoutKey', layoutKey),
    );
    properties.add(
      DiagnosticsProperty<ScrollController?>('scrollController', scrollController,
          defaultValue: null),
    );
    properties.add(DiagnosticsProperty<EdgeInsets>('scrollPadding', scrollPadding));
    properties.add(EnumProperty<Axis>('scrollDirection', scrollDirection));
    properties.add(
      DiagnosticsProperty<ScrollPhysics?>('physics', physics, defaultValue: null),
    );
  }
}

// ---------------------------------------------------------------------------
// DocumentScrollableState
// ---------------------------------------------------------------------------

/// State object for [DocumentScrollable].
///
/// Exposes:
/// - [effectiveScrollController] — the active [ScrollController] (internal or
///   external).
/// - [bringDocumentPositionIntoView] — scrolls so that [position]'s caret
///   rect is fully visible, inflated by [DocumentScrollable.scrollPadding].
class DocumentScrollableState extends State<DocumentScrollable> {
  /// The internal [ScrollController] created when no external one is provided.
  ScrollController? _internalScrollController;

  /// Guard: `true` while a post-frame show-caret callback is pending.
  bool _showCaretOnScreenScheduled = false;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _internalScrollController = ScrollController();
    }
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(DocumentScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Swap scroll controller if the external one changed.
    if (!identical(oldWidget.scrollController, widget.scrollController)) {
      if (widget.scrollController == null) {
        // Switched from external → internal: create a fresh internal controller.
        _internalScrollController = ScrollController();
      } else {
        // Switched from internal → external: dispose the internal controller.
        _internalScrollController?.dispose();
        _internalScrollController = null;
      }
    }

    // Resubscribe when the document controller changes.
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    // Only dispose controllers we own.
    _internalScrollController?.dispose();
    _internalScrollController = null;
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// The active [ScrollController] — the external one if provided, otherwise
  /// the internally managed one.
  ScrollController get effectiveScrollController =>
      widget.scrollController ?? _internalScrollController!;

  /// Scrolls the viewport so that [position]'s caret rect is fully visible,
  /// padded by [DocumentScrollable.scrollPadding] on all sides.
  ///
  /// When [animate] is `true` (the default), [ScrollController.animateTo] is
  /// used with a 100 ms `fastOutSlowIn` curve. When `false`,
  /// [ScrollController.jumpTo] is used for an immediate snap.
  ///
  /// This method is a no-op when:
  /// - `layoutKey.currentState` is `null` (layout not yet mounted).
  /// - The caret rect cannot be determined for [position].
  /// - The caret is already fully visible within the current viewport.
  void bringDocumentPositionIntoView(
    DocumentPosition position, {
    bool animate = true,
  }) {
    final layoutState = widget.layoutKey.currentState;
    if (layoutState == null) return;

    final caretRect = layoutState.rectForDocumentPosition(position);
    if (caretRect == null) return;

    // Inflate by scroll padding.
    final paddedRect = widget.scrollPadding.inflateRect(caretRect);

    final sc = effectiveScrollController;
    if (!sc.hasClients) return;

    final viewportDimension = sc.position.viewportDimension;
    final currentOffset = sc.offset;
    final maxOffset = sc.position.maxScrollExtent;

    double targetOffset;
    if (widget.scrollDirection == Axis.vertical) {
      // Compute the scroll offset needed so paddedRect is fully in view.
      if (paddedRect.bottom > currentOffset + viewportDimension) {
        // Caret is below the viewport: scroll down.
        targetOffset = paddedRect.bottom - viewportDimension;
      } else if (paddedRect.top < currentOffset) {
        // Caret is above the viewport: scroll up.
        targetOffset = paddedRect.top;
      } else {
        // Already in view.
        return;
      }
    } else {
      // Horizontal scrolling.
      if (paddedRect.right > currentOffset + viewportDimension) {
        targetOffset = paddedRect.right - viewportDimension;
      } else if (paddedRect.left < currentOffset) {
        targetOffset = paddedRect.left;
      } else {
        return;
      }
    }

    // Clamp to valid scroll range.
    targetOffset = targetOffset.clamp(0.0, maxOffset);

    if (animate) {
      sc.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 100),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      sc.jumpTo(targetOffset);
    }
  }

  // -------------------------------------------------------------------------
  // Controller change listener
  // -------------------------------------------------------------------------

  void _onControllerChanged() {
    _scheduleShowCaretOnScreen();
  }

  /// Schedules a post-frame callback that brings the selection extent caret
  /// into view.
  ///
  /// Calls are coalesced — if a callback is already queued, subsequent calls
  /// before the frame fires are silently ignored.
  void _scheduleShowCaretOnScreen() {
    if (_showCaretOnScreenScheduled) return;
    _showCaretOnScreenScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _showCaretOnScreenScheduled = false;
      if (!mounted) return;

      final selection = widget.controller.selection;
      if (selection == null) return;

      bringDocumentPositionIntoView(selection.extent);
    });
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return _DocumentScrollableScope(
      child: SingleChildScrollView(
        controller: effectiveScrollController,
        scrollDirection: widget.scrollDirection,
        physics: widget.physics,
        child: widget.child,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ScrollController>(
        'effectiveScrollController', effectiveScrollController));
  }
}

// ---------------------------------------------------------------------------
// _DocumentScrollableScope
// ---------------------------------------------------------------------------

/// An [InheritedWidget] that signals to descendant [EditableDocument] widgets
/// that auto-scrolling is managed by an ancestor [DocumentScrollable].
///
/// When this scope is present, [EditableDocumentState] skips its own
/// `showOnScreen()` call to avoid conflicting scroll animations.
class _DocumentScrollableScope extends InheritedWidget {
  const _DocumentScrollableScope({required super.child});

  /// Returns `true` when a [DocumentScrollable] ancestor is present.
  static bool isActive(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_DocumentScrollableScope>() != null;
  }

  @override
  bool updateShouldNotify(_DocumentScrollableScope oldWidget) => false;
}
