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
/// - **Phase 4.4**: Autofill — AutofillGroup integration for email/password fields
/// - **Phase 5.1**: ComponentBuilder — automatic node → widget mapping
/// - **Phase 5.2**: DocumentLayout — automatic document rendering widget
/// - **Phase 5.3**: EditableDocument — drop-in for EditableText
/// - **Phase 5.4**: DocumentField — TextField equivalent with InputDecoration
/// - **Phase 6**: Selection overlay, caret blink, mouse interaction, handles, toolbar
/// - **Phase 7**: DocumentScrollable — document-aware scrolling with auto-scroll to caret
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

  // Phase 4.4: autofill demo — dedicated controllers, editors, and focus nodes.
  late final DocumentEditingController _emailController;
  late final DocumentEditingController _passwordController;
  late final UndoableEditor _emailEditor;
  late final UndoableEditor _passwordEditor;
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;

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

    // Phase 4.4: autofill demo controllers and focus nodes.
    _emailController = DocumentEditingController(
      document: MutableDocument([
        ParagraphNode(id: 'email-p1', text: AttributedText()),
      ]),
    );
    _passwordController = DocumentEditingController(
      document: MutableDocument([
        ParagraphNode(id: 'password-p1', text: AttributedText()),
      ]),
    );
    _emailEditor = UndoableEditor(
      editContext: EditContext(
        document: _emailController.document,
        controller: _emailController,
      ),
    );
    _passwordEditor = UndoableEditor(
      editContext: EditContext(
        document: _passwordController.document,
        controller: _passwordController,
      ),
    );
    _emailFocusNode = FocusNode(debugLabel: 'AutofillEmail');
    _passwordFocusNode = FocusNode(debugLabel: 'AutofillPassword');

    // Listen for document changes to rebuild the UI.
    _document.changes.addListener(_onDocumentChanged);
  }

  @override
  void dispose() {
    _document.changes.removeListener(_onDocumentChanged);
    _focusNode.dispose();
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
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
      ParagraphNode(id: newId, text: AttributedText()),
    );
    _controller.setSelection(DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: newId,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    ));
  }

  void _addListItem() {
    final newId = 'dynamic-${_nextNodeId++}';
    _document.insertNode(
      _insertIndex(),
      ListItemNode(
        id: newId,
        text: AttributedText(),
        type: ListItemType.unordered,
      ),
    );
    _controller.setSelection(DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: newId,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    ));
  }

  void _removeLastNode() {
    if (_document.nodeCount > 1) {
      final lastId = _document.nodes.last.id;
      // If selection is in the node being deleted, move it first.
      final sel = _controller.selection;
      if (sel != null && (sel.base.nodeId == lastId || sel.extent.nodeId == lastId)) {
        final newLast = _document.nodes[_document.nodeCount - 2];
        _controller.setSelection(DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: newLast.id,
            nodePosition: newLast is TextNode
                ? TextNodePosition(offset: newLast.text.text.length)
                : const BinaryNodePosition.downstream(),
          ),
        ));
      }
      _document.deleteNode(lastId);
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
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Interactive document editor (Phases 5-7).
              // DocumentScrollable provides auto-scroll to caret (Phase 7).
              // DocumentMouseInteractor handles click/drag/double-click.
              // DocumentSelectionOverlay renders caret + selection highlights.
              // EditableDocument wires Focus, IME, and keyboard handler.
              SizedBox(
                height: 400,
                child: DocumentScrollable(
                  controller: _controller,
                  layoutKey: _layoutKey,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: DocumentMouseInteractor(
                      controller: _controller,
                      layoutKey: _layoutKey,
                      document: _document,
                      focusNode: _focusNode,
                      child: Stack(
                        children: [
                          // Selection highlights (no static caret — the
                          // blinking overlay below handles that).
                          DocumentSelectionOverlay(
                            controller: _controller,
                            layoutKey: _layoutKey,
                            startHandleLayerLink: _startHandleLayerLink,
                            endHandleLayerLink: _endHandleLayerLink,
                            showCaret: false,
                            child: EditableDocument(
                              controller: _controller,
                              focusNode: _focusNode,
                              layoutKey: _layoutKey,
                              autofocus: true,
                              editor: _editor,
                            ),
                          ),
                          // Blinking caret overlay.
                          Positioned.fill(
                            child: CaretDocumentOverlay(
                              controller: _controller,
                              layoutKey: _layoutKey,
                            ),
                          ),
                        ],
                      ),
                    ),
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

              // Autofill demo (Phase 4.4).
              _buildAutofillDemo(),

              const SizedBox(height: 16),

              // Phase 6 info panel.
              _buildPhase6Info(),
            ],
          ),
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
              'Selection & Scrolling (Phases 6-7)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The document above is wrapped in DocumentScrollable (Phase 7) '
              'for auto-scroll to caret, and DocumentSelectionOverlay '
              '(Phase 6) for caret and selection highlights.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            const Text('Phase 6 widgets:'),
            const SizedBox(height: 4),
            const Text('  - DocumentSelectionOverlay (caret + highlights)'),
            const Text('  - CaretDocumentOverlay (blink animation)'),
            const Text('  - DocumentMouseInteractor (desktop mouse)'),
            const Text('  - iOS handles, magnifier, gesture controller'),
            const Text('  - Android handles, magnifier, gesture controller'),
            const Text('  - DocumentTextSelectionControls (floating toolbar)'),
            const SizedBox(height: 8),
            const Text('Phase 7 widgets:'),
            const SizedBox(height: 4),
            const Text('  - DocumentScrollable (auto-scroll to caret)'),
            const Text('  - DragHandleAutoScroller (drag-based auto-scroll)'),
            const Text('  - SliverEditableDocument (CustomScrollView support)'),
          ],
        ),
      ),
    );
  }

  Widget _buildAutofillDemo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Autofill Support (Phase 4.4)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'When EditableDocument is placed inside an AutofillGroup with '
              'autofillHints, the platform can offer autofill suggestions '
              '(e.g. email, password). Only single-TextNode documents '
              'participate in autofill.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DocumentField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    editor: _emailEditor,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email (DocumentField)',
                      hintText: 'user@example.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  DocumentField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    editor: _passwordEditor,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Password (DocumentField)',
                      hintText: 'Enter password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Comparison: standard Flutter TextField with same autofill hints '
              '(if neither shows system suggestions, it is a Flutter platform '
              'limitation on macOS desktop — autofill works on iOS/Android).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            const AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    autofillHints: [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: 'Email (TextField)',
                      hintText: 'user@example.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    autofillHints: [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password (TextField)',
                      hintText: 'Enter password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
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
