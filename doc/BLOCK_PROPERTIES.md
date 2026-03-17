# Block Editor — Style Property Hierarchy

Inspired by Excalidraw's `_ExcalidrawElementBase` pattern:
a **shared base** holds identity/versioning, then each level adds only what it owns.
All properties are **JSON-serialisable, no computed state**.
Inheritance is resolved at render time: `span → block → style → document defaults`.

---

## Level 0 — Document Defaults (`DocumentStyle`)

The root cascade source. Every other level inherits from this unless overridden.

```dart
class DocumentStyle {
  // Page / canvas geometry
  final double pageWidth;           // pt — content column width
  final double marginTop;
  final double marginBottom;
  final double marginLeft;          // also the gutter edge
  final double marginRight;

  // Gutter / line numbers
  final bool showLineNumbers;
  final double gutterWidth;         // 0 = no gutter
  final TextStyle gutterTextStyle;
  final Color gutterBackground;

  // Default text baseline (all blocks inherit unless overridden)
  final String fontFamily;
  final double fontSize;            // pt
  final double lineHeight;          // multiplier, e.g. 1.4
  final Color textColor;
  final Color pageBackground;

  // Global spacing rhythm (used as default block spacing)
  final double defaultSpacingUnit;  // e.g. 8px — blocks multiply this
}
```

---

## Level 1 — Block Style (`BlockStyle`)

Applied per block node. Inherits unset fields from `DocumentStyle`.
Models the **CSS block formatting context**: spacing, indent, border, background.

```dart
class BlockStyle {
  // ── Spacing (CSS margin / padding) ──────────────────────────
  final double? spaceBefore;        // top margin  (null = inherit)
  final double? spaceAfter;         // bottom margin
  final double? paddingTop;         // inner top (e.g. for callout blocks)
  final double? paddingBottom;

  // ── Indentation ─────────────────────────────────────────────
  final double? indentLeft;         // left margin offset (list nesting, blockquote)
  final double? indentRight;        // right margin offset
  final double? firstLineIndent;    // positive = indent, negative = hanging
  // Note: hanging = firstLineIndent < 0, with indentLeft absorbing the overhang

  // ── Alignment ───────────────────────────────────────────────
  final TextAlign? textAlign;       // left | right | center | justify
  final double? tabSize;            // for code blocks

  // ── Border (all four sides, like CSS border-*) ───────────────
  final BorderSide? borderTop;
  final BorderSide? borderBottom;
  final BorderSide? borderLeft;     // e.g. thick left = blockquote bar
  final BorderSide? borderRight;
  final double? borderRadius;

  // ── Background ──────────────────────────────────────────────
  final Color? backgroundColor;     // null = transparent / inherit

  // ── Line height override ─────────────────────────────────────
  final double? lineHeight;         // multiplier; null = inherit from document

  // ── Numbering / list ────────────────────────────────────────
  final ListStyle? listStyle;       // bullet | decimal | alpha | roman | none
  final int? listLevel;             // nesting depth
  final int? listStartAt;           // override counter start

  // ── Block-level visibility ───────────────────────────────────
  final bool keepWithNext;          // no page-break between this and next block
  final bool keepTogether;          // no page-break within this block
}

class BorderSide {
  final Color color;
  final double width;
  final BorderStyle style;          // solid | dashed | dotted | none
}

enum ListStyle { none, bullet, decimal, lowerAlpha, upperAlpha, lowerRoman, upperRoman }
```

---

## Level 2 — Inline Span Style (`SpanStyle`)

Applied per `InlineSpan`. Inherits unset fields from the parent `BlockStyle` / `DocumentStyle`.
Models the **CSS inline formatting context**: font, decoration, colour, spacing.

```dart
class SpanStyle {
  // ── Font ─────────────────────────────────────────────────────
  final String? fontFamily;         // null = inherit
  final double? fontSize;           // pt; null = inherit
  final FontWeight? fontWeight;     // w100–w900
  final FontStyle? fontStyle;       // normal | italic
  final FontVariant? fontVariant;   // normal | smallCaps

  // ── Spacing ──────────────────────────────────────────────────
  final double? letterSpacing;      // pt (kerning offset)
  final double? wordSpacing;        // pt
  final double? baselineShift;      // pt — superscript/subscript (+/-)

  // ── Colour ───────────────────────────────────────────────────
  final Color? color;               // foreground; null = inherit
  final Color? backgroundColor;     // highlight; null = transparent

  // ── Decoration ───────────────────────────────────────────────
  final TextDecoration? decoration;         // underline | overline | lineThrough | none
  final Color? decorationColor;
  final TextDecorationStyle? decorationStyle; // solid | dashed | dotted | wavy | double
  final double? decorationThickness;

  // ── Case / transform ─────────────────────────────────────────
  final TextTransform? textTransform; // none | uppercase | lowercase | capitalize

  // ── Link / annotation ────────────────────────────────────────
  final String? linkHref;
  final String? annotationId;       // comment / suggestion anchor
  final SpanRole? role;             // null | code | mention | hashtag | emoji
}

enum TextTransform { none, uppercase, lowercase, capitalize }
enum FontVariant    { normal, smallCaps }
enum SpanRole       { code, mention, hashtag, emoji }
```

---

## Inheritance Resolution (at render time)

```
resolved(property) =
    spanStyle[property]
    ?? blockStyle[property]
    ?? namedStyle[property]        // e.g. "Heading 1" style sheet
    ?? documentStyle[property]
    ?? hardcodedDefault
```

Named styles (`StyleSheet`) are an optional map of `String → BlockStyle + SpanStyle` pairs (like Word paragraph styles), applied before document defaults:

```dart
class StyleSheet {
  final String name;                // "Heading 1", "Body", "Code Block"
  final BlockStyle block;
  final SpanStyle span;
  final String? basedOn;           // inherit from another named style
}
```

---

## Excalidraw Pattern Mapping

| Excalidraw concept         | Block editor equivalent                    |
|----------------------------|--------------------------------------------|
| `_ExcalidrawElementBase`   | Shared `id / version / type` on `BlockNode`|
| `strokeColor / fillStyle`  | `BorderSide / backgroundColor` on `BlockStyle` |
| `fontSize / fontFamily`    | `SpanStyle.fontSize / fontFamily`          |
| `textAlign`                | `BlockStyle.textAlign`                     |
| `opacity`                  | `SpanStyle.color` with alpha               |
| `groupIds`                 | `BlockNode.parentId` (nested blocks)       |
| `isDeleted`                | `BlockNode.isDeleted` (soft delete for OT) |
| `version / versionNonce`   | `BlockNode.version` for CRDT merge         |
| AppState (canvas-level)    | `DocumentStyle` (document-level defaults)  |