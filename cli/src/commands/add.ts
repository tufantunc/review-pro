import path from "node:path";
import { installStack } from "../lib/repo.js";
import { listCatalogStacks, resolveCatalogDir } from "../lib/catalog.js";
import { info, fail } from "../lib/log.js";

export function add(stack: string, opts: { where?: string }): void {
  const repoRoot = path.resolve(opts.where || process.cwd());
  const catalogDir = resolveCatalogDir();
  const available = listCatalogStacks(catalogDir);
  if (!available.includes(stack)) {
    fail(`stack '${stack}' not in catalog. Available: ${available.join(", ") || "(none)"}`);
    process.exit(1);
  }
  const v = installStack(repoRoot, catalogDir, stack);
  info(`installed ${stack}@${v} -> ${path.join(repoRoot, ".review-pro", stack)}`);
}
