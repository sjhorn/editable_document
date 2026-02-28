# Technical research for editable_document package

The `editable_document` package must bridge a fundamental gap in Flutter's text editing stack: **Flutter's EditableText operates on a single flat string, while real documents require block-structured, heterogeneous content**. This report synthesizes deep research across Flutter internals, super_editor's architecture, contribution requirements, and TDD patterns to inform both a ROADMAP.md and CLAUDE.md for the package.

## Flutter's EditableText stack: what you're replacing and why

### The widget-to-render pipeline

Flutter's text editing lives in a tightly coupled vertical: `EditableText` (StatefulWidget) → `EditableTextState` (with five mixins: `AutomaticKeepAliveClientMixin`, `WidgetsBindingObserver`, `TickerProviderStateMixin`, `TextSelectionDelegate`, `TextInputClient`) → a private `_Editable` (LeafRenderObjectWidget) → `RenderEditable` (RenderBox with `ContainerRenderObjectMixin`, `RelayoutWhenSystemFontsChangeMixin`, implementing `TextLayoutMetrics`).

The build tree produced by `EditableTextState.build()` is deeply nested: `_CompositionCallback` → `Actions` → `Builder` → `TextFieldTapRegion` → `MouseRegion` → `UndoHistory<TextEditingValue>` → `Focus` → `NotificationListener<ScrollNotification>` → `Scrollable` → `CompositedTransformTarget` → `Semantics` → `_ScribbleFocusable` → `SizeChangedLayoutNotifier` → `_Editable`. The `_editableKey` GlobalKey on `_Editable` provides lazy access to the `RenderEditable` via `findRenderObject()`.

`RenderEditable`'s constructor accepts **~30 parameters** covering text content (`InlineSpan?`), cursor configuration (color, width, height, radius, offset), selection (color, height/width style), scroll offset (`ViewportOffset`), display flags (maxLines, minLines, expands, obscureText), painters (`RenderEditablePainter?` for foreground/background), and layer links for handle positioning.

### IME management: the TextInputClient contract

`EditableTextState` implements `TextInputClient`, receiving platform IME events through these key methods:
- **`updateEditingValue(TextEditingValue)`** — the primary text sync pathway. Applies input formatters, updates controller, syncs back via `_updateRemoteEditingValueIfNeeded()`.
- **`performAction(TextInputAction)`** — IME action buttons (done, next, send). Triggers `_finalizeEditing()`.
- **`updateFloatingCursor(RawFloatingCursorPoint)`** — iOS floating cursor gestures.
- **`insertContent(KeyboardInsertedContent)`** — Android keyboard image/GIF insertion.
- **`connectionClosed()`** — platform closed the input connection.

The connection flow: focus gained → `_openInputConnection()` → `TextInput.attach(this, textInputConfiguration)` → `show()` → `setEditingState(_value)`. Communication uses `SystemChannels.textInput` MethodChannel with outgoing calls (`setClient`, `show`, `setEditingState`, `hide`, `clearClient`, `setCaretRect`, `setSelectionRects`) and incoming calls (`updateEditingState`, `updateEditingStateWithDeltas`, `performAction`, `requestExistingInputState`).

The **delta model** (`DeltaTextInputClient`) is an opt-in extension providing granular change tracking via `updateEditingValueWithDeltas(List<TextEditingDelta>)`. Delta types: `TextEditingDeltaInsertion`, `TextEditingDeltaDeletion`, `TextEditingDeltaReplacement`, `TextEditingDeltaNonTextUpdate`. Enabled via `TextInputConfiguration.enableDeltaModel = true`. **This is critical for editable_document** — it enables tracking exactly what changed rather than diffing entire values.

### Keyboard events: the Actions/Shortcuts system

Keyboard handling follows a two-phase pipeline: raw key events processed by `Shortcuts` widget hierarchy first, then unhandled events flow to `TextInputClient`. `DefaultTextEditingShortcuts` (inserted near the root by `WidgetsApp`) maps platform-specific key combinations to Intent objects with different mappings for macOS, Windows, Linux, iOS, Android.

`EditableTextState` registers **20+ Intent→Action pairs** in its `Actions` widget, including `DeleteCharacterIntent`, `ExtendSelectionByCharacterIntent`, `ExtendSelectionToLineBreakIntent`, `ExtendSelectionVerticallyToAdjacentLineIntent`, `SelectAllTextIntent`, `CopySelectionTextIntent`, `PasteTextIntent`, `UndoTextIntent`, `RedoTextIntent`, and more. **These actions are private to EditableTextState**, making reuse by custom editors impossible — a known limitation.

### Selection overlay, cursor, and handles

`TextSelectionOverlay` wraps `SelectionOverlay` and is created/managed by `EditableTextState`. It computes handle positions from `RenderEditable.getEndpointsForSelection(selection)` returning `List<TextSelectionPoint>`. Handles and toolbar are inserted into the `Overlay` via `OverlayEntry` with `CompositedTransformFollower`/`CompositedTransformTarget` pairs via `LayerLink` for efficient repositioning during scrolling.

Cursor rendering uses a private `_CaretPainter` drawing an `RRect` with configurable color/width/height/radius. Selection highlight rectangles are computed via `_textPainter.getBoxesForSelection()`. iOS paints cursor above text; Android paints below. The floating cursor (iOS) has constants: `_kFloatingCaretSizeIncrease = EdgeInsets.symmetric(horizontal: 0.5, vertical: 1.0)`.

### Scrolling within EditableText

`EditableTextState.build()` wraps `_Editable` in a `Scrollable` widget with `axisDirection` based on multiline vs single-line. `RenderEditable` receives a `ViewportOffset` from the `Scrollable`, computes `maxScrollExtent` during layout (text content size minus viewport size), and calculates `_paintOffset` from `offset.pixels`. Auto-scroll uses `bringIntoView(TextPosition)` computing caret rect via `renderEditable.getLocalRectForCaret(position)` then calling `showOnScreen()`. Default `scrollPadding` is `EdgeInsets.all(20.0)`.

### TextEditingController and buildTextSpan

`TextEditingController extends ValueNotifier<TextEditingValue>`. Setting `text`, `selection`, or `value` triggers `notifyListeners()`. `EditableTextState` registers `_didChangeTextEditingValue` as a listener in `initState()`.

The **`buildTextSpan()`** method on the controller converts text to a `TextSpan` for rendering: if composing is active, it splits text into segments with the composing region underlined. This method is the override point for custom styling (syntax highlighting, mentions). The result is set as `_Editable.inlineSpan` → `RenderEditable.text`.

`InlineSpan` is the abstract base with subclasses `TextSpan` (styled text), `WidgetSpan` (inline widget), and `PlaceholderSpan` (non-text inline content).

### TextPainter for layout

`RenderEditable` uses a private `_textPainter` (`TextPainter`) for all text layout and painting. Key methods: `getPositionForOffset()` for hit testing, `getOffsetForCaret()` for caret positioning, `getBoxesForSelection()` for selection rectangles, `getLineBoundary()` and `getWordBoundary()` for text navigation, `computeLineMetrics()` for per-line metrics. Layout is performed in `performLayout()` → `_layoutText(minWidth, maxWidth)`.

### Accessibility wiring

`RenderEditable.describeSemanticsConfiguration()` sets `isTextField = true`, `isMultiline`, `isReadOnly`, `isObscured`, `isFocused`, and registers callbacks: `onSetText`, `onSetSelection`, `onMoveCursorForwardByCharacter`, `onMoveCursorBackwardByCharacter`. The `Semantics` widget in the build tree adds `onCopy`, `onCut`, `onPaste`. Known limitation: **macOS does not support text selection across multiple semantics nodes** (flutter/flutter#77957).

### Platform differences

Android: Gboard puts non-CJK words in composing regions; supports `performPrivateCommand` and `insertContent`. iOS: floating cursor, cursor above text, Scribble/Apple Pencil handwriting via `_ScribbleFocusable`. Web: browser's native input element handles text input. macOS/Windows/Linux: hardware keyboard via `DefaultTextEditingShortcuts` with platform-specific mappings.

### Magnifier and autofill

`TextMagnifierConfiguration` with platform-specific builders: `TextMagnifier` (Android), `CupertinoTextMagnifier` (iOS), null on desktop/web. `AutofillGroup` groups `AutofillClient`s; `EditableTextState implements AutofillClient` with `autofillId`, `autofillHints`, and the platform sends `updateEditingStateWithTag` to target specific clients.

### Known limitations driving editable_document's existence

1. **Single-paragraph model** — `EditableText`/`RenderEditable` operates on one flat `TextEditingValue`. No multi-paragraph, no heterogeneous blocks.
2. **No text virtualization** — entire text is laid out and painted; no viewport-based rendering for large documents.
3. **Private Actions** — text editing Actions are private to `EditableTextState`, blocking reuse.
4. **Performance with large text** — `TextPainter.layout()` is expensive for large texts (flutter/flutter#92173).
5. **GestureRecognizer assertion failure** — `TapGestureRecognizer` in `TextSpan`s within non-readOnly fields triggers assertion (flutter/flutter#97433, #127091).

---

## super_editor's architecture: lessons and patterns to learn from

### Core architecture and data flow

super_editor separates concerns into five layers:
1. **`Document`/`MutableDocument`** — data model: ordered list of typed `DocumentNode`s, each with a UUID `id` and `metadata` map.
2. **`Editor`** — command pipeline implementing event sourcing: `EditRequest → EditCommand → EditEvent → EditReaction/EditListener`. All mutations must flow through this pipeline for undo/redo.
3. **`DocumentComposer`/`MutableDocumentComposer`** — transient editing state: current `DocumentSelection` and `ComposerPreferences` (active attributions).
4. **`DocumentLayout`** — visual layout interface answering geometric queries: `getDocumentPositionNearestToOffset()`, `getComponentByNodeId()`, `getRectForPosition()`. Concrete: `SingleColumnDocumentLayout`.
5. **`SuperEditor`** widget — composes everything with `stylesheet`, `componentBuilders`, `keyboardActions`, `imePolicies`, `documentOverlayBuilders`.

Data flow: user input → gesture interactor/keyboard handler → creates `EditRequest`s → submitted to `Editor` → mapped to `EditCommand` → mutates `MutableDocument` and `DocumentComposer` → produces `EditEvent`s → `EditReaction`s may fire additional requests → `EditListener`s notified → UI rebuilds.

### Document model vs TextEditingValue

The contrast is fundamental. Where Flutter has a flat `TextEditingValue` (string + selection + composing), super_editor has:
- **Block-structured**: ordered `List<DocumentNode>`, each with unique UUID.
- **Rich text per node**: `TextNode` holds `AttributedText` with span-based attributions (bold, italic, link, custom).
- **Heterogeneous**: nodes can be `ParagraphNode`, `ListItemNode`, `ImageNode`, `HorizontalRuleNode`, `TaskNode`.
- **`DocumentPosition`**: `{nodeId: String, nodePosition: NodePosition}` where `NodePosition` is a marker interface with implementations `TextNodePosition` (int offset + TextAffinity) and `BinaryNodePosition` (upstream/downstream for non-text nodes).
- **`DocumentSelection`**: `{base: DocumentPosition, extent: DocumentPosition}` spanning across multiple heterogeneous nodes.

### IME virtualization: the critical bridge pattern

This is the most architecturally significant pattern for editable_document to study. The core challenge: **Flutter's IME API expects a single flat TextEditingValue, but super_editor has a structured multi-block document**.

Key classes:
- **`DocumentImeInputClient`** implements `DeltaTextInputClient` — the bridge between platform IME and the document editor.
- **`DocumentImeSerializer`** — serializes/deserializes between Document+DocumentSelection and TextEditingValue+TextSelection.

The serializer operates in **two modes**:
1. **Text Editing Mode** (single text node selected): serializes only the currently-selected `TextNode`'s text as the `TextEditingValue`. Preserves auto-correct, suggestions, voice dictation.
2. **Insert/Delete Mode** (multi-node selection or non-text node): gives IME a minimal synthetic `TextEditingValue`; intercepts backspace/delete and maps to document-level operations.

When IME sends deltas via `updateEditingValueWithDeltas()`: the `DocumentImeInputClient` receives `TextEditingDelta` objects → deserialized back into document operations → diff applied to `TextNode`'s `AttributedText` preserving attributions. Special handling exists for Android `\n` newline deltas and auto-correct/voice dictation multi-character changes.

IME connection management uses `DocumentSelectionOpenAndCloseImePolicy`, `SuperEditorImePolicies`, `SoftwareKeyboardController`, and `DeltaTextInputClientDecorator` for app-level IME overrides. A recent breaking change centralized all IME connections to fix non-reproducible connection loss issues.

### Selection overlay: document layer system

super_editor does NOT use Flutter's `TextSelectionOverlay`. Instead it uses a **document layer system**: `documentOverlayBuilders` (List\<DocumentLayerBuilder\>) rendered on top of the document layout. Default: `DefaultCaretOverlayBuilder` → `CaretDocumentOverlay` → `CaretPainter`.

Platform-specific handles:
- **Desktop**: `DocumentMouseInteractor` — caret only, no drag handles.
- **iOS**: `IosDocumentGestureEditingController` + `IOSCollapsedHandle` + `IOSSelectionHandle` + magnifier (`MagnifyingGlass`) + `IOSTextEditingFloatingToolbar`.
- **Android**: `AndroidDocumentGestureEditingController` + `AndroidSelectionHandle` + `AndroidTextFieldCaret` + `AndroidTextEditingFloatingToolbar`.

Selection highlighting is painted per-component: each component (text, image, HR) knows how to paint its own selection state via the view model. For cross-block selection, the system iterates all nodes between base and extent, computes per-node selection, and each component paints its portion.

### ComponentBuilder pattern for extensible rendering

```dart
abstract class ComponentBuilder {
  SingleColumnLayoutComponentViewModel? createViewModel(Document, DocumentNode);
  Widget? createComponent(SingleColumnLayoutComponentViewModel);
}
```

Priority-ordered list: first builder returning non-null wins. `defaultComponentBuilders` provides the standard set. Apps prepend custom builders. Each builder produces a **view model** (data) and a **component widget** (UI). Built-in node types: `ParagraphNode` (extends `TextNode`, metadata for headers/blockquotes), `ListItemNode` (ordered/unordered with indent level), `ImageNode` (block with `BinaryNodePosition`), `HorizontalRuleNode` (extends `BlockNode`), `TaskNode` (checkbox + text).

### Scrolling and layout optimization

`SingleColumnDocumentLayout` arranges components vertically. `DragHandleAutoScroller` auto-scrolls when caret approaches viewport boundaries. Can embed in `CustomScrollView` via `SliverExampleEditor`. The `Presenter` style pipeline caches phases: (1) create baseline view model, (2) apply document-wide styles, (3) apply component-specific styles, (4) apply selection styles. When only the caret moves, only phase 4 re-runs.

### Known limitations and issues to avoid

- **IME testing gap**: Flutter lacks mechanisms to test real IME delta behavior (flutter/flutter#131510). super_editor "can't diagnose" many IME bugs.
- **Flutter API instability**: Breaking changes to `TextInputClient`/`DeltaTextInputClient` have repeatedly broken super_editor.
- **Platform keyboard issues**: Samsung Korean, Japanese input, GBoard spacebar caret movement all required special handling.
- **No stable release**: v0.3.0-dev.X series since 2024, APIs still evolving.
- **256 open issues**, 32 open PRs.
- **Typing lag in large documents** was a known issue, specifically fixed.
- **Mobile caret overlays** changed from Tickers to Timers to prevent frame churn.

---

## Flutter contribution and merge requirements

### The contribution pipeline

The process for eventual Flutter merger follows: fork → branch → code + tests → `flutter analyze --flutter-repo` → PR with detailed commit messages → review within two weeks → LGTM from maintainer → CI passes → merge. Every PR must confirm: read Contributor Guide, read Tree Hygiene, followed Flutter Style Guide including "Features we expect every widget to implement", signed CLA, listed fixing issue(s), updated/added documentation, added tests, followed breaking change policy.

### Code style: strict by design

Flutter's `analysis_options.yaml` enforces `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true` with **page width of 100 characters**. Key enabled rules include `always_declare_return_types`, `avoid_dynamic_calls`, `avoid_print`, `flutter_style_todos` (format: `// TODO(username): description`), `prefer_const_constructors`, `prefer_relative_imports`, `prefer_single_quotes`, `sort_child_properties_last`, `use_key_in_widget_constructors`, `use_super_parameters`, `missing_code_block_language_in_doc_comment`. Naming: `UpperCamelCase` classes, `lowerCamelCase` methods, `snake_case.dart` files.

At the package level (`packages/flutter/analysis_options.yaml`), `public_member_api_docs` and `diagnostic_describe_all_properties` are additionally enabled — **every public API member must have `///` documentation**.

### Test requirements: comprehensive coverage mandatory

Tests mirror `lib/src/` directory structure in `packages/flutter/test/`. Every change must be tested; PRs lacking tests need explicit exemption. Types required: unit tests, widget tests (`testWidgets` with `WidgetTester`), render object tests (via `TestRenderingFlutterBinding`), golden tests (`matchesGoldenFile` — changes to golden files are considered breaking changes), and integration tests where applicable.

The **FlutterTest font** provides deterministic text metrics: 14pt text has height=14.0, ascent=10.5, descent=3.5, width=14.0 per glyph. IME testing uses `tester.testTextInput` and `tester.binding.defaultBinaryMessenger.setMockMethodCallHandler()` to mock platform channels.

### Documentation: API docs as long as needed

Flutter expects dartdoc on every public member, with these standards: "It's perfectly reasonable for API docs to be multiple pages long with subheadings" (e.g., `RenderBox`). Code examples use `{@tool snippet}`, `{@tool dartpad}`, and `{@tool sample}` annotations. Example code lives in `examples/api/lib/`. "When you discover an answer while working, document it where you first looked for the answer."

### Design doc process for major features

For a feature like editable_document merging into Flutter: create a Google Doc via `flutter.dev/go/template`, mint a shortlink, file a tracking GitHub issue with `design doc` label, solicit feedback on Discord (#hackers-text-input), iterate, then implement via PRs. Key principle: **"Decisions are made in PRs, not in design docs."** All design information must be captured in source code API docs — don't assume anyone will read the design doc after discussion.

### Framework layering architecture

Flutter's strict bottom-up layers: `dart:ui` → `foundation` → `animation` → `painting` → `gestures` → `rendering` → `widgets` → `material`/`cupertino`, with `services`, `scheduler`, and `semantics` as cross-cutting layers. Each layer may only depend on layers below it. Code in `material/` must not be imported by `widgets/`. Barrel files at `packages/flutter/lib/` (e.g., `material.dart`, `widgets.dart`) re-export all public APIs from `src/` subdirectories.

For editable_document, this means new render objects go in `rendering/`, new widgets in `widgets/`, and Material/Cupertino wrappers in their respective directories. The package should mirror this layering internally.

---

## TDD patterns and testing strategy for editable_document

### Test-first development approach

Flutter's architecture is naturally TDD-friendly. The cycle: write a failing `testWidgets`, implement minimum code, refactor. **Render objects are particularly suited to TDD** since they have clear input (constraints) and output (size, paint commands).

Key `flutter_test` classes: `WidgetTester` (provides `pumpWidget()`, `pump()`, `pumpAndSettle()`, `tap()`, `drag()`, `enterText()`), `TestWidgetsFlutterBinding` (FakeAsync zone for deterministic time), Finder classes (`find.text()`, `find.byType()`, `find.byKey()`), Matchers (`findsOneWidget`, `matchesGoldenFile()`, `matchesSemantics()`, `hasSemantics()`).

### SOLID principles mapped to editable_document

- **SRP**: Separate `DocumentWidget` (configuration) from `DocumentState` (mutable state) from `RenderDocument` (layout/paint). Each DocumentNode type has its own renderer.
- **OCP**: `ComponentBuilder` pattern (from super_editor) — extend with new node types without modifying existing builders.
- **LSP**: Any `DocumentNode` subclass substitutable where `DocumentNode` expected. `NodePosition` implementations substitutable in `DocumentPosition`.
- **ISP**: Small focused interfaces — `TextInputClient` for IME, `TickerProvider` for animation, separate interfaces for selection handling vs text input vs layout queries.
- **DIP**: `InheritedWidget` for dependency injection. Constructor injection for testability. Abstract `DocumentLayout` interface decoupled from concrete `SingleColumnDocumentLayout`.

### Test structure mirroring Flutter's own patterns

Organize tests mirroring `lib/src/`: `test/src/model/document_test.dart`, `test/src/rendering/render_document_test.dart`, `test/src/widgets/editable_document_test.dart`. Use `group()` blocks for related scenarios, `setUp()` with `debugResetSemanticsIdCounter()` for semantics tests. Always wrap test widgets in `MaterialApp` for `Localizations`/`MediaQuery`/`Directionality`.

For IME testing: mock `SystemChannels.textInput` via `tester.binding.defaultBinaryMessenger.setMockMethodCallHandler()`. Use `tester.testTextInput` for IME simulation. Note Flutter's limitation: no mechanism to test real IME delta behavior (flutter/flutter#131510).

### Golden testing strategy

Use `matchesGoldenFile()` with widgets wrapped in `RepaintBoundary` → `Center` → `MaterialApp`. Generate goldens in CI on consistent environment (Linux container). Use custom `GoldenFileComparator` with tolerance for cross-platform differences. Tag golden tests in `dart_test.yaml` for selective execution. Golden tests for: cursor rendering, selection highlights across blocks, handle positioning, magnifier appearance, different node type rendering.

### Performance benchmarking

Use `benchmark_harness` for micro-benchmarks (document model operations, serialization). Use `integration_test` + `flutter drive --profile` for macro-benchmarks (typing latency, scroll performance, large document rendering). Key metrics: frame build time <16ms, frame rasterization time, jank count, memory usage. Always measure in profile mode on real devices.

### Package structure for editable_document

```
editable_document/
├── lib/
│   ├── editable_document.dart        # Barrel file
│   └── src/
│       ├── model/                     # Document, DocumentNode, DocumentSelection
│       ├── rendering/                 # RenderDocument, RenderDocumentBlock
│       ├── widgets/                   # EditableDocument widget, components
│       ├── services/                  # IME bridge, keyboard handling
│       └── testing/                   # Test utilities (exported separately)
├── test/                              # Mirrors lib/src/
├── example/
├── benchmark/
├── integration_test/
├── analysis_options.yaml              # Match Flutter's strict rules
├── pubspec.yaml
├── ROADMAP.md
├── CLAUDE.md
├── README.md
├── CHANGELOG.md
└── LICENSE                            # BSD-3-Clause
```

Use Flutter's analysis options (strict-casts, strict-inference, strict-raw-types, page width 100). Enable `public_member_api_docs`. Minimize external dependencies — ideally zero beyond Flutter SDK for merger compatibility. Provide a `testing/` subpackage with mocks and test utilities.

---

## Architectural decisions for editable_document's ROADMAP

Based on this research, the package should make these key architectural choices:

**Document model**: Follow super_editor's pattern of `Document` → `List<DocumentNode>` with typed nodes and UUID IDs, but design it as a drop-in-compatible API that could replace `TextEditingValue` in Flutter's widget layer. Define `DocumentPosition` = `{nodeId, NodePosition}` and `DocumentSelection` = `{base: DocumentPosition, extent: DocumentPosition}`.

**IME bridge**: Implement `DeltaTextInputClient` (not the non-delta model) using super_editor's serialization approach — serialize only the currently-selected text node to the platform, with a synthetic minimal value for non-text or cross-block selections. This is the hardest engineering challenge.

**Rendering**: Use a `ComponentBuilder` pattern for extensible per-node rendering, but implement render objects that participate in Flutter's standard layout protocol (`RenderBox` with `ContainerRenderObjectMixin`). Target eventual placement in `packages/flutter/lib/src/rendering/` and `packages/flutter/lib/src/widgets/`.

**Selection and overlays**: Build a document-aware selection overlay system that extends (not replaces) Flutter's `SelectionOverlay`/`TextSelectionOverlay` patterns. Support per-platform handle styles (iOS handles + magnifier, Android handles + magnifier, desktop caret-only).

**Command pipeline**: Implement an event-sourced command pipeline (`EditRequest → EditCommand → EditEvent`) for all mutations, enabling undo/redo and content reactions. This is proven by super_editor's architecture.

**Testing strategy**: TDD with comprehensive widget tests, render object tests, golden tests for visual regression, IME mock tests, semantics tests, and performance benchmarks. Mirror Flutter's own test structure for merger readiness.

**Contribution path**: Start as a standalone pub.dev package, write a design doc via `flutter.dev/go/template`, engage Flutter framework team on Discord (#hackers-text-input), iterate based on feedback, then propose merger via PR series with migration guides for any breaking changes to existing `EditableText`.