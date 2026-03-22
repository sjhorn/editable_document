// Copyright 2024 Simon Horn. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

import 'package:flutter/painting.dart';

import 'package:editable_document/editable_document.dart';

/// Builds a sample [MutableDocument] demonstrating all supported node types
/// and features.
///
/// Used by the example app to populate the editor on first launch and as the
/// target when loading JSON fails validation.
MutableDocument buildSampleDocument() {
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
