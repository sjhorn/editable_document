/// Blinking caret overlay widget for the editable_document package.
///
/// [CaretDocumentOverlay] is a [StatefulWidget] that wraps a
/// [RenderDocumentCaret] in a [LeafRenderObjectWidget] (_CaretRenderWidget)
/// and drives blink animation via a periodic [Timer]. It is the widget-layer
/// complement to [DocumentSelectionOverlay] — while [DocumentSelectionOverlay]
/// owns selection highlights and static caret drawing, [CaretDocumentOverlay]
/// specifically handles the blink rhythm that [EditableText] delivers through
/// an [AnimationController].
///
/// ## Blink behaviour
///
/// - The caret is shown immediately whenever a collapsed selection is set.
/// - A [Timer.periodic] fires every [blinkInterval] to toggle [isCursorVisible].
/// - Calling [CaretDocumentOverlayState.blinkRestart] resets the blink cycle
///   and makes the caret visible immediately (used by keyboard handlers to
///   prevent the caret from blinking away mid-keystroke).
/// - When [showCaret] is `false`, the caret is always hidden and no timer runs.
/// - When the selection is `null` or expanded the caret is hidden.
///
/// ## Geometry computation
///
/// Geometry (the caret rect) is computed at paint time by [RenderDocumentCaret]
/// by querying [RenderDocumentLayout] directly. No post-frame callbacks are
/// needed.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../model/document_editing_controller.dart';
import '../model/document_selection.dart';
import '../rendering/render_document_caret.dart';
import 'document_layout.dart';

// ---------------------------------------------------------------------------
// CaretDocumentOverlay
// ---------------------------------------------------------------------------

/// The half-period of the caret blink animation — matches [EditableText].
const Duration _kCursorBlinkInterval = Duration(milliseconds: 500);

/// A widget that draws a blinking text cursor over a [DocumentLayout].
///
/// [CaretDocumentOverlay] is placed inside a [Stack] alongside (or on top of)
/// a [DocumentLayout].  It passes [layoutKey] to a [RenderDocumentCaret] which
/// queries geometry at paint time, and toggles visibility every [blinkInterval]
/// to produce the familiar blinking cursor.
///
/// ### Typical usage inside a Stack
///
/// ```dart
/// final layoutKey = GlobalKey<DocumentLayoutState>();
///
/// Stack(
///   children: [
///     DocumentLayout(
///       key: layoutKey,
///       document: controller.document,
///       controller: controller,
///       componentBuilders: defaultComponentBuilders,
///     ),
///     Positioned.fill(
///       child: CaretDocumentOverlay(
///         controller: controller,
///         layoutKey: layoutKey,
///       ),
///     ),
///   ],
/// )
/// ```
///
/// ### Blink control
///
/// A keyboard handler may call [CaretDocumentOverlayState.blinkRestart] after
/// each key event so that the caret is always visible while the user is
/// actively typing.
///
/// ### Read-only mode
///
/// Set [showCaret] to `false` to suppress the caret entirely (e.g. for a
/// read-only document viewer).
class CaretDocumentOverlay extends StatefulWidget {
  /// Creates a [CaretDocumentOverlay].
  ///
  /// [controller] is the source of truth for the document selection.
  /// [layoutKey] is used to obtain the [RenderDocumentLayout] that
  /// [RenderDocumentCaret] queries at paint time.
  ///
  /// [caretColor] defaults to opaque black.
  /// [caretWidth] defaults to `2.0` logical pixels.
  /// [cornerRadius] defaults to `1.0` logical pixel.
  /// [blinkInterval] defaults to `_kCursorBlinkInterval` (500 ms), matching
  /// [EditableText]'s blink rate.
  /// [showCaret] defaults to `true`; set to `false` in read-only mode.
  const CaretDocumentOverlay({
    super.key,
    required this.controller,
    required this.layoutKey,
    this.caretColor = const Color(0xFF000000),
    this.caretWidth = 2.0,
    this.cornerRadius = 1.0,
    this.blinkInterval = _kCursorBlinkInterval,
    this.showCaret = true,
  });

  /// The document editing controller that provides selection state.
  final DocumentEditingController controller;

  /// A [GlobalKey] into the [DocumentLayoutState] used to obtain the
  /// [RenderDocumentLayout] for paint-time geometry queries.
  final GlobalKey<DocumentLayoutState> layoutKey;

  /// The fill colour of the caret rectangle.
  ///
  /// Defaults to `Color(0xFF000000)` (opaque black).
  final Color caretColor;

  /// The painted width of the caret in logical pixels.
  ///
  /// Defaults to `2.0`.
  final double caretWidth;

  /// The corner radius applied to all four corners of the caret rectangle.
  ///
  /// Defaults to `1.0`.
  final double cornerRadius;

  /// The half-period of the blink animation.
  ///
  /// The caret toggles between visible and hidden every [blinkInterval].
  /// Defaults to 500 ms, matching [EditableText].
  final Duration blinkInterval;

  /// Whether to paint the caret at all.
  ///
  /// Set to `false` in read-only mode to suppress the caret entirely.
  /// Defaults to `true`.
  final bool showCaret;

  @override
  State<CaretDocumentOverlay> createState() => CaretDocumentOverlayState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController>('controller', controller),
    );
    properties.add(
      DiagnosticsProperty<GlobalKey<DocumentLayoutState>>('layoutKey', layoutKey),
    );
    properties.add(ColorProperty('caretColor', caretColor));
    properties.add(DoubleProperty('caretWidth', caretWidth));
    properties.add(DoubleProperty('cornerRadius', cornerRadius));
    properties.add(
      DiagnosticsProperty<Duration>('blinkInterval', blinkInterval),
    );
    properties.add(FlagProperty('showCaret', value: showCaret, ifTrue: 'showCaret'));
  }
}

// ---------------------------------------------------------------------------
// CaretDocumentOverlayState
// ---------------------------------------------------------------------------

/// State object for [CaretDocumentOverlay].
///
/// Manages the blink timer and reacts to [DocumentEditingController] changes.
///
/// ### Public API
///
/// - [isCursorVisible] — whether the caret is currently in the visible phase
///   of its blink cycle (and all other conditions allow it).
/// - [blinkRestart] — resets the blink cycle so the caret is immediately
///   visible; call this from a keyboard handler after each key event.
class CaretDocumentOverlayState extends State<CaretDocumentOverlay> {
  // ---------------------------------------------------------------------------
  // State fields
  // ---------------------------------------------------------------------------

  /// Whether the caret is in the visible phase of the blink cycle.
  ///
  /// This flag is toggled by `_blinkTimer` every [CaretDocumentOverlay.blinkInterval].
  bool _blinkVisible = true;

  /// The periodic timer that drives the blink.
  Timer? _blinkTimer;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// The current caret bounding rectangle in [DocumentLayout] local coordinates.
  ///
  /// Returns `null` when [CaretDocumentOverlay.showCaret] is `false`, when
  /// there is no selection, or when the selection is expanded.
  ///
  /// Geometry is queried on demand from [DocumentLayoutState] rather than
  /// cached, so the returned rect is always up-to-date with the current layout.
  ///
  /// Exposed for testing via `@visibleForTesting`; production code should
  /// not rely on this getter.
  @visibleForTesting
  // ignore: diagnostic_describe_all_properties
  Rect? get caretRect {
    if (!widget.showCaret) return null;
    final sel = widget.controller.selection;
    if (sel == null || !sel.isCollapsed) return null;
    final layoutState = widget.layoutKey.currentState;
    if (layoutState == null) return null;
    return layoutState.rectForDocumentPosition(sel.extent);
  }

  /// Whether the caret is currently visible.
  ///
  /// Returns `true` only when:
  /// - [CaretDocumentOverlay.showCaret] is `true`, AND
  /// - The controller has a collapsed selection, AND
  /// - The blink cycle is in the visible phase.
  bool get isCursorVisible {
    if (!widget.showCaret) return false;
    final sel = widget.controller.selection;
    if (sel == null || !sel.isCollapsed) return false;
    return _blinkVisible;
  }

  /// Resets the blink cycle so the caret is immediately visible.
  ///
  /// Call this method from a keyboard handler after each key event to prevent
  /// the caret from blinking away while the user is actively typing.
  void blinkRestart() {
    _stopBlink();
    _blinkVisible = true;
    _startBlink();
    // setState is called inside _startBlink implicitly on the next toggle, but
    // we need an immediate rebuild to show the caret right away.
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _updateBlinkState();
  }

  @override
  void didUpdateWidget(CaretDocumentOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }

    _updateBlinkState();
  }

  @override
  void dispose() {
    _stopBlink();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Controller listener
  // ---------------------------------------------------------------------------

  void _onControllerChanged() {
    // Show caret immediately on any selection change, then restart blink.
    _blinkVisible = true;
    _stopBlink();
    _updateBlinkState();
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Starts or stops the blink timer based on the current selection state.
  ///
  /// Timer is active only when `widget.showCaret` is `true` and the selection
  /// is collapsed.
  void _updateBlinkState() {
    final sel = widget.controller.selection;
    final shouldBlink = widget.showCaret && sel != null && sel.isCollapsed;

    if (shouldBlink) {
      if (_blinkTimer == null) {
        _startBlink();
      }
    } else {
      _stopBlink();
    }
  }

  /// Starts a new periodic blink timer.
  void _startBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(widget.blinkInterval, (_) {
      if (!mounted) return;
      setState(() {
        _blinkVisible = !_blinkVisible;
      });
    });
  }

  /// Cancels the blink timer.
  void _stopBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return _CaretRenderWidget(
      layoutKey: widget.layoutKey,
      selection: widget.controller.selection,
      color: widget.caretColor,
      width: widget.caretWidth,
      cornerRadius: widget.cornerRadius,
      visible: _blinkVisible && widget.showCaret,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Rect?>('caretRect', caretRect, defaultValue: null));
    properties.add(FlagProperty('blinkVisible', value: _blinkVisible, ifTrue: 'blinkVisible'));
    properties
        .add(FlagProperty('isCursorVisible', value: isCursorVisible, ifTrue: 'cursorVisible'));
  }
}

// ---------------------------------------------------------------------------
// _CaretRenderWidget
// ---------------------------------------------------------------------------

/// A [LeafRenderObjectWidget] that creates and updates a [RenderDocumentCaret].
///
/// This is an implementation detail of [CaretDocumentOverlay] and is not part
/// of the public API. The render object queries [RenderDocumentLayout] at paint
/// time so no pre-computed geometry is needed in the widget layer.
class _CaretRenderWidget extends LeafRenderObjectWidget {
  const _CaretRenderWidget({
    required this.layoutKey,
    required this.selection,
    required this.color,
    required this.width,
    required this.cornerRadius,
    required this.visible,
    required this.devicePixelRatio,
  });

  final GlobalKey<DocumentLayoutState> layoutKey;
  final DocumentSelection? selection;
  final Color color;
  final double width;
  final double cornerRadius;
  final bool visible;
  final double devicePixelRatio;

  @override
  RenderDocumentCaret createRenderObject(BuildContext context) {
    return RenderDocumentCaret(
      documentLayout: layoutKey.currentState?.renderObject,
      selection: selection,
      color: color,
      width: width,
      cornerRadius: cornerRadius,
      visible: visible,
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
      ..width = width
      ..cornerRadius = cornerRadius
      ..visible = visible
      ..devicePixelRatio = devicePixelRatio;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<GlobalKey<DocumentLayoutState>>('layoutKey', layoutKey),
    );
    properties.add(DiagnosticsProperty<DocumentSelection?>('selection', selection));
    properties.add(ColorProperty('color', color));
    properties.add(DoubleProperty('width', width));
    properties.add(DoubleProperty('cornerRadius', cornerRadius));
    properties.add(FlagProperty('visible', value: visible, ifTrue: 'visible'));
    properties.add(DoubleProperty('devicePixelRatio', devicePixelRatio));
  }
}
