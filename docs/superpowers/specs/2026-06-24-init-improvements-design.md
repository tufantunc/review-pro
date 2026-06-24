# init Improvements — Design Spec

**Date:** 2026-06-24
**Status:** Approved (brainstormed)
**Relation:** Fixes issues in the [cross-platform init spec](./2026-06-21-cross-platform-init-design.md) + CLI behavior.

---

## 1. Problems

Three issues with the current `init` + platform-install:

1. **`init` defaults to opencode silently** — no choice; user must know `--target`.
2. **Stack install in wrong directory** — `init` runs stack selection in cwd; if cwd isn't the project root, `.review-pro/` lands in the wrong place with no warning.
3. **Cursor install broken** — flat-copy to `~/.cursor/plugins/` doesn't work; Cursor doesn't discover manually-placed plugins.
4. **Codex skills wrong path** — installed to `~/.codex/skills/`; Codex reads USER skills from `~/.agents/skills/`. Agent TOML `[[skills.config]]` is unnecessary (it's a config.toml feature, not an agent feature) and points to the wrong path.

## 2. Verification results (from official docs)

| Platform | Skills | Agents | Status |
|---|---|---|---|
| opencode | `~/.config/opencode/skills/` | `~/.config/opencode/agents/` | ✅ correct (tested) |
| Claude Code | `~/.claude/skills/` | `~/.claude/agents/` | ✅ correct (docs confirmed) |
| Cursor | flat-copy `~/.cursor/plugins/` | same | ❌ broken → use `/add-plugin` |
| Codex | `~/.codex/skills/` → **`~/.agents/skills/`** | `~/.codex/agents/` | ❌ skills path wrong; TOML `skills.config` unnecessary |

## 3. Changes

### 3.1 Interactive platform selection (replaces default-to-opencode)

**New `init` flow (TTY):**
1. `@inquirer/prompts` checkbox: {opencode, Claude Code, Cursor, Codex}. Default-checked: auto-detected (homes that exist).
2. For each selected platform: install core.
   - opencode/Claude Code/Codex → `installCore(platform)` (filesystem copy).
   - Cursor → print `/add-plugin` guidance (no copy).
3. Project-root check → if not a project root, warn about stack location.
4. Interactive stack selection (existing checkbox, if stacks requested).
5. Print restart reminder.

**Non-interactive:**
- `--target <platform|all|auto>` (comma-separated or keywords). Skips the checkbox.
- `--no-stacks` skips the stack phase.
- Non-TTY without `--target`: error "Use --target in CI."

### 3.2 Project-root check (before stack phase)

After platform install, before the interactive stack phase (or `add` via `--target`):
- Check: does cwd have `.git/` or any project manifest (`package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `requirements.txt`, `pom.xml`, `build.gradle`, `Gemfile`, `.csproj`, etc.) or `.review-pro/` already?
- If NOT a project root:
  - Print warning: "This doesn't look like a project root (no .git or project manifest found). Stack packs install into ./.review-pro/. Run from your project root, or use --where <path>."
  - If interactive: offer "Skip stack installation? [Y/n]". Default: skip.
  - If non-interactive (`--target` without `--no-stacks`): print warning and skip stacks.

### 3.3 Cursor fix: `/add-plugin` guidance (no filesystem copy)

- Remove `case "cursor"` flat-copy from `installCore()`.
- Replace with `guideCursor()`:
  ```
  Cursor plugins are installed via /add-plugin.
  Run in Cursor: /add-plugin https://github.com/tufantunc/review-pro
  ```
- The repo `.cursor-plugin/plugin.json` at root stays (Cursor reads it).
- In the interactive platform selection, cursor is listed; its "install" = print guidance.

### 3.4 Codex fix: correct skill path + simplified TOML

- **Skills path:** `~/.codex/skills/` → **`~/.agents/skills/`** (Codex USER skill location per official docs).
- **Agent TOML:** remove `[[skills.config]]` section entirely. It was wrong (config.toml feature, not agent feature) and pointed to the wrong path.
- Agent TOML after fix:
  ```toml
  name = "security-reviewer"
  description = "..."
  sandbox_mode = "read-only"
  developer_instructions = """
  <body>
  """
  ```
- The `developer_instructions` body references the reviewer skill by name ("use the `security` skill to review…"). Codex auto-discovers skills from `~/.agents/skills/` and the spawned agent inherits the parent session's skill set.
- `installCore("codex")` updated: skills → `~/.agents/skills/`, agents → `~/.codex/agents/` (unchanged).
- `mdToCodexToml()` simplified: remove the `[[skills.config]]` block.

## 4. Ripple effects

- **`cli/src/lib/plugin.ts`:**
  - `resolveHome("codex")` skills part: skills go to `~/.agents/skills/`, agents stay at `~/.codex/agents/`.
  - `installCore("codex")`: copy skills to `path.join(home, ".agents", "skills")` where home = `os.homedir()`. Agents to `path.join(codexHome, "agents")` where codexHome = `$CODEX_HOME || ~/.codex`.
  - `installCore("cursor")`: remove flat-copy, call `guideCursor()`.
- **`cli/src/lib/agents.ts`:** `mdToCodexToml()` remove `[[skills.config]]` block + `skillsAbsDir` parameter.
- **`cli/src/commands/init.ts`:** interactive platform checkbox + project-root check + revised flow.
- **`cli/tests/`:** update `plugin-cross.test.ts` (codex skills path, cursor = guidance not copy, no `[[skills.config]]` in TOML).
- **Docs:** `docs.html` per-platform notes + `cli/README.md` update.

## 5. MVP scope

All 4 changes in one release (0.2.0 — minor bump, new behavior).
