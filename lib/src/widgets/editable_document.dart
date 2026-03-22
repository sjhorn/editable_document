/// [EditableDocument] — the primary widget for the editable_document package.
///
/// A drop-in replacement for Flutter's [EditableText] that operates on a
/// block [Document] model instead of a flat [String]. The widget wires
/// together:
///
/// - [DocumentEditingController] — document + selection source of truth.
/// - [DocumentImeInputClient] — bridges the platform IME to the document.
/// - [DefaultDocumentEditingShortcuts] — maps key combos to document intents.
/// - [Actions] — handles document intents via [EditableDocumentState] methods.
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

import '../model/attribution.dart';
import '../model/document_editing_controller.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/edit_request.dart';
import '../model/editor.dart';
import '../model/node_position.dart';
import '../model/text_node.dart';
import '../model/attributed_text.dart';
import '../model/blockquote_node.dart';
import '../model/code_block_node.dart';
import '../model/document.dart';
import '../model/document_node.dart';
import '../model/list_item_node.dart';
import '../model/paragraph_node.dart';
import '../model/table_node.dart';
import '../services/document_autofill_client.dart';
import '../services/document_clipboard.dart';
import '../services/document_ime_input_client.dart';
import '../services/document_ime_serializer.dart';
import '../rendering/render_document_layout.dart';
import '../rendering/render_text_block.dart';
import 'component_builder.dart';
import 'default_document_editing_shortcuts.dart';
import 'document_editing_actions.dart';
import 'document_layout.dart';
import 'document_scrollable.dart';
import 'document_semantics_scope.dart';

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
/// When [readOnly] is `true`, the IME connection is never opened and editing
/// actions are suppressed. The document remains renderable but non-editable.
class EditableDocument extends StatefulWidget {
  /// Creates an [EditableDocument].
  ///
  /// [controller] and [focusNode] are required. All other parameters have
  /// sensible defaults.
  ///
  /// [documentPadding] sets the inset space around the entire content area
  /// (default [EdgeInsets.zero]). [showLineNumbers] controls whether a
  /// line-number gutter is rendered (default `false`). [lineNumberWidth] is
  /// the explicit gutter width in logical pixels (default `0.0` — auto).
  /// [lineNumberTextStyle] is the [TextStyle] for line-number labels (default
  /// `null`). [lineNumberBackgroundColor] is the fill colour behind the gutter
  /// (default `null` — transparent). [lineNumberAlignment] controls the
  /// vertical alignment of each label within its block (default
  /// [LineNumberAlignment.top]). All six are forwarded to [DocumentLayout]
  /// and ultimately to [RenderDocumentLayout].
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
    this.documentPadding = EdgeInsets.zero,
    this.showLineNumbers = false,
    this.lineNumberWidth = 0.0,
    this.lineNumberTextStyle,
    this.lineNumberBackgroundColor,
    this.lineNumberAlignment = LineNumberAlignment.top,
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

  /// The padding inset applied around the document's content area.
  ///
  /// The [EdgeInsets.top] and [EdgeInsets.bottom] values add whitespace above
  /// the first child and below the last child respectively. The
  /// [EdgeInsets.left] and [EdgeInsets.right] values shift all children inward
  /// and reduce each child's available width by the horizontal total.
  ///
  /// Forwarded to [DocumentLayout] and [RenderDocumentLayout.documentPadding].
  /// Defaults to [EdgeInsets.zero].
  final EdgeInsets documentPadding;

  /// Whether to render a line-number gutter on the left side of the content
  /// area.
  ///
  /// When `true`, each non-float block receives a sequential line-number label
  /// in a vertical gutter column. Forwarded to [DocumentLayout] and
  /// [RenderDocumentLayout.showLineNumbers]. Defaults to `false`.
  final bool showLineNumbers;

  /// The explicit gutter width in logical pixels.
  ///
  /// When `0.0` (the default), the width is auto-computed from the child count
  /// and [lineNumberTextStyle]. Supply a positive value to pin the gutter to a
  /// fixed width. Forwarded to [RenderDocumentLayout.lineNumberWidth].
  final double lineNumberWidth;

  /// The [TextStyle] used to render the line-number labels in the gutter.
  ///
  /// When `null` (the default), a built-in fallback style is used. Forwarded
  /// to [RenderDocumentLayout.lineNumberTextStyle].
  final TextStyle? lineNumberTextStyle;

  /// The fill [Color] painted behind the entire gutter column.
  ///
  /// When `null` (the default), no background is drawn. Forwarded to
  /// [RenderDocumentLayout.lineNumberBackgroundColor].
  final Color? lineNumberBackgroundColor;

  /// The vertical alignment of each line-number label relative to its block.
  ///
  /// - [LineNumberAlignment.top] — label aligns with the block's top edge.
  /// - [LineNumberAlignment.middle] — label is centred vertically within the block.
  /// - [LineNumberAlignment.bottom] — label aligns with the block's bottom edge.
  ///
  /// Forwarded to [RenderDocumentLayout.lineNumberAlignment].
  /// Defaults to [LineNumberAlignment.top].
  final LineNumberAlignment lineNumberAlignment;

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
    properties.add(DiagnosticsProperty<EdgeInsets>('documentPadding', documentPadding));
    properties
        .add(FlagProperty('showLineNumbers', value: showLineNumbers, ifTrue: 'showLineNumbers'));
    properties.add(DoubleProperty('lineNumberWidth', lineNumberWidth, defaultValue: 0.0));
    properties.add(
      DiagnosticsProperty<TextStyle?>('lineNumberTextStyle', lineNumberTextStyle,
          defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<Color?>('lineNumberBackgroundColor', lineNumberBackgroundColor,
          defaultValue: null),
    );
    properties.add(EnumProperty<LineNumberAlignment>(
      'lineNumberAlignment',
      lineNumberAlignment,
      defaultValue: LineNumberAlignment.top,
    ));
  }
}

// ---------------------------------------------------------------------------
// EditableDocumentState
// ---------------------------------------------------------------------------

/// State object for [EditableDocument].
///
/// Manages:
/// - [DocumentImeInputClient] lifecycle (open/close on focus changes).
/// - [Actions] and [DefaultDocumentEditingShortcuts] wiring in [build].
/// - Selection-change listener forwarded to [EditableDocument.onSelectionChanged].
/// - Auto-scrolling the caret into view on selection change via
///   `_scheduleShowCaretOnScreen`.
/// - Public navigation, editing, clipboard, and formatting methods that
///   [Action] objects call directly.
class EditableDocumentState extends State<EditableDocument> implements DocumentEditingDelegate {
  late DocumentImeInputClient _imeClient;
  late DocumentAutofillClient _autofillClient;
  AutofillGroupState? _currentAutofillScope;

  /// Stateless clipboard service used by copy/cut/paste handlers.
  final DocumentClipboard _clipboard = const DocumentClipboard();

  /// The actions map wired into the [Actions] widget in [build].
  ///
  /// Initialised in [initState] via [createDocumentEditingActions].
  late Map<Type, Action<Intent>> _actions;

  /// Internal [GlobalKey] for [DocumentLayout], used when `widget.layoutKey`
  /// is not provided so that `_scheduleShowCaretOnScreen` can always locate
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
    _actions = createDocumentEditingActions(() => this);
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
  /// Delegates to `_autofillClient.autofillId`.
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
    // Rebuild so DocumentSemanticsScope reflects the new focus state.
    setState(() {});
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
  ///
  /// When a [DocumentScrollable] ancestor is present, this method is a no-op
  /// because [DocumentScrollable] handles auto-scrolling via
  /// [DocumentScrollableState.bringDocumentPositionIntoView]. Running both
  /// mechanisms simultaneously produces conflicting scroll animations.
  void _scheduleShowCaretOnScreen() {
    if (_showCaretOnScreenScheduled) return;
    _showCaretOnScreenScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _showCaretOnScreenScheduled = false;
      if (!mounted) return;

      // When a DocumentScrollable ancestor manages scrolling, skip the
      // showOnScreen call to avoid conflicting scroll animations.
      if (DocumentScrollable.handlesAutoScroll(context)) return;

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
  // Clipboard handlers
  // -------------------------------------------------------------------------

  /// Copies the selected text to the system clipboard.
  ///
  /// No-op when the selection is `null` or collapsed.
  @override
  void copySelection() {
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) return;
    _clipboard.copy(widget.controller.document, selection);
  }

  /// Cuts the selected text: writes to the clipboard and deletes the selection.
  ///
  /// No-op when [EditableDocument.readOnly] is `true`, or when the selection
  /// is `null` or collapsed.
  @override
  void cutSelection() {
    if (widget.readOnly) return;
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) return;
    _clipboard.cut(widget.controller.document, selection).then((request) {
      if (request != null) _handleRequest(request);
    });
  }

  /// Pastes plain text from the system clipboard at the current caret position.
  ///
  /// If the selection is expanded, the selected content is deleted first, then
  /// the clipboard text is inserted at the resulting collapsed position.
  ///
  /// No-op when [EditableDocument.readOnly] is `true`, when the selection is
  /// `null`, or when the target node is not a [TextNode].
  @override
  void pasteClipboard() {
    if (widget.readOnly) return;
    final selection = widget.controller.selection;
    if (selection == null) return;

    // If the selection is expanded, delete it first so paste always inserts
    // at a collapsed position.
    if (selection.isExpanded) {
      _handleRequest(DeleteContentRequest(selection: selection));
    }

    // After the potential delete the controller carries the updated selection.
    final pasteSelection = widget.controller.selection;
    if (pasteSelection == null) return;
    final pastePos = pasteSelection.extent;
    final node = widget.controller.document.nodeById(pastePos.nodeId);
    if (node == null || node is! TextNode) return;

    final offset = (pastePos.nodePosition as TextNodePosition).offset;
    _clipboard.paste(pastePos.nodeId, offset).then((request) {
      if (request != null) _handleRequest(request);
    });
  }

  /// Selects all content in the document.
  ///
  /// Sets a [DocumentSelection] from the very first position of the first node
  /// to the very last position of the last node.
  ///
  /// No-op when the document is empty.
  @override
  void selectAll() {
    final doc = widget.controller.document;
    if (doc.nodes.isEmpty) return;
    final firstNode = doc.nodes.first;
    final lastNode = doc.nodes.last;
    widget.controller.setSelection(
      DocumentSelection(
        base: DocumentPosition(
          nodeId: firstNode.id,
          nodePosition: firstNode is TextNode
              ? const TextNodePosition(offset: 0)
              : const BinaryNodePosition.upstream(),
        ),
        extent: DocumentPosition(
          nodeId: lastNode.id,
          nodePosition: lastNode is TextNode
              ? TextNodePosition(offset: lastNode.text.text.length)
              : const BinaryNodePosition.downstream(),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Request routing
  // -------------------------------------------------------------------------

  /// Routes an [EditRequest] through `widget.editor` when available, otherwise
  /// applies it directly to the document via `widget.controller`.
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
  // Navigation — public (called by Actions)
  // -------------------------------------------------------------------------

  /// Moves the caret one character forward or backward.
  ///
  /// When [extend] is `true` the selection base stays fixed and only the
  /// extent moves. On an expanded selection with [extend] `false` the
  /// selection collapses to its normalised base (left) when moving backward
  /// or to its normalised extent (right) when moving forward.
  void moveByCharacter({required bool forward, required bool extend}) {
    final selection = widget.controller.selection;
    if (selection == null) return;

    if (!extend && selection.isExpanded) {
      final normalised = selection.normalize(widget.controller.document);
      widget.controller.setSelection(
        DocumentSelection.collapsed(
          position: forward ? normalised.extent : normalised.base,
        ),
      );
      return;
    }

    final extentPos = selection.extent;
    final node = widget.controller.document.nodeById(extentPos.nodeId);
    if (node == null) return;

    final newExtent =
        forward ? _moveCharacterRight(extentPos, node) : _moveCharacterLeft(extentPos, node);
    _updateSelection(newExtent, extend: extend);
  }

  /// Moves the caret to the next or previous word boundary.
  ///
  /// When [extend] is `true` the selection is extended rather than collapsed.
  void moveByWord({required bool forward, required bool extend}) {
    final selection = widget.controller.selection;
    if (selection == null) return;

    final extentPos = selection.extent;
    final node = widget.controller.document.nodeById(extentPos.nodeId);
    if (node == null) return;

    final newExtent = forward ? _moveToWordEnd(extentPos, node) : _moveToWordStart(extentPos, node);
    _updateSelection(newExtent, extend: extend);
  }

  /// Moves the caret to the visual line start or end within the current node.
  ///
  /// Uses [_resolveLineMove] when available (layout-backed line resolver).
  /// Falls back to node start/end when the resolver is unavailable or returns
  /// `null` (e.g. for binary nodes).
  ///
  /// When [extend] is `true` the selection is extended.
  void moveToLineStartOrEnd({required bool forward, required bool extend}) {
    final selection = widget.controller.selection;
    if (selection == null) return;

    final extentPos = selection.extent;
    final node = widget.controller.document.nodeById(extentPos.nodeId);
    if (node == null) return;

    final resolved = _resolveLineMove(from: extentPos, forward: forward);
    final newExtent = resolved ?? (forward ? _endOfNode(node) : _startOfNode(node));
    _updateSelection(newExtent, extend: extend);
  }

  /// Moves the caret one visual line up or down.
  ///
  /// Uses [_resolveVerticalMove] when available. Falls back to block-level
  /// movement (previous/next node start) when unavailable.
  ///
  /// When [extend] is `true` the selection is extended.
  void moveVertically({required bool forward, required bool extend}) {
    final selection = widget.controller.selection;
    if (selection == null) return;

    if (!extend && selection.isExpanded) {
      final normalised = selection.normalize(widget.controller.document);
      widget.controller.setSelection(
        DocumentSelection.collapsed(
          position: forward ? normalised.extent : normalised.base,
        ),
      );
      return;
    }

    final extentPos = selection.extent;
    final node = widget.controller.document.nodeById(extentPos.nodeId);
    if (node == null) return;

    final DocumentPosition newExtent;
    final resolved = _resolveVerticalMove(from: extentPos, forward: forward);
    if (resolved != null) {
      newExtent = resolved;
    } else if (forward) {
      final nextNode = widget.controller.document.nodeAfter(extentPos.nodeId);
      newExtent = nextNode == null ? _endOfNode(node) : _startOfNode(nextNode);
    } else {
      final prevNode = widget.controller.document.nodeBefore(extentPos.nodeId);
      newExtent = prevNode == null ? _startOfNode(node) : _startOfNode(prevNode);
    }

    _updateSelection(newExtent, extend: extend);
  }

  /// Moves the caret to the very start or end of the document.
  ///
  /// When [extend] is `true` the selection is extended.
  void moveToDocumentStartOrEnd({required bool forward, required bool extend}) {
    final selection = widget.controller.selection;
    if (selection == null) return;

    final doc = widget.controller.document;
    if (doc.nodes.isEmpty) return;

    final newExtent = forward ? _endOfNode(doc.nodes.last) : _startOfNode(doc.nodes.first);
    _updateSelection(newExtent, extend: extend);
  }

  /// Moves the caret to the start or end of the current node.
  ///
  /// When [extend] is `true` the selection is extended.
  void moveToNodeStartOrEnd({required bool forward, required bool extend}) {
    final selection = widget.controller.selection;
    if (selection == null) return;

    final extentPos = selection.extent;
    final node = widget.controller.document.nodeById(extentPos.nodeId);
    if (node == null) return;

    final newExtent = forward ? _endOfNode(node) : _startOfNode(node);
    _updateSelection(newExtent, extend: extend);
  }

  /// Moves the caret one viewport height up or down.
  ///
  /// Uses [_resolvePageMove]. When unavailable this is a no-op.
  ///
  /// When [extend] is `true` the selection is extended.
  void moveByPage({required bool forward, required bool extend}) {
    final selection = widget.controller.selection;
    if (selection == null) return;

    final resolved = _resolvePageMove(from: selection.extent, forward: forward);
    if (resolved == null) return;
    _updateSelection(resolved, extend: extend);
  }

  /// Moves the caret to the start of the current node (Home key).
  ///
  /// For table cells, moves to the start of the current cell. When
  /// [extend] is `true` the selection is extended.
  void moveHome({required bool extend}) {
    final selection = widget.controller.selection;
    if (selection == null) return;

    final extentPos = selection.extent;
    final node = widget.controller.document.nodeById(extentPos.nodeId);
    if (node == null) return;

    DocumentPosition newExtent;
    if (node is TableNode && extentPos.nodePosition is TableCellPosition) {
      final cellPos = extentPos.nodePosition as TableCellPosition;
      newExtent = DocumentPosition(
        nodeId: node.id,
        nodePosition: cellPos.copyWith(offset: 0),
      );
    } else {
      newExtent = _startOfNode(node);
    }

    _updateSelection(newExtent, extend: extend);
  }

  /// Moves the caret to the end of the current node (End key).
  ///
  /// For table cells, moves to the end of the current cell. When
  /// [extend] is `true` the selection is extended.
  void moveEnd({required bool extend}) {
    final selection = widget.controller.selection;
    if (selection == null) return;

    final extentPos = selection.extent;
    final node = widget.controller.document.nodeById(extentPos.nodeId);
    if (node == null) return;

    DocumentPosition newExtent;
    if (node is TableNode && extentPos.nodePosition is TableCellPosition) {
      final cellPos = extentPos.nodePosition as TableCellPosition;
      newExtent = DocumentPosition(
        nodeId: node.id,
        nodePosition: cellPos.copyWith(
          offset: node.cellAt(cellPos.row, cellPos.col).text.length,
        ),
      );
    } else {
      newExtent = _endOfNode(node);
    }

    _updateSelection(newExtent, extend: extend);
  }

  // -------------------------------------------------------------------------
  // Editing — public (called by Actions)
  // -------------------------------------------------------------------------

  /// Collapses the current selection to its extent position.
  ///
  /// No-op when [EditableDocument.readOnly] is `true`, when the selection is
  /// `null`, or when the selection is already collapsed.
  void collapseSelection() {
    if (widget.readOnly) return;
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) return;
    widget.controller.setSelection(
      DocumentSelection.collapsed(position: selection.extent),
    );
  }

  /// Deletes the character at the caret, or the entire selection if expanded.
  ///
  /// No-op when [EditableDocument.readOnly] is `true` or when the selection
  /// is `null`.
  void deleteForward() {
    if (widget.readOnly) return;
    final selection = widget.controller.selection;
    if (selection == null) return;

    if (selection.isExpanded) {
      _handleRequest(DeleteContentRequest(selection: selection));
      return;
    }

    final extentPos = selection.extent;
    final node = widget.controller.document.nodeById(extentPos.nodeId);
    if (node == null) return;

    if (node is TextNode) {
      final offset = (extentPos.nodePosition as TextNodePosition).offset;
      if (offset >= node.text.text.length) {
        final nextNode = widget.controller.document.nodeAfter(extentPos.nodeId);
        if (nextNode == null) return;
        _handleRequest(
          MergeNodeRequest(firstNodeId: node.id, secondNodeId: nextNode.id),
        );
      } else {
        _handleRequest(
          DeleteContentRequest(
            selection: DocumentSelection(
              base: extentPos,
              extent: DocumentPosition(
                nodeId: extentPos.nodeId,
                nodePosition: TextNodePosition(offset: offset + 1),
              ),
            ),
          ),
        );
      }
    } else if (node is TableNode) {
      final cellPos = extentPos.nodePosition;
      if (cellPos is! TableCellPosition) return;
      final cellText = node.cellAt(cellPos.row, cellPos.col).text;
      if (cellPos.offset >= cellText.length) return;
      final newText =
          cellText.substring(0, cellPos.offset) + cellText.substring(cellPos.offset + 1);
      _handleRequest(
        UpdateTableCellRequest(
          nodeId: node.id,
          row: cellPos.row,
          col: cellPos.col,
          newText: AttributedText(newText),
          newCursorOffset: cellPos.offset,
        ),
      );
    } else {
      _handleRequest(
        DeleteContentRequest(
          selection: DocumentSelection(
            base: DocumentPosition(
              nodeId: extentPos.nodeId,
              nodePosition: const BinaryNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: extentPos.nodeId,
              nodePosition: const BinaryNodePosition.downstream(),
            ),
          ),
        ),
      );
    }
  }

  /// Deletes the character before the caret, or the entire selection if
  /// expanded.
  ///
  /// Has complex block-aware logic: at offset 0 of an empty list item it
  /// converts the list item to a paragraph; at offset 0 of a text node it
  /// merges with (or deletes) the preceding node.
  ///
  /// No-op when [EditableDocument.readOnly] is `true` or when the selection
  /// is `null`.
  void deleteBackward() {
    if (widget.readOnly) return;
    final selection = widget.controller.selection;
    if (selection == null) return;

    if (selection.isExpanded) {
      _handleRequest(DeleteContentRequest(selection: selection));
      return;
    }

    final extentPos = selection.extent;
    final node = widget.controller.document.nodeById(extentPos.nodeId);
    if (node == null) return;

    if (node is TextNode) {
      final offset = (extentPos.nodePosition as TextNodePosition).offset;
      if (offset == 0) {
        if (node is ListItemNode && node.text.text.isEmpty) {
          _handleRequest(ConvertListItemToParagraphRequest(nodeId: node.id));
        } else if (node is ParagraphNode &&
            node.blockType == ParagraphBlockType.blockquote &&
            node.text.text.isEmpty) {
          _handleRequest(
            ChangeBlockTypeRequest(
              nodeId: node.id,
              newBlockType: ParagraphBlockType.paragraph,
            ),
          );
        } else {
          final prevNode = widget.controller.document.nodeBefore(extentPos.nodeId);
          if (prevNode == null) return;
          if (prevNode is TextNode) {
            _handleRequest(
              MergeNodeRequest(firstNodeId: prevNode.id, secondNodeId: node.id),
            );
          } else {
            _handleRequest(
              DeleteContentRequest(
                selection: DocumentSelection(
                  base: DocumentPosition(
                    nodeId: prevNode.id,
                    nodePosition: const BinaryNodePosition.upstream(),
                  ),
                  extent: DocumentPosition(
                    nodeId: prevNode.id,
                    nodePosition: const BinaryNodePosition.downstream(),
                  ),
                ),
              ),
            );
          }
        }
      } else {
        _handleRequest(
          DeleteContentRequest(
            selection: DocumentSelection(
              base: DocumentPosition(
                nodeId: extentPos.nodeId,
                nodePosition: TextNodePosition(offset: offset - 1),
              ),
              extent: extentPos,
            ),
          ),
        );
      }
    } else if (node is TableNode) {
      final cellPos = extentPos.nodePosition;
      if (cellPos is! TableCellPosition) return;
      if (cellPos.offset == 0) return;
      final cellText = node.cellAt(cellPos.row, cellPos.col).text;
      final newText =
          cellText.substring(0, cellPos.offset - 1) + cellText.substring(cellPos.offset);
      _handleRequest(
        UpdateTableCellRequest(
          nodeId: node.id,
          row: cellPos.row,
          col: cellPos.col,
          newText: AttributedText(newText),
          newCursorOffset: cellPos.offset - 1,
        ),
      );
    } else {
      _handleRequest(
        DeleteContentRequest(
          selection: DocumentSelection(
            base: DocumentPosition(
              nodeId: extentPos.nodeId,
              nodePosition: const BinaryNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: extentPos.nodeId,
              nodePosition: const BinaryNodePosition.downstream(),
            ),
          ),
        ),
      );
    }
  }

  /// Handles the Tab key.
  ///
  /// In a [TableNode], moves to the next cell. In a [ListItemNode], indents
  /// the item. Otherwise, inserts a literal tab character into the current
  /// text node.
  ///
  /// No-op when [EditableDocument.readOnly] is `true`.
  void handleTab() {
    if (widget.readOnly) return;
    final selection = widget.controller.selection;
    if (selection == null) return;
    final node = widget.controller.document.nodeById(selection.extent.nodeId);

    if (node is TableNode) {
      final pos = selection.extent.nodePosition;
      if (pos is! TableCellPosition) return;
      int nextRow = pos.row;
      int nextCol = pos.col + 1;
      if (nextCol >= node.columnCount) {
        nextCol = 0;
        nextRow++;
      }
      if (nextRow >= node.rowCount) return;
      widget.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: node.id,
            nodePosition: TableCellPosition(
              row: nextRow,
              col: nextCol,
              offset: node.cellAt(nextRow, nextCol).text.length,
            ),
          ),
        ),
      );
      return;
    }

    if (node is ListItemNode) {
      _handleRequest(IndentListItemRequest(nodeId: node.id));
      return;
    }

    if (node is TextNode && selection.isCollapsed) {
      final offset = (selection.extent.nodePosition as TextNodePosition).offset;
      _handleRequest(
        InsertTextRequest(
          nodeId: node.id,
          offset: offset,
          text: AttributedText('\t'),
        ),
      );
    }
  }

  /// Handles the Shift+Tab key combination.
  ///
  /// In a [TableNode], moves to the previous cell. In a [ListItemNode],
  /// unindents the item.
  ///
  /// No-op when [EditableDocument.readOnly] is `true`.
  void handleShiftTab() {
    if (widget.readOnly) return;
    final selection = widget.controller.selection;
    if (selection == null) return;
    final node = widget.controller.document.nodeById(selection.extent.nodeId);

    if (node is TableNode) {
      final pos = selection.extent.nodePosition;
      if (pos is! TableCellPosition) return;
      int prevRow = pos.row;
      int prevCol = pos.col - 1;
      if (prevCol < 0) {
        prevCol = node.columnCount - 1;
        prevRow--;
      }
      if (prevRow < 0) return;
      widget.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: node.id,
            nodePosition: TableCellPosition(
              row: prevRow,
              col: prevCol,
              offset: node.cellAt(prevRow, prevCol).text.length,
            ),
          ),
        ),
      );
      return;
    }

    if (node is ListItemNode) {
      _handleRequest(UnindentListItemRequest(nodeId: node.id));
    }
  }

  /// Handles the Enter key.
  ///
  /// Context-sensitive:
  /// - **Table cell** — inserts a newline within the cell.
  /// - **Empty list item** — converts to paragraph.
  /// - **Empty ParagraphNode blockquote** — converts to normal paragraph.
  /// - **BlockquoteNode** — inserts newline, or exits on double-Enter.
  /// - **CodeBlockNode** — inserts newline, or exits on double-Enter.
  /// - Other nodes — no-op (IME handles normal paragraph Enter).
  ///
  /// No-op when [EditableDocument.readOnly] is `true`.
  void handleEnter() {
    if (widget.readOnly) return;
    final selection = widget.controller.selection;
    if (selection == null || selection.isExpanded) return;
    final node = widget.controller.document.nodeById(selection.extent.nodeId);

    if (node is TableNode) {
      final cellPos = selection.extent.nodePosition;
      if (cellPos is! TableCellPosition) return;
      final cellText = node.cellAt(cellPos.row, cellPos.col).text;
      final newText =
          cellText.substring(0, cellPos.offset) + '\n' + cellText.substring(cellPos.offset);
      final newOffset = cellPos.offset + 1;
      _handleRequest(
        UpdateTableCellRequest(
          nodeId: node.id,
          row: cellPos.row,
          col: cellPos.col,
          newText: AttributedText(newText),
          newCursorOffset: newOffset,
        ),
      );
      widget.controller.setSelection(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: node.id,
            nodePosition: TableCellPosition(
              row: cellPos.row,
              col: cellPos.col,
              offset: newOffset,
            ),
          ),
        ),
      );
      return;
    }

    if (node is ListItemNode && node.text.text.isEmpty) {
      _handleRequest(ConvertListItemToParagraphRequest(nodeId: node.id));
      return;
    }

    if (node is ParagraphNode &&
        node.blockType == ParagraphBlockType.blockquote &&
        node.text.text.isEmpty) {
      _handleRequest(
        ChangeBlockTypeRequest(
          nodeId: node.id,
          newBlockType: ParagraphBlockType.paragraph,
        ),
      );
      return;
    }

    if (node is BlockquoteNode) {
      final offset = (selection.extent.nodePosition as TextNodePosition).offset;
      final text = node.text.text;
      if (text.isEmpty) {
        _handleRequest(ExitBlockquoteRequest(nodeId: node.id, splitOffset: 0));
        return;
      }
      if (offset == text.length && text.endsWith('\n')) {
        _handleRequest(
          ExitBlockquoteRequest(
            nodeId: node.id,
            splitOffset: offset,
            removeTrailingNewline: true,
          ),
        );
        return;
      }
      _handleRequest(
        InsertTextRequest(
          nodeId: node.id,
          offset: offset,
          text: AttributedText('\n'),
        ),
      );
      return;
    }

    if (node is CodeBlockNode) {
      final offset = (selection.extent.nodePosition as TextNodePosition).offset;
      final text = node.text.text;
      if (text.isEmpty) {
        _handleRequest(ExitCodeBlockRequest(nodeId: node.id, splitOffset: 0));
        return;
      }
      if (offset == text.length && text.endsWith('\n')) {
        _handleRequest(
          ExitCodeBlockRequest(
            nodeId: node.id,
            splitOffset: offset,
            removeTrailingNewline: true,
          ),
        );
        return;
      }
      _handleRequest(
        InsertTextRequest(
          nodeId: node.id,
          offset: offset,
          text: AttributedText('\n'),
        ),
      );
    }
  }

  /// Handles Shift+Enter.
  ///
  /// Exits a [CodeBlockNode] at the current cursor position. No-op for all
  /// other node types.
  ///
  /// No-op when [EditableDocument.readOnly] is `true`.
  void handleShiftEnter() {
    if (widget.readOnly) return;
    final selection = widget.controller.selection;
    if (selection == null || selection.isExpanded) return;
    final node = widget.controller.document.nodeById(selection.extent.nodeId);
    if (node is! CodeBlockNode) return;

    final offset = (selection.extent.nodePosition as TextNodePosition).offset;
    _handleRequest(ExitCodeBlockRequest(nodeId: node.id, splitOffset: offset));
  }

  // -------------------------------------------------------------------------
  // Formatting — public (called by Actions)
  // -------------------------------------------------------------------------

  /// Toggles [attribution] on the current selection.
  ///
  /// When the selection is collapsed, toggles the [Attribution] on the
  /// [ComposerPreferences] (so the next typed character inherits it).
  ///
  /// When the selection is expanded and the entire selected range already
  /// carries [attribution], removes it. Otherwise, applies it.
  ///
  /// No-op when [EditableDocument.readOnly] is `true` or when the selection
  /// is `null`.
  void toggleAttribution(Attribution attribution) {
    if (widget.readOnly) return;
    final selection = widget.controller.selection;
    if (selection == null) return;

    if (selection.isCollapsed) {
      widget.controller.preferences.toggle(attribution);
      // DocumentEditingController has no public "notify preferences changed"
      // method; notifyListeners is @protected/@visibleForTesting on
      // ChangeNotifier but both classes live in the same package and this is
      // an intentional internal cross-class call.
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      widget.controller.notifyListeners();
      return;
    }

    final fullyApplied =
        isSelectionFullyAttributed(selection, attribution, widget.controller.document);
    if (fullyApplied) {
      _handleRequest(
        RemoveAttributionRequest(selection: selection, attribution: attribution),
      );
    } else {
      _handleRequest(
        ApplyAttributionRequest(selection: selection, attribution: attribution),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Position helpers — private
  // -------------------------------------------------------------------------

  /// Returns the position at the start of [node].
  DocumentPosition _startOfNode(DocumentNode node) {
    if (node is TextNode) {
      return DocumentPosition(
        nodeId: node.id,
        nodePosition: const TextNodePosition(offset: 0),
      );
    }
    if (node is TableNode) {
      return DocumentPosition(
        nodeId: node.id,
        nodePosition: const TableCellPosition(row: 0, col: 0, offset: 0),
      );
    }
    return DocumentPosition(
      nodeId: node.id,
      nodePosition: const BinaryNodePosition.upstream(),
    );
  }

  /// Returns the position at the end of [node].
  DocumentPosition _endOfNode(DocumentNode node) {
    if (node is TextNode) {
      return DocumentPosition(
        nodeId: node.id,
        nodePosition: TextNodePosition(offset: node.text.text.length),
      );
    }
    if (node is TableNode) {
      final lastRow = node.rowCount - 1;
      final lastCol = node.columnCount - 1;
      return DocumentPosition(
        nodeId: node.id,
        nodePosition: TableCellPosition(
          row: lastRow,
          col: lastCol,
          offset: node.cellAt(lastRow, lastCol).text.length,
        ),
      );
    }
    return DocumentPosition(
      nodeId: node.id,
      nodePosition: const BinaryNodePosition.downstream(),
    );
  }

  /// Moves one character to the left within [node], or wraps to the previous
  /// node.
  DocumentPosition _moveCharacterLeft(DocumentPosition pos, DocumentNode node) {
    if (node is TextNode) {
      final offset = (pos.nodePosition as TextNodePosition).offset;
      if (offset > 0) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: offset - 1),
        );
      }
      final prev = widget.controller.document.nodeBefore(node.id);
      if (prev != null) return _endOfNode(prev);
    } else if (node is TableNode && pos.nodePosition is TableCellPosition) {
      final cellPos = pos.nodePosition as TableCellPosition;
      if (cellPos.offset > 0) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: cellPos.copyWith(offset: cellPos.offset - 1),
        );
      }
      int prevRow = cellPos.row;
      int prevCol = cellPos.col - 1;
      if (prevCol < 0) {
        prevCol = node.columnCount - 1;
        prevRow--;
      }
      if (prevRow >= 0) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: TableCellPosition(
            row: prevRow,
            col: prevCol,
            offset: node.cellAt(prevRow, prevCol).text.length,
          ),
        );
      }
      final prev = widget.controller.document.nodeBefore(node.id);
      if (prev != null) return _endOfNode(prev);
    } else if (pos.nodePosition is BinaryNodePosition) {
      final binaryPos = pos.nodePosition as BinaryNodePosition;
      if (binaryPos.type == BinaryNodePositionType.downstream) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: const BinaryNodePosition.upstream(),
        );
      }
      final prev = widget.controller.document.nodeBefore(node.id);
      if (prev != null) return _endOfNode(prev);
    }
    return pos;
  }

  /// Moves one character to the right within [node], or wraps to the next
  /// node.
  DocumentPosition _moveCharacterRight(DocumentPosition pos, DocumentNode node) {
    if (node is TextNode) {
      final offset = (pos.nodePosition as TextNodePosition).offset;
      if (offset < node.text.text.length) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: offset + 1),
        );
      }
      final next = widget.controller.document.nodeAfter(node.id);
      if (next != null) return _startOfNode(next);
    } else if (node is TableNode && pos.nodePosition is TableCellPosition) {
      final cellPos = pos.nodePosition as TableCellPosition;
      final cellText = node.cellAt(cellPos.row, cellPos.col).text;
      if (cellPos.offset < cellText.length) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: cellPos.copyWith(offset: cellPos.offset + 1),
        );
      }
      int nextRow = cellPos.row;
      int nextCol = cellPos.col + 1;
      if (nextCol >= node.columnCount) {
        nextCol = 0;
        nextRow++;
      }
      if (nextRow < node.rowCount) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: TableCellPosition(row: nextRow, col: nextCol, offset: 0),
        );
      }
      final next = widget.controller.document.nodeAfter(node.id);
      if (next != null) return _startOfNode(next);
    } else if (pos.nodePosition is BinaryNodePosition) {
      final binaryPos = pos.nodePosition as BinaryNodePosition;
      if (binaryPos.type == BinaryNodePositionType.upstream) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: const BinaryNodePosition.downstream(),
        );
      }
      final next = widget.controller.document.nodeAfter(node.id);
      if (next != null) return _startOfNode(next);
    }
    return pos;
  }

  /// Moves to the start of the current word (or node start for non-text).
  DocumentPosition _moveToWordStart(DocumentPosition pos, DocumentNode node) {
    if (node is TableNode && pos.nodePosition is TableCellPosition) {
      final cellPos = pos.nodePosition as TableCellPosition;
      final text = node.cellAt(cellPos.row, cellPos.col).text;
      var offset = cellPos.offset;
      while (offset > 0 && text[offset - 1] == ' ') {
        offset--;
      }
      while (offset > 0 && text[offset - 1] != ' ') {
        offset--;
      }
      return DocumentPosition(
        nodeId: node.id,
        nodePosition: cellPos.copyWith(offset: offset),
      );
    }
    if (node is! TextNode) return _startOfNode(node);
    final text = node.text.text;
    var offset = (pos.nodePosition as TextNodePosition).offset;
    while (offset > 0 && text[offset - 1] == ' ') {
      offset--;
    }
    while (offset > 0 && text[offset - 1] != ' ') {
      offset--;
    }
    return DocumentPosition(
      nodeId: node.id,
      nodePosition: TextNodePosition(offset: offset),
    );
  }

  /// Moves to the end of the current word (or node end for non-text).
  DocumentPosition _moveToWordEnd(DocumentPosition pos, DocumentNode node) {
    if (node is TableNode && pos.nodePosition is TableCellPosition) {
      final cellPos = pos.nodePosition as TableCellPosition;
      final text = node.cellAt(cellPos.row, cellPos.col).text;
      var offset = cellPos.offset;
      while (offset < text.length && text[offset] == ' ') {
        offset++;
      }
      while (offset < text.length && text[offset] != ' ') {
        offset++;
      }
      return DocumentPosition(
        nodeId: node.id,
        nodePosition: cellPos.copyWith(offset: offset),
      );
    }
    if (node is! TextNode) return _endOfNode(node);
    final text = node.text.text;
    var offset = (pos.nodePosition as TextNodePosition).offset;
    while (offset < text.length && text[offset] == ' ') {
      offset++;
    }
    while (offset < text.length && text[offset] != ' ') {
      offset++;
    }
    return DocumentPosition(
      nodeId: node.id,
      nodePosition: TextNodePosition(offset: offset),
    );
  }

  // -------------------------------------------------------------------------
  // Selection update helper — private
  // -------------------------------------------------------------------------

  /// Updates the controller's selection to [newExtent].
  ///
  /// When [extend] is `true`, keeps the current base and extends to
  /// [newExtent]. When `false`, collapses to [newExtent].
  void _updateSelection(DocumentPosition newExtent, {required bool extend}) {
    final current = widget.controller.selection;
    if (extend && current != null) {
      widget.controller.setSelection(
        DocumentSelection(base: current.base, extent: newExtent),
      );
    } else {
      widget.controller.setSelection(DocumentSelection.collapsed(position: newExtent));
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final builders = widget.componentBuilders ?? defaultComponentBuilders;

    return DefaultDocumentEditingShortcuts(
      child: Actions(
        actions: _actions,
        child: Focus(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          child: DocumentSemanticsScope(
            isFocused: widget.focusNode.hasFocus,
            isReadOnly: widget.readOnly,
            child: DocumentLayout(
              key: _layoutKey,
              document: widget.controller.document,
              controller: widget.controller,
              componentBuilders: builders,
              blockSpacing: widget.blockSpacing,
              stylesheet: widget.stylesheet,
              documentPadding: widget.documentPadding,
              showLineNumbers: widget.showLineNumbers,
              lineNumberWidth: widget.lineNumberWidth,
              lineNumberTextStyle: widget.lineNumberTextStyle,
              lineNumberBackgroundColor: widget.lineNumberBackgroundColor,
              lineNumberAlignment: widget.lineNumberAlignment,
            ),
          ),
        ),
      ),
    );
  }
}
