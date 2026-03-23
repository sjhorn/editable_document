// Copyright 2024 Simon Horn. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

/// Example app showcasing EditableDocument — a rich-text block editor.
///
/// Demonstrates DocumentToolbar, DocumentPropertyPanel,
/// DocumentSettingsPanel, DocumentStatusBar, DocumentTheme, and
/// DocumentJsonSerializer from the editable_document core library.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';

import 'package:editable_document/editable_document.dart';

import 'sample_document.dart';

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

class _DocumentDemoState extends State<DocumentDemo> with TickerProviderStateMixin {
  late final MutableDocument _document;
  late final DocumentEditingController _controller;
  late final UndoableEditor _editor;
  late final FocusNode _focusNode;

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
    _document = buildSampleDocument();
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
    _panelTabController?.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDocumentChanged() {
    final sel = _controller.selection;
    final node = sel != null ? _document.nodeById(sel.extent.nodeId) : null;
    if (node == null && _showBlockPanel) {
      _showBlockPanel = false;
      _syncPanelTabController();
    }
    setState(() {});
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
  // Panel toggle logic
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
  Widget _buildInlineTableToolbar(GlobalKey<DocumentLayoutState> layoutKey) {
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
    final component = layoutKey.currentState?.componentForNode(node.id);
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
    return DocumentEditor(
      controller: _controller,
      focusNode: _focusNode,
      editor: _editor,
      autofocus: true,
      blockSpacing: _blockSpacing,
      style: TextStyle(height: _defaultLineHeight),
      documentPadding: EdgeInsets.symmetric(
        horizontal: _documentPaddingH,
        vertical: _documentPaddingV,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      lineNumberBackgroundColor: _lineNumberBgColor != null ? Color(_lineNumberBgColor!) : null,
      componentBuilders: [
        _syntaxBuilder,
        ...defaultComponentBuilders.where((b) => b is! CodeBlockComponentBuilder),
      ],
      overlayBuilder: (context, controller, layoutKey) => [
        _buildInlineTableToolbar(layoutKey),
      ],
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
