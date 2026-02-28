// Copyright 2024 Simon Horn. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

/// Minimal example demonstrating the editable_document model and rendering
/// layers.
///
/// This example creates a document with various block types — headings,
/// paragraphs with attributed text, list items, a code block, a horizontal
/// rule, and an image placeholder — then renders them on screen using thin
/// [LeafRenderObjectWidget] wrappers around the per-block render objects.
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

/// Demonstrates document model + rendering.
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

  @override
  void initState() {
    super.initState();
    _document = _buildSampleDocument();
    _controller = DocumentEditingController(document: _document);
    _editor = UndoableEditor(
      editContext: EditContext(document: _document, controller: _controller),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  MutableDocument _buildSampleDocument() {
    final boldHello = AttributedText('Hello, editable_document!')
      ..applyAttribution(NamedAttribution.bold, 0, 4);

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
        text: AttributedText(
          'A drop-in replacement for EditableText with full block-level '
          'document model support.',
        ),
      ),
      ParagraphNode(
        id: 'features-heading',
        text: AttributedText('Features'),
        blockType: ParagraphBlockType.header2,
      ),
      ListItemNode(
        id: 'feature-1',
        text: AttributedText('Block-level document model'),
        type: ListItemType.unordered,
      ),
      ListItemNode(
        id: 'feature-2',
        text: AttributedText('Per-block render objects'),
        type: ListItemType.unordered,
      ),
      ListItemNode(
        id: 'feature-3',
        text: AttributedText('Event-sourced command pipeline'),
        type: ListItemType.unordered,
      ),
      ListItemNode(
        id: 'feature-4',
        text: AttributedText('Snapshot-based undo/redo'),
        type: ListItemType.unordered,
      ),
      HorizontalRuleNode(id: 'rule'),
      ParagraphNode(
        id: 'code-heading',
        text: AttributedText('Code example'),
        blockType: ParagraphBlockType.header3,
      ),
      CodeBlockNode(
        id: 'code',
        text: AttributedText(
          'final doc = MutableDocument(nodes: [\n'
          '  ParagraphNode(\n'
          '    id: "1",\n'
          '    text: AttributedText("Hello"),\n'
          '  ),\n'
          ']);',
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
    ]);
  }

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
            for (final node in _document.nodes) ...[
              _buildBlockWidget(node),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlockWidget(DocumentNode node) {
    return switch (node) {
      ParagraphNode() => ParagraphBlockWidget(node: node),
      ListItemNode() => ListItemBlockWidget(
          node: node,
          ordinalIndex: _ordinalIndexFor(node),
        ),
      CodeBlockNode() => CodeBlockWidget(node: node),
      HorizontalRuleNode() => HorizontalRuleBlockWidget(node: node),
      ImageNode() => ImageBlockWidget(node: node),
      _ => const SizedBox.shrink(),
    };
  }

  int _ordinalIndexFor(ListItemNode node) {
    var index = 1;
    for (final n in _document.nodes) {
      if (n.id == node.id) break;
      if (n is ListItemNode && n.type == ListItemType.ordered && n.indent == node.indent) {
        index++;
      }
    }
    return index;
  }
}

// ---------------------------------------------------------------------------
// Thin LeafRenderObjectWidget wrappers
// ---------------------------------------------------------------------------

/// Renders a [ParagraphNode] using [RenderParagraphBlock].
class ParagraphBlockWidget extends LeafRenderObjectWidget {
  /// Creates a paragraph block widget.
  const ParagraphBlockWidget({super.key, required this.node});

  /// The paragraph node to render.
  final ParagraphNode node;

  @override
  RenderParagraphBlock createRenderObject(BuildContext context) {
    return RenderParagraphBlock(
      nodeId: node.id,
      text: node.text,
      blockType: node.blockType,
      baseTextStyle: DefaultTextStyle.of(context).style,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderParagraphBlock renderObject) {
    renderObject
      ..nodeId = node.id
      ..text = node.text
      ..blockType = node.blockType
      ..baseTextStyle = DefaultTextStyle.of(context).style;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ParagraphNode>('node', node));
  }
}

/// Renders a [ListItemNode] using [RenderListItemBlock].
class ListItemBlockWidget extends LeafRenderObjectWidget {
  /// Creates a list item block widget.
  const ListItemBlockWidget({
    super.key,
    required this.node,
    this.ordinalIndex = 1,
  });

  /// The list item node to render.
  final ListItemNode node;

  /// The 1-based ordinal index for ordered list items.
  final int ordinalIndex;

  @override
  RenderListItemBlock createRenderObject(BuildContext context) {
    return RenderListItemBlock(
      nodeId: node.id,
      text: node.text,
      type: node.type,
      indent: node.indent,
      ordinalIndex: ordinalIndex,
      textStyle: DefaultTextStyle.of(context).style,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderListItemBlock renderObject) {
    renderObject
      ..nodeId = node.id
      ..text = node.text
      ..type = node.type
      ..indent = node.indent
      ..ordinalIndex = ordinalIndex
      ..textStyle = DefaultTextStyle.of(context).style;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ListItemNode>('node', node));
    properties.add(IntProperty('ordinalIndex', ordinalIndex));
  }
}

/// Renders a [CodeBlockNode] using [RenderCodeBlock].
class CodeBlockWidget extends LeafRenderObjectWidget {
  /// Creates a code block widget.
  const CodeBlockWidget({super.key, required this.node});

  /// The code block node to render.
  final CodeBlockNode node;

  @override
  RenderCodeBlock createRenderObject(BuildContext context) {
    return RenderCodeBlock(
      nodeId: node.id,
      text: node.text,
      baseTextStyle: DefaultTextStyle.of(context).style,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderCodeBlock renderObject) {
    renderObject
      ..nodeId = node.id
      ..text = node.text;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CodeBlockNode>('node', node));
  }
}

/// Renders a [HorizontalRuleNode] using [RenderHorizontalRuleBlock].
class HorizontalRuleBlockWidget extends LeafRenderObjectWidget {
  /// Creates a horizontal rule widget.
  const HorizontalRuleBlockWidget({super.key, required this.node});

  /// The horizontal rule node to render.
  final HorizontalRuleNode node;

  @override
  RenderHorizontalRuleBlock createRenderObject(BuildContext context) {
    return RenderHorizontalRuleBlock(nodeId: node.id);
  }

  @override
  void updateRenderObject(BuildContext context, RenderHorizontalRuleBlock renderObject) {
    renderObject.nodeId = node.id;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<HorizontalRuleNode>('node', node));
  }
}

/// Renders an [ImageNode] using [RenderImageBlock].
class ImageBlockWidget extends LeafRenderObjectWidget {
  /// Creates an image block widget.
  const ImageBlockWidget({super.key, required this.node});

  /// The image node to render.
  final ImageNode node;

  @override
  RenderImageBlock createRenderObject(BuildContext context) {
    return RenderImageBlock(
      nodeId: node.id,
      imageWidth: node.width,
      imageHeight: node.height,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderImageBlock renderObject) {
    renderObject
      ..nodeId = node.id
      ..imageWidth = node.width
      ..imageHeight = node.height;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ImageNode>('node', node));
  }
}
