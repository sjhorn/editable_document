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
/// - BlockBorder: solid, dashed, and dotted outside borders on individual blocks
/// - DocumentPropertyPanel: core block-property panel widget wired via the
///   Block Properties toggle button; shows text alignment, line height, spacing,
///   border, indent, and block layout (alignment, text wrap, dimensions) for the
///   selected block — all routing handled by the core widget
/// - DocumentTheme: wraps the entire screen with DocumentThemeData (block spacing,
///   caret color, selection color, code block background, property panel width)
/// - Document Settings panel (when nothing selected): block spacing, default line height,
///   document padding, and line number gutter controls
/// - documentPadding: EdgeInsets applied around the content area (horizontal/vertical
///   sliders wired live via Document Settings panel)
/// - showLineNumbers: optional left-gutter that numbers each block sequentially,
///   toggled from the Document Settings panel with a configurable background color
/// - lineNumberAlignment: segmented control (Top / Middle / Bottom) in the Document
///   Settings panel that sets vertical alignment of each line number label within
///   its block row; only visible when showLineNumbers is enabled
/// - DocumentToolbar: core toolbar widget wired as the main toolbar; file
///   actions (save/load JSON) and panel toggles are passed via leading/trailing
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

class _DocumentDemoState extends State<DocumentDemo> with TickerProviderStateMixin {
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

  /// Vertical spacing between document blocks.
  double _blockSpacing = 0.0;

  /// Document-level default line height multiplier. `null` means inherit.
  double? _defaultLineHeight;

  /// Horizontal padding (left + right) around the document content area.
  double _documentPaddingH = 0.0;

  /// Vertical padding (top + bottom) around the document content area.
  double _documentPaddingV = 0.0;

  /// Whether to show line numbers in a left-side gutter.
  bool _showLineNumbers = false;

  /// Vertical alignment of each line number label within its block row.
  LineNumberAlignment _lineNumberAlignment = LineNumberAlignment.top;

  /// Font family for line numbers (`null` = inherit from document).
  String? _lineNumberFontFamily;

  /// Font size for line numbers (`null` = inherit from document).
  double? _lineNumberFontSize;

  /// Text color for line numbers (`null` = inherit from document).
  int? _lineNumberColor;

  /// Background color for the line number gutter (`null` = transparent).
  int? _lineNumberBgColor;

  bool _showBlockPanel = false;
  bool _showDocumentPanel = false;
  TabController? _panelTabController;

  /// Preset color swatches for text-color and background-color pickers.
  ///
  /// Keys are ARGB 32-bit integer values; values are display labels.
  static const _colorPresets = {
    0x00000000: 'Transparent',
    0xFFFFFFFF: 'White',
    0xFF000000: 'Black',
    0xFF9E9E9E: 'Grey',
    0xFFF5F5F5: 'Light Grey',
    0xFFF44336: 'Red',
    0xFF4CAF50: 'Green',
    0xFF2196F3: 'Blue',
    0xFFFF9800: 'Orange',
    0xFF9C27B0: 'Purple',
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
    _panelTabController?.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDocumentChanged() {
    _contextMenuController.remove();
    final sel = _controller.selection;
    final node = sel != null ? _document.nodeById(sel.extent.nodeId) : null;
    if (node == null && _showBlockPanel) {
      _showBlockPanel = false;
      _syncPanelTabController();
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
      // 50%-width code block — demonstrates BlockDimension.percent().
      // The block occupies half the document column regardless of viewport
      // width, centre-aligned so it sits in the middle.
      CodeBlockNode(
        id: 'code-percent-width',
        text: AttributedText(
          '// BlockDimension.percent(0.5) = 50% of document width\n'
          'final w = BlockDimension.percent(0.5);',
        ),
        language: 'dart',
        width: const BlockDimension.percent(0.5),
        alignment: BlockAlignment.center,
      ),
      ParagraphNode(
        id: 'percent-width-caption',
        text: AttributedText(
          'The code block above uses BlockDimension.percent(0.5), so it always '
          'occupies 50 % of the document column width. Resize the window to see '
          'it reflow. Fixed-pixel dimensions use BlockDimension.pixels(value).',
        ),
      ),
      // Center-aligned image.
      ImageNode(
        id: 'img-center',
        imageUrl: 'https://picsum.photos/300/150',
        altText: 'Center-aligned image',
        width: const BlockDimension.pixels(300),
        height: const BlockDimension.pixels(150),
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
        width: const BlockDimension.pixels(200),
        height: const BlockDimension.pixels(250),
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
        width: const BlockDimension.pixels(250),
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
        width: const BlockDimension.pixels(250),
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
        width: const BlockDimension.pixels(150),
        height: const BlockDimension.pixels(100),
        alignment: BlockAlignment.start,
        textWrap: TextWrapMode.wrap,
      ),
      // End-aligned (right) float.
      ImageNode(
        id: 'img-dual-end',
        imageUrl: 'https://picsum.photos/seed/dual-right/150/100',
        altText: 'Right float image',
        width: const BlockDimension.pixels(150),
        height: const BlockDimension.pixels(100),
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
        width: const BlockDimension.pixels(400),
        height: const BlockDimension.pixels(120),
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
      // --- Block Borders section ---
      //
      // BlockBorder lets you draw a solid, dashed, or dotted outline around
      // any document block. The border is paint-only — it does not inset the
      // block's content area — and each block accepts an independent border.
      HorizontalRuleNode(id: 'rule-before-borders'),
      ParagraphNode(
        id: 'h2-borders',
        text: AttributedText('Block Borders'),
        blockType: ParagraphBlockType.header2,
      ),
      ParagraphNode(
        id: 'borders-intro',
        text: AttributedText(
          'Any document block can carry an optional BlockBorder that is drawn '
          'around its outside bounds. Three styles are available: solid, dashed, '
          'and dotted. The border does not affect layout — content dimensions '
          'are unchanged.',
        ),
      ),
      // Solid border — blue, 2 px.
      ParagraphNode(
        id: 'border-solid',
        text: AttributedText(
          'Solid border — 2 px blue outline drawn with BlockBorderStyle.solid.',
        ),
        border: const BlockBorder(
          style: BlockBorderStyle.solid,
          width: 2.0,
          color: Color(0xFF2196F3),
        ),
      ),
      // Dashed border — orange, 1.5 px, on a code block.
      CodeBlockNode(
        id: 'border-dashed',
        text: AttributedText(
          'final border = BlockBorder(\n'
          '  style: BlockBorderStyle.dashed,\n'
          '  width: 1.5,\n'
          '  color: Color(0xFFFF9800),\n'
          ');',
        ),
        language: 'dart',
        border: const BlockBorder(
          style: BlockBorderStyle.dashed,
          width: 1.5,
          color: Color(0xFFFF9800),
        ),
      ),
      // Dotted border — green, 2 px, on a blockquote.
      BlockquoteNode(
        id: 'border-dotted',
        text: AttributedText(
          'Dotted border — 2 px green outline drawn with BlockBorderStyle.dotted. '
          'Borders work on every block type, including blockquotes.',
        ),
        border: const BlockBorder(
          style: BlockBorderStyle.dotted,
          width: 2.0,
          color: Color(0xFF4CAF50),
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
        _addBorderFields(map, node.border);
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
        _addBorderFields(map, node.border);
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
        _addBorderFields(map, node.border);
        _addBlockLayoutFields(map, node);
        _addAttributionSpans(map, node.text);
      } else if (node is CodeBlockNode) {
        map['type'] = 'codeBlock';
        map['text'] = node.text.text;
        if (node.language != null) map['language'] = node.language;
        if (node.lineHeight != null) map['lineHeight'] = node.lineHeight;
        if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
        if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
        _addBorderFields(map, node.border);
        _addBlockLayoutFields(map, node);
      } else if (node is ImageNode) {
        map['type'] = 'image';
        map['imageUrl'] = node.imageUrl;
        if (node.altText != null) map['altText'] = node.altText;
        if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
        if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
        _addBorderFields(map, node.border);
        _addBlockLayoutFields(map, node);
      } else if (node is HorizontalRuleNode) {
        map['type'] = 'horizontalRule';
        if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
        if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
        _addBorderFields(map, node.border);
        _addBlockLayoutFields(map, node);
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

  /// Serializes [border] into [map] using three keys:
  ///
  /// - `borderStyle` — the [BlockBorderStyle.name] string.
  /// - `borderWidth` — the stroke width as a [double].
  /// - `borderColor` — the ARGB 32-bit integer (omitted when `color` is null).
  ///
  /// Does nothing when [border] is null.
  void _addBorderFields(Map<String, Object?> map, BlockBorder? border) {
    if (border == null) return;
    map['borderStyle'] = border.style.name;
    map['borderWidth'] = border.width;
    if (border.color != null) map['borderColor'] = border.color!.toARGB32();
  }

  /// Deserializes a [BlockBorder] from [map], or returns `null` when the
  /// `borderStyle` key is absent.
  BlockBorder? _parseBorder(Map<String, Object?> map) {
    final styleName = map['borderStyle'] as String?;
    if (styleName == null) return null;
    final style = BlockBorderStyle.values.firstWhere(
      (s) => s.name == styleName,
      orElse: () => BlockBorderStyle.solid,
    );
    return BlockBorder(
      style: style,
      width: (map['borderWidth'] as num?)?.toDouble() ?? 1.0,
      color: map['borderColor'] != null ? Color(map['borderColor']! as int) : null,
    );
  }

  /// Serializes a [BlockDimension] into a JSON-safe object.
  ///
  /// Pixels are stored as `{"type": "pixels", "value": <num>}`.
  /// Percent are stored as `{"type": "percent", "value": <num>}` where the
  /// stored value is the fractional representation (e.g. 0.5 for 50%).
  /// Returns `null` when [dim] is null.
  Map<String, Object?>? _blockDimensionToJson(BlockDimension? dim) {
    return switch (dim) {
      PixelDimension(:final value) => {'type': 'pixels', 'value': value},
      PercentDimension(:final value) => {'type': 'percent', 'value': value},
      null => null,
    };
  }

  /// Deserializes a [BlockDimension] from a JSON object produced by
  /// [_blockDimensionToJson], or returns `null` when [raw] is absent.
  BlockDimension? _parseBlockDimension(Object? raw) {
    if (raw == null) return null;
    final map = raw as Map<String, Object?>;
    final type = map['type'] as String?;
    final value = (map['value'] as num?)?.toDouble() ?? 0.0;
    return switch (type) {
      'percent' => BlockDimension.percent(value),
      _ => BlockDimension.pixels(value),
    };
  }

  /// Writes block-layout fields (width, height, alignment, textWrap) into
  /// [map] for nodes that implement [HasBlockLayout].
  ///
  /// Only non-default values are written to keep the JSON compact.
  void _addBlockLayoutFields(Map<String, Object?> map, HasBlockLayout node) {
    final widthJson = _blockDimensionToJson(node.width);
    if (widthJson != null) map['width'] = widthJson;
    final heightJson = _blockDimensionToJson(node.height);
    if (heightJson != null) map['height'] = heightJson;
    // Only write when not the default (stretch) to keep JSON compact.
    if (node.alignment != BlockAlignment.stretch) {
      map['blockAlignment'] = node.alignment.name;
    }
    if (node.textWrap != TextWrapMode.none) {
      map['textWrap'] = node.textWrap.name;
    }
  }

  /// Deserializes block-layout scalars (alignment, textWrap) from [map].
  ///
  /// Returns [BlockAlignment.stretch] when the key is absent, matching the
  /// default constructor value on all concrete [HasBlockLayout] nodes.
  BlockAlignment _parseBlockAlignment(Map<String, Object?> map) {
    final name = map['blockAlignment'] as String?;
    if (name == null) return BlockAlignment.stretch;
    return BlockAlignment.values.firstWhere(
      (e) => e.name == name,
      orElse: () => BlockAlignment.stretch,
    );
  }

  /// Deserializes [TextWrapMode] from [map], returning [TextWrapMode.none]
  /// when the key is absent.
  TextWrapMode _parseTextWrap(Map<String, Object?> map) {
    final name = map['textWrap'] as String?;
    if (name == null) return TextWrapMode.none;
    return TextWrapMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TextWrapMode.none,
    );
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
            border: _parseBorder(map),
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
            border: _parseBorder(map),
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
            border: _parseBorder(map),
            width: _parseBlockDimension(map['width']),
            height: _parseBlockDimension(map['height']),
            alignment: _parseBlockAlignment(map),
            textWrap: _parseTextWrap(map),
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
            border: _parseBorder(map),
            width: _parseBlockDimension(map['width']),
            height: _parseBlockDimension(map['height']),
            alignment: _parseBlockAlignment(map),
            textWrap: _parseTextWrap(map),
          ));
        case 'image':
          nodes.add(ImageNode(
            id: id,
            imageUrl: map['imageUrl'] as String? ?? '',
            altText: map['altText'] as String?,
            spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
            spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
            border: _parseBorder(map),
            width: _parseBlockDimension(map['width']),
            height: _parseBlockDimension(map['height']),
            alignment: _parseBlockAlignment(map),
            textWrap: _parseTextWrap(map),
          ));
        case 'horizontalRule':
          nodes.add(HorizontalRuleNode(
            id: id,
            spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
            spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
            border: _parseBorder(map),
            width: _parseBlockDimension(map['width']),
            height: _parseBlockDimension(map['height']),
            alignment: _parseBlockAlignment(map),
            textWrap: _parseTextWrap(map),
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
    return DocumentTheme(
      data: DocumentThemeData(
        defaultBlockSpacing: _blockSpacing,
        caretColor: Colors.blue,
        selectionColor: Colors.blue.withValues(alpha: 0.3),
        codeBlockBackgroundColor: const Color(0xFFF5F5F5),
        propertyPanelTheme: const PropertyPanelThemeData(
          width: 280,
        ),
      ),
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildToolbar() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final selectedNode = _controller.selection != null
            ? _document.nodeById(_controller.selection!.extent.nodeId)
            : null;
        return DocumentToolbar(
          controller: _controller,
          requestHandler: _editor.submit,
          editor: _editor,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.save_outlined, size: 18),
                onPressed: _showSaveDialog,
                tooltip: 'Save as JSON',
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: const EdgeInsets.all(4),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.file_open_outlined, size: 18),
                onPressed: _showLoadDialog,
                tooltip: 'Load from JSON',
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DocumentFormatToggle(
                icon: Icons.view_sidebar_outlined,
                tooltip: 'Block Properties',
                isActive: _showBlockPanel,
                onPressed: selectedNode != null ? _toggleBlockPanel : null,
              ),
              DocumentFormatToggle(
                icon: Icons.settings_outlined,
                tooltip: 'Document Settings',
                isActive: _showDocumentPanel,
                onPressed: _toggleDocumentPanel,
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Block property panel
  // ---------------------------------------------------------------------------

  void _toggleBlockPanel() {
    setState(() {
      _showBlockPanel = !_showBlockPanel;
      _syncPanelTabController();
    });
  }

  void _toggleDocumentPanel() {
    setState(() {
      _showDocumentPanel = !_showDocumentPanel;
      _syncPanelTabController();
    });
  }

  void _syncPanelTabController() {
    if (_showBlockPanel && _showDocumentPanel) {
      if (_panelTabController == null) {
        _panelTabController = TabController(length: 2, vsync: this);
      }
    } else {
      _panelTabController?.dispose();
      _panelTabController = null;
    }
  }

  /// Shows a dialog for choosing an image file path, then submits a
  /// [ReplaceNodeRequest] to update the current image node's URL.
  ///
  /// Does nothing if the current selection is not an [ImageNode].
  Future<void> _pickImageFile() async {
    final sel = _controller.selection;
    if (sel == null) return;
    final node = _document.nodeById(sel.extent.nodeId);
    if (node is! ImageNode) return;

    final textController = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Image File'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: '/path/to/image.png',
            labelText: 'File path',
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(textController.text),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (path == null || path.trim().isEmpty) return;
    _editor.submit(
      ReplaceNodeRequest(
        nodeId: node.id,
        newNode: ImageNode(
          id: node.id,
          imageUrl: path.trim(),
          altText: node.altText,
          width: node.width,
          height: node.height,
          alignment: node.alignment,
          textWrap: node.textWrap,
          lockAspect: node.lockAspect,
          border: node.border,
        ),
      ),
    );
  }

  /// Builds the document-wide settings panel using [DocumentSettingsPanel].
  Widget _buildDocumentSettingsPanel() {
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
      lineNumberFontFamily: _lineNumberFontFamily,
      onLineNumberFontFamilyChanged: (v) => setState(() => _lineNumberFontFamily = v),
      lineNumberFontSize: _lineNumberFontSize,
      onLineNumberFontSizeChanged: (v) => setState(() => _lineNumberFontSize = v),
      lineNumberColor: _lineNumberColor,
      onLineNumberColorChanged: (v) => setState(() => _lineNumberColor = v),
      lineNumberBackgroundColor: _lineNumberBgColor,
      onLineNumberBackgroundColorChanged: (v) => setState(() => _lineNumberBgColor = v),
      colorPresets: _colorPresets,
    );
  }

  Widget _buildPropertyPanel() {
    if (!_showBlockPanel && !_showDocumentPanel) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    const panelWidth = 280.0;

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
                tabs: const [
                  Tab(text: 'Block'),
                  Tab(text: 'Document'),
                ],
                labelStyle: Theme.of(context).textTheme.labelSmall,
              ),
              Expanded(
                child: TabBarView(
                  controller: _panelTabController,
                  children: [
                    DocumentPropertyPanel(
                      controller: _controller,
                      requestHandler: _editor.submit,
                      width: panelWidth,
                      onPickImageFile: _pickImageFile,
                    ),
                    _buildDocumentSettingsPanel(),
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
            controller: _controller,
            requestHandler: _editor.submit,
            width: panelWidth,
            onPickImageFile: _pickImageFile,
          ),
        ),
      );
    }

    return SizedBox(
      width: panelWidth,
      height: double.infinity,
      child: DecoratedBox(
        decoration: panelDecoration,
        child: _buildDocumentSettingsPanel(),
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
                lineNumberTextStyle:
                    (_lineNumberFontFamily ?? _lineNumberFontSize ?? _lineNumberColor) != null
                        ? TextStyle(
                            fontFamily: _lineNumberFontFamily,
                            fontSize: _lineNumberFontSize,
                            color: _lineNumberColor != null ? Color(_lineNumberColor!) : null,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )
                        : null,
                lineNumberBackgroundColor:
                    _lineNumberBgColor != null ? Color(_lineNumberBgColor!) : null,
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
    properties.add(DoubleProperty('defaultLineHeight', _defaultLineHeight, defaultValue: null));
    properties.add(DoubleProperty('documentPaddingH', _documentPaddingH));
    properties.add(DoubleProperty('documentPaddingV', _documentPaddingV));
    properties.add(
      FlagProperty('showLineNumbers', value: _showLineNumbers, ifTrue: 'showLineNumbers'),
    );
    properties.add(
      EnumProperty<LineNumberAlignment>('lineNumberAlignment', _lineNumberAlignment,
          defaultValue: LineNumberAlignment.top),
    );
    properties
        .add(StringProperty('lineNumberFontFamily', _lineNumberFontFamily, defaultValue: null));
    properties.add(DoubleProperty('lineNumberFontSize', _lineNumberFontSize, defaultValue: null));
    properties.add(IntProperty('lineNumberColor', _lineNumberColor, defaultValue: null));
    properties.add(IntProperty('lineNumberBgColor', _lineNumberBgColor, defaultValue: null));
    properties.add(
      FlagProperty('showBlockPanel', value: _showBlockPanel, ifTrue: 'showBlockPanel'),
    );
    properties.add(
      FlagProperty('showDocumentPanel', value: _showDocumentPanel, ifTrue: 'showDocumentPanel'),
    );
  }
}

// ---------------------------------------------------------------------------
// Table resize button — contextual table toolbar
// ---------------------------------------------------------------------------

/// A toolbar button in the contextual table toolbar that opens an 8×8 grid
/// picker for choosing the new table dimensions via [ResizeTableRequest].
///
/// Uses [_TableSizePickerOverlay] and calls [onResize] with the chosen
/// (rows, cols) when the user confirms a selection.
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
            DocumentFormatToggle(
              icon: Icons.format_align_left,
              tooltip: 'Align column left',
              isActive: colAlign == TextAlign.start,
              onPressed: () => _setCellAlign(TextAlign.start),
            ),
            DocumentFormatToggle(
              icon: Icons.format_align_center,
              tooltip: 'Align column center',
              isActive: colAlign == TextAlign.center,
              onPressed: () => _setCellAlign(TextAlign.center),
            ),
            DocumentFormatToggle(
              icon: Icons.format_align_right,
              tooltip: 'Align column right',
              isActive: colAlign == TextAlign.right,
              onPressed: () => _setCellAlign(TextAlign.right),
            ),
            divider(),
            // Row vertical alignment — applies to all selected rows
            DocumentFormatToggle(
              icon: Icons.vertical_align_top,
              tooltip: 'Align row top',
              isActive: rowVAlign == TableVerticalAlignment.top,
              onPressed: () => _setCellVAlign(TableVerticalAlignment.top),
            ),
            DocumentFormatToggle(
              icon: Icons.vertical_align_center,
              tooltip: 'Align row middle',
              isActive: rowVAlign == TableVerticalAlignment.middle,
              onPressed: () => _setCellVAlign(TableVerticalAlignment.middle),
            ),
            DocumentFormatToggle(
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
// Table size picker overlay (shared by resize button in context toolbar)
// ---------------------------------------------------------------------------

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
