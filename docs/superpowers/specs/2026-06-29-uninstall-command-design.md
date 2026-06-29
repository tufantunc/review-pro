# `uninstall` Command — Design Spec

**Date:** 2026-06-29
**Status:** Approved (brainstormed)
**Relation:** Inverse of the [cross-platform `init` spec](./2026-06-21-cross-platform-init-design.md).

---

## 1. Purpose

Add `npx review-pro uninstall` — the clean inverse of `init`. It removes the review-pro **core** (the 14 subagents + 15 skills `init` copies into a tool's home), leaving no residue. Stack packs (`.review-pro/`) are repo-local and untouched; the command prints guidance for removing them.

## 2. Decisions (from brainstorm)

- **Target selection** — mirrors `init` exactly: arg-less + TTY prompts (detected installs checked); `--target <platform|all|auto>` supported; same `resolveTargets` resolver (`all` / `auto` / single / comma-list).
- **Stack packs** — guidance message only. The command never touches `.review-pro/`.
- **Deletion logic — Approach A (manifest-driven).** The deletion list is derived from the bundled plugin directory (`resolvePluginDir()` → `skills/*` folder names + `agents/*.md` basenames), which is the *same source* `installCore` copies from. This guarantees a perfect inverse with no build changes and no extra marker files. (The repo-root `manifest.json` is not bundled at runtime; it is only used at build time to generate `catalog/reviewers.json`.)

## 3. Command interface

```bash
npx review-pro uninstall                    # TTY: interactive platform select (detected = checked)
npx review-pro uninstall --target opencode  # opencode | claude-code | codex | all | auto
npx review-pro uninstall --target all -y    # skip confirmation (CI-safe)
```

Registered in `cli/src/cli.ts` with options `-t, --target <platform>` and `-y, --yes`. The `--where` global option is inherited but only affects the stack-pack guidance message (no repo writes).

## 4. What gets removed (per target)

The lists below are derived at runtime by scanning `resolvePluginDir()`:

- **skills** — every subdirectory of `<pluginDir>/skills/` (15 names: `review-pro`, `review-pro-triage`, `review-pro-synthesize`, `security`, `correctness`, `craft`, `ai-antipatterns`, `dry`, `performance`, `backend`, `frontend`, `a11y`, `db`, `api-contract`, `tests`).
- **agents** — every `*.md` basename in `<pluginDir>/agents/` (14 names). For Codex the orchestrator agents are skipped, mirroring `installCore`'s `ORCHESTRATOR_SKILLS` filter (`review-pro-triage`, `review-pro-synthesize`) via `parseAgentMd(...).loads_skill`.

| Target | Skills removed | Agents removed |
|---|---|---|
| **opencode** | `$OPENCODE_HOME/skills/<name>/` | `$OPENCODE_HOME/agents/<name>.md` |
| **claude-code** | `~/.claude/skills/<name>/` | `~/.claude/agents/<name>.md` |
| **codex** | `~/.agents/skills/<name>/` | `~/.codex/agents/<name>.toml` (reviewer agents only — orchestrators skipped) |
| **cursor** | *(no filesystem deletion)* | prints `/remove-plugin` guidance |

Home resolution reuses `resolveHome(target)` (`$OPENCODE_HOME` / `$CODEX_HOME` honoured). Each entry is deleted with `fs.rmSync(path, { force: true, recursive: true })` — **missing entries are silently skipped** (idempotent). Parent `skills/` and `agents/` directories are **never deleted** — they belong to the tool, not review-pro.

## 5. Safety

Two gates, mirroring `init`'s TTY-gate conventions:

- **Platform selection:** needs a TTY (interactive select) **or** `--target`. Non-TTY without `--target` → fail with guidance.
- **Confirmation:** needs a TTY (confirm prompt) **or** `-y`. Non-TTY without `-y` → fail with guidance (a destructive op must not run silently).

So the fully non-interactive path is `uninstall --target <...> -y`. In TTY the confirmation prompt lists what will be removed (e.g. "15 skills + 14 agents will be removed from ~/.claude").

- Only manifest-derived names are touched; a user's own skills/agents are never affected.

## 6. Stack-pack guidance (printed after core removal)

```
Stack packs live in your repo's .review-pro/ and are not removed by this command.
To remove them:  npx review-pro remove <stack>
          or:    rm -rf .review-pro
```

## 7. Code structure

| File | Change |
|---|---|
| `cli/src/lib/plugin.ts` | Add `uninstallCore(target, pluginDir?, home?, skillsHome?)` — mirrors `installCore`'s signature and switch, deletes instead of copies. Reuses `resolvePluginDir`, `resolveHome`, `ORCHESTRATOR_SKILLS`, `parseAgentMd`. Add `resolveTargets(target)` + export it (moved from `init.ts` so both commands share it — DRY). |
| `cli/src/commands/uninstall.ts` | New command: resolve targets (interactive select or `--target`), confirm (unless `-y`), call `uninstallCore` per target, print Cursor guidance + stack-pack guidance. Parallel structure to `init.ts`. |
| `cli/src/commands/init.ts` | Replace its local `resolveTargets` with the shared `lib/plugin.ts` export (no behaviour change). |
| `cli/src/cli.ts` | Register the `uninstall` command with `--target` + `--yes` options. |

## 8. Tests (`cli/tests/`)

Temp tool-home fixture: run `installCore` then `uninstallCore`, assert:

- all skill folders + agent files gone;
- parent `skills/` / `agents/` dirs still present;
- idempotent — second `uninstallCore` call throws nothing;
- **codex** — orchestrator `.toml` files are *not* deleted (init never wrote them); reviewer `.toml` files are;
- parametrised over opencode, claude-code, codex (cursor is guidance-only, no filesystem).

Command-level: `uninstall` with `--target all -y` removes from all detected homes; missing installs are a no-op (not an error).

## 9. Documentation updates

| Surface | Change |
|---|---|
| `cli/README.md` | Add `uninstall` row to the Commands table; short "Uninstall" note after the Install section. |
| Repo `README.md` | One-liner under "Install (one-time)": `npx review-pro uninstall --target <platform>` removes the core; stack packs are repo-local. |
| `adapters/opencode/README.md` (+ other adapter READMEs) | Symmetric "Uninstall" sub-section under Install: same `--target` logic + what it deletes; Cursor `/remove-plugin` guidance. |
| Website docs (`docs-src/docs.html`) | New `<tr>` in Commands table: `uninstall [--target <platform>]` → `{{docs.commands.r8}}`. |
| Website i18n (`docs-src/i18n/*.json`) | Add `docs.commands.r8` to **all 7** dicts (`en, tr, zh, hi, de, fr, nl`) — `assertParity` enforces equal keys. |
| Website build | Run `node scripts/build-site.js` to regenerate all 7 `docs/<lang>/docs.html` + root `docs/docs.html`; run `build-site.test.js`. |
| Website homepage (`index.html`) | **No change** (per requirement — not surfaced on the landing page). |

### Implementation order

1. CLI: `uninstallCore` + `resolveTargets` move + `uninstall.ts` + `cli.ts` wiring.
2. Tests; `npm test` green.
3. READMEs (`cli`, repo root, adapters).
4. Website: `docs-src/docs.html` row + 7 i18n dicts → rebuild → `build-site.test.js` green.

## 10. Edge cases & non-goals

- **Version drift** — if the running CLI's bundled plugin dir lists names that differ from an older install (e.g. a skill added after the install), uninstall only removes what the *current* manifest knows. Skill/agent names are additive and stable, so this is low-risk and accepted. (Marking-file Approach C was rejected precisely to avoid leaving a marker behind.)
- **Non-goal:** removing stack packs (`.review-pro/`) — guidance only.
- **Non-goal:** removing the user's own/custom skills or agents.
- **Non-goal:** uninstalling Cursor via filesystem (it is plugin-managed; `/remove-plugin` only).
