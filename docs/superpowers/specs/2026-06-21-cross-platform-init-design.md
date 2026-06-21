# Cross-Platform `init` — Design Spec

**Date:** 2026-06-21
**Status:** Approved (brainstormed)
**Relation:** Extends the [review-pro-stack CLI spec](./2026-06-21-review-pro-stack-cli-design.md) with multi-platform install targets.

---

## 1. Purpose

Make `npx review-pro init` install the review-pro core into **four** platforms — opencode, Claude Code, Cursor, Codex — **without maintaining duplicated agent files**. A single canonical source (`core/`) is consumed by every platform; only Codex needs a format transform (its agents are TOML, not Markdown).

## 2. Canonical source model (key decision)

`core/` is the **single source of truth** and is already platform-portable:

- `core/skills/<n>/SKILL.md` — rubrics. All four platforms read `SKILL.md` (YAML frontmatter `name`/`description` + markdown) per the Agent Skills open standard.
- `core/agents/<n>-reviewer.md` — subagent definitions. Frontmatter is made **dual-field** so the same file works on every Markdown platform:

```yaml
---
name: security-reviewer
description: Security reviewer. ...
loads_skill: security        # opencode
skills: [security]           # Claude Code (preloads the skill into the subagent)
---
<body>                       # platform-neutral role instructions
```

Platforms ignore unknown frontmatter keys, so one file serves opencode + Claude Code + Cursor. **No per-platform agent copies.**

Agent bodies are reworded to be platform-neutral: "Your core `<skill>` skill is provided (auto-loaded / preloaded / co-located). Apply it plus any `### Stack signals`." Each platform resolves "provided" via its own mechanism (opencode `loads_skill`; Claude Code `skills:` preload; Cursor co-location in the plugin; Codex `skills.config` path).

## 3. Per-platform consumption

| Platform | Skills destination | Agents destination | Agent format | Copy/Transform |
|---|---|---|---|---|
| **opencode** | `~/.config/opencode/skills/<n>/` | `~/.config/opencode/agents/` | `.md` (dual frontmatter) | copy as-is |
| **Claude Code** | `~/.claude/skills/<n>/SKILL.md` | `~/.claude/agents/<n>.md` | `.md` (`skills:` preload) | copy as-is |
| **Cursor** | repo **is** the plugin (`./core/skills/`) | `./core/agents/` | `.md` (name/description/body) | none — `/add-plugin` reads the repo; CLI copy is fallback |
| **Codex** | `~/.codex/skills/<n>/SKILL.md` | `~/.codex/agents/<n>.toml` | `.toml` | **transform `.md` → `.toml`** at install |

Homes overridable by env: `$OPENCODE_HOME`, `~/.claude` (no env standard), `~/.cursor`, `$CODEX_HOME` (default `~/.codex`).

### Cursor: repo-as-plugin
Add `.cursor-plugin/plugin.json` at the **repo root** declaring `skills: "./core/skills/"` and `agents: "./core/agents/"`. Then `Cursor → /add-plugin <local-path-or-git-url>` loads review-pro directly — **zero copies** (the thermos model). Manifest fields mirror the thermos schema: `name`, `displayName`, `version`, `description`, `author`, `license`, `skills`, `agents`. If Cursor rejects nested `./core/...` paths, the CLI fallback copies `core/skills` + `core/agents` + the manifest into a flat `~/.cursor/plugins/review-pro/<version>/`.

### Codex: `.md` → `.toml` transform
Codex custom agents are TOML under `~/.codex/agents/`. The CLI transforms each canonical reviewer `.md` into:
```toml
name = "security-reviewer"
description = "..."
sandbox_mode = "read-only"
developer_instructions = """
<body>
"""
[[skills.config]]
path = "/abs/home/.codex/skills/security/SKILL.md"
```
The `path` is resolved to the absolute Codex skills location at install time. Only the 12 **reviewer** agents become TOML; triage and synthesis run **inline** in the `review-pro` orchestrator skill (as on every platform), so no triage/synthesize TOML agents are needed.

Codex fan-out is native: the `review-pro` skill tells Codex to "spawn the dispatched reviewer agents in parallel, wait for all, synthesize" — Codex's documented orchestration model.

## 4. CLI `init --target`

```
npx review-pro init                                # default: opencode (backward-compatible)
npx review-pro init --target claude-code
npx review-pro init --target cursor                # flat-copy into ~/.cursor/plugins/
npx review-pro init --target codex
npx review-pro init --target all                   # all four
npx review-pro init --target auto                  # detect installed homes, install to each
```

`init` always: copies `core/skills/` to the platform's skills dir + the platform's agents (as-is for `.md` platforms; transformed for Codex) + writes any platform manifest. Then runs the interactive stack selection into `./.review-pro/` unless `--no-stacks`. Global `--where`/`--opencode-home` style overrides generalize to `--<platform>-home` per target (reserved; v1 uses env + defaults).

**Cursor note:** `--target cursor` performs the flat copy into `~/.cursor/plugins/review-pro/<version>/`. Separately, because the repo root has `.cursor-plugin/plugin.json`, `Cursor → /add-plugin <repo>` works without any CLI step — both paths are valid; the README documents both.

## 5. Ripple effects

- **`core/agents/*.md` frontmatter:** add `skills: [<loads_skill value>]` to each (dual-field). Reword bodies to platform-neutral wording. opencode behavior unchanged (still reads `loads_skill`).
- **`manifest.json`:** skills list stays (portable). Agents already listed; no per-platform agent entries needed.
- **`.cursor-plugin/plugin.json`:** new, at repo root.
- **CLI `lib/plugin.ts`:** `installCore(target)` generalized — per-target destination dirs + Codex agent transform.
- **CLI `lib/agents.ts` (new):** `mdToCodexToml(canonicalMd, skillsAbsRoot)` transform + a small parser for the canonical frontmatter.
- **`build-assets.mjs`:** bundles `core/` (skills+agents+shared) and the Cursor `plugin.json` into the npm package so `init` can install any platform offline.
- **Validator:** no change to agent checks (still scans `core/agents/*.md`); guardrail still "agent frontmatter only in `core/agents/`." The new `skills:` field is tolerated. Add a check that each agent's `skills:` value matches its `loads_skill` (consistency).

## 6. MVP scope

**In scope:**
- 4 targets (opencode refactor to the generalized installer; Claude Code copy; Cursor repo-as-plugin + flat-copy fallback; Codex transform).
- Dual-field canonical agent frontmatter + neutral body rewording.
- `--target all|auto|<platform>`.
- Cursor `.cursor-plugin/plugin.json` at repo root.
- Codex `.md`→`.toml` transform + skills to `~/.codex/skills/`.
- Updated `build-assets` + tests for the transform and per-target install.

**Post-MVP:** per-platform home overrides (`--codex-home` etc.), marketplace publishing for Cursor, `--json` output, remote/registry (not planned — all packs in repo).

## 7. Risks / verification

- **Cursor nested plugin paths:** verify `/add-plugin` accepts `./core/skills/`. If not, use the flat-copy fallback. Verify at implementation against a real Cursor.
- **Dual-frontmatter tolerance:** verify opencode and Cursor ignore the extra `skills:` key (unknown YAML keys are typically ignored). If a platform rejects it, the CLI strips per-target at copy time.
- **Codex skills location:** confirm `~/.codex/skills/` is the right place (vs. only path-referenced). Using explicit `skills.config` paths is robust either way.
