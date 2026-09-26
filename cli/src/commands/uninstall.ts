import fs from "node:fs";
import path from "node:path";
import { confirm } from "@inquirer/prompts";
import { uninstallCore } from "../lib/plugin.js";
import { reviewProDir } from "../lib/repo.js";
import { resolveCommandTargets } from "./targets.js";
import { info, fail } from "../lib/log.js";

export async function uninstall(opts: {
  where?: string;
  target?: string;
  yes?: boolean;
}): Promise<void> {
  const targets = await resolveCommandTargets(opts.target, "Select platforms to remove review-pro from:");

  if (!opts.yes) {
    if (!process.stdin.isTTY) {
      fail("non-interactive uninstall needs confirmation. Re-run with -y / --yes.");
      process.exit(2);
    }
    const ok = await confirm({
      message: `Remove review-pro core from: ${targets.join(", ")}?`,
      default: false,
    });
    if (!ok) {
      info("aborted");
      return;
    }
  }

  for (const t of targets) {
    if (t === "cursor") {
      info("");
      info("Cursor manages its own plugins. In Cursor, run:");
      info("  /remove-plugin review-pro");
      info("");
    } else {
      uninstallCore(t);
      info(`removed review-pro core from ${t}`);
    }
  }

  // Never advise deleting the folder: .review-pro/ can hold the maintainer's own rules file
  // beside the stack packs, and a blanket delete would take it too.
  info("");
  info("Stack packs live in your repo's .review-pro/ and are not removed by this command.");
  info("Remove one with:  npx review-pro remove <stack>");
  const repoRoot = path.resolve(opts.where || process.cwd());
  if (fs.existsSync(path.join(reviewProDir(repoRoot), "rules.md")))
    info(".review-pro/rules.md is your repository's own rules file; it is left in place.");
}
