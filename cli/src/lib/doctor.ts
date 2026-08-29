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

/** `.md` pack filenames in a stack dir, computed once so both pack checks
 *  share one view of the directory instead of statting and listing it apart. */
function listPackFiles(dir: string): Set<string> {
  if (!fs.existsSync(dir)) return new Set();
  return new Set(fs.readdirSync(dir).filter((f) => f.endsWith(".md")));
}

function checkDeclaredPacks(stack: string, packs: Set<string>, m: StackManifest, knownReviewers: string[]): Diagnosis[] {
  const out: Diagnosis[] = [];
  for (const r of m.reviewers) {
    if (!packs.has(`${r}.md`))
      out.push({ kind: "missing-pack", stack, detail: `${stack}: manifest declares '${r}' but ${r}.md missing` });
    else if (!knownReviewers.includes(r))
      out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${r}.md' targets unknown reviewer` });
  }
  return out;
}

function checkStrayPacks(stack: string, packs: Set<string>, m: StackManifest, knownReviewers: string[]): Diagnosis[] {
  const out: Diagnosis[] = [];
  for (const f of packs) {
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
    const packs = listPackFiles(path.join(reviewProDir(repoRoot), stack));
    out.push(...checkDrift(stack, m, catalogVersions));
    out.push(...checkDeclaredPacks(stack, packs, m, knownReviewers));
    out.push(...checkStrayPacks(stack, packs, m, knownReviewers));
  }
  return out;
}
