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
/// - Text alignment (start, center, end, justify) for paragraph, list, and blockquote nodes
/// - Block alignment (start, center, end, stretch) for container blocks
/// - Float-style text wrapping with textWrap property
/// - Dual concurrent floats: start + end images with text wrapping around both
/// - BlockquoteNode with left accent border
/// - Scrollable property panel shown for ALL block types with sections for:
///   text alignment, line height, spacing (before/after), indent (left/right/first-line),
///   and block layout (alignment, text wrap, dimensions) for container blocks
/// - Document Settings panel (when nothing selected): block spacing, default line height,
///   document padding, and line number gutter controls
/// - documentPadding: EdgeInsets applied around the content area (horizontal/vertical
///   sliders wired live via Document Settings panel)
/// - showLineNumbers: optional left-gutter that numbers each block sequentially,
///   toggled from the Document Settings panel with a configurable background color
/// - lineNumberAlignment: segmented control (Top / Middle / Bottom) in the Document
///   Settings panel that sets vertical alignment of each line number label within
///   its block row; only visible when showLineNumbers is enabled
/// - TableNode: insert via toolbar table button with 8×8 grid-size picker popup
/// - Contextual table toolbar: appears between the main toolbar and the editor
///   when the cursor is inside a table cell; provides resize, column text
///   alignment, row vertical alignment, row/column insertion, and deletion
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
import 'package:flutter/rendering.dart';
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

  /// Document-level default line height multiplier.
  double _defaultLineHeight = 1.0;

  /// Horizontal padding (left + right) around the document content area.
  double _documentPaddingH = 0.0;

  /// Vertical padding (top + bottom) around the document content area.
  double _documentPaddingV = 0.0;

  /// Whether to show line numbers in a left-side gutter.
  bool _showLineNumbers = false;

  /// Vertical alignment of each line number label within its block row.
  LineNumberAlignment _lineNumberAlignment = LineNumberAlignment.top;

  /// The node ID for which the floating property panel is shown, or `null`
  /// when the panel is hidden.
  String? _propertyPanelNodeId;

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
    // Show the panel for ANY selected block node, not just container blocks.
    final sel = _controller.selection;
    final node = sel != null ? _document.nodeById(sel.extent.nodeId) : null;
    if (node != null) {
      _propertyPanelNodeId = node.id;
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
      // --- Document Padding & Line Numbers section ---
      HorizontalRuleNode(id: 'rule-before-layout'),
      ParagraphNode(
        id: 'h2-layout-props',
        text: AttributedText('Document Padding and Line Numbers'),
        blockType: ParagraphBlockType.header2,
      ),
      ParagraphNode(
        id: 'layout-props-intro',
        text: AttributedText(
          'Two new document-level properties are available from the Document '
          'Settings panel (visible when nothing is selected).',
        ),
      ),
      ParagraphNode(
        id: 'layout-props-padding',
        text: AttributedText(
          'documentPadding accepts an EdgeInsets and insets the entire content '
          'area — horizontal padding narrows the column while vertical padding '
          'adds whitespace above the first block and below the last. Use the H '
          'and V sliders in Document Settings to see it live.',
        ),
      ),
      ParagraphNode(
        id: 'layout-props-linenums',
        text: AttributedText(
          'showLineNumbers renders a sequential number beside each top-level '
          'block in a left-side gutter. Toggle it from the Line Numbers switch '
          'in Document Settings. The gutter width is auto-computed from the '
          'block count; lineNumberWidth pins it to a fixed value.',
        ),
      ),
      CodeBlockNode(
        id: 'code-layout-props',
        text: AttributedText(
          'EditableDocument(\n'
          '  controller: controller,\n'
          '  focusNode: focusNode,\n'
          '  // 24 px inset on each side, 16 px top/bottom whitespace\n'
          '  documentPadding: const EdgeInsets.symmetric(\n'
          '    horizontal: 24,\n'
          '    vertical: 16,\n'
          '  ),\n'
          '  showLineNumbers: true,\n'
          '  lineNumberTextStyle: const TextStyle(\n'
          '    fontSize: 11,\n'
          '    color: Color(0xFF9E9E9E),\n'
          '  ),\n'
          '  lineNumberBackgroundColor: const Color(0xFFF5F5F5),\n'
          ')',
        ),
        language: 'dart',
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Insert helpers
  // ---------------------------------------------------------------------------

  String _newId() => 'dynamic-${_nextNodeId++}';

  void _insertNode(DocumentNode node) {
    final sel = _controller.selection;

    // Build the follow-on node for non-text insertions.
    final sourceNode = sel != null ? _document.nodeById(sel.extent.nodeId) : null;
    final followOn = node is TextNode ? null : _emptyBlockLike(sourceNode);

    _editor.submit(InsertNodeAtPositionRequest(
      node: node,
      position: sel?.extent,
      followOnNode: followOn,
    ));

    // Place cursor on the block after the inserted node. In a mid-text split
    // the command skips the follow-on and creates a remaining-text paragraph
    // instead, so we always resolve the target by index lookup.
    final nodeIndex = _document.getNodeIndexById(node.id);
    final cursorTarget = (nodeIndex >= 0 && nodeIndex + 1 < _document.nodeCount)
        ? _document.nodeAt(nodeIndex + 1)
        : node;
    _controller.setSelection(DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: cursorTarget.id,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    ));
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
    } else if (node is TableNode) {
      return 'Table';
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

  /// Returns the common [TextAlign] of all selected alignable nodes,
  /// or `null` if the selection spans nodes with different alignments
  /// or if no alignable nodes are selected.
  TextAlign? _currentTextAlign() {
    final selection = _controller.selection;
    if (selection == null) return null;

    final doc = _controller.document;
    final baseIndex = doc.getNodeIndexById(selection.base.nodeId);
    final extentIndex = doc.getNodeIndexById(selection.extent.nodeId);
    final start = baseIndex < extentIndex ? baseIndex : extentIndex;
    final end = baseIndex < extentIndex ? extentIndex : baseIndex;

    TextAlign? common;
    for (var i = start; i <= end; i++) {
      final node = doc.nodeAt(i);
      final TextAlign? nodeAlign;
      if (node is ParagraphNode) {
        nodeAlign = node.textAlign;
      } else if (node is ListItemNode) {
        nodeAlign = node.textAlign;
      } else if (node is BlockquoteNode) {
        nodeAlign = node.textAlign;
      } else {
        continue;
      }
      if (common == null) {
        common = nodeAlign;
      } else if (common != nodeAlign) {
        return null; // mixed
      }
    }
    return common;
  }

  /// Sets the [TextAlign] of all selected alignable nodes.
  void _setTextAlign(TextAlign align) {
    final selection = _controller.selection;
    if (selection == null) return;

    final doc = _controller.document;
    final baseIndex = doc.getNodeIndexById(selection.base.nodeId);
    final extentIndex = doc.getNodeIndexById(selection.extent.nodeId);
    final start = baseIndex < extentIndex ? baseIndex : extentIndex;
    final end = baseIndex < extentIndex ? extentIndex : baseIndex;

    for (var i = start; i <= end; i++) {
      final node = doc.nodeAt(i);
      if (node is ParagraphNode || node is ListItemNode || node is BlockquoteNode) {
        _editor.submit(ChangeTextAlignRequest(nodeId: node.id, newTextAlign: align));
      }
    }
  }

  /// Creates a new [TextNode] of [type] preserving [id], [text], and [textAlign].
  TextNode? _makeNode(
    String type,
    String id,
    AttributedText text, {
    TextAlign textAlign = TextAlign.start,
  }) {
    return switch (type) {
      'paragraph' => ParagraphNode(id: id, text: text, textAlign: textAlign),
      'blockquote' => BlockquoteNode(id: id, text: text, textAlign: textAlign),
      'code' => CodeBlockNode(id: id, text: text),
      'unordered' =>
        ListItemNode(id: id, text: text, type: ListItemType.unordered, textAlign: textAlign),
      'ordered' =>
        ListItemNode(id: id, text: text, type: ListItemType.ordered, textAlign: textAlign),
      _ => null,
    };
  }

  /// Converts all selected text nodes to [type], or back to paragraph if
  /// every selected node already matches (toggle behavior).
  ///
  /// The [TextAlign] of each node is preserved during conversion.
  void _toggleBlockType(String type) {
    final nodes = _selectedTextNodes();
    if (nodes.isEmpty) return;

    // If every node already matches, toggle back to paragraph.
    final allMatch = nodes.every((n) => _nodeMatchesType(n, type));
    final targetType = allMatch && type != 'paragraph' ? 'paragraph' : type;

    for (final node in nodes) {
      if (_nodeMatchesType(node, targetType)) continue;
      // Preserve the existing text alignment across the block type conversion.
      final existingAlign = switch (node) {
        ParagraphNode(:final textAlign) => textAlign,
        ListItemNode(:final textAlign) => textAlign,
        BlockquoteNode(:final textAlign) => textAlign,
        _ => TextAlign.start,
      };
      final newNode = _makeNode(targetType, node.id, node.text, textAlign: existingAlign);
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
        if (node.textAlign != TextAlign.start) {
          map['textAlign'] = node.textAlign.name;
        }
        if (node.lineHeight != null) map['lineHeight'] = node.lineHeight;
        if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
        if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
        if (node.indentLeft != null) map['indentLeft'] = node.indentLeft;
        if (node.indentRight != null) map['indentRight'] = node.indentRight;
        if (node.firstLineIndent != null) map['firstLineIndent'] = node.firstLineIndent;
        _addAttributionSpans(map, node.text);
      } else if (node is ListItemNode) {
        map['type'] = 'listItem';
        map['text'] = node.text.text;
        map['listType'] = node.type.name;
        if (node.indent > 0) map['indent'] = node.indent;
        if (node.textAlign != TextAlign.start) {
          map['textAlign'] = node.textAlign.name;
        }
        if (node.lineHeight != null) map['lineHeight'] = node.lineHeight;
        if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
        if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
        if (node.indentLeft != null) map['indentLeft'] = node.indentLeft;
        if (node.indentRight != null) map['indentRight'] = node.indentRight;
        _addAttributionSpans(map, node.text);
      } else if (node is BlockquoteNode) {
        map['type'] = 'blockquote';
        map['text'] = node.text.text;
        if (node.textAlign != TextAlign.start) {
          map['textAlign'] = node.textAlign.name;
        }
        if (node.lineHeight != null) map['lineHeight'] = node.lineHeight;
        if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
        if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
        if (node.indentLeft != null) map['indentLeft'] = node.indentLeft;
        if (node.indentRight != null) map['indentRight'] = node.indentRight;
        if (node.firstLineIndent != null) map['firstLineIndent'] = node.firstLineIndent;
        _addAttributionSpans(map, node.text);
      } else if (node is CodeBlockNode) {
        map['type'] = 'codeBlock';
        map['text'] = node.text.text;
        if (node.language != null) map['language'] = node.language;
        if (node.lineHeight != null) map['lineHeight'] = node.lineHeight;
        if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
        if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
      } else if (node is ImageNode) {
        map['type'] = 'image';
        map['imageUrl'] = node.imageUrl;
        if (node.altText != null) map['altText'] = node.altText;
        if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
        if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
      } else if (node is HorizontalRuleNode) {
        map['type'] = 'horizontalRule';
        if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
        if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
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
            textAlign: _parseTextAlign(map['textAlign'] as String?),
            lineHeight: (map['lineHeight'] as num?)?.toDouble(),
            spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
            spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
            indentLeft: (map['indentLeft'] as num?)?.toDouble(),
            indentRight: (map['indentRight'] as num?)?.toDouble(),
            firstLineIndent: (map['firstLineIndent'] as num?)?.toDouble(),
          ));
        case 'listItem':
          final text = _textFromJson(map);
          final listTypeName = map['listType'] as String? ?? 'unordered';
          nodes.add(ListItemNode(
            id: id,
            text: text,
            type: listTypeName == 'ordered' ? ListItemType.ordered : ListItemType.unordered,
            indent: (map['indent'] as int?) ?? 0,
            textAlign: _parseTextAlign(map['textAlign'] as String?),
            lineHeight: (map['lineHeight'] as num?)?.toDouble(),
            spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
            spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
            indentLeft: (map['indentLeft'] as num?)?.toDouble(),
            indentRight: (map['indentRight'] as num?)?.toDouble(),
          ));
        case 'blockquote':
          final text = _textFromJson(map);
          nodes.add(BlockquoteNode(
            id: id,
            text: text,
            textAlign: _parseTextAlign(map['textAlign'] as String?),
            lineHeight: (map['lineHeight'] as num?)?.toDouble(),
            spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
            spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
            indentLeft: (map['indentLeft'] as num?)?.toDouble(),
            indentRight: (map['indentRight'] as num?)?.toDouble(),
            firstLineIndent: (map['firstLineIndent'] as num?)?.toDouble(),
          ));
        case 'codeBlock':
          final text = _textFromJson(map);
          nodes.add(CodeBlockNode(
            id: id,
            text: text,
            language: map['language'] as String?,
            lineHeight: (map['lineHeight'] as num?)?.toDouble(),
            spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
            spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
          ));
        case 'image':
          nodes.add(ImageNode(
            id: id,
            imageUrl: map['imageUrl'] as String? ?? '',
            altText: map['altText'] as String?,
            spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
            spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
          ));
        case 'horizontalRule':
          nodes.add(HorizontalRuleNode(
            id: id,
            spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
            spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
          ));
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

  /// Parses a [TextAlign] from its [TextAlign.name] string, returning
  /// [TextAlign.start] for unrecognised or null values.
  TextAlign _parseTextAlign(String? value) {
    if (value == null) return TextAlign.start;
    return TextAlign.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TextAlign.start,
    );
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
            child: Row(
              children: [
                Expanded(child: _buildEditor()),
                _buildPropertyPanel(),
              ],
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
                // --- Insert block buttons ---
                IconButton(
                  icon: const Icon(Icons.horizontal_rule, size: iconSize),
                  onPressed: hasCursor ? () => _insertNode(HorizontalRuleNode(id: _newId())) : null,
                  tooltip: 'Horizontal rule',
                  style: buttonStyle,
                ),
                IconButton(
                  icon: const Icon(Icons.image_outlined, size: iconSize),
                  onPressed: hasCursor
                      ? () => _insertNode(ImageNode(
                            id: _newId(),
                            imageUrl: 'https://picsum.photos/600/200',
                            altText: 'Inserted image',
                          ))
                      : null,
                  tooltip: 'Image',
                  style: buttonStyle,
                ),
                _TableInsertButton(
                  enabled: hasCursor,
                  onInsert: (rows, cols) => _insertNode(
                    TableNode(
                      id: _newId(),
                      rowCount: rows,
                      columnCount: cols,
                      cells: List.generate(
                        rows,
                        (_) => List.generate(cols, (_) => AttributedText('')),
                      ),
                    ),
                  ),
                ),
                divider(),
                // --- Text alignment ---
                _FormatToggle(
                  icon: Icons.format_align_left,
                  tooltip: 'Align left',
                  isActive: _currentTextAlign() == TextAlign.start,
                  onPressed: isOnTextNode ? () => _setTextAlign(TextAlign.start) : null,
                ),
                _FormatToggle(
                  icon: Icons.format_align_center,
                  tooltip: 'Align center',
                  isActive: _currentTextAlign() == TextAlign.center,
                  onPressed: isOnTextNode ? () => _setTextAlign(TextAlign.center) : null,
                ),
                _FormatToggle(
                  icon: Icons.format_align_right,
                  tooltip: 'Align right',
                  isActive: _currentTextAlign() == TextAlign.right,
                  onPressed: isOnTextNode ? () => _setTextAlign(TextAlign.right) : null,
                ),
                _FormatToggle(
                  icon: Icons.format_align_justify,
                  tooltip: 'Justify',
                  isActive: _currentTextAlign() == TextAlign.justify,
                  onPressed: isOnTextNode ? () => _setTextAlign(TextAlign.justify) : null,
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
              ],
            ),
          ),
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
      lockAspect: node.lockAspect,
    );
    _editor.submit(ReplaceNodeRequest(nodeId: node.id, newNode: updated));
  }

  void _updateLockAspect(ImageNode node, bool value) {
    _editor.submit(
      ReplaceNodeRequest(
        nodeId: node.id,
        newNode: node.copyWith(lockAspect: value),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Line height, spacing, and indent helpers
  // ---------------------------------------------------------------------------

  /// Returns the line height multiplier of [node], or `null` if the node type
  /// does not support it.
  double? _getLineHeight(DocumentNode node) {
    return switch (node) {
      ParagraphNode(:final lineHeight) => lineHeight,
      ListItemNode(:final lineHeight) => lineHeight,
      BlockquoteNode(:final lineHeight) => lineHeight,
      CodeBlockNode(:final lineHeight) => lineHeight,
      _ => null,
    };
  }

  /// Sets the line height multiplier of [node].  Passing `null` resets to the
  /// document default.
  void _updateLineHeight(DocumentNode node, double? value) {
    _editor.submit(ChangeLineHeightRequest(nodeId: node.id, newLineHeight: value));
  }

  /// Returns the spaceBefore value of [node], or `null` when not supported.
  double? _getSpaceBefore(DocumentNode node) {
    return switch (node) {
      ParagraphNode(:final spaceBefore) => spaceBefore,
      ListItemNode(:final spaceBefore) => spaceBefore,
      BlockquoteNode(:final spaceBefore) => spaceBefore,
      CodeBlockNode(:final spaceBefore) => spaceBefore,
      ImageNode(:final spaceBefore) => spaceBefore,
      HorizontalRuleNode(:final spaceBefore) => spaceBefore,
      TableNode(:final spaceBefore) => spaceBefore,
      _ => null,
    };
  }

  /// Returns the spaceAfter value of [node], or `null` when not supported.
  double? _getSpaceAfter(DocumentNode node) {
    return switch (node) {
      ParagraphNode(:final spaceAfter) => spaceAfter,
      ListItemNode(:final spaceAfter) => spaceAfter,
      BlockquoteNode(:final spaceAfter) => spaceAfter,
      CodeBlockNode(:final spaceAfter) => spaceAfter,
      ImageNode(:final spaceAfter) => spaceAfter,
      HorizontalRuleNode(:final spaceAfter) => spaceAfter,
      TableNode(:final spaceAfter) => spaceAfter,
      _ => null,
    };
  }

  /// Whether [node] supports spaceBefore / spaceAfter properties.
  bool _hasSpacingProperties(DocumentNode node) {
    return node is ParagraphNode ||
        node is ListItemNode ||
        node is BlockquoteNode ||
        node is CodeBlockNode ||
        node is ImageNode ||
        node is HorizontalRuleNode ||
        node is TableNode;
  }

  /// Sets spaceBefore and/or spaceAfter on [node].  Non-null values replace
  /// the current value; to clear a value, use [_clearSpaceBefore] or
  /// [_clearSpaceAfter].
  void _updateSpacing(DocumentNode node, {double? spaceBefore, double? spaceAfter}) {
    _editor.submit(ChangeSpacingRequest(
      nodeId: node.id,
      newSpaceBefore: spaceBefore,
      newSpaceAfter: spaceAfter,
    ));
  }

  /// Clears spaceBefore to `null` for [node] using a full node replacement.
  void _clearSpaceBefore(DocumentNode node) {
    _replaceNodeWithSpacing(node, spaceBefore: null, spaceAfter: _getSpaceAfter(node));
  }

  /// Clears spaceAfter to `null` for [node] using a full node replacement.
  void _clearSpaceAfter(DocumentNode node) {
    _replaceNodeWithSpacing(node, spaceBefore: _getSpaceBefore(node), spaceAfter: null);
  }

  /// Replaces [node] with an updated copy that has explicit spacing values.
  ///
  /// This helper is needed because [ChangeSpacingCommand] treats `null` as
  /// "leave unchanged" — it cannot clear a value to `null`.  Direct node
  /// construction is used so that `null` correctly resets spacing to the
  /// document default.
  void _replaceNodeWithSpacing(
    DocumentNode node, {
    required double? spaceBefore,
    required double? spaceAfter,
  }) {
    final DocumentNode updated;
    if (node is ParagraphNode) {
      updated = ParagraphNode(
        id: node.id,
        text: node.text,
        blockType: node.blockType,
        textAlign: node.textAlign,
        lineHeight: node.lineHeight,
        spaceBefore: spaceBefore,
        spaceAfter: spaceAfter,
        indentLeft: node.indentLeft,
        indentRight: node.indentRight,
        firstLineIndent: node.firstLineIndent,
        metadata: node.metadata,
      );
    } else if (node is ListItemNode) {
      updated = ListItemNode(
        id: node.id,
        text: node.text,
        type: node.type,
        indent: node.indent,
        textAlign: node.textAlign,
        lineHeight: node.lineHeight,
        spaceBefore: spaceBefore,
        spaceAfter: spaceAfter,
        indentLeft: node.indentLeft,
        indentRight: node.indentRight,
        metadata: node.metadata,
      );
    } else if (node is BlockquoteNode) {
      updated = BlockquoteNode(
        id: node.id,
        text: node.text,
        width: node.width,
        height: node.height,
        alignment: node.alignment,
        textWrap: node.textWrap,
        textAlign: node.textAlign,
        lineHeight: node.lineHeight,
        spaceBefore: spaceBefore,
        spaceAfter: spaceAfter,
        indentLeft: node.indentLeft,
        indentRight: node.indentRight,
        firstLineIndent: node.firstLineIndent,
        metadata: node.metadata,
      );
    } else if (node is CodeBlockNode) {
      updated = CodeBlockNode(
        id: node.id,
        text: node.text,
        language: node.language,
        width: node.width,
        height: node.height,
        alignment: node.alignment,
        textWrap: node.textWrap,
        lineHeight: node.lineHeight,
        spaceBefore: spaceBefore,
        spaceAfter: spaceAfter,
        metadata: node.metadata,
      );
    } else if (node is ImageNode) {
      updated = ImageNode(
        id: node.id,
        imageUrl: node.imageUrl,
        altText: node.altText,
        width: node.width,
        height: node.height,
        alignment: node.alignment,
        textWrap: node.textWrap,
        lockAspect: node.lockAspect,
        spaceBefore: spaceBefore,
        spaceAfter: spaceAfter,
        metadata: node.metadata,
      );
    } else if (node is HorizontalRuleNode) {
      updated = HorizontalRuleNode(
        id: node.id,
        width: node.width,
        height: node.height,
        alignment: node.alignment,
        textWrap: node.textWrap,
        spaceBefore: spaceBefore,
        spaceAfter: spaceAfter,
        metadata: node.metadata,
      );
    } else if (node is TableNode) {
      // Reconstruct the cells grid from public cellAt accessor since _cells is private.
      final cells = [
        for (var r = 0; r < node.rowCount; r++)
          [for (var c = 0; c < node.columnCount; c++) node.cellAt(r, c)],
      ];
      updated = TableNode(
        id: node.id,
        rowCount: node.rowCount,
        columnCount: node.columnCount,
        cells: cells,
        columnWidths: node.columnWidths,
        alignment: node.alignment,
        spaceBefore: spaceBefore,
        spaceAfter: spaceAfter,
        metadata: node.metadata,
      );
    } else {
      return;
    }
    _editor.submit(ReplaceNodeRequest(nodeId: node.id, newNode: updated));
  }

  /// Returns the indentLeft value of [node], or `null` when not supported.
  double? _getIndentLeft(DocumentNode node) {
    return switch (node) {
      ParagraphNode(:final indentLeft) => indentLeft,
      ListItemNode(:final indentLeft) => indentLeft,
      BlockquoteNode(:final indentLeft) => indentLeft,
      _ => null,
    };
  }

  /// Returns the indentRight value of [node], or `null` when not supported.
  double? _getIndentRight(DocumentNode node) {
    return switch (node) {
      ParagraphNode(:final indentRight) => indentRight,
      ListItemNode(:final indentRight) => indentRight,
      BlockquoteNode(:final indentRight) => indentRight,
      _ => null,
    };
  }

  /// Returns the firstLineIndent value of [node], or `null` when not supported
  /// (includes [ListItemNode] which does not use first-line indent).
  double? _getFirstLineIndent(DocumentNode node) {
    return switch (node) {
      ParagraphNode(:final firstLineIndent) => firstLineIndent,
      BlockquoteNode(:final firstLineIndent) => firstLineIndent,
      _ => null,
    };
  }

  /// Whether [node] supports indentLeft / indentRight properties.
  bool _hasIndentProperties(DocumentNode node) {
    return node is ParagraphNode || node is ListItemNode || node is BlockquoteNode;
  }

  /// Replaces [node] with an updated copy that has explicit indent values.
  ///
  /// Direct node construction is used so that `null` correctly resets indent
  /// to the document default (since [copyWith] uses `??` and cannot clear
  /// nullable fields to `null`).
  void _replaceNodeWithIndent(
    DocumentNode node, {
    required double? indentLeft,
    required double? indentRight,
    required double? firstLineIndent,
  }) {
    final DocumentNode updated;
    if (node is ParagraphNode) {
      updated = ParagraphNode(
        id: node.id,
        text: node.text,
        blockType: node.blockType,
        textAlign: node.textAlign,
        lineHeight: node.lineHeight,
        spaceBefore: node.spaceBefore,
        spaceAfter: node.spaceAfter,
        indentLeft: indentLeft,
        indentRight: indentRight,
        firstLineIndent: firstLineIndent,
        metadata: node.metadata,
      );
    } else if (node is ListItemNode) {
      updated = ListItemNode(
        id: node.id,
        text: node.text,
        type: node.type,
        indent: node.indent,
        textAlign: node.textAlign,
        lineHeight: node.lineHeight,
        spaceBefore: node.spaceBefore,
        spaceAfter: node.spaceAfter,
        indentLeft: indentLeft,
        indentRight: indentRight,
        metadata: node.metadata,
      );
    } else if (node is BlockquoteNode) {
      updated = BlockquoteNode(
        id: node.id,
        text: node.text,
        width: node.width,
        height: node.height,
        alignment: node.alignment,
        textWrap: node.textWrap,
        textAlign: node.textAlign,
        lineHeight: node.lineHeight,
        spaceBefore: node.spaceBefore,
        spaceAfter: node.spaceAfter,
        indentLeft: indentLeft,
        indentRight: indentRight,
        firstLineIndent: firstLineIndent,
        metadata: node.metadata,
      );
    } else {
      return;
    }
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

  /// Builds a labelled section for the property panel.
  Widget _buildPropertySection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        ...children,
      ],
    );
  }

  Widget _buildPropertyPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    const panelWidth = 240.0;

    final List<Widget> content;

    // When no node is selected, show the Document Settings panel.
    if (_propertyPanelNodeId == null) {
      content = [
        Text(
          'Document Settings',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        _buildPropertySection('Block Spacing', [
          DropdownButtonHideUnderline(
            child: DropdownButton<double>(
              value: _blockSpacing,
              isExpanded: true,
              isDense: true,
              style: Theme.of(context).textTheme.bodySmall,
              onChanged: (value) {
                if (value != null) setState(() => _blockSpacing = value);
              },
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('Single')),
                DropdownMenuItem(value: 6.0, child: Text('1.5 lines')),
                DropdownMenuItem(value: 12.0, child: Text('Double')),
              ],
            ),
          ),
        ]),
        _buildPropertySection('Default Line Height', [
          DropdownButtonHideUnderline(
            child: DropdownButton<double>(
              value: _defaultLineHeight,
              isExpanded: true,
              isDense: true,
              style: Theme.of(context).textTheme.bodySmall,
              onChanged: (value) {
                if (value != null) setState(() => _defaultLineHeight = value);
              },
              items: const [
                DropdownMenuItem(value: 1.0, child: Text('Single')),
                DropdownMenuItem(value: 1.15, child: Text('1.15')),
                DropdownMenuItem(value: 1.5, child: Text('1.5 lines')),
                DropdownMenuItem(value: 2.0, child: Text('Double')),
              ],
            ),
          ),
        ]),
        _buildPropertySection('Document Padding', [
          // Horizontal padding slider
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  'H: ${_documentPaddingH.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _documentPaddingH,
                  min: 0,
                  max: 80,
                  divisions: 8,
                  label: _documentPaddingH.toStringAsFixed(0),
                  onChanged: (value) => setState(() => _documentPaddingH = value),
                ),
              ),
            ],
          ),
          // Vertical padding slider
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  'V: ${_documentPaddingV.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _documentPaddingV,
                  min: 0,
                  max: 80,
                  divisions: 8,
                  label: _documentPaddingV.toStringAsFixed(0),
                  onChanged: (value) => setState(() => _documentPaddingV = value),
                ),
              ),
            ],
          ),
        ]),
        _buildPropertySection('Line Numbers', [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Show line numbers',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Switch(
                value: _showLineNumbers,
                onChanged: (value) => setState(() => _showLineNumbers = value),
              ),
            ],
          ),
          if (_showLineNumbers) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Gutter uses tabular figures, 11px, grey text '
                'on a light background.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Number alignment',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SegmentedButton<LineNumberAlignment>(
              segments: const [
                ButtonSegment(
                  value: LineNumberAlignment.top,
                  label: Text('Top'),
                ),
                ButtonSegment(
                  value: LineNumberAlignment.middle,
                  label: Text('Middle'),
                ),
                ButtonSegment(
                  value: LineNumberAlignment.bottom,
                  label: Text('Bottom'),
                ),
              ],
              selected: {_lineNumberAlignment},
              onSelectionChanged: (selection) => setState(
                () => _lineNumberAlignment = selection.first,
              ),
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ]),
      ];
    } else {
      final node = _document.nodeById(_propertyPanelNodeId!);
      if (node == null) {
        content = [];
      } else {
        final isTextNode = node is ParagraphNode || node is ListItemNode || node is BlockquoteNode;
        final isTextOrCode = isTextNode || node is CodeBlockNode;
        final isContainerBlock = _isContainerBlock(node);

        content = [
          // --- Header row ---
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

          // --- Text section (alignment) for text-bearing nodes ---
          if (isTextNode) ...[
            _buildPropertySection('Text Alignment', [
              Row(
                children: [
                  for (final entry in {
                    TextAlign.start: Icons.format_align_left,
                    TextAlign.center: Icons.format_align_center,
                    TextAlign.right: Icons.format_align_right,
                    TextAlign.justify: Icons.format_align_justify,
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: Icon(entry.value, size: 20),
                        isSelected: _currentTextAlign() == entry.key,
                        style: IconButton.styleFrom(
                          backgroundColor: _currentTextAlign() == entry.key
                              ? colorScheme.primaryContainer
                              : null,
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                        tooltip: entry.key.name,
                        onPressed: () => _setTextAlign(entry.key),
                      ),
                    ),
                ],
              ),
            ]),
          ],

          // --- Line Height section for text-bearing + code nodes ---
          if (isTextOrCode) ...[
            _buildPropertySection('Line Height', [
              DropdownButtonHideUnderline(
                child: DropdownButton<double?>(
                  value: _getLineHeight(node),
                  isExpanded: true,
                  isDense: true,
                  style: Theme.of(context).textTheme.bodySmall,
                  onChanged: (value) => _updateLineHeight(node, value),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Default')),
                    DropdownMenuItem(value: 1.0, child: Text('1.0')),
                    DropdownMenuItem(value: 1.15, child: Text('1.15')),
                    DropdownMenuItem(value: 1.5, child: Text('1.5')),
                    DropdownMenuItem(value: 2.0, child: Text('2.0')),
                  ],
                ),
              ),
            ]),
          ],

          // --- Spacing section for all block types that support it ---
          if (_hasSpacingProperties(node)) ...[
            _buildPropertySection('Spacing', [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Before',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        _DimensionField(
                          key: ValueKey('${node.id}-sb'),
                          value: _getSpaceBefore(node),
                          onChanged: (value) {
                            if (value == null) {
                              _clearSpaceBefore(node);
                            } else {
                              _updateSpacing(node, spaceBefore: value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'After',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        _DimensionField(
                          key: ValueKey('${node.id}-sa'),
                          value: _getSpaceAfter(node),
                          onChanged: (value) {
                            if (value == null) {
                              _clearSpaceAfter(node);
                            } else {
                              _updateSpacing(node, spaceAfter: value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
          ],

          // --- Indent section for text nodes (Paragraph, ListItem, Blockquote) ---
          if (_hasIndentProperties(node)) ...[
            _buildPropertySection('Indent', [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Left',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        _DimensionField(
                          key: ValueKey('${node.id}-il'),
                          value: _getIndentLeft(node),
                          onChanged: (value) => _replaceNodeWithIndent(
                            node,
                            indentLeft: value,
                            indentRight: _getIndentRight(node),
                            firstLineIndent: _getFirstLineIndent(node),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Right',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        _DimensionField(
                          key: ValueKey('${node.id}-ir'),
                          value: _getIndentRight(node),
                          onChanged: (value) => _replaceNodeWithIndent(
                            node,
                            indentLeft: _getIndentLeft(node),
                            indentRight: value,
                            firstLineIndent: _getFirstLineIndent(node),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // First-line indent (not for ListItemNode)
              if (node is! ListItemNode) ...[
                const SizedBox(height: 6),
                Text(
                  'First Line',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                _DimensionField(
                  key: ValueKey('${node.id}-fli'),
                  value: _getFirstLineIndent(node),
                  onChanged: (value) => _replaceNodeWithIndent(
                    node,
                    indentLeft: _getIndentLeft(node),
                    indentRight: _getIndentRight(node),
                    firstLineIndent: value,
                  ),
                ),
              ],
            ]),
          ],

          // --- Layout section for container blocks ---
          if (isContainerBlock) ...[
            _buildPropertySection('Block Alignment', [
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
                        isSelected: _getBlockAlignment(node) == entry.key,
                        style: IconButton.styleFrom(
                          backgroundColor: _getBlockAlignment(node) == entry.key
                              ? colorScheme.primaryContainer
                              : null,
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                        tooltip: entry.key.name,
                        onPressed: () => _updateBlockAlignment(node, entry.key),
                      ),
                    ),
                ],
              ),
            ]),
            if (_hasSizingProperties(node)) ...[
              _buildPropertySection('Text Wrap', [
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
              ]),
              _buildPropertySection('Width \u00d7 Height', [
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
              ]),
              if (node is ImageNode) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lock Aspect',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Checkbox(
                      value: node.lockAspect,
                      onChanged: (value) => _updateLockAspect(node, value ?? true),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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
        ];
      }
    }

    return SizedBox(
      width: panelWidth,
      height: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: content,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the contextual table toolbar as a [Positioned] widget inside
  /// the document's scrollable [Stack].
  ///
  /// Because it lives inside the scrollable content, it scrolls naturally
  /// with the table — no coordinate conversion or scroll listeners needed.
  /// Returns [SizedBox.shrink] when the cursor is not in a table cell.
  Widget _buildInlineTableToolbar() {
    final sel = _controller.selection;
    if (sel == null) return const SizedBox.shrink();
    final node = _document.nodeById(sel.extent.nodeId);
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
      child: _TableContextToolbar(
        nodeId: node.id,
        minRow: minRow,
        maxRow: maxRow,
        minCol: minCol,
        maxCol: maxCol,
        cellTextAligns: node.cellTextAligns,
        cellVerticalAligns: node.cellVerticalAligns,
        rowCount: node.rowCount,
        columnCount: node.columnCount,
        editor: _editor,
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
                style: TextStyle(height: _defaultLineHeight),
                documentPadding: EdgeInsets.symmetric(
                  horizontal: _documentPaddingH,
                  vertical: _documentPaddingV,
                ),
                showLineNumbers: _showLineNumbers,
                lineNumberAlignment: _lineNumberAlignment,
                lineNumberTextStyle: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9E9E9E),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                lineNumberBackgroundColor: const Color(0xFFF5F5F5),
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
            // Table context toolbar — positioned inside the scrollable
            // content so it scrolls naturally with the document.
            _buildInlineTableToolbar(),
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
    properties.add(DoubleProperty('blockSpacing', _blockSpacing));
    properties.add(DoubleProperty('defaultLineHeight', _defaultLineHeight));
    properties.add(DoubleProperty('documentPaddingH', _documentPaddingH));
    properties.add(DoubleProperty('documentPaddingV', _documentPaddingV));
    properties.add(
      FlagProperty('showLineNumbers', value: _showLineNumbers, ifTrue: 'showLineNumbers'),
    );
    properties.add(
      EnumProperty<LineNumberAlignment>('lineNumberAlignment', _lineNumberAlignment,
          defaultValue: LineNumberAlignment.top),
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

// ---------------------------------------------------------------------------
// Table resize button — contextual table toolbar
// ---------------------------------------------------------------------------

/// A toolbar button in the contextual table toolbar that opens an 8×8 grid
/// picker for choosing the new table dimensions via [ResizeTableRequest].
///
/// Visually identical to [_TableInsertButton] but calls [onResize] instead of
/// an insert callback.
class _TableResizeButton extends StatefulWidget {
  const _TableResizeButton({required this.onResize, this.existingRows, this.existingCols});

  /// Called with the chosen (rows, cols) when the user confirms a selection.
  final void Function(int rows, int cols) onResize;

  /// Current table row count, shown as a distinct region in the grid picker.
  final int? existingRows;

  /// Current table column count, shown as a distinct region in the grid picker.
  final int? existingCols;

  @override
  State<_TableResizeButton> createState() => _TableResizeButtonState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      ObjectFlagProperty<void Function(int, int)>.has('onResize', onResize),
    );
  }
}

class _TableResizeButtonState extends State<_TableResizeButton> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _showPicker() {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => _TableSizePickerOverlay(
        layerLink: _layerLink,
        existingRows: widget.existingRows,
        existingCols: widget.existingCols,
        onSelect: (rows, cols) {
          _hideOverlay();
          widget.onResize(rows, cols);
        },
        onDismiss: _hideOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        icon: const Icon(Icons.grid_on, size: 18),
        onPressed: _showPicker,
        tooltip: 'Resize table',
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          padding: const EdgeInsets.all(4),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table context toolbar
// ---------------------------------------------------------------------------

/// Compact toolbar for table operations, positioned above the table in the
/// document's scrollable content stack.
class _TableContextToolbar extends StatelessWidget {
  const _TableContextToolbar({
    required this.nodeId,
    required this.minRow,
    required this.maxRow,
    required this.minCol,
    required this.maxCol,
    required this.cellTextAligns,
    required this.cellVerticalAligns,
    required this.rowCount,
    required this.columnCount,
    required this.editor,
  });

  final String nodeId;
  final int minRow;
  final int maxRow;
  final int minCol;
  final int maxCol;
  final List<List<TextAlign>>? cellTextAligns;
  final List<List<TableVerticalAlignment>>? cellVerticalAligns;
  final int rowCount;
  final int columnCount;
  final UndoableEditor editor;

  /// Returns the shared [TextAlign] for all selected cells, or `null` if mixed.
  TextAlign? _sharedCellAlign() {
    TextAlign? shared;
    for (int r = minRow; r <= maxRow; r++) {
      for (int c = minCol; c <= maxCol; c++) {
        final align =
            cellTextAligns != null && r < cellTextAligns!.length && c < cellTextAligns![r].length
                ? cellTextAligns![r][c]
                : TextAlign.start;
        if (shared == null) {
          shared = align;
        } else if (shared != align) {
          return null;
        }
      }
    }
    return shared;
  }

  /// Returns the shared [TableVerticalAlignment] for all selected cells, or `null` if mixed.
  TableVerticalAlignment? _sharedCellVAlign() {
    TableVerticalAlignment? shared;
    for (int r = minRow; r <= maxRow; r++) {
      for (int c = minCol; c <= maxCol; c++) {
        final align = cellVerticalAligns != null &&
                r < cellVerticalAligns!.length &&
                c < cellVerticalAligns![r].length
            ? cellVerticalAligns![r][c]
            : TableVerticalAlignment.top;
        if (shared == null) {
          shared = align;
        } else if (shared != align) {
          return null;
        }
      }
    }
    return shared;
  }

  /// Submits a [ChangeTableCellAlignRequest] for every selected cell.
  void _setCellAlign(TextAlign align) {
    for (int r = minRow; r <= maxRow; r++) {
      for (int c = minCol; c <= maxCol; c++) {
        editor.submit(
          ChangeTableCellAlignRequest(nodeId: nodeId, row: r, col: c, textAlign: align),
        );
      }
    }
  }

  /// Submits a [ChangeTableCellVerticalAlignRequest] for every selected cell.
  void _setCellVAlign(TableVerticalAlignment align) {
    for (int r = minRow; r <= maxRow; r++) {
      for (int c = minCol; c <= maxCol; c++) {
        editor.submit(
          ChangeTableCellVerticalAlignRequest(nodeId: nodeId, row: r, col: c, verticalAlign: align),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const iconSize = 16.0;
    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size(28, 28),
      padding: const EdgeInsets.all(2),
    );

    Widget divider() => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: SizedBox(height: 20, child: VerticalDivider(width: 1)),
        );

    final colAlign = _sharedCellAlign();
    final rowVAlign = _sharedCellVAlign();
    final deleteColor = colorScheme.error;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Resize
            _TableResizeButton(
              existingRows: rowCount,
              existingCols: columnCount,
              onResize: (rows, cols) => editor.submit(
                ResizeTableRequest(nodeId: nodeId, newRowCount: rows, newColumnCount: cols),
              ),
            ),
            divider(),
            // Column text alignment — applies to all selected columns
            _FormatToggle(
              icon: Icons.format_align_left,
              tooltip: 'Align column left',
              isActive: colAlign == TextAlign.start,
              onPressed: () => _setCellAlign(TextAlign.start),
            ),
            _FormatToggle(
              icon: Icons.format_align_center,
              tooltip: 'Align column center',
              isActive: colAlign == TextAlign.center,
              onPressed: () => _setCellAlign(TextAlign.center),
            ),
            _FormatToggle(
              icon: Icons.format_align_right,
              tooltip: 'Align column right',
              isActive: colAlign == TextAlign.right,
              onPressed: () => _setCellAlign(TextAlign.right),
            ),
            divider(),
            // Row vertical alignment — applies to all selected rows
            _FormatToggle(
              icon: Icons.vertical_align_top,
              tooltip: 'Align row top',
              isActive: rowVAlign == TableVerticalAlignment.top,
              onPressed: () => _setCellVAlign(TableVerticalAlignment.top),
            ),
            _FormatToggle(
              icon: Icons.vertical_align_center,
              tooltip: 'Align row middle',
              isActive: rowVAlign == TableVerticalAlignment.middle,
              onPressed: () => _setCellVAlign(TableVerticalAlignment.middle),
            ),
            _FormatToggle(
              icon: Icons.vertical_align_bottom,
              tooltip: 'Align row bottom',
              isActive: rowVAlign == TableVerticalAlignment.bottom,
              onPressed: () => _setCellVAlign(TableVerticalAlignment.bottom),
            ),
            divider(),
            // Insert row — above first / below last selected row
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: iconSize),
              tooltip: 'Insert row above',
              style: buttonStyle,
              onPressed: () => editor.submit(
                InsertTableRowRequest(nodeId: nodeId, rowIndex: minRow, insertBefore: true),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: iconSize),
              tooltip: 'Insert row below',
              style: buttonStyle,
              onPressed: () => editor.submit(
                InsertTableRowRequest(nodeId: nodeId, rowIndex: maxRow, insertBefore: false),
              ),
            ),
            divider(),
            // Insert column — left of first / right of last selected column
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_left, size: iconSize),
              tooltip: 'Insert column left',
              style: buttonStyle,
              onPressed: () => editor.submit(
                InsertTableColumnRequest(nodeId: nodeId, colIndex: minCol, insertBefore: true),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_right, size: iconSize),
              tooltip: 'Insert column right',
              style: buttonStyle,
              onPressed: () => editor.submit(
                InsertTableColumnRequest(nodeId: nodeId, colIndex: maxCol, insertBefore: false),
              ),
            ),
            divider(),
            // Delete row / column / table
            IconButton(
              icon: Icon(Icons.table_rows_outlined, size: iconSize, color: deleteColor),
              tooltip: 'Delete row',
              style: buttonStyle,
              onPressed: () {
                // Delete selected rows from bottom to top to preserve indices.
                for (int r = maxRow; r >= minRow; r--) {
                  editor.submit(DeleteTableRowRequest(nodeId: nodeId, rowIndex: r));
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.view_column_outlined, size: iconSize, color: deleteColor),
              tooltip: 'Delete column',
              style: buttonStyle,
              onPressed: () {
                // Delete selected columns from right to left to preserve indices.
                for (int c = maxCol; c >= minCol; c--) {
                  editor.submit(DeleteTableColumnRequest(nodeId: nodeId, colIndex: c));
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: iconSize, color: deleteColor),
              tooltip: 'Delete table',
              style: buttonStyle,
              onPressed: () => editor.submit(DeleteTableRequest(nodeId: nodeId)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table insert button with grid-size picker popup
// ---------------------------------------------------------------------------

/// A toolbar button that opens an 8×8 grid picker for choosing table dimensions.
///
/// Tapping the button shows an [OverlayEntry] positioned below the button.
/// Hovering over the grid highlights cells to preview the selected row/column
/// count. Clicking a cell inserts a table and closes the popup.
class _TableInsertButton extends StatefulWidget {
  const _TableInsertButton({
    required this.enabled,
    required this.onInsert,
  });

  /// Whether the button is interactive (false when there is no cursor).
  final bool enabled;

  /// Called with the chosen (rows, cols) when the user confirms a selection.
  final void Function(int rows, int cols) onInsert;

  @override
  State<_TableInsertButton> createState() => _TableInsertButtonState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('enabled', value: enabled, ifTrue: 'enabled'));
    properties.add(
      ObjectFlagProperty<void Function(int, int)>.has('onInsert', onInsert),
    );
  }
}

class _TableInsertButtonState extends State<_TableInsertButton> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _showPicker() {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => _TableSizePickerOverlay(
        layerLink: _layerLink,
        onSelect: (rows, cols) {
          _hideOverlay();
          widget.onInsert(rows, cols);
        },
        onDismiss: _hideOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        icon: const Icon(Icons.table_chart_outlined, size: 18),
        onPressed: widget.enabled ? _showPicker : null,
        tooltip: 'Insert table',
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          padding: const EdgeInsets.all(4),
        ),
      ),
    );
  }
}

/// Overlay popup showing an 8×8 grid for picking table dimensions.
///
/// Uses [CompositedTransformFollower] to anchor below the originating button.
/// Mouse hover updates the highlighted region; tapping a cell confirms the
/// selection and calls [onSelect].
class _TableSizePickerOverlay extends StatefulWidget {
  const _TableSizePickerOverlay({
    required this.layerLink,
    required this.onSelect,
    required this.onDismiss,
    this.existingRows,
    this.existingCols,
  });

  final LayerLink layerLink;

  /// Called with the chosen (rows, cols) when the user taps a cell.
  final void Function(int rows, int cols) onSelect;

  /// Called when the user taps outside the popup.
  final VoidCallback onDismiss;

  /// Current table row count, shown with a distinct fill in the grid.
  final int? existingRows;

  /// Current table column count, shown with a distinct fill in the grid.
  final int? existingCols;

  @override
  State<_TableSizePickerOverlay> createState() => _TableSizePickerOverlayState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LayerLink>('layerLink', layerLink));
    properties.add(
      ObjectFlagProperty<void Function(int, int)>.has('onSelect', onSelect),
    );
    properties.add(ObjectFlagProperty<VoidCallback>.has('onDismiss', onDismiss));
  }
}

class _TableSizePickerOverlayState extends State<_TableSizePickerOverlay> {
  static const int _maxRows = 8;
  static const int _maxCols = 8;
  static const double _cellSize = 24.0;
  static const double _cellSpacing = 2.0;

  int _hoverRow = 0;
  int _hoverCol = 0;

  void _onHover(Offset localPosition) {
    final col = (localPosition.dx / (_cellSize + _cellSpacing)).floor().clamp(0, _maxCols - 1);
    final row = (localPosition.dy / (_cellSize + _cellSpacing)).floor().clamp(0, _maxRows - 1);
    if (row != _hoverRow || col != _hoverCol) {
      setState(() {
        _hoverRow = row;
        _hoverCol = col;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const gridWidth = _maxCols * (_cellSize + _cellSpacing) - _cellSpacing;
    const gridHeight = _maxRows * (_cellSize + _cellSpacing) - _cellSpacing;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Full-screen transparent layer to catch outside taps.
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        // Popup anchored to the button via CompositedTransformFollower.
        CompositedTransformFollower(
          link: widget.layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MouseRegion(
                    onHover: (event) => _onHover(event.localPosition),
                    child: GestureDetector(
                      onTapUp: (_) => widget.onSelect(_hoverRow + 1, _hoverCol + 1),
                      child: SizedBox(
                        width: gridWidth,
                        height: gridHeight,
                        child: CustomPaint(
                          painter: _GridPainter(
                            maxRows: _maxRows,
                            maxCols: _maxCols,
                            cellSize: _cellSize,
                            cellSpacing: _cellSpacing,
                            selectedRows: _hoverRow + 1,
                            selectedCols: _hoverCol + 1,
                            existingRows: widget.existingRows ?? 0,
                            existingCols: widget.existingCols ?? 0,
                            highlightColor: colorScheme.primary.withValues(alpha: 0.3),
                            existingColor: colorScheme.primary.withValues(alpha: 0.12),
                            borderColor: colorScheme.outline.withValues(alpha: 0.3),
                            selectedBorderColor: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_hoverRow + 1} \u00d7 ${_hoverCol + 1}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// [CustomPainter] that draws the table size picker grid.
///
/// Cells in rows 0..[selectedRows)-1 and columns 0..[selectedCols)-1 are
/// filled with [highlightColor] and outlined with [selectedBorderColor].
/// All other cells are outlined with [borderColor] only.
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.maxRows,
    required this.maxCols,
    required this.cellSize,
    required this.cellSpacing,
    required this.selectedRows,
    required this.selectedCols,
    required this.existingRows,
    required this.existingCols,
    required this.highlightColor,
    required this.existingColor,
    required this.borderColor,
    required this.selectedBorderColor,
  });

  final int maxRows;
  final int maxCols;
  final double cellSize;
  final double cellSpacing;
  final int selectedRows;
  final int selectedCols;
  final int existingRows;
  final int existingCols;
  final Color highlightColor;
  final Color existingColor;
  final Color borderColor;
  final Color selectedBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(3);
    final fillPaint = Paint()..color = highlightColor;
    final existingPaint = Paint()..color = existingColor;
    final selectedStroke = Paint()
      ..color = selectedBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final normalStroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int r = 0; r < maxRows; r++) {
      for (int c = 0; c < maxCols; c++) {
        final rect = Rect.fromLTWH(
          c * (cellSize + cellSpacing),
          r * (cellSize + cellSpacing),
          cellSize,
          cellSize,
        );
        final rrect = RRect.fromRectAndRadius(rect, radius);
        final isSelected = r < selectedRows && c < selectedCols;
        final isExisting = r < existingRows && c < existingCols;

        if (isSelected) {
          canvas.drawRRect(rrect, fillPaint);
        } else if (isExisting) {
          canvas.drawRRect(rrect, existingPaint);
        }
        canvas.drawRRect(rrect, isSelected ? selectedStroke : normalStroke);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.selectedRows != selectedRows ||
      old.selectedCols != selectedCols ||
      old.existingRows != existingRows ||
      old.existingCols != existingCols ||
      old.highlightColor != highlightColor ||
      old.existingColor != existingColor ||
      old.borderColor != borderColor ||
      old.selectedBorderColor != selectedBorderColor;
}
