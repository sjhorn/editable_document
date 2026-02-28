# CLAUDE.md — editable_document

> Agent system prompts live in `.claude/agents/`. This file is project context only.

The roadmap is in ./ROADMAP.md and background is in ./doc/BACKGROUND.md

## Project identity

| Key | Value |
|-----|-------|
| Package | `editable_document` |
| pub.dev | https://pub.dev/packages/editable_document |
| GitHub | https://github.com/sjhorn/editable_document |
| Primary widget | `EditableDocument` — mirrors `EditableText` for block documents |
| Goal | Drop-in replacement for `EditableText`/`TextField`; eventual Flutter framework merge |
| SDK | `>=3.3.0 <4.0.0` |
| Platforms | iOS · Android · Web · macOS · Windows · Linux |
| External deps | **Zero** (Flutter SDK only — merger prerequisite) |
| License | BSD-3-Clause |

## Agent map

| Agent | Scope | Trigger |
|-------|-------|---------|
| `model` | `lib/src/model/`, `test/src/model/` | DocumentNode, AttributedText, DocumentSelection, document data layer |
| `rendering` | `lib/src/rendering/`, `test/src/rendering/`, `test/goldens/rendering/` | RenderObjects, painting, layout, golden tests |
| `services` | `lib/src/services/`, `test/src/services/` | IME, TextInputClient, keyboard, autofill, platform channels |
| `widgets` | `lib/src/widgets/`, `test/src/widgets/`, `test/goldens/widgets/` | StatefulWidgets, EditableDocument, handles, overlays, scrolling |
| `integration` | `integration_test/` | End-to-end UI tests, caret precision, selection drawing, mobile handles |
| `benchmark` | `benchmark/` | Performance benchmarks, frame budget, jank measurement |
| `docs` | `doc/`, `example/`, `README.md`, `CHANGELOG.md` | Documentation, example app, migration guide |

## Non-negotiable rules

1. **TDD is mandatory.** Write failing test first. Implement minimum. Refactor. Commit.
2. **`flutter analyze` and `dart format --line-length 100` must pass** before any commit.
3. **Every public symbol has `///` dartdoc.** `dart doc` must produce zero warnings.
4. **Zero external dependencies.** Flutter SDK only.
5. **100 % branch coverage on `lib/src/services/`.** ≥ 90 % overall.
6. **Golden tests are required** for all pixel-drawing code. Update only via `--update-goldens` on Linux.
7. **Commit messages:** `type(scope): description` — one ROADMAP checkbox per commit maximum.

## Layering law

Dependencies flow **downward only**:

```
model  ←  rendering  ←  services  ←  widgets
```

| Layer | Allowed Flutter imports |
|-------|------------------------|
| `model` | `foundation`, `painting` (TextAffinity only) |
| `rendering` | `foundation`, `painting`, `rendering`, `scheduler` |
| `services` | `foundation`, `painting`, `services` |
| `widgets` | All Flutter layers |

## Quick-start

```bash
cat ROADMAP.md            # Find next unchecked checkbox
flutter analyze           # Must be clean
flutter test              # Must all pass
dart format --line-length 100 --set-exit-if-changed .
```

## Key source references

| `editable_document` class | Flutter/super_editor source to study |
|---------------------------|--------------------------------------|
| `DocumentEditingController` | `widgets/editable_text.dart` → `TextEditingController` |
| `DocumentImeInputClient` | `widgets/editable_text.dart` → `EditableTextState` |
| `DocumentImeSerializer` | super_editor `document_ime_serializer.dart` |
| `RenderDocumentLayout` | `rendering/editable.dart` → `RenderEditable` |
| `DocumentSelectionOverlay` | `widgets/text_selection.dart` → `TextSelectionOverlay` |
| `DefaultDocumentShortcuts` | `widgets/default_text_editing_shortcuts.dart` |
| `ComponentBuilder` | super_editor `component_builder.dart` |
| `Editor` / `EditRequest` | super_editor `editor.dart` |

## Relevant Flutter issues

- [#90205](https://github.com/flutter/flutter/pull/90205) — `DeltaTextInputClient` PR (IME delta model)
- [#90684](https://github.com/flutter/flutter/pull/90684) — Actions moved to `EditableTextState`
- [#131510](https://github.com/flutter/flutter/issues/131510) — IME testing gap
- super_editor [#522](https://github.com/superlistapp/super_editor/discussions/522) — `TextInputClient` pain points