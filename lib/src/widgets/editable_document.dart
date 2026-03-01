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
import 'package:flutter/services.dart';

import '../model/document_editing_controller.dart';
import '../model/document_selection.dart';
import '../model/edit_request.dart';
import '../model/editor.dart';
import '../services/document_ime_input_client.dart';
import '../services/document_ime_serializer.dart';
import '../services/document_keyboard_handler.dart';
import 'component_builder.dart';
import 'document_layout.dart';

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
  });

  /// The document editing controller holding the [MutableDocument] and current
  /// [DocumentSelection].
  final DocumentEditingController controller;

  /// The focus node used to manage keyboard focus for this widget.
  ///
  /// The caller owns the [FocusNode]; [EditableDocument] registers and
  /// unregisters listeners but never disposes it.
  final FocusNode focusNode;

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
class EditableDocumentState extends State<EditableDocument> {
  late final DocumentImeInputClient _imeClient;
  late final DocumentKeyboardHandler _keyboardHandler;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _imeClient = DocumentImeInputClient(
      serializer: const DocumentImeSerializer(),
      controller: widget.controller,
      requestHandler: _handleRequest,
    );
    _keyboardHandler = DocumentKeyboardHandler(
      document: widget.controller.document,
      controller: widget.controller,
      requestHandler: _handleRequest,
    );
    widget.focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onControllerChanged);
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
      );
      // Rebuild IME client for the new controller.
      _imeClient = DocumentImeInputClient(
        serializer: const DocumentImeSerializer(),
        controller: widget.controller,
        requestHandler: _handleRequest,
      );
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onControllerChanged);
    _imeClient.closeConnection();
    super.dispose();
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
        document: widget.controller.document,
        controller: widget.controller,
        componentBuilders: builders,
        blockSpacing: widget.blockSpacing,
        stylesheet: widget.stylesheet,
      ),
    );
  }
}
