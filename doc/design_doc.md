# EditableDocument — Block-Structured Document Editing for Flutter

**Author:** Scott Horn (sjhorn)
**Go Link:** flutter.dev/go/editable-document
**Created:** March/2026   /   **Last updated:** March/2026

---

## SUMMARY

EditableDocument is a block-structured document editing widget for Flutter,
designed as a drop-in companion to `EditableText`. Where `EditableText` handles
single-field text via a flat `TextEditingValue`, `EditableDocument` handles
multi-block, rich-text documents via a structured document model. The package
uses zero external dependencies and mirrors Flutter's own layering
(model → rendering → services → widgets) for eventual framework merge.

---

## WHAT PROBLEM IS THIS SOLVING?

Flutter application developers building rich text editors — notes apps, CMS
editors, documentation tools, and email composers — cannot use `EditableText`
because it only supports a single flat string. They must turn to third-party
packages like `super_editor` or build complex custom solutions from scratch. This
gap forces teams to choose between Flutter's well-integrated but limited text
editing infrastructure, or external packages that duplicate large portions of the
framework and introduce external dependency constraints.

**Intended users:** Flutter application developers who need multi-paragraph,
mixed-content editing. Specifically:

- Developers building notes or journaling apps that need headings, lists, and
  inline formatting.
- Teams building CMS editors or documentation tools that need structural block
  types (code blocks, images, horizontal rules).
- Email composer authors who need mixed rich text with inline attributions.
- Developers evaluating `super_editor` alternatives that remain within the
  Flutter SDK's own idioms and integration points.

**Reference Flutter issues and PRs:**

- [#92173](https://github.com/flutter/flutter/issues/92173) — `TextPainter`
  performance
- [#97433](https://github.com/flutter/flutter/issues/97433) — `GestureRecognizer`
  assertion
- [#131510](https://github.com/flutter/flutter/issues/131510) — IME testing gap
- [PR #90205](https://github.com/flutter/flutter/pull/90205) —
  `DeltaTextInputClient` (the delta model this package depends on)
- [PR #90684](https://github.com/flutter/flutter/pull/90684) — Actions moved to
  `EditableTextState`

---

## BACKGROUND

**Audience:** Flutter framework contributors familiar with `EditableText`,
`RenderEditable`, and the `TextInputClient` / `DeltaTextInputClient` contract.

### EditableText's architecture

`EditableText` is built around a single `TextEditingValue` — an immutable
snapshot of `(text: String, selection: TextSelection, composing: TextRange)`.
Every keystroke replaces the entire value. This maps cleanly to a single
`RenderEditable`, which lays out one `TextPainter` with a `TextSelection` and a
cursor at a character offset.

The IME bridge is `TextInputClient` / `DeltaTextInputClient`. The delta variant
(`DeltaTextInputClient`) delivers `TextEditingDelta` objects — each carrying
a specific insertion, deletion, replacement, or non-text-update — rather than
requiring the client to diff successive full-replacement values.

### The TextInputClient / DeltaTextInputClient contract

When `TextInput.attach` is called, Flutter hands the platform IME an opaque
connection. Keyboard input arrives as a sequence of `TextEditingDelta` objects
via `DeltaTextInputClient.updateEditingValueWithDeltas`. Each delta includes:
`oldText`, `newText`, the changed `TextRange`, and a `composingRegion`.

After applying a delta, the client pushes the new canonical `TextEditingValue`
back to the platform via `TextInputConnection.setEditingState`. This round-trip
keeps the platform IME's internal model synchronized with Flutter's model.

For block documents, a direct mapping of the full document text into a single
`TextEditingValue` is impractical — it breaks autocorrect, composition
underlines, and word-boundary detection at block boundaries. `EditableDocument`
solves this by virtualizing: it serializes only the focused block's text (or a
synthetic placeholder for cross-block selections) into the `TextEditingValue`
seen by the platform IME.

### super_editor's lessons

`super_editor` (by the `superlist` team) demonstrated that block document
editing is tractable in Flutter. Three architectural lessons informed
`editable_document`:

1. **ComponentBuilder pattern.** Each block type is rendered by a separate
   `ComponentBuilder` that maps a `DocumentNode` to a widget. This avoids a
   monolithic render object and keeps block rendering extensible.
2. **IME virtualization.** Rather than exposing the full document text to the
   platform IME, only the focused node's text is serialized. Cross-block
   selections use a synthetic zero-width space placeholder.
3. **Event-sourced command pipeline.** All document mutations flow through
   typed `EditRequest` / `EditCommand` pairs. Reactions and listeners can observe
   or augment edits without coupling to the editing widget.

### Glossary

| Term | Definition |
|------|------------|
| `DocumentNode` | Abstract base for a single block in a document. Identified by a stable string `id`. |
| `AttributedText` | An immutable rich-text value: a `String` plus a list of `SpanMarker`s that mark attribution start/end offsets. |
| `Attribution` | An abstract marker applied to a span of `AttributedText`. Concrete subclasses: `NamedAttribution` (bold, italics, etc.) and `LinkAttribution`. |
| `DocumentPosition` | A logical cursor position: `{nodeId: String, nodePosition: NodePosition}`. |
| `DocumentSelection` | A range in the document: `{base: DocumentPosition, extent: DocumentPosition}`. May be collapsed (caret) or span multiple nodes. |
| `EditRequest` | An abstract marker interface identifying a mutation intent (e.g. `InsertTextRequest`, `SplitParagraphRequest`). |
| `EditCommand` | Executes an `EditRequest` against an `EditContext`, mutates the `MutableDocument`, and returns `List<DocumentChangeEvent>`. |
| `EditReaction` | An observer that runs after each `EditCommand`. May return follow-up `EditRequest`s (cascading, depth-capped at 10). |
| `EditListener` | A passive observer notified once per `Editor.submit` call with all accumulated `DocumentChangeEvent`s. |
| `ComponentBuilder` | A factory that maps a `DocumentNode` to a `ComponentViewModel` and then to a `Widget`. |

---

## OVERVIEW

`editable_document` is organized into four layers. Dependencies flow downward
only — no layer imports from a layer above it.

```
+-------------------------------------------------------------------+
|                         widgets layer                             |
|  EditableDocument, DocumentField, DocumentLayout, ComponentBuilder|
|  DocumentSelectionOverlay, CaretDocumentOverlay                   |
|  DocumentScrollable, SliverEditableDocument                       |
|  DocumentMouseInteractor, IosDocumentGestureController            |
|  AndroidDocumentGestureController, DocumentTextSelectionControls  |
+----------------------------+--------------------------------------+
                             |
              imports rendering + services + model
                             |
           +-----------------+------------------+
           |                                    |
+----------+----------+         +--------------+----------+
|   rendering layer   |         |    services layer       |
|  RenderDocumentBlock|         | DocumentImeSerializer   |
|  RenderDocumentLayout         | DocumentImeInputClient  |
|  RenderParagraphBlock         | DocumentKeyboardHandler |
|  RenderListItemBlock          | DocumentAutofillClient  |
|  RenderCodeBlock    |         +--------------+----------+
|  RenderImageBlock   |                        |
|  RenderHRuleBlock   |         imports model only
+----------+----------+                        |
           |                                   |
           +-------------------+---------------+
                               |
                     +---------+---------+
                     |    model layer    |
                     |  DocumentNode     |
                     |  AttributedText   |
                     |  Document /       |
                     |  MutableDocument  |
                     |  DocumentPosition |
                     |  DocumentSelection|
                     |  DocumentEditing- |
                     |    Controller     |
                     |  Editor /         |
                     |  UndoableEditor   |
                     |  EditRequest      |
                     |  EditCommand      |
                     |  EditContext      |
                     |  EditReaction     |
                     |  EditListener     |
                     +-------------------+
```

**Layer responsibilities:**

- **model** (`lib/src/model/`) — `DocumentNode` hierarchy, `Document` /
  `MutableDocument`, `DocumentPosition` / `DocumentSelection`,
  `DocumentEditingController`, `Editor` / `UndoableEditor` with event-sourced
  command pipeline.
- **rendering** (`lib/src/rendering/`) — `RenderDocumentLayout`, per-block
  `RenderDocumentBlock` subclasses (paragraph, list item, code, image, horizontal
  rule), `DocumentCaretPainter`, `DocumentSelectionPainter`.
- **services** (`lib/src/services/`) — `DocumentImeSerializer` (bidirectional
  IME bridge), `DocumentImeInputClient` (`DeltaTextInputClient` implementation),
  `DocumentKeyboardHandler`, `DocumentAutofillClient`.
- **widgets** (`lib/src/widgets/`) — `EditableDocument` (primary widget),
  `DocumentField` (`TextField` equivalent), `DocumentLayout`,
  `ComponentBuilder` system, selection overlays, platform handles (iOS / Android
  / desktop), scrolling.

**Allowed Flutter imports per layer:**

| Layer | Permitted Flutter packages |
|-------|---------------------------|
| `model` | `flutter/foundation`, `flutter/painting` (`TextAffinity` only) |
| `rendering` | `flutter/foundation`, `flutter/painting`, `flutter/rendering`, `flutter/scheduler` |
| `services` | `flutter/foundation`, `flutter/painting`, `flutter/services` |
| `widgets` | All Flutter layers (`flutter/material`, `flutter/cupertino`, etc.) |

### Non-goals

- Replacing `EditableText` for single-field text input — `EditableText` /
  `TextField` remain the right choice for single-line or simple multi-line inputs.
- Markdown / HTML parsing or export — the model is intentionally agnostic about
  serialization format.
- Collaborative / real-time editing (CRDT / OT) — the current architecture
  assumes a single editor at a time.
- Rich media embedding beyond images — video, audio, and other embed types are
  deferred.
- Material / Cupertino wrapper widgets (e.g. `DocumentTextField` with Material
  theming) — deferred to the framework team if the package is merged.

---

## USAGE EXAMPLES

### Example 1 — Simple DocumentField (TextField equivalent)

The simplest migration from `TextField`. `DocumentField` wraps `EditableDocument`
and accepts the same `InputDecoration` parameter.

```dart
final controller = DocumentEditingController(
  document: MutableDocument([
    ParagraphNode(id: 'p1', text: AttributedText('Hello world')),
  ]),
);

DocumentField(
  controller: controller,
  decoration: const InputDecoration(labelText: 'Notes'),
)
```

### Example 2 — EditableDocument with editor and undo

For cases where you need programmatic edits, undo/redo, or reactions, create an
`UndoableEditor` and pass it to `EditableDocument`.

```dart
final controller = DocumentEditingController(
  document: MutableDocument([
    ParagraphNode(id: 'p1', text: AttributedText('First paragraph')),
    ParagraphNode(
      id: 'p2',
      text: AttributedText('Second paragraph'),
      blockType: ParagraphBlockType.header1,
    ),
    ListItemNode(
      id: 'li1',
      text: AttributedText('Item one'),
      type: ListItemType.unordered,
    ),
  ]),
);
final editor = UndoableEditor(
  editContext: EditContext(document: controller.document, controller: controller),
);

EditableDocument(
  controller: controller,
  focusNode: FocusNode(),
  editor: editor,
  autofocus: true,
)
```

### Example 3 — Custom ComponentBuilder

`ComponentBuilder` is the `EditableDocument` equivalent of
`TextEditingController.buildTextSpan()`. It maps a `DocumentNode` to a widget,
allowing completely custom rendering per block type.

```dart
class CustomParagraphBuilder extends ComponentBuilder {
  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode) return null;
    return ParagraphComponentViewModel(
      nodeId: node.id,
      text: node.text,
      blockType: node.blockType,
      textStyle: const TextStyle(fontFamily: 'Georgia', height: 1.6),
    );
  }

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is! ParagraphComponentViewModel) return null;
    return ParagraphComponent(viewModel: viewModel);
  }
}

// Prepend custom builders to override specific node types while keeping
// the defaults for all other node types.
EditableDocument(
  controller: controller,
  focusNode: focusNode,
  componentBuilders: [CustomParagraphBuilder(), ...defaultComponentBuilders],
)
```

### Example 4 — Programmatic editing via Editor

All document mutations flow through typed `EditRequest`s submitted to the
`Editor`. This keeps undo, reactions, and listeners in sync automatically.

```dart
// Bold the current selection.
editor.submit(ApplyAttributionRequest(
  selection: controller.selection!,
  attribution: NamedAttribution.bold,
));

// Change a block's type to a level-1 heading.
editor.submit(ChangeBlockTypeRequest(
  nodeId: 'p1',
  newBlockType: ParagraphBlockType.header1,
));

// Undo and redo (UndoableEditor only).
if (editor.canUndo) editor.undo();
if (editor.canRedo) editor.redo();
```

---

## DETAILED DESIGN/DISCUSSION

### Layer 1 — Document Model (`lib/src/model/`)

#### DocumentNode hierarchy

`DocumentNode` is an abstract, `Diagnosticable` base class identified by a
stable UUID string `id`. Every block in a document is a `DocumentNode`
subclass:

```
DocumentNode (abstract)
  +-- TextNode (abstract)        # adds AttributedText text field
  |     +-- ParagraphNode        # blockType: body / h1–h3 / blockquote
  |     +-- ListItemNode         # type: ordered | unordered; indent; ordinalIndex
  |     +-- CodeBlockNode        # language (optional)
  +-- ImageNode                  # imageUrl, altText, width, height
  +-- HorizontalRuleNode         # no additional fields
```

All `DocumentNode` subclasses are immutable. Mutations produce new instances
via `copyWith`, enabling snapshot-based undo and equality-based diffing.

#### AttributedText

`AttributedText` is an immutable rich-text value: a plain `String` plus an
ordered list of `SpanMarker`s. Each `SpanMarker` records an `Attribution`, an
`offset`, and a `markerType` (`start` or `end`). Attribution queries are
O(log n) via binary search on the sorted marker list.

Built-in `NamedAttribution` constants: `bold`, `italics`, `underline`,
`strikethrough`, `code`. `LinkAttribution` carries a `url` string.

#### Document and MutableDocument

`Document` is a read-only interface: `nodes` list, `nodeById(id)`,
`nodeAt(index)`. `MutableDocument` adds mutation methods (`addNode`,
`insertNodeAfter`, `moveNode`, `deleteNode`, `reset`) and exposes a
`ValueNotifier<List<DocumentChangeEvent>> changes` for reactive observation.

#### DocumentPosition and DocumentSelection

`DocumentPosition` is a `{nodeId: String, nodePosition: NodePosition}` pair.
`NodePosition` is abstract; `TextNodePosition` adds `offset` and `affinity`;
`BinaryNodePosition` is used for atomic non-text nodes (images, horizontal
rules).

`DocumentSelection` holds `base` and `extent` `DocumentPosition`s. A collapsed
selection (caret) has equal `base` and `extent`. `DocumentSelection.normalize`
returns a copy with `base` guaranteed to precede `extent` in document order.

#### DocumentEditingController

`DocumentEditingController` extends `ChangeNotifier` and holds three related
state objects:

| Field | Type | Purpose |
|-------|------|---------|
| `document` | `MutableDocument` | The document content |
| `selection` | `DocumentSelection?` | Current cursor or selection |
| `preferences` | `ComposerPreferences` | Active attributions for next typed characters |

Listeners are notified whenever any of the three change. `preferences` is
mutable in-place; callers must invoke `notifyListeners()` manually after
toggling `ComposerPreferences`.

#### Event-sourced command pipeline

All document mutations follow a typed request-command-event pattern:

```
EditRequest (intent, immutable value object)
    |
    v
EditCommand.execute(EditContext)
    |   mutates MutableDocument
    |   returns List<DocumentChangeEvent>
    v
EditReaction.react(context, requests, events)
    |   optional; returns follow-up EditRequest list
    |   depth-capped at 10 to prevent infinite loops
    v
EditListener.onEdit(events)
    passive observer; no follow-ups
```

Concrete `EditRequest` / `EditCommand` pairs:

| Request | Command |
|---------|---------|
| `InsertTextRequest` | `InsertTextCommand` |
| `DeleteContentRequest` | `DeleteContentCommand` |
| `ReplaceNodeRequest` | `ReplaceNodeCommand` |
| `SplitParagraphRequest` | `SplitParagraphCommand` |
| `MergeNodeRequest` | `MergeNodeCommand` |
| `MoveNodeRequest` | `MoveNodeCommand` |
| `ChangeBlockTypeRequest` | `ChangeBlockTypeCommand` |
| `ApplyAttributionRequest` | `ApplyAttributionCommand` |
| `RemoveAttributionRequest` | `RemoveAttributionCommand` |

#### UndoableEditor and snapshot-based undo

`UndoableEditor` extends `Editor`. Before each `submit`, it pushes a full deep
copy of every `DocumentNode` (via `DocumentNode.copyWith`) and the current
`DocumentSelection` onto a bounded undo stack. On `undo`,
`MutableDocument.reset(snapshot)` atomically replaces all nodes and the
selection is restored. On `redo`, the original `EditRequest` is re-submitted
through `super.submit`, generating a fresh undo entry automatically.

The undo stack is bounded by `maxUndoLevels` (default 100). Oldest entries are
evicted once the cap is exceeded.

---

### Layer 2 — Rendering (`lib/src/rendering/`)

#### RenderDocumentBlock hierarchy

`RenderDocumentBlock` is an abstract `RenderBox` that all block render objects
extend. It exposes the geometry API the widget layer uses for keyboard navigation
and hit testing:

- `getPositionAtOffset(Offset) -> NodePosition?`
- `getRectForPosition(NodePosition) -> Rect?`
- `getLineBoundary(TextNodePosition) -> TextRange`

Text blocks extend `RenderTextBlock`, which wraps a `TextPainter` and handles
text layout. Specialized subclasses:

| Class | Block type | Notable behavior |
|-------|-----------|-----------------|
| `RenderParagraphBlock` | `ParagraphNode` | Scales font for h1/h2/h3 |
| `RenderListItemBlock` | `ListItemNode` | Bullet/number gutter + indentation |
| `RenderCodeBlock` | `CodeBlockNode` | Monospace font, background fill |
| `RenderImageBlock` | `ImageNode` | Placeholder with aspect ratio |
| `RenderHorizontalRuleBlock` | `HorizontalRuleNode` | Fixed-height hairline |

#### RenderDocumentLayout

`RenderDocumentLayout` extends `RenderBox` with
`ContainerRenderObjectMixin<RenderDocumentBlock, DocumentBlockParentData>`. It
lays out blocks in a vertical stack with configurable `blockSpacing` and
exposes the coordinate-based query API used by the widget layer:

- `getComponentByNodeId(String) -> RenderDocumentBlock?`
- `getDocumentPositionAtOffset(Offset) -> DocumentPosition?`
- `getDocumentPositionNearestToOffset(Offset) -> DocumentPosition`
- `getRectForDocumentPosition(DocumentPosition) -> Rect?`
- `computeMaxScrollExtent(double viewportHeight) -> double`

#### Caret and selection painters

`DocumentCaretPainter` and `DocumentSelectionPainter` are `CustomPainter`
implementations. They are hosted by `RenderDocumentCaret` and
`RenderDocumentSelectionHighlight` respectively, which sit in the same layer
stack as `RenderDocumentLayout` rather than inside individual blocks. This
means selection highlights and the caret are painted in a single pass,
avoiding per-block repaint triggers for selection-change events.

---

### Layer 3 — Services / IME Bridge (`lib/src/services/`)

#### DocumentImeSerializer

`DocumentImeSerializer` is a stateless, `const` utility that handles the
bidirectional translation between the block document model and the flat
`TextEditingValue` the platform IME expects.

**Serialization (document → IME):**

| Condition | Mode | `TextEditingValue.text` |
|-----------|------|------------------------|
| Selection within a single `TextNode` | Mode 1 | Full node plain text |
| Cross-block or non-text-node selection | Mode 2 | `'\u200B'` (zero-width space) |
| No selection (`null`) | Mode 2 | `''` (empty string) |

Mode 1 preserves autocorrect, voice dictation, and IME composition underlines.
Mode 2 prevents the platform IME from sending confusing empty-string deltas
when the selection spans block boundaries.

**Deserialization (IME → document):**

`deltaToRequests` maps each incoming `TextEditingDelta` to one or more
`EditRequest`s:

| Delta type | EditRequest(s) produced |
|-----------|------------------------|
| `TextEditingDeltaInsertion('\n')` | `SplitParagraphRequest` |
| `TextEditingDeltaInsertion(text)` | `InsertTextRequest` |
| `TextEditingDeltaDeletion` | `DeleteContentRequest` |
| `TextEditingDeltaReplacement` | `DeleteContentRequest` + `InsertTextRequest` |
| `TextEditingDeltaNonTextUpdate` | _(empty — selection update only)_ |

#### DocumentImeInputClient

`DocumentImeInputClient` implements `DeltaTextInputClient` (not the older
`TextInputClient`). It holds a `DocumentImeSerializer`, a
`DocumentEditingController`, and a `requestHandler` callback (typically
`Editor.submit`).

Key methods:
- `openConnection(TextInputConfiguration)` — attaches to the platform IME; the
  configuration always has `enableDeltaModel: true`.
- `syncToIme()` — serializes the current document + selection and calls
  `TextInputConnection.setEditingState`. Called by `EditableDocumentState`
  after every `DocumentEditingController` change notification.
- `updateEditingValueWithDeltas(List<TextEditingDelta>)` — the hot path; calls
  `serializer.deltaToRequests` and then `requestHandler` for each result.
- `updateEditingValue(TextEditingValue)` — fallback for platforms that do not
  send deltas; synthesizes a delta and delegates to
  `updateEditingValueWithDeltas`.

**Full IME round-trip:**

```
Platform IME
  | (TextInputChannel)
  v
DocumentImeInputClient.updateEditingValueWithDeltas(deltas)
  |
  v
DocumentImeSerializer.deltaToRequests(deltas, document, selection)
  |  -> List<EditRequest>
  v
Editor.submit(EditRequest)
  |
  +-> EditCommand.execute(EditContext)
  |     mutates MutableDocument
  |     returns List<DocumentChangeEvent>
  |
  +-> EditReaction.react(...)
  |     optional follow-up requests
  |
  +-> EditListener.onEdit(events)
  |
  v
DocumentEditingController.notifyListeners()
  |
  v
EditableDocumentState._onControllerChanged()
  |
  v
DocumentImeInputClient.syncToIme()
  |
  v
TextInputConnection.setEditingState(TextEditingValue)
  |
  v
Platform IME (internal model updated)
```

#### DocumentKeyboardHandler

Handles non-IME key events: arrow keys, Home/End, Page Up/Down, and keyboard
shortcuts (Ctrl/Cmd+B for bold, etc.). Returns `true` to consume the event or
`false` to let it bubble. Depends only on `Document`, `DocumentEditingController`,
and `requestHandler` — no widget imports.

#### DocumentAutofillClient

Implements `AutofillClient`. When an `AutofillGroup` ancestor is present,
`DocumentImeInputClient.openConnection` delegates to `AutofillScope.attach`
instead of `TextInput.attach`, routing the connection through
`DocumentAutofillClient` so the editor participates in the platform's autofill
group.

---

### Layer 4 — Widgets (`lib/src/widgets/`)

#### ComponentBuilder pattern

The `ComponentBuilder` abstraction is the most important extensibility point in
the widget layer. It mirrors Flutter's `RenderObjectWidget` split:

1. `createViewModel(Document, DocumentNode) -> ComponentViewModel?` — produces
   an immutable view-model value object from the document node.
2. `createComponent(ComponentViewModel, ComponentContext) -> Widget?` — produces
   a widget from the view-model.

`DocumentLayout` iterates the builder list for each `DocumentNode`. The first
builder whose `createViewModel` returns non-null wins. View-model equality
(via `==`) is checked against the previous build; if unchanged, `createComponent`
is skipped and the previous widget subtree is reused. This keeps layout stable
during selection-only changes.

Default builder list:

```
defaultComponentBuilders = [
  ParagraphComponentBuilder,     // ParagraphNode
  ListItemComponentBuilder,      // ListItemNode
  ImageComponentBuilder,         // ImageNode
  CodeBlockComponentBuilder,     // CodeBlockNode
  HorizontalRuleComponentBuilder,// HorizontalRuleNode
]
```

Prepend custom builders to override specific node types:

```dart
final builders = [MyCustomParagraphBuilder(), ...defaultComponentBuilders];
```

#### EditableDocument

`EditableDocument` is the primary public widget. Its constructor surface mirrors
`EditableText`:

| Parameter | Type | Purpose |
|-----------|------|---------|
| `controller` | `DocumentEditingController` | Content + selection state |
| `focusNode` | `FocusNode` | Focus management |
| `editor` | `Editor?` | Routes `EditRequest`s; optional (read-only use) |
| `readOnly` | `bool` | Disables editing |
| `autofocus` | `bool` | Focuses on first build |
| `textInputAction` | `TextInputAction` | IME action button label |
| `keyboardType` | `TextInputType` | Keyboard variant |
| `componentBuilders` | `List<ComponentBuilder>` | Custom block rendering |
| `blockSpacing` | `double` | Vertical gap between blocks |
| `stylesheet` | `DocumentStylesheet?` | Typography and spacing |
| `layoutKey` | `GlobalKey<DocumentLayoutState>?` | Access to geometry queries |
| `scrollPadding` | `EdgeInsets` | Padding around caret during auto-scroll |

`EditableDocument.build()` produces:

```
Focus (focusNode, onKeyEvent -> DocumentKeyboardHandler)
  +-- DocumentSemanticsScope
        +-- DocumentLayout
              +-- ParagraphComponent       (RenderParagraphBlock)
              +-- ListItemComponent        (RenderListItemBlock)
              +-- ImageComponent           (RenderImageBlock)
              +-- CodeBlockComponent       (RenderCodeBlock)
              +-- HorizontalRuleComponent  (RenderHorizontalRuleBlock)
```

#### Typical app-level composition

```
DocumentScrollable
  +-- DocumentMouseInteractor (desktop) /
  |   IosDocumentGestureController (iOS) /
  |   AndroidDocumentGestureController (Android)
        +-- DocumentSelectionOverlay
              +-- EditableDocument
```

#### DocumentField

`DocumentField` is the `TextField` equivalent. It wraps `EditableDocument` and
`InputDecoration`, and automatically creates an `UndoableEditor` if none is
provided. It matches `TextField`'s constructor surface: `decoration`, `focusNode`,
`readOnly`, `autofocus`, `textInputAction`, `keyboardType`, `autofillHints`, and
`maxLength` (counter display only; does not enforce a hard cap).

#### Selection overlays and gesture controllers

- `DocumentSelectionOverlay` — floating selection handles and context menu,
  rendered in the `Overlay`.
- `CaretDocumentOverlay` — blinking caret, rendered in the same `Overlay`.
- `DocumentMouseInteractor` — desktop: click to place caret, drag to select,
  triple-click to select block.
- `IosDocumentGestureController` — iOS: tap, long-press, magnifier, drag handles.
- `AndroidDocumentGestureController` — Android: tap, long-press, magnifier.
- `DocumentTextSelectionControls` — delegates to
  `materialTextSelectionControls` / `cupertinoTextSelectionControls` based on
  platform, matching the behavior of `TextField`.

#### Scrolling

`DocumentScrollable` wraps a `ScrollController` and subscribes to
`DocumentEditingController` to auto-scroll the caret into view after every edit.
`SliverEditableDocument` is a sliver variant for use inside a
`CustomScrollView`; it wraps `EditableDocument` in a `SliverToBoxAdapter` and
manages the sliver scroll offset.

#### Key design decisions

**DeltaTextInputClient (not TextInputClient).** `DocumentImeInputClient`
implements `DeltaTextInputClient`. Deltas carry offset and text directly; a
full-replacement approach would require reconstructing which node was edited on
every keystroke. Using deltas avoids that reconstruction entirely.

**Immutable model values.** `DocumentNode`, `AttributedText`, and `SpanMarker`
are immutable. All mutations produce new instances via `copyWith`. This makes
snapshot-based undo (`UndoableEditor`) straightforward and enables
equality-based diffing in `ComponentViewModel` to skip unnecessary widget
rebuilds.

**ComponentBuilder / ComponentViewModel indirection.** The two-step
view-model-then-widget pattern mirrors Flutter's `RenderObjectWidget` split. It
allows `DocumentLayout` to diff old and new view models (via `==`) and skip
calling `createComponent` when nothing changed, keeping layout stable during
selection-only changes.

**RenderDocumentLayout geometry queries.** The rendering layer exposes
pixel-coordinate queries (`getRectForDocumentPosition`,
`getDocumentPositionNearestToOffset`) that the widget layer uses to implement
keyboard navigation (Up/Down arrows, Page Up/Down, line-boundary moves) without
the widget tree needing to know anything about text layout internals.

---

## ACCESSIBILITY

`DocumentSemanticsScope` wraps the full `DocumentLayout` and contributes the
root semantics node (live region, `isMultiline: true`).

`DocumentSemanticsBuilder` generates one `SemanticsNode` per `DocumentNode`:

| Property | Value |
|----------|-------|
| `isTextField` | `true` for all text blocks |
| `isMultiline` | `true` |
| `isReadOnly` | reflects `EditableDocument.readOnly` |
| `header` | set on `ParagraphNode` with `h1` / `h2` / `h3` block type |
| `image` | set on `ImageNode`; `label` is `ImageNode.altText` |
| `onSetText` | routes through `Editor.submit(InsertTextRequest)` |
| `onSetSelection` | routes through `DocumentEditingController.setSelection` |
| `onMoveCursorForwardByCharacter` | routes through `DocumentKeyboardHandler` |
| `onMoveCursorBackwardByCharacter` | routes through `DocumentKeyboardHandler` |
| `onMoveCursorForwardByWord` | routes through `DocumentKeyboardHandler` |
| `onMoveCursorBackwardByWord` | routes through `DocumentKeyboardHandler` |

Screen reader focus order follows document order (top to bottom). The live
region on the document root ensures that screen readers announce content
changes caused by remote edits (e.g. auto-formatting reactions).

---

## INTERNATIONALIZATION

**Right-to-left.** `TextDirection` is accepted on `EditableDocument` and
propagated to each `RenderTextBlock`. Per-block `TextAlign` is respected.
`DocumentImeSerializer` maps cursor positions using character offsets, which
are direction-agnostic.

**CJK / composition input.** `DocumentImeInputClient` uses
`DeltaTextInputClient`, which preserves the `composingRegion` on each delta
unmodified. `DocumentImeSerializer` maps the composing region within the
serialized `TextNodePosition` in Mode 1 (single text node), so CJK composition
underlines are rendered correctly by the platform.

**No hardcoded strings.** All user-visible text (context menu labels, empty
state labels) comes from the caller's localizations or Flutter's own
`MaterialLocalizations` / `CupertinoLocalizations`. No strings are
hard-coded inside the package.

---

## INTEGRATION WITH EXISTING FEATURES

**Coexistence with EditableText / TextField.** `EditableDocument` introduces
no new symbols to the `flutter/widgets.dart` or `flutter/material.dart`
namespaces and makes no changes to existing classes. It can be used alongside
`TextField` / `EditableText` in the same application without conflict.

**InputDecoration.** `DocumentField` accepts the same `InputDecoration` as
`TextField`. The decoration is rendered by the same `InputDecorator` widget used
by `TextField`, so it responds identically to theming.

**TextMagnifierConfiguration.** `EditableDocument` forwards
`TextMagnifierConfiguration` to platform gesture controllers unchanged; the
magnifier widget is the same `TextMagnifier` used by `EditableText`.

**AutofillGroup.** `DocumentAutofillClient` implements `AutofillClient`.
`DocumentImeInputClient` detects an enclosing `AutofillGroup` and delegates to
`AutofillScope.attach`, so `EditableDocument` participates in platform autofill
in the same way `TextField` does.

**Actions and Shortcuts.** `DefaultDocumentShortcuts` extends
`DefaultTextEditingShortcuts` with document-specific bindings (heading
promotion, list insertion, code block toggle). All actions are registered as
`Intent` / `Action` pairs and can be overridden by the caller in the usual way
via an `Actions` ancestor widget.

**Migration path.** See `doc/migration_from_editable_text.md` for a
side-by-side API comparison and step-by-step migration from `TextField` and
`EditableText`. The short summary:

| Flutter | `editable_document` |
|---------|---------------------|
| `EditableText` | `EditableDocument` |
| `TextField` | `DocumentField` |
| `TextEditingController` | `DocumentEditingController` |
| `TextEditingValue` | `MutableDocument` + `DocumentSelection` + `ComposerPreferences` |
| `TextSelection` | `DocumentSelection` |
| `TextInputFormatter` | `EditReaction` |
| `buildTextSpan()` | `ComponentBuilder.createComponent()` |
| _(no equivalent)_ | `UndoableEditor` |

---

## OPEN QUESTIONS

1. **Package location.** Should this land as a new package in `packages/flutter/`
   (e.g. `packages/flutter/lib/src/rendering/document_layout.dart`,
   `packages/flutter/lib/src/widgets/editable_document.dart`) modelled on how
   `EditableText` and `RenderEditable` live today? Or as a separate first-party
   package under `packages/` that is then re-exported from `flutter/material.dart`?

2. **Material / Cupertino wrapper strategy.** Should the framework ship
   `DocumentTextField` (Material) and `CupertinoDocumentField` as companions to
   `TextField` and `CupertinoTextField`? If so, which team owns those wrappers?

3. **IME testing gap (flutter/flutter#131510).** The framework currently lacks a
   mechanism to drive real `TextEditingDelta` sequences in widget tests — only
   full-replacement `TextEditingValue`s can be injected via `WidgetTester`. Should
   this be addressed as a prerequisite to merging `EditableDocument` (since tests
   for its IME bridge depend on delta injection)?

4. **Controller hierarchy.** Should `DocumentEditingController` extend
   `TextEditingController` for backwards-compatibility convenience (e.g. so
   existing controller listeners keep working)? Or remain a separate
   `ChangeNotifier` hierarchy to avoid inheriting `TextEditingController`'s flat
   `text` contract, which would be misleading for block documents?

5. **Viewport virtualization.** The current `ComponentBuilder` per-block approach
   renders all blocks, even those outside the viewport. For documents with
   10,000+ nodes, this will be a performance problem. Should viewport-based
   virtualization (similar to `ListView.builder`) be a Phase 1 requirement before
   merge, or deferred post-merge?

---

## TESTING PLAN

The package ships a comprehensive test suite that covers all four layers:

- **1,244 tests** across 48 test files (828 `test()` unit tests + 416
  `testWidgets()` widget tests).
- **60 source files** across `lib/src/` (model, rendering, services, widgets).
- **Golden tests** for caret rendering, selection highlight rendering, and all
  five block types.
- **Integration tests** for gesture handling on iOS, Android, and desktop
  (click, drag, triple-click, long-press, magnifier).
- **Benchmark suite** — micro-benchmarks for document model operations, IME
  serialization round-trips, and layout geometry queries. Baselines recorded on
  Flutter 3.38.x on macOS Apple Silicon.

Coverage targets:
- Overall: ≥ 90% branch coverage.
- `lib/src/services/` specifically: 100% branch coverage (enforced by CI).

All tests pass with `flutter test` on Flutter 3.38.x. The CI gate runs
`flutter analyze` (zero warnings), `dart format --set-exit-if-changed`, and
`flutter test --coverage` before every merge.

---

## DOCUMENTATION PLAN

- **Dartdoc.** Every public symbol carries `///` documentation. The
  `public_member_api_docs` analysis option is enabled; `dart doc` must produce
  zero warnings. Flutter-style documentation includes `{@tool snippet}`
  examples, `/// See also:` sections, and cross-links to analogous Flutter
  classes (e.g. `/// * [TextEditingController], Flutter's equivalent for flat text.`).

- **doc/architecture.md.** Layer diagram, class relationship diagrams (all four
  layers), IME data flow sequence, command pipeline sequence, widget tree
  structure, and key design decisions. Kept as Markdown for embedding in pull
  requests.

- **doc/migration_from_editable_text.md.** Side-by-side API comparison table,
  conceptual differences section (flat string vs. block model; formatter vs.
  reaction; `buildTextSpan` vs. `ComponentBuilder`), and step-by-step before/after
  code examples for `TextField → DocumentField` and `EditableText → EditableDocument`.

- **example/main.dart.** Full-featured rich text editor demo. Toolbar with Bold,
  Italic, Underline, H1/H2/H3, bullet list, ordered list, code block, horizontal
  rule, and image insertion. Footer with word count, character count, undo, and
  redo. Platform-adaptive: Material on Android / Windows / Linux; Cupertino on
  iOS / macOS.

- **README.md.** Quick-start snippet, feature list, four-layer architecture
  overview, and links to architecture and migration docs. Kept short and
  scannable.

---

## MIGRATION PLAN

`EditableDocument` is designed to coexist with `EditableText` as a new surface.
No existing APIs are modified.

**For app developers (voluntary adoption):**

1. Replace `TextEditingController` with `DocumentEditingController`, wrapping
   initial text in a `ParagraphNode` inside a `MutableDocument`.
2. Replace `TextField` with `DocumentField` (same `InputDecoration` API).
3. Replace `EditableText` with `EditableDocument` (same constructor shape for
   `focusNode`, `readOnly`, `autofocus`, `textInputAction`, `keyboardType`).
4. Replace `TextInputFormatter` with `EditReaction` for input transformation.
5. Replace `buildTextSpan()` overrides with `ComponentBuilder` for custom
   rendering.
6. Consult `doc/migration_from_editable_text.md` for detailed per-API
   migration.

**If merged into the Flutter framework:**

- New files only. No modifications to existing `EditableText`, `TextField`,
  `RenderEditable`, or `TextEditingController`.
- Exported from `flutter/widgets.dart` and `flutter/material.dart` alongside
  the existing text editing surface.
- `EditableText` is not deprecated — it remains the right choice for single-field
  text input. No deprecation path is needed.
- If Material / Cupertino wrapper widgets (`DocumentTextField`,
  `CupertinoDocumentField`) are added, they follow the same deprecation-free
  pattern: new symbols only.
