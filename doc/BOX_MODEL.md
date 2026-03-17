# Flutter Block-Based WYSIWYG Editor — Implementation Spec

## Goal
Build a lazy-loading, block-based rich text WYSIWYG editor in Dart/Flutter, similar in API feel to `EditableText`/`TextField`, but with block-level granularity and viewport-driven lazy rendering.

---

## Architecture Overview

```
DocumentController
    └── BlockList (ordered)
            └── BlockNode           ← data/model layer
                    └── InlineSpan[]
ScrollViewport
    └── BlockViewportSlice[]        ← layout/lazy layer
            └── BlockRenderObject   ← render/paint layer
                    └── LineBox[]   ← computed, cached
```

---

## Core Data Models

### `BlockType`
```dart
enum BlockType { paragraph, heading1, heading2, heading3, bulletList, orderedList, blockquote, code, divider, embed }
```

### `BlockNode`
```dart
class BlockNode {
  final String id;                          // stable UUID
  final BlockType type;
  final int version;                        // for OT/CRDT
  final List<InlineSpan> spans;
  final Map<String, dynamic> attrs;         // e.g. {level: 2, listIndex: 3}
  final bool isLoaded;
  final Future<BlockNode> Function()? loader; // null if already loaded
  final int estimatedLineCount;             // hint for height estimation before load
}
```

### `InlineSpan`
```dart
class InlineSpan {
  final String text;
  final TextStyle style;
  final String? linkHref;
  final String? annotationId;
  final InlineEmbed? embed;         // image, mention, emoji — treated as 0-char span
  final int offsetStart;            // char offset within parent block
  final int offsetEnd;
}
```

### `InlineEmbed`
```dart
class InlineEmbed {
  final String type;                // 'image' | 'mention' | 'emoji'
  final Map<String, dynamic> data;
  final Size intrinsicSize;
  final VerticalAlignment alignment; // baseline | middle | top
}
```

---

## Layout Layer

### `LineBox` (computed, never serialised)
```dart
class LineBox {
  final int lineIndex;
  final List<InlineFragment> fragments;
  final double baseline;
  final double ascent;
  final double descent;
  final Rect bounds;                // local to block
  final TextDirection direction;

  TextPosition getPositionForOffset(Offset localOffset);
  List<TextBox> getBoxesForRange(int start, int end);
}
```

### `BlockRenderObject`
```dart
class BlockRenderObject {
  EdgeInsets margin;
  EdgeInsets padding;
  BoxConstraints constraints;
  double? fixedHeight;              // void blocks (divider, full-image)

  List<LineBox>? _lineBoxCache;
  double? _cachedWidth;             // invalidate on viewport width change

  void layout(BoxConstraints constraints);
  void paint(Canvas canvas, Offset offset);
  void paintCursor(Canvas canvas, TextPosition position);
  void paintSelection(Canvas canvas, TextSelection selection);
  TextPosition? hitTest(Offset globalOffset);
}
```

**Implementation note:** Drive `dart:ui` `ParagraphBuilder` + `Paragraph` directly (not `RenderParagraph`) to get per-`LineBox` control for selection painting, decorations, and cache eviction.

---

## Lazy Rendering Layer

### `BlockViewportSlice`
```dart
class BlockViewportSlice {
  final String blockId;
  final double estimatedHeight;     // used before layout; base on estimatedLineCount * lineHeight
  double? measuredHeight;           // set after inflate()
  bool isInViewport;
  bool isLayoutDirty;
  bool isContentLoaded;

  Future<void> inflate();           // load content + run layout, called as block enters viewport
  void deflate({bool keepModel = true}); // evict LineBox cache when far off-screen
}
```

### Viewport Lifecycle
1. Slices are created for all blocks with `estimatedHeight` only.
2. As user scrolls, slices entering a **preload buffer** (e.g. 2× viewport height) call `inflate()`.
3. `inflate()` triggers `loader()` if `!isContentLoaded`, then runs `BlockRenderObject.layout()`.
4. Slices exiting the buffer call `deflate()` — evicts `LineBox` cache, optionally keeps `BlockNode`.
5. On width change (rotation, resize), mark all loaded slices `isLayoutDirty = true`, re-layout on next scroll pass.

---

## Document & Selection

### `DocumentController`
```dart
class DocumentController extends ChangeNotifier {
  final List<BlockNode> blocks;
  DocumentSelection? selection;

  void insertText(String text);
  void deleteRange(DocumentRange range);
  void applyStyle(TextStyle style, DocumentRange range);
  void insertBlock(BlockNode block, {required int afterIndex});
  void deleteBlock(String blockId);
  void splitBlock(String blockId, int atOffset);
  void mergeBlocks(String blockIdA, String blockIdB);
}
```

### `DocumentSelection`
```dart
class DocumentSelection {
  final DocumentPosition base;
  final DocumentPosition extent;
}

class DocumentPosition {
  final String blockId;
  final int offset;                 // char offset within block
}
```

**Key rule:** Each `BlockRenderObject` only handles selection painting for its own local range. `DocumentController` maps the document-level `DocumentSelection` to per-block `TextSelection` ranges.

---

## Block Box Model (CSS analogy)

| CSS concept | Flutter equivalent |
|---|---|
| `display: block` | `BlockRenderObject` in a `Column`-like scroll list |
| `<span>` / inline flow | `InlineSpan[]` → `ParagraphBuilder` runs |
| Line box | `LineBox` (computed from `Paragraph.getLineBoundaries`) |
| `vertical-align` (inline embed) | `PlaceholderAlignment` in `ParagraphBuilder.addPlaceholder` |
| `overflow: hidden` + lazy | `BlockViewportSlice.deflate()` |
| Block margin collapse | Handle explicitly in viewport slice spacing |

---

## Void Blocks
Blocks with no inline flow (e.g. `divider`, standalone `embed`):
- Skip `ParagraphBuilder` entirely.
- `fixedHeight` set directly on `BlockRenderObject`.
- No caret entry; arrow keys skip over them.
- Hit test returns `null` (editor handles navigation around them).

---

## Key Implementation Notes

- **Height estimation:** `estimatedHeight = estimatedLineCount * defaultLineHeight + verticalPadding`. Store `estimatedLineCount` in serialised block data.
- **Cache invalidation triggers:** viewport width change, span edit, embed resize, style change.
- **Cursor ownership:** only the block containing `DocumentController.selection.extent` paints a cursor.
- **Soft vs hard newlines:** soft wrap = `LineBox` boundary (layout only); hard newline = new `BlockNode`.
- **IME / composing region:** track composing range at document level, pass to the active block's `TextInputConnection`.
- **Undo/Redo:** operate on `BlockNode` snapshots; avoid storing `LineBox` state in history.
- **Accessibility:** each `BlockRenderObject` should provide a `SemanticsNode` with full plain-text content regardless of lazy state.