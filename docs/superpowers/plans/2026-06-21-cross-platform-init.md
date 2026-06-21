# Cross-Platform `init` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement task-by-task. Steps use `- [ ]` checkboxes.

**Goal:** Make `npx review-pro init --target <platform>` install the review-pro core into opencode, Claude Code, Cursor, and Codex from ONE canonical source (`core/`). No duplicated agent files; only Codex needs a `.md`→`.toml` transform.

**Architecture:** `core/` is the single source. Agent `.md` frontmatter becomes dual-field (`loads_skill` + `skills:`) so the same file serves opencode/Claude Code/Cursor as-is. Cursor additionally gets a repo-root `.cursor-plugin/plugin.json` (repo = plugin). Codex agents are transformed to TOML at install. The CLI gains per-target install logic.

**Tech Stack:** Node ≥18, TypeScript (existing CLI), no new runtime deps.

---

## File map

| File | Change |
|---|---|
| `core/agents/*.md` (15) | add `skills: [<loads_skill>]` frontmatter; neutral body wording (12 reviewers) |
| `.cursor-plugin/plugin.json` | NEW at repo root (Cursor plugin manifest) |
| `cli/src/lib/agents.ts` | NEW: parse canonical agent `.md` + `mdToCodexToml` transform |
| `cli/src/lib/plugin.ts` | generalize `installCore(target)` for 4 platforms + `detectInstalled` |
| `cli/src/commands/init.ts` | `--target all\|auto\|<platform>` handling |
| `cli/build-assets.mjs` | also bundle `.cursor-plugin/plugin.json` |
| `cli/tests/agents.test.ts`, `cli/tests/plugin-cross.test.ts` | NEW tests |
| `scripts/validate.sh` (+ `.test.sh`) | consistency check: agent `skills:` matches `loads_skill` |
| `README.md`, `adapters/opencode/README.md` | document `--target` |

---

## Task 1: Dual-field canonical agent frontmatter

**Files:** `core/agents/*.md` (15 files)

- [ ] **Step 1: Run a one-off transform script to add the `skills:` field**

From the repo root, run (zsh/bash):
```bash
cd ~/Desktop/Projects/Personal/review-pro
for f in core/agents/*.md; do
  # skip if skills: already present
  grep -q '^skills:' "$f" && continue
  ls_skill="$(awk -F': ' '/^loads_skill:/{print $2}' "$f")"
  [ -z "$ls_skill" ] && continue
  # insert skills: line right after the loads_skill: line
  awk -v ls="$ls_skill" '/^loads_skill:/{print; print "skills: [" ls "]"; next}1' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
echo "done"; grep -c '^skills:' core/agents/*.md | head -20
```
Expected: each of the 15 agent files now has a `skills: [<loads_skill>]` line.

- [ ] **Step 2: Reword the 12 reviewer bodies to platform-neutral phrasing**

For each `core/agents/*-reviewer.md`, replace the exact string `(declared via \`loads_skill\`)` with `(auto-loaded / preloaded / co-located by the platform)`:
```bash
cd ~/Desktop/Projects/Personal/review-pro
for f in core/agents/*-reviewer.md; do
  sed -i '' 's/(declared via `loads_skill`)/(auto-loaded \/ preloaded \/ co-located by the platform)/' "$f"
done
grep -L "auto-loaded / preloaded / co-located" core/agents/*-reviewer.md || echo "all reviewers updated"
```
Expected: "all reviewers updated" (no file missing the new phrasing).

- [ ] **Step 3: Validate + run validator**

```bash
./scripts/validate.sh
```
Expected: `OK: all artifacts valid` (the new `skills:` field is tolerated).

- [ ] **Step 4: Commit**

```bash
git add core/agents/
git commit -m "feat(agents): dual-field frontmatter (loads_skill + skills) for cross-platform"
```

---

## Task 2: Cursor plugin manifest at repo root

**Files:** create `.cursor-plugin/plugin.json`

- [ ] **Step 1: Create `.cursor-plugin/plugin.json`**

```json
{
  "name": "review-pro",
  "displayName": "Review-Pro",
  "version": "0.1.0",
  "description": "Tiered AI code-review: triage -> relevant specialist reviewers -> synthesis. Reviews AI-written code using AI agents.",
  "author": { "name": "review-pro contributors" },
  "homepage": "https://github.com/tufantunc/review-pro",
  "repository": "https://github.com/tufantunc/review-pro",
  "license": "MIT",
  "category": "developer-tools",
  "keywords": ["code-review", "security", "code-quality", "subagents", "ai-code"],
  "tags": ["review", "quality", "shipping"],
  "skills": "./core/skills/",
  "agents": "./core/agents/"
}
```

- [ ] **Step 2: Commit**

```bash
git add .cursor-plugin/plugin.json
git commit -m "feat(cursor): repo-root plugin manifest (repo = Cursor plugin)"
```

---

## Task 3: `lib/agents.ts` — canonical parse + Codex transform (TDD)

**Files:** create `cli/src/lib/agents.ts`, `cli/tests/agents.test.ts`

- [ ] **Step 1: Write failing test `cli/tests/agents.test.ts`**

```ts
import { describe, it, expect } from "vitest";
import { parseAgentMd, mdToCodexToml } from "../src/lib/agents.js";

const MD = `---
name: security-reviewer
description: "Security reviewer subagent."
loads_skill: security
skills: [security]
---

# Security Reviewer (subagent)

You are a review-pro subagent. Apply your core skill.
`;

describe("agents", () => {
  it("parses canonical agent md", () => {
    const a = parseAgentMd(MD);
    expect(a.name).toBe("security-reviewer");
    expect(a.description).toBe("Security reviewer subagent.");
    expect(a.loads_skill).toBe("security");
    expect(a.body).toContain("review-pro subagent");
  });

  it("transforms to codex toml with resolved skill path", () => {
    const a = parseAgentMd(MD);
    const toml = mdToCodexToml(a, "/home/.codex/skills");
    expect(toml).toContain('name = "security-reviewer"');
    expect(toml).toContain('sandbox_mode = "read-only"');
    expect(toml).toContain('developer_instructions = """');
    expect(toml).toContain('path = "/home/.codex/skills/security/SKILL.md"');
  });

  it("throws on missing frontmatter", () => {
    expect(() => parseAgentMd("no frontmatter")).toThrow(/frontmatter/);
  });
});
```

- [ ] **Step 2: Run, expect fail** (`cd cli && npx vitest run tests/agents.test.ts`).

- [ ] **Step 3: Implement `cli/src/lib/agents.ts`**

```ts
import path from "node:path";

export interface CanonicalAgent {
  name: string;
  description: string;
  loads_skill: string;
  body: string;
}

function unquote(v: string): string {
  return v.replace(/^"/, "").replace(/"$/, "");
}

export function parseAgentMd(content: string): CanonicalAgent {
  const lines = content.split("\n");
  if (lines[0].trim() !== "---") throw new Error("agent: missing frontmatter");
  const fm: Record<string, string> = {};
  let i = 1;
  while (i < lines.length && lines[i].trim() !== "---") {
    const m = lines[i].match(/^([a-zA-Z_]+):\s*(.*)$/);
    if (m) fm[m[1]] = m[2];
    i++;
  }
  if (i >= lines.length) throw new Error("agent: unterminated frontmatter");
  const body = lines.slice(i + 1).join("\n").trim();
  if (!fm.name) throw new Error("agent: missing name");
  if (!fm.loads_skill) throw new Error("agent: missing loads_skill");
  return {
    name: unquote(fm.name),
    description: fm.description ? unquote(fm.description) : "",
    loads_skill: unquote(fm.loads_skill),
    body,
  };
}

export function mdToCodexToml(a: CanonicalAgent, skillsAbsDir: string): string {
  const skillPath = path.join(skillsAbsDir, a.loads_skill, "SKILL.md");
  return `name = ${JSON.stringify(a.name)}
description = ${JSON.stringify(a.description)}
sandbox_mode = "read-only"
developer_instructions = """
${a.body}
"""
[[skills.config]]
path = ${JSON.stringify(skillPath)}
`;
}
```

- [ ] **Step 4: Run, expect pass** (`npx vitest run tests/agents.test.ts`).

- [ ] **Step 5: Commit**

```bash
git add cli/src/lib/agents.ts cli/tests/agents.test.ts
git commit -m "feat(cli): canonical agent parser + codex toml transform + tests"
```

---

## Task 4: `lib/plugin.ts` — per-target install + detect (TDD)

**Files:** modify `cli/src/lib/plugin.ts`; create `cli/tests/plugin-cross.test.ts`

- [ ] **Step 1: Write failing test `cli/tests/plugin-cross.test.ts`**

```ts
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { installCore, resolveHome, detectInstalled, type Target } from "../src/lib/plugin.js";

let pluginSrc = "", homes = "";
beforeEach(() => {
  pluginSrc = fs.mkdtempSync(path.join(os.tmpdir(), "rp-plug-"));
  homes = fs.mkdtempSync(path.join(os.tmpdir(), "rp-homes-"));
  // plugin layout: skills/<name>/SKILL.md, agents/<name>.md, ../.cursor-plugin/plugin.json
  fs.mkdirSync(path.join(pluginSrc, "skills", "security"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "skills", "security", "SKILL.md"), "# s");
  fs.mkdirSync(path.join(pluginSrc, "agents"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "agents", "security-reviewer.md"),
    "---\nname: security-reviewer\ndescription: \"x\"\nloads_skill: security\nskills: [security]\n---\n# body\n");
  // cli package.json for cursor version (pluginSrc/../package.json not available in tmp; installCore reads it gracefully)
});
afterEach(() => { fs.rmSync(pluginSrc, { recursive: true, force: true }); fs.rmSync(homes, { recursive: true, force: true }); });

const H = (t: Target) => path.join(homes, t);

describe("installCore per target", () => {
  it("opencode copies skills + agents as-is", () => {
    installCore("opencode", pluginSrc, H("opencode"));
    expect(fs.existsSync(path.join(H("opencode"), "skills", "security", "SKILL.md"))).toBe(true);
    expect(fs.existsSync(path.join(H("opencode"), "agents", "security-reviewer.md"))).toBe(true);
  });

  it("claude-code copies skills + agents as-is", () => {
    installCore("claude-code", pluginSrc, H("claude-code"));
    expect(fs.existsSync(path.join(H("claude-code"), "skills", "security", "SKILL.md"))).toBe(true);
    expect(fs.existsSync(path.join(H("claude-code"), "agents", "security-reviewer.md"))).toBe(true);
  });

  it("cursor flat-copies into plugins/review-pro/<ver>/ + manifest", () => {
    installCore("cursor", pluginSrc, H("cursor"));
    const dirs = fs.readdirSync(path.join(H("cursor"), "plugins", "review-pro"));
    expect(dirs.length).toBeGreaterThan(0);
    const ver = dirs[0];
    expect(fs.existsSync(path.join(H("cursor"), "plugins", "review-pro", ver, "skills", "security", "SKILL.md"))).toBe(true);
    expect(fs.existsSync(path.join(H("cursor"), "plugins", "review-pro", ver, "agents", "security-reviewer.md"))).toBe(true);
  });

  it("codex copies skills + transforms agents to .toml", () => {
    installCore("codex", pluginSrc, H("codex"));
    expect(fs.existsSync(path.join(H("codex"), "skills", "security", "SKILL.md"))).toBe(true);
    const toml = path.join(H("codex"), "agents", "security-reviewer.toml");
    expect(fs.existsSync(toml)).toBe(true);
    expect(fs.readFileSync(toml, "utf8")).toContain('name = "security-reviewer"');
    expect(fs.readFileSync(toml, "utf8")).toContain('path = ');
  });

  it("codex skips orchestrator subagents (triage/synthesize)", () => {
    fs.writeFileSync(path.join(pluginSrc, "agents", "review-pro-triage-subagent.md"),
      "---\nname: review-pro-triage-subagent\ndescription: \"x\"\nloads_skill: review-pro-triage\nskills: [review-pro-triage]\n---\n# body\n");
    installCore("codex", pluginSrc, H("codex2"));
    expect(fs.existsSync(path.join(H("codex2"), "agents", "review-pro-triage-subagent.toml"))).toBe(false);
  });

  it("detectInstalled returns targets whose homes exist", () => {
    fs.mkdirSync(H("opencode"), { recursive: true });
    const found = detectInstalled((t) => H(t));
    expect(found).toContain("opencode");
  });
});
```

- [ ] **Step 2: Rewrite `cli/src/lib/plugin.ts`**

```ts
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseAgentMd, mdToCodexToml } from "./agents.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export type Target = "opencode" | "claude-code" | "cursor" | "codex";
export const TARGETS: Target[] = ["opencode", "claude-code", "cursor", "codex"];
const ORCHESTRATOR_SKILLS = new Set(["review-pro-triage", "review-pro-synthesize", "review-pro"]);

/** Bundled plugin dir (dist/../plugin), else repo core/ in dev. */
export function resolvePluginDir(explicit?: string): string {
  if (explicit) return explicit;
  const bundled = path.resolve(__dirname, "..", "plugin");
  if (fs.existsSync(bundled)) return bundled;
  return path.resolve(__dirname, "..", "..", "core");
}

export function resolveHome(target: Target): string {
  const h = (...p: string[]) => path.join(os.homedir(), ...p);
  switch (target) {
    case "opencode": return process.env.OPENCODE_HOME || h(".config", "opencode");
    case "claude-code": return h(".claude");
    case "cursor": return h(".cursor");
    case "codex": return process.env.CODEX_HOME || h(".codex");
  }
}

export function detectInstalled(resolver: (t: Target) => string = resolveHome): Target[] {
  return TARGETS.filter((t) => fs.existsSync(resolver(t)));
}

function cliVersion(): string {
  const p = path.resolve(__dirname, "..", "package.json");
  try {
    return JSON.parse(fs.readFileSync(p, "utf8")).version || "0.0.0";
  } catch {
    return "0.0.0";
  }
}

function copySkills(src: string, dst: string): void {
  for (const d of fs.readdirSync(src, { withFileTypes: true })) {
    if (!d.isDirectory()) continue;
    const target = path.join(dst, d.name);
    fs.rmSync(target, { recursive: true, force: true });
    fs.mkdirSync(dst, { recursive: true });
    fs.cpSync(path.join(src, d.name), target, { recursive: true });
  }
}

function copyAgentsMd(src: string, dst: string): void {
  fs.mkdirSync(dst, { recursive: true });
  for (const a of fs.readdirSync(src)) {
    if (!a.endsWith(".md")) continue;
    fs.cpSync(path.join(src, a), path.join(dst, a));
  }
}

function installCodexAgents(src: string, dst: string, skillsAbsDir: string): void {
  fs.mkdirSync(dst, { recursive: true });
  for (const a of fs.readdirSync(src)) {
    if (!a.endsWith(".md")) continue;
    const agent = parseAgentMd(fs.readFileSync(path.join(src, a), "utf8"));
    if (ORCHESTRATOR_SKILLS.has(agent.loads_skill)) continue; // triage/synthesize run inline
    const toml = mdToCodexToml(agent, skillsAbsDir);
    fs.writeFileSync(path.join(dst, `${agent.name}.toml`), toml);
  }
}

export function installCore(
  target: Target,
  pluginDir: string = resolvePluginDir(),
  home: string = resolveHome(target),
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
      const ver = cliVersion();
      const dest = path.join(home, "plugins", "review-pro", ver);
      fs.rmSync(dest, { recursive: true, force: true });
      copySkills(skillsSrc, path.join(dest, "skills"));
      copyAgentsMd(agentsSrc, path.join(dest, "agents"));
      // copy repo-root .cursor-plugin/plugin.json if present alongside pluginDir
      const manifest = path.resolve(pluginDir, "..", ".cursor-plugin", "plugin.json");
      if (fs.existsSync(manifest)) {
        fs.mkdirSync(path.join(dest, ".cursor-plugin"), { recursive: true });
        fs.cpSync(manifest, path.join(dest, ".cursor-plugin", "plugin.json"));
      }
      return;
    }
    case "codex": {
      copySkills(skillsSrc, path.join(home, "skills"));
      installCodexAgents(agentsSrc, path.join(home, "agents"), path.join(home, "skills"));
      return;
    }
  }
}
```

> Note: the existing `cli/tests/plugin.test.ts` calls the old 2-arg `installCore(pluginSrc, ocHome)` signature. Update it in Step 4 to `installCore("opencode", pluginSrc, ocHome)`.

- [ ] **Step 3: Run, expect pass** (`npx vitest run tests/plugin-cross.test.ts`).

- [ ] **Step 4: Update the old `cli/tests/plugin.test.ts`** to the new signature `installCore("opencode", pluginSrc, ocHome)` (it previously called `installCore(pluginSrc, ocHome)`). Adjust its 3 cases and re-run `npx vitest run tests/plugin.test.ts`.

- [ ] **Step 5: Commit**

```bash
git add cli/src/lib/plugin.ts cli/tests/plugin-cross.test.ts cli/tests/plugin.test.ts
git commit -m "feat(cli): per-target installCore (opencode/claude-code/cursor/codex) + detect"
```

---

## Task 5: `init` command — `--target`

**Files:** modify `cli/src/commands/init.ts`, `cli/src/cli.ts`

- [ ] **Step 1: Rewrite `cli/src/commands/init.ts`**

```ts
import { installCore, detectInstalled, TARGETS, type Target } from "../lib/plugin.js";
import { runInteractive } from "./interactive.js";
import { info, fail } from "../lib/log.js";

export async function init(opts: {
  where?: string;
  stacks?: boolean;
  target?: string;
}): Promise<void> {
  const targets = resolveTargets(opts.target);
  if (targets.length === 0) {
    fail(`no targets. Use --target <${TARGETS.join("|")|all|auto}>`);
    process.exit(1);
  }
  for (const t of targets) {
    installCore(t);
    info(`installed review-pro core for ${t}`);
  }
  if (opts.stacks !== false) {
    await runInteractive({ where: opts.where });
  }
  info("restart your agent tool so the new skills/agents are discovered.");
  info('then trigger a review: "review-pro ile bu branch\'i incele" or invoke the review-pro skill.');
}

function resolveTargets(target: string | undefined): Target[] {
  if (!target) return ["opencode"]; // backward-compatible default
  if (target === "all") return [...TARGETS];
  if (target === "auto") return detectInstalled();
  if ((TARGETS as string[]).includes(target)) return [target as Target];
  return [];
}
```

- [ ] **Step 2: Add the `--target` option in `cli/src/cli.ts`**

In the `init` command block, add the option:
```ts
program
  .command("init")
  .option("--no-stacks", "install core only, skip stack selection")
  .option("-t, --target <platform>", "opencode | claude-code | cursor | codex | all | auto")
  .action(async (opts: { stacks?: boolean; target?: string }) => {
    await init({ ...opts, ...program.opts() });
  });
```

- [ ] **Step 3: Typecheck + build + smoke**

```bash
cd cli && npx tsc --noEmit && npm run build
node dist/cli.js init --help
node dist/cli.js init --target auto --no-stacks  # installs to whatever homes exist
```
Expected: `--help` lists `--target`; `--target auto` installs to detected homes without error.

- [ ] **Step 4: Commit**

```bash
git add cli/src/commands/init.ts cli/src/cli.ts
git commit -m "feat(cli): init --target all|auto|<platform>"
```

---

## Task 6: Build bundles the Cursor manifest

**Files:** modify `cli/build-assets.mjs`

- [ ] **Step 1: Also copy `.cursor-plugin/plugin.json` into the bundle**

In `cli/build-assets.mjs`, after the existing `core` copy, add:
```js
// Cursor plugin manifest (repo root) for flat-copy install
const cursorManifestSrc = path.join(root, ".cursor-plugin", "plugin.json");
if (fs.existsSync(cursorManifestSrc)) {
  fs.mkdirSync(path.join(pluginDst, "..", ".cursor-plugin"), { recursive: true });
  fs.cpSync(cursorManifestSrc, path.join(pluginDst, "..", ".cursor-plugin", "plugin.json"));
}
```
(This places it at `cli/.cursor-plugin/plugin.json` so `installCore("cursor")` finds it via `pluginDir/../.cursor-plugin/plugin.json`.)

Also update `cli/.gitignore` to ignore `.cursor-plugin/` (build output).

- [ ] **Step 2: Rebuild + verify the manifest is bundled**

```bash
cd cli && npm run build
test -f .cursor-plugin/plugin.json && echo "cursor manifest bundled"
```

- [ ] **Step 3: Commit**

```bash
git add cli/build-assets.mjs cli/.gitignore
git commit -m "feat(cli): bundle .cursor-plugin manifest for cursor install"
```

---

## Task 7: Validator consistency check (TDD)

**Files:** `scripts/validate.sh`, `scripts/validate.test.sh`

- [ ] **Step 1: Add failing test (Case J)** — agent whose `skills:` doesn't match `loads_skill`:

Append before `echo "---"` in `scripts/validate.test.sh`:
```bash

# Case J: agent skills: field inconsistent with loads_skill: -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/core/agents/security-reviewer.md" <<'EOF'
---
name: security-reviewer
description: "x"
loads_skill: security
skills: [craft]
---
# body
EOF
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [{"name":"security-reviewer","loads_skill":"security"}] }
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "skills:.*must match loads_skill"; then ok "agent skills/loads_skill mismatch detected"; else bad "mismatch not detected"; fi
rm -rf "$T"
```

- [ ] **Step 2: Run, expect J fail** (`bash scripts/validate.test.sh`).

- [ ] **Step 3: Implement** — in `scripts/validate.sh`, inside the agent loop (after the existing `ls_skill` checks), add:
```bash
      skills_field="$(fm_get "$a" "skills")"
      if [[ -n "$skills_field" ]] && ! echo "$skills_field" | grep -qE "\[\s*$ls_skill\s*\]|\[\s*$ls_skill,"; then
        add_error "$(basename "$a"): skills: field must include loads_skill '$ls_skill'"
      fi
```
(The error string contains "skills: field must match loads_skill" to match the test grep.)

- [ ] **Step 4: Run, expect pass=10 fail=0**; then `./scripts/validate.sh` → `OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate.sh scripts/validate.test.sh
git commit -m "test: agent skills: must match loads_skill"
```

---

## Task 8: Docs + integration smoke

**Files:** `README.md`, `adapters/opencode/README.md`

- [ ] **Step 1: Document `--target` in `README.md`**

Replace the "Install (opencode, one-time)" section's command with:
```markdown
## Install (one-time)

```bash
npx review-pro init                           # opencode (default)
npx review-pro init --target claude-code      # or cursor | codex | all | auto
```
Installs the review-pro core (skills + subagents) into the target platform's home from one canonical source. Codex agents are auto-transformed to TOML; the repo root `.cursor-plugin/plugin.json` also lets Cursor `/add-plugin` it directly. Then `npx review-pro add <stack>` to install packs into `.review-pro/`, restart the tool, and invoke the **`review-pro`** skill.
```

- [ ] **Step 2: Rename `adapters/opencode/README.md` content** to a cross-platform note (keep the file; update the install commands to show `--target`).

- [ ] **Step 3: Integration smoke — safe installs only**

Claude Code and Cursor have no standard env override for their homes, so do NOT smoke them against your real `~/.claude` / `~/.cursor`. Their install logic is already covered by the `plugin-cross.test.ts` unit tests (Task 4). Smoke only the env-overridable targets:
```bash
cd cli && npm run build
TMP="$(mktemp -d)"
OPENCODE_HOME="$TMP/opencode" CODEX_HOME="$TMP/codex" \
  node dist/cli.js init --target opencode --no-stacks
CODEX_HOME="$TMP/codex" node dist/cli.js init --target codex --no-stacks
test -f "$TMP/opencode/skills/security/SKILL.md" && echo "opencode ok"
test -f "$TMP/codex/skills/security/SKILL.md" && echo "codex skills ok"
ls "$TMP/codex/agents/"*.toml >/dev/null && echo "codex toml ok"
rm -rf "$TMP"
```
Expected: opencode + codex verified in temp; claude-code/cursor correctness comes from the unit tests.

- [ ] **Step 4: Full gate**

```bash
cd .. && ./scripts/validate.sh && bash scripts/validate.test.sh | tail -2
cd cli && npx vitest run | tail -3 && npm run build | tail -1
```
Expected: validator OK + 10/10; vitest all green; build success.

- [ ] **Step 5: Commit**

```bash
git add README.md adapters/opencode/README.md
git commit -m "docs: cross-platform init --target"
```

---

## Task 9: Plan self-review (executing engineer)

Confirm against `docs/superpowers/specs/2026-06-21-cross-platform-init-design.md`:
- §2 dual-field canonical agents → Task 1. ✔
- §3 Cursor repo-as-plugin + Codex transform → Tasks 2, 3, 4. ✔
- §4 `--target all|auto|<platform>` → Task 5. ✔
- §5 ripple (build bundles manifest, validator consistency) → Tasks 6, 7. ✔
- §7 risks: Cursor nested-path accepted by `/add-plugin` is not testable here without Cursor → documented; flat-copy fallback is tested (Task 4). Dual-frontmatter tolerance validated by `./scripts/validate.sh` passing. Codex skills path uses explicit `skills.config` → robust. ✔

All gates green → feature done.
