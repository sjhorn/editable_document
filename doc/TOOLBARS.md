# Toolbars, Property Panels, and Keyboard Handling — Design Document

## Motivation

The example app contains ~4,800 lines of toolbar, property panels, document settings, table toolbar, context menus, status bar, and JSON serialization — all of which should be reusable core library widgets. Users who adopt `editable_document` today must reimplement this UI from scratch or copy-paste from the example.

Additionally, `DocumentKeyboardHandler` uses raw `KeyEvent` dispatch instead of Flutter's `Shortcuts`/`Actions` system. This means keyboard shortcuts are not discoverable, not overridable from parent widgets, and not composable with the rest of the Flutter framework.

This document describes the migration of all example-app UI into the core library and the adoption of Flutter-idiomatic patterns throughout.

---

## Design principles

1. **Mirror Flutter's EditableText patterns exactly** — `DefaultTextEditingShortcuts`, `text_editing_intents.dart`, `EditableTextState._actions`, `contextMenuBuilder`. If Flutter has a convention, we follow it.

2. **Composable, not monolithic** — Individual toolbar bar widgets (`DocumentFormattingBar`, `DocumentBlockTypeBar`, etc.) that users arrange however they want. A default composed `DocumentToolbar` is provided for convenience.

3. **Both building blocks and composed defaults** — Property editors are individual widgets (`TextAlignmentEditor`, `SpacingEditor`, etc.) AND a default `DocumentPropertyPanel` that auto-selects visible editors based on the selected node type.

4. **Full theme system** — `DocumentTheme`, `DocumentToolbarTheme`, `PropertyPanelTheme`, and `DocumentDecoration` as `InheritedTheme` widgets, following Flutter's `InputDecoration` / `InputDecorationTheme` pattern.

5. **Actions call methods on EditableDocumentState** — Matching how Flutter's `EditableTextState` mediates between `Actions` and the text editing system. The state object owns the logic; Actions are thin wrappers.

6. **Zero external dependencies** — Flutter SDK only (merger prerequisite).

---

## Architecture: Shortcuts / Actions / Intents

### How Flutter does it

Flutter's text editing keyboard handling works in two layers:

```
WidgetsApp
  DefaultTextEditingShortcuts        ← Shortcuts widget with platform maps
    ...                                 (SingleActivator → Intent)
      EditableTextState.build()
        Actions(actions: _actions)   ← Map<Type, Action<Intent>>
          Focus(...)
            RenderEditable
```

`DefaultTextEditingShortcuts` maps platform-specific key combos to Intent classes defined in `text_editing_intents.dart`. `EditableTextState._actions` provides `Action` handlers for each Intent. Actions are wrapped with `Action.overridable()` so parent widgets can intercept them.

### How editable_document will do it

```
MaterialApp (provides DefaultTextEditingShortcuts)
  ...
    DefaultDocumentEditingShortcuts   ← Additional shortcuts for document ops
      EditableDocumentState.build()
        Actions(actions: _actions)    ← Handles BOTH Flutter intents AND our intents
          Focus(focusNode: ...)
            DocumentSemanticsScope
              DocumentLayout
```

**Key insight:** Flutter's `DefaultTextEditingShortcuts` is already in the tree (from `MaterialApp`). It maps standard keys (arrows, delete, Home/End, Cmd+C/V/X/A, Cmd+Z) to Flutter's built-in Intent classes. We reuse those intents and provide our own `Action` handlers for them.

`DefaultDocumentEditingShortcuts` only needs to add document-specific shortcuts:
- `Cmd/Ctrl+B` → `ToggleAttributionIntent(NamedAttribution.bold)`
- `Cmd/Ctrl+I` → `ToggleAttributionIntent(NamedAttribution.italics)`
- `Cmd/Ctrl+U` → `ToggleAttributionIntent(NamedAttribution.underline)`
- `Cmd/Ctrl+Shift+Z` → `RedoTextIntent()` (macOS needs explicit Shift mapping)

### Intent classes

**Reused from Flutter** (no new code needed):
| Intent | Operation |
|--------|-----------|
| `DeleteCharacterIntent` | Delete/Backspace |
| `ExtendSelectionByCharacterIntent` | Arrow keys |
| `ExtendSelectionToNextWordBoundaryIntent` | Option/Ctrl+Arrow |
| `ExtendSelectionToLineBreakIntent` | Cmd/Alt+Arrow (line) |
| `ExpandSelectionToDocumentBoundaryIntent` | Cmd/Alt+Up/Down |
| `ExtendSelectionVerticallyToAdjacentLineIntent` | Up/Down arrows |
| `ExtendSelectionByPageIntent` | Page Up/Down |
| `SelectAllTextIntent` | Cmd/Ctrl+A |
| `CopySelectionTextIntent` | Cmd/Ctrl+C |
| `PasteTextIntent` | Cmd/Ctrl+V |
| `UndoTextIntent` | Cmd/Ctrl+Z |
| `RedoTextIntent` | Cmd/Ctrl+Shift+Z |

**New document-specific intents** (`lib/src/widgets/document_editing_intents.dart`):

| Intent | Operation |
|--------|-----------|
| `ToggleAttributionIntent` | Bold, italic, underline, strikethrough, code |
| `ClearFormattingIntent` | Remove all inline attributions |
| `ConvertToParagraphIntent` | Convert block to paragraph |
| `ConvertToBlockquoteIntent` | Convert to blockquote |
| `ConvertToCodeBlockIntent` | Convert to code block |
| `ConvertToListItemIntent` | Convert to ordered/unordered list |
| `ChangeTextAlignIntent` | Set text alignment |
| `IndentListItemIntent` | Indent list item |
| `UnindentListItemIntent` | Unindent list item |
| `InsertHorizontalRuleIntent` | Insert HR |
| `InsertImageIntent` | Insert image block |
| `InsertTableIntent` | Insert table |
| `MoveToNodeBoundaryIntent` | Option/Ctrl+Up/Down (node start/end) |
| `MoveToAdjacentTableCellIntent` | Tab/Shift+Tab in tables |
| `CollapseSelectionIntent` | Escape key |
| `InsertTableRowIntent` | Table context: insert row |
| `InsertTableColumnIntent` | Table context: insert column |
| `DeleteTableRowIntent` | Table context: delete row |
| `DeleteTableColumnIntent` | Table context: delete column |
| `DeleteTableIntent` | Table context: delete table |

### Action wiring

`EditableDocumentState._actions` provides handlers for all intents:

```dart
late final Map<Type, Action<Intent>> _actions = {
  // Flutter intents — our document-aware implementations
  DeleteCharacterIntent: _makeOverridable(
    _DocumentDeleteAction<DeleteCharacterIntent>(state: this),
  ),
  ExtendSelectionByCharacterIntent: _makeOverridable(
    _DocumentMoveAction<ExtendSelectionByCharacterIntent>(state: this),
  ),
  // ... more Flutter intents

  // Document-specific intents
  ToggleAttributionIntent: _makeOverridable(
    _ToggleAttributionAction(state: this),
  ),
  ConvertToParagraphIntent: _makeOverridable(
    _ConvertBlockAction<ConvertToParagraphIntent>(state: this),
  ),
  // ... more document intents
};
```

Each action calls a public method on `EditableDocumentState`:

```dart
// Public methods on EditableDocumentState — usable from Actions,
// toolbar buttons, and external code.
void toggleAttribution(Attribution attribution) { ... }
void changeBlockType(ParagraphBlockType? type) { ... }
void convertToBlockquote() { ... }
void insertHorizontalRule() { ... }
// etc.
```

This matches Flutter's pattern where `EditableTextState` exposes methods like `copySelection()`, `cutSelection()`, `pasteText()` that are called by both Actions and toolbar buttons.

---

## Composable toolbar widgets

### Atomic building blocks

Small reusable widgets extracted from the example app:

| Widget | File | Purpose |
|--------|------|---------|
| `DocumentFormatToggle` | `toolbar/document_format_toggle.dart` | Toggle button with active state |
| `DocumentColorPicker` | `toolbar/document_color_picker.dart` | Popup color selector with presets |
| `TableSizePicker` | `toolbar/table_size_picker.dart` | Interactive grid size picker |
| `DimensionField` | `toolbar/dimension_field.dart` | Numeric input with "auto" placeholder |
| `UrlField` | `toolbar/url_field.dart` | URL text input |
| `BorderColorButton` | `toolbar/border_color_button.dart` | Small color swatch button |

### Composed toolbar bars

Each bar is an independent widget taking `controller` + `editor`:

| Widget | Contents |
|--------|----------|
| `DocumentFormattingBar` | Bold, italic, underline, strikethrough, code |
| `DocumentBlockTypeBar` | Paragraph, blockquote, code, bullet, numbered |
| `DocumentAlignmentBar` | Left, center, right, justify |
| `DocumentInsertBar` | Horizontal rule, image, table |
| `DocumentFontBar` | Font family + size dropdowns |
| `DocumentColorBar` | Text color + background color pickers |
| `DocumentUndoRedoBar` | Undo, redo |
| `DocumentListIndentBar` | Indent, unindent |

### Default composed toolbar

```dart
DocumentToolbar(
  controller: myController,
  editor: myEditor,
  // Optional: hide/show sections
  showFileActions: false,
  trailing: [MyCustomButton()],
)
```

Internally composes all bars with `VerticalDivider` separators, respecting `DocumentToolbarTheme`.

### Usage patterns

```dart
// Option A: Use the default toolbar
DocumentToolbar(controller: c, editor: e)

// Option B: Compose your own
Row(children: [
  DocumentFormattingBar(controller: c, editor: e),
  VerticalDivider(),
  DocumentBlockTypeBar(controller: c, editor: e),
  Spacer(),
  DocumentUndoRedoBar(editor: e),
])

// Option C: Use Actions directly — buttons that auto-wire
ElevatedButton(
  onPressed: () => Actions.invoke(context, ToggleAttributionIntent(NamedAttribution.bold)),
  child: Text('Bold'),
)
```

---

## Property editors

### Building blocks

Individual stateless editor widgets in `lib/src/widgets/properties/`:

| Widget | Edits |
|--------|-------|
| `TextAlignmentEditor` | `TextAlign` via segmented buttons |
| `LineHeightEditor` | `double?` via dropdown presets |
| `SpacingEditor` | `spaceBefore` / `spaceAfter` via dimension fields |
| `BlockBorderEditor` | `BlockBorder?` — style, width, color |
| `IndentEditor` | `indentLeft`, `indentRight`, `firstLineIndent` |
| `BlockAlignmentEditor` | `BlockAlignment` via segmented buttons |
| `TextWrapEditor` | `TextWrapMode` via segmented buttons |
| `BlockDimensionEditor` | `BlockDimension?` width/height with px/% toggle |
| `ImagePropertiesEditor` | URL, lock aspect, file picker callback |

Each editor takes a `value` and `onChanged` callback — pure functional pattern. No dependency on `Editor` or `DocumentEditingController`.

### Default panel

```dart
DocumentPropertyPanel(
  controller: myController,
  editor: myEditor,
  width: 280.0,
)
```

Auto-selects visible editors based on the selected node type:
- **ParagraphNode / ListItemNode**: text align, line height, spacing, border, indent
- **BlockquoteNode / CodeBlockNode**: + block alignment, text wrap, dimensions
- **ImageNode**: + image URL, lock aspect, file picker
- **HorizontalRuleNode**: spacing, border, block alignment, dimensions
- **TableNode**: spacing, border

---

## Theme system

### DocumentTheme

The top-level theme carrying all document styling defaults:

```dart
DocumentTheme(
  data: DocumentThemeData(
    defaultTextStyle: TextStyle(fontSize: 16, height: 1.5),
    defaultBlockSpacing: 12.0,
    heading1Style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    codeBlockStyle: TextStyle(fontFamily: 'Courier New'),
    codeBlockBackgroundColor: Color(0xFFF5F5F5),
    caretColor: Colors.blue,
    selectionColor: Colors.blue.withValues(alpha: 0.3),
    toolbarTheme: DocumentToolbarThemeData(...),
    propertyPanelTheme: PropertyPanelThemeData(...),
  ),
  child: myDocumentWidget,
)
```

Accessed via `DocumentTheme.of(context)` — follows Flutter's `Theme.of(context)` pattern.

### DocumentToolbarTheme

```dart
DocumentToolbarThemeData(
  backgroundColor: Colors.white,
  borderSide: BorderSide(color: Colors.grey.shade300),
  iconSize: 20.0,
  activeColor: Colors.blue,
  dividerColor: Colors.grey.shade300,
)
```

### PropertyPanelTheme

```dart
PropertyPanelThemeData(
  backgroundColor: Colors.grey.shade50,
  width: 280.0,
  sectionLabelStyle: TextStyle(fontWeight: FontWeight.w600),
)
```

### DocumentDecoration

Like `InputDecoration` for `DocumentField`:

```dart
DocumentField(
  controller: myController,
  decoration: DocumentDecoration(
    border: OutlineInputBorder(),
    showToolbar: true,
    showPropertyPanel: false,
    showStatusBar: true,
  ),
)
```

---

## Document settings

```dart
DocumentSettingsPanel(
  blockSpacing: 12.0,
  onBlockSpacingChanged: (v) => setState(() => _spacing = v),
  defaultLineHeight: null,
  onDefaultLineHeightChanged: (v) => ...,
  documentPadding: EdgeInsets.all(24),
  onDocumentPaddingChanged: (v) => ...,
  showLineNumbers: false,
  onShowLineNumbersChanged: (v) => ...,
  // ... line number styling callbacks
)
```

---

## Context menus

Following Flutter's `contextMenuBuilder` pattern:

```dart
DocumentField(
  controller: myController,
  contextMenuBuilder: (context, primaryAnchor, controller, editor) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: TextSelectionToolbarAnchors(primaryAnchor: primaryAnchor),
      buttonItems: defaultDocumentContextMenuButtonItems(
        controller: controller,
        editor: editor,
      ),
    );
  },
)
```

Default menu items: Cut, Copy, Paste, Select All — matching Flutter's `EditableText` defaults.

---

## Status bar

```dart
DocumentStatusBar(
  controller: myController,
  showBlockCount: true,
  showWordCount: true,
  showCharCount: true,
  showCurrentBlockType: true,
)
```

Utility functions exposed for custom status bars:
```dart
int documentWordCount(Document document);
int documentCharCount(Document document);
```

---

## JSON serialization

```dart
const serializer = DocumentJsonSerializer();

// Save
final json = serializer.toJson(document);
final encoded = jsonEncode(json);

// Load
final decoded = jsonDecode(encoded) as Map<String, Object?>;
final nodes = serializer.fromJson(decoded);
final document = MutableDocument(nodes: nodes);
```

Round-trips all node types, attributions, `BlockDimension` (px/%), borders, alignment, spacing.

---

## Migration from DocumentKeyboardHandler

`DocumentKeyboardHandler` is removed. All its logic moves into:

1. **Flutter's `DefaultTextEditingShortcuts`** (already in tree) — standard keybindings
2. **`DefaultDocumentEditingShortcuts`** — document-specific keybindings
3. **`EditableDocumentState._actions`** — action handlers for all intents
4. **`EditableDocumentState` public methods** — the actual logic

Before:
```dart
final handler = DocumentKeyboardHandler(
  document: controller.document,
  controller: controller,
  requestHandler: editor.submit,
);
Focus(onKeyEvent: (_, event) => handler.onKeyEvent(event) ? ... : ...)
```

After:
```dart
// Nothing — it's automatic.
// DefaultDocumentEditingShortcuts + Actions are in the build tree.
// Override any action from a parent widget:
Actions(
  actions: {
    ToggleAttributionIntent: CallbackAction<ToggleAttributionIntent>(
      onInvoke: (intent) { /* custom logic */ },
    ),
  },
  child: EditableDocument(...),
)
```

The `PageMoveResolver`, `VerticalMoveResolver`, and `LineMoveResolver` typedefs remain — they are used internally by `EditableDocumentState` to resolve visual-line and page movements.

---

## Phasing

| Phase | What | Status |
|-------|------|--------|
| **1a** | Intent classes | Done |
| **1b** | Actions on EditableDocumentState | |
| **1c** | DefaultDocumentEditingShortcuts | |
| **1d** | Wire into EditableDocument, remove DocumentKeyboardHandler | |
| **2a** | DocumentToolbarTheme | |
| **2b** | Atomic toolbar widgets | |
| **2c** | Composed toolbar bars + DocumentToolbar | |
| **3a** | Individual property editors | |
| **3b** | DocumentPropertyPanel | |
| **4a** | DocumentTheme | |
| **4b** | PropertyPanelTheme | |
| **4c** | DocumentDecoration | |
| **4d** | Wire themes into widgets | |
| **5** | DocumentSettingsPanel | |
| **6a** | Default context menu builder | |
| **6b** | Table context toolbar | |
| **6c** | Status bar | |
| **6d** | JSON serializer | |
| **7** | Example app becomes thin shell | |

Execution order respects layer dependencies: intents/actions first, then toolbar widgets, then property editors, then themes, then everything else. The example app is rewritten last.

---

## Example app after migration

~200 lines:

```dart
class DocumentDemo extends StatefulWidget { ... }

class _DocumentDemoState extends State<DocumentDemo> {
  late final _document = _buildSampleDocument();
  late final _controller = DocumentEditingController(document: _document);
  late final _editor = UndoableEditor(controller: _controller);
  late final _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return DocumentTheme(
      data: DocumentThemeData(
        codeBlockStyle: TextStyle(fontFamily: 'Courier New'),
      ),
      child: Scaffold(
        body: Column(children: [
          DocumentToolbar(controller: _controller, editor: _editor),
          Expanded(child: Row(children: [
            Expanded(child: DocumentScrollable(
              controller: _controller,
              layoutKey: _layoutKey,
              child: DocumentLayout(
                key: _layoutKey,
                document: _controller.document,
                controller: _controller,
                componentBuilders: defaultComponentBuilders,
              ),
            )),
            DocumentPropertyPanel(
              controller: _controller,
              editor: _editor,
            ),
          ])),
          DocumentStatusBar(controller: _controller),
        ]),
      ),
    );
  }
}
```
