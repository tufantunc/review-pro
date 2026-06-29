# `uninstall` Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `npx review-pro uninstall` — the clean inverse of `init` that removes the review-pro core (agents + skills) from a tool's home, leaving no residue, with docs/README/website updates.

**Architecture:** Manifest-driven deletion (Approach A). A new `uninstallCore()` in `cli/src/lib/plugin.ts` mirrors `installCore()`'s structure but deletes instead of copies, deriving the deletion list from the bundled plugin directory (the same source `installCore` copies from). A thin `commands/uninstall.ts` mirrors `init.ts` for target selection + confirmation. `resolveTargets` is shared (DRY). Docs: commands-table row in 7 i18n dicts + rebuild.

**Tech Stack:** TypeScript (ESM, Node ≥ 18), commander, @inquirer/prompts, vitest. Site: zero-dep `scripts/build-site.js` + tokenized `docs-src/*.html` + `docs-src/i18n/*.json` (7 langs), tested with `node:test`.

**Spec:** [`docs/superpowers/specs/2026-06-29-uninstall-command-design.md`](../specs/2026-06-29-uninstall-command-design.md)

**Conventions to follow:**
- CLI tests live in `cli/tests/*.test.ts`, use vitest, build temp plugin-src + home fixtures (see `cli/tests/plugin-cross.test.ts` for the exact pattern).
- Commands (`cli/src/commands/*.ts`) are thin wrappers; only `cli/src/lib/*` is unit-tested. Interactive prompts are not unit-tested (no TTY).
- No code comments unless asked.
- Commit style: `feat(cli):`, `refactor:`, `docs:` prefixes (see `git log --oneline`).

---

## File map

| File | Responsibility | Action |
|---|---|---|
| `cli/src/lib/plugin.ts` | Core install/uninstall logic; target/home resolution | **Modify** — add exported `resolveTargets`, `uninstallCore`, helpers |
| `cli/src/commands/init.ts` | `init` command | **Modify** — import shared `resolveTargets`, drop local copy |
| `cli/src/commands/uninstall.ts` | `uninstall` command (target select + confirm + guidance) | **Create** |
| `cli/src/cli.ts` | commander program wiring | **Modify** — register `uninstall` |
| `cli/tests/uninstall.test.ts` | unit tests for `uninstallCore` + `resolveTargets` | **Create** |
| `cli/README.md` | npm package README | **Modify** — commands table + Uninstall note |
| `README.md` | repo README | **Modify** — one-liner |
| `adapters/opencode/README.md` | opencode adapter docs | **Modify** — Uninstall sub-section |
| `docs-src/docs.html` | docs page template | **Modify** — commands table row |
| `docs-src/i18n/{en,tr,zh,hi,de,fr,nl}.json` | i18n dictionaries | **Modify** — add `docs.commands.r8` |
| `docs/**` | built site (7 langs + root) | **Regenerate** via `node scripts/build-site.js` |

---

## Task 1: Share `resolveTargets` (DRY refactor)

Move the existing `resolveTargets` from `init.ts` into `lib/plugin.ts` and export it, so both `init` and `uninstall` share one resolver. Pure refactor — no behaviour change.

**Files:**
- Modify: `cli/src/lib/plugin.ts`
- Modify: `cli/src/commands/init.ts`
- Test: `cli/tests/uninstall.test.ts` (created in Task 2 also uses this; here we only verify no regression)

- [ ] **Step 1: Verify the refactor target passes before changes**

Run from `cli/`:
```bash
npm test
```
Expected: all existing tests PASS. (Baseline — if this fails before we start, stop and surface it.)

- [ ] **Step 2: Add `resolveTargets` to `lib/plugin.ts`**

Append this after the existing `detectInstalled` function in `cli/src/lib/plugin.ts` (it already uses `TARGETS` and `detectInstalled`, both defined above it):

```ts
export function resolveTargets(target: string): Target[] {
  if (target === "all") return [...TARGETS];
  if (target === "auto") return detectInstalled();
  if ((TARGETS as readonly string[]).includes(target)) return [target as Target];
  const parts = target.split(",").map((s) => s.trim());
  if (parts.every((p) => (TARGETS as readonly string[]).includes(p))) {
    return parts as Target[];
  }
  return [];
}
```

- [ ] **Step 3: Replace `init.ts`'s local copy with the shared import**

In `cli/src/commands/init.ts`:

3a. Add `resolveTargets` to the import from `../lib/plugin.js`. The existing import line is:
```ts
import { installCore, detectInstalled, TARGETS, type Target } from "../lib/plugin.js";
```
Change it to:
```ts
import { installCore, detectInstalled, resolveTargets, TARGETS, type Target } from "../lib/plugin.js";
```

3b. Delete the local `resolveTargets` function at the bottom of `init.ts` (the whole `function resolveTargets(target: string): Target[] { ... }` block, ~lines 89-98).

- [ ] **Step 4: Verify the refactor compiles and tests pass**

Run from `cli/`:
```bash
npm run build && npm test
```
Expected: build succeeds (no TS errors about missing/duplicate `resolveTargets`); all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add cli/src/lib/plugin.ts cli/src/commands/init.ts
git commit -m "refactor(cli): share resolveTargets between init and (upcoming) uninstall"
```

---

## Task 2: Implement `uninstallCore` (TDD)

Add the deletion engine to `lib/plugin.ts`, mirroring `installCore`. Tests first.

**Files:**
- Test: `cli/tests/uninstall.test.ts` (Create)
- Modify: `cli/src/lib/plugin.ts`

- [ ] **Step 1: Write the failing tests**

Create `cli/tests/uninstall.test.ts`:

```ts
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { installCore, uninstallCore, resolveTargets } from "../src/lib/plugin.js";

let pluginSrc = "", homes = "";
beforeEach(() => {
  pluginSrc = fs.mkdtempSync(path.join(os.tmpdir(), "rp-plug-"));
  homes = fs.mkdtempSync(path.join(os.tmpdir(), "rp-homes-"));
  fs.mkdirSync(path.join(pluginSrc, "skills", "security"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "skills", "security", "SKILL.md"), "# s");
  fs.mkdirSync(path.join(pluginSrc, "skills", "craft"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "skills", "craft", "SKILL.md"), "# c");
  fs.mkdirSync(path.join(pluginSrc, "agents"), { recursive: true });
  fs.writeFileSync(
    path.join(pluginSrc, "agents", "security-reviewer.md"),
    "---\nname: security-reviewer\ndescription: \"x\"\nloads_skill: security\nskills: [security]\n---\n# body\n",
  );
});
afterEach(() => {
  fs.rmSync(pluginSrc, { recursive: true, force: true });
  fs.rmSync(homes, { recursive: true, force: true });
});

const H = (t: string) => path.join(homes, t);

describe("resolveTargets", () => {
  it("all → every target", () => {
    expect(resolveTargets("all")).toEqual(["opencode", "claude-code", "cursor", "codex"]);
  });
  it("single valid target", () => {
    expect(resolveTargets("opencode")).toEqual(["opencode"]);
  });
  it("comma-separated list", () => {
    expect(resolveTargets("opencode,codex")).toEqual(["opencode", "codex"]);
  });
  it("unknown → empty", () => {
    expect(resolveTargets("nope")).toEqual([]);
  });
});

describe("uninstallCore per target", () => {
  it("opencode removes skills + agents, keeps parent dirs", () => {
    installCore("opencode", pluginSrc, H("opencode"));
    uninstallCore("opencode", pluginSrc, H("opencode"));
    expect(fs.existsSync(path.join(H("opencode"), "skills", "security"))).toBe(false);
    expect(fs.existsSync(path.join(H("opencode"), "skills", "craft"))).toBe(false);
    expect(fs.existsSync(path.join(H("opencode"), "agents", "security-reviewer.md"))).toBe(false);
    expect(fs.existsSync(path.join(H("opencode"), "skills"))).toBe(true);
    expect(fs.existsSync(path.join(H("opencode"), "agents"))).toBe(true);
  });

  it("claude-code removes skills + agents", () => {
    installCore("claude-code", pluginSrc, H("claude-code"));
    uninstallCore("claude-code", pluginSrc, H("claude-code"));
    expect(fs.existsSync(path.join(H("claude-code"), "skills", "security"))).toBe(false);
    expect(fs.existsSync(path.join(H("claude-code"), "agents", "security-reviewer.md"))).toBe(false);
  });

  it("codex removes skills + reviewer .toml", () => {
    installCore("codex", pluginSrc, H("codex"), path.join(H("codex"), "skills"));
    uninstallCore("codex", pluginSrc, H("codex"), path.join(H("codex"), "skills"));
    expect(fs.existsSync(path.join(H("codex"), "skills", "security"))).toBe(false);
    expect(fs.existsSync(path.join(H("codex"), "agents", "security-reviewer.toml"))).toBe(false);
  });

  it("codex skips orchestrator agents that were never written", () => {
    fs.writeFileSync(
      path.join(pluginSrc, "agents", "review-pro-triage-subagent.md"),
      "---\nname: review-pro-triage-subagent\ndescription: \"x\"\nloads_skill: review-pro-triage\nskills: [review-pro-triage]\n---\n# body\n",
    );
    installCore("codex", pluginSrc, H("codex2"), path.join(H("codex2"), "skills"));
    expect(() => uninstallCore("codex", pluginSrc, H("codex2"), path.join(H("codex2"), "skills"))).not.toThrow();
    expect(fs.existsSync(path.join(H("codex2"), "agents", "review-pro-triage-subagent.toml"))).toBe(false);
  });

  it("is idempotent — second call throws nothing", () => {
    installCore("opencode", pluginSrc, H("oc"));
    uninstallCore("opencode", pluginSrc, H("oc"));
    expect(() => uninstallCore("opencode", pluginSrc, H("oc"))).not.toThrow();
  });

  it("is a no-op on a home that was never installed", () => {
    expect(() => uninstallCore("opencode", pluginSrc, H("empty"))).not.toThrow();
  });

  it("does not touch a user's own skill folder", () => {
    installCore("opencode", pluginSrc, H("oc"));
    fs.mkdirSync(path.join(H("oc"), "skills", "my-own-skill"), { recursive: true });
    fs.writeFileSync(path.join(H("oc"), "skills", "my-own-skill", "SKILL.md"), "# mine");
    uninstallCore("opencode", pluginSrc, H("oc"));
    expect(fs.existsSync(path.join(H("oc"), "skills", "my-own-skill", "SKILL.md"))).toBe(true);
  });

  it("cursor is a no-op (guidance-only)", () => {
    expect(() => uninstallCore("cursor", pluginSrc, H("cursor"))).not.toThrow();
    expect(fs.existsSync(H("cursor"))).toBe(true);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run from `cli/`:
```bash
npm test
```
Expected: FAIL — `uninstallCore` is not exported from `../src/lib/plugin.js` (import error / "is not a function"). `resolveTargets` tests PASS (added in Task 1).

- [ ] **Step 3: Implement `uninstallCore` + helpers in `lib/plugin.ts`**

Append to `cli/src/lib/plugin.ts` (after the new `resolveTargets` and after the existing `installCore`):

```ts
function listSkillNames(src: string): string[] {
  if (!fs.existsSync(src)) return [];
  return fs.readdirSync(src, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);
}

function listAgentNames(src: string): string[] {
  if (!fs.existsSync(src)) return [];
  return fs.readdirSync(src)
    .filter((f) => f.endsWith(".md"))
    .map((f) => f.slice(0, -3));
}

export function uninstallCore(
  target: Target,
  pluginDir: string = resolvePluginDir(),
  home: string = resolveHome(target),
  skillsHome?: string,
): void {
  const skillsSrc = path.join(pluginDir, "skills");
  const agentsSrc = path.join(pluginDir, "agents");
  const skillNames = listSkillNames(skillsSrc);

  switch (target) {
    case "opencode":
    case "claude-code": {
      for (const s of skillNames) fs.rmSync(path.join(home, "skills", s), { recursive: true, force: true });
      for (const a of listAgentNames(agentsSrc)) fs.rmSync(path.join(home, "agents", `${a}.md`), { force: true });
      return;
    }
    case "cursor": {
      return;
    }
    case "codex": {
      const sHome = skillsHome || path.join(os.homedir(), ".agents", "skills");
      for (const s of skillNames) fs.rmSync(path.join(sHome, s), { recursive: true, force: true });
      for (const a of fs.readdirSync(agentsSrc)) {
        if (!a.endsWith(".md")) continue;
        const agent = parseAgentMd(fs.readFileSync(path.join(agentsSrc, a), "utf8"));
        if (ORCHESTRATOR_SKILLS.has(agent.loads_skill)) continue;
        fs.rmSync(path.join(home, "agents", `${agent.name}.toml`), { force: true });
      }
      return;
    }
  }
}
```

Note: this mirrors `installCore` exactly — same switch arms, same `ORCHESTRATOR_SKILLS` skip for codex, same default `skillsHome`. `fs.rmSync(..., { force: true })` makes missing entries a silent no-op (idempotent). Parent `skills/`/`agents/` dirs are never removed.

- [ ] **Step 4: Run tests to verify they pass**

Run from `cli/`:
```bash
npm test
```
Expected: all tests PASS, including the new `uninstallCore` and `resolveTargets` suites.

- [ ] **Step 5: Build check**

Run from `cli/`:
```bash
npm run build
```
Expected: tsup builds `dist/cli.js` with no TS errors.

- [ ] **Step 6: Commit**

```bash
git add cli/src/lib/plugin.ts cli/tests/uninstall.test.ts
git commit -m "feat(cli): add uninstallCore — manifest-driven core removal"
```

---

## Task 3: Wire the `uninstall` command

Create the command (mirroring `init.ts`) and register it in `cli.ts`. Commands are thin wrappers — no unit test (convention; the engine is tested in Task 2).

**Files:**
- Create: `cli/src/commands/uninstall.ts`
- Modify: `cli/src/cli.ts`

- [ ] **Step 1: Create the command**

Create `cli/src/commands/uninstall.ts`:

```ts
import { checkbox, confirm } from "@inquirer/prompts";
import { uninstallCore, detectInstalled, resolveTargets, TARGETS, type Target } from "../lib/plugin.js";
import { info, fail } from "../lib/log.js";

export async function uninstall(opts: {
  where?: string;
  target?: string;
  yes?: boolean;
}): Promise<void> {
  let targets: Target[];
  if (opts.target) {
    targets = resolveTargets(opts.target);
  } else if (process.stdin.isTTY) {
    targets = await selectPlatforms();
  } else {
    fail("interactive platform selection needs a TTY. Use --target <platform|all|auto>.");
    process.exit(2);
  }
  if (targets.length === 0) {
    fail(`no targets. Use --target <${TARGETS.join("|")}|all|auto>`);
    process.exit(1);
  }

  if (!opts.yes) {
    if (!process.stdin.isTTY) {
      fail("non-interactive uninstall needs confirmation. Re-run with -y / --yes.");
      process.exit(2);
    }
    const ok = await confirm({
      message: `Remove review-pro core from: ${targets.join(", ")}?`,
      default: false,
    });
    if (!ok) {
      info("aborted");
      return;
    }
  }

  for (const t of targets) {
    if (t === "cursor") {
      info("");
      info("Cursor manages its own plugins. In Cursor, run:");
      info("  /remove-plugin review-pro");
      info("");
    } else {
      uninstallCore(t);
      info(`removed review-pro core from ${t}`);
    }
  }

  info("");
  info("Stack packs live in your repo's .review-pro/ and are not removed by this command.");
  info("To remove them:  npx review-pro remove <stack>");
  info("          or:    rm -rf .review-pro");
}

async function selectPlatforms(): Promise<Target[]> {
  const detected = detectInstalled();
  const choices = TARGETS.map((t) => ({
    name: detected.includes(t) ? `${t} (detected)` : t,
    value: t,
    checked: detected.includes(t),
  }));
  const selected = await checkbox({
    message: "Select platforms to remove review-pro from:",
    choices,
  });
  return selected as Target[];
}
```

- [ ] **Step 2: Register the command in `cli.ts`**

In `cli/src/cli.ts`:

2a. Add the import. After the existing `init` import line:
```ts
import { init } from "./commands/init.js";
```
add:
```ts
import { uninstall } from "./commands/uninstall.js";
```

2b. Register the command. After the existing `init` command block (the `program.command("init") ... .action(...)` block) and before `program.command("doctor")`, add:
```ts
program
  .command("uninstall")
  .option("-t, --target <platform>", "opencode | claude-code | cursor | codex | all | auto")
  .option("-y, --yes", "skip confirmation prompt")
  .action(async (opts: { target?: string; yes?: boolean }) => {
    await uninstall({ ...opts, ...program.opts() });
  });
```

- [ ] **Step 3: Build + full test suite**

Run from `cli/`:
```bash
npm run build && npm test
```
Expected: build OK; all tests PASS.

- [ ] **Step 4: Smoke-test the CLI manually (optional, TTY)**

Run from `cli/`:
```bash
node dist/cli.js uninstall --help
```
Expected: prints help showing `uninstall` accepts `-t, --target` and `-y, --yes`.

```bash
node dist/cli.js uninstall --target opencode -y
```
Expected: prints `removed review-pro core from opencode` then the stack-pack guidance. Re-run it (idempotent) — same output, no error.

- [ ] **Step 5: Commit**

```bash
git add cli/src/commands/uninstall.ts cli/src/cli.ts
git commit -m "feat(cli): add uninstall command (init's inverse)"
```

---

## Task 4: Update READMEs

**Files:**
- Modify: `cli/README.md`
- Modify: `README.md`
- Modify: `adapters/opencode/README.md`

- [ ] **Step 1: `cli/README.md` — commands table + Uninstall note**

1a. In the Commands table, after the `init` row:
```markdown
| `init [--target <platform>]` | install the core plugin into a tool's home |
```
add a new row after it:
```markdown
| `uninstall [--target <platform>]` | remove the core plugin from a tool's home |
```

1b. After the `doctor` row (last table row), the table closes. Then add a short section. Find the `## Commands` heading block; after the table, before `## Requirements & license`, add:
```markdown
## Uninstall

Removes the review-pro core (the agents + skills `init` copied) from a tool's home. Mirrors `init`'s `--target` logic.

```bash
npx review-pro uninstall --target opencode   # or claude-code | codex | all | auto
```

Stack packs (`.review-pro/`) live in your repo and are **not** touched — remove them with `npx review-pro remove <stack>` or `rm -rf .review-pro`. Cursor manages its own plugins: run `/remove-plugin review-pro` in Cursor.
```

- [ ] **Step 2: Repo `README.md` — one-liner under Install**

In `README.md`, the "## Install (one-time)" section ends with a paragraph mentioning `npx review-pro add <stack>`. After that paragraph (before `## Stack packs (catalog)`), add:
```markdown
**Uninstall** the core with `npx review-pro uninstall --target <platform>` (removes agents + skills from the tool home; stack packs in `.review-pro/` are repo-local — see `remove`).
```

- [ ] **Step 3: `adapters/opencode/README.md` — Uninstall sub-section**

After the "## Install (one-time)" section (before "## Install stacks (per repo)"), add:
```markdown
## Uninstall

```bash
npx review-pro uninstall --target opencode   # removes core skills + agents from $OC_HOME
```

Mirrors `init`'s `--target` logic (`all` / `auto` / comma-list). Removes every `core/skills/<name>/` and `core/agents/*.md` `init` copied into `$OPENCODE_HOME`; leaves your own skills/agents and the `skills/`/`agents/` dirs themselves untouched. Stack packs (`.review-pro/`) are repo-local — `npx review-pro remove <stack>` or `rm -rf .review-pro`.
```

- [ ] **Step 4: Commit**

```bash
git add cli/README.md README.md adapters/opencode/README.md
git commit -m "docs: document uninstall command"
```

---

## Task 5: Website docs — commands row + i18n + rebuild

Add the `uninstall` row to the docs commands table across all 7 languages and rebuild the site. The homepage (`index.html`) is **not** changed (per spec).

**Files:**
- Modify: `docs-src/docs.html`
- Modify: `docs-src/i18n/en.json`, `tr.json`, `zh.json`, `hi.json`, `de.json`, `fr.json`, `nl.json`
- Regenerate: `docs/**` (via build script)

- [ ] **Step 1: Add the table row to `docs-src/docs.html`**

In `docs-src/docs.html`, find the commands table body. After the `init` row:
```html
        <tr><td><code>init [--target &lt;platform&gt;]</code></td><td>{{docs.commands.r2}}</td></tr>
```
add:
```html
        <tr><td><code>uninstall [--target &lt;platform&gt;]</code></td><td>{{{docs.commands.r8}}}</td></tr>
```

(Use triple-brace `{{{...}}}` because the value contains `<code>` HTML — same as `r1`.)

- [ ] **Step 2: Add `docs.commands.r8` to all 7 i18n dictionaries**

In each file, add the new key **immediately after the `docs.commands.r7` line** (keeps key order consistent across dicts). Values:

**`docs-src/i18n/en.json`** (after r7):
```json
  "docs.commands.r8": "Remove the core plugin from a tool’s home (agents + skills). Stack packs in <code>.review-pro/</code> are untouched.",
```

**`docs-src/i18n/tr.json`**:
```json
  "docs.commands.r8": "Çekirdek eklentiyi bir aracın ev dizininden kaldırır (agent + skill). <code>.review-pro/</code> içindeki yığın paketleri dokunulmaz.",
```

**`docs-src/i18n/zh.json`**:
```json
  "docs.commands.r8": "从工具主目录移除核心插件（agent + skill）。<code>.review-pro/</code> 中的技术栈包不受影响。",
```

**`docs-src/i18n/hi.json`**:
```json
  "docs.commands.r8": "किसी टूल के होम से कोर प्लगइन हटाता है (agent + skill)। <code>.review-pro/</code> में स्टैक पैक प्रभावित नहीं होते।",
```

**`docs-src/i18n/de.json`**:
```json
  "docs.commands.r8": "Entfernt das Kern-Plugin aus dem Home eines Tools (Agenten + Skills). Stack-Pakete in <code>.review-pro/</code> bleiben unangetastet.",
```

**`docs-src/i18n/fr.json`**:
```json
  "docs.commands.r8": "Supprime le plugin cœur du dossier d’un outil (agents + skills). Les packs de stack dans <code>.review-pro/</code> ne sont pas touchés.",
```

**`docs-src/i18n/nl.json`**:
```json
  "docs.commands.r8": "Verwijdert de kern-plug-in uit de home van een tool (agents + skills). Stack-pakketten in <code>.review-pro/</code> worden niet aangeraakt.",
```

- [ ] **Step 3: Run the site test (parity check) — expect PASS**

The `assertParity` check requires all dicts to have identical keys. Run from repo root:
```bash
node --test scripts/build-site.test.js
```
Expected: PASS (all 7 dicts now share `docs.commands.r8`). If it FAILS with "missing keys", a dict was missed — return to Step 2.

- [ ] **Step 4: Rebuild the site (all 7 languages + root)**

Run from repo root:
```bash
node scripts/build-site.js
```
Expected: completes without error. This regenerates `docs/docs.html`, `docs/<lang>/docs.html` for all 7 langs.

- [ ] **Step 5: Verify the new row rendered in the built output**

Run from repo root:
```bash
grep -l "uninstall" docs/docs.html docs/tr/docs.html docs/zh/docs.html
```
Expected: all three (and the other 4 lang dirs) are listed — the `uninstall` row is present in every built docs page.

- [ ] **Step 6: Confirm the homepage is unchanged**

Run from repo root:
```bash
git diff --stat docs/index.html docs/tr/index.html
```
Expected: no output (homepage files are NOT modified by this change).

- [ ] **Step 7: Commit**

```bash
git add docs-src/ docs/
git commit -m "docs(site): add uninstall to commands table (7 languages)"
```

---

## Task 6: Final verification

- [ ] **Step 1: Full CLI build + tests**

Run from `cli/`:
```bash
npm run build && npm test
```
Expected: build OK; all tests PASS.

- [ ] **Step 2: Site test**

Run from repo root:
```bash
node --test scripts/build-site.test.js
```
Expected: PASS.

- [ ] **Step 3: Review the full diff**

Run from repo root:
```bash
git log --oneline main..HEAD
git diff main..HEAD --stat
```
Expected: commits for refactor + uninstallCore + command + docs + site; no stray files.

---

## Self-review notes (plan author)

- **Spec coverage:** §3 interface → Task 3; §4 deletion logic → Task 2; §5 safety gates → Task 3 (TTY/`--target`/`-y` logic); §6 guidance → Task 3; §7 code structure → Tasks 1-3; §8 tests → Task 2; §9 docs → Tasks 4-5. §10 edge cases (version drift, non-goals) need no task — they're inherent to the design.
- **Type consistency:** `uninstallCore(target, pluginDir?, home?, skillsHome?)` signature matches `installCore` exactly in every task that references it. `resolveTargets(target: string): Target[]` is identical wherever used.
- **No placeholders:** every step has concrete code or exact commands.
