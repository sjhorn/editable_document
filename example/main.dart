// Copyright 2024 Simon Horn. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

/// Comprehensive example demonstrating all implemented layers of the
/// editable_document package.
///
/// Demonstrates:
/// - **Phase 1**: Document model — nodes, attributed text, positions, selections
/// - **Phase 2**: Command pipeline — edit requests, undo/redo
/// - **Phase 3**: Rendering — per-block render objects via ComponentBuilder
/// - **Phase 4**: Services — IME serialization preview, keyboard handler info
/// - **Phase 5.1**: ComponentBuilder — automatic node → widget mapping
/// - **Phase 5.2**: DocumentLayout — automatic document rendering widget
/// - **Phase 5.3**: EditableDocument — drop-in for EditableText
/// - **Phase 5.4**: DocumentField — TextField equivalent with InputDecoration
/// - **Phase 6**: Selection overlay, caret blink, mouse interaction, handles, toolbar
///
/// Run with: `flutter run -t example/main.dart`
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:editable_document/editable_document.dart';

void main() {
  runApp(const ExampleApp());
}

/// Root widget for the editable_document example.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'editable_document example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DocumentDemo(),
    );
  }
}

/// Demonstrates all implemented editable_document layers.
class DocumentDemo extends StatefulWidget {
  /// Creates the demo screen.
  const DocumentDemo({super.key});

  @override
  State<DocumentDemo> createState() => _DocumentDemoState();
}

class _DocumentDemoState extends State<DocumentDemo> {
  late final MutableDocument _document;
  late final DocumentEditingController _controller;
  late final UndoableEditor _editor;
  late final FocusNode _focusNode;

  // Phase 6: selection overlay and mouse interaction support.
  final _layoutKey = GlobalKey<DocumentLayoutState>();
  final _startHandleLayerLink = LayerLink();
  final _endHandleLayerLink = LayerLink();

  /// Counter for generating unique node IDs.
  int _nextNodeId = 100;

  @override
  void initState() {
    super.initState();
    _document = _buildSampleDocument();
    _controller = DocumentEditingController(document: _document);
    _editor = UndoableEditor(
      editContext: EditContext(document: _document, controller: _controller),
    );
    _focusNode = FocusNode(debugLabel: 'DocumentDemo');
    // Listen for document changes to rebuild the UI.
    _document.changes.addListener(_onDocumentChanged);
  }

  @override
  void dispose() {
    _document.changes.removeListener(_onDocumentChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDocumentChanged() {
    setState(() {});
  }

  MutableDocument _buildSampleDocument() {
    // Rich text with bold attribution.
    final boldHello = AttributedText('Hello, editable_document!')
      ..applyAttribution(NamedAttribution.bold, 0, 4);

    // Rich text with italic and underline.
    final styledDesc = AttributedText(
      'A drop-in replacement for EditableText with full block-level '
      'document model support. This text has italic and underline styling.',
    )
      ..applyAttribution(NamedAttribution.italics, 27, 40)
      ..applyAttribution(NamedAttribution.underline, 77, 82);

    return MutableDocument([
      ParagraphNode(
        id: 'heading',
        text: AttributedText('editable_document'),
        blockType: ParagraphBlockType.header1,
      ),
      ParagraphNode(
        id: 'intro',
        text: boldHello,
      ),
      ParagraphNode(
        id: 'desc',
        text: styledDesc,
      ),
      ParagraphNode(
        id: 'phases-heading',
        text: AttributedText('Implemented Phases'),
        blockType: ParagraphBlockType.header2,
      ),
      // Ordered list items demonstrating Phase 1 model.
      ListItemNode(
        id: 'phase-1',
        text: AttributedText('Document model (nodes, text, positions, selections)'),
        type: ListItemType.ordered,
      ),
      ListItemNode(
        id: 'phase-2',
        text: AttributedText('Command pipeline with undo/redo'),
        type: ListItemType.ordered,
      ),
      ListItemNode(
        id: 'phase-3',
        text: AttributedText('Per-block render objects and layout'),
        type: ListItemType.ordered,
      ),
      ListItemNode(
        id: 'phase-4',
        text: AttributedText('IME bridge (serializer, input client, keyboard)'),
        type: ListItemType.ordered,
      ),
      ListItemNode(
        id: 'phase-5',
        text: AttributedText('ComponentBuilder widget system'),
        type: ListItemType.ordered,
      ),
      HorizontalRuleNode(id: 'rule-1'),
      ParagraphNode(
        id: 'features-heading',
        text: AttributedText('Features'),
        blockType: ParagraphBlockType.header2,
      ),
      // Unordered list with nested indent levels.
      ListItemNode(
        id: 'feature-1',
        text: AttributedText('Block-level document model'),
        type: ListItemType.unordered,
      ),
      ListItemNode(
        id: 'feature-1a',
        text: AttributedText('Paragraph, list, code, image, HR nodes'),
        type: ListItemType.unordered,
        indent: 1,
      ),
      ListItemNode(
        id: 'feature-1b',
        text: AttributedText('Rich text attributions (bold, italic, underline)'),
        type: ListItemType.unordered,
        indent: 1,
      ),
      ListItemNode(
        id: 'feature-2',
        text: AttributedText('Event-sourced command pipeline'),
        type: ListItemType.unordered,
      ),
      ListItemNode(
        id: 'feature-3',
        text: AttributedText('Snapshot-based undo/redo'),
        type: ListItemType.unordered,
      ),
      ListItemNode(
        id: 'feature-4',
        text: AttributedText('IME delta model bridge'),
        type: ListItemType.unordered,
      ),
      HorizontalRuleNode(id: 'rule-2'),
      ParagraphNode(
        id: 'code-heading',
        text: AttributedText('Code example'),
        blockType: ParagraphBlockType.header3,
      ),
      CodeBlockNode(
        id: 'code',
        text: AttributedText(
          'final doc = MutableDocument([\n'
          '  ParagraphNode(\n'
          '    id: "1",\n'
          '    text: AttributedText("Hello"),\n'
          '  ),\n'
          ']);\n'
          '\n'
          'final editor = UndoableEditor(\n'
          '  editContext: EditContext(\n'
          '    document: doc,\n'
          '    controller: controller,\n'
          '  ),\n'
          ');',
        ),
      ),
      ImageNode(
        id: 'image',
        imageUrl: 'https://example.com/placeholder.png',
        altText: 'Placeholder image',
      ),
      ParagraphNode(
        id: 'quote',
        text: AttributedText(
          'EditableDocument is to block documents what EditableText is to '
          'single-field text.',
        ),
        blockType: ParagraphBlockType.blockquote,
      ),
      ParagraphNode(
        id: 'ime-heading',
        text: AttributedText('IME Serialization'),
        blockType: ParagraphBlockType.header3,
      ),
      ParagraphNode(
        id: 'ime-desc',
        text: AttributedText(
          'The DocumentImeSerializer converts between the block document model '
          'and the flat TextEditingValue that platform IMEs expect. '
          'The DocumentKeyboardHandler maps non-IME key events (arrows, '
          'Home/End, Delete, Tab) to EditRequests.',
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Command pipeline demo actions
  // ---------------------------------------------------------------------------

  /// Returns the insert index after the currently selected node, or the end
  /// of the document if nothing is selected.
  int _insertIndex() {
    final sel = _controller.selection;
    if (sel != null) {
      final idx = _document.getNodeIndexById(sel.extent.nodeId);
      if (idx >= 0) return idx + 1;
    }
    return _document.nodeCount;
  }

  void _addParagraph() {
    final newId = 'dynamic-${_nextNodeId++}';
    _document.insertNode(
      _insertIndex(),
      ParagraphNode(
        id: newId,
        text: AttributedText('New paragraph added via command pipeline.'),
      ),
    );
  }

  void _addListItem() {
    final newId = 'dynamic-${_nextNodeId++}';
    _document.insertNode(
      _insertIndex(),
      ListItemNode(
        id: newId,
        text: AttributedText('Dynamically added list item'),
        type: ListItemType.unordered,
      ),
    );
  }

  void _removeLastNode() {
    if (_document.nodeCount > 1) {
      _document.deleteNode(_document.nodes.last.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('editable_document'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _editor.canUndo ? () => setState(() => _editor.undo()) : null,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _editor.canRedo ? () => setState(() => _editor.redo()) : null,
            tooltip: 'Redo',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Interactive document editor (Phases 5-6).
            // DocumentMouseInteractor handles click/drag/double-click.
            // DocumentSelectionOverlay renders caret + selection highlights.
            // EditableDocument wires Focus, IME, and keyboard handler.
            DocumentMouseInteractor(
              controller: _controller,
              layoutKey: _layoutKey,
              document: _document,
              child: DocumentSelectionOverlay(
                controller: _controller,
                layoutKey: _layoutKey,
                startHandleLayerLink: _startHandleLayerLink,
                endHandleLayerLink: _endHandleLayerLink,
                child: EditableDocument(
                  controller: _controller,
                  focusNode: _focusNode,
                  layoutKey: _layoutKey,
                  autofocus: true,
                  editor: _editor,
                ),
              ),
            ),

            const Divider(height: 32),

            // Info panel showing document stats.
            _buildInfoPanel(),

            const SizedBox(height: 16),

            // IME serialization preview.
            _buildImePreview(),

            const SizedBox(height: 16),

            // DocumentField demo (Phase 5.4) — TextField equivalent.
            _buildDocumentFieldDemo(),

            const SizedBox(height: 16),

            // Phase 6 info panel.
            _buildPhase6Info(),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'add-paragraph',
            onPressed: _addParagraph,
            tooltip: 'Add paragraph',
            child: const Icon(Icons.text_fields),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'add-list',
            onPressed: _addListItem,
            tooltip: 'Add list item',
            child: const Icon(Icons.format_list_bulleted),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'remove-last',
            onPressed: _document.nodeCount > 1 ? _removeLastNode : null,
            tooltip: 'Remove last node',
            child: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildPhase6Info() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selection Overlay (Phase 6)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The document above is wrapped in a DocumentSelectionOverlay '
              'that draws caret and selection highlights using '
              'DocumentCaretPainter and DocumentSelectionPainter.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            const Text('Phase 6 widgets implemented:'),
            const SizedBox(height: 4),
            const Text('  - DocumentSelectionOverlay (caret + highlights)'),
            const Text('  - CaretDocumentOverlay (blink animation)'),
            const Text('  - DocumentMouseInteractor (desktop mouse)'),
            const Text('  - iOS handles, magnifier, gesture controller'),
            const Text('  - Android handles, magnifier, gesture controller'),
            const Text('  - DocumentTextSelectionControls (floating toolbar)'),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentFieldDemo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DocumentField (Phase 5.4)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'DocumentField wraps EditableDocument with InputDecoration, '
              'just like TextField wraps EditableText.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            // A DocumentField with label, hint, and character counter.
            const DocumentField(
              decoration: InputDecoration(
                labelText: 'Notes',
                hintText: 'Start typing...',
                border: OutlineInputBorder(),
              ),
              maxLength: 500,
            ),
            const SizedBox(height: 12),
            // A disabled DocumentField.
            const DocumentField(
              decoration: InputDecoration(
                labelText: 'Read-only field',
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

  Widget _buildInfoPanel() {
    final textNodeCount = _document.nodes.whereType<TextNode>().length;
    final totalChars =
        _document.nodes.whereType<TextNode>().fold<int>(0, (sum, n) => sum + n.text.text.length);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Stats',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Total nodes: ${_document.nodeCount}'),
            Text('Text nodes: $textNodeCount'),
            Text('Total characters: $totalChars'),
            Text('Can undo: ${_editor.canUndo}'),
            Text('Can redo: ${_editor.canRedo}'),
          ],
        ),
      ),
    );
  }

  Widget _buildImePreview() {
    const serializer = DocumentImeSerializer();
    final value = serializer.toTextEditingValue(
      document: _document,
      selection: _controller.selection,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IME Serialization Preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'TextEditingValue text length: ${value.text.length}',
            ),
            Text(
              'Selection: ${value.selection}',
            ),
            Text(
              'Composing: ${value.composing}',
            ),
            const SizedBox(height: 8),
            Text(
              'First 200 chars of serialized text:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value.text.length > 200 ? '${value.text.substring(0, 200)}...' : value.text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<MutableDocument>('document', _document),
    );
    properties.add(
      DiagnosticsProperty<DocumentEditingController>(
        'controller',
        _controller,
      ),
    );
  }
}
