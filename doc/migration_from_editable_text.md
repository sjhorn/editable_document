# Migrating from EditableText / TextField to EditableDocument / DocumentField

This guide is for developers who are replacing Flutter's built-in single-field
text widgets with `editable_document`'s block-aware equivalents. The two
systems share the same conceptual shape — controller, focus node, widget — but
the underlying model is fundamentally different. Read the conceptual section
before jumping to the code examples.

---

## 1. API comparison

| Flutter | editable_document | Notes |
|---------|-------------------|-------|
| `EditableText` | `EditableDocument` | Primary low-level editing widget |
| `TextField` | `DocumentField` | Decorated wrapper with `InputDecoration` |
| `TextEditingController` | `DocumentEditingController` | State holder for content + selection |
| `TextEditingValue` | `MutableDocument` + `DocumentSelection` + `ComposerPreferences` | Structured; not a single value |
| `TextSelection` | `DocumentSelection` | Base/extent positions across nodes |
| `TextPosition` | `DocumentPosition` | `{nodeId, nodePosition}` pair |
| `TextInputFormatter` | `EditReaction` | Post-execution side-effect pipeline |
| `buildTextSpan()` | `ComponentBuilder.createComponent()` | Per-block widget factory |
| `TextSpan` / `InlineSpan` | `AttributedText` + `ComponentBuilder` | Rich text value + rendering |
| `TextSelectionControls` | `DocumentTextSelectionControls` | Platform handles and toolbar |
| `ScrollController` | `DocumentScrollable` | Document-aware auto-scroll wrapper |
| `TextEditingController.text` | iterating `document.nodes` | See section 5 |
| _(no equivalent)_ | `UndoableEditor` | Snapshot-based undo/redo |
| _(no equivalent)_ | `ChangeBlockTypeRequest` | Converts body text to headings, etc. |

---

## 2. Key conceptual differences

### 2.1 Flat string vs. block-structured document

`TextField` stores everything in a single `String` accessed via
`TextEditingController.text`. `DocumentField` stores content as a
`MutableDocument` — an ordered list of typed `DocumentNode` objects:

- `ParagraphNode` — body text, headings (H1–H6), blockquotes
- `ListItemNode` — ordered and unordered list items with indent levels
- `ImageNode` — embedded images by URL
- `CodeBlockNode` — fenced code with an optional language tag
- `HorizontalRuleNode` — a visual divider with no text

Each node has a stable string `id` that persists across edits. Cross-node
operations (for example, deleting from the middle of one paragraph to the
middle of the next) are expressed as structured `EditRequest`s rather than
string splices.

### 2.2 State is split across three objects, not one

`TextEditingValue` bundles text, selection, and composing region into a single
immutable snapshot. `DocumentEditingController` separates these concerns:

| Concern | Class |
|---------|-------|
| Document content | `MutableDocument` (via `controller.document`) |
| Cursor / selection | `DocumentSelection?` (via `controller.selection`) |
| Active inline style | `ComposerPreferences` (via `controller.preferences`) |

All three are held by `DocumentEditingController`, which is a `ChangeNotifier`.
Listeners are notified whenever any of the three change.

### 2.3 Input transformation: formatter vs. reaction

`TextInputFormatter` intercepts raw text before it is applied, synchronously
returning a modified `TextEditingValue`. `EditReaction` runs after each
`EditRequest` has already been applied to the document. It may return
additional `EditRequest`s to process, enabling cascading transformations such
as auto-formatting or structural constraints:

```dart
class MarkdownBoldReaction implements EditReaction {
  @override
  List<EditRequest> react(
    EditContext context,
    List<EditRequest> requests,
    List<DocumentChangeEvent> changes,
  ) {
    // Inspect `changes` and return follow-up requests if needed.
    return const [];
  }
}
```

Register reactions on the `Editor`:

```dart
editor.addReaction(MarkdownBoldReaction());
```

### 2.4 Custom rendering: buildTextSpan vs. ComponentBuilder

`TextEditingController.buildTextSpan()` lets you style a flat string.
`ComponentBuilder` is more powerful: it maps a `DocumentNode` to an arbitrary
`Widget`, so each block type can have a completely different visual
representation.

```dart
class MyParagraphBuilder extends ComponentBuilder {
  const MyParagraphBuilder();

  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode) return null;
    return ParagraphComponentViewModel(
      nodeId: node.id,
      text: node.text,
      blockType: node.blockType,
      textStyle: const TextStyle(fontFamily: 'Georgia'),
    );
  }

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is! ParagraphComponentViewModel) return null;
    // Return any widget — not restricted to a TextSpan tree.
    return _StyledParagraphWidget(viewModel: viewModel);
  }
}
```

Prepend your builder to the default list to override specific node types:

```dart
EditableDocument(
  controller: controller,
  focusNode: focusNode,
  componentBuilders: [const MyParagraphBuilder(), ...defaultComponentBuilders],
)
```

### 2.5 Undo/redo

`TextField` and `EditableText` have no built-in undo. `editable_document`
ships `UndoableEditor`, which wraps the `Editor` command pipeline with
snapshot-based undo/redo. `DocumentField` creates one automatically; when
using `EditableDocument` directly, create one explicitly:

```dart
final editor = UndoableEditor(
  editContext: EditContext(document: doc, controller: ctrl),
  maxUndoLevels: 50,
);
```

---

## 3. Migration: TextField to DocumentField

The simplest migration. `DocumentField` matches `TextField`'s constructor
surface: same `decoration`, `focusNode`, `readOnly`, `autofocus`,
`textInputAction`, `keyboardType`, and `autofillHints` parameters.

**Before (TextField):**

```dart
final controller = TextEditingController(text: 'Hello world');

TextField(
  controller: controller,
  decoration: const InputDecoration(labelText: 'Notes'),
  onChanged: (value) => debugPrint('text: $value'),
)
```

**After (DocumentField):**

```dart
final controller = DocumentEditingController(
  document: MutableDocument([
    ParagraphNode(id: 'p1', text: AttributedText('Hello world')),
  ]),
);

DocumentField(
  controller: controller,
  decoration: const InputDecoration(labelText: 'Notes'),
  onSelectionChanged: (selection) => debugPrint('selection: $selection'),
)
```

Key differences:

- The initial text is wrapped in a `ParagraphNode` inside a `MutableDocument`.
  Use `AttributedText(string)` to create plain text; omit the argument for an
  empty node.
- `onChanged` (a `ValueChanged<String>`) does not yet exist on `DocumentField`.
  Listen to the controller directly or use `onSelectionChanged` for selection
  events.
- Character limit display is handled by the `maxLength` parameter (same name),
  but it does not enforce a hard cap — it only updates the counter widget.

---

## 4. Migration: EditableText to EditableDocument

`EditableText` requires a `FocusNode`, `TextEditingController`, and several
style parameters. `EditableDocument` has the same shape.

**Before (EditableText):**

```dart
final controller = TextEditingController(text: 'Initial content');
final focusNode = FocusNode();
final layoutKey = GlobalKey<EditableTextState>();

EditableText(
  key: layoutKey,
  controller: controller,
  focusNode: focusNode,
  style: Theme.of(context).textTheme.bodyLarge!,
  cursorColor: Colors.blue,
  backgroundCursorColor: Colors.grey,
  selectionColor: Colors.blue.withOpacity(0.3),
  textDirection: TextDirection.ltr,
  autofocus: true,
  readOnly: false,
  keyboardType: TextInputType.multiline,
  textInputAction: TextInputAction.newline,
  onChanged: (value) => _onTextChanged(value),
)
```

**After (EditableDocument):**

```dart
final controller = DocumentEditingController(
  document: MutableDocument([
    ParagraphNode(id: 'p1', text: AttributedText('Initial content')),
  ]),
);
final focusNode = FocusNode();
final layoutKey = GlobalKey<DocumentLayoutState>();
final editor = UndoableEditor(
  editContext: EditContext(document: controller.document, controller: controller),
);

EditableDocument(
  controller: controller,
  focusNode: focusNode,
  layoutKey: layoutKey,
  style: Theme.of(context).textTheme.bodyLarge,
  textDirection: TextDirection.ltr,
  autofocus: true,
  readOnly: false,
  keyboardType: TextInputType.multiline,
  textInputAction: TextInputAction.newline,
  editor: editor,
  onSelectionChanged: (selection) => _onSelectionChanged(selection),
)
```

Parameters that do not exist on `EditableDocument`:

| `EditableText` param | Reason absent | Alternative |
|----------------------|---------------|-------------|
| `cursorColor` | Caret is drawn by `CaretDocumentOverlay` | Style via `stylesheet` |
| `backgroundCursorColor` | Not applicable to block model | N/A |
| `selectionColor` | Drawn by `DocumentSelectionOverlay` | Style via theme |
| `obscureText` | Not supported for block documents | N/A |
| `autocorrect` | Forwarded through IME configuration | Planned |
| `onChanged` | Reserved; pending Phase 6 | Listen to `controller` directly |

---

## 5. Reading text content

**TextEditingController — single string:**

```dart
final text = controller.text; // 'Hello world'
```

**DocumentEditingController — iterate nodes:**

```dart
// All text nodes joined with newlines.
final text = controller.document.nodes
    .whereType<TextNode>()
    .map((node) => node.text.text)
    .join('\n');

// Total character count (as DocumentField.maxLength does internally).
final charCount = controller.document.nodes
    .whereType<TextNode>()
    .fold(0, (sum, node) => sum + node.text.text.length);

// Access a specific node by id.
final node = controller.document.nodeById('p1');
if (node is ParagraphNode) {
  debugPrint(node.text.text);
}
```

---

## 6. Working with selection

**Flutter — character offsets:**

```dart
// Collapsed caret at offset 5.
controller.selection = const TextSelection.collapsed(offset: 5);

// Range selection from offset 2 to 8.
controller.selection = const TextSelection(baseOffset: 2, extentOffset: 8);
```

**editable_document — node id + within-node offset:**

```dart
// Collapsed caret at character offset 5 in node 'p1'.
controller.setSelection(
  DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: 'p1',
      nodePosition: TextNodePosition(offset: 5),
    ),
  ),
);

// Range selection: base at offset 2 in 'p1', extent at offset 3 in 'p2'.
controller.setSelection(
  DocumentSelection(
    base: DocumentPosition(
      nodeId: 'p1',
      nodePosition: TextNodePosition(offset: 2),
    ),
    extent: DocumentPosition(
      nodeId: 'p2',
      nodePosition: TextNodePosition(offset: 3),
    ),
  ),
);
```

`DocumentSelection.isCollapsed` is the equivalent of
`TextSelection.isCollapsed`. `DocumentSelection.normalize(document)` returns a
copy with `base` guaranteed to precede `extent` in document order, matching the
behaviour of `TextSelection` when `baseOffset <= extentOffset`.

Non-text nodes (images, horizontal rules) use `BinaryNodePosition` instead of
`TextNodePosition`:

```dart
// Select an image node.
controller.setSelection(
  DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: 'img1',
      nodePosition: BinaryNodePosition.upstream(),
    ),
  ),
);
```

---

## 7. Rich text formatting

`EditableText` and `TextField` have no formatting API — they render a flat
string. All inline styling in `editable_document` is expressed as
`Attribution`s applied to spans of `AttributedText`.

### Applying an attribution via the editor

```dart
// Assume `selection` is the current DocumentSelection from the controller.
editor.submit(ApplyAttributionRequest(
  selection: selection,
  attribution: NamedAttribution.bold,
));

// Italics (note: the constant is `italics`, not `italic`).
editor.submit(ApplyAttributionRequest(
  selection: selection,
  attribution: NamedAttribution.italics,
));

// Removing an attribution.
editor.submit(RemoveAttributionRequest(
  selection: selection,
  attribution: NamedAttribution.bold,
));
```

### Built-in `NamedAttribution` constants

| Constant | Rendered as |
|----------|-------------|
| `NamedAttribution.bold` | Bold weight |
| `NamedAttribution.italics` | Italic style |
| `NamedAttribution.underline` | Underline decoration |
| `NamedAttribution.strikethrough` | Strikethrough decoration |
| `NamedAttribution.code` | Monospace inline code |

### Changing block type

There is no `TextField` equivalent. Use `ChangeBlockTypeRequest`:

```dart
// Promote a paragraph to a level-1 heading.
editor.submit(ChangeBlockTypeRequest(
  nodeId: 'p1',
  newBlockType: ParagraphBlockType.header1,
));

// Demote back to body text.
editor.submit(ChangeBlockTypeRequest(
  nodeId: 'p1',
  newBlockType: ParagraphBlockType.paragraph,
));
```

### Tracking active style for new text

`ComposerPreferences` (accessible via `controller.preferences`) holds the set
of attributions that will be applied to the next characters typed. Toggle bold
on/off in a toolbar button:

```dart
controller.preferences.toggle(NamedAttribution.bold);
controller.notifyListeners(); // Tell the UI to redraw the toolbar state.
```

---

## 8. Undo and redo

`EditableText` has no undo API. `DocumentField` wires `UndoableEditor`
automatically. When using `EditableDocument` directly, create and pass an
`UndoableEditor`:

```dart
final editor = UndoableEditor(
  editContext: EditContext(document: controller.document, controller: controller),
  maxUndoLevels: 100,
);

// In your toolbar or keyboard shortcut handler:
if (editor.canUndo) editor.undo();
if (editor.canRedo) editor.redo();

// Clear history (e.g. after a save):
editor.clearHistory();
```

---

## 9. Common mistakes

**Using `NamedAttribution.italic` instead of `NamedAttribution.italics`.**
The constant is spelled `italics` (with an `s`). Referencing `.italic` will
cause a compile-time error.

**Passing a plain `Editor` when `UndoableEditor` is needed.**
When you supply a bare `Editor` to `EditableDocument.editor`, IME-originated
`EditRequest`s will be routed through it but the undo stack will not be
populated. Use `UndoableEditor` if undo is required.

**Mutating `MutableDocument` directly instead of via `Editor.submit`.**
Direct mutation bypasses reactions, listeners, and the undo stack. Always
submit an `EditRequest` through the editor.

**Forgetting to call `controller.notifyListeners()` after mutating
`ComposerPreferences`.**
`ComposerPreferences` is mutable in-place. The controller is not automatically
notified when you call `prefs.activate()` or `prefs.toggle()`. Call
`controller.notifyListeners()` manually, or trigger a selection change that
will cause the controller to rebuild the toolbar.
