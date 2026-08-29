import fs from "node:fs";
import path from "node:path";
import { listCatalogStacks, readStackManifest } from "./catalog.js";
import { listInstalled, getInstalledManifest, reviewProDir } from "./repo.js";
import type { StackManifest } from "./manifest.js";

export type Diagnosis =
  | { kind: "drift"; stack: string; detail: string }
  | { kind: "orphan"; stack: string; detail: string }
  | { kind: "unknown-reviewer"; stack: string; detail: string }
  | { kind: "missing-pack"; stack: string; detail: string };

function readCatalogVersions(catalogDir: string): Map<string, string> {
  const versions = new Map<string, string>();
  for (const s of listCatalogStacks(catalogDir)) {
    const m = readStackManifest(catalogDir, s);
    if (m) versions.set(s, m.version);
  }
  return versions;
}

function checkDrift(stack: string, installed: StackManifest, catalogVersions: Map<string, string>): Diagnosis[] {
  const cv = catalogVersions.get(stack);
  if (cv === undefined) return [{ kind: "orphan", stack, detail: `'${stack}' installed but not in catalog` }];
  if (cv !== installed.version)
    return [{ kind: "drift", stack, detail: `${stack}: installed ${installed.version} -> catalog ${cv}` }];
  return [];
}

function checkDeclaredPacks(stack: string, dir: string, m: StackManifest, knownReviewers: string[]): Diagnosis[] {
  const out: Diagnosis[] = [];
  for (const r of m.reviewers) {
    const pack = path.join(dir, `${r}.md`);
    if (!fs.existsSync(pack))
      out.push({ kind: "missing-pack", stack, detail: `${stack}: manifest declares '${r}' but ${r}.md missing` });
    else if (!knownReviewers.includes(r))
      out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${r}.md' targets unknown reviewer` });
  }
  return out;
}

function checkStrayPacks(stack: string, dir: string, m: StackManifest, knownReviewers: string[]): Diagnosis[] {
  const out: Diagnosis[] = [];
  for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) {
    if (!f.endsWith(".md")) continue;
    const r = f.slice(0, -3);
    // A pack for a known reviewer the manifest does not declare is allowed to
    // sit in the stack dir; only packs targeting unknown reviewers are flagged.
    if (!m.reviewers.includes(r) && !knownReviewers.includes(r))
      out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${f}' targets unknown reviewer` });
  }
  return out;
}

export function diagnose(repoRoot: string, catalogDir: string, knownReviewers: string[]): Diagnosis[] {
  const out: Diagnosis[] = [];
  const catalogVersions = readCatalogVersions(catalogDir);
  for (const stack of listInstalled(repoRoot)) {
    const m = getInstalledManifest(repoRoot, stack);
    if (!m) continue;
    const dir = path.join(reviewProDir(repoRoot), stack);
    out.push(...checkDrift(stack, m, catalogVersions));
    out.push(...checkDeclaredPacks(stack, dir, m, knownReviewers));
    out.push(...checkStrayPacks(stack, dir, m, knownReviewers));
  }
  return out;
}
