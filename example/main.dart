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
/// - JSON save/load round-trip with full attribution serialization
///
/// Run with: `flutter run -t example/main.dart`
library;

import 'dart:convert';

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
      title: 'EditableDocument Demo',
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

  /// Counter for generating unique node IDs.
  int _nextNodeId = 100;

  /// Vertical spacing between document blocks.
  double _blockSpacing = 0.0;

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
    _controller.removeListener(_onDocumentChanged);
    _document.changes.removeListener(_onDocumentChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDocumentChanged() {
    setState(() {});
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
      ParagraphNode(
        id: 'quote-1',
        text: AttributedText(
          'EditableDocument is to block documents what EditableText '
          'is to single-field text.',
        ),
        blockType: ParagraphBlockType.blockquote,
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
    String? emptyNodeId;
    if (sel != null) {
      final selected = _document.nodeById(sel.extent.nodeId);
      if (selected is TextNode && selected.text.text.isEmpty) {
        emptyNodeId = selected.id;
      }
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
    }
  }

  // ---------------------------------------------------------------------------
  // Block type changes
  // ---------------------------------------------------------------------------

  void _changeBlockType(ParagraphBlockType blockType) {
    final sel = _controller.selection;
    if (sel == null) return;
    final node = _document.nodeById(sel.extent.nodeId);
    if (node is! ParagraphNode) return;
    _editor.submit(ChangeBlockTypeRequest(
      nodeId: node.id,
      newBlockType: blockType,
    ));
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
    } else if (node is CodeBlockNode) {
      return 'Code block';
    } else if (node is HorizontalRuleNode) {
      return 'Horizontal rule';
    } else if (node is ImageNode) {
      return 'Image';
    }
    return '';
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
      appBar: AppBar(
        title: const Text('EditableDocument Demo'),
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: _buildEditor(),
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
    final isOnParagraph = selectedNode is ParagraphNode;
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
                // --- Block type dropdown ---
                _buildBlockTypeDropdown(isOnParagraph, selectedNode),
                const SizedBox(width: 8),
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
                // --- Lists ---
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted, size: iconSize),
                  onPressed: hasCursor
                      ? () => _insertNode(ListItemNode(
                            id: _newId(),
                            text: AttributedText(),
                            type: ListItemType.unordered,
                          ))
                      : null,
                  tooltip: 'Bullet list',
                  style: buttonStyle,
                ),
                IconButton(
                  icon: const Icon(Icons.format_list_numbered, size: iconSize),
                  onPressed: hasCursor
                      ? () => _insertNode(ListItemNode(
                            id: _newId(),
                            text: AttributedText(),
                            type: ListItemType.ordered,
                          ))
                      : null,
                  tooltip: 'Numbered list',
                  style: buttonStyle,
                ),
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

  Widget _buildBlockTypeDropdown(bool isOnParagraph, DocumentNode? selectedNode) {
    final current = _currentBlockTypeValue(selectedNode);
    return SizedBox(
      width: 140,
      height: 32,
      child: DropdownButtonFormField<String>(
        initialValue: current,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          isDense: true,
        ),
        style: Theme.of(context).textTheme.bodySmall,
        items: const [
          DropdownMenuItem(value: 'paragraph', child: Text('Paragraph')),
          DropdownMenuItem(value: 'header1', child: Text('Heading 1')),
          DropdownMenuItem(value: 'header2', child: Text('Heading 2')),
          DropdownMenuItem(value: 'header3', child: Text('Heading 3')),
          DropdownMenuItem(value: 'blockquote', child: Text('Blockquote')),
        ],
        onChanged: isOnParagraph
            ? (value) {
                if (value == null) return;
                final blockType = ParagraphBlockType.values.firstWhere(
                  (bt) => bt.name == value,
                  orElse: () => ParagraphBlockType.paragraph,
                );
                _changeBlockType(blockType);
              }
            : null,
      ),
    );
  }

  String? _currentBlockTypeValue(DocumentNode? node) {
    if (node is ParagraphNode) return node.blockType.name;
    return null;
  }

  Widget _buildInsertMenu(bool enabled) {
    return PopupMenuButton<String>(
      tooltip: 'Insert',
      enabled: enabled,
      offset: const Offset(0, 36),
      onSelected: (value) {
        switch (value) {
          case 'code':
            _insertNode(CodeBlockNode(
              id: _newId(),
              text: AttributedText(),
              language: 'dart',
            ));
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
        PopupMenuItem(value: 'code', child: Text('Code block')),
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

  Widget _buildEditor() {
    return DocumentScrollable(
      controller: _controller,
      layoutKey: _layoutKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DocumentMouseInteractor(
          controller: _controller,
          layoutKey: _layoutKey,
          document: _document,
          focusNode: _focusNode,
          child: Stack(
            children: [
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
                  blockSpacing: _blockSpacing,
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
