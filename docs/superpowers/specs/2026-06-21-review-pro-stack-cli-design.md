# review-pro-stack CLI — Design Spec

**Date:** 2026-06-21
**Status:** Approved (brainstormed)
**Relation:** Companion CLI to the review-pro plugin (same repo, separate npm package). Implements the `.review-pro/` stack-install model defined in the [review-pro design spec](./2026-06-20-review-pro-design.md) §8.

---

## 1. Purpose

`review-pro-stack` is the one-command installer for the review-pro ecosystem. It replaces all user-run shell scripts (`install.sh`, `compose-rubric.sh` — the latter already removed). It:

- Installs the **core plugin** (skills + agents) into opencode (`init`).
- Installs/removes/updates **stack packs** into a repo's `.review-pro/` (`add`/`remove`/`update`/interactive).
- Validates installed packs (`doctor`).

It ships as a **single npm package** (`review-pro-stack`) whose source lives in this repo under `cli/`. The plugin loaders are unaffected: only `core/skills/*/SKILL.md` and `core/agents/*.md` are ever loaded as plugin content.

## 2. Decisions locked (from brainstorming)

- **Same repo**, `cli/` subdirectory, npm package name `review-pro-stack`.
- **Full command set** for v1: interactive default + `list` + `add` + `remove` + `update` + `init` + `doctor`.
- **`init` is Node-native and cross-platform** (no bash) — targets opencode for v1; replaces `adapters/opencode/install.sh`.
- **Version lives inside each stack**, not in a central lockfile: `"version"` in `stacks/<pack>/manifest.json`, copied verbatim into `.review-pro/<stack>/manifest.json`. Keeps the CLI optional (manual `cp` carries the version too).
- **Tech stack:** TypeScript + `@inquirer/prompts` (interactive multi-select) + `commander` (arg parsing) + `tsup` (build) + `vitest` (tests).
- **Self-contained npm package:** build bundles `dist` + `catalog` (from `stacks/`) + `plugin` (from `core/`) into the published package.

## 3. Repository structure (additions)

```
review-pro/
  core/{skills,agents,shared}/      # plugin — unchanged
  stacks/<pack>/manifest.json       # catalog — now carries "version"
  adapters/opencode/install.sh      # REMOVED (init replaces it)
  cli/                              # NEW — npm package "review-pro-stack"
    package.json                    # name, bin, files, scripts, deps
    tsconfig.json
    tsup.config.ts
    src/
      cli.ts                        # entry; commander program
      commands/
        interactive.ts              # default (no-arg) multi-select install
        list.ts
        add.ts
        remove.ts
        update.ts
        init.ts
        doctor.ts
      lib/
        catalog.ts                  # read bundled catalog/ (list stacks + versions)
        repo.ts                     # .review-pro/ read/write helpers
        plugin.ts                   # core install (opencode home detection + copy)
        manifest.ts                 # parse/validate stack manifest.json
        log.ts                      # consistent output
      types.ts
    tests/                          # vitest unit tests
  scripts/validate.sh (+ .test.sh)  # gains two guardrail rules
```

## 4. `.review-pro/` layout & version model

```
<target-repo>/.review-pro/
  typescript-react/
    manifest.json      { "name": "typescript-react", "version": "0.1.0", "reviewers": [...] }
    security.md
    correctness.md
    ...
  node/
    manifest.json      { "name": "node", "version": "0.1.0", "reviewers": [...] }
    ...
```

- The `version` field is the **only** source of truth for an installed stack's version.
- No `.review-pro/.review-pro.json` or any central lockfile.
- The agent reads `.review-pro/<stack>/<reviewer>.md` for stack signals exactly as before; `version` is metadata it ignores at review time.

Source packs gain the same field: `stacks/<pack>/manifest.json` → `{ "name", "version", "reviewers" }`. Existing packs (typescript-react, node) get `"version": "0.1.0"`.

## 5. Command reference

All commands operate on **cwd** by default; `--where <path>` (global option) overrides the target repo path. `init` additionally targets the opencode home (`$OPENCODE_HOME` or `~/.config/opencode`), overridable via `--opencode-home <path>`.

### `review-pro-stack` (no args, TTY)
Interactive multi-select of catalog stacks not yet installed → writes selected into `.review-pro/`. In non-TTY: prints help and exits non-zero (use `add` in CI).

### `list`
Prints a table: stack name, catalog version, installed version (or `—`), drift marker (`=`/`<`/`>`). Source: bundled `catalog/` vs `.review-pro/`.

### `add <stack>`
Installs one stack from the catalog into `.review-pro/<stack>/` (overwrites). Non-interactive, CI-safe. Errors if the stack is not in the catalog. Prints installed version.

### `remove <stack>` (alias `rm`)
Deletes `.review-pro/<stack>/`. No-op (with note) if absent. Never touches anything outside `.review-pro/`.

### `update [stack]`
Without a name: refreshes every installed stack whose `.review-pro/<stack>/manifest.json:version` differs from the catalog version. With a name: refreshes just that one. The version field is the sole diff signal (no content hashing). Idempotent; prints per-stack `updated 0.1.0 -> 0.2.0` or `already latest`.

### `init`
1. Detect opencode home (`$OPENCODE_HOME` → `~/.config/opencode`); create if missing.
2. Copy bundled `plugin/core/skills/<name>/` → `<oc-home>/skills/<name>/` for every skill in the plugin manifest; copy `plugin/core/agents/*.md` → `<oc-home>/agents/`.
3. Then run the interactive stack selection (same as the no-arg command) into cwd's `.review-pro/`.
4. Print a "restart opencode" reminder and the suggested trigger phrase.

`init --no-stacks` skips step 3. `init --target cursor|claude-code` is reserved (post-MVP) and errors with "unsupported in v1" today.

### `doctor`
For every `.review-pro/<stack>/`:
- **Version drift:** compare `manifest.json:version` to the bundled catalog version.
- **Roster integrity:** every `<reviewer>.md` pack file must target a reviewer listed in the bundled `catalog/reviewers.json` (built from the plugin `manifest.json`); every reviewer declared in the stack's own `manifest.json:reviewers` must have a matching file on disk.
Also reports stacks present in `.review-pro/` but no longer in the catalog (orphaned). Exit non-zero if any drift/orphan/roster problem. Does not modify anything.

## 6. Build & publish

`cli/` build (`npm run build` → `tsup`):
1. Bundle `src/` → `cli/dist/` (ESM + CJS, with shebang on the bin).
2. Copy `../stacks/` → `cli/catalog/` (catalog packs with versions).
3. Copy `../core/` → `cli/plugin/` (skills + agents + shared, for `init`).
4. Generate `cli/catalog/reviewers.json` from the repo `manifest.json` — `{ "reviewers": ["security","correctness",...] }` (reviewer-role skills only).

`cli/package.json`:
```json
{
  "name": "review-pro-stack",
  "version": "0.1.0",
  "type": "module",
  "bin": { "review-pro-stack": "dist/cli.js" },
  "files": ["dist", "catalog", "plugin"],
  "engines": { "node": ">=18" },
  "scripts": { "build": "tsup", "test": "vitest run", "prepublishOnly": "npm run build && npm test" }
}
```

`npm publish` from `cli/` ships only `dist` + `catalog` + `plugin` (slim, no source TS). `npx review-pro-stack` fetches this package.

## 7. Guardrail (validator, TDD)

Two new rules in `scripts/validate.sh`, both unit-tested in `scripts/validate.test.sh`:

1. **`SKILL.md` location:** any file named exactly `SKILL.md` must live under `core/skills/`. Elsewhere → `FAIL: <path>: SKILL.md outside core/skills/`.
2. **Agent frontmatter location:** any `.md` whose frontmatter contains a `loads_skill:` key must live under `core/agents/`. Elsewhere → `FAIL: <path>: agent frontmatter outside core/agents/`.

These prevent the CLI/catalog/docs from accidentally leaking into plugin loading as the repo grows. Existing validator behavior unchanged.

## 8. Non-TTY / CI behavior

- `list`, `add`, `remove`, `update`, `doctor`, `init --no-stacks` work fully non-interactive.
- The no-arg interactive command and the interactive phase of `init` require a TTY; in CI they error with a pointer to `add` / `--no-stacks`.
- All commands exit non-zero on failure; machine-readable output is a post-MVP concern (`--json`).

## 9. Safety

- `add`/`update` overwrite the target `.review-pro/<stack>/` directory entirely (the whole dir is CLI-managed). Before overwriting a stack whose on-disk version differs from what the CLI wrote last, print a one-line note (not a prompt) — version is the diff signal.
- `remove` only deletes within `.review-pro/`. It never deletes `.review-pro/` itself or anything outside.
- `init` copies (does not delete) into the opencode home; pre-existing skills/agents of the same name are overwritten (idempotent install).

## 10. MVP scope (v0.1)

**In scope:** all 7 commands; opencode-only `init`; `doctor` (version drift + roster integrity + orphans); TypeScript build via tsup; vitest unit tests for catalog/repo/manifest logic; guardrail validator rules; bundled self-contained package; `stacks/*` packs gain `version`.

**Explicitly post-MVP:** Cursor & Claude Code `init` targets; remote registry / external pack URLs; `upgrade` (catalog self-update / `npx` cache busting); `--json` output; interactive dependency-resolving stacks; community pack contribution guide.

## 11. Open questions / future

- **Catalog update UX:** today `update` refreshes packs from the bundled catalog; to get a newer catalog the user re-runs `npx` (which fetches the latest package). A future `upgrade` command could self-update the package.
- **Stack dependencies:** a stack might want to declare it requires another (e.g. `nextjs` requires `typescript-react`). Defer to post-MVP.
- **`doctor` for the core plugin:** could also validate installed core skills/agents match the bundled plugin. Small extension once `init` lands.
