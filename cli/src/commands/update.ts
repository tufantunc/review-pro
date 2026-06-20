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
