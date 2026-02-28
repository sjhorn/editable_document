# CLAUDE.md — editable_document

> Agent system prompts live in `.claude/agents/`. This file is project context — read it fully at the start of every session.

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

---

## Agent delegation protocol

**Every agent in this project must follow this protocol.** The agent map below is not a passive reference — it defines active delegation rules you must act on.

### The standard task workflow

Every implementation task follows this exact chain, no exceptions:

```
1. Read ROADMAP.md → identify the next unchecked checkbox
2. Identify which agent owns that work (see "When to invoke each agent" below)
3. Invoke that agent: use the <name> agent to <task>
4. That agent writes the failing test, then the implementation
5. That agent says: use the qa agent to run the gate for <layer>
6. qa agent reports PASS or FAIL with diagnosis
7. If FAIL → owning agent fixes, loops back to step 5
8. If PASS → owning agent commits, ticks the ROADMAP checkbox
9. If the change adds or modifies a public API → use the docs agent to update dartdoc
```

### When to invoke each agent

| If you need to… | Say this |
|-----------------|----------|
| Create or change anything in `lib/src/model/` or `test/src/model/` | `use the model agent` |
| Create or change anything in `lib/src/rendering/` or `test/src/rendering/` | `use the rendering agent` |
| Create or change anything in `lib/src/services/` or `test/src/services/` | `use the services agent` |
| Create or change anything in `lib/src/widgets/` or `test/src/widgets/` | `use the widgets agent` |
| Write or run any end-to-end or integration UI test | `use the integration agent` |
| Run flutter test, flutter analyze, dart format, dart fix, or check coverage | `use the qa agent` |
| Write or update dartdoc, example app, README, or CHANGELOG | `use the docs agent` |
| Write or run performance benchmarks | `use the benchmark agent` |

### Mandatory handoff points — these are required, not optional

- **Before every single commit** → `use the qa agent to run the full gate`
- **After any public API surface change** → `use the docs agent to update dartdoc and examples`
- **After Phase 3 (rendering) is complete** → `use the integration agent to add golden tests`
- **After Phase 5 (widgets) is complete** → `use the integration agent to add caret and selection precision tests`
- **After Phase 9 (benchmarks) is complete** → `use the benchmark agent to record baselines`

### Cross-layer dependency order

When a ROADMAP phase touches multiple layers, invoke agents in this strict order:

```
model agent → rendering agent → services agent → widgets agent
                                                        ↓
                                               use the qa agent (run gate)
                                                        ↓
                                         use the docs agent (if API changed)
                                                        ↓
                                                     commit
```

### Agent scope — hard boundaries

Each agent owns its directory exclusively. **No agent may write files outside its scope.** If you discover you need to change something in another layer, stop — invoke that agent by name.

| Agent | Owns (read + write) | Never writes |
|-------|---------------------|--------------|
| `model` | `lib/src/model/`, `test/src/model/` | all other `lib/`, `test/` |
| `rendering` | `lib/src/rendering/`, `test/src/rendering/`, `test/goldens/rendering/` | `services/`, `widgets/` |
| `services` | `lib/src/services/`, `test/src/services/` | `rendering/`, `widgets/` |
| `widgets` | `lib/src/widgets/`, `test/src/widgets/`, `test/goldens/widgets/` | `model/`, `rendering/`, `services/` |
| `integration` | `integration_test/` | `lib/` (read only) |
| `benchmark` | `benchmark/` | `lib/` (read only) |
| `docs` | `doc/`, `example/`, `README.md`, `CHANGELOG.md` | `lib/`, `test/` |
| `qa` | runs `scripts/ci/`, reads `/tmp/ed_*.txt` | `lib/`, `test/` (read only) |

---

## Non-negotiable rules

1. **TDD is mandatory.** Write failing test first. Implement minimum. Refactor. Commit.
2. **The `qa` agent must give PASS before any commit.** Never run `flutter analyze`, `flutter test`, or `dart format` directly — always use the `qa` agent and its `scripts/ci/` wrappers.
3. **Every public symbol has `///` dartdoc.** `dart doc` must produce zero warnings.
4. **Zero external dependencies.** Flutter SDK only.
5. **100 % branch coverage on `lib/src/services/`.** ≥ 90 % overall.
6. **Golden tests** for all pixel-drawing code. Update only via the `qa` agent on Linux (`bash scripts/ci/flutter_test.sh --update-goldens`).
7. **Commit messages:** `type(scope): description` — one ROADMAP checkbox per commit maximum.

---

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

---

## Quick-start

```bash
# 1. Orient yourself
cat ROADMAP.md                          # find next unchecked checkbox

# 2. Identify and invoke the right agent
#    e.g. "use the model agent to implement DocumentNode"

# 3. After implementation, always run the gate via qa agent
#    e.g. "use the qa agent to run the full gate"
bash scripts/ci/ci_gate.sh
bash scripts/ci/log_tail.sh summary

# 4. Inspect any failures
bash scripts/ci/log_tail.sh failures
```

**Never type `flutter test`, `flutter analyze`, or `dart format` directly. Always go through the `qa` agent.**

---

## Key source references

| `editable_document` class | Flutter / super_editor source to study |
|---------------------------|----------------------------------------|
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