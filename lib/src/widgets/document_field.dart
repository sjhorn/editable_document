/// [DocumentField] — a [TextField]-equivalent for block documents.
///
/// Wraps [EditableDocument] with an [InputDecorator] so that labels, hints,
/// error text, prefixes, suffixes, and counters work identically to
/// [TextField]. Manages its own [FocusNode] and
/// [DocumentEditingController] when none are supplied by the caller.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/attributed_text.dart';
import '../model/document_editing_controller.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/edit_context.dart';
import '../model/editor.dart';
import '../model/mutable_document.dart';
import '../model/node_position.dart';
import '../model/paragraph_node.dart';
import '../model/text_node.dart';
import '../model/undoable_editor.dart';
import 'caret_document_overlay.dart';
import 'component_builder.dart';
import 'document_layout.dart';
import 'editable_document.dart';

// ---------------------------------------------------------------------------
// DocumentField
// ---------------------------------------------------------------------------

/// A [TextField]-equivalent widget for block documents.
///
/// [DocumentField] wraps [EditableDocument] with [InputDecorator] so that
/// the full Material Design input decoration system — labels, hints, error
/// text, prefix/suffix icons, counters, border animation — works out of the
/// box, exactly as it does for [TextField].
///
/// Like [TextField], [DocumentField] creates its own [FocusNode] and
/// [DocumentEditingController] when none are supplied by the caller.
///
/// ## Minimal usage
///
/// ```dart
/// DocumentField(
///   decoration: InputDecoration(
///     labelText: 'Document title',
///     hintText: 'Enter your content here',
///   ),
/// )
/// ```
///
/// ## Controlled usage
///
/// ```dart
/// final controller = DocumentEditingController(
///   document: MutableDocument([
///     ParagraphNode(id: '1', text: AttributedText('Hello')),
///   ]),
/// );
///
/// DocumentField(
///   controller: controller,
///   decoration: const InputDecoration(labelText: 'Body'),
///   maxLength: 500,
/// )
/// ```
class DocumentField extends StatefulWidget {
  /// Creates a [DocumentField].
  ///
  /// All parameters are optional. When [controller] is `null`, an internal
  /// [DocumentEditingController] is created and owned by the state. When
  /// [focusNode] is `null`, an internal [FocusNode] is created and owned by
  /// the state.
  ///
  /// [decoration] defaults to `const InputDecoration()`. Pass `null` to
  /// suppress all decoration.
  const DocumentField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.style,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.readOnly = false,
    this.autofocus = false,
    this.textInputAction = TextInputAction.newline,
    this.keyboardType = TextInputType.multiline,
    this.onSelectionChanged,
    this.componentBuilders,
    this.blockSpacing = 12.0,
    this.stylesheet,
    this.editor,
    this.maxLength,
    this.enabled = true,
    this.scrollPadding = const EdgeInsets.all(20.0),
  });

  /// The controller for the document being edited.
  ///
  /// When `null`, [DocumentFieldState] creates and owns its own
  /// [DocumentEditingController] backed by an empty [MutableDocument].
  final DocumentEditingController? controller;

  /// The focus node for this field.
  ///
  /// When `null`, [DocumentFieldState] creates and owns its own [FocusNode].
  final FocusNode? focusNode;

  /// The decoration to show around the document field.
  ///
  /// Passed to [InputDecorator]. Defaults to `const InputDecoration()`.
  /// Set to `null` to suppress all decoration (no border, no label, etc.).
  final InputDecoration? decoration;

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
  /// events are not forwarded. Defaults to `false`.
  ///
  /// Note: when [enabled] is `false`, [readOnly] is effectively always `true`
  /// regardless of this parameter.
  final bool readOnly;

  /// Whether this widget requests focus automatically when mounted.
  ///
  /// Defaults to `false`.
  final bool autofocus;

  /// The keyboard action button label shown by the soft keyboard.
  ///
  /// Defaults to [TextInputAction.newline].
  final TextInputAction textInputAction;

  /// The type of keyboard to display for this field.
  ///
  /// Defaults to [TextInputType.multiline].
  final TextInputType keyboardType;

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
  /// Passed through to [EditableDocument] and made available to each
  /// [ComponentBuilder] via [ComponentContext.stylesheet].
  final Map<String, TextStyle>? stylesheet;

  /// An optional [Editor] used to route [EditRequest]s through the command
  /// pipeline including reactions and listeners.
  ///
  /// When `null`, requests are applied directly to the [controller].
  final Editor? editor;

  /// The maximum number of characters (across all text nodes) before the
  /// counter changes appearance.
  ///
  /// When non-null, a character counter widget is shown in the decoration
  /// footer displaying `currentLength / maxLength`.
  ///
  /// This parameter does not enforce a hard limit on input — it only controls
  /// the counter display.
  final int? maxLength;

  /// Whether the field is interactive.
  ///
  /// When `false`:
  /// - [InputDecorator] is set to disabled state (greyed out border/text).
  /// - [EditableDocument] is set to `readOnly: true`.
  /// - Focus cannot be acquired.
  ///
  /// Defaults to `true`.
  final bool enabled;

  /// {@macro editable_document.scrollPadding}
  ///
  /// Padding around the caret to ensure it is not flush against the viewport
  /// edge after auto-scrolling.
  ///
  /// Defaults to `EdgeInsets.all(20.0)`. Forwarded to the inner
  /// [EditableDocument].
  final EdgeInsets scrollPadding;

  @override
  State<DocumentField> createState() => DocumentFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController?>('controller', controller, defaultValue: null),
    );
    properties.add(DiagnosticsProperty<FocusNode?>('focusNode', focusNode, defaultValue: null));
    properties.add(
      DiagnosticsProperty<InputDecoration?>('decoration', decoration, defaultValue: null),
    );
    properties.add(DiagnosticsProperty<TextStyle?>('style', style, defaultValue: null));
    properties.add(
      EnumProperty<TextDirection?>('textDirection', textDirection, defaultValue: null),
    );
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign));
    properties.add(FlagProperty('readOnly', value: readOnly, ifTrue: 'readOnly'));
    properties.add(FlagProperty('autofocus', value: autofocus, ifTrue: 'autofocus'));
    properties.add(EnumProperty<TextInputAction>('textInputAction', textInputAction));
    properties.add(DiagnosticsProperty<TextInputType>('keyboardType', keyboardType));
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
    properties.add(IntProperty('maxLength', maxLength, defaultValue: null));
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
    properties.add(DiagnosticsProperty<EdgeInsets>('scrollPadding', scrollPadding));
  }
}

// ---------------------------------------------------------------------------
// DocumentFieldState
// ---------------------------------------------------------------------------

/// State object for [DocumentField].
///
/// Manages:
/// - Optional internal [DocumentEditingController] and [FocusNode] (when none
///   are supplied by the caller).
/// - Focus change listener to update [InputDecorator.isFocused].
/// - Controller change listener to update [InputDecorator.isEmpty] and the
///   character counter.
class DocumentFieldState extends State<DocumentField> {
  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  /// A [GlobalKey] for the [DocumentLayout] created inside [EditableDocument].
  ///
  /// Passed as [EditableDocument.layoutKey] so that [CaretDocumentOverlay]
  /// can resolve the [RenderDocumentLayout] at paint time for geometry
  /// queries without a post-frame callback.
  final _layoutKey = GlobalKey<DocumentLayoutState>();

  /// The effective controller (either caller-supplied or internal).
  DocumentEditingController get _effectiveController => widget.controller ?? _internalController!;

  /// The effective focus node (either caller-supplied or internal).
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode!;

  /// The effective editor (either caller-supplied or internal).
  ///
  /// Never null — an internal [UndoableEditor] is created when [widget.editor]
  /// is `null` so that IME-originated requests are never silently dropped.
  Editor get _effectiveEditor => widget.editor ?? _internalEditor!;

  DocumentEditingController? _internalController;
  FocusNode? _internalFocusNode;
  UndoableEditor? _internalEditor;

  bool _hasFocus = false;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    if (widget.controller == null) {
      _internalController = DocumentEditingController(
        document: MutableDocument([
          ParagraphNode(id: 'p1', text: AttributedText()),
        ]),
      );
    }

    if (widget.editor == null) {
      _internalEditor = UndoableEditor(
        editContext: EditContext(
          document: _effectiveController.document,
          controller: _effectiveController,
        ),
      );
    }

    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }

    _effectiveFocusNode.addListener(_onFocusChanged);
    _effectiveController.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(DocumentField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle controller swap.
    final oldController = oldWidget.controller ?? _internalController!;
    final newController = widget.controller ?? _internalController!;

    if (widget.controller != null && oldWidget.controller == null) {
      // Caller has started providing a controller — dispose the internal one.
      _internalController!.removeListener(_onControllerChanged);
      _internalController!.dispose();
      _internalController = null;
      newController.addListener(_onControllerChanged);
    } else if (widget.controller == null && oldWidget.controller != null) {
      // Caller has stopped providing a controller — create an internal one.
      _internalController = DocumentEditingController(
        document: MutableDocument([
          ParagraphNode(id: 'p1', text: AttributedText()),
        ]),
      );
      oldController.removeListener(_onControllerChanged);
      _internalController!.addListener(_onControllerChanged);
    } else if (!identical(oldController, newController)) {
      oldController.removeListener(_onControllerChanged);
      newController.addListener(_onControllerChanged);
    }

    // Handle editor swap.
    if (widget.editor != null && oldWidget.editor == null) {
      // Caller has started providing an editor — drop the internal one.
      _internalEditor = null;
    } else if (widget.editor == null && oldWidget.editor != null) {
      // Caller has stopped providing an editor — create an internal one.
      _internalEditor = UndoableEditor(
        editContext: EditContext(
          document: _effectiveController.document,
          controller: _effectiveController,
        ),
      );
    } else if (widget.editor == null &&
        oldWidget.controller != widget.controller &&
        _internalEditor != null) {
      // The controller changed while we own the editor: rebuild it so it
      // references the new effective controller's document.
      _internalEditor = UndoableEditor(
        editContext: EditContext(
          document: _effectiveController.document,
          controller: _effectiveController,
        ),
      );
    }

    // Handle focus node swap.
    final oldFocus = oldWidget.focusNode ?? _internalFocusNode!;
    final newFocus = widget.focusNode ?? _internalFocusNode!;

    if (widget.focusNode != null && oldWidget.focusNode == null) {
      // Caller has started providing a focus node — dispose the internal one.
      _internalFocusNode!.removeListener(_onFocusChanged);
      _internalFocusNode!.dispose();
      _internalFocusNode = null;
      newFocus.addListener(_onFocusChanged);
    } else if (widget.focusNode == null && oldWidget.focusNode != null) {
      // Caller has stopped providing a focus node — create an internal one.
      _internalFocusNode = FocusNode();
      oldFocus.removeListener(_onFocusChanged);
      _internalFocusNode!.addListener(_onFocusChanged);
    } else if (!identical(oldFocus, newFocus)) {
      oldFocus.removeListener(_onFocusChanged);
      newFocus.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChanged);
    _effectiveController.removeListener(_onControllerChanged);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    _internalEditor = null; // UndoableEditor has no dispose method.
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Change handlers
  // -------------------------------------------------------------------------

  void _onFocusChanged() {
    setState(() {
      _hasFocus = _effectiveFocusNode.hasFocus;
    });
    if (_hasFocus && _effectiveController.selection == null) {
      final nodes = _effectiveController.document.nodes;
      if (nodes.isNotEmpty) {
        _effectiveController.setSelection(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodes.first.id,
              nodePosition: nodes.first is TextNode
                  ? const TextNodePosition(offset: 0)
                  : const BinaryNodePosition.upstream(),
            ),
          ),
        );
      }
    }
  }

  void _onControllerChanged() {
    setState(() {
      // Rebuild so isEmpty and counter are updated.
    });
  }

  // -------------------------------------------------------------------------
  // Tap handling
  // -------------------------------------------------------------------------

  /// Requests focus when the field is tapped, unless disabled.
  void _handleTap() {
    if (!widget.enabled) return;
    _effectiveFocusNode.requestFocus();
  }

  // -------------------------------------------------------------------------
  // Character count helpers
  // -------------------------------------------------------------------------

  /// Computes the total character count across all [TextNode]s in the document.
  int _computeCharacterCount() {
    int count = 0;
    for (final node in _effectiveController.document.nodes) {
      if (node is TextNode) {
        count += node.text.text.length;
      }
    }
    return count;
  }

  /// Returns `true` when every [TextNode] in the document is empty.
  bool _computeIsEmpty() {
    final nodes = _effectiveController.document.nodes;
    if (nodes.isEmpty) return true;
    for (final node in nodes) {
      if (node is TextNode && node.text.text.isNotEmpty) return false;
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isReadOnly = !widget.enabled || widget.readOnly;
    final bool isEmpty = _computeIsEmpty();

    // Build the counter widget if maxLength is specified.
    Widget? counter;
    if (widget.maxLength != null) {
      final charCount = _computeCharacterCount();
      counter = Text(
        '$charCount / ${widget.maxLength}',
        semanticsLabel: '$charCount of ${widget.maxLength} characters',
      );
    }

    // Resolve the effective decoration, applying enabled/disabled state and
    // the counter widget.
    final InputDecoration effectiveDecoration = (widget.decoration ?? const InputDecoration())
        .applyDefaults(Theme.of(context).inputDecorationTheme)
        .copyWith(
          enabled: widget.enabled,
          counter: counter,
        );

    final child = GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: InputDecorator(
        decoration: effectiveDecoration,
        isFocused: _hasFocus,
        isEmpty: isEmpty,
        child: Stack(
          children: [
            EditableDocument(
              controller: _effectiveController,
              focusNode: _effectiveFocusNode,
              layoutKey: _layoutKey,
              style: widget.style,
              textDirection: widget.textDirection,
              textAlign: widget.textAlign,
              readOnly: isReadOnly,
              autofocus: widget.autofocus,
              textInputAction: widget.textInputAction,
              keyboardType: widget.keyboardType,
              onSelectionChanged: widget.onSelectionChanged,
              componentBuilders: widget.componentBuilders,
              blockSpacing: widget.blockSpacing,
              stylesheet: widget.stylesheet,
              editor: _effectiveEditor,
              scrollPadding: widget.scrollPadding,
            ),
            Positioned.fill(
              child: CaretDocumentOverlay(
                controller: _effectiveController,
                layoutKey: _layoutKey,
                showCaret: !isReadOnly,
              ),
            ),
          ],
        ),
      ),
    );

    return child;
  }
}
