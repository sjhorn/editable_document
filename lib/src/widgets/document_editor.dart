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
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../model/attributed_text.dart';
import '../model/document_editing_controller.dart';
import '../model/document_selection.dart';
import '../model/edit_context.dart';
import '../model/block_border.dart';
import '../model/edit_request.dart';
import '../model/mutable_document.dart';
import '../model/node_position.dart';
import '../model/paragraph_node.dart';
import '../model/table_node.dart';
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
import 'document_status_bar.dart';
import 'gestures/document_mouse_interactor.dart';
import 'properties/document_property_panel.dart';
import 'properties/document_settings_panel.dart';
import 'theme/document_theme.dart';
import 'toolbar/document_format_toggle.dart';
import 'toolbar/document_toolbar.dart';
import 'toolbar/table_context_toolbar.dart';

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
///
/// ## Built-in toolbar and panels
///
/// Enable the built-in [DocumentToolbar] (on by default) and opt-in to the
/// block property panel and document settings panel:
///
/// ```dart
/// DocumentEditor(
///   showToolbar: true,
///   showPropertyPanel: true,
///   showSettingsPanel: true,
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
    this.showTableToolbar = true,
    this.showStatusBar = true,
    this.showBlockCount = true,
    this.showWordCount = true,
    this.showCharCount = true,
    this.showCurrentBlockType = true,
    this.statusBarTrailing,
    this.showToolbar = true,
    this.showFormatting = true,
    this.showBlockTypes = true,
    this.showAlignment = true,
    this.showInsert = true,
    this.showFont = true,
    this.showColor = true,
    this.showUndoRedo = true,
    this.showIndent = true,
    this.toolbarLeading,
    this.toolbarTrailing,
    this.showPropertyPanel = false,
    this.showSettingsPanel = false,
    this.onPickImageFile,
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

  /// Whether a [TableContextToolbar] is shown above the table when the
  /// selection is inside a [TableNode].
  ///
  /// The toolbar provides cell alignment, row/column insert/delete, resize,
  /// and table deletion controls. Defaults to `true`.
  final bool showTableToolbar;

  /// Whether a [DocumentStatusBar] is shown at the bottom of the editor.
  ///
  /// The status bar displays block count, word count, character count, and
  /// the current block type label. Style it via [StatusBarThemeData] in
  /// [DocumentTheme]. Defaults to `true`.
  final bool showStatusBar;

  /// Whether the status bar shows the block count.
  ///
  /// Only relevant when [showStatusBar] is `true`. Defaults to `true`.
  final bool showBlockCount;

  /// Whether the status bar shows the word count.
  ///
  /// Only relevant when [showStatusBar] is `true`. Defaults to `true`.
  final bool showWordCount;

  /// Whether the status bar shows the character count.
  ///
  /// Only relevant when [showStatusBar] is `true`. Defaults to `true`.
  final bool showCharCount;

  /// Whether the status bar shows the current block type label.
  ///
  /// Only relevant when [showStatusBar] is `true`. Defaults to `true`.
  final bool showCurrentBlockType;

  /// Optional widgets appended at the trailing end of the status bar.
  ///
  /// Only relevant when [showStatusBar] is `true`.
  final List<Widget>? statusBarTrailing;

  /// Whether a [DocumentToolbar] is shown above the editor.
  ///
  /// Defaults to `true`. Set to `false` to hide the built-in toolbar entirely.
  final bool showToolbar;

  /// Whether the inline formatting bar is shown in the toolbar.
  ///
  /// Forwarded to [DocumentToolbar.showFormatting]. Only relevant when
  /// [showToolbar] is `true`. Defaults to `true`.
  final bool showFormatting;

  /// Whether the block type bar is shown in the toolbar.
  ///
  /// Forwarded to [DocumentToolbar.showBlockTypes]. Only relevant when
  /// [showToolbar] is `true`. Defaults to `true`.
  final bool showBlockTypes;

  /// Whether the text alignment bar is shown in the toolbar.
  ///
  /// Forwarded to [DocumentToolbar.showAlignment]. Only relevant when
  /// [showToolbar] is `true`. Defaults to `true`.
  final bool showAlignment;

  /// Whether the insert bar is shown in the toolbar.
  ///
  /// Forwarded to [DocumentToolbar.showInsert]. Only relevant when
  /// [showToolbar] is `true`. Defaults to `true`.
  final bool showInsert;

  /// Whether the font bar is shown in the toolbar.
  ///
  /// Forwarded to [DocumentToolbar.showFont]. Only relevant when
  /// [showToolbar] is `true`. Defaults to `true`.
  final bool showFont;

  /// Whether the color bar is shown in the toolbar.
  ///
  /// Forwarded to [DocumentToolbar.showColor]. Only relevant when
  /// [showToolbar] is `true`. Defaults to `true`.
  final bool showColor;

  /// Whether the undo/redo bar is shown in the toolbar.
  ///
  /// Forwarded to [DocumentToolbar.showUndoRedo]. Only relevant when
  /// [showToolbar] is `true`. Defaults to `true`.
  final bool showUndoRedo;

  /// Whether the indent bar is shown in the toolbar.
  ///
  /// Forwarded to [DocumentToolbar.showIndent]. Only relevant when
  /// [showToolbar] is `true`. Defaults to `true`.
  final bool showIndent;

  /// An optional widget placed at the leading end of the toolbar.
  ///
  /// Only relevant when [showToolbar] is `true`.
  final Widget? toolbarLeading;

  /// An optional widget placed at the trailing end of the toolbar.
  ///
  /// Panel toggle buttons (block properties, settings) are appended after
  /// this widget when [showPropertyPanel] or [showSettingsPanel] is `true`.
  /// Only relevant when [showToolbar] is `true`.
  final Widget? toolbarTrailing;

  /// Whether the block property panel toggle is available.
  ///
  /// When `true`, a toggle button appears in the toolbar that opens a
  /// [DocumentPropertyPanel] showing editors for the currently selected block.
  /// Defaults to `false` (opt-in).
  final bool showPropertyPanel;

  /// Whether the document settings panel toggle is available.
  ///
  /// When `true`, a toggle button appears in the toolbar that opens a
  /// [DocumentSettingsPanel] for document-wide settings such as block spacing,
  /// line height, padding, and line numbers. Defaults to `false` (opt-in).
  final bool showSettingsPanel;

  /// Callback invoked when the user requests to pick an image file.
  ///
  /// Used by the [DocumentPropertyPanel] image properties editor. When `null`,
  /// the image file picker button is disabled.
  final VoidCallback? onPickImageFile;

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
      FlagProperty('showTableToolbar', value: showTableToolbar, ifTrue: 'showTableToolbar'),
    );
    properties.add(
      FlagProperty('showStatusBar', value: showStatusBar, ifTrue: 'showStatusBar'),
    );
    properties.add(
      FlagProperty('showBlockCount', value: showBlockCount, ifTrue: 'showBlockCount'),
    );
    properties.add(
      FlagProperty('showWordCount', value: showWordCount, ifTrue: 'showWordCount'),
    );
    properties.add(
      FlagProperty('showCharCount', value: showCharCount, ifTrue: 'showCharCount'),
    );
    properties.add(
      FlagProperty(
        'showCurrentBlockType',
        value: showCurrentBlockType,
        ifTrue: 'showCurrentBlockType',
      ),
    );
    properties.add(
      FlagProperty('showToolbar', value: showToolbar, ifTrue: 'showToolbar'),
    );
    properties.add(
      FlagProperty('showFormatting', value: showFormatting, ifTrue: 'showFormatting'),
    );
    properties.add(
      FlagProperty('showBlockTypes', value: showBlockTypes, ifTrue: 'showBlockTypes'),
    );
    properties.add(
      FlagProperty('showAlignment', value: showAlignment, ifTrue: 'showAlignment'),
    );
    properties.add(FlagProperty('showInsert', value: showInsert, ifTrue: 'showInsert'));
    properties.add(FlagProperty('showFont', value: showFont, ifTrue: 'showFont'));
    properties.add(FlagProperty('showColor', value: showColor, ifTrue: 'showColor'));
    properties.add(FlagProperty('showUndoRedo', value: showUndoRedo, ifTrue: 'showUndoRedo'));
    properties.add(FlagProperty('showIndent', value: showIndent, ifTrue: 'showIndent'));
    properties.add(
      DiagnosticsProperty<Widget?>('toolbarLeading', toolbarLeading, defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<Widget?>('toolbarTrailing', toolbarTrailing, defaultValue: null),
    );
    properties.add(
      FlagProperty('showPropertyPanel', value: showPropertyPanel, ifTrue: 'showPropertyPanel'),
    );
    properties.add(
      FlagProperty('showSettingsPanel', value: showSettingsPanel, ifTrue: 'showSettingsPanel'),
    );
    properties.add(
      ObjectFlagProperty<VoidCallback?>.has('onPickImageFile', onPickImageFile),
    );
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
/// - Panel visibility for the block property panel and document settings panel.
/// - Mutable settings state when [DocumentEditor.showSettingsPanel] is `true`.
class DocumentEditorState extends State<DocumentEditor> with TickerProviderStateMixin {
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
  // Panel state
  // -------------------------------------------------------------------------

  /// Whether the block property panel is currently open.
  bool _showBlockPanel = false;

  /// Whether the document settings panel is currently open.
  bool _showDocumentPanel = false;

  /// Tab controller used when both panels are open simultaneously.
  TabController? _panelTabController;

  // -------------------------------------------------------------------------
  // Settings panel mutable state
  // -------------------------------------------------------------------------

  /// Current block spacing value, mutable when [DocumentEditor.showSettingsPanel] is `true`.
  late double _blockSpacing;

  /// Current default line height value, mutable when [DocumentEditor.showSettingsPanel] is `true`.
  late double? _defaultLineHeight;

  /// Current horizontal document padding, mutable when [DocumentEditor.showSettingsPanel] is `true`.
  late double _documentPaddingH;

  /// Current vertical document padding, mutable when [DocumentEditor.showSettingsPanel] is `true`.
  late double _documentPaddingV;

  /// Current show-line-numbers flag, mutable when [DocumentEditor.showSettingsPanel] is `true`.
  late bool _showLineNumbers;

  /// Current line number alignment, mutable when [DocumentEditor.showSettingsPanel] is `true`.
  late LineNumberAlignment _lineNumberAlignment;

  /// Current line number text style, mutable when [DocumentEditor.showSettingsPanel] is `true`.
  TextStyle? _lineNumberTextStyle;

  /// Current line number background color, mutable when [DocumentEditor.showSettingsPanel] is `true`.
  Color? _lineNumberBackgroundColor;

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
    _effectiveController.document.changes.addListener(_onDocumentChanged);

    _blockSpacing = widget.blockSpacing;
    _defaultLineHeight = widget.style?.height;
    _documentPaddingH = widget.documentPadding.left;
    _documentPaddingV = widget.documentPadding.top;
    _showLineNumbers = widget.showLineNumbers;
    _lineNumberAlignment = widget.lineNumberAlignment;
    _lineNumberTextStyle = widget.lineNumberTextStyle;
    _lineNumberBackgroundColor = widget.lineNumberBackgroundColor;
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
      _internalController!.document.changes.removeListener(_onDocumentChanged);
      _internalController!.dispose();
      _internalController = null;
      newController.addListener(_onControllerChanged);
      newController.document.changes.addListener(_onDocumentChanged);
    } else if (widget.controller == null && oldWidget.controller != null) {
      // Caller has stopped providing a controller — create an internal one.
      _internalController = DocumentEditingController(
        document: MutableDocument([
          ParagraphNode(id: 'p1', text: AttributedText()),
        ]),
      );
      oldController.removeListener(_onControllerChanged);
      oldController.document.changes.removeListener(_onDocumentChanged);
      _internalController!.addListener(_onControllerChanged);
      _internalController!.document.changes.addListener(_onDocumentChanged);
    } else if (!identical(oldController, newController)) {
      oldController.removeListener(_onControllerChanged);
      oldController.document.changes.removeListener(_onDocumentChanged);
      newController.addListener(_onControllerChanged);
      newController.document.changes.addListener(_onDocumentChanged);
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
    _effectiveController.document.changes.removeListener(_onDocumentChanged);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    _internalEditor = null; // UndoableEditor has no dispose method.
    _panelTabController?.dispose();
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

  void _onDocumentChanged() {
    setState(() {
      // Rebuild so the table toolbar and other content reflect document mutations
      // (e.g. border changes, node replacements) that don't trigger controller
      // notifications.
    });
  }

  void _onControllerChanged() {
    // Auto-hide block panel when selection leaves a node.
    if (widget.showPropertyPanel) {
      final sel = _effectiveController.selection;
      final node = sel != null ? _effectiveController.document.nodeById(sel.extent.nodeId) : null;
      if (node == null && _showBlockPanel) {
        _showBlockPanel = false;
        _syncPanelTabController();
      }
    }
    setState(() {
      // Rebuild so overlay builders reflect the latest controller state.
    });
  }

  // -------------------------------------------------------------------------
  // Panel toggle methods
  // -------------------------------------------------------------------------

  /// Toggles the block property panel open or closed.
  void _toggleBlockPanel() {
    setState(() {
      _showBlockPanel = !_showBlockPanel;
      _syncPanelTabController();
    });
    _scheduleTableToolbarRebuild();
  }

  /// Toggles the document settings panel open or closed.
  void _toggleDocumentPanel() {
    setState(() {
      _showDocumentPanel = !_showDocumentPanel;
      _syncPanelTabController();
    });
    _scheduleTableToolbarRebuild();
  }

  /// Schedules a post-frame [setState] when the table toolbar is visible so
  /// that its position is recalculated after the layout has re-flowed.
  ///
  /// After a panel toggle the layout changes size in the same frame that
  /// [build] runs, but [_buildTableToolbar] reads [BoxParentData.offset] from
  /// the previous frame. A second build after layout completes picks up the
  /// correct offsets.
  void _scheduleTableToolbarRebuild() {
    if (!widget.showTableToolbar) return;
    final sel = _effectiveController.selection;
    if (sel == null) return;
    final node = _effectiveController.document.nodeById(sel.extent.nodeId);
    if (node is! TableNode) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// Creates or disposes the [TabController] based on current panel visibility.
  ///
  /// A tab controller is only needed when both panels are open simultaneously.
  void _syncPanelTabController() {
    if (_showBlockPanel && _showDocumentPanel) {
      _panelTabController ??= TabController(length: 2, vsync: this);
    } else {
      _panelTabController?.dispose();
      _panelTabController = null;
    }
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
  // Table toolbar
  // -------------------------------------------------------------------------

  /// Builds a [TableContextToolbar] positioned above the table when the
  /// selection is inside a [TableNode], or [SizedBox.shrink] otherwise.
  Widget _buildTableToolbar() {
    final sel = _effectiveController.selection;
    if (sel == null) return const SizedBox.shrink();
    final node = _effectiveController.document.nodeById(sel.extent.nodeId);
    if (node is! TableNode) return const SizedBox.shrink();
    final extentPos = sel.extent.nodePosition;
    if (extentPos is! TableCellPosition) return const SizedBox.shrink();

    // Determine the selected cell range (base may differ from extent).
    final basePos = sel.base.nodePosition;
    final int baseRow;
    final int baseCol;
    if (basePos is TableCellPosition && sel.base.nodeId == node.id) {
      baseRow = basePos.row;
      baseCol = basePos.col;
    } else {
      baseRow = extentPos.row;
      baseCol = extentPos.col;
    }

    // Normalize so minRow <= maxRow, minCol <= maxCol.
    final minRow = baseRow < extentPos.row ? baseRow : extentPos.row;
    final maxRow = baseRow > extentPos.row ? baseRow : extentPos.row;
    final minCol = baseCol < extentPos.col ? baseCol : extentPos.col;
    final maxCol = baseCol > extentPos.col ? baseCol : extentPos.col;

    // Get the table block's position in document-layout coordinates.
    final component = _layoutKey.currentState?.componentForNode(node.id);
    if (component == null || !component.hasSize) return const SizedBox.shrink();

    final parentData = component.parentData;
    if (parentData is! BoxParentData) return const SizedBox.shrink();
    final tableOffset = parentData.offset;

    return Positioned(
      left: tableOffset.dx,
      top: tableOffset.dy - 36,
      child: TableContextToolbar(
        controller: _effectiveController,
        requestHandler: _effectiveEditor.submit,
        nodeId: node.id,
        minRow: minRow,
        maxRow: maxRow,
        minCol: minCol,
        maxCol: maxCol,
        cellTextAligns: node.cellTextAligns,
        cellVerticalAligns: node.cellVerticalAligns,
        rowCount: node.rowCount,
        columnCount: node.columnCount,
        border: node.border,
        showHorizontalGridLines: node.showHorizontalGridLines,
        showVerticalGridLines: node.showVerticalGridLines,
        onBorderOptionSelected: (option) {
          final BlockBorder? newBorder;
          final bool newShowH;
          final bool newShowV;
          switch (option) {
            case TableBorderOption.noBorder:
              newBorder = null;
              newShowH = false;
              newShowV = false;
            case TableBorderOption.allBorders:
              newBorder = const BlockBorder(style: BlockBorderStyle.solid, color: Color(0xFFCCCCCC));
              newShowH = true;
              newShowV = true;
            case TableBorderOption.outsideBorders:
              newBorder = const BlockBorder(style: BlockBorderStyle.solid, color: Color(0xFFCCCCCC));
              newShowH = false;
              newShowV = false;
            case TableBorderOption.insideBorders:
              newBorder = null;
              newShowH = true;
              newShowV = true;
            case TableBorderOption.horizontalInsideBorders:
              newBorder = null;
              newShowH = true;
              newShowV = false;
            case TableBorderOption.verticalInsideBorders:
              newBorder = null;
              newShowH = false;
              newShowV = true;
          }
          _effectiveEditor.submit(
            ReplaceNodeRequest(
              nodeId: node.id,
              newNode: node.copyWith(
                border: newBorder,
                showHorizontalGridLines: newShowH,
                showVerticalGridLines: newShowV,
              ),
            ),
          );
          _effectiveFocusNode.requestFocus();
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Toolbar builder
  // -------------------------------------------------------------------------

  /// Builds the [DocumentToolbar] with optional panel toggle buttons appended
  /// to the trailing end.
  Widget _buildToolbar() {
    final panelToggles = <Widget>[];

    if (widget.showPropertyPanel) {
      final sel = _effectiveController.selection;
      final hasSelection =
          sel != null && _effectiveController.document.nodeById(sel.extent.nodeId) != null;
      panelToggles.add(
        DocumentFormatToggle(
          icon: Icons.view_sidebar_outlined,
          tooltip: 'Block Properties',
          isActive: _showBlockPanel,
          onPressed: hasSelection ? _toggleBlockPanel : null,
        ),
      );
    }

    if (widget.showSettingsPanel) {
      panelToggles.add(
        DocumentFormatToggle(
          icon: Icons.settings_outlined,
          tooltip: 'Document Settings',
          isActive: _showDocumentPanel,
          onPressed: _toggleDocumentPanel,
        ),
      );
    }

    Widget? effectiveTrailing;
    if (widget.toolbarTrailing != null || panelToggles.isNotEmpty) {
      effectiveTrailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.toolbarTrailing != null) widget.toolbarTrailing!,
          ...panelToggles,
        ],
      );
    }

    return DocumentToolbar(
      controller: _effectiveController,
      requestHandler: _effectiveEditor.submit,
      editor: _effectiveEditor,
      showFormatting: widget.showFormatting,
      showBlockTypes: widget.showBlockTypes,
      showAlignment: widget.showAlignment,
      showInsert: widget.showInsert,
      showFont: widget.showFont,
      showColor: widget.showColor,
      showUndoRedo: widget.showUndoRedo,
      showIndent: widget.showIndent,
      leading: widget.toolbarLeading,
      trailing: effectiveTrailing,
    );
  }

  // -------------------------------------------------------------------------
  // Property panel builder
  // -------------------------------------------------------------------------

  /// Builds the side panel that shows either the block property panel, the
  /// document settings panel, or both in a [TabBarView].
  Widget _buildPropertyPanel() {
    final themeData = DocumentTheme.maybeOf(context);
    final panelWidth = themeData?.propertyPanelTheme?.width ?? 280.0;
    final colorScheme = Theme.of(context).colorScheme;

    final panelDecoration = BoxDecoration(
      color: colorScheme.surfaceContainerLow,
      border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
    );

    if (_showBlockPanel && _showDocumentPanel && _panelTabController != null) {
      return SizedBox(
        width: panelWidth,
        height: double.infinity,
        child: DecoratedBox(
          decoration: panelDecoration,
          child: Column(
            children: [
              TabBar(
                controller: _panelTabController,
                tabs: const [Tab(text: 'Block'), Tab(text: 'Document')],
                labelStyle: Theme.of(context).textTheme.labelSmall,
              ),
              Expanded(
                child: TabBarView(
                  controller: _panelTabController,
                  children: [
                    DocumentPropertyPanel(
                      controller: _effectiveController,
                      requestHandler: _effectiveEditor.submit,
                      width: panelWidth,
                      onPickImageFile: widget.onPickImageFile,
                    ),
                    _buildSettingsPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_showBlockPanel) {
      return SizedBox(
        width: panelWidth,
        height: double.infinity,
        child: DecoratedBox(
          decoration: panelDecoration,
          child: DocumentPropertyPanel(
            controller: _effectiveController,
            requestHandler: _effectiveEditor.submit,
            width: panelWidth,
            onPickImageFile: widget.onPickImageFile,
          ),
        ),
      );
    }

    return SizedBox(
      width: panelWidth,
      height: double.infinity,
      child: DecoratedBox(
        decoration: panelDecoration,
        child: _buildSettingsPanel(),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Settings panel builder
  // -------------------------------------------------------------------------

  /// Builds the [DocumentSettingsPanel] wired to local mutable state.
  Widget _buildSettingsPanel() {
    return DocumentSettingsPanel(
      blockSpacing: _blockSpacing,
      onBlockSpacingChanged: (v) => setState(() => _blockSpacing = v),
      defaultLineHeight: _defaultLineHeight,
      onDefaultLineHeightChanged: (v) => setState(() => _defaultLineHeight = v),
      documentPadding: EdgeInsets.symmetric(
        horizontal: _documentPaddingH,
        vertical: _documentPaddingV,
      ),
      onDocumentPaddingChanged: (v) => setState(() {
        _documentPaddingH = v.left;
        _documentPaddingV = v.top;
      }),
      showLineNumbers: _showLineNumbers,
      onShowLineNumbersChanged: (v) => setState(() => _showLineNumbers = v),
      lineNumberAlignment: _lineNumberAlignment,
      onLineNumberAlignmentChanged: (v) => setState(() => _lineNumberAlignment = v),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scrollableEditor = DocumentScrollable(
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
                style: widget.showSettingsPanel
                    ? widget.style?.copyWith(height: _defaultLineHeight) ??
                        TextStyle(height: _defaultLineHeight)
                    : widget.style,
                textDirection: widget.textDirection,
                textAlign: widget.textAlign,
                readOnly: widget.readOnly,
                autofocus: widget.autofocus,
                textInputAction: widget.textInputAction,
                keyboardType: widget.keyboardType,
                onSelectionChanged: widget.onSelectionChanged,
                componentBuilders: widget.componentBuilders,
                blockSpacing: widget.showSettingsPanel ? _blockSpacing : widget.blockSpacing,
                stylesheet: widget.stylesheet,
                editor: _effectiveEditor,
                scrollPadding: widget.scrollPadding,
                documentPadding: widget.showSettingsPanel
                    ? EdgeInsets.symmetric(
                        horizontal: _documentPaddingH,
                        vertical: _documentPaddingV,
                      )
                    : widget.documentPadding,
                showLineNumbers:
                    widget.showSettingsPanel ? _showLineNumbers : widget.showLineNumbers,
                lineNumberAlignment:
                    widget.showSettingsPanel ? _lineNumberAlignment : widget.lineNumberAlignment,
                lineNumberTextStyle:
                    widget.showSettingsPanel ? _lineNumberTextStyle : widget.lineNumberTextStyle,
                lineNumberBackgroundColor: widget.showSettingsPanel
                    ? _lineNumberBackgroundColor
                    : widget.lineNumberBackgroundColor,
              ),
            ),
            Positioned.fill(
              child: CaretDocumentOverlay(
                controller: _effectiveController,
                layoutKey: _layoutKey,
                showCaret: !widget.readOnly,
              ),
            ),
            if (widget.showTableToolbar) _buildTableToolbar(),
            if (widget.overlayBuilder != null)
              ...widget.overlayBuilder!(context, _effectiveController, _layoutKey),
          ],
        ),
      ),
    );

    final panelVisible = _showBlockPanel || _showDocumentPanel;

    Widget editorRow = panelVisible
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: scrollableEditor),
              _buildPropertyPanel(),
            ],
          )
        : scrollableEditor;

    final statusTheme =
        widget.showStatusBar ? DocumentTheme.maybeOf(context)?.statusBarTheme : null;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showToolbar) _buildToolbar(),
        Expanded(child: editorRow),
        if (widget.showStatusBar)
          Container(
            padding:
                statusTheme?.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: statusTheme?.backgroundColor ?? colorScheme.surfaceContainerHighest,
              border: Border(
                top: statusTheme?.borderSide ?? BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: DefaultTextStyle.merge(
              style: statusTheme?.textStyle ?? const TextStyle(),
              child: DocumentStatusBar(
                controller: _effectiveController,
                showBlockCount: widget.showBlockCount,
                showWordCount: widget.showWordCount,
                showCharCount: widget.showCharCount,
                showCurrentBlockType: widget.showCurrentBlockType,
                trailing: widget.statusBarTrailing,
              ),
            ),
          ),
      ],
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
    properties.add(
      FlagProperty('showBlockPanel', value: _showBlockPanel, ifTrue: 'showBlockPanel'),
    );
    properties.add(
      FlagProperty('showDocumentPanel', value: _showDocumentPanel, ifTrue: 'showDocumentPanel'),
    );
    properties.add(DoubleProperty('blockSpacing', _blockSpacing));
    properties.add(DoubleProperty('documentPaddingH', _documentPaddingH));
    properties.add(DoubleProperty('documentPaddingV', _documentPaddingV));
    properties.add(
      FlagProperty('showLineNumbers', value: _showLineNumbers, ifTrue: 'showLineNumbers'),
    );
    properties.add(
      EnumProperty<LineNumberAlignment>('lineNumberAlignment', _lineNumberAlignment),
    );
  }
}
