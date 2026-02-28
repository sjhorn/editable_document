# editable_document — ROADMAP

**Package:** `editable_document` · [pub.dev](https://pub.dev/packages/editable_document) · [GitHub](https://github.com/sjhorn/editable_document)  
**Goal:** A drop-in replacement for Flutter's `EditableText`/`TextField` with full block-level document model support, targeting eventual merge into the Flutter framework.  
**Architecture principle:** `EditableDocument` is to block documents what `EditableText` is to single-field text.

---

## Guiding constraints

- Zero external dependencies beyond the Flutter SDK (merger prerequisite).
- Every phase is committed when all its checkboxes pass: TDD red → green → refactor → commit.
- Each commit is small and self-contained (Flutter tree-hygiene rule).
- Flutter's strict analysis options apply from day one (`strict-casts`, `strict-inference`, `strict-raw-types`, page width 100).
- `public_member_api_docs` is enforced: every exported symbol must have `///` dartdoc.
- Test coverage ≥ 90 % overall; 100 % on key paths (IME bridge, document mutation, selection model).
- Platform targets: **iOS · Android · Web · macOS · Windows · Linux** (all six from Phase 1).

---

## Phase 0 — Repository & tooling bootstrap

> **Commit message:** `chore: bootstrap editable_document package skeleton`

### 0.1 Package skeleton
- [ ] `flutter create --template=package editable_document` with `sdk: ">=3.3.0 <4.0.0"`.
- [ ] `pubspec.yaml` — name, description, homepage, repository, issue_tracker, topics set.
- [ ] `LICENSE` — BSD-3-Clause (matches Flutter).
- [ ] `CHANGELOG.md` — `## 0.1.0-dev.1` stub.
- [ ] `README.md` — package purpose, badges (pub version, CI, coverage), quickstart stub.

### 0.2 Analysis & linting
- [ ] `analysis_options.yaml` matching Flutter's framework options:
  - `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`
  - `page_width: 100`
  - Enabled rules: `always_declare_return_types`, `avoid_dynamic_calls`, `avoid_print`, `flutter_style_todos`, `prefer_const_constructors`, `prefer_relative_imports`, `prefer_single_quotes`, `sort_child_properties_last`, `use_key_in_widget_constructors`, `use_super_parameters`, `missing_code_block_language_in_doc_comment`, `public_member_api_docs`, `diagnostic_describe_all_properties`.
- [ ] `dart format` passes with `--line-length 100`.
- [ ] `flutter analyze` produces zero issues.

### 0.3 CI pipeline (GitHub Actions)
- [ ] `.github/workflows/ci.yml` — triggered on push + pull_request to `main`.
  - Jobs: `analyze`, `test` (unit + widget), `integration_test` (matrix: ubuntu, macos, windows), `golden_test`, `coverage`, `docs`.
- [ ] Coverage threshold gate: fail if overall < 90 %.
- [ ] Golden files committed to `test/goldens/` with platform-tagged suffixes.
- [ ] `dart doc` build step — fail on any undocumented public API.

### 0.4 Developer tooling
- [ ] `.claude/settings.local.json` — AI agent configuration (see CLAUDE.md Phase 0).
- [ ] `CLAUDE.md` committed at repo root.
- [ ] `Makefile` with targets: `analyze`, `test`, `golden-update`, `coverage`, `docs`, `benchmark`.
- [ ] `.github/PULL_REQUEST_TEMPLATE.md` mirroring Flutter's checklist.
- [ ] `.github/ISSUE_TEMPLATE/bug_report.md` and `feature_request.md`.

---

## Phase 1 — Document model (the data layer)

> **Commit message:** `feat(model): introduce DocumentNode, Document, DocumentPosition, DocumentSelection`

All Phase 1 code lives in `lib/src/model/`. Every class is tested in `test/src/model/` — write failing test first.

### 1.1 Core node types
- [ ] `DocumentNode` — abstract base with `String id` (UUID v4), `Map<String, dynamic> metadata`, copyWith, equality, `debugDescribeChildren`.
- [ ] `TextNode extends DocumentNode` — `AttributedText text`, typed-span attributions (bold, italic, underline, strikethrough, link, code, color, custom).
- [ ] `ParagraphNode extends TextNode` — metadata keys for `blockType` (paragraph, h1–h6, blockquote, code block).
- [ ] `ListItemNode extends TextNode` — `ListItemType` (ordered/unordered), `int indent`.
- [ ] `ImageNode extends DocumentNode` — `String imageUrl`, `String? altText`, `double? width`, `double? height`, `BinaryNodePosition` (upstream/downstream).
- [ ] `CodeBlockNode extends TextNode` — `String? language`, monospace attribution.
- [ ] `HorizontalRuleNode extends DocumentNode` — no content, `BinaryNodePosition`.
- [ ] `AttributedText` — `String text` + `SpanMarker` list for O(log n) attribution queries; `copyText(start, end)`, `insert`, `delete`, `applyAttribution`, `removeAttribution`.
- [ ] Tests: node creation, equality, copyWith, metadata round-trip, attribution overlap/merge/split for all node types.

### 1.2 Document container
- [ ] `Document` — immutable view: `List<DocumentNode> nodes`, `nodeById(String)`, `nodeAt(int)`, `nodeAfter`, `nodeBefore`, `getNodeIndexById`.
- [ ] `MutableDocument extends Document` — mutation: `insertNode`, `deleteNode`, `replaceNode`, `moveNode`, `updateNode`.
- [ ] `DocumentChangeEvent` — sealed class hierarchy: `NodeInserted`, `NodeDeleted`, `NodeReplaced`, `NodeMoved`, `TextChanged`.
- [ ] `ValueNotifier<List<DocumentChangeEvent>>` on `MutableDocument`.
- [ ] Tests: CRUD operations, ordering invariants, change event emission, empty document edge cases.

### 1.3 Position and selection model
- [ ] `NodePosition` — abstract marker interface.
- [ ] `TextNodePosition implements NodePosition` — `int offset`, `TextAffinity affinity`.
- [ ] `BinaryNodePosition implements NodePosition` — `BinaryNodePositionType` (upstream/downstream).
- [ ] `DocumentPosition` — `{String nodeId, NodePosition nodePosition}`, equality, `copyWith`.
- [ ] `DocumentSelection` — `{DocumentPosition base, DocumentPosition extent}`, `isCollapsed`, `isExpanded`, `affinity`, `normalize(Document)`, equality.
- [ ] Tests: collapsed/expanded detection, normalization across heterogeneous node types, equality semantics.

### 1.4 Document controller
- [ ] `DocumentEditingController extends ChangeNotifier` — analogous to `TextEditingController`:
  - `MutableDocument document`
  - `DocumentSelection? selection`
  - `ComposerPreferences preferences` (active attributions)
  - `setSelection`, `clearSelection`, `collapseSelection`
  - `buildNodeSpan(DocumentNode)` — analogous to `buildTextSpan`
- [ ] Tests: controller listeners fire on selection change, on document change, composer preferences round-trip.

---

## Phase 2 — Command pipeline & undo/redo

> **Commit message:** `feat(editor): event-sourced command pipeline with undo/redo`

### 2.1 Command architecture
- [ ] `EditRequest` — abstract marker (e.g., `InsertTextRequest`, `DeleteContentRequest`, `ReplaceNodeRequest`, `SplitParagraphRequest`, `MergeNodeRequest`, `MoveNodeRequest`, `ChangeBlockTypeRequest`, `ApplyAttributionRequest`, `RemoveAttributionRequest`).
- [ ] `EditCommand` — abstract with `execute(EditContext)` returning `List<DocumentChangeEvent>`.
- [ ] `EditContext` — `{MutableDocument document, MutableDocumentComposer composer}`.
- [ ] `Editor` — `submit(EditRequest)` maps request → command → executes → emits events → notifies reactions/listeners.
- [ ] `EditReaction` — fires additional requests in response to events (e.g., `SplitParagraphReaction` converting paragraphs on Enter).
- [ ] `EditListener` — `onEdit(List<DocumentChangeEvent>)` for UI rebuild.
- [ ] Tests: each request type produces correct events; reaction chaining; listener notification order; command failure leaves document unchanged.

### 2.2 Undo/redo
- [ ] `UndoableEditor extends Editor` — wraps commands with inverse command generation.
- [ ] `undo()`, `redo()`, `canUndo`, `canRedo`.
- [ ] Integration with `UndoHistory<DocumentEditingValue>` widget (matching `EditableText`'s pattern).
- [ ] Tests: undo/redo for each command type; undo stack cleared on non-undoable commands; boundary conditions (empty stack, max stack depth).

---

## Phase 3 — Rendering layer

> **Commit message:** `feat(rendering): RenderDocumentLayout, per-block RenderObject tree`

All render objects in `lib/src/rendering/`. Tests in `test/src/rendering/` using `TestRenderingFlutterBinding`.

### 3.1 Per-block render objects
- [ ] `RenderDocumentBlock` — abstract `RenderBox` base for all block types; defines `DocumentNodeId nodeId`, `DocumentSelection? nodeSelection`, `getLocalRectForPosition(NodePosition)`, `getPositionAtOffset(Offset)`, `getEndpointsForSelection(NodePosition base, NodePosition extent)`.
- [ ] `RenderTextBlock extends RenderDocumentBlock` — wraps `TextPainter`; renders `AttributedText` with selection highlight rectangles and cursor; handles `TextDirection`, `TextAlign`, `TextScaler`.
- [ ] `RenderParagraphBlock extends RenderTextBlock` — plus heading-level styles.
- [ ] `RenderListItemBlock extends RenderTextBlock` — plus bullet/number rendering at correct indent.
- [ ] `RenderImageBlock extends RenderDocumentBlock` — image sizing with `BinaryNodePosition` hit testing.
- [ ] `RenderCodeBlock extends RenderTextBlock` — monospace, background fill, line numbers (optional).
- [ ] `RenderHorizontalRuleBlock extends RenderDocumentBlock` — horizontal line with `BinaryNodePosition`.
- [ ] Tests: layout at various constraints, paint output via `TestCanvas`, hit testing accuracy, position-to-rect and rect-to-position round-trips.

### 3.2 Document layout render object
- [ ] `RenderDocumentLayout extends RenderBox with ContainerRenderObjectMixin` — vertical stack of `RenderDocumentBlock` children.
- [ ] `DocumentLayoutGeometry` — `getDocumentPositionAtOffset(Offset)`, `getRectForDocumentPosition(DocumentPosition)`, `getComponentByNodeId(String)`, `getDocumentPositionNearestToOffset(Offset)`.
- [ ] Scrollable viewport integration: accepts `ViewportOffset`, computes `maxScrollExtent`.
- [ ] Tests: intrinsic sizes, layout with mixed block types, hit testing delegated to correct child, scroll extent computation.

### 3.3 Caret and selection painting
- [ ] `DocumentSelectionPainter extends CustomPainter` — iterates nodes between base and extent; delegates selection rect computation to each `RenderDocumentBlock`; paints cross-block selection across multiple `RenderTextBlock` instances.
- [ ] `DocumentCaretPainter extends CustomPainter` — draws cursor rect from `RenderDocumentBlock.getLocalRectForPosition`; blink animation via `AnimationController`.
- [ ] Golden tests: cursor at line start/end/middle, selection spanning same paragraph, selection spanning multiple paragraphs, selection spanning text+image, RTL text cursor.

---

## Phase 4 — IME bridge

> **Commit message:** `feat(services): DocumentImeInputClient — IME virtualization bridge`

All IME code in `lib/src/services/`. This is the highest-risk phase; 100 % test coverage required on all paths.

### 4.1 DocumentImeSerializer
- [ ] `DocumentImeSerializer` — bidirectional serialization:
  - `Document + DocumentSelection → TextEditingValue` (single text node: full text; multi-node/non-text: synthetic minimal value).
  - `TextEditingValue + Document → DocumentSelection`.
  - `List<TextEditingDelta> + Document → List<EditRequest>` (delta → document mutations).
- [ ] Handle composing region within a `TextNodePosition`.
- [ ] Handle `\n` split (Android Enter via delta) → `SplitParagraphRequest`.
- [ ] Tests: serialization round-trips for each node type; delta→request mapping for insertion, deletion, replacement, non-text-update; composing region preserved through round-trip; empty document edge case.

### 4.2 DocumentImeInputClient
- [ ] `DocumentImeInputClient implements DeltaTextInputClient` — connection lifecycle:
  - `openConnection(TextInputConfiguration)` → `TextInput.attach(this, config)` with `enableDeltaModel: true`.
  - `closeConnection()` → `_inputConnection?.close()`.
  - `updateEditingValueWithDeltas(List<TextEditingDelta>)` → serialize → dispatch `EditRequest`s.
  - `performAction(TextInputAction)` → `onAction` callback.
  - `updateFloatingCursor(RawFloatingCursorPoint)` → iOS floating cursor state.
  - `insertContent(KeyboardInsertedContent)` → `InsertInlineContentRequest` (Android image/GIF).
  - `connectionClosed()` → notify composer.
  - `showKeyboard()` / `hideKeyboard()`.
- [ ] `syncToIme()` — push current `TextEditingValue` back to platform after document mutations.
- [ ] Tests: mock `SystemChannels.textInput`; verify outgoing calls (`setClient`, `setEditingState`, `show`, `hide`, `clearClient`); verify incoming calls route correctly; delta model enabled; floating cursor state machine.

### 4.3 Keyboard & shortcuts
- [ ] `DocumentKeyboardHandler` — `KeyEventResult onKeyEvent(FocusNode, KeyEvent)` — handles keys not covered by IME deltas (desktop arrow navigation, Home/End, Shift+arrow selection, Ctrl+arrow word navigation, Delete forward, Escape).
- [ ] `DefaultDocumentShortcuts` — extends `DefaultTextEditingShortcuts` with document-specific intents: `SplitBlockIntent`, `MergeBlockBackwardIntent`, `MergeBlockForwardIntent`, `IndentListItemIntent`, `UnindentListItemIntent`, `ToggleAttributionIntent`.
- [ ] Platform-specific mappings: macOS (Cmd), Windows/Linux (Ctrl), iOS/Android (no hardware shortcuts needed but handled gracefully).
- [ ] Tests: all intents dispatch correct `EditRequest`s; platform shortcut mapping verified for all six platforms; unknown keys pass through.

### 4.4 Autofill
- [ ] `DocumentAutofillClient implements AutofillClient` — single-text-node documents participate in autofill groups.
- [ ] `autofillHints` passed through `DocumentEditingController`.
- [ ] Tests: autofill connection established when `autofillHints` is set; `updateEditingStateWithTag` routes to correct node.

---

## Phase 5 — Widget layer

> **Commit message:** `feat(widgets): EditableDocument widget — drop-in for EditableText`

All widgets in `lib/src/widgets/`. Tests in `test/src/widgets/` using `testWidgets`.

### 5.1 Component builder system
- [ ] `ComponentBuilder` — abstract with `createViewModel(Document, DocumentNode)` and `createComponent(ComponentViewModel, ComponentContext)`.
- [ ] `ComponentViewModel` — abstract data class with `nodeId`, `selection`, `isSelected`.
- [ ] `ComponentContext` — `{Document, DocumentSelection?, ComponentBuilder, StyleSheet}`.
- [ ] Default builders: `ParagraphComponentBuilder`, `ListItemComponentBuilder`, `ImageComponentBuilder`, `CodeBlockComponentBuilder`, `HorizontalRuleComponentBuilder`.
- [ ] Tests: each builder returns non-null for its node type; returns null for other types; custom builder prepended to list takes precedence.

### 5.2 DocumentLayout widget
- [ ] `DocumentLayout extends StatefulWidget` — renders `RenderDocumentLayout` via `DocumentLayoutElement extends RenderObjectElement`.
- [ ] Responds to `Document` changes via `EditListener`.
- [ ] `GlobalKey<DocumentLayoutState>` exposes `documentPositionAtOffset`, `rectForDocumentPosition`, `componentForNode`.
- [ ] Tests: layout updates when document changes; correct component rendered for each node type; position queries delegated to render layer.

### 5.3 EditableDocument widget (the main deliverable)
- [ ] `EditableDocument extends StatefulWidget` — parameter surface mirrors `EditableText`:
  - `DocumentEditingController controller`
  - `FocusNode focusNode`
  - `TextStyle? style`
  - `StrutStyle? strutStyle`
  - `TextDirection? textDirection`
  - `TextAlign textAlign`
  - `bool readOnly`
  - `bool autofocus`
  - `TextInputAction textInputAction`
  - `TextInputType keyboardType`
  - `List<TextInputFormatter>? inputFormatters` (applied per text node)
  - `ValueChanged<String>? onChanged`
  - `ValueChanged<DocumentSelection?>? onSelectionChanged`
  - `VoidCallback? onEditingComplete`
  - `ValueChanged<String>? onSubmitted`
  - `ScrollController? scrollController`
  - `EdgeInsets scrollPadding`
  - `bool enableInteractiveSelection`
  - `TextMagnifierConfiguration? magnifierConfiguration`
  - `List<ComponentBuilder> componentBuilders`
  - `StyleSheet? stylesheet`
  - `List<EditReaction> reactions`
  - `bool enableDeltaModel` (default true)
- [ ] `EditableDocumentState` — five mixins analogous to `EditableTextState`: `AutomaticKeepAliveClientMixin`, `WidgetsBindingObserver`, `TickerProviderStateMixin`, `TextSelectionDelegate`, `DeltaTextInputClient`.
- [ ] Build tree (analogous to `EditableText`): `Actions` → `Focus` → `Scrollable` → `DocumentLayout` → `DocumentSelectionOverlay`.
- [ ] Tests: widget builds without error for each node type; focus/blur cycles open/close IME; readOnly blocks IME; autofocus works; scroll to caret on focus.

### 5.4 DocumentField widget (TextField equivalent)
- [ ] `DocumentField extends StatefulWidget` — wraps `EditableDocument` with decoration (`InputDecoration`), label, hint, prefix/suffix, error text.
- [ ] `_DocumentFieldState` delegates to `EditableDocumentState`.
- [ ] Tests: decoration renders; label animates on focus; error state shows; counter tracks document length.

---

## Phase 6 — Selection overlay & platform handles

> **Commit message:** `feat(widgets): cross-block selection overlay, platform handles, magnifier`

### 6.1 DocumentSelectionOverlay
- [ ] `DocumentSelectionOverlay` — manages `OverlayEntry`s for caret, handles, toolbar.
- [ ] Uses `LayerLink` pairs (start handle ↔ `CompositedTransformTarget` at selection start; end handle ↔ end) mirroring `TextSelectionOverlay`.
- [ ] `DocumentSelectionOverlayState.update(DocumentSelection?)` — recomputes positions from `DocumentLayout` geometry.
- [ ] Tests: overlay entries created on selection; removed on collapse; positions match render layer geometry (golden tests).

### 6.2 Caret overlay
- [ ] `CaretDocumentOverlay extends StatefulWidget` — `CustomPaint` with `DocumentCaretPainter`; blink via `AnimationController` with `_kCursorBlinkInterval = Duration(milliseconds: 500)` matching `EditableText`.
- [ ] Pause blink on key events; restart on idle.
- [ ] Integration test: caret visible after focus; blink animation runs; caret hidden in `readOnly`.

### 6.3 Desktop selection (mouse)
- [ ] `DocumentMouseInteractor` — `MouseRegion` + `GestureDetector`; tap → collapse to position; drag → extend selection; double-tap → word selection; triple-tap → block selection; Shift+click → extend.
- [ ] Tests: tap places caret at correct `DocumentPosition`; drag selects text; word/block selection boundaries correct.

### 6.4 iOS handles & magnifier
- [ ] `IosDocumentGestureController` — tap, double-tap, long-press, drag.
- [ ] `IOSCollapsedHandle`, `IOSSelectionHandle` — `GestureDetector` on `CustomPaint` handle widgets; drag updates selection via `DocumentLayout.getDocumentPositionAtOffset`.
- [ ] `IOSDocumentMagnifier` — `TextMagnifier`-equivalent; shows on long-press and handle drag; hides on release.
- [ ] Integration tests: handle positions correct after selection; magnifier appears on long-press; selection extends on handle drag.

### 6.5 Android handles & magnifier
- [ ] `AndroidDocumentGestureController` — tap, double-tap, long-press, drag with velocity.
- [ ] `AndroidSelectionHandle`, `AndroidDocumentCaret`.
- [ ] `AndroidDocumentMagnifier`.
- [ ] Integration tests: mirrors iOS test coverage for Android gesture set.

### 6.6 Floating toolbar
- [ ] `DocumentTextSelectionControls implements TextSelectionControls` — delegates to `materialTextSelectionControls` / `cupertinoTextSelectionControls` per platform.
- [ ] Actions: Cut, Copy, Paste, Select All, Bold, Italic (extensible via `toolbarItems`).
- [ ] Tests: toolbar appears on selection; actions dispatch correct `EditRequest`s.

---

## Phase 7 — Scrolling

> **Commit message:** `feat(widgets): document-aware scrolling with auto-scroll to caret`

- [ ] `DocumentScrollable extends StatefulWidget` — wraps `SingleChildScrollView` or `CustomScrollView`; exposes `ScrollController`.
- [ ] `DragHandleAutoScroller` — auto-scrolls when caret or drag handle approaches viewport edge; velocity-based acceleration.
- [ ] `bringDocumentPositionIntoView(DocumentPosition)` — computes caret rect via `DocumentLayout`, calls `ensureVisible` or `animateTo`.
- [ ] `SliverEditableDocument` — `SliverToBoxAdapter` variant for embedding in `CustomScrollView`.
- [ ] Tests: caret at bottom of viewport triggers scroll; caret at top triggers scroll up; large document renders without jank; `SliverEditableDocument` participates in `CustomScrollView` correctly.

---

## Phase 8 — Accessibility & semantics

> **Commit message:** `feat(semantics): document-level semantics tree, screen reader support`

- [ ] `DocumentSemanticsBuilder` — generates `SemanticsNode` tree from `Document`; one node per `DocumentBlock`; `SemanticsProperties.header` for heading nodes; `SemanticsProperties.liveRegion` for document root.
- [ ] Per-block semantics: `isTextField`, `isMultiline`, `isReadOnly`, `onSetText`, `onSetSelection`, `onMoveCursorForward/BackwardByCharacter`, `onMoveCursorForward/BackwardByWord`.
- [ ] Tests: `matchesSemantics()` for each node type; screen reader focus order follows document order; heading nodes expose correct heading level; `debugSemantics` output matches expected tree.

---

## Phase 9 — Performance benchmarking

> **Commit message:** `perf: add benchmark suite and set performance baselines`

- [ ] `benchmark/` — `package:benchmark_harness` micro-benchmarks:
  - Document model: `insertNode`, `deleteNode`, `AttributedText.applyAttribution` at various sizes.
  - IME serialization: `DocumentImeSerializer` round-trip for 100/1 000/10 000 node documents.
  - Selection queries: `DocumentLayout.getDocumentPositionAtOffset` for large documents.
- [ ] Integration test perf profiles (`--profile` mode):
  - Typing latency: 100 consecutive characters in a 1 000-paragraph document; frame build < 16 ms.
  - Scroll performance: fast fling through 10 000-paragraph document; < 2 jank frames.
  - Selection drag: drag handle across 500 paragraphs; no dropped frames.
- [ ] `Makefile benchmark` target writes results to `benchmark/results/`.
- [ ] Baseline comparison: compare `EditableDocument` vs `EditableText` for single-paragraph case; target parity or better.

---

## Phase 10 — Documentation & example app

> **Commit message:** `docs: complete API documentation and example app`

### 10.1 API documentation
- [ ] Every public symbol has `///` dartdoc; multi-paragraph docs for complex APIs.
- [ ] `{@tool snippet}` examples for: `DocumentEditingController`, `EditableDocument`, `DocumentField`, `ComponentBuilder`, custom `DocumentNode`.
- [ ] `dart doc` generates zero warnings.
- [ ] `doc/` — architecture overview (`architecture.md`): widget tree diagram, IME bridge data flow, command pipeline sequence diagram.

### 10.2 Example app
- [ ] `example/` — full-featured rich text editor demo:
  - Toolbar: bold, italic, underline, strikethrough, link, H1–H3, bullet list, ordered list, code block, horizontal rule, image insert.
  - Platform-adaptive: Material on Android/Windows/Linux, Cupertino on iOS/macOS, native scrollbar on Web.
  - Load/save document as JSON.
  - Undo/redo with keyboard shortcuts.
  - Word and character count.

### 10.3 Migration guide
- [ ] `doc/migration_from_editable_text.md` — side-by-side API comparison; how to wrap `EditableDocument` to match `EditableText` signature; `DocumentEditingController` vs `TextEditingController`.

---

## Phase 11 — Flutter framework contribution prep

> **Commit message:** `chore: flutter contribution readiness — design doc, analysis alignment`

- [ ] Write design doc via `flutter.dev/go/template`; mint shortlink `flutter.dev/go/editable-document`.
- [ ] File Flutter tracking issue with `design doc` label.
- [ ] Engage Flutter framework team on Discord `#hackers-text-input`.
- [ ] Ensure package layering mirrors Flutter internals: `model/` → `rendering/` → `widgets/` → `material/`/`cupertino/` with no upward dependencies.
- [ ] Replace all package-relative imports with path-relative imports (Flutter framework style).
- [ ] Run full Flutter framework test suite against prototype integration branch.
- [ ] Address all feedback from design doc review before filing merge PR.

---

## Phase 12 — Stable 1.0.0 release

> **Commit message:** `release: editable_document 1.0.0`

- [ ] All phases 0–11 complete with all checkboxes ticked.
- [ ] Test coverage ≥ 90 % overall; 100 % on `services/`, `model/position`, `model/selection`.
- [ ] Zero `flutter analyze` issues.
- [ ] Zero `dart doc` warnings.
- [ ] `CHANGELOG.md` complete with all notable changes.
- [ ] `pub publish --dry-run` passes.
- [ ] Semantic version `1.0.0` tagged and released.
- [ ] GitHub Release notes published with migration guide link.

---

## Version milestones at a glance

| Version | Phases | Status |
|---------|--------|--------|
| `0.1.0-dev` | 0 | Skeleton |
| `0.2.0-dev` | 1–2 | Document model + commands |
| `0.3.0-dev` | 3 | Rendering |
| `0.4.0-dev` | 4 | IME bridge |
| `0.5.0-dev` | 5 | Widget layer |
| `0.6.0-dev` | 6–7 | Overlays + scrolling |
| `0.7.0-dev` | 8 | Accessibility |
| `0.8.0-dev` | 9–10 | Benchmarks + docs |
| `0.9.0-dev` | 11 | Flutter contribution prep |
| `1.0.0` | 12 | Stable |
