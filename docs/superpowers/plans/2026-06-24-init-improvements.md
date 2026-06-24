# init Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Goal:** Fix `init` UX (interactive platform selection + project-root check) and fix two broken platform installs (Cursor flat-copy → `/add-plugin` guidance; Codex skills path `~/.codex/` → `~/.agents/`).

**Architecture:** Token-free changes to `cli/src/lib/agents.ts` (Codex TOML), `cli/src/lib/plugin.ts` (per-target paths + cursor no-op), `cli/src/commands/init.ts` (interactive flow + project-root check). TDD on lib functions.

**Tech Stack:** Node ≥18, TypeScript, `@inquirer/prompts`, `commander`, `vitest`.

---

## File map

| File | Change |
|---|---|
| `cli/src/lib/agents.ts` | `mdToCodexToml`: remove `[[skills.config]]` + `skillsAbsDir` param |
| `cli/src/lib/plugin.ts` | codex skills → `~/.agents/skills/`; cursor case → no-op; add `skillsHome` param |
| `cli/src/commands/init.ts` | interactive platform selection; project-root check; cursor guidance |
| `cli/tests/agents.test.ts` | assert no `[[skills.config]]` in TOML |
| `cli/tests/plugin-cross.test.ts` | codex skills at new path; cursor = no files |
| `cli/src/cli.ts` | no change needed (already has `--target`) |
| `cli/package.json` | bump `0.1.3 → 0.2.0` |
| `docs/docs.html` | update per-platform notes |

---

## Task 1: Codex TOML — remove `[[skills.config]]` (TDD)

**Files:** modify `cli/src/lib/agents.ts`, `cli/tests/agents.test.ts`

- [ ] **Step 1: Update test — remove `path =` assertion, assert no `[[skills.config]]`**

In `cli/tests/agents.test.ts`, replace the transform test:

```ts
  it("transforms to codex toml without skills.config", () => {
    const a = parseAgentMd(MD);
    const toml = mdToCodexToml(a);
    expect(toml).toContain('name = "security-reviewer"');
    expect(toml).toContain('sandbox_mode = "read-only"');
    expect(toml).toContain('developer_instructions = """');
    expect(toml).not.toContain('[[skills.config]]');
    expect(toml).not.toContain('path =');
  });
```

- [ ] **Step 2: Run test — expect fail** (`npx vitest run tests/agents.test.ts`).

- [ ] **Step 3: Simplify `mdToCodexToml` — remove `skillsAbsDir` param + `[[skills.config]]`**

Replace the function in `cli/src/lib/agents.ts`:

```ts
export function mdToCodexToml(a: CanonicalAgent): string {
  return `name = ${JSON.stringify(a.name)}
description = ${JSON.stringify(a.description)}
sandbox_mode = "read-only"
developer_instructions = """
${a.body}
"""
`;
}
```

Also remove the `import path from "node:path";` at the top (no longer used).

- [ ] **Step 4: Run test — expect pass** (`npx vitest run tests/agents.test.ts`).

- [ ] **Step 5: Commit**

```bash
git add cli/src/lib/agents.ts cli/tests/agents.test.ts
git commit -m "fix(cli): remove [[skills.config]] from codex agent TOML"
```

---

## Task 2: Codex + Cursor install paths in `plugin.ts` (TDD)

**Files:** modify `cli/src/lib/plugin.ts`, `cli/tests/plugin-cross.test.ts`

- [ ] **Step 1: Update tests — codex skills at `~/.agents/skills/`, cursor = no files**

Replace the codex test + cursor test in `cli/tests/plugin-cross.test.ts`:

```ts
  it("codex copies skills to .agents/skills/ and transforms agents to .toml", () => {
    installCore("codex", pluginSrc, H("codex"), path.join(H("codex"), "skills"));
    expect(fs.existsSync(path.join(H("codex"), "skills", "security", "SKILL.md"))).toBe(true);
    const toml = path.join(H("codex"), "agents", "security-reviewer.toml");
    expect(fs.existsSync(toml)).toBe(true);
    const content = fs.readFileSync(toml, "utf8");
    expect(content).toContain('name = "security-reviewer"');
    expect(content).not.toContain('[[skills.config]]');
  });

  it("codex skips orchestrator subagents", () => {
    fs.writeFileSync(path.join(pluginSrc, "agents", "review-pro-triage-subagent.md"),
      "---\nname: review-pro-triage-subagent\ndescription: \"x\"\nloads_skill: review-pro-triage\nskills: [review-pro-triage]\n---\n# body\n");
    installCore("codex", pluginSrc, H("codex2"), path.join(H("codex2"), "skills"));
    expect(fs.existsSync(path.join(H("codex2"), "agents", "review-pro-triage-subagent.toml"))).toBe(false);
  });

  it("cursor is a no-op (installed via /add-plugin)", () => {
    installCore("cursor", pluginSrc, H("cursor"));
    expect(fs.existsSync(path.join(H("cursor"), "plugins"))).toBe(false);
  });
```

- [ ] **Step 2: Run tests — expect fail** (`npx vitest run tests/plugin-cross.test.ts`).

- [ ] **Step 3: Update `plugin.ts` — codex skills path, cursor no-op, `skillsHome` param**

Replace `installCore` + `installCodexAgents` + the cursor case:

```ts
function installCodexAgents(src: string, dst: string): void {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dst, { recursive: true });
  for (const a of fs.readdirSync(src)) {
    if (!a.endsWith(".md")) continue;
    const agent = parseAgentMd(fs.readFileSync(path.join(src, a), "utf8"));
    if (ORCHESTRATOR_SKILLS.has(agent.loads_skill)) continue;
    fs.writeFileSync(path.join(dst, `${agent.name}.toml`), mdToCodexToml(agent));
  }
}

export function installCore(
  target: Target,
  pluginDir: string = resolvePluginDir(),
  home: string = resolveHome(target),
  skillsHome?: string,
): void {
  const skillsSrc = path.join(pluginDir, "skills");
  const agentsSrc = path.join(pluginDir, "agents");

  switch (target) {
    case "opencode":
    case "claude-code": {
      copySkills(skillsSrc, path.join(home, "skills"));
      copyAgentsMd(agentsSrc, path.join(home, "agents"));
      return;
    }
    case "cursor": {
      // Cursor plugins are installed via /add-plugin, not filesystem copy.
      // The caller (init.ts) prints the guidance message.
      return;
    }
    case "codex": {
      const sHome = skillsHome || path.join(os.homedir(), ".agents", "skills");
      copySkills(skillsSrc, sHome);
      installCodexAgents(agentsSrc, path.join(home, "agents"));
      return;
    }
  }
}
```

- [ ] **Step 4: Run tests — expect pass** (`npx vitest run tests/plugin-cross.test.ts`).

- [ ] **Step 5: Commit**

```bash
git add cli/src/lib/plugin.ts cli/tests/plugin-cross.test.ts
git commit -m "fix(cli): codex skills → ~/.agents/skills/; cursor install → no-op (via /add-plugin)"
```

---

## Task 3: Interactive platform selection + project-root check

**Files:** rewrite `cli/src/commands/init.ts`; no test (command-layer UX; lib is tested)

- [ ] **Step 1: Rewrite `cli/src/commands/init.ts`**

```ts
import fs from "node:fs";
import path from "node:path";
import { checkbox, confirm } from "@inquirer/prompts";
import { installCore, detectInstalled, TARGETS, type Target } from "../lib/plugin.js";
import { runInteractive } from "./interactive.js";
import { info, warn, fail } from "../lib/log.js";

const PROJECT_MARKERS = [
  ".git", "package.json", "go.mod", "Cargo.toml", "pyproject.toml",
  "requirements.txt", "pom.xml", "build.gradle", "Gemfile", "setup.py",
  ".review-pro",
];

export async function init(opts: {
  where?: string;
  stacks?: boolean;
  target?: string;
}): Promise<void> {
  // --- Platform selection ---
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

  // --- Install core per platform ---
  for (const t of targets) {
    if (t === "cursor") {
      info("");
      info("Cursor uses /add-plugin. Run in Cursor:");
      info("  /add-plugin https://github.com/tufantunc/review-pro");
      info("");
    } else {
      installCore(t);
      info(`installed review-pro core for ${t}`);
    }
  }

  // --- Stack phase ---
  if (opts.stacks !== false) {
    const repoRoot = path.resolve(opts.where || process.cwd());
    if (!looksLikeProjectRoot(repoRoot)) {
      warn("This doesn't look like a project root (no .git or project manifest found).");
      warn("Stack packs install into ./.review-pro/. Run from your project root, or use --where <path>.");
      if (process.stdin.isTTY) {
        const skip = await confirm({ message: "Skip stack installation?", default: true });
        if (skip) {
          info("skipped stacks");
          info("restart your agent tool so the new skills/agents are discovered.");
          return;
        }
      } else {
        info("skipped stacks (not a project root)");
        info("restart your agent tool so the new skills/agents are discovered.");
        return;
      }
    }
    await runInteractive({ where: opts.where });
  }

  info("restart your agent tool so the new skills/agents are discovered.");
  info('then trigger a review: "review-pro ile bu branch\'i incele" or invoke the review-pro skill.');
}

async function selectPlatforms(): Promise<Target[]> {
  const detected = detectInstalled();
  const choices = TARGETS.map((t) => ({
    name: detected.includes(t) ? `${t} (detected)` : t,
    value: t,
    checked: detected.includes(t),
  }));
  const selected = await checkbox({ message: "Select platforms to install review-pro into:", choices });
  return selected as Target[];
}

function looksLikeProjectRoot(dir: string): boolean {
  return PROJECT_MARKERS.some((m) => fs.existsSync(path.join(dir, m)));
}

function resolveTargets(target: string): Target[] {
  if (target === "all") return [...TARGETS];
  if (target === "auto") return detectInstalled();
  if ((TARGETS as readonly string[]).includes(target)) return [target as Target];
  // comma-separated
  const parts = target.split(",").map((s) => s.trim());
  if (parts.every((p) => (TARGETS as readonly string[]).includes(p))) {
    return parts as Target[];
  }
  return [];
}
```

- [ ] **Step 2: Typecheck**

```bash
cd cli && npx tsc --noEmit
```

- [ ] **Step 3: Build + smoke**

```bash
npm run build
node dist/cli.js init --help          # shows --target
node dist/cli.js init --target badname  # error: no targets
TMP="$(mktemp -d)"
CODEX_HOME="$TMP" node dist/cli.js init --target codex --no-stacks  # codex install
test -f "$TMP/agents/security-reviewer.toml" && echo "codex agents ok"
# skills go to ~/.agents/skills/ (real home — verify carefully)
ls "$HOME/.agents/skills/security/SKILL.md" 2>/dev/null && echo "codex skills ok" || echo "codex skills: check ~/.agents/skills/"
rm -rf "$TMP"
```

- [ ] **Step 4: Commit**

```bash
git add cli/src/commands/init.ts
git commit -m "feat(cli): interactive platform selection + project-root check + cursor /add-plugin guidance"
```

---

## Task 4: Update docs + version bump

**Files:** `docs/docs.html`, `cli/package.json`

- [ ] **Step 1: Update Codex + Cursor notes in `docs/docs.html`**

In the per-platform `<ul>` under `#install`, replace the Cursor and Codex `<li>` items:

```html
      <li><strong>Cursor</strong> — installed via Cursor <code>/add-plugin</code>; run <code>/add-plugin https://github.com/tufantunc/review-pro</code> in Cursor (the repo ships a <code>.cursor-plugin/plugin.json</code>).</li>
      <li><strong>Codex</strong> — skills to <code>~/.agents/skills/</code>, agents auto-transformed to <code>~/.codex/agents/*.toml</code>. Codex auto-discovers skills; agents inherit the session skill set.</li>
```

- [ ] **Step 2: Bump version `0.1.3 → 0.2.0`**

In `cli/package.json`, change `"version": "0.1.3"` to `"version": "0.2.0"`.

- [ ] **Step 3: Full gate**

```bash
cd cli && npx vitest run | tail -3 && npm run build | tail -1
cd .. && ./scripts/validate.sh
```

- [ ] **Step 4: Commit**

```bash
git add docs/docs.html cli/package.json
git commit -m "docs+chore: update platform notes; bump 0.2.0"
```

---

## Task 5: Self-review

Spec coverage check:
- §3.1 interactive platform selection → Task 3 ✔
- §3.2 project-root check → Task 3 (`looksLikeProjectRoot` + `confirm`) ✔
- §3.3 Cursor fix → Task 2 (no-op in installCore) + Task 3 (guidance in init) ✔
- §3.4 Codex fix → Task 1 (TOML) + Task 2 (skill path) ✔

Full gate green → done.
