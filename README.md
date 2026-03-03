# editable_document

[![pub package](https://img.shields.io/pub/v/editable_document.svg)](https://pub.dev/packages/editable_document)
[![CI](https://github.com/sjhorn/editable_document/actions/workflows/ci.yml/badge.svg)](https://github.com/sjhorn/editable_document/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/sjhorn/editable_document/branch/main/graph/badge.svg)](https://codecov.io/gh/sjhorn/editable_document)

A drop-in replacement for Flutter's `EditableText` with full block-level
document model support. `EditableDocument` is to block documents what
`EditableText` is to single-field text.

## Features

- **Block-structured document model** — paragraphs, headings, lists, code
  blocks, images, and horizontal rules as first-class node types.
- **Rich text attributions** — bold, italic, underline, strikethrough, inline
  code, and hyperlinks via `AttributedText`.
- **Event-sourced command pipeline** — all mutations flow through
  `EditRequest` / `EditCommand` with reaction and listener support.
- **Snapshot-based undo/redo** — `UndoableEditor` with configurable stack depth.
- **IME bridge** — `DocumentImeSerializer` virtualizes the block document as a
  flat `TextEditingValue` for platform IMEs. Delta model enabled by default.
- **Per-block rendering** — `ComponentBuilder` pattern for extensible,
  type-safe block rendering via `RenderDocumentBlock` subclasses.
- **Cross-block selection** — `DocumentSelection` spans heterogeneous node
  types with platform-adaptive handles and magnifiers.
- **Document-aware scrolling** — `DocumentScrollable` with auto-scroll to caret
  and `SliverEditableDocument` for `CustomScrollView` integration.
- **Full accessibility** — semantics tree with heading levels, image alt text,
  live regions, and screen reader navigation.
- **Zero external dependencies** — Flutter SDK only (framework merge
  prerequisite).
- **All six platforms** — iOS, Android, Web, macOS, Windows, Linux.

## Installation

```yaml
dependencies:
  editable_document: ^0.8.0-dev
```

## Quick start

```dart
import 'package:editable_document/editable_document.dart';
import 'package:flutter/material.dart';

// 1. Create a document with some content.
final document = MutableDocument([
  ParagraphNode(
    id: 'p1',
    text: AttributedText('Hello, editable_document!'),
    blockType: ParagraphBlockType.header1,
  ),
  ParagraphNode(
    id: 'p2',
    text: AttributedText('Start typing below...'),
  ),
]);

// 2. Create a controller (like TextEditingController).
final controller = DocumentEditingController(document: document);

// 3. Optionally create an editor for undo/redo and reactions.
final editor = UndoableEditor(
  editContext: EditContext(document: document, controller: controller),
);

// 4. Use DocumentField (like TextField) for a decorated input.
DocumentField(
  controller: controller,
  editor: editor,
  decoration: const InputDecoration(
    labelText: 'Notes',
    border: OutlineInputBorder(),
  ),
)
```

For a full-featured editor with toolbar, scrolling, caret overlay, and selection
handles, see the [example app](example/main.dart).

## Architecture

The package is organized into four layers with downward-only dependencies:

```
model  <--  rendering  <--  services  <--  widgets
```

- **model** — `Document`, `DocumentNode`, `DocumentSelection`,
  `DocumentEditingController`, command pipeline, undo/redo.
- **rendering** — `RenderDocumentLayout`, `RenderDocumentBlock` subclasses,
  caret and selection painters.
- **services** — `DocumentImeInputClient`, `DocumentImeSerializer`,
  `DocumentKeyboardHandler`, `DocumentAutofillClient`.
- **widgets** — `EditableDocument`, `DocumentField`, `DocumentLayout`,
  `ComponentBuilder`, selection overlays, gesture controllers, scrolling.

See [doc/architecture.md](doc/architecture.md) for detailed diagrams and data
flow descriptions.

## Migrating from EditableText

See [doc/migration_from_editable_text.md](doc/migration_from_editable_text.md)
for a side-by-side API comparison and step-by-step migration examples.

## Status

This package is under active development. See the
[ROADMAP](https://github.com/sjhorn/editable_document/blob/main/ROADMAP.md)
for the current progress. Phases 1-10 are complete.

## License

BSD-3-Clause. See
[LICENSE](https://github.com/sjhorn/editable_document/blob/main/LICENSE).
