# review-pro CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the `review-pro` CLI (7 commands, opencode `init`, `doctor`) as a self-contained npm package from `cli/`, plus two guardrail rules in the validator.

**Architecture:** Single repo, `cli/` subdirectory → npm package `review-pro`. TypeScript + `@inquirer/prompts` + `commander` + `tsup` + `vitest`. Build bundles `dist` + `catalog` (from `stacks/`) + `plugin` (from `core/`) + generated `reviewers.json`. Version lives inside each stack's `manifest.json`. `init` is Node-native and replaces `adapters/opencode/install.sh`.

**Tech Stack:** Node ≥18, TypeScript, ESM, `commander`, `@inquirer/prompts`, `tsup`, `vitest`.

---

## File map

| File | Responsibility |
|---|---|
| `scripts/validate.sh` (+ `.test.sh`) | gains two guardrail rules (Task 1) |
| `cli/package.json` | npm package manifest + bin + scripts |
| `cli/tsconfig.json` | TS config (ESM, node18) |
| `cli/tsup.config.ts` | build → `dist/cli.js` with shebang |
| `cli/build-assets.mjs` | copies `stacks/`→`catalog/`, `core/`→`plugin/`, generates `reviewers.json` |
| `cli/src/cli.ts` | commander program + command wiring + no-arg default |
| `cli/src/lib/manifest.ts` | parse/validate stack `manifest.json` |
| `cli/src/lib/catalog.ts` | resolve + read bundled catalog, list stacks, resolve reviewers |
| `cli/src/lib/repo.ts` | `.review-pro/` operations (install/remove/list/installed manifest) |
| `cli/src/lib/plugin.ts` | resolve opencode home + core install |
| `cli/src/lib/doctor.ts` | diagnose drift/orphan/roster |
| `cli/src/lib/log.ts` | consistent output helpers |
| `cli/src/commands/{interactive,list,add,remove,update,init,doctor}.ts` | thin command wrappers |
| `cli/tests/*.test.ts` | vitest unit tests for lib |
| `stacks/*/manifest.json` | each gains `"version": "0.1.0"` |
| `adapters/opencode/install.sh` | REMOVED (init replaces it) |

**Shared lib convention:** every function that touches the filesystem takes an explicit root/dir argument (defaults via resolvers), so tests pass temp dirs — no monkeypatching of cwd.

---

## Task 1: Guardrail validator rules (TDD, bash)

**Files:** modify `scripts/validate.sh`, `scripts/validate.test.sh`

- [ ] **Step 1: Add failing tests**

Append before the final `echo "---"` in `scripts/validate.test.sh`:

```bash

# Case H: SKILL.md outside core/skills -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/cli/docs"
write_good_reviewer "$T/core/skills/security/SKILL.md"
printf -- '---\nname: review-pro-triage\ndescription: "x"\n---\n# T\n' > "$T/core/skills/review-pro-triage/SKILL.md"
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
EOF
printf '# stray\n' > "$T/cli/docs/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "SKILL.md outside core/skills"; then ok "stray SKILL.md detected"; else bad "stray SKILL.md not detected"; fi
rm -rf "$T"

# Case I: agent frontmatter (loads_skill:) outside core/agents -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/stacks/s"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
EOF
cat > "$T/stacks/s/foo.md" <<'EOF'
---
name: stray-agent
loads_skill: security
---
# x
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "agent frontmatter outside core/agents"; then ok "stray agent frontmatter detected"; else bad "stray agent frontmatter not detected"; fi
rm -rf "$T"
```

- [ ] **Step 2: Run, expect new cases fail**

`bash scripts/validate.test.sh` → `pass=7 fail=2`.

- [ ] **Step 3: Implement in `scripts/validate.sh`**

Insert just before the final `[[ "$errors" -eq 0 ]] ...` line:

```bash
# Guardrail: SKILL.md only under core/skills/ (skip build/deps dirs)
shopt -s nullglob
while IFS= read -r f; do
  case "$f" in
    "$SKILLS_DIR"/*/SKILL.md) ;;
    *) add_error "$f: SKILL.md outside core/skills/";;
  esac
done < <(find "$ROOT" -name SKILL.md -type f \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/cli/plugin/*' -not -path '*/cli/dist/*' 2>/dev/null)

# Guardrail: loads_skill: frontmatter only under core/agents/
while IFS= read -r f; do
  case "$f" in
    "$AGENTS_DIR"/*.md) ;;
    *) if head -n20 "$f" 2>/dev/null | grep -q '^loads_skill:'; then add_error "$f: agent frontmatter outside core/agents/"; fi;;
  esac
done < <(find "$ROOT" -name '*.md' -type f \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/cli/plugin/*' -not -path '*/cli/dist/*' 2>/dev/null)
shopt -u nullglob
```

- [ ] **Step 4: Run, expect `pass=9 fail=0`**

`bash scripts/validate.test.sh` → `pass=9 fail=0`; then `./scripts/validate.sh` → `OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate.sh scripts/validate.test.sh
git commit -m "test: guardrail — SKILL.md and agent frontmatter location rules"
```

---

## Task 2: CLI scaffold

**Files:** create `cli/package.json`, `cli/tsconfig.json`, `cli/tsup.config.ts`, `cli/.gitignore`

- [ ] **Step 1: `cli/package.json`**

```json
{
  "name": "review-pro",
  "version": "0.1.0",
  "description": "Installer CLI for review-pro: install core plugin + stack packs (.review-pro/).",
  "license": "MIT",
  "type": "module",
  "bin": { "review-pro": "dist/cli.js" },
  "files": ["dist", "catalog", "plugin"],
  "engines": { "node": ">=18" },
  "scripts": {
    "build": "tsup && node build-assets.mjs",
    "test": "vitest run",
    "prepublishOnly": "npm run build && npm test"
  },
  "dependencies": {
    "@inquirer/prompts": "^7.0.0",
    "commander": "^12.1.0"
  },
  "devDependencies": {
    "@types/node": "^20.14.0",
    "tsup": "^8.3.0",
    "typescript": "^5.6.0",
    "vitest": "^2.1.0"
  }
}
```

- [ ] **Step 2: `cli/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2023"],
    "types": ["node"],
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
```

- [ ] **Step 3: `cli/tsup.config.ts`**

```ts
import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/cli.ts"],
  format: ["esm"],
  target: "node18",
  platform: "node",
  splitting: false,
  sourcemap: false,
  clean: true,
  banner: { js: "#!/usr/bin/env node" },
});
```

- [ ] **Step 4: `cli/.gitignore`**

```
node_modules/
dist/
catalog/
plugin/
*.log
```

(`catalog/` and `plugin/` are build outputs, ignored.)

- [ ] **Step 5: Install deps + verify build tooling**

```bash
cd cli && npm install
```
Expected: `node_modules/` created, no errors.

- [ ] **Step 6: Commit**

```bash
git add cli/package.json cli/tsconfig.json cli/tsup.config.ts cli/.gitignore
git commit -m "feat(cli): scaffold review-pro package"
```
(Do NOT commit `node_modules/` — it's gitignored.)

---

## Task 3: `lib/manifest.ts` (TDD)

**Files:** create `cli/src/lib/manifest.ts`, `cli/tests/manifest.test.ts`

- [ ] **Step 1: Write failing test `cli/tests/manifest.test.ts`**

```ts
import { describe, it, expect } from "vitest";
import { parseManifest } from "../src/lib/manifest.js";

describe("parseManifest", () => {
  it("parses a valid manifest", () => {
    const m = parseManifest({ name: "node", version: "0.1.0", reviewers: ["security", "db"] });
    expect(m).toEqual({ name: "node", version: "0.1.0", reviewers: ["security", "db"] });
  });

  it("throws on missing name", () => {
    expect(() => parseManifest({ version: "0.1.0", reviewers: [] })).toThrow(/name/);
  });

  it("throws on missing version", () => {
    expect(() => parseManifest({ name: "x", reviewers: [] })).toThrow(/version/);
  });

  it("throws on non-array reviewers", () => {
    expect(() => parseManifest({ name: "x", version: "1.0.0", reviewers: "nope" })).toThrow(/reviewers/);
  });

  it("throws on malformed version", () => {
    expect(() => parseManifest({ name: "x", version: "latest", reviewers: [] })).toThrow(/version/);
  });
});
```

- [ ] **Step 2: Run, expect fail**

`cd cli && npx vitest run tests/manifest.test.ts` → fails (module not found).

- [ ] **Step 3: Implement `cli/src/lib/manifest.ts`**

```ts
export interface StackManifest {
  name: string;
  version: string;
  reviewers: string[];
}

const SEMVER = /^\d+\.\d+\.\d+(?:[-+].+)?$/;

export function parseManifest(raw: unknown): StackManifest {
  if (typeof raw !== "object" || raw === null) throw new Error("manifest: not an object");
  const r = raw as Record<string, unknown>;
  if (typeof r.name !== "string" || r.name.length === 0) throw new Error("manifest: missing 'name'");
  if (typeof r.version !== "string" || !SEMVER.test(r.version))
    throw new Error(`manifest: invalid 'version' (expected semver): ${String(r.version)}`);
  if (!Array.isArray(r.reviewers) || !r.reviewers.every((x) => typeof x === "string"))
    throw new Error("manifest: 'reviewers' must be a string array");
  return { name: r.name, version: r.version, reviewers: r.reviewers };
}
```

- [ ] **Step 4: Run, expect pass**

`npx vitest run tests/manifest.test.ts` → all pass.

- [ ] **Step 5: Commit**

```bash
git add cli/src/lib/manifest.ts cli/tests/manifest.test.ts
git commit -m "feat(cli): stack manifest parser + tests"
```

---

## Task 4: `lib/catalog.ts` (TDD)

**Files:** create `cli/src/lib/catalog.ts`, `cli/tests/catalog.test.ts`

- [ ] **Step 1: Write failing test**

```ts
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { listCatalogStacks, readStackManifest, resolveReviewers } from "../src/lib/catalog.js";

let tmp = "";
beforeEach(() => { tmp = fs.mkdtempSync(path.join(os.tmpdir(), "rp-cat-")); });
afterEach(() => { fs.rmSync(tmp, { recursive: true, force: true }); });

function writeStack(name: string, reviewers: string[] = ["security"]) {
  fs.mkdirSync(path.join(tmp, name), { recursive: true });
  fs.writeFileSync(
    path.join(tmp, name, "manifest.json"),
    JSON.stringify({ name, version: "0.1.0", reviewers }),
  );
  fs.writeFileSync(path.join(tmp, name, "security.md"), "# pack");
}

describe("catalog", () => {
  it("lists stacks", () => {
    writeStack("node"); writeStack("go");
    expect(listCatalogStacks(tmp).sort()).toEqual(["go", "node"]);
  });

  it("reads a stack manifest", () => {
    writeStack("node", ["security", "db"]);
    expect(readStackManifest(tmp, "node")).toEqual({
      name: "node", version: "0.1.0", reviewers: ["security", "db"],
    });
  });

  it("returns null for missing stack", () => {
    expect(readStackManifest(tmp, "ghost")).toBeNull();
  });

  it("resolves reviewers from reviewers.json if present", () => {
    fs.writeFileSync(path.join(tmp, "reviewers.json"),
      JSON.stringify({ reviewers: ["security", "craft"] }));
    expect(resolveReviewers(tmp).sort()).toEqual(["craft", "security"]);
  });

  it("resolves reviewers from manifest.json fallback (dev: manifest in catalog parent)", () => {
    const devRoot = fs.mkdtempSync(path.join(os.tmpdir(), "rp-dev-"));
    const stacksDir = path.join(devRoot, "stacks");
    fs.mkdirSync(stacksDir);
    fs.writeFileSync(path.join(devRoot, "manifest.json"),
      JSON.stringify({ skills: [
        { name: "security", role: "reviewer" },
        { name: "review-pro-triage", role: "orchestrator" },
      ] }));
    expect(resolveReviewers(stacksDir).sort()).toEqual(["security"]);
    fs.rmSync(devRoot, { recursive: true, force: true });
  });
});
```

- [ ] **Step 2: Run, expect fail** (`npx vitest run tests/catalog.test.ts`).

- [ ] **Step 3: Implement `cli/src/lib/catalog.ts`**

```ts
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseManifest, type StackManifest } from "./manifest.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** Bundled catalog dir (dist/../catalog), else repo stacks/ in dev. */
export function resolveCatalogDir(): string {
  const bundled = path.resolve(__dirname, "..", "catalog");
  if (fs.existsSync(bundled)) return bundled;
  return path.resolve(__dirname, "..", "..", "stacks");  // dev: cli/../stacks
}

export function listCatalogStacks(catalogDir: string = resolveCatalogDir()): string[] {
  return fs
    .readdirSync(catalogDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(catalogDir, d.name, "manifest.json")))
    .map((d) => d.name);
}

export function readStackManifest(
  catalogDir: string = resolveCatalogDir(),
  stack: string,
): StackManifest | null {
  const f = path.join(catalogDir, stack, "manifest.json");
  if (!fs.existsSync(f)) return null;
  return parseManifest(JSON.parse(fs.readFileSync(f, "utf8")));
}

/** Bundled reviewers.json (build output) else repo manifest.json (dev). */
export function resolveReviewers(catalogDir: string = resolveCatalogDir()): string[] {
  const rj = path.join(catalogDir, "reviewers.json");
  if (fs.existsSync(rj)) {
    const d = JSON.parse(fs.readFileSync(rj, "utf8"));
    if (Array.isArray(d.reviewers)) return d.reviewers;
  }
  const rootManifest = path.resolve(catalogDir, "..", "manifest.json");
  if (fs.existsSync(rootManifest)) {
    const d = JSON.parse(fs.readFileSync(rootManifest, "utf8"));
    if (Array.isArray(d.skills))
      return d.skills.filter((s: any) => s.role === "reviewer").map((s: any) => s.name);
  }
  return [];
}
```

**Fix the typo** in `resolveCatalogDir`: the dev fallback must read `path.resolve(__dirname, "..", "..", "stacks")` (the sample above is already correct).

- [ ] **Step 4: Run, expect pass** (`npx vitest run tests/catalog.test.ts`).

- [ ] **Step 5: Commit**

```bash
git add cli/src/lib/catalog.ts cli/tests/catalog.test.ts
git commit -m "feat(cli): catalog reader + reviewers resolver + tests"
```

---

## Task 5: `lib/repo.ts` (TDD)

**Files:** create `cli/src/lib/repo.ts`, `cli/tests/repo.test.ts`

- [ ] **Step 1: Write failing test**

```ts
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  reviewProDir, listInstalled, installStack, removeStack, getInstalledManifest,
} from "../src/lib/repo.js";

let repo = "", catalog = "";
beforeEach(() => {
  repo = fs.mkdtempSync(path.join(os.tmpdir(), "rp-repo-"));
  catalog = fs.mkdtempSync(path.join(os.tmpdir(), "rp-cat-"));
  // a catalog stack
  fs.mkdirSync(path.join(catalog, "node"), { recursive: true });
  fs.writeFileSync(path.join(catalog, "node", "manifest.json"),
    JSON.stringify({ name: "node", version: "0.1.0", reviewers: ["security"] }));
  fs.writeFileSync(path.join(catalog, "node", "security.md"), "# pack");
});
afterEach(() => { fs.rmSync(repo, { recursive: true, force: true }); fs.rmSync(catalog, { recursive: true, force: true }); });

describe("repo (.review-pro/)", () => {
  it("installStack copies into .review-pro/<stack>", () => {
    const v = installStack(repo, catalog, "node");
    expect(v).toBe("0.1.0");
    expect(fs.existsSync(path.join(repo, ".review-pro", "node", "security.md"))).toBe(true);
    expect(listInstalled(repo)).toEqual(["node"]);
  });

  it("installStack overwrites existing", () => {
    installStack(repo, catalog, "node");
    // bump catalog version + reinstall
    fs.writeFileSync(path.join(catalog, "node", "manifest.json"),
      JSON.stringify({ name: "node", version: "0.2.0", reviewers: ["security"] }));
    const v = installStack(repo, catalog, "node");
    expect(v).toBe("0.2.0");
    expect(getInstalledManifest(repo, "node")?.version).toBe("0.2.0");
  });

  it("removeStack deletes the dir", () => {
    installStack(repo, catalog, "node");
    removeStack(repo, "node");
    expect(listInstalled(repo)).toEqual([]);
    expect(fs.existsSync(path.join(repo, ".review-pro", "node"))).toBe(false);
  });

  it("removeStack is a no-op when absent", () => {
    expect(() => removeStack(repo, "ghost")).not.toThrow();
  });

  it("getInstalledManifest returns null when missing", () => {
    expect(getInstalledManifest(repo, "ghost")).toBeNull();
  });
});
```

- [ ] **Step 2: Run, expect fail**.

- [ ] **Step 3: Implement `cli/src/lib/repo.ts`**

```ts
import fs from "node:fs";
import path from "node:path";
import { parseManifest, type StackManifest } from "./manifest.js";

export function reviewProDir(repoRoot: string): string {
  return path.join(repoRoot, ".review-pro");
}

export function listInstalled(repoRoot: string): string[] {
  const dir = reviewProDir(repoRoot);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(dir, d.name, "manifest.json")))
    .map((d) => d.name);
}

export function getInstalledManifest(repoRoot: string, stack: string): StackManifest | null {
  const f = path.join(reviewProDir(repoRoot), stack, "manifest.json");
  if (!fs.existsSync(f)) return null;
  return parseManifest(JSON.parse(fs.readFileSync(f, "utf8")));
}

/** Copy catalogDir/<stack> -> repoRoot/.review-pro/<stack> (overwrite). Returns installed version. */
export function installStack(repoRoot: string, catalogDir: string, stack: string): string {
  const src = path.join(catalogDir, stack);
  if (!fs.existsSync(path.join(src, "manifest.json")))
    throw new Error(`stack '${stack}' not found in catalog`);
  const dest = path.join(reviewProDir(repoRoot), stack);
  fs.mkdirSync(reviewProDir(repoRoot), { recursive: true });
  fs.rmSync(dest, { recursive: true, force: true });
  fs.cpSync(src, dest, { recursive: true });
  const m = parseManifest(JSON.parse(fs.readFileSync(path.join(dest, "manifest.json"), "utf8")));
  return m.version;
}

export function removeStack(repoRoot: string, stack: string): void {
  const dest = path.join(reviewProDir(repoRoot), stack);
  fs.rmSync(dest, { recursive: true, force: true });
}
```

- [ ] **Step 4: Run, expect pass**.

- [ ] **Step 5: Commit**

```bash
git add cli/src/lib/repo.ts cli/tests/repo.test.ts
git commit -m "feat(cli): .review-pro/ repo operations + tests"
```

---

## Task 6: `lib/plugin.ts` + `lib/log.ts`

**Files:** create `cli/src/lib/plugin.ts`, `cli/src/lib/log.ts`, `cli/tests/plugin.test.ts`

- [ ] **Step 1: Write failing test `cli/tests/plugin.test.ts`**

```ts
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { installCore, resolvePluginDir } from "../src/lib/plugin.js";

let pluginSrc = "", ocHome = "";
beforeEach(() => {
  pluginSrc = fs.mkdtempSync(path.join(os.tmpdir(), "rp-plug-"));
  ocHome = fs.mkdtempSync(path.join(os.tmpdir(), "rp-oc-"));
  fs.mkdirSync(path.join(pluginSrc, "skills", "security"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "skills", "security", "SKILL.md"), "# s");
  fs.mkdirSync(path.join(pluginSrc, "agents"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "agents", "security-reviewer.md"), "# a");
});
afterEach(() => { fs.rmSync(pluginSrc, { recursive: true, force: true }); fs.rmSync(ocHome, { recursive: true, force: true }); });

describe("plugin", () => {
  it("installCore copies skills + agents into oc home", () => {
    installCore(pluginSrc, ocHome);
    expect(fs.existsSync(path.join(ocHome, "skills", "security", "SKILL.md"))).toBe(true);
    expect(fs.existsSync(path.join(ocHome, "agents", "security-reviewer.md"))).toBe(true);
  });

  it("installCore is idempotent", () => {
    installCore(pluginSrc, ocHome);
    expect(() => installCore(pluginSrc, ocHome)).not.toThrow();
  });

  it("resolvePluginDir returns the provided arg", () => {
    expect(resolvePluginDir(pluginSrc)).toBe(pluginSrc);
  });
});
```

- [ ] **Step 2: Implement `cli/src/lib/plugin.ts`**

```ts
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** Bundled plugin dir (dist/../plugin), else repo core/ in dev. */
export function resolvePluginDir(explicit?: string): string {
  if (explicit) return explicit;
  const bundled = path.resolve(__dirname, "..", "plugin");
  if (fs.existsSync(bundled)) return bundled;
  return path.resolve(__dirname, "..", "..", "core");
}

export function resolveOpenCodeHome(): string {
  return process.env.OPENCODE_HOME || path.join(os.homedir(), ".config", "opencode");
}

/** Copy <pluginDir>/skills/** and <pluginDir>/agents/** into <ocHome>/. */
export function installCore(pluginDir: string = resolvePluginDir(), ocHome: string = resolveOpenCodeHome()): void {
  fs.mkdirSync(path.join(ocHome, "skills"), { recursive: true });
  fs.mkdirSync(path.join(ocHome, "agents"), { recursive: true });
  const skillsSrc = path.join(pluginDir, "skills");
  for (const d of fs.readdirSync(skillsSrc, { withFileTypes: true })) {
    if (!d.isDirectory()) continue;
    const dest = path.join(ocHome, "skills", d.name);
    fs.rmSync(dest, { recursive: true, force: true });
    fs.cpSync(path.join(skillsSrc, d.name), dest, { recursive: true });
  }
  const agentsSrc = path.join(pluginDir, "agents");
  if (fs.existsSync(agentsSrc)) {
    for (const a of fs.readdirSync(agentsSrc)) {
      if (!a.endsWith(".md")) continue;
      fs.cpSync(path.join(agentsSrc, a), path.join(ocHome, "agents", a));
    }
  }
}
```

- [ ] **Step 3: Implement `cli/src/lib/log.ts`**

```ts
export function info(msg: string): void { console.log(msg); }
export function warn(msg: string): void { console.error(`warn: ${msg}`); }
export function fail(msg: string): void { console.error(`error: ${msg}`); }
```

- [ ] **Step 4: Run, expect pass** (`npx vitest run tests/plugin.test.ts`).

- [ ] **Step 5: Commit**

```bash
git add cli/src/lib/plugin.ts cli/src/lib/log.ts cli/tests/plugin.test.ts
git commit -m "feat(cli): core plugin install (opencode) + log helpers + tests"
```

---

## Task 7: `lib/doctor.ts` (TDD)

**Files:** create `cli/src/lib/doctor.ts`, `cli/tests/doctor.test.ts`

- [ ] **Step 1: Write failing test**

```ts
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { diagnose } from "../src/lib/doctor.js";
import { installStack } from "../src/lib/repo.js";

let repo = "", catalog = "";
beforeEach(() => {
  repo = fs.mkdtempSync(path.join(os.tmpdir(), "rp-repo-"));
  catalog = fs.mkdtempSync(path.join(os.tmpdir(), "rp-cat-"));
  // catalog stack "node" with security pack
  fs.mkdirSync(path.join(catalog, "node"), { recursive: true });
  fs.writeFileSync(path.join(catalog, "node", "manifest.json"),
    JSON.stringify({ name: "node", version: "0.1.0", reviewers: ["security"] }));
  fs.writeFileSync(path.join(catalog, "node", "security.md"), "# pack");
  // reviewers.json: only security is known
  fs.writeFileSync(path.join(catalog, "reviewers.json"), JSON.stringify({ reviewers: ["security"] }));
});
afterEach(() => { fs.rmSync(repo, { recursive: true, force: true }); fs.rmSync(catalog, { recursive: true, force: true }); });

describe("doctor", () => {
  it("reports no issues when up-to-date", () => {
    installStack(repo, catalog, "node");
    expect(diagnose(repo, catalog, ["security"])).toEqual([]);
  });

  it("reports version drift", () => {
    installStack(repo, catalog, "node");
    fs.writeFileSync(path.join(catalog, "node", "manifest.json"),
      JSON.stringify({ name: "node", version: "0.2.0", reviewers: ["security"] }));
    const d = diagnose(repo, catalog, ["security"]);
    expect(d.some((x) => x.kind === "drift" && x.stack === "node")).toBe(true);
  });

  it("reports orphan (installed but not in catalog)", () => {
    fs.mkdirSync(path.join(repo, ".review-pro", "ghost"), { recursive: true });
    fs.writeFileSync(path.join(repo, ".review-pro", "ghost", "manifest.json"),
      JSON.stringify({ name: "ghost", version: "0.1.0", reviewers: [] }));
    const d = diagnose(repo, catalog, ["security"]);
    expect(d.some((x) => x.kind === "orphan" && x.stack === "ghost")).toBe(true);
  });

  it("reports unknown reviewer in pack", () => {
    fs.mkdirSync(path.join(repo, ".review-pro", "node"), { recursive: true });
    fs.writeFileSync(path.join(repo, ".review-pro", "node", "manifest.json"),
      JSON.stringify({ name: "node", version: "0.1.0", reviewers: ["security", "ghost"] }));
    fs.writeFileSync(path.join(repo, ".review-pro", "node", "ghost.md"), "# pack");
    const d = diagnose(repo, catalog, ["security"]);
    expect(d.some((x) => x.kind === "unknown-reviewer" && x.stack === "node")).toBe(true);
  });

  it("reports missing pack file declared in manifest", () => {
    fs.mkdirSync(path.join(repo, ".review-pro", "node"), { recursive: true });
    fs.writeFileSync(path.join(repo, ".review-pro", "node", "manifest.json"),
      JSON.stringify({ name: "node", version: "0.1.0", reviewers: ["security"] }));
    // security.md missing
    const d = diagnose(repo, catalog, ["security"]);
    expect(d.some((x) => x.kind === "missing-pack" && x.stack === "node")).toBe(true);
  });
});
```

- [ ] **Step 2: Implement `cli/src/lib/doctor.ts`**

```ts
import fs from "node:fs";
import path from "node:path";
import { listCatalogStacks, readStackManifest } from "./catalog.js";
import { listInstalled, getInstalledManifest, reviewProDir } from "./repo.js";

export type Diagnosis =
  | { kind: "drift"; stack: string; detail: string }
  | { kind: "orphan"; stack: string; detail: string }
  | { kind: "unknown-reviewer"; stack: string; detail: string }
  | { kind: "missing-pack"; stack: string; detail: string };

export function diagnose(repoRoot: string, catalogDir: string, knownReviewers: string[]): Diagnosis[] {
  const out: Diagnosis[] = [];
  const catalogVersions = new Map<string, string>();
  for (const s of listCatalogStacks(catalogDir)) {
    const m = readStackManifest(catalogDir, s);
    if (m) catalogVersions.set(s, m.version);
  }

  for (const stack of listInstalled(repoRoot)) {
    const m = getInstalledManifest(repoRoot, stack);
    if (!m) continue;

    // orphan: installed but no longer in catalog
    if (!catalogVersions.has(stack)) {
      out.push({ kind: "orphan", stack, detail: `'${stack}' installed but not in catalog` });
    } else {
      // drift
      const cv = catalogVersions.get(stack)!;
      if (cv !== m.version)
        out.push({ kind: "drift", stack, detail: `${stack}: installed ${m.version} -> catalog ${cv}` });
    }

    // roster integrity
    const dir = path.join(reviewProDir(repoRoot), stack);
    for (const r of m.reviewers) {
      const pack = path.join(dir, `${r}.md`);
      if (!fs.existsSync(pack))
        out.push({ kind: "missing-pack", stack, detail: `${stack}: manifest declares '${r}' but ${r}.md missing` });
      else if (!knownReviewers.includes(r))
        out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${r}.md' targets unknown reviewer` });
    }
    // stray pack files not in manifest
    for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) {
      if (!f.endsWith(".md")) continue;
      const r = f.slice(0, -3);
      if (r === "manifest") continue;
      if (!m.reviewers.includes(r) && !knownReviewers.includes(r))
        out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${f}' targets unknown reviewer` });
    }
  }
  return out;
}
```

- [ ] **Step 3: Run, expect pass** (`npx vitest run tests/doctor.test.ts`).

- [ ] **Step 4: Commit**

```bash
git add cli/src/lib/doctor.ts cli/tests/doctor.test.ts
git commit -m "feat(cli): doctor diagnosis (drift/orphan/roster) + tests"
```

---

## Task 8: Commands — add / list / remove / update

**Files:** create `cli/src/commands/{list,add,remove,update}.ts`

These are thin wrappers over `lib/`. No unit tests (logic is in tested lib).

- [ ] **Step 1: `cli/src/commands/add.ts`**

```ts
import path from "node:path";
import { installStack } from "../lib/repo.js";
import { listCatalogStacks, resolveCatalogDir } from "../lib/catalog.js";
import { info, fail } from "../lib/log.js";

export function add(stack: string, opts: { where?: string }): void {
  const repoRoot = path.resolve(opts.where || process.cwd());
  const catalogDir = resolveCatalogDir();
  if (!listCatalogStacks(catalogDir).includes(stack)) {
    fail(`stack '${stack}' not in catalog. Available: ${listCatalogStacks(catalogDir).join(", ") || "(none)"}`);
    process.exit(1);
  }
  const v = installStack(repoRoot, catalogDir, stack);
  info(`installed ${stack}@${v} -> ${path.join(repoRoot, ".review-pro", stack)}`);
}
```

- [ ] **Step 2: `cli/src/commands/list.ts`**

```ts
import path from "node:path";
import { listCatalogStacks, readStackManifest, resolveCatalogDir } from "../lib/catalog.js";
import { listInstalled, getInstalledManifest } from "../lib/repo.js";
import { info } from "../lib/log.js";

export function list(opts: { where?: string }): void {
  const repoRoot = path.resolve(opts.where || process.cwd());
  const catalogDir = resolveCatalogDir();
  const installed = new Map(listInstalled(repoRoot).map((s) => [s, getInstalledManifest(repoRoot, s)]));
  for (const stack of listCatalogStacks(catalogDir)) {
    const cv = readStackManifest(catalogDir, stack)?.version ?? "?";
    const iv = installed.get(stack)?.version;
    const mark = iv == null ? "—" : iv === cv ? "=" : iv < cv ? "<" : ">";
    info(`${stack.padEnd(20)} catalog=${cv}  installed=${iv ?? "—"}  ${mark}`);
  }
  for (const stack of listInstalled(repoRoot)) {
    if (!listCatalogStacks(catalogDir).includes(stack))
      info(`${stack.padEnd(20)} (installed, not in catalog)`);
  }
}
```

- [ ] **Step 3: `cli/src/commands/remove.ts`**

```ts
import path from "node:path";
import { removeStack, listInstalled } from "../lib/repo.js";
import { info, warn } from "../lib/log.js";

export function remove(stack: string, opts: { where?: string }): void {
  const repoRoot = path.resolve(opts.where || process.cwd());
  if (!listInstalled(repoRoot).includes(stack)) {
    warn(`'${stack}' is not installed`);
    return;
  }
  removeStack(repoRoot, stack);
  info(`removed ${stack}`);
}
```

- [ ] **Step 4: `cli/src/commands/update.ts`**

```ts
import path from "node:path";
import { listCatalogStacks, readStackManifest, resolveCatalogDir } from "../lib/catalog.js";
import { listInstalled, getInstalledManifest, installStack } from "../lib/repo.js";
import { info } from "../lib/log.js";

export function update(stack: string | undefined, opts: { where?: string }): void {
  const repoRoot = path.resolve(opts.where || process.cwd());
  const catalogDir = resolveCatalogDir();
  const targets = stack ? [stack] : listInstalled(repoRoot);
  let changed = 0;
  for (const s of targets) {
    const cv = readStackManifest(catalogDir, s)?.version;
    const iv = getInstalledManifest(repoRoot, s)?.version;
    if (!cv) { info(`${s}: not in catalog, skipped`); continue; }
    if (iv === cv) { info(`${s}: already latest (${iv})`); continue; }
    installStack(repoRoot, catalogDir, s);
    info(`${s}: updated ${iv ?? "—"} -> ${cv}`);
    changed++;
  }
  info(changed === 0 ? "nothing to update" : `${changed} stack(s) updated`);
}
```

- [ ] **Step 5: Commit**

```bash
git add cli/src/commands/list.ts cli/src/commands/add.ts cli/src/commands/remove.ts cli/src/commands/update.ts
git commit -m "feat(cli): list/add/remove/update commands"
```

---

## Task 9: Commands — doctor / init / interactive

**Files:** create `cli/src/commands/{doctor,init,interactive}.ts`

- [ ] **Step 1: `cli/src/commands/doctor.ts`**

```ts
import path from "node:path";
import { diagnose } from "../lib/doctor.js";
import { resolveCatalogDir, resolveReviewers } from "../lib/catalog.js";
import { info, fail } from "../lib/log.js";

export function doctor(opts: { where?: string }): void {
  const repoRoot = path.resolve(opts.where || process.cwd());
  const catalogDir = resolveCatalogDir();
  const reviewers = resolveReviewers(catalogDir);
  const findings = diagnose(repoRoot, catalogDir, reviewers);
  if (findings.length === 0) { info("no issues found"); return; }
  for (const f of findings) fail(`[${f.kind}] ${f.detail}`);
  process.exit(1);
}
```

- [ ] **Step 2: `cli/src/commands/init.ts`**

```ts
import path from "node:path";
import { installCore, resolveOpenCodeHome, resolvePluginDir } from "../lib/plugin.js";
import { runInteractive } from "./interactive.js";
import { info } from "../lib/log.js";

// commander renders `--no-stacks` as `opts.stacks === false`.
export async function init(opts: { where?: string; stacks?: boolean; opencodeHome?: string }): Promise<void> {
  const pluginDir = resolvePluginDir();
  const ocHome = opts.opencodeHome || resolveOpenCodeHome();
  installCore(pluginDir, ocHome);
  info(`installed review-pro core into ${ocHome}`);
  if (opts.stacks !== false) {
    await runInteractive({ where: opts.where });
  }
  info("restart opencode so the new skills/agents are discovered.");
  info("then trigger a review: \"review-pro ile bu branch'i incele\" or invoke the review-pro skill.");
}
```

- [ ] **Step 3: `cli/src/commands/interactive.ts`**

```ts
import path from "node:path";
import { checkbox } from "@inquirer/prompts";
import { listCatalogStacks, resolveCatalogDir } from "../lib/catalog.js";
import { listInstalled, installStack } from "../lib/repo.js";
import { info, fail } from "../lib/log.js";

export async function runInteractive(opts: { where?: string }): Promise<void> {
  if (!process.stdin.isTTY) {
    fail("interactive mode needs a TTY. Use `review-pro add <stack>` in CI.");
    process.exit(2);
  }
  const repoRoot = path.resolve(opts.where || process.cwd());
  const catalogDir = resolveCatalogDir();
  const installed = new Set(listInstalled(repoRoot));
  const choices = listCatalogStacks(catalogDir)
    .sort()
    .map((s) => ({ name: installed.has(s) ? `${s} (reinstall)` : s, value: s, checked: installed.has(s) }));
  if (choices.length === 0) { info("catalog is empty"); return; }
  const selected = await checkbox({ message: "Select stacks to install into .review-pro/", choices });
  for (const s of selected) {
    const v = installStack(repoRoot, catalogDir, s);
    info(`installed ${s}@${v}`);
  }
  if (selected.length === 0) info("nothing selected");
}
```

- [ ] **Step 4: Commit**

```bash
git add cli/src/commands/doctor.ts cli/src/commands/init.ts cli/src/commands/interactive.ts
git commit -m "feat(cli): doctor/init/interactive commands"
```

---

## Task 10: `cli.ts` wiring + default no-arg action

**Files:** create `cli/src/cli.ts`

- [ ] **Step 1: `cli/src/cli.ts`**

```ts
import { Command } from "commander";
import { runInteractive } from "./commands/interactive.js";
import { list } from "./commands/list.js";
import { add } from "./commands/add.js";
import { remove } from "./commands/remove.js";
import { update } from "./commands/update.js";
import { init } from "./commands/init.js";
import { doctor } from "./commands/doctor.js";

const program = new Command();

program
  .name("review-pro")
  .description("Install review-pro core plugin + stack packs (.review-pro/).")
  .option("--where <path>", "target repo path (default: cwd)")
  .action(async (opts) => { await runInteractive(opts); });

program.command("list").action((opts) => { list(program.opts()); });
program.command("add <stack>").action((stack, opts) => { add(stack, program.opts()); });
program.command("remove <stack>").alias("rm").action((stack, opts) => { remove(stack, program.opts()); });
program.command("update [stack]").action((stack, opts) => { update(stack, program.opts()); });
program
  .command("init")
  .option("--no-stacks", "install core only, skip stack selection")
  .option("--opencode-home <path>", "opencode home (default: $OPENCODE_HOME or ~/.config/opencode)")
  .action(async (opts) => { await init({ ...opts, ...program.opts() }); });
program.command("doctor").action((opts) => { doctor(program.opts()); });

program.parseAsync(process.argv).catch((e) => {
  console.error(`error: ${e instanceof Error ? e.message : String(e)}`);
  process.exit(1);
});
```

- [ ] **Step 2: Build + smoke**

```bash
cd cli && npm run build
node dist/cli.js --help
node dist/cli.js list --where ~/Desktop/Projects/Personal/review-pro-test
```
Expected: help prints; `list` prints catalog stacks (catalog was generated by build-assets from `stacks/`).

- [ ] **Step 3: Commit**

```bash
git add cli/src/cli.ts
git commit -m "feat(cli): wire commander program + commands"
```

---

## Task 11: `build-assets.mjs` + version in stack manifests

**Files:** create `cli/build-assets.mjs`; modify `stacks/typescript-react/manifest.json`, `stacks/node/manifest.json`

- [ ] **Step 1: `cli/build-assets.mjs`**

```js
// Copies stacks/ -> cli/catalog/ and core/ -> cli/plugin/, and generates
// cli/catalog/reviewers.json from the repo manifest.json. Run after tsup.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");

const catalogDst = path.join(__dirname, "catalog");
const pluginDst = path.join(__dirname, "plugin");

fs.rmSync(catalogDst, { recursive: true, force: true });
fs.rmSync(pluginDst, { recursive: true, force: true });
fs.cpSync(path.join(root, "stacks"), catalogDst, { recursive: true });
fs.cpSync(path.join(root, "core"), pluginDst, { recursive: true });

// reviewers.json from repo manifest.json (reviewer-role skills only)
const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));
const reviewers = manifest.skills.filter((s) => s.role === "reviewer").map((s) => s.name);
fs.writeFileSync(path.join(catalogDst, "reviewers.json"), JSON.stringify({ reviewers }, null, 2) + "\n");

console.log(`built assets: ${reviewers.length} reviewers, catalog + plugin copied`);
```

- [ ] **Step 2: Add `version` to the two stack manifests**

`stacks/typescript-react/manifest.json`:
```json
{
  "name": "typescript-react",
  "version": "0.1.0",
  "description": "React + TypeScript signals for review-pro reviewers",
  "reviewers": ["security", "correctness", "craft", "frontend", "a11y", "performance", "api-contract", "tests"]
}
```

`stacks/node/manifest.json`:
```json
{
  "name": "node",
  "version": "0.1.0",
  "description": "Node.js server signals for review-pro reviewers",
  "reviewers": ["security", "correctness", "backend", "db", "api-contract", "performance", "tests"]
}
```

- [ ] **Step 3: Update validator's pack-manifest check (version now required)**

The stacks-integrity validator reads `reviewers` from pack manifests; it must also accept `version`. No code change needed (it ignores unknown keys), but add a quick assertion: in `scripts/validate.sh`, inside the stack loop, after parsing, verify `version` is present. Add after the `reviewers` existence check:

```bash
    python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d.get('version'), str) and d['version']" "$pm" 2>/dev/null \
      || add_error "stacks/$pack_name/manifest.json: missing 'version'"
```

Run `./scripts/validate.sh` → `OK`.

- [ ] **Step 4: Full build + run validator + tests**

```bash
cd cli && npm run build && npm test
cd .. && ./scripts/validate.sh && bash scripts/validate.test.sh | tail -2
```
Expected: build succeeds, all vitest tests pass, validator `OK`, `pass=9 fail=0`.

- [ ] **Step 5: Commit**

```bash
git add cli/build-assets.mjs stacks/typescript-react/manifest.json stacks/node/manifest.json scripts/validate.sh
git commit -m "feat(cli): build-assets (catalog+plugin+reviewers.json) + stack versions"
```

---

## Task 12: Remove `install.sh`, update docs, integration smoke

**Files:** delete `adapters/opencode/install.sh`; modify `adapters/opencode/README.md`, `README.md`

- [ ] **Step 1: Remove install.sh**

```bash
git rm adapters/opencode/install.sh
```

- [ ] **Step 2: Update `adapters/opencode/README.md`** — replace the "Install (one-time)" section to use the CLI:

```markdown
## Install (one-time)
```bash
npx review-pro init
# or local dev:
cd cli && npm install && npm run build && node dist/cli.js init
```
`init` copies the core skills + agents into your opencode home (`$OPENCODE_HOME` or `~/.config/opencode`), then interactively selects stacks into `.review-pro/`. The old `install.sh` is removed — `init` replaces it (cross-platform, no bash).
```

- [ ] **Step 3: Update project `README.md`** — Install section:

```markdown
## Install (opencode, one-time)
```bash
npx review-pro init          # installs core + lets you pick stacks
npx review-pro add node      # or add a stack non-interactively
```
Restart opencode, then in any repo open a branch and invoke the **`review-pro`** skill (or ask the session to review it). The agent does everything else natively.
```

- [ ] **Step 4: Integration smoke against the test repo**

```bash
cd cli && npm run build
# init core into a temp opencode home (don't touch your real one)
TMPHOME="$(mktemp -d)"
OPENCODE_HOME="$TMPHOME" node dist/cli.js init --no-stacks
test -f "$TMPHOME/skills/security/SKILL.md" && echo "core installed"
rm -rf "$TMPHOME"

# add/remove/update/doctor against the test repo (it already has .review-pro/)
TR=~/Desktop/Projects/Personal/review-pro-test
node dist/cli.js list --where "$TR"
node dist/cli.js doctor --where "$TR"   # expect: no issues (stacks already installed)
node dist/cli.js remove node --where "$TR" && node dist/cli.js add node --where "$TR"
node dist/cli.js doctor --where "$TR"
```
Expected: core installed; `list` shows ts-react + node; `doctor` clean before and after remove+add.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(cli): remove install.sh, init replaces it; update docs"
```

---

## Task 13: Plan self-review (executing engineer)

Confirm against `docs/superpowers/specs/2026-06-21-review-pro-cli-design.md`:
- §4 version model → `manifest.json:version`, no lockfile. ✔ (Tasks 3, 11)
- §5 commands → all 7 implemented. ✔ (Tasks 8, 9, 10)
- §6 build → dist + catalog + plugin + reviewers.json. ✔ (Task 11)
- §7 guardrail → two rules. ✔ (Task 1)
- §9 safety → remove only inside `.review-pro/`, init copies. ✔ (Tasks 5, 6)
- §10 MVP scope → all in; Cursor/Claude `init`, remote registry, `--json` deferred. ✔

Run the full gate one more time:
```bash
cd cli && npm test && npm run build
cd .. && ./scripts/validate.sh && bash scripts/validate.test.sh
```
All green → done.
