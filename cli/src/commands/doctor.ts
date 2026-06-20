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
