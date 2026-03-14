// Copyright 2024 Simon Horn. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

/// Example app showcasing EditableDocument — a rich-text block editor built
/// on top of Flutter's rendering pipeline.
///
/// Demonstrates:
/// - Block-level document model with multiple node types
/// - Inline text formatting (bold, italic, underline, strikethrough, code)
/// - Parameterized formatting: font family, font size, text color, background color
/// - Block type changes (headings, blockquote, paragraph)
/// - Block insertion (lists, code blocks, horizontal rules, images)
/// - Undo/redo via UndoableEditor
/// - Clipboard (Cmd/Ctrl+C/X/V/A) and right-click context menu
/// - JSON save/load round-trip with full attribution serialization
/// - Block alignment (start, center, end, stretch) for container blocks
/// - Float-style text wrapping with textWrap property
/// - Dual concurrent floats: start + end images with text wrapping around both
/// - BlockquoteNode with left accent border
/// - Property panel for editing block alignment, text wrap, and sizing
/// - TableNode: a block-level table with editable cells and column widths
/// - Block drag-to-move: tap a non-text block to select it, then drag it to
///   reorder it within the document — a blue insertion indicator shows the
///   drop position (wired automatically via DocumentSelectionOverlay)
/// - Editor auto-wiring for block resize and drag-to-move: passing `editor`
///   to DocumentSelectionOverlay removes the need for manual onBlockResize,
///   onResetImageSize, and onBlockMoved callbacks
///
/// Run with: `flutter run -t example/main.dart`
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Syntax highlighting theme — a light-friendly palette based on GitHub style.
// ---------------------------------------------------------------------------
const _syntaxTheme = <String, TextStyle>{
  'keyword': TextStyle(color: Color(0xFFD73A49), fontWeight: FontWeight.bold),
  'built_in': TextStyle(color: Color(0xFF005CC5)),
  'type': TextStyle(color: Color(0xFF005CC5)),
  'literal': TextStyle(color: Color(0xFF005CC5)),
  'number': TextStyle(color: Color(0xFF005CC5)),
  'string': TextStyle(color: Color(0xFF032F62)),
  'comment': TextStyle(color: Color(0xFF6A737D), fontStyle: FontStyle.italic),
  'doctag': TextStyle(color: Color(0xFF6A737D), fontStyle: FontStyle.italic),
  'meta': TextStyle(color: Color(0xFF735C0F)),
  'meta keyword': TextStyle(color: Color(0xFF735C0F), fontWeight: FontWeight.bold),
  'meta string': TextStyle(color: Color(0xFF032F62)),
  'symbol': TextStyle(color: Color(0xFFE36209)),
  'regexp': TextStyle(color: Color(0xFF032F62)),
  'title': TextStyle(color: Color(0xFF6F42C1)),
  'title.class_': TextStyle(color: Color(0xFF6F42C1)),
  'title.function': TextStyle(color: Color(0xFF6F42C1)),
  'name': TextStyle(color: Color(0xFF22863A)),
  'section': TextStyle(color: Color(0xFF005CC5), fontWeight: FontWeight.bold),
  'attr': TextStyle(color: Color(0xFF005CC5)),
  'attribute': TextStyle(color: Color(0xFF005CC5)),
  'variable': TextStyle(color: Color(0xFFE36209)),
  'params': TextStyle(color: Color(0xFF24292E)),
  'template-variable': TextStyle(color: Color(0xFFE36209)),
  'selector-tag': TextStyle(color: Color(0xFF22863A)),
  'selector-id': TextStyle(color: Color(0xFF005CC5), fontWeight: FontWeight.bold),
  'selector-class': TextStyle(color: Color(0xFF6F42C1)),
  'addition': TextStyle(color: Color(0xFF22863A), backgroundColor: Color(0xFFE6FFEC)),
  'deletion': TextStyle(color: Color(0xFFD73A49), backgroundColor: Color(0xFFFFEEF0)),
  'subst': TextStyle(color: Color(0xFF24292E)),
  'formula': TextStyle(color: Color(0xFF24292E)),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.bold),
  'link': TextStyle(color: Color(0xFF032F62), decoration: TextDecoration.underline),
};

// ---------------------------------------------------------------------------
// SyntaxHighlightCodeBlockBuilder — plugs re_highlight into code blocks.
// ---------------------------------------------------------------------------

class SyntaxHighlightCodeBlockBuilder extends CodeBlockComponentBuilder {
  SyntaxHighlightCodeBlockBuilder() {
    _highlight.registerLanguages(builtinAllLanguages);
  }

  final Highlight _highlight = Highlight();

  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! CodeBlockNode) return null;
    return CodeBlockComponentViewModel(
      nodeId: node.id,
      text: node.text,
      textStyle: const TextStyle(),
      language: node.language,
      width: node.width,
      height: node.height,
      alignment: node.alignment,
      textWrap: node.textWrap,
      textSpanBuilder: (text, baseStyle) => _buildHighlightedSpan(text, baseStyle),
    );
  }

  TextSpan _buildHighlightedSpan(AttributedText text, TextStyle baseStyle) {
    final code = text.text;
    if (code.isEmpty) return TextSpan(text: '', style: baseStyle);

    final result = _highlight.highlightAuto(code, builtinAllLanguages.keys.toList());
    final renderer = TextSpanRenderer(baseStyle, _syntaxTheme);
    result.render(renderer);
    return renderer.span ?? TextSpan(text: code, style: baseStyle);
  }
}

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
      //title: 'EditableDocument Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DocumentDemo(),
    );
  }
}

/// Demonstrates EditableDocument as a rich-text block editor.
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

  final _layoutKey = GlobalKey<DocumentLayoutState>();
  final _startHandleLayerLink = LayerLink();
  final _endHandleLayerLink = LayerLink();
  final _blockDragOverlayKey = GlobalKey<BlockDragOverlayState>();
  final _contextMenuController = ContextMenuController();
  final _clipboard = const DocumentClipboard();
  final _syntaxBuilder = SyntaxHighlightCodeBlockBuilder();

  /// Counter for generating unique node IDs.
  int _nextNodeId = 100;

  /// Vertical spacing between document blocks.
  double _blockSpacing = 0.0;

  /// The node ID for which the floating property panel is shown, or `null`
  /// when the panel is hidden.
  String? _propertyPanelNodeId;

  /// Whether a pointer drag is in progress over the editor area.
  ///
  /// While `true`, the floating property panel is suppressed so it doesn't
  /// interfere with drag-selection focus.
  bool _isDragSelecting = false;

  /// Preset color swatches for text-color and background-color pickers.
  ///
  /// Keys are ARGB 32-bit integer values; values are display labels.
  static const _colorPresets = {
    0xFF000000: 'Black',
    0xFFF44336: 'Red',
    0xFF4CAF50: 'Green',
    0xFF2196F3: 'Blue',
    0xFFFF9800: 'Orange',
    0xFF9C27B0: 'Purple',
    0xFF9E9E9E: 'Grey',
  };

  @override
  void initState() {
    super.initState();
    _document = _buildSampleDocument();
    _controller = DocumentEditingController(document: _document);
    _editor = UndoableEditor(
      editContext: EditContext(document: _document, controller: _controller),
    );
    _focusNode = FocusNode(debugLabel: 'DocumentDemo');

    _document.changes.addListener(_onDocumentChanged);
    _controller.addListener(_onDocumentChanged);
  }

  @override
  void dispose() {
    _contextMenuController.remove();
    _controller.removeListener(_onDocumentChanged);
    _document.changes.removeListener(_onDocumentChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDocumentChanged() {
    _contextMenuController.remove();
    // Auto-show/hide the property panel based on selection.
    final sel = _controller.selection;
    final node = sel != null ? _document.nodeById(sel.extent.nodeId) : null;
    if (_isContainerBlock(node)) {
      _propertyPanelNodeId = node!.id;
    } else {
      _propertyPanelNodeId = null;
    }
    setState(() {});
  }

  // -----------------------------------------------------------------------
  // Context menu
  // -----------------------------------------------------------------------

  void _showContextMenu(Offset globalPosition) {
    final selection = _controller.selection;
    final bool hasExpanded = selection != null && selection.isExpanded;

    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (BuildContext menuContext) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: TextSelectionToolbarAnchors(
            primaryAnchor: globalPosition,
          ),
          buttonItems: [
            if (hasExpanded)
              ContextMenuButtonItem(
                label: 'Cut',
                onPressed: () {
                  _contextMenuController.remove();
                  _handleCut();
                },
              ),
            if (hasExpanded)
              ContextMenuButtonItem(
                label: 'Copy',
                onPressed: () {
                  _contextMenuController.remove();
                  _handleCopy();
                },
              ),
            ContextMenuButtonItem(
              label: 'Paste',
              onPressed: () {
                _contextMenuController.remove();
                _handlePaste();
              },
            ),
            ContextMenuButtonItem(
              label: 'Select All',
              onPressed: () {
                _contextMenuController.remove();
                _handleSelectAll();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleCopy() {
    final selection = _controller.selection;
    if (selection == null || selection.isCollapsed) return;
    _clipboard.copy(_document, selection);
  }

  void _handleCut() {
    final selection = _controller.selection;
    if (selection == null || selection.isCollapsed) return;
    _clipboard.cut(_document, selection).then((request) {
      if (request != null) _editor.submit(request);
    });
  }

  void _handlePaste() {
    final selection = _controller.selection;
    if (selection == null) return;
    if (selection.isExpanded) {
      _editor.submit(DeleteContentRequest(selection: selection));
    }
    final pasteSelection = _controller.selection;
    if (pasteSelection == null) return;
    final pos = pasteSelection.extent;
    final node = _document.nodeById(pos.nodeId);
    if (node == null || node is! TextNode) return;
    final offset = (pos.nodePosition as TextNodePosition).offset;
    _clipboard.paste(pos.nodeId, offset).then((request) {
      if (request != null) _editor.submit(request);
    });
  }

  void _handleSelectAll() {
    if (_document.nodes.isEmpty) return;
    final first = _document.nodes.first;
    final last = _document.nodes.last;
    _controller.setSelection(
      DocumentSelection(
        base: DocumentPosition(
          nodeId: first.id,
          nodePosition: first is TextNode
              ? const TextNodePosition(offset: 0)
              : const BinaryNodePosition.upstream(),
        ),
        extent: DocumentPosition(
          nodeId: last.id,
          nodePosition: last is TextNode
              ? TextNodePosition(offset: last.text.text.length)
              : const BinaryNodePosition.downstream(),
        ),
      ),
    );
  }

  MutableDocument _buildSampleDocument() {
    final welcome = AttributedText('Welcome to EditableDocument')
      ..applyAttribution(NamedAttribution.bold, 11, 26);

    final intro = AttributedText(
      'A drop-in replacement for EditableText that supports rich, '
      'block-level documents. Select text and use the toolbar above '
      'to apply formatting.',
    )
      ..applyAttribution(NamedAttribution.italics, 27, 40)
      ..applyAttribution(NamedAttribution.bold, 27, 40);

    // Paragraph demonstrating parameterized formatting attributions.
    final colorDemo = AttributedText(
      'Font family, font size, text color, and background color '
      'attributions are supported. Select this text and try the new toolbar controls.',
    )
      ..applyAttribution(const FontFamilyAttribution('Georgia'), 0, 10)
      ..applyAttribution(const FontSizeAttribution(18.0), 13, 21)
      ..applyAttribution(const TextColorAttribution(0xFF2196F3), 24, 33)
      ..applyAttribution(const BackgroundColorAttribution(0xFFFF9800), 38, 53);

    return MutableDocument([
      ParagraphNode(
        id: 'h1',
        text: welcome,
        blockType: ParagraphBlockType.header1,
      ),
      ParagraphNode(id: 'intro', text: intro),
      ParagraphNode(
        id: 'h2-rich',
        text: AttributedText('Rich Text Editing'),
        blockType: ParagraphBlockType.header2,
      ),
      ListItemNode(
        id: 'cap-1',
        text: AttributedText('Inline styles: bold, italic, underline, '
            'strikethrough, code'),
        type: ListItemType.unordered,
      ),
      ListItemNode(
        id: 'cap-1a',
        text: AttributedText('Applied via toolbar or keyboard shortcuts'),
        type: ListItemType.unordered,
        indent: 1,
      ),
      ListItemNode(
        id: 'cap-2',
        text: AttributedText('Block-level structure with headings, '
            'lists, and quotes'),
        type: ListItemType.unordered,
      ),
      ListItemNode(
        id: 'cap-3',
        text: AttributedText('Full undo/redo with snapshot-based history'),
        type: ListItemType.unordered,
      ),
      ParagraphNode(
        id: 'h2-blocks',
        text: AttributedText('Block Types'),
        blockType: ParagraphBlockType.header2,
      ),
      ListItemNode(
        id: 'bt-1',
        text: AttributedText('Paragraph — standard body text'),
        type: ListItemType.ordered,
      ),
      ListItemNode(
        id: 'bt-2',
        text: AttributedText('Headings — H1 through H3 for hierarchy'),
        type: ListItemType.ordered,
      ),
      ListItemNode(
        id: 'bt-3',
        text: AttributedText('Lists — ordered and unordered with nesting'),
        type: ListItemType.ordered,
      ),
      ListItemNode(
        id: 'bt-4',
        text: AttributedText('Code blocks — syntax-highlighted source'),
        type: ListItemType.ordered,
      ),
      ListItemNode(
        id: 'bt-5',
        text: AttributedText('Images, horizontal rules, and blockquotes'),
        type: ListItemType.ordered,
      ),
      HorizontalRuleNode(id: 'rule-1'),
      ParagraphNode(
        id: 'h2-color',
        text: AttributedText('Parameterized Formatting'),
        blockType: ParagraphBlockType.header2,
      ),
      ParagraphNode(
        id: 'color-demo',
        text: colorDemo,
      ),
      ParagraphNode(
        id: 'h3-code',
        text: AttributedText('Code Example'),
        blockType: ParagraphBlockType.header3,
      ),
      CodeBlockNode(
        id: 'code-1',
        text: AttributedText(
          'final doc = MutableDocument([\n'
          '  ParagraphNode(\n'
          '    id: "title",\n'
          '    text: AttributedText("Hello!"),\n'
          '    blockType: ParagraphBlockType.header1,\n'
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
        language: 'dart',
      ),
      ImageNode(
        id: 'image-1',
        imageUrl: 'https://picsum.photos/600/200',
        altText: 'Placeholder image demonstrating ImageNode support',
      ),
      BlockquoteNode(
        id: 'quote-1',
        text: AttributedText(
          'EditableDocument is to block documents what EditableText '
          'is to single-field text.',
        ),
      ),
      // --- Block Layout Properties section ---
      ParagraphNode(
        id: 'h2-layout',
        text: AttributedText('Block Layout Properties'),
        blockType: ParagraphBlockType.header2,
      ),
      ParagraphNode(
        id: 'layout-intro',
        text: AttributedText(
          'Container blocks support horizontal alignment and text wrapping. '
          'Images, code blocks, blockquotes, and horizontal rules can be '
          'aligned start, center, end, or stretch.',
        ),
      ),
      // Center-aligned image.
      ImageNode(
        id: 'img-center',
        imageUrl: 'https://picsum.photos/300/150',
        altText: 'Center-aligned image',
        width: 300,
        height: 150,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      ),
      ParagraphNode(
        id: 'float-text2',
        text: AttributedText(
          'This paragraph wraps beside the floated image. When textWrap is '
          'true and alignment is start or end, subsequent blocks receive '
          'reduced-width constraints and flow beside the image. Once the '
          'text extends past the image, the next block gets full width.',
        ),
      ),
      // Float image with adjacent text wrap — tall enough for multiple blocks.
      ImageNode(
        id: 'img-float',
        imageUrl: 'https://picsum.photos/200/250',
        altText: 'Floated image with text wrap',
        width: 200,
        height: 250,
        alignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      ),
      ParagraphNode(
        id: 'float-text',
        text: AttributedText(
          'This paragraph wraps beside the floated image. When textWrap is '
          'true and alignment is start or end, subsequent blocks receive '
          'reduced-width constraints and flow beside the image.',
        ),
      ),
      CodeBlockNode(
        id: 'code-beside-image',
        text: AttributedText(
          '// Code blocks also wrap\n'
          'final x = 42;',
        ),
        language: 'dart',
      ),
      // BlockquoteNode — dedicated type with left accent border.
      BlockquoteNode(
        id: 'bq-1',
        text: AttributedText(
          'The new BlockquoteNode renders with a left accent border and '
          'supports container layout properties like alignment and textWrap.',
        ),
      ),
      // End-aligned code block with explicit width.
      CodeBlockNode(
        id: 'code-aligned',
        text: AttributedText('print("end-aligned!")'),
        language: 'dart',
        width: 250,
        alignment: BlockAlignment.end,
      ),
      // Floated code block with text wrapping.
      CodeBlockNode(
        id: 'code-float',
        text: AttributedText(
          'void main() {\n'
          '  runApp(MyApp());\n'
          '}',
        ),
        language: 'dart',
        width: 250,
        alignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      ),
      ParagraphNode(
        id: 'code-float-text',
        text: AttributedText(
          'This paragraph wraps beside the floated code block. Code blocks '
          'participate in text wrapping just like images and blockquotes — '
          'set a width, choose an alignment, and enable text wrap.',
        ),
      ),
      // Center-aligned horizontal rule.
      HorizontalRuleNode(
        id: 'rule-center',
        alignment: BlockAlignment.center,
      ),
      // --- Dual Float Demo section ---
      ParagraphNode(
        id: 'h2-dual-float',
        text: AttributedText('Dual Concurrent Floats'),
        blockType: ParagraphBlockType.header2,
      ),
      ParagraphNode(
        id: 'dual-float-intro',
        text: AttributedText(
          'Two images can float simultaneously — one anchored to the start edge '
          'and one to the end edge — while text wraps through the space between '
          'them. The layout engine tracks independent exclusion zones for each '
          'float and narrows the available width for wrapping blocks accordingly.',
        ),
      ),
      // Start-aligned (left) float.
      ImageNode(
        id: 'img-dual-start',
        imageUrl: 'https://picsum.photos/seed/dual-left/150/100',
        altText: 'Left float image',
        width: 150,
        height: 100,
        alignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      ),
      // End-aligned (right) float.
      ImageNode(
        id: 'img-dual-end',
        imageUrl: 'https://picsum.photos/seed/dual-right/150/100',
        altText: 'Right float image',
        width: 150,
        height: 100,
        alignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      ),
      // This paragraph wraps in the space between both floats.
      ParagraphNode(
        id: 'dual-float-text',
        text: AttributedText(
          'This paragraph flows through the gap between the two floating images. '
          'As long as both floats are still active — i.e. their bottom edges have '
          'not been passed — every wrapping block gets its available width reduced '
          'by both exclusion zones at once. Once the text descends past the shorter '
          'float, the full column width is restored for that side.',
        ),
      ),
      // --- Block Drag-to-Move section ---
      //
      // Drag-to-move is automatic: tap any non-text block (image, horizontal
      // rule, etc.) to fully select it, then drag it vertically. A blue
      // insertion indicator line shows where the block will land on drop.
      // DocumentSelectionOverlay wires up BlockDragOverlay internally — no
      // extra widget setup is needed here.
      HorizontalRuleNode(id: 'rule-before-drag'),
      ParagraphNode(
        id: 'h2-drag',
        text: AttributedText('Block Drag-to-Move'),
        blockType: ParagraphBlockType.header2,
      ),
      ParagraphNode(
        id: 'drag-intro',
        text: AttributedText(
          'Tap any non-text block below to select it, then drag it up or down '
          'to reorder it within the document. A blue horizontal line shows '
          'where the block will be inserted on drop. The feature works out of '
          'the box for ImageNode, HorizontalRuleNode, CodeBlockNode, and '
          'any other block whose selection state is fully binary.',
        ),
      ),
      // Draggable image — tap to select, then drag vertically to reorder.
      ImageNode(
        id: 'img-drag-demo',
        imageUrl: 'https://picsum.photos/seed/drag-demo/400/120',
        altText: 'Draggable demo image — tap to select, then drag to reorder',
        width: 400,
        height: 120,
        alignment: BlockAlignment.center,
      ),
      ParagraphNode(
        id: 'drag-between-1',
        text: AttributedText('Paragraph A — drag the image or rule above or below here.'),
      ),
      // Draggable horizontal rule — tap to select, then drag to reorder.
      HorizontalRuleNode(id: 'rule-drag-demo'),
      ParagraphNode(
        id: 'drag-between-2',
        text: AttributedText('Paragraph B — try dragging the horizontal rule past this line.'),
      ),
      // --- Table Demo section ---
      HorizontalRuleNode(id: 'rule-before-table'),
      ParagraphNode(
        id: 'h2-table',
        text: AttributedText('Table Support'),
        blockType: ParagraphBlockType.header2,
      ),
      ParagraphNode(
        id: 'table-intro',
        text: AttributedText(
          'TableNode stores a 2D grid of AttributedText cells. Each cell '
          'supports the same inline attributions as any other text node. '
          'Column widths can be set individually; null entries are auto-sized. '
          'Tables participate in the same IME and edit-request pipeline as '
          'all other block types.',
        ),
      ),
      // A simple 3x3 table with a header row.
      TableNode(
        id: 'table-demo',
        rowCount: 3,
        columnCount: 3,
        cells: [
          [
            AttributedText('Feature')..applyAttribution(NamedAttribution.bold, 0, 6),
            AttributedText('Status')..applyAttribution(NamedAttribution.bold, 0, 5),
            AttributedText('Notes')..applyAttribution(NamedAttribution.bold, 0, 4),
          ],
          [
            AttributedText('Inline formatting'),
            AttributedText('Complete'),
            AttributedText('Bold, italic, underline, code'),
          ],
          [
            AttributedText('Table editing'),
            AttributedText('In progress'),
            AttributedText('IME + edit requests'),
          ],
        ],
        columnWidths: [200.0, 120.0, null],
        alignment: BlockAlignment.stretch,
      ),
      ParagraphNode(
        id: 'table-outro',
        text: AttributedText(
          'Use InsertTableRequest, UpdateTableCellRequest, and DeleteTableRequest '
          'to mutate table content through the standard editor pipeline, giving '
          'full undo/redo support for every cell edit.',
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Insert helpers
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

  String _newId() => 'dynamic-${_nextNodeId++}';

  void _insertNode(DocumentNode node) {
    final sel = _controller.selection;
    // Capture the selected node before any mutations so we can match its
    // type when creating a follow-on block.
    final selectedNode = sel != null ? _document.nodeById(sel.extent.nodeId) : null;
    String? emptyNodeId;
    if (selectedNode is TextNode && selectedNode.text.text.isEmpty) {
      emptyNodeId = selectedNode.id;
    }

    _document.insertNode(_insertIndex(), node);

    if (emptyNodeId != null) {
      _document.deleteNode(emptyNodeId);
    }

    if (node is TextNode) {
      _controller.setSelection(DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: node.id,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ));
    } else {
      // Insert an empty block after the non-text node, matching the type
      // of the block the user was in when they triggered the insertion.
      final idx = _document.getNodeIndexById(node.id);
      if (idx < 0) return;
      final emptyBlock = _emptyBlockLike(selectedNode);
      _document.insertNode(idx + 1, emptyBlock);
      _controller.setSelection(DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: emptyBlock.id,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ));
    }
  }

  /// Returns a new empty text block matching the type of [source].
  ///
  /// If [source] is `null` or a non-text node, a plain [ParagraphNode] is
  /// returned as the default.
  TextNode _emptyBlockLike(DocumentNode? source) {
    final id = _newId();
    final empty = AttributedText('');
    if (source is BlockquoteNode) return BlockquoteNode(id: id, text: empty);
    if (source is CodeBlockNode) return CodeBlockNode(id: id, text: empty);
    if (source is ListItemNode) {
      return ListItemNode(id: id, text: empty, type: source.type);
    }
    return ParagraphNode(id: id, text: empty);
  }

  /// Returns the current block type name for the selected node.
  String _currentBlockLabel() {
    final sel = _controller.selection;
    if (sel == null) return '';
    final node = _document.nodeById(sel.extent.nodeId);
    if (node is ParagraphNode) {
      switch (node.blockType) {
        case ParagraphBlockType.header1:
          return 'H1';
        case ParagraphBlockType.header2:
          return 'H2';
        case ParagraphBlockType.header3:
          return 'H3';
        case ParagraphBlockType.blockquote:
          return 'Blockquote';
        case ParagraphBlockType.paragraph:
          return 'Paragraph';
        default:
          return 'Paragraph';
      }
    } else if (node is ListItemNode) {
      return node.type == ListItemType.ordered ? 'Ordered list' : 'Bullet list';
    } else if (node is BlockquoteNode) {
      return 'Blockquote';
    } else if (node is CodeBlockNode) {
      return 'Code block';
    } else if (node is HorizontalRuleNode) {
      return 'Horizontal rule';
    } else if (node is ImageNode) {
      return 'Image';
    }
    return '';
  }

  /// Returns the [TextNode]s covered by the current selection.
  List<TextNode> _selectedTextNodes() {
    final sel = _controller.selection;
    if (sel == null) return const [];
    final baseIdx = _document.getNodeIndexById(sel.base.nodeId);
    final extentIdx = _document.getNodeIndexById(sel.extent.nodeId);
    if (baseIdx < 0 || extentIdx < 0) return const [];
    final start = baseIdx < extentIdx ? baseIdx : extentIdx;
    final end = baseIdx < extentIdx ? extentIdx : baseIdx;
    return [
      for (var i = start; i <= end; i++)
        if (_document.nodeAt(i) is TextNode) _document.nodeAt(i) as TextNode,
    ];
  }

  /// Returns `true` when the node matches [type].
  bool _nodeMatchesType(DocumentNode? node, String type) {
    return switch (type) {
      'paragraph' => node is ParagraphNode && node.blockType == ParagraphBlockType.paragraph,
      'blockquote' => node is BlockquoteNode,
      'code' => node is CodeBlockNode,
      'unordered' => node is ListItemNode && node.type == ListItemType.unordered,
      'ordered' => node is ListItemNode && node.type == ListItemType.ordered,
      _ => false,
    };
  }

  /// Returns `true` when **all** selected text nodes match [type].
  bool _isBlockType(String type) {
    final nodes = _selectedTextNodes();
    if (nodes.isEmpty) return false;
    return nodes.every((n) => _nodeMatchesType(n, type));
  }

  /// Creates a new [TextNode] of [type] preserving [id] and [text].
  TextNode? _makeNode(String type, String id, AttributedText text) {
    return switch (type) {
      'paragraph' => ParagraphNode(id: id, text: text),
      'blockquote' => BlockquoteNode(id: id, text: text),
      'code' => CodeBlockNode(id: id, text: text),
      'unordered' => ListItemNode(id: id, text: text, type: ListItemType.unordered),
      'ordered' => ListItemNode(id: id, text: text, type: ListItemType.ordered),
      _ => null,
    };
  }

  /// Converts all selected text nodes to [type], or back to paragraph if
  /// every selected node already matches (toggle behavior).
  void _toggleBlockType(String type) {
    final nodes = _selectedTextNodes();
    if (nodes.isEmpty) return;

    // If every node already matches, toggle back to paragraph.
    final allMatch = nodes.every((n) => _nodeMatchesType(n, type));
    final targetType = allMatch && type != 'paragraph' ? 'paragraph' : type;

    for (final node in nodes) {
      if (_nodeMatchesType(node, targetType)) continue;
      final newNode = _makeNode(targetType, node.id, node.text);
      if (newNode != null) {
        _editor.submit(ReplaceNodeRequest(nodeId: node.id, newNode: newNode));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Formatting toolbar actions
  // ---------------------------------------------------------------------------

  void _toggleAttribution(Attribution attribution) {
    final sel = _controller.selection;
    if (sel == null || sel.isCollapsed) return;

    final startNode = _document.nodeById(sel.base.nodeId);
    final isApplied = startNode is TextNode &&
        sel.base.nodePosition is TextNodePosition &&
        startNode.text.hasAttributionAt(
          (sel.base.nodePosition as TextNodePosition).offset,
          attribution,
        );

    if (isApplied) {
      _editor.submit(RemoveAttributionRequest(
        selection: sel,
        attribution: attribution,
      ));
    } else {
      _editor.submit(ApplyAttributionRequest(
        selection: sel,
        attribution: attribution,
      ));
    }
  }

  bool _isAttributionActive(Attribution attribution) {
    final sel = _controller.selection;
    if (sel == null || sel.isCollapsed) return false;
    final node = _document.nodeById(sel.base.nodeId);
    if (node is! TextNode) return false;
    final pos = sel.base.nodePosition;
    if (pos is! TextNodePosition) return false;
    return node.text.hasAttributionAt(pos.offset, attribution);
  }

  /// Returns the active parameterized attribution of type [T] at the selection
  /// base offset, or `null` if none is found.
  ///
  /// Looks at the text node at the selection base and searches its attributions
  /// at that offset for an instance of [T].
  T? _getAttributionValue<T extends Attribution>() {
    final sel = _controller.selection;
    if (sel == null) return null;
    final node = _document.nodeById(sel.base.nodeId);
    if (node is! TextNode) return null;
    final pos = sel.base.nodePosition;
    if (pos is! TextNodePosition) return null;
    final offset = pos.offset;
    final attributions = node.text.getAttributionsAt(offset);
    return attributions.whereType<T>().firstOrNull;
  }

  /// Applies a parameterized [attribution] to the current expanded selection.
  ///
  /// Removes any existing attribution of the same runtime type from the
  /// selection first, then applies the new one. This ensures only one value
  /// of each parameterized type is active at a time.
  void _applyParameterizedAttribution(Attribution newAttribution) {
    final sel = _controller.selection;
    if (sel == null || sel.isCollapsed) return;

    // Remove any existing attribution of the same runtime type.
    final node = _document.nodeById(sel.base.nodeId);
    if (node is TextNode) {
      final pos = sel.base.nodePosition;
      if (pos is TextNodePosition) {
        final existing = node.text.getAttributionsAt(pos.offset);
        for (final attr in existing) {
          if (attr.runtimeType == newAttribution.runtimeType) {
            _editor.submit(RemoveAttributionRequest(
              selection: sel,
              attribution: attr,
            ));
          }
        }
      }
    }

    _editor.submit(ApplyAttributionRequest(
      selection: sel,
      attribution: newAttribution,
    ));
  }

  /// Removes all attributions of type [T] from the current expanded selection.
  void _clearParameterizedAttribution<T extends Attribution>() {
    final sel = _controller.selection;
    if (sel == null || sel.isCollapsed) return;
    final node = _document.nodeById(sel.base.nodeId);
    if (node is! TextNode) return;
    final pos = sel.base.nodePosition;
    if (pos is! TextNodePosition) return;
    final existing = node.text.getAttributionsAt(pos.offset);
    for (final attr in existing.whereType<T>()) {
      _editor.submit(RemoveAttributionRequest(
        selection: sel,
        attribution: attr,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // JSON save/load
  // ---------------------------------------------------------------------------

  Map<String, Object?> _documentToJson() {
    final nodes = <Map<String, Object?>>[];
    for (final node in _document.nodes) {
      final map = <String, Object?>{'id': node.id};
      if (node is ParagraphNode) {
        map['type'] = 'paragraph';
        map['text'] = node.text.text;
        if (node.blockType != ParagraphBlockType.paragraph) {
          map['blockType'] = node.blockType.name;
        }
        _addAttributionSpans(map, node.text);
      } else if (node is ListItemNode) {
        map['type'] = 'listItem';
        map['text'] = node.text.text;
        map['listType'] = node.type.name;
        if (node.indent > 0) map['indent'] = node.indent;
        _addAttributionSpans(map, node.text);
      } else if (node is CodeBlockNode) {
        map['type'] = 'codeBlock';
        map['text'] = node.text.text;
        if (node.language != null) map['language'] = node.language;
      } else if (node is ImageNode) {
        map['type'] = 'image';
        map['imageUrl'] = node.imageUrl;
        if (node.altText != null) map['altText'] = node.altText;
      } else if (node is HorizontalRuleNode) {
        map['type'] = 'horizontalRule';
      }
      nodes.add(map);
    }
    return {'nodes': nodes};
  }

  /// Serializes attribution spans from [text] into [map] under the key
  /// `'attributions'`.
  ///
  /// Parameterized attributions ([FontFamilyAttribution], [FontSizeAttribution],
  /// [TextColorAttribution], [BackgroundColorAttribution]) include an additional
  /// `'value'` key so the round-trip can reconstruct the correct type.
  void _addAttributionSpans(Map<String, Object?> map, AttributedText text) {
    final spans = text.getAttributionSpansInRange(0, text.text.length);
    if (spans.isEmpty) return;
    map['attributions'] = spans.map((s) {
      final spanMap = <String, Object?>{
        'attribution': s.attribution.id,
        'start': s.start,
        'end': s.end,
      };
      final attr = s.attribution;
      if (attr is FontFamilyAttribution) {
        spanMap['value'] = attr.fontFamily;
      } else if (attr is FontSizeAttribution) {
        spanMap['value'] = attr.fontSize;
      } else if (attr is TextColorAttribution) {
        spanMap['value'] = attr.colorValue;
      } else if (attr is BackgroundColorAttribution) {
        spanMap['value'] = attr.colorValue;
      }
      return spanMap;
    }).toList();
  }

  void _showSaveDialog() {
    final json = const JsonEncoder.withIndent('  ').convert(_documentToJson());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Document JSON'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLoadDialog() {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Document JSON'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: TextField(
            controller: textController,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Paste JSON here...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              try {
                final data = jsonDecode(textController.text) as Map<String, Object?>;
                _loadDocumentFromJson(data);
                Navigator.of(ctx).pop();
              } on Object {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Invalid JSON')),
                );
              }
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  void _loadDocumentFromJson(Map<String, Object?> data) {
    final nodeList = data['nodes'] as List<Object?>? ?? [];
    final nodes = <DocumentNode>[];
    for (final raw in nodeList) {
      final map = raw! as Map<String, Object?>;
      final id = map['id'] as String? ?? generateNodeId();
      final type = map['type'] as String?;
      switch (type) {
        case 'paragraph':
          final text = _textFromJson(map);
          final blockTypeName = map['blockType'] as String?;
          nodes.add(ParagraphNode(
            id: id,
            text: text,
            blockType: blockTypeName != null
                ? ParagraphBlockType.values.firstWhere(
                    (bt) => bt.name == blockTypeName,
                    orElse: () => ParagraphBlockType.paragraph,
                  )
                : ParagraphBlockType.paragraph,
          ));
        case 'listItem':
          final text = _textFromJson(map);
          final listTypeName = map['listType'] as String? ?? 'unordered';
          nodes.add(ListItemNode(
            id: id,
            text: text,
            type: listTypeName == 'ordered' ? ListItemType.ordered : ListItemType.unordered,
            indent: (map['indent'] as int?) ?? 0,
          ));
        case 'codeBlock':
          final text = _textFromJson(map);
          nodes.add(CodeBlockNode(
            id: id,
            text: text,
            language: map['language'] as String?,
          ));
        case 'image':
          nodes.add(ImageNode(
            id: id,
            imageUrl: map['imageUrl'] as String? ?? '',
            altText: map['altText'] as String?,
          ));
        case 'horizontalRule':
          nodes.add(HorizontalRuleNode(id: id));
        default:
          nodes.add(ParagraphNode(
            id: id,
            text: AttributedText(map['text'] as String? ?? ''),
          ));
      }
    }
    if (nodes.isEmpty) return;

    _controller.clearSelection();
    _document.reset(nodes);
  }

  /// Deserializes an [AttributedText] from a JSON node map.
  ///
  /// Handles both plain [NamedAttribution]s (stored with only an `'attribution'`
  /// id key) and the four parameterized attribution types
  /// ([FontFamilyAttribution], [FontSizeAttribution], [TextColorAttribution],
  /// [BackgroundColorAttribution]), which include a `'value'` key.
  AttributedText _textFromJson(Map<String, Object?> map) {
    final text = AttributedText(map['text'] as String? ?? '');
    final attributions = map['attributions'] as List<Object?>?;
    if (attributions != null) {
      for (final raw in attributions) {
        final span = raw! as Map<String, Object?>;
        final attrId = span['attribution'] as String;
        final start = span['start'] as int;
        final end = span['end'] as int;
        final Attribution attribution;
        switch (attrId) {
          case 'fontFamily':
            attribution = FontFamilyAttribution(span['value'] as String);
          case 'fontSize':
            attribution = FontSizeAttribution((span['value'] as num).toDouble());
          case 'textColor':
            attribution = TextColorAttribution(span['value'] as int);
          case 'backgroundColor':
            attribution = BackgroundColorAttribution(span['value'] as int);
          default:
            attribution = NamedAttribution(attrId);
        }
        text.applyAttribution(attribution, start, end);
      }
    }
    return text;
  }

  // ---------------------------------------------------------------------------
  // Word and character count
  // ---------------------------------------------------------------------------

  int _wordCount() {
    var count = 0;
    for (final node in _document.nodes) {
      if (node is TextNode) {
        final trimmed = node.text.text.trim();
        if (trimmed.isNotEmpty) {
          count += trimmed.split(RegExp(r'\s+')).length;
        }
      }
    }
    return count;
  }

  int _charCount() {
    var count = 0;
    for (final node in _document.nodes) {
      if (node is TextNode) {
        count += node.text.text.length;
      }
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Listener(
              onPointerDown: (_) {
                if (!_isDragSelecting) setState(() => _isDragSelecting = true);
              },
              onPointerUp: (_) {
                if (_isDragSelecting) setState(() => _isDragSelecting = false);
              },
              onPointerCancel: (_) {
                if (_isDragSelecting) setState(() => _isDragSelecting = false);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildEditor(),
                  _buildFloatingPropertyPanel(),
                ],
              ),
            ),
          ),
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final sel = _controller.selection;
    final hasExpandedSelection = sel != null && !sel.isCollapsed;
    final hasCursor = sel != null;
    final selectedNode = sel != null ? _document.nodeById(sel.extent.nodeId) : null;
    final isOnTextNode = selectedNode is TextNode;
    final colorScheme = Theme.of(context).colorScheme;

    const iconSize = 18.0;
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size(32, 32),
      padding: const EdgeInsets.all(4),
    );

    Widget divider() => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(height: 24, child: VerticalDivider(width: 1)),
        );

    // Resolve current parameterized attribution values at the selection base.
    final currentFontFamily = _getAttributionValue<FontFamilyAttribution>()?.fontFamily;
    final currentFontSize = _getAttributionValue<FontSizeAttribution>()?.fontSize;
    final activeTextColor = _getAttributionValue<TextColorAttribution>()?.colorValue;
    final activeBgColor = _getAttributionValue<BackgroundColorAttribution>()?.colorValue;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              children: [
                // --- File actions ---
                IconButton(
                  icon: const Icon(Icons.save_outlined, size: iconSize),
                  onPressed: _showSaveDialog,
                  tooltip: 'Save as JSON',
                  style: buttonStyle,
                ),
                IconButton(
                  icon: const Icon(Icons.file_open_outlined, size: iconSize),
                  onPressed: _showLoadDialog,
                  tooltip: 'Load from JSON',
                  style: buttonStyle,
                ),
                divider(),
                // --- Undo / Redo ---
                IconButton(
                  icon: const Icon(Icons.undo, size: iconSize),
                  onPressed: _editor.canUndo ? () => setState(() => _editor.undo()) : null,
                  tooltip: 'Undo',
                  style: buttonStyle,
                ),
                IconButton(
                  icon: const Icon(Icons.redo, size: iconSize),
                  onPressed: _editor.canRedo ? () => setState(() => _editor.redo()) : null,
                  tooltip: 'Redo',
                  style: buttonStyle,
                ),
                divider(),
                // --- Block type toggles ---
                _FormatToggle(
                  icon: Icons.segment,
                  tooltip: 'Paragraph',
                  isActive: _isBlockType('paragraph'),
                  onPressed: isOnTextNode ? () => _toggleBlockType('paragraph') : null,
                ),
                _FormatToggle(
                  icon: Icons.format_quote,
                  tooltip: 'Blockquote',
                  isActive: _isBlockType('blockquote'),
                  onPressed: isOnTextNode ? () => _toggleBlockType('blockquote') : null,
                ),
                _FormatToggle(
                  icon: Icons.data_object,
                  tooltip: 'Code',
                  isActive: _isBlockType('code'),
                  onPressed: isOnTextNode ? () => _toggleBlockType('code') : null,
                ),
                _FormatToggle(
                  icon: Icons.format_list_bulleted,
                  tooltip: 'Bullet list',
                  isActive: _isBlockType('unordered'),
                  onPressed: isOnTextNode ? () => _toggleBlockType('unordered') : null,
                ),
                _FormatToggle(
                  icon: Icons.format_list_numbered,
                  tooltip: 'Numbered list',
                  isActive: _isBlockType('ordered'),
                  onPressed: isOnTextNode ? () => _toggleBlockType('ordered') : null,
                ),
                divider(),
                // --- Inline formatting ---
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
                  onPressed: hasExpandedSelection
                      ? () => _toggleAttribution(NamedAttribution.italics)
                      : null,
                ),
                _FormatToggle(
                  icon: Icons.format_underlined,
                  tooltip: 'Underline',
                  isActive: _isAttributionActive(NamedAttribution.underline),
                  onPressed: hasExpandedSelection
                      ? () => _toggleAttribution(NamedAttribution.underline)
                      : null,
                ),
                _FormatToggle(
                  icon: Icons.strikethrough_s,
                  tooltip: 'Strikethrough',
                  isActive: _isAttributionActive(NamedAttribution.strikethrough),
                  onPressed: hasExpandedSelection
                      ? () => _toggleAttribution(NamedAttribution.strikethrough)
                      : null,
                ),
                _FormatToggle(
                  icon: Icons.code,
                  tooltip: 'Inline code',
                  isActive: _isAttributionActive(NamedAttribution.code),
                  onPressed:
                      hasExpandedSelection ? () => _toggleAttribution(NamedAttribution.code) : null,
                ),
                divider(),
                // --- Font family dropdown ---
                SizedBox(
                  width: 120,
                  height: 32,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: currentFontFamily,
                      hint: Text('Font', style: bodySmall),
                      style: bodySmall,
                      isDense: true,
                      isExpanded: true,
                      onChanged: hasExpandedSelection
                          ? (value) {
                              if (value == null) {
                                _clearParameterizedAttribution<FontFamilyAttribution>();
                              } else {
                                _applyParameterizedAttribution(FontFamilyAttribution(value));
                              }
                            }
                          : null,
                      items: const [
                        DropdownMenuItem<String?>(value: null, child: Text('Default')),
                        DropdownMenuItem<String?>(value: 'Georgia', child: Text('Serif')),
                        DropdownMenuItem<String?>(value: 'Courier New', child: Text('Mono')),
                        DropdownMenuItem<String?>(value: 'Comic Sans MS', child: Text('Casual')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // --- Font size dropdown ---
                SizedBox(
                  width: 80,
                  height: 32,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<double?>(
                      value: currentFontSize,
                      hint: Text('Size', style: bodySmall),
                      style: bodySmall,
                      isDense: true,
                      isExpanded: true,
                      onChanged: hasExpandedSelection
                          ? (value) {
                              if (value == null) {
                                _clearParameterizedAttribution<FontSizeAttribution>();
                              } else {
                                _applyParameterizedAttribution(FontSizeAttribution(value));
                              }
                            }
                          : null,
                      items: const [
                        DropdownMenuItem<double?>(value: null, child: Text('Default')),
                        DropdownMenuItem<double?>(value: 12, child: Text('12')),
                        DropdownMenuItem<double?>(value: 14, child: Text('14')),
                        DropdownMenuItem<double?>(value: 16, child: Text('16')),
                        DropdownMenuItem<double?>(value: 18, child: Text('18')),
                        DropdownMenuItem<double?>(value: 24, child: Text('24')),
                        DropdownMenuItem<double?>(value: 32, child: Text('32')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                divider(),
                // --- Text color popup ---
                Tooltip(
                  message: 'Text color',
                  child: PopupMenuButton<int?>(
                    enabled: hasExpandedSelection,
                    offset: const Offset(0, 36),
                    onSelected: (value) {
                      if (value == null) {
                        _clearParameterizedAttribution<TextColorAttribution>();
                      } else {
                        _applyParameterizedAttribution(TextColorAttribution(value));
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem<int?>(
                        value: null,
                        child: Text('Default'),
                      ),
                      for (final entry in _colorPresets.entries)
                        PopupMenuItem<int?>(
                          value: entry.key,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Color(entry.key),
                                  border: Border.all(
                                    color: Colors.black26,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(entry.value),
                            ],
                          ),
                        ),
                    ],
                    child: SizedBox(
                      height: 32,
                      width: 32,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.format_color_text,
                            size: 18,
                            color: hasExpandedSelection
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                          Container(
                            height: 3,
                            width: 16,
                            color: activeTextColor != null
                                ? Color(activeTextColor)
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // --- Background color popup ---
                Tooltip(
                  message: 'Background color',
                  child: PopupMenuButton<int?>(
                    enabled: hasExpandedSelection,
                    offset: const Offset(0, 36),
                    onSelected: (value) {
                      if (value == null) {
                        _clearParameterizedAttribution<BackgroundColorAttribution>();
                      } else {
                        _applyParameterizedAttribution(BackgroundColorAttribution(value));
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem<int?>(
                        value: null,
                        child: Text('Default'),
                      ),
                      for (final entry in _colorPresets.entries)
                        PopupMenuItem<int?>(
                          value: entry.key,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Color(entry.key),
                                  border: Border.all(
                                    color: Colors.black26,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(entry.value),
                            ],
                          ),
                        ),
                    ],
                    child: SizedBox(
                      height: 32,
                      width: 32,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.format_color_fill,
                            size: 18,
                            color: hasExpandedSelection
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                          Container(
                            height: 3,
                            width: 16,
                            color:
                                activeBgColor != null ? Color(activeBgColor) : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                divider(),
                // --- List indent/unindent ---
                IconButton(
                  icon: const Icon(Icons.format_indent_increase, size: iconSize),
                  onPressed: selectedNode is ListItemNode
                      ? () => _editor.submit(
                            IndentListItemRequest(nodeId: selectedNode.id),
                          )
                      : null,
                  tooltip: 'Indent',
                  style: buttonStyle,
                ),
                IconButton(
                  icon: const Icon(Icons.format_indent_decrease, size: iconSize),
                  onPressed: selectedNode is ListItemNode && selectedNode.indent > 0
                      ? () => _editor.submit(
                            UnindentListItemRequest(nodeId: selectedNode.id),
                          )
                      : null,
                  tooltip: 'Unindent',
                  style: buttonStyle,
                ),
                divider(),
                // --- Insert menu ---
                _buildInsertMenu(hasCursor),
                divider(),
                // --- Line spacing ---
                PopupMenuButton<double>(
                  tooltip: 'Line spacing',
                  offset: const Offset(0, 36),
                  onSelected: (value) => setState(() => _blockSpacing = value),
                  itemBuilder: (context) => [
                    for (final entry in {0.0: 'Single', 6.0: '1.5 lines', 12.0: 'Double'}.entries)
                      PopupMenuItem(
                        value: entry.key,
                        child: Row(
                          children: [
                            if (_blockSpacing == entry.key)
                              const Icon(Icons.check, size: 16)
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            Text(entry.value),
                          ],
                        ),
                      ),
                  ],
                  child: const SizedBox(
                    height: 32,
                    width: 32,
                    child: Icon(Icons.format_line_spacing, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsertMenu(bool enabled) {
    return PopupMenuButton<String>(
      tooltip: 'Insert',
      enabled: enabled,
      offset: const Offset(0, 36),
      onSelected: (value) {
        switch (value) {
          case 'hr':
            _insertNode(HorizontalRuleNode(id: _newId()));
          case 'image':
            _insertNode(ImageNode(
              id: _newId(),
              imageUrl: 'https://picsum.photos/600/200',
              altText: 'Inserted image',
            ));
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'hr', child: Text('Horizontal rule')),
        PopupMenuItem(value: 'image', child: Text('Image')),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: enabled ? null : Theme.of(context).disabledColor),
            const SizedBox(width: 4),
            Text(
              'Insert',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: enabled ? null : Theme.of(context).disabledColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Block property panel
  // ---------------------------------------------------------------------------

  /// Returns true if [node] is a container block that supports layout properties.
  bool _isContainerBlock(DocumentNode? node) => node is HasBlockLayout;

  /// Dismisses the floating property panel.
  void _dismissPropertyPanel() {
    if (_propertyPanelNodeId == null) return;
    setState(() {
      _propertyPanelNodeId = null;
    });
  }

  /// Returns true if [node] supports width/height/textWrap properties.
  bool _hasSizingProperties(DocumentNode? node) => node is HasBlockLayout;

  BlockAlignment _getBlockAlignment(DocumentNode node) {
    return switch (node) {
      HasBlockLayout(:final alignment) => alignment,
      _ => BlockAlignment.stretch,
    };
  }

  TextWrapMode _getTextWrap(DocumentNode node) {
    return switch (node) {
      HasBlockLayout(:final textWrap) => textWrap,
      _ => TextWrapMode.none,
    };
  }

  double? _getWidth(DocumentNode node) {
    return switch (node) {
      HasBlockLayout(:final width) => width,
      _ => null,
    };
  }

  double? _getHeight(DocumentNode node) {
    return switch (node) {
      HasBlockLayout(:final height) => height,
      _ => null,
    };
  }

  void _updateBlockAlignment(DocumentNode node, BlockAlignment alignment) {
    // When switching to stretch, clear width/height (stretch ignores them).
    DocumentNode updated;
    if (node is ImageNode) {
      updated = alignment == BlockAlignment.stretch
          ? ImageNode(
              id: node.id,
              imageUrl: node.imageUrl,
              altText: node.altText,
              width: null,
              height: null,
              alignment: alignment,
              textWrap: node.textWrap,
            )
          : node.copyWith(alignment: alignment);
    } else if (node is CodeBlockNode) {
      updated = alignment == BlockAlignment.stretch
          ? CodeBlockNode(
              id: node.id,
              text: node.text,
              language: node.language,
              width: null,
              height: null,
              alignment: alignment,
              textWrap: node.textWrap,
            )
          : node.copyWith(alignment: alignment);
    } else if (node is BlockquoteNode) {
      updated = alignment == BlockAlignment.stretch
          ? BlockquoteNode(
              id: node.id,
              text: node.text,
              width: null,
              height: null,
              alignment: alignment,
              textWrap: node.textWrap,
            )
          : node.copyWith(alignment: alignment);
    } else if (node is HorizontalRuleNode) {
      updated = alignment == BlockAlignment.stretch
          ? HorizontalRuleNode(
              id: node.id,
              width: null,
              height: null,
              alignment: alignment,
              textWrap: node.textWrap,
            )
          : node.copyWith(alignment: alignment);
    } else {
      return;
    }
    _editor.submit(ReplaceNodeRequest(nodeId: node.id, newNode: updated));
  }

  void _updateTextWrap(DocumentNode node, TextWrapMode textWrap) {
    DocumentNode updated;
    if (node is ImageNode) {
      updated = node.copyWith(textWrap: textWrap);
    } else if (node is CodeBlockNode) {
      updated = node.copyWith(textWrap: textWrap);
    } else if (node is BlockquoteNode) {
      updated = node.copyWith(textWrap: textWrap);
    } else if (node is HorizontalRuleNode) {
      updated = node.copyWith(textWrap: textWrap);
    } else {
      return;
    }
    _editor.submit(ReplaceNodeRequest(nodeId: node.id, newNode: updated));
  }

  void _updateWidth(DocumentNode node, double? width) {
    // copyWith can't set nullable fields to null, so construct directly.
    // If currently stretch-aligned and a width is set, switch to start
    // (stretch ignores explicit dimensions).
    final alignment = width != null && _getBlockAlignment(node) == BlockAlignment.stretch
        ? BlockAlignment.start
        : _getBlockAlignment(node);
    DocumentNode updated;
    if (node is ImageNode) {
      updated = ImageNode(
        id: node.id,
        imageUrl: node.imageUrl,
        altText: node.altText,
        width: width,
        height: node.height,
        alignment: alignment,
        textWrap: node.textWrap,
      );
    } else if (node is CodeBlockNode) {
      updated = CodeBlockNode(
        id: node.id,
        text: node.text,
        language: node.language,
        width: width,
        height: node.height,
        alignment: alignment,
        textWrap: node.textWrap,
      );
    } else if (node is BlockquoteNode) {
      updated = BlockquoteNode(
        id: node.id,
        text: node.text,
        width: width,
        height: node.height,
        alignment: alignment,
        textWrap: node.textWrap,
      );
    } else if (node is HorizontalRuleNode) {
      updated = HorizontalRuleNode(
        id: node.id,
        width: width,
        height: node.height,
        alignment: alignment,
        textWrap: node.textWrap,
      );
    } else {
      return;
    }
    _editor.submit(ReplaceNodeRequest(nodeId: node.id, newNode: updated));
  }

  void _updateHeight(DocumentNode node, double? height) {
    // copyWith can't set nullable fields to null, so construct directly.
    // If currently stretch-aligned and a height is set, switch to start
    // (stretch ignores explicit dimensions).
    final alignment = height != null && _getBlockAlignment(node) == BlockAlignment.stretch
        ? BlockAlignment.start
        : _getBlockAlignment(node);
    DocumentNode updated;
    if (node is ImageNode) {
      updated = ImageNode(
        id: node.id,
        imageUrl: node.imageUrl,
        altText: node.altText,
        width: node.width,
        height: height,
        alignment: alignment,
        textWrap: node.textWrap,
      );
    } else if (node is CodeBlockNode) {
      updated = CodeBlockNode(
        id: node.id,
        text: node.text,
        language: node.language,
        width: node.width,
        height: height,
        alignment: alignment,
        textWrap: node.textWrap,
      );
    } else if (node is BlockquoteNode) {
      updated = BlockquoteNode(
        id: node.id,
        text: node.text,
        width: node.width,
        height: height,
        alignment: alignment,
        textWrap: node.textWrap,
      );
    } else if (node is HorizontalRuleNode) {
      updated = HorizontalRuleNode(
        id: node.id,
        width: node.width,
        height: height,
        alignment: alignment,
        textWrap: node.textWrap,
      );
    } else {
      return;
    }
    _editor.submit(ReplaceNodeRequest(nodeId: node.id, newNode: updated));
  }

  void _updateImageUrl(DocumentNode node, String url) {
    if (node is! ImageNode) return;
    final updated = ImageNode(
      id: node.id,
      imageUrl: url,
      altText: node.altText,
      width: node.width,
      height: node.height,
      alignment: node.alignment,
      textWrap: node.textWrap,
    );
    _editor.submit(ReplaceNodeRequest(nodeId: node.id, newNode: updated));
  }

  Future<void> _pickImageFile(DocumentNode node) async {
    if (node is! ImageNode) return;
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Image File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '/path/to/image.png',
            labelText: 'File path',
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (path == null || path.trim().isEmpty) return;
    _updateImageUrl(node, path.trim());
  }

  Widget _buildFloatingPropertyPanel() {
    if (_propertyPanelNodeId == null || _isDragSelecting) {
      return const SizedBox.shrink();
    }

    final node = _document.nodeById(_propertyPanelNodeId!);
    if (!_isContainerBlock(node)) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final alignment = _getBlockAlignment(node!);
    final hasSizing = _hasSizingProperties(node);
    const panelWidth = 220.0;

    return Positioned(
      right: 8,
      top: 8,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surfaceContainerLow,
        child: Container(
          width: panelWidth,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentBlockLabel(),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      onPressed: _dismissPropertyPanel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // --- Alignment ---
              Text('Alignment', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final entry in {
                    BlockAlignment.start: Icons.align_horizontal_left,
                    BlockAlignment.center: Icons.align_horizontal_center,
                    BlockAlignment.end: Icons.align_horizontal_right,
                    BlockAlignment.stretch: Icons.expand,
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: entry.key == BlockAlignment.stretch
                            ? const RotatedBox(
                                quarterTurns: 1,
                                child: Icon(Icons.expand, size: 20),
                              )
                            : Icon(entry.value, size: 20),
                        isSelected: alignment == entry.key,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              alignment == entry.key ? colorScheme.primaryContainer : null,
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                        tooltip: entry.key.name,
                        onPressed: () => _updateBlockAlignment(node, entry.key),
                      ),
                    ),
                ],
              ),
              if (hasSizing) ...[
                const SizedBox(height: 12),
                // --- Text Wrap ---
                Text('Text Wrap', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final entry in {
                      TextWrapMode.none: Icons.close,
                      TextWrapMode.wrap: Icons.wrap_text,
                      TextWrapMode.behindText: Icons.flip_to_back,
                      TextWrapMode.inFrontOfText: Icons.flip_to_front,
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(entry.value, size: 20),
                          isSelected: _getTextWrap(node) == entry.key,
                          style: IconButton.styleFrom(
                            backgroundColor: _getTextWrap(node) == entry.key
                                ? colorScheme.primaryContainer
                                : null,
                            minimumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                          ),
                          tooltip: entry.key.name,
                          onPressed: () => _updateTextWrap(node, entry.key),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // --- Width x Height ---
                Text('Width x Height', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _DimensionField(
                        key: ValueKey('${node.id}-w'),
                        value: _getWidth(node),
                        onChanged: (value) => _updateWidth(node, value),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('\u00d7'), // ×
                    ),
                    Expanded(
                      child: _DimensionField(
                        key: ValueKey('${node.id}-h'),
                        value: _getHeight(node),
                        onChanged: (value) => _updateHeight(node, value),
                      ),
                    ),
                  ],
                ),
                if (node is ImageNode) ...[
                  const SizedBox(height: 12),
                  Text('Image URL', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  _UrlField(
                    key: ValueKey('${node.id}-url'),
                    value: node.imageUrl,
                    onChanged: (url) => _updateImageUrl(node, url),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Choose File'),
                      onPressed: () => _pickImageFile(node),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return DocumentScrollable(
      controller: _controller,
      layoutKey: _layoutKey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DocumentMouseInteractor(
        controller: _controller,
        layoutKey: _layoutKey,
        document: _document,
        focusNode: _focusNode,
        onSecondaryTapDown: _showContextMenu,
        blockDragOverlayKey: _blockDragOverlayKey,
        child: Stack(
          children: [
            // Passing editor: _editor auto-wires block resize, image reset,
            // and drag-to-move — no manual onBlockResize, onResetImageSize,
            // or onBlockMoved callbacks are required. BlockDragOverlay is
            // mounted internally by DocumentSelectionOverlay; the shared
            // _blockDragOverlayKey lets DocumentMouseInteractor coordinate
            // drag gestures with the overlay.
            DocumentSelectionOverlay(
              controller: _controller,
              layoutKey: _layoutKey,
              startHandleLayerLink: _startHandleLayerLink,
              endHandleLayerLink: _endHandleLayerLink,
              showCaret: false,
              document: _document,
              editor: _editor,
              blockDragOverlayKey: _blockDragOverlayKey,
              child: EditableDocument(
                controller: _controller,
                focusNode: _focusNode,
                layoutKey: _layoutKey,
                autofocus: true,
                editor: _editor,
                blockSpacing: _blockSpacing,
                componentBuilders: [
                  _syntaxBuilder,
                  ...defaultComponentBuilders.where((b) => b is! CodeBlockComponentBuilder),
                ],
              ),
            ),
            Positioned.fill(
              child: CaretDocumentOverlay(
                controller: _controller,
                layoutKey: _layoutKey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final style = Theme.of(context).textTheme.bodySmall;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text('${_document.nodeCount} blocks', style: style),
          const SizedBox(width: 16),
          Text('${_wordCount()} words', style: style),
          const SizedBox(width: 16),
          Text('${_charCount()} chars', style: style),
          const Spacer(),
          if (_controller.selection != null) Text(_currentBlockLabel(), style: style),
        ],
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
    properties.add(FlagProperty('isActive', value: isActive, ifTrue: 'active'));
    properties.add(ObjectFlagProperty<VoidCallback?>.has('onPressed', onPressed));
  }
}

/// A text field for editing an optional dimension (width or height) value.
///
/// Shows "auto" as placeholder when [value] is null. Accepts numeric input
/// and calls [onChanged] with the parsed value, or null to clear.
class _DimensionField extends StatefulWidget {
  const _DimensionField({super.key, required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  State<_DimensionField> createState() => _DimensionFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('value', value));
    properties.add(ObjectFlagProperty<ValueChanged<double?>>.has('onChanged', onChanged));
  }
}

class _DimensionFieldState extends State<_DimensionField> {
  late final TextEditingController _textController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.value != null ? widget.value!.toStringAsFixed(0) : '',
    );
  }

  @override
  void didUpdateWidget(_DimensionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync from widget when not actively editing.
    if (!_isEditing) {
      final newText = widget.value != null ? widget.value!.toStringAsFixed(0) : '';
      if (_textController.text != newText) {
        _textController.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      widget.onChanged(null);
    } else {
      final parsed = double.tryParse(trimmed);
      if (parsed != null && parsed > 0) {
        widget.onChanged(parsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Focus(
        onFocusChange: (hasFocus) {
          _isEditing = hasFocus;
        },
        child: TextField(
          controller: _textController,
          decoration: const InputDecoration(
            hintText: 'auto',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          style: Theme.of(context).textTheme.bodySmall,
          onChanged: _onChanged,
        ),
      ),
    );
  }
}

class _UrlField extends StatefulWidget {
  const _UrlField({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_UrlField> createState() => _UrlFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('value', value));
    properties.add(ObjectFlagProperty<ValueChanged<String>>.has('onChanged', onChanged));
  }
}

class _UrlFieldState extends State<_UrlField> {
  late final TextEditingController _textController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_UrlField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.value != oldWidget.value) {
      _textController.text = widget.value;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Focus(
        onFocusChange: (hasFocus) => _isEditing = hasFocus,
        child: TextField(
          controller: _textController,
          decoration: const InputDecoration(
            hintText: 'https://...',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(),
          ),
          style: Theme.of(context).textTheme.bodySmall,
          onSubmitted: (text) {
            final trimmed = text.trim();
            if (trimmed.isNotEmpty) widget.onChanged(trimmed);
          },
        ),
      ),
    );
  }
}
