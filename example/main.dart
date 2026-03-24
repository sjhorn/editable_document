// Copyright 2026 Scott Horn. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

/// Minimal example of [DocumentEditor] — a rich-text block editor.
///
/// This single-file example shows how to create a full editor with toolbar,
/// property panel, settings panel, and status bar using sensible defaults.
/// For a full-featured example with syntax highlighting, JSON persistence,
/// and image picker, see `example/complex_example/`.
library;

import 'package:flutter/material.dart';

import 'package:editable_document/editable_document.dart';

void main() {
  runApp(const EditableDocumentExample());
}

/// A minimal rich-text block editor.
class EditableDocumentExample extends StatefulWidget {
  /// Creates the example.
  const EditableDocumentExample({super.key});

  @override
  State<EditableDocumentExample> createState() => _EditableDocumentExampleState();
}

class _EditableDocumentExampleState extends State<EditableDocumentExample> {
  late final MutableDocument _document;
  late final DocumentEditingController _controller;
  late final UndoableEditor _editor;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _document = _buildSampleDocument();
    _controller = DocumentEditingController(document: _document);
    _editor = UndoableEditor(
      editContext: EditContext(document: _document, controller: _controller),
    );
    _focusNode = FocusNode(debugLabel: 'EditableDocumentExample');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EditableDocument Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: DocumentEditor(
          controller: _controller,
          focusNode: _focusNode,
          editor: _editor,
          autofocus: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          showPropertyPanel: true,
          showSettingsPanel: true,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sample document
// ---------------------------------------------------------------------------

/// Builds a sample document with a variety of block types.
MutableDocument _buildSampleDocument() {
  return MutableDocument([
    ParagraphNode(
      id: 'title',
      text: AttributedText('Welcome to EditableDocument'),
      blockType: ParagraphBlockType.header1,
    ),
    ParagraphNode(
      id: 'intro',
      text: AttributedText(
        'EditableDocument is a drop-in replacement for Flutter\'s '
        'EditableText with full block-level document model support. '
        'Try editing this document — use the toolbar above to format '
        'text, insert blocks, and change styles.',
      ),
    ),
    ParagraphNode(
      id: 'h2-features',
      text: AttributedText('Features'),
      blockType: ParagraphBlockType.header2,
    ),
    ListItemNode(
      id: 'feature-1',
      text: AttributedText('Rich text with bold, italic, and underline'),
      type: ListItemType.unordered,
      indent: 0,
    ),
    ListItemNode(
      id: 'feature-2',
      text: AttributedText('Headings (H1-H6), blockquotes, and code blocks'),
      type: ListItemType.unordered,
      indent: 0,
    ),
    ListItemNode(
      id: 'feature-3',
      text: AttributedText('Ordered and unordered lists with indentation'),
      type: ListItemType.unordered,
      indent: 0,
    ),
    ListItemNode(
      id: 'feature-4',
      text: AttributedText('Images, tables, and horizontal rules'),
      type: ListItemType.unordered,
      indent: 0,
    ),
    ListItemNode(
      id: 'feature-5',
      text: AttributedText('Undo/redo, property panels, and theming'),
      type: ListItemType.unordered,
      indent: 0,
    ),
    ParagraphNode(
      id: 'h2-code',
      text: AttributedText('Code Example'),
      blockType: ParagraphBlockType.header2,
    ),
    CodeBlockNode(
      id: 'code-1',
      text: AttributedText(
        'DocumentEditor(\n'
        '  controller: controller,\n'
        '  editor: editor,\n'
        '  autofocus: true,\n'
        '  showPropertyPanel: true,\n'
        '  showSettingsPanel: true,\n'
        ')',
      ),
      language: 'dart',
    ),
    ParagraphNode(
      id: 'h2-try',
      text: AttributedText('Try It Out'),
      blockType: ParagraphBlockType.header2,
    ),
    ParagraphNode(
      id: 'try-text',
      text: AttributedText(
        'Click anywhere in this document to start editing. Use the '
        'toolbar to apply formatting, insert new block types, or '
        'toggle the property and settings panels on the right.',
      ),
    ),
    HorizontalRuleNode(id: 'hr-1'),
    ParagraphNode(
      id: 'footer',
      text: AttributedText(
        'Built with editable_document — zero external dependencies.',
      ),
    ),
  ]);
}
