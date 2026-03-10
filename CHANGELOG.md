## [Unreleased]

### Added
- Dual concurrent float support in `RenderDocumentLayout`: independent start-edge
  and end-edge exclusion zones are tracked simultaneously so that a start-aligned
  float and an end-aligned float can coexist, with wrapping blocks receiving a
  width reduced by both exclusion zones at once.
- `TableNode` — block-level 2D grid of `AttributedText` cells. Constructor
  parameters: `rowCount`, `columnCount`, `cells`, `columnWidths` (optional
  per-column widths; `null` entries auto-size), `alignment`, `textWrap`,
  `width`, `height`. Implements `HasBlockLayout` for the full layout property
  surface.
- `TableCellPosition` — `NodePosition` subtype for cursor placement within a
  table cell, carrying `row`, `column`, and a nested `TextNodePosition`.
- `RenderTableBlock` — `RenderDocumentBlock` subclass that lays out and paints
  a `TableNode` with per-cell borders, column width constraints, and
  selection/caret geometry.
- `TableComponentBuilder` — registered in `defaultComponentBuilders` so tables
  are rendered automatically without any additional wiring.
- Table IME support in `DocumentImeSerializer`: `TableNode` cells are
  serialised into the flat `TextEditingValue` string and deltas are
  correctly mapped back to `TableCellPosition` offsets.
- Edit requests for table mutation:
  - `InsertTableRequest` — inserts a new `TableNode` at a given document index.
  - `UpdateTableCellRequest` — replaces the `AttributedText` of a single cell,
    identified by node ID, row, and column.
  - `DeleteTableRequest` — removes a `TableNode` from the document.
- Example app: *Dual Concurrent Floats* section demonstrating a
  start-aligned and end-aligned image with wrapping text flowing between them.
- Example app: *Table Support* section demonstrating a 3×3 `TableNode` with
  a bold header row, mixed column widths, and contextual explanatory text.

## 0.8.0-dev (Phases 9-10)

### Block layout property deduplication
- `HasBlockLayout` interface (model) for polymorphic access to container block
  layout properties (alignment, textWrap, width, height).
- `BlockLayoutMixin` (rendering) eliminates duplicated field/setter boilerplate
  across 4 container render objects.
- `HasLayoutFields` interface (widgets) with shared `_updateBlockLayout` helper
  for view model → render object property wiring.

### Performance benchmarks (Phase 9)
- Micro-benchmarks for document model operations (`insertNode`, `deleteNode`,
  `AttributedText.applyAttribution`) at various document sizes.
- IME serialization round-trip benchmarks for 100/1,000/10,000 node documents.
- Selection query benchmarks for large documents.
- `scripts/ci/benchmark.sh` runner with results written to `benchmark/results/`.
- Baseline comparison: `EditableDocument` vs `EditableText` for single-paragraph case.

### Documentation & example app (Phase 10)
- Zero `dart doc` warnings across all public symbols.
- `doc/architecture.md` — layer diagram, IME data flow, command pipeline,
  widget tree diagram.
- `doc/migration_from_editable_text.md` — side-by-side API comparison and
  migration examples.
- Example app: formatting toolbar (bold, italic, underline, strikethrough,
  inline code), JSON save/load, word and character count display.
- Expanded README with features list, installation, and quick example.

## 0.7.0-dev (Phase 8)

### Accessibility & semantics
- `DocumentSemanticsBuilder` generates a `SemanticsNode` tree from the document.
- Per-block semantics: heading levels (H1-H6), image alt text, horizontal rule
  labels, `isTextField`/`isMultiline`/`isReadOnly` flags.
- Live-region announcements for document mutations.
- Screen reader focus order follows document order.

## 0.6.0-dev (Phases 6-7)

### Selection overlay & platform handles (Phase 6)
- `DocumentSelectionOverlay` — manages caret, selection highlights, and handle
  overlay entries.
- `CaretDocumentOverlay` — blinking caret with 500ms interval.
- `DocumentMouseInteractor` — desktop click/drag/double-click/triple-click
  selection.
- `IosDocumentGestureController` — iOS tap, long-press, handle drag, magnifier.
- `AndroidDocumentGestureController` — Android gesture set with velocity-based
  drag.
- `IOSCollapsedHandle`, `IOSSelectionHandle`, `AndroidSelectionHandle` —
  platform-specific handle widgets.
- `IOSDocumentMagnifier`, `AndroidDocumentMagnifier` — magnifier overlays.
- `RenderDocumentCaret`, `RenderDocumentSelectionHighlight` — paint-time
  geometry (eliminates post-frame-callback delay).
- `DocumentTextSelectionControls` — floating toolbar with Cut, Copy, Paste,
  Select All, Bold, Italic actions.

### Scrolling (Phase 7)
- `DocumentScrollable` — wraps `SingleChildScrollView` with auto-scroll to
  caret on selection change.
- `DragHandleAutoScroller` — velocity-based auto-scroll when handles approach
  viewport edges.
- `SliverEditableDocument` — `CustomScrollView` integration.

## 0.5.0-dev (Phase 5)

### Widget layer
- `ComponentBuilder` system with default builders for paragraph, list item,
  image, code block, and horizontal rule nodes.
- `DocumentLayout` — renders `RenderDocumentLayout` and responds to document
  changes.
- `EditableDocument` — the main widget, mirrors `EditableText` parameter
  surface with IME, keyboard, and focus management.
- `DocumentField` — wraps `EditableDocument` with `InputDecoration`, label,
  hint, prefix/suffix, error text, and character counter.

## 0.4.0-dev (Phase 4)

### IME bridge
- `DocumentImeSerializer` — bidirectional `Document` + `DocumentSelection` to
  `TextEditingValue` serialization.
- `DocumentImeInputClient implements DeltaTextInputClient` — connection
  lifecycle, delta processing, floating cursor, keyboard content insertion.
- `DocumentKeyboardHandler` — arrow navigation, Home/End, Shift+arrow
  selection, Ctrl/Cmd+arrow word navigation, platform-specific mappings.
- `DefaultDocumentShortcuts` — document-specific intents (split block, merge
  block, indent/unindent list, toggle attribution).
- `DocumentAutofillClient implements AutofillClient` — autofill group
  participation for single-text-node documents.

## 0.3.0-dev (Phase 3)

### Rendering layer
- `RenderDocumentBlock` — abstract `RenderBox` base with position/selection
  geometry API.
- `RenderTextBlock`, `RenderParagraphBlock`, `RenderListItemBlock`,
  `RenderCodeBlock` — text-based block renderers.
- `RenderImageBlock`, `RenderHorizontalRuleBlock` — non-text block renderers.
- `RenderDocumentLayout` — vertical stack with `ContainerRenderObjectMixin`
  and scrollable viewport integration.
- `DocumentCaretPainter`, `DocumentSelectionPainter` — cursor and selection
  highlight painting.

## 0.2.0-dev (Phases 1-2)

### Document model (Phase 1)
- `DocumentNode` hierarchy: `TextNode`, `ParagraphNode`, `ListItemNode`,
  `CodeBlockNode`, `ImageNode`, `HorizontalRuleNode`.
- `AttributedText` — rich text with O(log n) attribution queries.
- `Document` / `MutableDocument` — immutable view and mutable container.
- `DocumentPosition`, `DocumentSelection` — cross-block position and selection.
- `DocumentEditingController` — analogous to `TextEditingController`.

### Command pipeline & undo/redo (Phase 2)
- `EditRequest` / `EditCommand` / `EditContext` — event-sourced mutation
  pipeline.
- `Editor` — request dispatch with reaction and listener support.
- `UndoableEditor` — snapshot-based undo/redo with configurable stack depth.

## 0.1.0-dev.1

- Initial package skeleton and tooling bootstrap.
