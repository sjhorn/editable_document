/// [EditableDocument] — the primary widget for the editable_document package.
///
/// A drop-in replacement for Flutter's [EditableText] that operates on a
/// block [Document] model instead of a flat [String]. The widget wires
/// together:
///
/// - [DocumentEditingController] — document + selection source of truth.
/// - [DocumentImeInputClient] — bridges the platform IME to the document.
/// - [DocumentKeyboardHandler] — maps [KeyEvent]s to [EditRequest]s.
/// - [DocumentLayout] — renders the block-level components.
///
/// Focus is managed via the caller-supplied [FocusNode]. When focus is gained
/// (and [readOnly] is false) the IME connection is opened; when focus is lost
/// the connection is closed.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../model/document_editing_controller.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/edit_request.dart';
import '../model/editor.dart';
import '../model/node_position.dart';
import '../services/document_autofill_client.dart';
import '../services/document_ime_input_client.dart';
import '../services/document_ime_serializer.dart';
import '../services/document_keyboard_handler.dart';
import '../rendering/render_document_layout.dart';
import '../rendering/render_text_block.dart';
import 'component_builder.dart';
import 'document_layout.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Maximum line height used for vertical-move overshoot calculation.
///
/// Text blocks return `preferredLineHeight` (~14-20px), well under this cap.
/// Binary nodes (images, HRs) return their full node height — clamping
/// prevents enormous jumps that skip intermediate blocks.
const double _kMaxLineHeight = 24.0;

// ---------------------------------------------------------------------------
// EditableDocument
// ---------------------------------------------------------------------------

/// The primary widget for the editable_document package.
///
/// Mirrors the parameter surface of [EditableText] and renders a block
/// [Document] as a vertically stacked sequence of components. Each block is
/// produced by the first [ComponentBuilder] in [componentBuilders] that
/// handles the corresponding [DocumentNode].
///
/// ## Minimal usage
///
/// ```dart
/// final controller = DocumentEditingController(
///   document: MutableDocument([
///     ParagraphNode(id: '1', text: AttributedText('Hello')),
///   ]),
/// );
/// final focusNode = FocusNode();
///
/// EditableDocument(
///   controller: controller,
///   focusNode: focusNode,
/// )
/// ```
///
/// ## readOnly mode
///
/// When [readOnly] is `true`, the IME connection is never opened and keyboard
/// events are not forwarded to [DocumentKeyboardHandler]. The document remains
/// renderable but non-editable.
class EditableDocument extends StatefulWidget {
  /// Creates an [EditableDocument].
  ///
  /// [controller] and [focusNode] are required. All other parameters have
  /// sensible defaults.
  const EditableDocument({
    super.key,
    required this.controller,
    required this.focusNode,
    this.layoutKey,
    this.style,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.readOnly = false,
    this.autofocus = false,
    this.textInputAction = TextInputAction.newline,
    this.keyboardType = TextInputType.multiline,
    this.onChanged,
    this.onSelectionChanged,
    this.componentBuilders,
    this.blockSpacing = 12.0,
    this.stylesheet,
    this.editor,
    this.scrollPadding = const EdgeInsets.all(20.0),
  });

  /// The document editing controller holding the [MutableDocument] and current
  /// [DocumentSelection].
  final DocumentEditingController controller;

  /// The focus node used to manage keyboard focus for this widget.
  ///
  /// The caller owns the [FocusNode]; [EditableDocument] registers and
  /// unregisters listeners but never disposes it.
  final FocusNode focusNode;

  /// An optional [GlobalKey] for the internal [DocumentLayout].
  ///
  /// When provided, the key is attached to the [DocumentLayout] widget so
  /// that external code (such as [DocumentSelectionOverlay] or
  /// [DocumentMouseInteractor]) can query [DocumentLayoutState] geometry.
  /// When `null`, a key is not explicitly set on the layout.
  final GlobalKey<DocumentLayoutState>? layoutKey;

  /// The base [TextStyle] applied to text blocks.
  ///
  /// Individual blocks may override this via the [stylesheet].
  final TextStyle? style;

  /// The text directionality for block layout.
  ///
  /// When `null`, the ambient [Directionality] is used.
  final TextDirection? textDirection;

  /// The text alignment applied to paragraph blocks.
  ///
  /// Defaults to [TextAlign.start].
  final TextAlign textAlign;

  /// Whether the document is read-only.
  ///
  /// When `true`, the IME connection is not opened on focus and keyboard
  /// events are not forwarded to the handler. Defaults to `false`.
  final bool readOnly;

  /// Whether this widget should receive focus automatically when the widget
  /// tree is built.
  ///
  /// Defaults to `false`.
  final bool autofocus;

  /// The keyboard action button label shown by the soft keyboard.
  ///
  /// Defaults to [TextInputAction.newline].
  final TextInputAction textInputAction;

  /// The type of keyboard to use for this text field.
  ///
  /// Defaults to [TextInputType.multiline].
  final TextInputType keyboardType;

  /// Called when the document content changes.
  ///
  /// Not yet implemented — reserved for Phase 6.
  final ValueChanged<String>? onChanged;

  /// Called whenever the document selection changes.
  ///
  /// Receives the new [DocumentSelection], or `null` when the selection is
  /// cleared.
  final ValueChanged<DocumentSelection?>? onSelectionChanged;

  /// The ordered list of [ComponentBuilder]s used to render block nodes.
  ///
  /// When `null`, [defaultComponentBuilders] is used. Prepend custom builders
  /// to override defaults for specific node types.
  final List<ComponentBuilder>? componentBuilders;

  /// The vertical gap in logical pixels between consecutive block children.
  ///
  /// Defaults to `12.0`.
  final double blockSpacing;

  /// An optional map of style-key strings to [TextStyle]s.
  ///
  /// Passed through to [DocumentLayout] and made available to each
  /// [ComponentBuilder] via [ComponentContext.stylesheet].
  final Map<String, TextStyle>? stylesheet;

  /// An optional [Editor] used to route [EditRequest]s through the command
  /// pipeline including reactions and listeners.
  ///
  /// When `null`, requests generated by the keyboard handler or IME are
  /// applied directly to [controller] using a minimal built-in handler.
  final Editor? editor;

  /// Padding around the caret to ensure it is not flush against the viewport
  /// edge after auto-scrolling.
  ///
  /// Defaults to `EdgeInsets.all(20.0)`, matching [EditableText.scrollPadding].
  final EdgeInsets scrollPadding;

  @override
  State<EditableDocument> createState() => EditableDocumentState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DocumentEditingController>('controller', controller));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode));
    properties.add(DiagnosticsProperty<TextStyle?>('style', style, defaultValue: null));
    properties
        .add(EnumProperty<TextDirection?>('textDirection', textDirection, defaultValue: null));
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign));
    properties.add(FlagProperty('readOnly', value: readOnly, ifTrue: 'readOnly'));
    properties.add(FlagProperty('autofocus', value: autofocus, ifTrue: 'autofocus'));
    properties.add(EnumProperty<TextInputAction>('textInputAction', textInputAction));
    properties.add(DiagnosticsProperty<TextInputType>('keyboardType', keyboardType));
    properties.add(
      ObjectFlagProperty<ValueChanged<String>?>.has('onChanged', onChanged),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<DocumentSelection?>?>.has(
        'onSelectionChanged',
        onSelectionChanged,
      ),
    );
    properties.add(
      DiagnosticsProperty<List<ComponentBuilder>?>(
        'componentBuilders',
        componentBuilders,
        defaultValue: null,
      ),
    );
    properties.add(DoubleProperty('blockSpacing', blockSpacing));
    properties.add(
      DiagnosticsProperty<Map<String, TextStyle>?>('stylesheet', stylesheet, defaultValue: null),
    );
    properties.add(DiagnosticsProperty<Editor?>('editor', editor, defaultValue: null));
    properties.add(DiagnosticsProperty<GlobalKey<DocumentLayoutState>?>('layoutKey', layoutKey));
    properties.add(DiagnosticsProperty<EdgeInsets>('scrollPadding', scrollPadding));
  }
}

// ---------------------------------------------------------------------------
// EditableDocumentState
// ---------------------------------------------------------------------------

/// State object for [EditableDocument].
///
/// Manages:
/// - [DocumentImeInputClient] lifecycle (open/close on focus changes).
/// - [DocumentKeyboardHandler] wiring via [Focus.onKeyEvent].
/// - Selection-change listener forwarded to [EditableDocument.onSelectionChanged].
/// - Auto-scrolling the caret into view on selection change via
///   [_scheduleShowCaretOnScreen].
class EditableDocumentState extends State<EditableDocument> {
  late DocumentImeInputClient _imeClient;
  late DocumentKeyboardHandler _keyboardHandler;
  late DocumentAutofillClient _autofillClient;
  AutofillGroupState? _currentAutofillScope;

  /// Internal [GlobalKey] for [DocumentLayout], used when [widget.layoutKey]
  /// is not provided so that [_scheduleShowCaretOnScreen] can always locate
  /// the render object.
  final _internalLayoutKey = GlobalKey<DocumentLayoutState>();

  /// Returns the effective layout key: the caller-supplied key if provided,
  /// otherwise the internal fallback key.
  GlobalKey<DocumentLayoutState> get _layoutKey => widget.layoutKey ?? _internalLayoutKey;

  bool _showCaretOnScreenScheduled = false;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _autofillClient = DocumentAutofillClient(
      controller: widget.controller,
      serializer: const DocumentImeSerializer(),
      requestHandler: _handleRequest,
    );
    _imeClient = DocumentImeInputClient(
      serializer: const DocumentImeSerializer(),
      controller: widget.controller,
      requestHandler: _handleRequest,
      autofillScopeGetter: () => _currentAutofillScope,
    );
    _keyboardHandler = DocumentKeyboardHandler(
      document: widget.controller.document,
      controller: widget.controller,
      requestHandler: _handleRequest,
      pageMoveResolver: _resolvePageMove,
      verticalMoveResolver: _resolveVerticalMove,
      lineMoveResolver: _resolveLineMove,
    );
    widget.focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAutofillScope();
  }

  @override
  void didUpdateWidget(EditableDocument oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusNode, widget.focusNode)) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      // Rebuild keyboard handler for the new controller/document.
      _keyboardHandler = DocumentKeyboardHandler(
        document: widget.controller.document,
        controller: widget.controller,
        requestHandler: _handleRequest,
        pageMoveResolver: _resolvePageMove,
        verticalMoveResolver: _resolveVerticalMove,
        lineMoveResolver: _resolveLineMove,
      );
      // Rebuild autofill client and IME client for the new controller.
      _autofillClient = DocumentAutofillClient(
        controller: widget.controller,
        serializer: const DocumentImeSerializer(),
        requestHandler: _handleRequest,
      );
      _imeClient = DocumentImeInputClient(
        serializer: const DocumentImeSerializer(),
        controller: widget.controller,
        requestHandler: _handleRequest,
        autofillScopeGetter: () => _currentAutofillScope,
      );
      // Re-register with autofill scope if present.
      if (_currentAutofillScope != null) {
        _currentAutofillScope!.register(_autofillClient);
      }
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _currentAutofillScope?.unregister(_autofillClient.autofillId);
    widget.focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onControllerChanged);
    _imeClient.closeConnection();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Autofill scope
  // -------------------------------------------------------------------------

  /// Updates [_currentAutofillScope] by looking up the ambient [AutofillGroup].
  ///
  /// Called from [didChangeDependencies] whenever the widget's dependencies
  /// may have changed. Unregisters from the old scope and registers with the
  /// new one when the scope changes.
  void _updateAutofillScope() {
    final newScope = AutofillGroup.maybeOf(context);
    if (newScope == _currentAutofillScope) return;

    // Unregister from old scope.
    _currentAutofillScope?.unregister(_autofillClient.autofillId);
    _currentAutofillScope = newScope;

    // Register with new scope.
    _currentAutofillScope?.register(_autofillClient);
  }

  /// The autofill identifier used for scope registration.
  ///
  /// Delegates to [_autofillClient.autofillId].
  String get autofillId => _autofillClient.autofillId;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('autofillId', autofillId));
  }

  // -------------------------------------------------------------------------
  // Focus handling
  // -------------------------------------------------------------------------

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _onFocusGained();
    } else {
      _onFocusLost();
    }
  }

  void _onFocusGained() {
    if (widget.readOnly) return;
    _imeClient.openConnection(
      TextInputConfiguration(
        enableDeltaModel: true,
        inputAction: widget.textInputAction,
        inputType: widget.keyboardType,
        autofillConfiguration: _autofillClient.enabled
            ? _autofillClient.textInputConfiguration.autofillConfiguration
            : AutofillConfiguration.disabled,
      ),
    );
  }

  void _onFocusLost() {
    _imeClient.closeConnection();
  }

  // -------------------------------------------------------------------------
  // Controller change handling
  // -------------------------------------------------------------------------

  void _onControllerChanged() {
    widget.onSelectionChanged?.call(widget.controller.selection);
    // Keep the platform IME in sync with the current selection so that
    // subsequent typing inserts at the correct position.
    _imeClient.syncToIme();
    _scheduleShowCaretOnScreen();
  }

  // -------------------------------------------------------------------------
  // Auto-scroll caret into view
  // -------------------------------------------------------------------------

  /// Schedules a post-frame callback that scrolls the caret rect into view,
  /// padded by [EditableDocument.scrollPadding] on all sides.
  ///
  /// Only one callback is queued at a time; subsequent calls before the frame
  /// fires are no-ops.
  void _scheduleShowCaretOnScreen() {
    if (_showCaretOnScreenScheduled) return;
    _showCaretOnScreenScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _showCaretOnScreenScheduled = false;
      if (!mounted) return;

      final selection = widget.controller.selection;
      if (selection == null) return;

      final layoutState = _layoutKey.currentState;
      if (layoutState == null) return;

      final caretRect = layoutState.rectForDocumentPosition(selection.extent);
      if (caretRect == null) return;

      final renderObject = layoutState.context.findRenderObject();
      if (renderObject == null) return;

      final paddedRect = widget.scrollPadding.inflateRect(caretRect);
      renderObject.showOnScreen(
        rect: paddedRect,
        duration: const Duration(milliseconds: 100),
        curve: Curves.fastOutSlowIn,
      );
    });
  }

  // -------------------------------------------------------------------------
  // Vertical-move resolver (Up/Down arrow — single visual line)
  // -------------------------------------------------------------------------

  /// Resolves a single-line vertical caret movement (Up/Down arrow) by
  /// computing the [DocumentPosition] one visual line above or below [from].
  ///
  /// Returns `null` when the layout is unavailable or the resolved position
  /// equals [from] (indicating the caret is already at the document boundary).
  DocumentPosition? _resolveVerticalMove({
    required DocumentPosition from,
    required bool forward,
  }) {
    final layoutState = _layoutKey.currentState;
    if (layoutState == null) return null;
    final caretRect = layoutState.rectForDocumentPosition(from);
    if (caretRect == null) return null;

    // Clamp: text lines are typically 14-20px; binary nodes (images, HRs)
    // can return their full node height. Cap to prevent enormous jumps.
    final effectiveHeight = caretRect.height.clamp(0.0, _kMaxLineHeight);
    final halfLine = effectiveHeight / 2;
    final targetY = forward ? caretRect.bottom + halfLine : caretRect.top - halfLine;

    final target = layoutState.documentPositionNearestToOffset(
      Offset(caretRect.left, targetY),
    );

    if (!_samePosition(target, from)) return target;

    // The clamped overshoot resolved back to the same position — typically
    // because the probe landed in the current node's padding. Fall back to
    // probing 1px past the node's rendered boundary.
    return _probeNextNode(
      layoutState: layoutState,
      from: from,
      forward: forward,
      probeX: caretRect.left,
    );
  }

  /// Probes past the current node's boundary to find the adjacent node.
  ///
  /// Probes just past the midpoint of the gap between the current node and
  /// its neighbour (using `blockSpacing / 2 + 1` as the offset) so that the
  /// nearest-position resolver picks the neighbour rather than the current
  /// node.
  ///
  /// Returns `null` when the caret is already at the document boundary.
  DocumentPosition? _probeNextNode({
    required DocumentLayoutState layoutState,
    required DocumentPosition from,
    required bool forward,
    required double probeX,
  }) {
    final component = layoutState.componentForNode(from.nodeId);
    if (component == null) return null;
    final parentData = component.parentData;
    if (parentData is! DocumentBlockParentData) return null;

    final nodeTop = parentData.offset.dy;
    final nodeBottom = nodeTop + component.size.height;

    // Probe just past the midpoint of the inter-block gap so the
    // nearest-position resolver favours the neighbouring node.
    final blockSpacing = layoutState.renderObject?.blockSpacing ?? 12.0;
    final gap = blockSpacing / 2 + 1;
    final probeY = forward ? nodeBottom + gap : nodeTop - gap;

    final target = layoutState.documentPositionNearestToOffset(
      Offset(probeX, probeY),
    );
    if (_samePosition(target, from)) return null;
    return target;
  }

  /// Returns `true` when [a] and [b] refer to the same logical location,
  /// ignoring [TextAffinity] on text nodes.
  static bool _samePosition(DocumentPosition a, DocumentPosition b) {
    if (a.nodeId != b.nodeId) return false;
    final ap = a.nodePosition;
    final bp = b.nodePosition;
    if (ap is TextNodePosition && bp is TextNodePosition) {
      return ap.offset == bp.offset;
    }
    return ap == bp;
  }

  // -------------------------------------------------------------------------
  // Line-move resolver (Cmd/Ctrl+Left/Right — visual line boundary)
  // -------------------------------------------------------------------------

  /// Resolves a visual-line-boundary movement (Cmd+Left/Right on macOS,
  /// Alt+Left/Right on other platforms).
  ///
  /// Returns the [DocumentPosition] at the start (backward) or end (forward)
  /// of the visual line containing [from]. Returns `null` when the layout is
  /// unavailable or the node is not a text block (binary nodes fall back to
  /// node start/end in the keyboard handler).
  DocumentPosition? _resolveLineMove({
    required DocumentPosition from,
    required bool forward,
  }) {
    final layoutState = _layoutKey.currentState;
    if (layoutState == null) return null;
    final component = layoutState.componentForNode(from.nodeId);
    if (component is! RenderTextBlock) return null;

    final textPos = from.nodePosition;
    if (textPos is! TextNodePosition) return null;

    final range = component.getLineBoundary(textPos);
    final targetOffset = forward ? range.end : range.start;
    // When moving forward to a soft line break, use upstream affinity so the
    // caret renders at the trailing edge of the current visual line rather
    // than the leading edge of the next line.
    final affinity = forward ? TextAffinity.upstream : TextAffinity.downstream;
    return DocumentPosition(
      nodeId: from.nodeId,
      nodePosition: TextNodePosition(offset: targetOffset, affinity: affinity),
    );
  }

  // -------------------------------------------------------------------------
  // Page-move resolver
  // -------------------------------------------------------------------------

  /// Resolves a Page Up/Down movement by computing the [DocumentPosition]
  /// one viewport height above or below [from].
  ///
  /// Returns `null` when the layout state is unavailable or the target
  /// offset falls outside the document bounds.
  DocumentPosition? _resolvePageMove({
    required DocumentPosition from,
    required bool forward,
  }) {
    final layoutState = _layoutKey.currentState;
    if (layoutState == null) return null;
    final caretRect = layoutState.rectForDocumentPosition(from);
    if (caretRect == null) return null;
    final renderObject = layoutState.context.findRenderObject();
    if (renderObject is! RenderBox) return null;

    final viewportHeight = _getViewportHeight(renderObject) ?? renderObject.size.height;
    final targetY = forward ? caretRect.top + viewportHeight : caretRect.top - viewportHeight;
    return layoutState.documentPositionNearestToOffset(
      Offset(caretRect.left, targetY),
    );
  }

  /// Walks up the render tree to find the nearest viewport and returns its
  /// height. Returns `null` when there is no viewport ancestor.
  double? _getViewportHeight(RenderObject renderObject) {
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport != null && viewport is RenderBox) {
      return (viewport as RenderBox).size.height;
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Request routing
  // -------------------------------------------------------------------------

  /// Routes an [EditRequest] through [widget.editor] when available, otherwise
  /// applies it directly to the document via [widget.controller].
  void _handleRequest(EditRequest request) {
    if (widget.editor != null) {
      widget.editor!.submit(request);
    }
    // When no editor is provided, requests from the keyboard handler already
    // mutate the controller directly (the handler calls controller.setSelection
    // for navigation). IME-originated requests require an Editor to execute
    // document mutations — without one they are silently dropped. This is
    // acceptable at Phase 5.3; Phase 6 will add a default Editor.
  }

  // -------------------------------------------------------------------------
  // Keyboard event adapter
  // -------------------------------------------------------------------------

  /// Adapts the [Focus.onKeyEvent] callback signature to
  /// [DocumentKeyboardHandler.onKeyEvent].
  ///
  /// In [readOnly] mode, key events are always ignored.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.readOnly) return KeyEventResult.ignored;
    final handled = _keyboardHandler.onKeyEvent(event);
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final builders = widget.componentBuilders ?? defaultComponentBuilders;

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      child: DocumentLayout(
        key: _layoutKey,
        document: widget.controller.document,
        controller: widget.controller,
        componentBuilders: builders,
        blockSpacing: widget.blockSpacing,
        stylesheet: widget.stylesheet,
      ),
    );
  }
}
