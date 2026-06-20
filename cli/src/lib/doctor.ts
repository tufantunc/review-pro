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

    if (!catalogVersions.has(stack)) {
      out.push({ kind: "orphan", stack, detail: `'${stack}' installed but not in catalog` });
    } else {
      const cv = catalogVersions.get(stack)!;
      if (cv !== m.version)
        out.push({ kind: "drift", stack, detail: `${stack}: installed ${m.version} -> catalog ${cv}` });
    }

    const dir = path.join(reviewProDir(repoRoot), stack);
    for (const r of m.reviewers) {
      const pack = path.join(dir, `${r}.md`);
      if (!fs.existsSync(pack))
        out.push({ kind: "missing-pack", stack, detail: `${stack}: manifest declares '${r}' but ${r}.md missing` });
      else if (!knownReviewers.includes(r))
        out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${r}.md' targets unknown reviewer` });
    }
    for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) {
      if (!f.endsWith(".md")) continue;
      const r = f.slice(0, -3);
      if (!m.reviewers.includes(r) && !knownReviewers.includes(r))
        out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${f}' targets unknown reviewer` });
    }
  }
  return out;
}
