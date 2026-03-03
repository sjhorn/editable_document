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
- [x] `flutter create --template=package editable_document` with `sdk: ">=3.3.0 <4.0.0"`.
- [x] `pubspec.yaml` — name, description, homepage, repository, issue_tracker, topics set.
- [x] `LICENSE` — BSD-3-Clause (matches Flutter).
- [x] `CHANGELOG.md` — `## 0.1.0-dev.1` stub.
- [x] `README.md` — package purpose, badges (pub version, CI, coverage), quickstart stub.

### 0.2 Analysis & linting
- [x] `analysis_options.yaml` matching Flutter's framework options:
  - `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`
  - `page_width: 100`
  - Enabled rules: `always_declare_return_types`, `avoid_dynamic_calls`, `avoid_print`, `flutter_style_todos`, `prefer_const_constructors`, `prefer_relative_imports`, `prefer_single_quotes`, `sort_child_properties_last`, `use_key_in_widget_constructors`, `use_super_parameters`, `missing_code_block_language_in_doc_comment`, `public_member_api_docs`, `diagnostic_describe_all_properties`.
- [x] `dart format` passes with `--line-length 100`.
- [x] `flutter analyze` produces zero issues.

### 0.3 CI pipeline (GitHub Actions)
- [x] `.github/workflows/ci.yml` — triggered on push + pull_request to `main`.
  - Jobs: `analyze`, `test` (unit + widget), `integration_test` (matrix: ubuntu, macos, windows), `golden_test`, `coverage`, `docs`.
- [x] Coverage threshold gate: fail if overall < 90 %.
- [x] Golden files committed to `test/goldens/` with platform-tagged suffixes.
- [x] `dart doc` build step — fail on any undocumented public API.

### 0.4 Developer tooling
- [x] `.claude/settings.local.json` — AI agent configuration (see CLAUDE.md Phase 0).
- [x] `CLAUDE.md` committed at repo root.
- [x] `.github/PULL_REQUEST_TEMPLATE.md` mirroring Flutter's checklist.
- [x] `.github/ISSUE_TEMPLATE/bug_report.md` and `feature_request.md`.

---

## Phase 1 — Document model (the data layer)

> **Commit message:** `feat(model): introduce DocumentNode, Document, DocumentPosition, DocumentSelection`

All Phase 1 code lives in `lib/src/model/`. Every class is tested in `test/src/model/` — write failing test first.

### 1.1 Core node types
- [x] `DocumentNode` — abstract base with `String id` (UUID v4), `Map<String, dynamic> metadata`, copyWith, equality, `debugDescribeChildren`.
- [x] `TextNode extends DocumentNode` — `AttributedText text`, typed-span attributions (bold, italic, underline, strikethrough, link, code, color, custom).
- [x] `ParagraphNode extends TextNode` — metadata keys for `blockType` (paragraph, h1–h6, blockquote, code block).
- [x] `ListItemNode extends TextNode` — `ListItemType` (ordered/unordered), `int indent`.
- [x] `ImageNode extends DocumentNode` — `String imageUrl`, `String? altText`, `double? width`, `double? height`, `BinaryNodePosition` (upstream/downstream).
- [x] `CodeBlockNode extends TextNode` — `String? language`, monospace attribution.
- [x] `HorizontalRuleNode extends DocumentNode` — no content, `BinaryNodePosition`.
- [x] `AttributedText` — `String text` + `SpanMarker` list for O(log n) attribution queries; `copyText(start, end)`, `insert`, `delete`, `applyAttribution`, `removeAttribution`.
- [x] Tests: node creation, equality, copyWith, metadata round-trip, attribution overlap/merge/split for all node types.

### 1.2 Document container
- [x] `Document` — immutable view: `List<DocumentNode> nodes`, `nodeById(String)`, `nodeAt(int)`, `nodeAfter`, `nodeBefore`, `getNodeIndexById`.
- [x] `MutableDocument extends Document` — mutation: `insertNode`, `deleteNode`, `replaceNode`, `moveNode`, `updateNode`.
- [x] `DocumentChangeEvent` — sealed class hierarchy: `NodeInserted`, `NodeDeleted`, `NodeReplaced`, `NodeMoved`, `TextChanged`.
- [x] `ValueNotifier<List<DocumentChangeEvent>>` on `MutableDocument`.
- [x] Tests: CRUD operations, ordering invariants, change event emission, empty document edge cases.

### 1.3 Position and selection model
- [x] `NodePosition` — abstract marker interface.
- [x] `TextNodePosition implements NodePosition` — `int offset`, `TextAffinity affinity`.
- [x] `BinaryNodePosition implements NodePosition` — `BinaryNodePositionType` (upstream/downstream).
- [x] `DocumentPosition` — `{String nodeId, NodePosition nodePosition}`, equality, `copyWith`.
- [x] `DocumentSelection` — `{DocumentPosition base, DocumentPosition extent}`, `isCollapsed`, `isExpanded`, `affinity`, `normalize(Document)`, equality.
- [x] Tests: collapsed/expanded detection, normalization across heterogeneous node types, equality semantics.

### 1.4 Document controller
- [x] `DocumentEditingController extends ChangeNotifier` — analogous to `TextEditingController`:
  - `MutableDocument document`
  - `DocumentSelection? selection`
  - `ComposerPreferences preferences` (active attributions)
  - `setSelection`, `clearSelection`, `collapseSelection`
  - `buildNodeSpan(DocumentNode)` — analogous to `buildTextSpan`
- [x] Tests: controller listeners fire on selection change, on document change, composer preferences round-trip.

---

## Phase 2 — Command pipeline & undo/redo

> **Commit message:** `feat(editor): event-sourced command pipeline with undo/redo`

### 2.1 Command architecture
- [x] `EditRequest` — abstract marker (e.g., `InsertTextRequest`, `DeleteContentRequest`, `ReplaceNodeRequest`, `SplitParagraphRequest`, `MergeNodeRequest`, `MoveNodeRequest`, `ChangeBlockTypeRequest`, `ApplyAttributionRequest`, `RemoveAttributionRequest`).
- [x] `EditCommand` — abstract with `execute(EditContext)` returning `List<DocumentChangeEvent>`.
- [x] `EditContext` — `{MutableDocument document, MutableDocumentComposer composer}`.
- [x] `Editor` — `submit(EditRequest)` maps request → command → executes → emits events → notifies reactions/listeners.
- [x] `EditReaction` — fires additional requests in response to events (e.g., `SplitParagraphReaction` converting paragraphs on Enter).
- [x] `EditListener` — `onEdit(List<DocumentChangeEvent>)` for UI rebuild.
- [x] Tests: each request type produces correct events; reaction chaining; listener notification order; command failure leaves document unchanged.

### 2.2 Undo/redo
- [x] `UndoableEditor extends Editor` — wraps commands with inverse command generation.
- [x] `undo()`, `redo()`, `canUndo`, `canRedo`.
- [x] Integration with `UndoHistory<DocumentEditingValue>` widget (matching `EditableText`'s pattern).
- [x] Tests: undo/redo for each command type; undo stack cleared on non-undoable commands; boundary conditions (empty stack, max stack depth).

---

## Phase 3 — Rendering layer

> **Commit message:** `feat(rendering): RenderDocumentLayout, per-block RenderObject tree`

All render objects in `lib/src/rendering/`. Tests in `test/src/rendering/` using `TestRenderingFlutterBinding`.

### 3.1 Per-block render objects
- [x] `RenderDocumentBlock` — abstract `RenderBox` base for all block types; defines `DocumentNodeId nodeId`, `DocumentSelection? nodeSelection`, `getLocalRectForPosition(NodePosition)`, `getPositionAtOffset(Offset)`, `getEndpointsForSelection(NodePosition base, NodePosition extent)`.
- [x] `RenderTextBlock extends RenderDocumentBlock` — wraps `TextPainter`; renders `AttributedText` with selection highlight rectangles and cursor; handles `TextDirection`, `TextAlign`, `TextScaler`.
- [x] `RenderParagraphBlock extends RenderTextBlock` — plus heading-level styles.
- [x] `RenderListItemBlock extends RenderTextBlock` — plus bullet/number rendering at correct indent.
- [x] `RenderImageBlock extends RenderDocumentBlock` — image sizing with `BinaryNodePosition` hit testing.
- [x] `RenderCodeBlock extends RenderTextBlock` — monospace, background fill, line numbers (optional).
- [x] `RenderHorizontalRuleBlock extends RenderDocumentBlock` — horizontal line with `BinaryNodePosition`.
- [x] Tests: layout at various constraints, paint output via `TestCanvas`, hit testing accuracy, position-to-rect and rect-to-position round-trips.

### 3.2 Document layout render object
- [x] `RenderDocumentLayout extends RenderBox with ContainerRenderObjectMixin` — vertical stack of `RenderDocumentBlock` children.
- [x] `DocumentLayoutGeometry` — `getDocumentPositionAtOffset(Offset)`, `getRectForDocumentPosition(DocumentPosition)`, `getComponentByNodeId(String)`, `getDocumentPositionNearestToOffset(Offset)`.
- [x] Scrollable viewport integration: accepts `ViewportOffset`, computes `maxScrollExtent`.
- [x] Tests: intrinsic sizes, layout with mixed block types, hit testing delegated to correct child, scroll extent computation.

### 3.3 Caret and selection painting
- [x] `DocumentSelectionPainter extends CustomPainter` — iterates nodes between base and extent; delegates selection rect computation to each `RenderDocumentBlock`; paints cross-block selection across multiple `RenderTextBlock` instances.
- [x] `DocumentCaretPainter extends CustomPainter` — draws cursor rect from `RenderDocumentBlock.getLocalRectForPosition`; blink animation via `AnimationController`.
- [x] Golden tests: cursor at line start/end/middle, selection spanning same paragraph, selection spanning multiple paragraphs, selection spanning text+image, RTL text cursor.

---

## Phase 4 — IME bridge

> **Commit message:** `feat(services): DocumentImeInputClient — IME virtualization bridge`

All IME code in `lib/src/services/`. This is the highest-risk phase; 100 % test coverage required on all paths.

### 4.1 DocumentImeSerializer
- [x] `DocumentImeSerializer` — bidirectional serialization:
  - `Document + DocumentSelection → TextEditingValue` (single text node: full text; multi-node/non-text: synthetic minimal value).
  - `TextEditingValue + Document → DocumentSelection`.
  - `List<TextEditingDelta> + Document → List<EditRequest>` (delta → document mutations).
- [x] Handle composing region within a `TextNodePosition`.
- [x] Handle `\n` split (Android Enter via delta) → `SplitParagraphRequest`.
- [x] Tests: serialization round-trips for each node type; delta→request mapping for insertion, deletion, replacement, non-text-update; composing region preserved through round-trip; empty document edge case.

### 4.2 DocumentImeInputClient
- [x] `DocumentImeInputClient implements DeltaTextInputClient` — connection lifecycle:
  - `openConnection(TextInputConfiguration)` → `TextInput.attach(this, config)` with `enableDeltaModel: true`.
  - `closeConnection()` → `_inputConnection?.close()`.
  - `updateEditingValueWithDeltas(List<TextEditingDelta>)` → serialize → dispatch `EditRequest`s.
  - `performAction(TextInputAction)` → `onAction` callback.
  - `updateFloatingCursor(RawFloatingCursorPoint)` → iOS floating cursor state.
  - `insertContent(KeyboardInsertedContent)` → `InsertInlineContentRequest` (Android image/GIF).
  - `connectionClosed()` → notify composer.
  - `showKeyboard()` / `hideKeyboard()`.
- [x] `syncToIme()` — push current `TextEditingValue` back to platform after document mutations.
- [x] Tests: mock `SystemChannels.textInput`; verify outgoing calls (`setClient`, `setEditingState`, `show`, `hide`, `clearClient`); verify incoming calls route correctly; delta model enabled; floating cursor state machine.

### 4.3 Keyboard & shortcuts
- [x] `DocumentKeyboardHandler` — `KeyEventResult onKeyEvent(FocusNode, KeyEvent)` — handles keys not covered by IME deltas (desktop arrow navigation, Home/End, Shift+arrow selection, Ctrl+arrow word navigation, Delete forward, Escape).
- [x] `DefaultDocumentShortcuts` — extends `DefaultTextEditingShortcuts` with document-specific intents: `SplitBlockIntent`, `MergeBlockBackwardIntent`, `MergeBlockForwardIntent`, `IndentListItemIntent`, `UnindentListItemIntent`, `ToggleAttributionIntent`.
- [x] Platform-specific mappings: macOS (Cmd), Windows/Linux (Ctrl), iOS/Android (no hardware shortcuts needed but handled gracefully).
- [x] Tests: all intents dispatch correct `EditRequest`s; platform shortcut mapping verified for all six platforms; unknown keys pass through.

### 4.4 Autofill
- [x] `DocumentAutofillClient implements AutofillClient` — single-text-node documents participate in autofill groups.
- [x] `autofillHints` passed through `DocumentEditingController`.
- [x] Tests: autofill connection established when `autofillHints` is set; `updateEditingStateWithTag` routes to correct node.

---

## Phase 5 — Widget layer

> **Commit message:** `feat(widgets): EditableDocument widget — drop-in for EditableText`

All widgets in `lib/src/widgets/`. Tests in `test/src/widgets/` using `testWidgets`.

### 5.1 Component builder system
- [x] `ComponentBuilder` — abstract with `createViewModel(Document, DocumentNode)` and `createComponent(ComponentViewModel, ComponentContext)`.
- [x] `ComponentViewModel` — abstract data class with `nodeId`, `selection`, `isSelected`.
- [x] `ComponentContext` — `{Document, DocumentSelection?, ComponentBuilder, StyleSheet}`.
- [x] Default builders: `ParagraphComponentBuilder`, `ListItemComponentBuilder`, `ImageComponentBuilder`, `CodeBlockComponentBuilder`, `HorizontalRuleComponentBuilder`.
- [x] Tests: each builder returns non-null for its node type; returns null for other types; custom builder prepended to list takes precedence.

### 5.2 DocumentLayout widget
- [x] `DocumentLayout extends StatefulWidget` — renders `RenderDocumentLayout` via `DocumentLayoutElement extends RenderObjectElement`.
- [x] Responds to `Document` changes via `EditListener`.
- [x] `GlobalKey<DocumentLayoutState>` exposes `documentPositionAtOffset`, `rectForDocumentPosition`, `componentForNode`.
- [x] Tests: layout updates when document changes; correct component rendered for each node type; position queries delegated to render layer.

### 5.3 EditableDocument widget (the main deliverable)
- [x] `EditableDocument extends StatefulWidget` — parameter surface mirrors `EditableText`:
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
- [x] `EditableDocumentState` — five mixins analogous to `EditableTextState`: `AutomaticKeepAliveClientMixin`, `WidgetsBindingObserver`, `TickerProviderStateMixin`, `TextSelectionDelegate`, `DeltaTextInputClient`.
- [x] Build tree (analogous to `EditableText`): `Actions` → `Focus` → `Scrollable` → `DocumentLayout` → `DocumentSelectionOverlay`.
- [x] Tests: widget builds without error for each node type; focus/blur cycles open/close IME; readOnly blocks IME; autofocus works; scroll to caret on focus.

### 5.4 DocumentField widget (TextField equivalent)
- [x] `DocumentField extends StatefulWidget` — wraps `EditableDocument` with decoration (`InputDecoration`), label, hint, prefix/suffix, error text.
- [x] `_DocumentFieldState` delegates to `EditableDocumentState`.
- [x] Tests: decoration renders; label animates on focus; error state shows; counter tracks document length.

---

## Phase 6 — Selection overlay & platform handles

> **Commit message:** `feat(widgets): cross-block selection overlay, platform handles, magnifier`

### 6.1 DocumentSelectionOverlay
- [x] `DocumentSelectionOverlay` — manages `OverlayEntry`s for caret, handles, toolbar.
- [x] Uses `LayerLink` pairs (start handle ↔ `CompositedTransformTarget` at selection start; end handle ↔ end) mirroring `TextSelectionOverlay`.
- [x] `DocumentSelectionOverlayState.update(DocumentSelection?)` — recomputes positions from `DocumentLayout` geometry.
- [x] Tests: overlay entries created on selection; removed on collapse; positions match render layer geometry (golden tests).

### 6.2 Caret overlay
- [x] `CaretDocumentOverlay extends StatefulWidget` — `CustomPaint` with `DocumentCaretPainter`; blink via `AnimationController` with `_kCursorBlinkInterval = Duration(milliseconds: 500)` matching `EditableText`.
- [x] Pause blink on key events; restart on idle.
- [x] Integration test: caret visible after focus; blink animation runs; caret hidden in `readOnly`.

### 6.3 Desktop selection (mouse)
- [x] `DocumentMouseInteractor` — `MouseRegion` + `GestureDetector`; tap → collapse to position; drag → extend selection; double-tap → word selection; triple-tap → block selection; Shift+click → extend.
- [x] Tests: tap places caret at correct `DocumentPosition`; drag selects text; word/block selection boundaries correct.

### 6.4 iOS handles & magnifier
- [x] `IosDocumentGestureController` — tap, double-tap, long-press, drag.
- [x] `IOSCollapsedHandle`, `IOSSelectionHandle` — `GestureDetector` on `CustomPaint` handle widgets; drag updates selection via `DocumentLayout.getDocumentPositionAtOffset`.
- [x] `IOSDocumentMagnifier` — `TextMagnifier`-equivalent; shows on long-press and handle drag; hides on release.
- [x] Integration tests: handle positions correct after selection; magnifier appears on long-press; selection extends on handle drag.

### 6.5 Android handles & magnifier
- [x] `AndroidDocumentGestureController` — tap, double-tap, long-press, drag with velocity.
- [x] `AndroidSelectionHandle`, `AndroidDocumentCaret`.
- [x] `AndroidDocumentMagnifier`.
- [x] Integration tests: mirrors iOS test coverage for Android gesture set.

### 6.7 Paint-time caret and selection geometry
- [x] `RenderDocumentCaret` — `LeafRenderObjectWidget` + `RenderBox` that queries `RenderDocumentLayout` at paint time; eliminates the post-frame-callback one-frame delay for caret positioning.
- [x] `RenderDocumentSelectionHighlight` — same pattern for selection highlight rectangles.
- [x] `CaretDocumentOverlay` and `DocumentSelectionOverlay` updated to use the new render objects.
- Note: handle anchor positioning (`CompositedTransformTarget`) still uses post-frame callbacks. A future improvement could replace these with a custom `RenderObject` that positions `LayerLink` targets during paint, eliminating all post-frame callbacks.

### 6.6 Floating toolbar
- [x] `DocumentTextSelectionControls implements TextSelectionControls` — delegates to `materialTextSelectionControls` / `cupertinoTextSelectionControls` per platform.
- [x] Actions: Cut, Copy, Paste, Select All, Bold, Italic (extensible via `toolbarItems`).
- [x] Tests: toolbar appears on selection; actions dispatch correct `EditRequest`s.

---

## Phase 7 — Scrolling

> **Commit message:** `feat(widgets): document-aware scrolling with auto-scroll to caret`

- [x] `DocumentScrollable extends StatefulWidget` — wraps `SingleChildScrollView` or `CustomScrollView`; exposes `ScrollController`.
- [x] `DragHandleAutoScroller` — auto-scrolls when caret or drag handle approaches viewport edge; velocity-based acceleration.
- [x] `bringDocumentPositionIntoView(DocumentPosition)` — computes caret rect via `DocumentLayout`, calls `ensureVisible` or `animateTo`.
- [x] `SliverEditableDocument` — `SliverToBoxAdapter` variant for embedding in `CustomScrollView`.
- [x] Tests: caret at bottom of viewport triggers scroll; caret at top triggers scroll up; large document renders without jank; `SliverEditableDocument` participates in `CustomScrollView` correctly.

---

## Phase 8 — Accessibility & semantics

> **Commit message:** `feat(semantics): document-level semantics tree, screen reader support`

- [x] `DocumentSemanticsBuilder` — generates `SemanticsNode` tree from `Document`; one node per `DocumentBlock`; `SemanticsProperties.header` for heading nodes; `SemanticsProperties.liveRegion` for document root.
- [x] Per-block semantics: `isTextField`, `isMultiline`, `isReadOnly`, `onSetText`, `onSetSelection`, `onMoveCursorForward/BackwardByCharacter`, `onMoveCursorForward/BackwardByWord`.
- [x] Tests: `matchesSemantics()` for each node type; screen reader focus order follows document order; heading nodes expose correct heading level; `debugSemantics` output matches expected tree.

---

## Phase 9 — Performance benchmarking

> **Commit message:** `perf: add benchmark suite and set performance baselines`

- [x] `benchmark/` — `package:benchmark_harness` micro-benchmarks:
  - Document model: `insertNode`, `deleteNode`, `AttributedText.applyAttribution` at various sizes.
  - IME serialization: `DocumentImeSerializer` round-trip for 100/1 000/10 000 node documents.
  - Selection queries: `DocumentLayout.getDocumentPositionAtOffset` for large documents.
- [x] Integration test perf profiles (`integration_test/perf_profile_test.dart`, run on macOS desktop):
  - Typing latency: 100 consecutive characters in a 1 000-paragraph document; mean ~17 ms in debug (profile target: < 16 ms).
  - Scroll performance: fast fling through 10 000-paragraph document; 15 frames in debug (profile target: < 2 jank frames).
  - Selection drag: expand selection across 500 paragraphs; ~5 ms (profile target: < 16 ms).
- [x] `scripts/ci/benchmark.sh` target writes results to `benchmark/results/`.
- [x] Baseline comparison: compare `EditableDocument` vs `EditableText` for single-paragraph case; target parity or better.

---

## Phase 10 — Documentation & example app

> **Commit message:** `docs: complete API documentation and example app`

### 10.1 API documentation
- [x] Every public symbol has `///` dartdoc; multi-paragraph docs for complex APIs.
- [x] `{@tool snippet}` examples for: `DocumentEditingController`, `EditableDocument`, `DocumentField`, `ComponentBuilder`, custom `DocumentNode`.
- [x] `dart doc` generates zero warnings.
- [x] `doc/` — architecture overview (`architecture.md`): widget tree diagram, IME bridge data flow, command pipeline sequence diagram.

### 10.2 Example app
- [x] `example/` — full-featured rich text editor demo:
  - Toolbar: bold, italic, underline, strikethrough, link, H1–H3, bullet list, ordered list, code block, horizontal rule, image insert.
  - Platform-adaptive: Material on Android/Windows/Linux, Cupertino on iOS/macOS, native scrollbar on Web.
  - Load/save document as JSON.
  - Undo/redo with keyboard shortcuts.
  - Word and character count.

### 10.3 Migration guide
- [x] `doc/migration_from_editable_text.md` — side-by-side API comparison; how to wrap `EditableDocument` to match `EditableText` signature; `DocumentEditingController` vs `TextEditingController`.

---

## Phase 11 — Flutter framework contribution prep

> **Commit message:** `chore: flutter contribution readiness — design doc, analysis alignment`

- [ ] Write design doc via `flutter.dev/go/template`; mint shortlink `flutter.dev/go/editable-document`.
- [ ] File Flutter tracking issue with `design doc` label.
- [ ] Engage Flutter framework team on Discord `#hackers-text-input`.
- [x] Ensure package layering mirrors Flutter internals: `model/` → `rendering/` → `widgets/` → `material/`/`cupertino/` with no upward dependencies.
- [x] Replace all package-relative imports with path-relative imports (Flutter framework style).
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
