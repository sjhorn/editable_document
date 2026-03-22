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
/// - Clipboard (Cmd/Ctrl+C/X/V/A) and right-click context menu via
///   defaultDocumentContextMenuButtonItems
/// - JSON save/load round-trip via DocumentJsonSerializer
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
/// - TableContextToolbar (core widget): contextual toolbar above the table cell
///   for resize, column text alignment, row vertical alignment, row/column
///   insertion, and deletion
/// - DocumentStatusBar (core widget): block count, word count, character count,
///   and current block type label, updated automatically from the controller
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
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (BuildContext menuContext) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: TextSelectionToolbarAnchors(primaryAnchor: globalPosition),
          buttonItems: defaultDocumentContextMenuButtonItems(
            controller: _controller,
            clipboard: _clipboard,
            requestHandler: _editor.submit,
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

  // ---------------------------------------------------------------------------
  // JSON save/load
  // ---------------------------------------------------------------------------

  static const _serializer = DocumentJsonSerializer();

  void _showSaveDialog() {
    final json = const JsonEncoder.withIndent('  ').convert(_serializer.toJson(_document));
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
    final nodes = _serializer.fromJson(data);
    if (nodes.isEmpty) return;
    _controller.clearSelection();
    _document.reset(nodes);
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
      child: TableContextToolbar(
        controller: _controller,
        requestHandler: _editor.submit,
        nodeId: node.id,
        minRow: minRow,
        maxRow: maxRow,
        minCol: minCol,
        maxCol: maxCol,
        cellTextAligns: node.cellTextAligns,
        cellVerticalAligns: node.cellVerticalAligns,
        rowCount: node.rowCount,
        columnCount: node.columnCount,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: DocumentStatusBar(controller: _controller),
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
