// Copyright 2024 Simon Horn. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

/// Example app showcasing EditableDocument — a rich-text block editor.
///
/// Demonstrates DocumentEditor with built-in toolbar, property panel,
/// settings panel, and status bar from the editable_document core library.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:editable_document/editable_document.dart';

import 'sample_document.dart';
import 'syntax_highlight.dart';

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

  final _syntaxBuilder = SyntaxHighlightCodeBlockBuilder();

  @override
  void initState() {
    super.initState();
    _document = buildSampleDocument();
    _controller = DocumentEditingController(document: _document);
    _editor = UndoableEditor(
      editContext: EditContext(document: _document, controller: _controller),
    );
    _focusNode = FocusNode(debugLabel: 'DocumentDemo');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
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
  // Image picker — app-specific: shows a path-entry dialog.
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DocumentTheme(
      data: DocumentThemeData(
        caretColor: Colors.blue,
        selectionColor: Colors.blue.withValues(alpha: 0.3),
        codeBlockBackgroundColor: const Color(0xFFF5F5F5),
        propertyPanelTheme: const PropertyPanelThemeData(width: 280),
      ),
      child: Scaffold(
        body: DocumentEditor(
          controller: _controller,
          focusNode: _focusNode,
          editor: _editor,
          autofocus: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          showPropertyPanel: true,
          showSettingsPanel: true,
          onPickImageFile: _pickImageFile,
          toolbarLeading: Row(
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
          componentBuilders: [
            _syntaxBuilder,
            ...defaultComponentBuilders.where((b) => b is! CodeBlockComponentBuilder),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MutableDocument>('document', _document));
    properties.add(
      DiagnosticsProperty<DocumentEditingController>('controller', _controller),
    );
  }
}
