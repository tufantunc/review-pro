import { confirm } from "@inquirer/prompts";
import { uninstallCore } from "../lib/plugin.js";
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

  info("");
  info("Stack packs live in your repo's .review-pro/ and are not removed by this command.");
  info("To remove them:  npx review-pro remove <stack>");
  info("          or:    rm -rf .review-pro");
}
