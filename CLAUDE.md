# CLAUDE.md — editable_document

> Agent system prompts live in `.claude/agents/`. This file is project context — read it fully at the start of every session.

The roadmap is in ./ROADMAP.md and background is in ./doc/BACKGROUND.md

For reference to the EditableText and related dart/flutter source use ./.flutter_src
.
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
8. If PASS → owning agent commits
9. Orchestrator ticks the completed ROADMAP.md checkbox(es) — `- [ ]` → `- [x]`
10. If the change adds or modifies a public API → use the docs agent to update dartdoc
11. use the docs agent to update example/main.dart to demonstrate the new feature
```

**IMPORTANT:** Step 9 is the orchestrator's job (not the agent's) because ROADMAP.md is outside agent write scope. The orchestrator must tick checkboxes after every successful commit — never skip this step.

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
- **After every phase completion** → `use the docs agent to update example/main.dart` so the example always demonstrates the latest features
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
| `qa` | runs MCP tools (`mcp__dart__*`, `mcp__server-git__*`), `scripts/ci/coverage.sh`, `scripts/ci/benchmark.sh` | `lib/`, `test/` (read only) |

---

## Non-negotiable rules

1. **TDD is mandatory.** Write failing test first. Implement minimum. Refactor. Commit.
2. **The `qa` agent must give PASS before any commit.** Never run `flutter analyze`, `flutter test`, or `dart format` directly — always use the `qa` agent (which uses MCP tools `mcp__dart__*`).
3. **Every public symbol has `///` dartdoc.** `dart doc` must produce zero warnings.
4. **Zero external dependencies.** Flutter SDK only.
5. **100 % branch coverage on `lib/src/services/`.** ≥ 90 % overall.
6. **Coverage gate before every commit.** Run `./scripts/ci/coverage_check.sh 90` and verify it passes before committing. If new code drops coverage below 90%, add tests for the new code paths in the same commit. Never commit code that lowers coverage below the gate — the CI will reject it.
7. **Golden tests** for all pixel-drawing code. Update only via the `qa` agent on Linux (`scripts/ci/flutter_test.sh --update-goldens` — this is the one case where the script is still needed, as MCP has no `--update-goldens` flag).
8. **Commit messages:** `type(scope): description` — one ROADMAP checkbox per commit maximum.
9. **No `$()` in Bash tool calls.** Claude Code blocks command substitution `$()` in Bash tool arguments. Never use `$()` in any Bash tool call — write intermediate values to temp files instead. (`$()` inside `.sh` script files is fine — the restriction only applies to Bash tool call arguments.)
10. **Use `scripts/ci/sed.sh` instead of raw `sed`.** Never call `sed` directly in Bash tool calls — use `scripts/ci/sed.sh <args>` instead. The wrapper is in the permission allowlist so it runs without interactive prompts.

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

```
1. Read ROADMAP.md → find next unchecked checkbox
2. Identify and invoke the right agent
   e.g. "use the model agent to implement DocumentNode"
3. After implementation, always run the gate via qa agent
   e.g. "use the qa agent to run the full gate"
   The qa agent runs: mcp__dart__analyze_files → mcp__dart__dart_format → mcp__dart__run_tests
4. The qa agent reports PASS/FAIL with diagnosis — no log files to inspect
5. Before committing, verify coverage ≥ 90%: ./scripts/ci/coverage_check.sh 90
```

**Never type `flutter test`, `flutter analyze`, or `dart format` directly. Always go through the `qa` agent.**

**Prefer MCP tools (`mcp__dart__*`) over shell commands** for testing, analysis, formatting, and fixes. MCP tools return results directly — no `/tmp` log files or shell redirect workarounds needed.

**Run benchmarks via `scripts/ci/benchmark.sh`.** The script handles pipe redirections and output capture internally — agents should never use raw `flutter test` for benchmarks.

---

## Dart MCP tools

The Dart MCP server provides native tool calls for development tasks. The `qa` agent uses these for quality gates; other agents should delegate to the `qa` agent rather than calling them directly.

| MCP tool | Purpose |
|----------|---------|
| `mcp__dart__run_tests` | Run tests (supports path, coverage, name filter, fail-fast) |
| `mcp__dart__analyze_files` | Static analysis (supports path scoping) |
| `mcp__dart__dart_format` | Check/apply formatting (respects `page_width: 100`) |
| `mcp__dart__dart_fix` | Apply dart fix auto-corrections |
| `mcp__dart__hover` | Get type/doc info at a source location |
| `mcp__dart__resolve_workspace_symbol` | Find symbols by name across the workspace |
| `mcp__dart__pub` | Run pub commands (get, upgrade, etc.) |
| `mcp__dart__pub_dev_search` | Search pub.dev for packages |
| `mcp__dart__launch_app` | Launch the app on a device |
| `mcp__dart__hot_reload` / `hot_restart` | Hot reload/restart a running app |
| `mcp__dart__get_widget_tree` | Inspect the widget tree of a running app |

## Git MCP tools

The git MCP server provides native tool calls for local git operations. **Prefer these over `git` CLI commands** — especially `mcp__server-git__git_commit` which accepts the message as a parameter (no temp file workaround needed).

| MCP tool | Purpose |
|----------|---------|
| `mcp__server-git__git_status` | Working tree status |
| `mcp__server-git__git_add` | Stage files |
| `mcp__server-git__git_commit` | Commit with message parameter |
| `mcp__server-git__git_diff` | Diff between branches/commits |
| `mcp__server-git__git_diff_staged` | Show staged changes |
| `mcp__server-git__git_diff_unstaged` | Show unstaged changes |
| `mcp__server-git__git_log` | Commit history |
| `mcp__server-git__git_show` | Show commit contents |
| `mcp__server-git__git_reset` | Unstage all |
| `mcp__server-git__git_branch` | List branches |
| `mcp__server-git__git_create_branch` | Create branch |
| `mcp__server-git__git_checkout` | Switch branches |

## GitHub MCP tools

The GitHub MCP server provides native tool calls for remote repository operations. Use these instead of `gh` CLI commands.

| MCP tool | Purpose |
|----------|---------|
| `mcp__github__create_pull_request` | Create a PR |
| `mcp__github__list_pull_requests` | List PRs |
| `mcp__github__pull_request_read` | Read PR details |
| `mcp__github__add_issue_comment` | Comment on an issue |
| `mcp__github__issue_read` / `issue_write` | Read/create issues |
| `mcp__github__search_code` | Search code across repos |
| `mcp__github__list_commits` | List recent commits |

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