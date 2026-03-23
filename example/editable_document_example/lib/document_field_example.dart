// Copyright 2026 Scott Horn. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

/// Standalone example for [DocumentField] — the TextField equivalent for
/// block documents.
///
/// Demonstrates:
/// - Rich text field with a compact formatting toolbar
/// - Multi-line notes field with character counter
/// - Fixed-height scrollable field with scrollbar
/// - Read-only field with pre-populated content
///
/// Run with: `flutter run -t example/document_field_example.dart`
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:editable_document/editable_document.dart';

void main() {
  runApp(const DocumentFieldExampleApp());
}

/// Root widget for the DocumentField example.
class DocumentFieldExampleApp extends StatelessWidget {
  /// Creates the example app.
  const DocumentFieldExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocumentField Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DocumentFieldDemo(),
    );
  }
}

/// Demonstrates [DocumentField] usage with various configurations.
class DocumentFieldDemo extends StatefulWidget {
  /// Creates the demo screen.
  const DocumentFieldDemo({super.key});

  @override
  State<DocumentFieldDemo> createState() => _DocumentFieldDemoState();
}

class _DocumentFieldDemoState extends State<DocumentFieldDemo> {
  // ---- Rich text field with toolbar ----
  late final MutableDocument _richDocument;
  late final DocumentEditingController _richController;
  late final UndoableEditor _richEditor;
  late final FocusNode _richFocusNode;

  // ---- Multi-line notes field (expands up to max height, then scrolls) ----
  late final MutableDocument _notesDocument;
  late final DocumentEditingController _notesController;
  late final UndoableEditor _notesEditor;
  late final FocusNode _notesFocusNode;
  final _notesLayoutKey = GlobalKey<DocumentLayoutState>();
  final _notesStartHandleLayerLink = LayerLink();
  final _notesEndHandleLayerLink = LayerLink();

  // ---- Fixed-height scrollable field ----
  late final MutableDocument _scrollDocument;
  late final DocumentEditingController _scrollController;
  late final UndoableEditor _scrollEditor;
  late final FocusNode _scrollFocusNode;
  final _scrollLayoutKey = GlobalKey<DocumentLayoutState>();
  final _scrollStartHandleLayerLink = LayerLink();
  final _scrollEndHandleLayerLink = LayerLink();

  // ---- Read-only field ----
  late final MutableDocument _readOnlyDocument;
  late final DocumentEditingController _readOnlyController;

  @override
  void initState() {
    super.initState();

    // Rich text field
    _richDocument = MutableDocument([
      ParagraphNode(
        id: 'r-h1',
        text: AttributedText('Project Notes'),
        blockType: ParagraphBlockType.header2,
      ),
      ParagraphNode(
        id: 'r-p1',
        text: AttributedText('This field has a formatting toolbar above it. '
            'Select text and tap bold, italic, or underline to apply styles.')
          ..applyAttribution(NamedAttribution.bold, 22, 40),
      ),
      ListItemNode(
        id: 'r-li1',
        text: AttributedText('Use the toolbar for inline formatting'),
        type: ListItemType.unordered,
      ),
      ParagraphNode(
        id: 'r-bq1',
        text: AttributedText(
          'DocumentField wraps EditableDocument with InputDecoration.',
        ),
        blockType: ParagraphBlockType.blockquote,
      ),
    ]);
    _richController = DocumentEditingController(document: _richDocument);
    _richEditor = UndoableEditor(
      editContext: EditContext(
        document: _richDocument,
        controller: _richController,
      ),
    );
    _richFocusNode = FocusNode(debugLabel: 'RichTextField');
    _richController.addListener(_onRichChanged);

    // Notes field
    _notesDocument = MutableDocument([
      ParagraphNode(
        id: 'n-p1',
        text: AttributedText('Meeting notes from the design review. '
            'Several items were discussed.'),
      ),
      ParagraphNode(
        id: 'n-p2',
        text: AttributedText('The team agreed on the new API surface. '
            'Next step is to write integration tests.'),
      ),
      CodeBlockNode(
        id: 'n-code',
        text: AttributedText(
          'final field = DocumentField(\n'
          '  controller: controller,\n'
          '  maxLength: 500,\n'
          ');',
        ),
        language: 'dart',
      ),
    ]);
    _notesController = DocumentEditingController(document: _notesDocument);
    _notesEditor = UndoableEditor(
      editContext: EditContext(
        document: _notesDocument,
        controller: _notesController,
      ),
    );
    _notesFocusNode = FocusNode(debugLabel: 'NotesField');

    // Fixed-height scrollable field
    _scrollDocument = MutableDocument([
      ParagraphNode(
        id: 's-h1',
        text: AttributedText('Scrollable Content'),
        blockType: ParagraphBlockType.header2,
      ),
      ParagraphNode(
        id: 's-p1',
        text: AttributedText(
          'This field has a fixed height of 200 pixels. When content '
          'exceeds the available space it scrolls vertically with a '
          'visible scrollbar.',
        ),
      ),
      ListItemNode(
        id: 's-li1',
        text: AttributedText('First item — scroll down to see more'),
        type: ListItemType.unordered,
      ),
      ListItemNode(
        id: 's-li2',
        text: AttributedText('Second item with additional detail'),
        type: ListItemType.unordered,
      ),
      ListItemNode(
        id: 's-li3',
        text: AttributedText('Third item near the bottom'),
        type: ListItemType.unordered,
      ),
      ParagraphNode(
        id: 's-bq1',
        text: AttributedText(
          'Use DocumentScrollable to add scroll behaviour to any '
          'height-constrained document editor.',
        ),
        blockType: ParagraphBlockType.blockquote,
      ),
      ParagraphNode(
        id: 's-p2',
        text: AttributedText(
          'This paragraph sits below the fold — you should only see '
          'it after scrolling.',
        ),
      ),
    ]);
    _scrollController = DocumentEditingController(document: _scrollDocument);
    _scrollEditor = UndoableEditor(
      editContext: EditContext(
        document: _scrollDocument,
        controller: _scrollController,
      ),
    );
    _scrollFocusNode = FocusNode(debugLabel: 'ScrollField');

    // Read-only field
    _readOnlyDocument = MutableDocument([
      ParagraphNode(
        id: 'ro-h1',
        text: AttributedText('Read-Only Content'),
        blockType: ParagraphBlockType.header2,
      ),
      ParagraphNode(
        id: 'ro-p1',
        text: AttributedText('This field is disabled. It displays a '
            'multi-block document that cannot be edited. '
            'Great for previews or published content.'),
      ),
    ]);
    _readOnlyController = DocumentEditingController(
      document: _readOnlyDocument,
    );
  }

  @override
  void dispose() {
    _richController.removeListener(_onRichChanged);
    _richFocusNode.dispose();
    _richController.dispose();
    _notesFocusNode.dispose();
    _notesController.dispose();
    _scrollFocusNode.dispose();
    _scrollController.dispose();
    _readOnlyController.dispose();
    super.dispose();
  }

  void _onRichChanged() {
    setState(() {});
  }

  // --------------------------------------------------------------------------
  // Formatting helpers (for the rich text field toolbar)
  // --------------------------------------------------------------------------

  void _toggleAttribution(Attribution attribution) {
    final sel = _richController.selection;
    if (sel == null || sel.isCollapsed) return;

    final startNode = _richDocument.nodeById(sel.base.nodeId);
    final isApplied = startNode is TextNode &&
        sel.base.nodePosition is TextNodePosition &&
        startNode.text.hasAttributionAt(
          (sel.base.nodePosition as TextNodePosition).offset,
          attribution,
        );

    if (isApplied) {
      _richEditor.submit(RemoveAttributionRequest(
        selection: sel,
        attribution: attribution,
      ));
    } else {
      _richEditor.submit(ApplyAttributionRequest(
        selection: sel,
        attribution: attribution,
      ));
    }
  }

  bool _isAttributionActive(Attribution attribution) {
    final sel = _richController.selection;
    if (sel == null || sel.isCollapsed) return false;
    final node = _richDocument.nodeById(sel.base.nodeId);
    if (node is! TextNode) return false;
    final pos = sel.base.nodePosition;
    if (pos is! TextNodePosition) return false;
    return node.text.hasAttributionAt(pos.offset, attribution);
  }

  // --------------------------------------------------------------------------
  // Mini toolbar
  // --------------------------------------------------------------------------

  Widget _buildMiniToolbar() {
    final sel = _richController.selection;
    final hasExpandedSelection = sel != null && !sel.isCollapsed;
    final colorScheme = Theme.of(context).colorScheme;

    const iconSize = 18.0;
    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size(32, 32),
      padding: const EdgeInsets.all(4),
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Undo / Redo
          IconButton(
            icon: const Icon(Icons.undo, size: iconSize),
            onPressed: _richEditor.canUndo ? () => setState(() => _richEditor.undo()) : null,
            tooltip: 'Undo',
            style: buttonStyle,
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: iconSize),
            onPressed: _richEditor.canRedo ? () => setState(() => _richEditor.redo()) : null,
            tooltip: 'Redo',
            style: buttonStyle,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(height: 24, child: VerticalDivider(width: 1)),
          ),
          // Bold / Italic / Underline
          _FormatToggle(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            isActive: _isAttributionActive(NamedAttribution.bold),
            onPressed:
                hasExpandedSelection ? () => _toggleAttribution(NamedAttribution.bold) : null,
          ),
          _FormatToggle(
            icon: Icons.format_italic,
            tooltip: 'Italic',
            isActive: _isAttributionActive(NamedAttribution.italics),
            onPressed:
                hasExpandedSelection ? () => _toggleAttribution(NamedAttribution.italics) : null,
          ),
          _FormatToggle(
            icon: Icons.format_underlined,
            tooltip: 'Underline',
            isActive: _isAttributionActive(NamedAttribution.underline),
            onPressed:
                hasExpandedSelection ? () => _toggleAttribution(NamedAttribution.underline) : null,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Expandable notes field (grows with content up to maxHeight, then scrolls)
  // --------------------------------------------------------------------------

  Widget _buildExpandableNotesField() {
    final theme = Theme.of(context);
    final effectiveStyle =
        theme.useMaterial3 ? theme.textTheme.bodyLarge! : theme.textTheme.titleMedium!;

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Meeting Notes',
        helperText: 'Grows with content up to 200px, then scrolls',
        border: OutlineInputBorder(),
      ),
      isFocused: _notesFocusNode.hasFocus,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: DefaultTextStyle(
          style: effectiveStyle,
          child: DocumentMouseInteractor(
            controller: _notesController,
            layoutKey: _notesLayoutKey,
            document: _notesDocument,
            focusNode: _notesFocusNode,
            child: Scrollbar(
              child: DocumentScrollable(
                controller: _notesController,
                layoutKey: _notesLayoutKey,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Stack(
                    children: [
                      DocumentSelectionOverlay(
                        controller: _notesController,
                        layoutKey: _notesLayoutKey,
                        startHandleLayerLink: _notesStartHandleLayerLink,
                        endHandleLayerLink: _notesEndHandleLayerLink,
                        showCaret: false,
                        child: EditableDocument(
                          controller: _notesController,
                          focusNode: _notesFocusNode,
                          layoutKey: _notesLayoutKey,
                          editor: _notesEditor,
                        ),
                      ),
                      Positioned.fill(
                        child: CaretDocumentOverlay(
                          controller: _notesController,
                          layoutKey: _notesLayoutKey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Fixed-height scrollable field (assembled from raw components)
  // --------------------------------------------------------------------------

  Widget _buildScrollableField() {
    final theme = Theme.of(context);
    final effectiveStyle =
        theme.useMaterial3 ? theme.textTheme.bodyLarge! : theme.textTheme.titleMedium!;

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Scrollable document',
        helperText: 'Fixed 200px height — content scrolls vertically',
        border: OutlineInputBorder(),
      ),
      isFocused: _scrollFocusNode.hasFocus,
      child: SizedBox(
        height: 200,
        child: DefaultTextStyle(
          style: effectiveStyle,
          child: DocumentMouseInteractor(
            controller: _scrollController,
            layoutKey: _scrollLayoutKey,
            document: _scrollDocument,
            focusNode: _scrollFocusNode,
            child: Scrollbar(
              child: DocumentScrollable(
                controller: _scrollController,
                layoutKey: _scrollLayoutKey,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Stack(
                    children: [
                      DocumentSelectionOverlay(
                        controller: _scrollController,
                        layoutKey: _scrollLayoutKey,
                        startHandleLayerLink: _scrollStartHandleLayerLink,
                        endHandleLayerLink: _scrollEndHandleLayerLink,
                        showCaret: false,
                        child: EditableDocument(
                          controller: _scrollController,
                          focusNode: _scrollFocusNode,
                          layoutKey: _scrollLayoutKey,
                          editor: _scrollEditor,
                        ),
                      ),
                      Positioned.fill(
                        child: CaretDocumentOverlay(
                          controller: _scrollController,
                          layoutKey: _scrollLayoutKey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DocumentField Demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DocumentField wraps EditableDocument with InputDecoration, '
              'just like TextField wraps EditableText.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // --- 1. Rich text field with toolbar ---
            Text(
              'Rich Text Field',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                _buildMiniToolbar(),
                DocumentField(
                  controller: _richController,
                  focusNode: _richFocusNode,
                  editor: _richEditor,
                  decoration: const InputDecoration(
                    hintText: 'Start typing...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(8),
                      ),
                    ),
                  ),
                  onSelectionChanged: (_) => setState(() {}),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- 2. Multi-line notes field (expands up to max height) ---
            Text(
              'Multi-Line Notes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildExpandableNotesField(),
            const SizedBox(height: 32),

            // --- 3. Fixed-height scrollable field ---
            Text(
              'Fixed-Height Scrollable',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildScrollableField(),
            const SizedBox(height: 32),

            // --- 4. Read-only field ---
            Text(
              'Read-Only Field',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DocumentField(
              controller: _readOnlyController,
              decoration: const InputDecoration(
                labelText: 'Published content',
                helperText: 'This field is disabled',
                border: OutlineInputBorder(),
              ),
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// A small toggle button for inline formatting in the toolbar ribbon.
class _FormatToggle extends StatelessWidget {
  const _FormatToggle({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onPressed,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 18,
              color: onPressed == null
                  ? Theme.of(context).disabledColor
                  : isActive
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(StringProperty('tooltip', tooltip));
    properties.add(
      FlagProperty('isActive', value: isActive, ifTrue: 'active'),
    );
    properties.add(
      ObjectFlagProperty<VoidCallback?>.has('onPressed', onPressed),
    );
  }
}
