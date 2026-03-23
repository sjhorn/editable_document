/// [DocumentEditor] — a convenience widget for full-page rich text editors.
///
/// Composes [DocumentScrollable], [DocumentMouseInteractor],
/// [DocumentSelectionOverlay], [EditableDocument], and [CaretDocumentOverlay]
/// into a single widget that eliminates the boilerplate required to build a
/// full-page editor. The internal controller, focus node, and editor are all
/// managed automatically when none are provided by the caller.
///
/// [DocumentEditor] is to full-page editors what [DocumentField] is to form
/// fields — it manages scroll, selection overlays, caret drawing, and the
/// context menu out of the box.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/attributed_text.dart';
import '../model/document_editing_controller.dart';
import '../model/document_selection.dart';
import '../model/edit_context.dart';
import '../model/mutable_document.dart';
import '../model/paragraph_node.dart';
import '../model/undoable_editor.dart';
import '../rendering/render_document_layout.dart';
import '../services/document_clipboard.dart';
import 'block_drag_overlay.dart';
import 'caret_document_overlay.dart';
import 'component_builder.dart';
import 'document_context_menu.dart';
import 'document_field.dart' show DocumentContextMenuBuilder;
import 'document_layout.dart';
import 'document_scrollable.dart';
import 'document_selection_overlay.dart';
import 'editable_document.dart';
import 'gestures/document_mouse_interactor.dart';

// ---------------------------------------------------------------------------
// DocumentEditorOverlayBuilder typedef
// ---------------------------------------------------------------------------

/// Signature for building additional overlay widgets in a [DocumentEditor]'s
/// [Stack].
///
/// The [context] is the editor's build context. [controller] is the effective
/// [DocumentEditingController]. [layoutKey] resolves to the
/// [DocumentLayoutState] so overlay widgets can query block geometry.
///
/// Return a list of widgets that are spread into the editor's [Stack] after
/// the caret overlay. An empty list is valid.
typedef DocumentEditorOverlayBuilder = List<Widget> Function(
  BuildContext context,
  DocumentEditingController controller,
  GlobalKey<DocumentLayoutState> layoutKey,
);

// ---------------------------------------------------------------------------
// DocumentEditor
// ---------------------------------------------------------------------------

/// A full-page rich text editor widget.
///
/// [DocumentEditor] composes [DocumentScrollable], [DocumentMouseInteractor],
/// [DocumentSelectionOverlay], [EditableDocument], and [CaretDocumentOverlay]
/// into a single, opinionated widget. It is the recommended starting point for
/// building a full-page editor screen.
///
/// Like [DocumentField], [DocumentEditor] creates its own
/// [DocumentEditingController], [FocusNode], and [UndoableEditor] when none
/// are supplied by the caller.
///
/// ## Minimal usage
///
/// ```dart
/// DocumentEditor()
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
/// final focusNode = FocusNode();
///
/// DocumentEditor(
///   controller: controller,
///   focusNode: focusNode,
///   autofocus: true,
/// )
/// ```
///
/// ## Custom overlay widgets
///
/// Use [overlayBuilder] to add widgets (e.g. a floating toolbar) above the
/// content without leaving [DocumentEditor]'s scroll and selection management:
///
/// ```dart
/// DocumentEditor(
///   overlayBuilder: (context, controller, layoutKey) {
///     return [MyFloatingToolbar(controller: controller)];
///   },
/// )
/// ```
class DocumentEditor extends StatefulWidget {
  /// Creates a [DocumentEditor].
  ///
  /// All parameters are optional. When [controller] is `null`, an internal
  /// [DocumentEditingController] backed by an empty [MutableDocument] is
  /// created. When [focusNode] is `null`, an internal [FocusNode] is created.
  /// When [editor] is `null`, an internal [UndoableEditor] is created.
  const DocumentEditor({
    super.key,
    this.controller,
    this.focusNode,
    this.editor,
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
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.documentPadding = EdgeInsets.zero,
    this.showLineNumbers = false,
    this.lineNumberAlignment = LineNumberAlignment.top,
    this.lineNumberTextStyle,
    this.lineNumberBackgroundColor,
    this.contentPadding = EdgeInsets.zero,
    this.contextMenuBuilder,
    this.overlayBuilder,
  });

  /// The controller for the document being edited.
  ///
  /// When `null`, [DocumentEditorState] creates and owns its own
  /// [DocumentEditingController] backed by an empty [MutableDocument].
  final DocumentEditingController? controller;

  /// The focus node for this editor.
  ///
  /// When `null`, [DocumentEditorState] creates and owns its own [FocusNode].
  final FocusNode? focusNode;

  /// An optional [UndoableEditor] used to route [EditRequest]s through the
  /// command pipeline including reactions and listeners.
  ///
  /// When `null`, an internal [UndoableEditor] is created and owned by the
  /// state.
  final UndoableEditor? editor;

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
  /// When `true`, the IME connection is not opened on focus and editing
  /// gestures are suppressed. Defaults to `false`.
  final bool readOnly;

  /// Whether this widget requests focus automatically when mounted.
  ///
  /// Defaults to `false`.
  final bool autofocus;

  /// The keyboard action button label shown by the soft keyboard.
  ///
  /// Defaults to [TextInputAction.newline].
  final TextInputAction textInputAction;

  /// The type of keyboard to display for this editor.
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

  /// An optional map of style-key strings to [TextStyle]s forwarded to each
  /// [ComponentBuilder] via [ComponentContext.stylesheet].
  final Map<String, TextStyle>? stylesheet;

  /// Padding around the caret rect applied before computing the auto-scroll
  /// target offset.
  ///
  /// Defaults to `EdgeInsets.all(20.0)`, matching [EditableText.scrollPadding].
  final EdgeInsets scrollPadding;

  /// Inset space around the document content area.
  ///
  /// Forwarded to [EditableDocument.documentPadding]. Defaults to
  /// [EdgeInsets.zero].
  final EdgeInsets documentPadding;

  /// Whether a line-number gutter is rendered alongside each block.
  ///
  /// Defaults to `false`.
  final bool showLineNumbers;

  /// The vertical alignment of each line-number label within its block.
  ///
  /// Defaults to [LineNumberAlignment.top].
  final LineNumberAlignment lineNumberAlignment;

  /// The [TextStyle] used to render line-number labels.
  ///
  /// When `null`, the ambient [DefaultTextStyle] is used.
  final TextStyle? lineNumberTextStyle;

  /// The background fill colour behind the line-number gutter.
  ///
  /// When `null`, the gutter is transparent.
  final Color? lineNumberBackgroundColor;

  /// Padding applied inside [DocumentScrollable] around the scrollable content.
  ///
  /// Use this to add insets between the viewport boundary and the document
  /// layout (e.g. horizontal margins on desktop). Defaults to [EdgeInsets.zero].
  final EdgeInsets contentPadding;

  /// An optional builder for the context menu shown on right-click.
  ///
  /// When `null`, a default [AdaptiveTextSelectionToolbar] with Cut, Copy,
  /// Paste, and Select All buttons is shown. Provide a custom builder to
  /// replace the default menu entirely.
  ///
  /// The builder receives the [BuildContext] of the overlay entry and the
  /// global [Offset] of the right-click position as the primary anchor.
  final DocumentContextMenuBuilder? contextMenuBuilder;

  /// An optional builder for additional overlay widgets placed in the
  /// editor's [Stack] above the caret overlay.
  ///
  /// Return a list of widgets (e.g. a floating table toolbar) that need
  /// access to the [DocumentEditingController] or [DocumentLayoutState].
  /// An empty list is valid.
  final DocumentEditorOverlayBuilder? overlayBuilder;

  @override
  State<DocumentEditor> createState() => DocumentEditorState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController?>(
        'controller',
        controller,
        defaultValue: null,
      ),
    );
    properties.add(DiagnosticsProperty<FocusNode?>('focusNode', focusNode, defaultValue: null));
    properties.add(
      DiagnosticsProperty<UndoableEditor?>('editor', editor, defaultValue: null),
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
    properties.add(DiagnosticsProperty<EdgeInsets>('scrollPadding', scrollPadding));
    properties.add(DiagnosticsProperty<EdgeInsets>('documentPadding', documentPadding));
    properties.add(
      FlagProperty('showLineNumbers', value: showLineNumbers, ifTrue: 'showLineNumbers'),
    );
    properties.add(
      EnumProperty<LineNumberAlignment>('lineNumberAlignment', lineNumberAlignment),
    );
    properties.add(
      DiagnosticsProperty<TextStyle?>('lineNumberTextStyle', lineNumberTextStyle,
          defaultValue: null),
    );
    properties.add(
      ColorProperty('lineNumberBackgroundColor', lineNumberBackgroundColor, defaultValue: null),
    );
    properties.add(DiagnosticsProperty<EdgeInsets>('contentPadding', contentPadding));
    properties.add(
      ObjectFlagProperty<DocumentContextMenuBuilder?>.has(
        'contextMenuBuilder',
        contextMenuBuilder,
      ),
    );
    properties.add(
      ObjectFlagProperty<DocumentEditorOverlayBuilder?>.has(
        'overlayBuilder',
        overlayBuilder,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DocumentEditorState
// ---------------------------------------------------------------------------

/// State object for [DocumentEditor].
///
/// Manages:
/// - Optional internal [DocumentEditingController], [FocusNode], and
///   [UndoableEditor] (when none are supplied by the caller).
/// - Focus change listener to dismiss the context menu on blur.
/// - Controller change listener to drive [setState] for dependent widgets.
/// - [ContextMenuController] for right-click context menus.
class DocumentEditorState extends State<DocumentEditor> {
  // -------------------------------------------------------------------------
  // Keys and links
  // -------------------------------------------------------------------------

  /// A [GlobalKey] for the [DocumentLayout] created inside [EditableDocument].
  ///
  /// Passed as [EditableDocument.layoutKey] so that [CaretDocumentOverlay],
  /// [DocumentScrollable], and [DocumentMouseInteractor] can resolve the
  /// [RenderDocumentLayout] at paint time for geometry queries.
  final _layoutKey = GlobalKey<DocumentLayoutState>();

  /// A [GlobalKey] for the [BlockDragOverlay] in [DocumentSelectionOverlay].
  ///
  /// Shared between [DocumentSelectionOverlay] (which owns the
  /// [BlockDragOverlay]) and [DocumentMouseInteractor] (which calls the
  /// overlay's methods during drag events).
  final _blockDragOverlayKey = GlobalKey<BlockDragOverlayState>();

  /// Layer links for selection handle overlay positioning.
  final _startHandleLayerLink = LayerLink();

  /// Layer link for the end selection handle overlay positioning.
  final _endHandleLayerLink = LayerLink();

  // -------------------------------------------------------------------------
  // Effective accessors
  // -------------------------------------------------------------------------

  /// The effective controller — caller-supplied or internal.
  DocumentEditingController get _effectiveController => widget.controller ?? _internalController!;

  /// The effective focus node — caller-supplied or internal.
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode!;

  /// The effective editor — caller-supplied or internal.
  ///
  /// Never null: an internal [UndoableEditor] is created when `widget.editor`
  /// is `null` so that IME-originated requests are never silently dropped.
  UndoableEditor get _effectiveEditor => widget.editor ?? _internalEditor!;

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  DocumentEditingController? _internalController;
  FocusNode? _internalFocusNode;
  UndoableEditor? _internalEditor;

  /// Clipboard service — stateless, safe to hold as a field.
  final _clipboard = const DocumentClipboard();

  /// Controls the visibility of the right-click context menu.
  final _contextMenuController = ContextMenuController();

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
  void didUpdateWidget(DocumentEditor oldWidget) {
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
    _contextMenuController.remove();
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
    if (!_effectiveFocusNode.hasFocus) {
      _contextMenuController.remove();
    }
  }

  void _onControllerChanged() {
    setState(() {
      // Rebuild so overlay builders reflect the latest controller state.
    });
  }

  // -------------------------------------------------------------------------
  // Context menu
  // -------------------------------------------------------------------------

  /// Shows the context menu anchored at [globalPosition].
  ///
  /// Delegates to [DocumentEditor.contextMenuBuilder] when one is provided;
  /// otherwise shows the default [AdaptiveTextSelectionToolbar] built from
  /// [defaultDocumentContextMenuButtonItems].
  void _showContextMenu(Offset globalPosition) {
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (BuildContext menuContext) {
        if (widget.contextMenuBuilder != null) {
          return widget.contextMenuBuilder!(menuContext, globalPosition);
        }
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: TextSelectionToolbarAnchors(primaryAnchor: globalPosition),
          buttonItems: defaultDocumentContextMenuButtonItems(
            controller: _effectiveController,
            clipboard: _clipboard,
            requestHandler: _effectiveEditor.submit,
          ).map((item) {
            final originalPressed = item.onPressed;
            return ContextMenuButtonItem(
              label: item.label,
              onPressed: originalPressed == null
                  ? null
                  : () {
                      _contextMenuController.remove();
                      originalPressed();
                    },
            );
          }).toList(),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DocumentScrollable(
      controller: _effectiveController,
      layoutKey: _layoutKey,
      contentPadding: widget.contentPadding,
      child: DocumentMouseInteractor(
        controller: _effectiveController,
        layoutKey: _layoutKey,
        document: _effectiveController.document,
        focusNode: _effectiveFocusNode,
        onSecondaryTapDown: widget.readOnly ? null : _showContextMenu,
        blockDragOverlayKey: widget.readOnly ? null : _blockDragOverlayKey,
        child: Stack(
          children: [
            DocumentSelectionOverlay(
              controller: _effectiveController,
              layoutKey: _layoutKey,
              startHandleLayerLink: _startHandleLayerLink,
              endHandleLayerLink: _endHandleLayerLink,
              showCaret: false,
              document: _effectiveController.document,
              editor: widget.readOnly ? null : _effectiveEditor,
              blockDragOverlayKey: widget.readOnly ? null : _blockDragOverlayKey,
              child: EditableDocument(
                controller: _effectiveController,
                focusNode: _effectiveFocusNode,
                layoutKey: _layoutKey,
                style: widget.style,
                textDirection: widget.textDirection,
                textAlign: widget.textAlign,
                readOnly: widget.readOnly,
                autofocus: widget.autofocus,
                textInputAction: widget.textInputAction,
                keyboardType: widget.keyboardType,
                onSelectionChanged: widget.onSelectionChanged,
                componentBuilders: widget.componentBuilders,
                blockSpacing: widget.blockSpacing,
                stylesheet: widget.stylesheet,
                editor: _effectiveEditor,
                scrollPadding: widget.scrollPadding,
                documentPadding: widget.documentPadding,
                showLineNumbers: widget.showLineNumbers,
                lineNumberAlignment: widget.lineNumberAlignment,
                lineNumberTextStyle: widget.lineNumberTextStyle,
                lineNumberBackgroundColor: widget.lineNumberBackgroundColor,
              ),
            ),
            Positioned.fill(
              child: CaretDocumentOverlay(
                controller: _effectiveController,
                layoutKey: _layoutKey,
                showCaret: !widget.readOnly,
              ),
            ),
            if (widget.overlayBuilder != null)
              ...widget.overlayBuilder!(context, _effectiveController, _layoutKey),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController>(
        'effectiveController',
        _effectiveController,
      ),
    );
    properties.add(
      DiagnosticsProperty<FocusNode>('effectiveFocusNode', _effectiveFocusNode),
    );
    properties.add(
      DiagnosticsProperty<UndoableEditor>('effectiveEditor', _effectiveEditor),
    );
    properties.add(
      FlagProperty(
        'hasInternalController',
        value: _internalController != null,
        ifTrue: 'internalController',
      ),
    );
    properties.add(
      FlagProperty(
        'hasInternalFocusNode',
        value: _internalFocusNode != null,
        ifTrue: 'internalFocusNode',
      ),
    );
    properties.add(
      FlagProperty(
        'hasInternalEditor',
        value: _internalEditor != null,
        ifTrue: 'internalEditor',
      ),
    );
  }
}
