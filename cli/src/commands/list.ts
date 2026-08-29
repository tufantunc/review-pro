import path from "node:path";
import { listCatalogStacks, readStackManifest, resolveCatalogDir } from "../lib/catalog.js";
import { versionMark } from "../lib/manifest.js";
import { listInstalled, getInstalledManifest } from "../lib/repo.js";
import { info } from "../lib/log.js";

export function list(opts: { where?: string; catalogDir?: string }): void {
  const repoRoot = path.resolve(opts.where || process.cwd());
  const catalogDir = opts.catalogDir ?? resolveCatalogDir();
  const installed = new Map(listInstalled(repoRoot).map((s) => [s, getInstalledManifest(repoRoot, s)]));
  for (const stack of listCatalogStacks(catalogDir)) {
    const cv = readStackManifest(catalogDir, stack)?.version ?? "?";
    const iv = installed.get(stack)?.version;
    const mark = versionMark(iv, cv);
    info(`${stack.padEnd(20)} catalog=${cv}  installed=${iv ?? "—"}  ${mark}`);
  }
  for (const stack of listInstalled(repoRoot)) {
    if (!listCatalogStacks(catalogDir).includes(stack))
      info(`${stack.padEnd(20)} (installed, not in catalog)`);
  }
}
