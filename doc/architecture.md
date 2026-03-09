# editable_document — Architecture

This document describes the internal structure of the `editable_document` package:
layer boundaries, class relationships, data flows, and the widget tree that
`EditableDocument` produces at runtime.

---

## 1. Layer diagram

Dependencies flow downward only. No layer may import from a layer above it.

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
|  RenderHRule..Block |         imports model only
|  DocumentCaretPainter                        |
|  DocumentSelectionPainter                    |
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

### Allowed Flutter imports per layer

| Layer | Permitted Flutter packages |
|-------|---------------------------|
| `model` | `flutter/foundation`, `flutter/painting` (TextAffinity only) |
| `rendering` | `flutter/foundation`, `flutter/painting`, `flutter/rendering`, `flutter/scheduler` |
| `services` | `flutter/foundation`, `flutter/painting`, `flutter/services` |
| `widgets` | All Flutter layers (`flutter/material`, `flutter/cupertino`, etc.) |

---

## 2. Class relationships per layer

### 2.1 Model layer (`lib/src/model/`)

```
DocumentNode (abstract, Diagnosticable)
  |
  +-- TextNode (abstract)          # adds AttributedText text field
  |     |
  |     +-- ParagraphNode          # blockType: ParagraphBlockType (body/h1/h2/h3/blockquote)
  |     +-- ListItemNode           # type: ordered|unordered, indent, ordinalIndex
  |     +-- CodeBlockNode          # language (optional)
  |
  +-- ImageNode                    # imageUrl, altText, width, height
  +-- BlockquoteNode               # text (AttributedText), layout properties
  +-- HorizontalRuleNode           # no additional fields

HasBlockLayout (abstract interface class)   # lib/src/model/block_layout.dart
  |-- alignment: BlockAlignment
  |-- textWrap: bool
  |-- width: double?
  |-- height: double?
  # implemented by: ImageNode, CodeBlockNode, BlockquoteNode, HorizontalRuleNode

AttributedText                     # immutable: text (String) + List<SpanMarker>
  |
  +-- SpanMarker                   # attribution, offset, markerType (start|end)
  +-- Attribution (abstract)
        +-- NamedAttribution        # bold, italics, underline, strikethrough
        +-- LinkAttribution          # url

Document (abstract)                # read-only interface: nodes, nodeById(), nodeAt()
  +-- MutableDocument              # add/insert/move/remove/reset node mutation
        |
        +-- ValueNotifier<List<DocumentChangeEvent>> changes

DocumentPosition                   # nodeId + NodePosition
DocumentSelection                  # base: DocumentPosition, extent: DocumentPosition
  +-- DocumentSelection.collapsed()

NodePosition (abstract)
  +-- TextNodePosition             # offset, affinity
  +-- BinaryNodePosition           # (for ImageNode, HorizontalRuleNode)

DocumentEditingController          # extends ChangeNotifier
  |-- document: MutableDocument
  |-- selection: DocumentSelection?
  |-- preferences: ComposerPreferences
  |-- autofillHints: List<String>?
  |-- setSelection(), clearSelection(), toggleAttributionInSelection()

EditRequest (abstract marker interface)
  +-- InsertTextRequest
  +-- DeleteContentRequest
  +-- ReplaceNodeRequest
  +-- SplitParagraphRequest
  +-- MergeNodeRequest
  +-- MoveNodeRequest
  +-- ChangeBlockTypeRequest
  +-- ApplyAttributionRequest
  +-- RemoveAttributionRequest

EditCommand (abstract)
  +-- execute(EditContext) -> List<DocumentChangeEvent>
  # Concrete commands: InsertTextCommand, DeleteContentCommand,
  #   ReplaceNodeCommand, SplitParagraphCommand, MergeNodeCommand,
  #   MoveNodeCommand, ChangeBlockTypeCommand, ApplyAttributionCommand,
  #   RemoveAttributionCommand

EditContext                        # document: MutableDocument, controller: DocumentEditingController

EditReaction (abstract)
  +-- react(EditContext, List<EditRequest>, List<DocumentChangeEvent>)
        -> List<EditRequest>       # follow-up requests (chained, max depth 10)

EditListener (abstract)
  +-- onEdit(List<DocumentChangeEvent>)

Editor
  |-- editContext: EditContext
  |-- submit(EditRequest)          # maps request -> command -> execute -> react -> notify
  |-- addReaction / removeReaction
  |-- addListener / removeListener
  |-- dispose()

UndoableEditor extends Editor
  |-- canUndo / canRedo: bool
  |-- undo()
  |-- redo()
  |-- clearHistory()
  |-- maxUndoLevels: int           # default 100; oldest entry evicted when exceeded
```

### 2.2 Rendering layer (`lib/src/rendering/`)

```
RenderDocumentBlock (abstract RenderBox)
  |-- nodeId: String               # links render object to DocumentNode
  |-- nodeSelection: DocumentSelection?
  |-- preferredLineHeight: double
  |-- getPositionAtOffset(Offset) -> NodePosition?
  |-- getRectForPosition(NodePosition) -> Rect?
  |-- getLineBoundary(TextNodePosition) -> TextRange  # text blocks only
  |
  +-- RenderTextBlock (abstract)   # wraps TextPainter; handles text layout
  |     +-- RenderParagraphBlock   # ParagraphBlockType scaling (h1/h2/h3)
  |     +-- RenderListItemBlock    # bullet/number gutter + indentation
  |     +-- RenderCodeBlock        # monospace font, background fill
  |
  +-- RenderImageBlock             # placeholder box with aspect ratio
  +-- RenderBlockquoteBlock        # quoted text with left border
  +-- RenderHorizontalRuleBlock    # fixed-height hairline rule

BlockLayoutMixin (mixin on RenderDocumentBlock)  # lib/src/rendering/block_layout_mixin.dart
  |-- blockAlignment: BlockAlignment  (storage + setter)
  |-- requestedWidth: double?         (storage + setter)
  |-- requestedHeight: double?        (storage + setter)
  |-- textWrap: bool                  (storage + setter)
  |-- initBlockLayout(...)            (constructor helper, no markNeedsLayout)
  |-- debugFillBlockLayoutProperties  (diagnostic helper)
  # used by: RenderImageBlock, RenderCodeBlock, RenderBlockquoteBlock, RenderHorizontalRuleBlock

RenderDocumentLayout extends RenderBox
    with ContainerRenderObjectMixin<RenderDocumentBlock, DocumentBlockParentData>
         RenderBoxContainerDefaultsMixin<...>
  |-- blockSpacing: double
  |-- getComponentByNodeId(String) -> RenderDocumentBlock?
  |-- getDocumentPositionAtOffset(Offset) -> DocumentPosition?
  |-- getDocumentPositionNearestToOffset(Offset) -> DocumentPosition
  |-- getRectForDocumentPosition(DocumentPosition) -> Rect?
  |-- computeMaxScrollExtent(double viewportHeight) -> double

DocumentBlockParentData
    extends ContainerBoxParentData<RenderDocumentBlock>
  |-- offset: Offset               # paint offset set during performLayout

DocumentCaretPainter               # CustomPainter — blinking caret line
DocumentSelectionPainter           # CustomPainter — selection highlight rects

RenderDocumentCaret extends RenderBox
RenderDocumentSelectionHighlight extends RenderBox
```

### 2.3 Services layer (`lib/src/services/`)

```
DocumentImeSerializer              # const, stateless
  |-- toTextEditingValue(document, selection, ...) -> TextEditingValue
  |     Mode 1: single TextNode -> full node text + mapped TextSelection
  |     Mode 2: cross-block or non-text -> synthetic placeholder '\u200B'
  |-- toDocumentSelection(imeValue, document, serializedNodeId) -> DocumentSelection?
  |-- deltaToRequests(deltas, document, selection) -> List<EditRequest>
  |     TextEditingDeltaInsertion('\n')  -> SplitParagraphRequest
  |     TextEditingDeltaInsertion(text)  -> InsertTextRequest
  |     TextEditingDeltaDeletion         -> DeleteContentRequest
  |     TextEditingDeltaReplacement      -> DeleteContentRequest + InsertTextRequest
  |     TextEditingDeltaNonTextUpdate    -> (empty — selection only)

DocumentImeInputClient implements DeltaTextInputClient
  |-- serializer: DocumentImeSerializer
  |-- controller: DocumentEditingController
  |-- requestHandler: void Function(EditRequest)
  |-- onAction, onFloatingCursor, onInsertContent (optional callbacks)
  |-- autofillScopeGetter: AutofillScope? Function()? (optional)
  |-- openConnection(TextInputConfiguration)  # must have enableDeltaModel: true
  |-- closeConnection()
  |-- syncToIme()                  # push current document state -> platform
  |-- showKeyboard() / hideKeyboard()
  |-- updateEditingValueWithDeltas(List<TextEditingDelta>)
  |-- updateEditingValue(TextEditingValue)  # fallback: synthesises delta then delegates

DocumentKeyboardHandler            # non-IME key events (arrows, shortcuts)
  |-- document: Document
  |-- controller: DocumentEditingController
  |-- requestHandler: void Function(EditRequest)
  |-- verticalMoveResolver / pageMoveResolver / lineMoveResolver (injected)
  |-- onKeyEvent(KeyEvent) -> bool

DocumentAutofillClient implements AutofillClient
  |-- controller: DocumentEditingController
  |-- autofillId: String
  |-- textInputConfiguration: TextInputConfiguration
  |-- enabled: bool
```

### 2.4 Widgets layer (`lib/src/widgets/`)

```
ComponentViewModel (abstract)
  |-- nodeId, nodeSelection, isSelected
  +-- ParagraphComponentViewModel   # text, blockType, textStyle
  +-- ListItemComponentViewModel    # text, type, indent, ordinalIndex, textStyle
  +-- ImageComponentViewModel       # imageUrl, altText, imageWidth, imageHeight  implements HasLayoutFields
  +-- CodeBlockComponentViewModel   # text, textStyle, language                  implements HasLayoutFields
  +-- BlockquoteComponentViewModel  # text, textStyle                            implements HasLayoutFields
  +-- HorizontalRuleComponentViewModel                                           # implements HasLayoutFields

HasLayoutFields (abstract interface class)   # in lib/src/widgets/component_builder.dart
  |-- blockAlignment: BlockAlignment
  |-- requestedWidth: double?
  |-- requestedHeight: double?
  |-- textWrap: bool
  # implemented by: ImageComponentViewModel, CodeBlockComponentViewModel,
  #   BlockquoteComponentViewModel, HorizontalRuleComponentViewModel
  # enables shared _updateBlockLayout(BlockLayoutMixin, HasLayoutFields) helper

ComponentContext                    # document, selection, stylesheet
ComponentBuilder (abstract)
  |-- createViewModel(Document, DocumentNode) -> ComponentViewModel?
  |-- createComponent(ComponentViewModel, ComponentContext) -> Widget?
  +-- ParagraphComponentBuilder
  +-- ListItemComponentBuilder
  +-- ImageComponentBuilder
  +-- CodeBlockComponentBuilder
  +-- HorizontalRuleComponentBuilder

defaultComponentBuilders: const List<ComponentBuilder>  # order matters

DocumentLayout (StatefulWidget)
  |-- Renders RenderDocumentLayout via MultiChildRenderObjectWidget
  |-- componentForNode(nodeId) -> RenderDocumentBlock?
  |-- rectForDocumentPosition(DocumentPosition) -> Rect?
  |-- documentPositionNearestToOffset(Offset) -> DocumentPosition?

EditableDocument (StatefulWidget)    # primary public widget
  |-- controller: DocumentEditingController
  |-- focusNode: FocusNode
  |-- editor: Editor?                # optional; routes EditRequests
  |-- readOnly, autofocus, textInputAction, keyboardType
  |-- componentBuilders, blockSpacing, stylesheet
  |-- layoutKey: GlobalKey<DocumentLayoutState>?
  |-- scrollPadding: EdgeInsets

DocumentField (StatefulWidget)       # wraps EditableDocument + InputDecoration

DocumentSelectionOverlay             # floating selection handles + context menu
CaretDocumentOverlay                 # blinking caret rendered in an Overlay

DocumentMouseInteractor              # desktop: click, drag, triple-click
IosDocumentGestureController         # iOS: tap, long-press, magnifier, handles
AndroidDocumentGestureController     # Android: tap, long-press, magnifier

DocumentScrollable                   # manages ScrollController + auto-scroll
DragHandleAutoScroller               # edge-triggered auto-scroll during handle drag
SliverEditableDocument               # Sliver variant for CustomScrollView

DocumentTextSelectionControls        # Material/Cupertino text selection toolbar
DocumentSemanticsScope               # SemanticsNode wrapper for a11y
```

---

## 3. IME data flow

The complete round-trip for a user keystroke on a software keyboard:

```
Platform IME (iOS/Android/web)
  |
  | (TextInputChannel — method channel)
  v
DocumentImeInputClient.updateEditingValueWithDeltas(List<TextEditingDelta>)
  |
  | each delta passed to:
  v
DocumentImeSerializer.deltaToRequests(deltas, document, selection)
  |
  | returns List<EditRequest>
  v
requestHandler(EditRequest)            # typically Editor.submit()
  |
  v
Editor.submit(EditRequest)
  |
  +-> _createCommand(request)          # request type -> concrete EditCommand
  |
  +-> EditCommand.execute(EditContext)
  |     |
  |     +-> MutableDocument mutations
  |     +-> returns List<DocumentChangeEvent>
  |
  +-> EditReaction.react(...)          # optional follow-up requests (max depth 10)
  |
  +-> EditListener.onEdit(events)      # UI rebuild, IME sync, etc.
  |
  v
DocumentEditingController notifies listeners
  |
  v
EditableDocumentState._onControllerChanged()
  |
  v
DocumentImeInputClient.syncToIme()
  |
  | serializes current document + selection -> TextEditingValue (Mode 1 or 2)
  v
TextInputConnection.setEditingState(TextEditingValue)
  |
  v
Platform IME (internal model updated)
```

### IME serialization modes

| Condition | Mode | TextEditingValue.text |
|-----------|------|-----------------------|
| Selection within a single `TextNode` | Mode 1 | Full node plain text |
| Cross-block or non-text-node selection | Mode 2 | `'\u200B'` (zero-width space) |
| No selection (`null`) | Mode 2 | `''` (empty string) |

Mode 1 preserves autocorrect, voice dictation, and IME composition (underline
suggestions). Mode 2 lets the document handle the edit directly, using the
synthetic placeholder to prevent the IME from sending confusing empty-string
deltas.

### Autofill path

When an `AutofillGroup` ancestor is present, `DocumentImeInputClient.openConnection`
delegates to `AutofillScope.attach` instead of `TextInput.attach`, routing the
connection through `DocumentAutofillClient` so the editor participates in the
platform's autofill group.

---

## 4. Command pipeline sequence

```
caller: editor.submit(EditRequest)
  |
  | [UndoableEditor only] push pre-submit snapshot to undo stack
  | clear redo stack
  |
  v
Editor._processRequest(request, accumulated, depth=0)
  |
  +-> EditCommand command = _createCommand(request)
  |     Maps request type to concrete command instance.
  |     Throws ArgumentError for unrecognised request types.
  |
  +-> List<DocumentChangeEvent> events = command.execute(editContext)
  |     Mutates MutableDocument; returns change events.
  |     Changes trigger MutableDocument.changes ValueNotifier.
  |
  +-> for each EditReaction in _reactions:
  |     List<EditRequest> followUps = reaction.react(context, [request], events)
  |     for each followUp: _processRequest(followUp, accumulated, depth+1)
  |     (reaction depth capped at _maxReactionDepth = 10 to prevent loops)
  |
  v
Editor.notifyEditListeners(all accumulated events)
  |
  +-> EditListener.onEdit(List<DocumentChangeEvent>)  [for each listener]
```

### UndoableEditor snapshot strategy

`UndoableEditor` captures a **full deep copy** of every `DocumentNode` (via
`DocumentNode.copyWith`) and the current `DocumentSelection` before each
`submit`. On `undo`, `MutableDocument.reset(snapshot)` atomically replaces all
nodes and the selection is restored. On `redo`, the original `EditRequest` is
re-submitted through `super.submit`, generating a fresh undo entry
automatically.

The undo stack is bounded by `maxUndoLevels` (default 100). Once the cap is
reached, the oldest entry is evicted to bound memory usage.

---

## 5. Widget tree

### What `EditableDocument.build()` produces

```
Focus (focusNode, onKeyEvent -> DocumentKeyboardHandler)
  |
  +-- DocumentSemanticsScope (isFocused, isReadOnly)
        |
        +-- DocumentLayout (GlobalKey<DocumentLayoutState>)
              |
              # One child widget per DocumentNode, produced by ComponentBuilders:
              +-- _ParagraphBlockWidget    -> RenderParagraphBlock
              +-- _ListItemBlockWidget     -> RenderListItemBlock
              +-- _ImageBlockWidget        -> RenderImageBlock
              +-- _CodeBlockWidget         -> RenderCodeBlock
              +-- _HorizontalRuleBlock..   -> RenderHorizontalRuleBlock
              +-- ...
```

### Typical app-level composition

```
DocumentScrollable (ScrollController, auto-scroll on selection change)
  |
  +-- DocumentMouseInteractor (desktop) or
  |   IosDocumentGestureController (iOS) or
  |   AndroidDocumentGestureController (Android)
        |
        +-- DocumentSelectionOverlay (floating handles + context menu)
              |
              +-- EditableDocument
                    |
                    +-- Focus
                          |
                          +-- DocumentSemanticsScope
                                |
                                +-- DocumentLayout
                                      |
                                      +-- ParagraphComponent
                                      +-- ListItemComponent
                                      +-- CodeBlockComponent
                                      +-- ImageComponent
                                      +-- HorizontalRuleComponent
                                      +-- ...
```

For a sliver-based layout (e.g. inside a `CustomScrollView`), replace
`DocumentScrollable` with `SliverEditableDocument`, which wraps
`EditableDocument` in a `SliverToBoxAdapter` and manages the sliver scroll
offset.

### ComponentBuilder resolution order

`DocumentLayout` iterates `defaultComponentBuilders` (or the caller-supplied
list) for each `DocumentNode`. The first builder whose `createViewModel` returns
non-null wins; its `createComponent` is then called immediately.

```
defaultComponentBuilders = [
  ParagraphComponentBuilder,   // handles ParagraphNode
  ListItemComponentBuilder,    // handles ListItemNode
  ImageComponentBuilder,       // handles ImageNode
  CodeBlockComponentBuilder,   // handles CodeBlockNode
  HorizontalRuleComponentBuilder, // handles HorizontalRuleNode
]
```

Prepend custom builders to override defaults:

```dart
final builders = [MyCustomParagraphBuilder(), ...defaultComponentBuilders];
```

---

## 6. Key design decisions

### Zero external dependencies

The package imports Flutter SDK only. This is a merger prerequisite: the
eventual goal is to land `EditableDocument` in the Flutter framework itself,
which prohibits pub.dev dependencies.

### DeltaTextInputClient (not TextInputClient)

`DocumentImeInputClient` implements `DeltaTextInputClient`, which delivers
`TextEditingDelta` objects instead of full replacement `TextEditingValue`s. This
is critical for a block document: a full-replacement approach would require
reconstructing which node was edited after every keystroke, whereas deltas
carry offset and text directly.

### Immutable model values

`DocumentNode`, `AttributedText`, and `SpanMarker` are immutable. All mutations
produce new instances via `copyWith`. This makes snapshot-based undo
(`UndoableEditor`) straightforward and enables equality-based diffing in
`ComponentViewModel` to skip unnecessary widget rebuilds.

### ComponentBuilder / ComponentViewModel pattern

This indirection mirrors Flutter's `RenderObjectWidget` split. The view-model
layer allows `DocumentLayout` to diff old and new view models (via `==`) and
skip calling `createComponent` when nothing changed, which keeps layout stable
during selection-only changes.

### RenderDocumentLayout geometry queries

The rendering layer exposes pixel-coordinate queries (`getRectForDocumentPosition`,
`getDocumentPositionNearestToOffset`) that the widget layer uses to implement
keyboard navigation (Up/Down arrows, Page Up/Down, line-boundary moves) without
the widget tree having to know anything about text layout internals. All
geometry resolution is encapsulated behind `DocumentLayoutState`.
