import path from "node:path";
import { checkbox } from "@inquirer/prompts";
import { listCatalogStacks, resolveCatalogDir } from "../lib/catalog.js";
import { listInstalled, installStack } from "../lib/repo.js";
import { info, fail } from "../lib/log.js";

export async function runInteractive(opts: { where?: string }): Promise<void> {
  if (!process.stdin.isTTY) {
    fail("interactive mode needs a TTY. Use `review-pro-stack add <stack>` in CI.");
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
