# Flutter Framework Integration Guide

This guide documents the concrete steps for creating a prototype integration branch in
`flutter/flutter` to validate that `editable_document` can be merged into the Flutter
framework. The goal of such a branch is to verify that all 60 source files compile, all
tests pass, and no regressions appear in the existing framework test suite before a
formal design-doc review is initiated with the Flutter team.

---

## Prerequisites

- A fork of `flutter/flutter` on GitHub.
- A local clone of your fork with the `flutter` tool on `PATH`.
- Familiarity with Flutter's package structure under `packages/flutter/lib/src/`.
- Optional: a local Flutter engine build for performance profiling (not required for
  integration validation).

---

## Step 1 — Create the integration branch

```bash
git clone https://github.com/<your-fork>/flutter.git
cd flutter
git checkout -b editable-document-integration
```

Work entirely inside the `packages/flutter/` subtree. All paths in the steps below are
relative to the root of the `flutter/flutter` repository unless otherwise stated.

---

## Step 2 — File mapping

### Directory-level mapping

Each `editable_document` source directory maps to a framework directory as follows:

| `editable_document` path | Flutter framework path | Rationale |
|--------------------------|------------------------|-----------|
| `lib/src/model/` | `packages/flutter/lib/src/widgets/` | Model classes live alongside widgets, the same way `TextEditingController` lives in `editable_text.dart`. Could alternatively go in a new `packages/flutter/lib/src/document/` directory — see the alternative placement note at the end of this guide. |
| `lib/src/rendering/` | `packages/flutter/lib/src/rendering/` | Same directory as `RenderEditable` in `editable.dart`. |
| `lib/src/services/` | `packages/flutter/lib/src/services/` | Same directory as `TextInput` in `text_input.dart`. |
| `lib/src/widgets/` | `packages/flutter/lib/src/widgets/` | Same directory as `EditableText` in `editable_text.dart`. |
| `lib/src/widgets/gestures/` | `packages/flutter/lib/src/widgets/` | Flatten into the widgets directory; no `gestures/` subdirectory exists in the framework. |
| `lib/src/widgets/toolbar/` | `packages/flutter/lib/src/widgets/` | Flatten into the widgets directory. |

### File-level mapping (all 60 source files)

**Model layer — 24 files**

| `editable_document` source | Framework target |
|----------------------------|------------------|
| `lib/src/model/attributed_text.dart` | `packages/flutter/lib/src/widgets/attributed_text.dart` |
| `lib/src/model/attribution.dart` | `packages/flutter/lib/src/widgets/attribution.dart` |
| `lib/src/model/code_block_node.dart` | `packages/flutter/lib/src/widgets/code_block_node.dart` |
| `lib/src/model/composer_preferences.dart` | `packages/flutter/lib/src/widgets/composer_preferences.dart` |
| `lib/src/model/document.dart` | `packages/flutter/lib/src/widgets/document.dart` |
| `lib/src/model/document_change_event.dart` | `packages/flutter/lib/src/widgets/document_change_event.dart` |
| `lib/src/model/document_editing_controller.dart` | `packages/flutter/lib/src/widgets/document_editing_controller.dart` |
| `lib/src/model/document_node.dart` | `packages/flutter/lib/src/widgets/document_node.dart` |
| `lib/src/model/document_position.dart` | `packages/flutter/lib/src/widgets/document_position.dart` |
| `lib/src/model/document_selection.dart` | `packages/flutter/lib/src/widgets/document_selection.dart` |
| `lib/src/model/edit_command.dart` | `packages/flutter/lib/src/widgets/edit_command.dart` |
| `lib/src/model/edit_context.dart` | `packages/flutter/lib/src/widgets/edit_context.dart` |
| `lib/src/model/edit_listener.dart` | `packages/flutter/lib/src/widgets/edit_listener.dart` |
| `lib/src/model/edit_reaction.dart` | `packages/flutter/lib/src/widgets/edit_reaction.dart` |
| `lib/src/model/edit_request.dart` | `packages/flutter/lib/src/widgets/edit_request.dart` |
| `lib/src/model/editor.dart` | `packages/flutter/lib/src/widgets/editor.dart` |
| `lib/src/model/horizontal_rule_node.dart` | `packages/flutter/lib/src/widgets/horizontal_rule_node.dart` |
| `lib/src/model/image_node.dart` | `packages/flutter/lib/src/widgets/image_node.dart` |
| `lib/src/model/list_item_node.dart` | `packages/flutter/lib/src/widgets/list_item_node.dart` |
| `lib/src/model/mutable_document.dart` | `packages/flutter/lib/src/widgets/mutable_document.dart` |
| `lib/src/model/node_position.dart` | `packages/flutter/lib/src/widgets/node_position.dart` |
| `lib/src/model/paragraph_node.dart` | `packages/flutter/lib/src/widgets/paragraph_node.dart` |
| `lib/src/model/text_node.dart` | `packages/flutter/lib/src/widgets/text_node.dart` |
| `lib/src/model/undoable_editor.dart` | `packages/flutter/lib/src/widgets/undoable_editor.dart` |

**Rendering layer — 12 files**

| `editable_document` source | Framework target |
|----------------------------|------------------|
| `lib/src/rendering/document_caret_painter.dart` | `packages/flutter/lib/src/rendering/document_caret_painter.dart` |
| `lib/src/rendering/document_selection_painter.dart` | `packages/flutter/lib/src/rendering/document_selection_painter.dart` |
| `lib/src/rendering/render_code_block.dart` | `packages/flutter/lib/src/rendering/render_code_block.dart` |
| `lib/src/rendering/render_document_block.dart` | `packages/flutter/lib/src/rendering/render_document_block.dart` |
| `lib/src/rendering/render_document_caret.dart` | `packages/flutter/lib/src/rendering/render_document_caret.dart` |
| `lib/src/rendering/render_document_layout.dart` | `packages/flutter/lib/src/rendering/render_document_layout.dart` |
| `lib/src/rendering/render_document_selection_highlight.dart` | `packages/flutter/lib/src/rendering/render_document_selection_highlight.dart` |
| `lib/src/rendering/render_horizontal_rule_block.dart` | `packages/flutter/lib/src/rendering/render_horizontal_rule_block.dart` |
| `lib/src/rendering/render_image_block.dart` | `packages/flutter/lib/src/rendering/render_image_block.dart` |
| `lib/src/rendering/render_list_item_block.dart` | `packages/flutter/lib/src/rendering/render_list_item_block.dart` |
| `lib/src/rendering/render_paragraph_block.dart` | `packages/flutter/lib/src/rendering/render_paragraph_block.dart` |
| `lib/src/rendering/render_text_block.dart` | `packages/flutter/lib/src/rendering/render_text_block.dart` |

**Services layer — 4 files**

| `editable_document` source | Framework target |
|----------------------------|------------------|
| `lib/src/services/document_autofill_client.dart` | `packages/flutter/lib/src/services/document_autofill_client.dart` |
| `lib/src/services/document_ime_input_client.dart` | `packages/flutter/lib/src/services/document_ime_input_client.dart` |
| `lib/src/services/document_ime_serializer.dart` | `packages/flutter/lib/src/services/document_ime_serializer.dart` |
| `lib/src/services/document_keyboard_handler.dart` | `packages/flutter/lib/src/services/document_keyboard_handler.dart` |

**Widgets layer — 20 files**

| `editable_document` source | Framework target |
|----------------------------|------------------|
| `lib/src/widgets/caret_document_overlay.dart` | `packages/flutter/lib/src/widgets/caret_document_overlay.dart` |
| `lib/src/widgets/component_builder.dart` | `packages/flutter/lib/src/widgets/component_builder.dart` |
| `lib/src/widgets/document_field.dart` | `packages/flutter/lib/src/widgets/document_field.dart` |
| `lib/src/widgets/document_layout.dart` | `packages/flutter/lib/src/widgets/document_layout.dart` |
| `lib/src/widgets/document_scrollable.dart` | `packages/flutter/lib/src/widgets/document_scrollable.dart` |
| `lib/src/widgets/document_selection_overlay.dart` | `packages/flutter/lib/src/widgets/document_selection_overlay.dart` |
| `lib/src/widgets/document_semantics_scope.dart` | `packages/flutter/lib/src/widgets/document_semantics_scope.dart` |
| `lib/src/widgets/drag_handle_auto_scroller.dart` | `packages/flutter/lib/src/widgets/drag_handle_auto_scroller.dart` |
| `lib/src/widgets/editable_document.dart` | `packages/flutter/lib/src/widgets/editable_document.dart` |
| `lib/src/widgets/gestures/android_document_caret.dart` | `packages/flutter/lib/src/widgets/android_document_caret.dart` |
| `lib/src/widgets/gestures/android_document_gesture_controller.dart` | `packages/flutter/lib/src/widgets/android_document_gesture_controller.dart` |
| `lib/src/widgets/gestures/android_document_magnifier.dart` | `packages/flutter/lib/src/widgets/android_document_magnifier.dart` |
| `lib/src/widgets/gestures/android_selection_handle.dart` | `packages/flutter/lib/src/widgets/android_selection_handle.dart` |
| `lib/src/widgets/gestures/document_mouse_interactor.dart` | `packages/flutter/lib/src/widgets/document_mouse_interactor.dart` |
| `lib/src/widgets/gestures/ios_collapsed_handle.dart` | `packages/flutter/lib/src/widgets/ios_collapsed_handle.dart` |
| `lib/src/widgets/gestures/ios_document_gesture_controller.dart` | `packages/flutter/lib/src/widgets/ios_document_gesture_controller.dart` |
| `lib/src/widgets/gestures/ios_document_magnifier.dart` | `packages/flutter/lib/src/widgets/ios_document_magnifier.dart` |
| `lib/src/widgets/gestures/ios_selection_handle.dart` | `packages/flutter/lib/src/widgets/ios_selection_handle.dart` |
| `lib/src/widgets/sliver_editable_document.dart` | `packages/flutter/lib/src/widgets/sliver_editable_document.dart` |
| `lib/src/widgets/toolbar/document_text_selection_controls.dart` | `packages/flutter/lib/src/widgets/document_text_selection_controls.dart` |

---

## Step 3 — Import conversion

When files move from the package into the framework, every import must change. The
package uses relative intra-package imports and `package:flutter/…` imports for the SDK.
In the framework, files inside `packages/flutter/lib/src/` must use framework-relative
paths, never `package:flutter/…` self-references.

### Rules

- `package:flutter/foundation.dart`, `package:flutter/painting.dart`,
  `package:flutter/rendering.dart`, `package:flutter/services.dart`,
  `package:flutter/widgets.dart` imports all remain unchanged — they are external SDK
  imports that are valid from any location.
- Intra-package relative imports (e.g. `../model/document_node.dart`) become
  framework-relative sibling imports once all files are in their target directories.
- Same-layer imports become simple sibling-relative imports (bare filename or `./`
  prefix).

### Example — rendering file importing model types

```dart
// Before (in editable_document package — rendering layer):
import '../model/document_node.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';

// After (in Flutter framework — rendering file in packages/flutter/lib/src/rendering/
// importing model files now in packages/flutter/lib/src/widgets/):
import '../widgets/document_node.dart';
import '../widgets/document_position.dart';
import '../widgets/document_selection.dart';
```

### Example — widget file importing services and rendering types

```dart
// Before (in editable_document package — widgets layer):
import '../rendering/render_document_layout.dart';
import '../services/document_ime_input_client.dart';

// After (in Flutter framework — widgets file in packages/flutter/lib/src/widgets/
// importing from sibling directories):
import '../rendering/render_document_layout.dart';
import '../services/document_ime_input_client.dart';
```

The rendering and services relative paths happen to be the same because the directory
depth is identical in the framework.

### Example — same-layer import

```dart
// Before (in editable_document package — widgets layer):
import 'document_layout.dart';

// After (in Flutter framework — widgets layer, same directory):
import 'document_layout.dart';   // unchanged; same-layer sibling imports need no change
```

---

## Step 4 — Barrel file updates

Add the new exports to Flutter's three barrel files. Insert the new `export` directives
in alphabetical order within each file to match Flutter's existing style.

### `packages/flutter/lib/widgets.dart`

Add all model and widget exports:

```dart
export 'src/widgets/android_document_caret.dart';
export 'src/widgets/android_document_gesture_controller.dart';
export 'src/widgets/android_document_magnifier.dart';
export 'src/widgets/android_selection_handle.dart';
export 'src/widgets/attributed_text.dart';
export 'src/widgets/attribution.dart';
export 'src/widgets/caret_document_overlay.dart';
export 'src/widgets/code_block_node.dart';
export 'src/widgets/component_builder.dart';
export 'src/widgets/composer_preferences.dart';
export 'src/widgets/document.dart';
export 'src/widgets/document_change_event.dart';
export 'src/widgets/document_editing_controller.dart';
export 'src/widgets/document_field.dart';
export 'src/widgets/document_layout.dart';
export 'src/widgets/document_mouse_interactor.dart';
export 'src/widgets/document_node.dart';
export 'src/widgets/document_position.dart';
export 'src/widgets/document_scrollable.dart';
export 'src/widgets/document_selection.dart';
export 'src/widgets/document_selection_overlay.dart';
export 'src/widgets/document_semantics_scope.dart';
export 'src/widgets/document_text_selection_controls.dart';
export 'src/widgets/drag_handle_auto_scroller.dart';
export 'src/widgets/edit_command.dart';
export 'src/widgets/edit_context.dart';
export 'src/widgets/edit_listener.dart';
export 'src/widgets/edit_reaction.dart';
export 'src/widgets/edit_request.dart';
export 'src/widgets/editable_document.dart';
export 'src/widgets/editor.dart';
export 'src/widgets/horizontal_rule_node.dart';
export 'src/widgets/image_node.dart';
export 'src/widgets/ios_collapsed_handle.dart';
export 'src/widgets/ios_document_gesture_controller.dart';
export 'src/widgets/ios_document_magnifier.dart';
export 'src/widgets/ios_selection_handle.dart';
export 'src/widgets/list_item_node.dart';
export 'src/widgets/mutable_document.dart';
export 'src/widgets/node_position.dart';
export 'src/widgets/paragraph_node.dart';
export 'src/widgets/sliver_editable_document.dart';
export 'src/widgets/text_node.dart';
export 'src/widgets/undoable_editor.dart';
```

### `packages/flutter/lib/rendering.dart`

Add the rendering exports:

```dart
export 'src/rendering/document_caret_painter.dart';
export 'src/rendering/document_selection_painter.dart';
export 'src/rendering/render_code_block.dart';
export 'src/rendering/render_document_block.dart';
export 'src/rendering/render_document_caret.dart';
export 'src/rendering/render_document_layout.dart';
export 'src/rendering/render_document_selection_highlight.dart';
export 'src/rendering/render_horizontal_rule_block.dart';
export 'src/rendering/render_image_block.dart';
export 'src/rendering/render_list_item_block.dart';
export 'src/rendering/render_paragraph_block.dart';
export 'src/rendering/render_text_block.dart';
```

### `packages/flutter/lib/services.dart`

Add the services exports:

```dart
export 'src/services/document_autofill_client.dart';
export 'src/services/document_ime_input_client.dart';
export 'src/services/document_ime_serializer.dart';
export 'src/services/document_keyboard_handler.dart';
```

---

## Step 5 — Test mapping

Tests follow the same directory logic as source files. Each test file moves to the
framework test directory that mirrors its source layer.

| `editable_document` test path | Flutter framework test path |
|-------------------------------|-----------------------------|
| `test/src/model/` | `packages/flutter/test/widgets/` |
| `test/src/rendering/` | `packages/flutter/test/rendering/` |
| `test/src/services/` | `packages/flutter/test/services/` |
| `test/src/widgets/` | `packages/flutter/test/widgets/` |
| `test/goldens/rendering/` | `packages/flutter/test/rendering/` (golden files alongside their test) |
| `test/goldens/widgets/` | `packages/flutter/test/widgets/` (golden files alongside their test) |

After copying, update the test imports:

```dart
// Before (in editable_document test):
import 'package:editable_document/editable_document.dart';

// After (in Flutter framework test):
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
```

Any test utilities from the package's own `test/` helpers (for example
`TestDocumentEditor`) should be adapted to use Flutter's `flutter_test` infrastructure
rather than relying on the package's own test harness.

---

## Step 6 — Running the test suite

After copying files and updating imports, validate the integration with the commands
below. Run these from the `packages/flutter/` directory.

```bash
# Run the full framework test suite — catches any regression in existing tests.
cd packages/flutter
flutter test test/

# Run only the new editable_document tests to iterate quickly during the port.
flutter test test/widgets/document_*_test.dart
flutter test test/widgets/editable_document_test.dart
flutter test test/rendering/render_document_*_test.dart
flutter test test/services/document_*_test.dart

# Static analysis — must report zero errors and zero warnings.
dart analyze lib/

# Full framework-wide analysis (run this before filing the PR).
flutter analyze --flutter-repo
```

The framework's CI also runs `dart format --output=none --set-exit-if-changed .` to
reject unformatted code. Run `dart format .` locally before pushing.

---

## Step 7 — Analysis alignment

`editable_document` was deliberately designed to match Flutter's strict analysis profile
so that no changes to `packages/flutter/analysis_options.yaml` are needed. The package
already enables:

- `strict-casts: true`
- `strict-inference: true`
- `strict-raw-types: true`
- `page_width: 100`
- `public_member_api_docs` — every public symbol has `///` dartdoc
- `diagnostic_describe_all_properties` — every `RenderObject` and `Widget` subclass
  implements `debugFillProperties`

Verify that `dart doc --validate-links` produces zero warnings after the import
conversion. The framework's CI runs `dart doc` as part of its analysis gate; any
undocumented public symbol or broken `[...]` cross-reference will fail the build.

---

## Step 8 — Checklist before filing the merge PR

Work through this checklist in order. Every item must be green before the PR is opened.

- [ ] All 60 source files copied to their correct framework locations (Step 2).
- [ ] All relative imports converted to framework-relative paths (Step 3).
- [ ] All three barrel files updated with new exports (Step 4).
- [ ] All tests copied and imports updated (Step 5).
- [ ] Full test suite passes: `flutter test packages/flutter/test/`
- [ ] Static analysis clean: `flutter analyze --flutter-repo` — zero warnings.
- [ ] Dart formatter passes: `dart format --output=none --set-exit-if-changed packages/flutter/`
- [ ] `dart doc` produces zero warnings from the framework packages.
- [ ] Design doc written via `flutter.dev/go/template` and shortlink minted.
- [ ] Tracking issue filed on `flutter/flutter` with the `design doc` label.
- [ ] Initial feedback solicited on Discord `#hackers-text-input` before the PR is
  opened, as recommended by the Flutter contribution guide.
- [ ] Framework team review obtained and design doc approved.

---

## Alternative: model layer placement

There is an open question about where the model classes (`DocumentNode`,
`DocumentPosition`, `DocumentSelection`, `AttributedText`, `Editor`, and related types)
should live in the framework. Two options exist:

### Option A — All in `widgets/` (recommended starting point)

Model classes live in `packages/flutter/lib/src/widgets/` alongside
`DocumentEditingController`, matching how `TextEditingController` lives in
`editable_text.dart`. All 24 model files and all 20 widget files go into the same
`widgets/` directory.

**Pros:** Simple; follows the existing pattern; no new top-level directories; no new
barrel file.

**Cons:** The `widgets/` directory already contains many files and mixing pure data
classes (`DocumentNode`, `EditRequest`, `AttributedText`) with widget classes could be
seen as muddying the layer separation.

### Option B — New `document/` directory

Create `packages/flutter/lib/src/document/` for the 24 model files, with a new barrel
file `packages/flutter/lib/document.dart`. The 20 widget files remain in `widgets/` and
import from `../document/`.

**Pros:** Clean separation between data model and widget layer; model types become
importable independently via `package:flutter/document.dart` without pulling in the full
widget layer.

**Cons:** A new top-level barrel file and top-level directory require explicit
framework-team buy-in; adds a new layer to Flutter's hierarchy; all existing framework
files that import `package:flutter/widgets.dart` and use document types would also need
to import `package:flutter/document.dart`.

The recommendation is to start with Option A for the prototype integration branch and
raise Option B as a question during the design-doc review phase. The framework team's
preference should drive the final decision, not the prototype branch.

---

## Known limitations

### 1. Golden test regeneration required

Golden files captured in `editable_document` are platform-specific. Flutter's CI runs
on Linux with the `FlutterTest` font, which provides deterministic per-glyph metrics
(14 pt text: height = 14.0, ascent = 10.5, descent = 3.5, width = 14.0 per glyph).
Package goldens were generated on macOS and will not match the Linux CI output
pixel-for-pixel. All golden files must be regenerated in the framework's Linux CI
environment using:

```bash
flutter test --update-goldens packages/flutter/test/rendering/render_document_*_test.dart
flutter test --update-goldens packages/flutter/test/widgets/document_*_test.dart
```

Commit the regenerated golden files as part of the integration branch, not as a
separate PR.

### 2. Test utility adaptation

The package's test helpers (for example `TestDocumentEditor` and any custom
`WidgetTester` extensions) were written for the standalone package and reference
`package:editable_document/editable_document.dart`. These helpers must be rewritten to
use only `package:flutter/widgets.dart` and `package:flutter_test/flutter_test.dart`.
The adapted helpers should live in `packages/flutter/test/widgets/` alongside the tests
that use them.

### 3. IME integration test gap

Flutter currently has no mechanism to drive real `TextEditingDelta` events in widget
tests (flutter/flutter#131510). The existing `DocumentImeInputClient` tests use mock
method channel handlers to simulate IME deltas. This limitation applies equally inside
the framework; no workaround is available until the tracking issue is resolved. Ensure
mock-based IME tests are marked with a comment referencing the issue so they can be
updated when a proper test API lands.

### 4. `editor.dart` name collision

The framework already has no file named `editor.dart` in `packages/flutter/lib/src/widgets/`,
so no collision exists today. However, `editor.dart` is a generic name. If the framework
team prefers a more namespaced filename (for example `document_editor.dart`) to avoid
future conflicts, rename the file during the port and update all imports accordingly.
Raise this question in the design-doc review.
