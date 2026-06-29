import { checkbox, confirm } from "@inquirer/prompts";
import { uninstallCore, detectInstalled, resolveTargets, TARGETS, type Target } from "../lib/plugin.js";
import { info, fail } from "../lib/log.js";

export async function uninstall(opts: {
  where?: string;
  target?: string;
  yes?: boolean;
}): Promise<void> {
  let targets: Target[];
  if (opts.target) {
    targets = resolveTargets(opts.target);
  } else if (process.stdin.isTTY) {
    targets = await selectPlatforms();
  } else {
    fail("interactive platform selection needs a TTY. Use --target <platform|all|auto>.");
    process.exit(2);
  }
  if (targets.length === 0) {
    fail(`no targets. Use --target <${TARGETS.join("|")}|all|auto>`);
    process.exit(1);
  }

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

async function selectPlatforms(): Promise<Target[]> {
  const detected = detectInstalled();
  const choices = TARGETS.map((t) => ({
    name: detected.includes(t) ? `${t} (detected)` : t,
    value: t,
    checked: detected.includes(t),
  }));
  const selected = await checkbox({
    message: "Select platforms to remove review-pro from:",
    choices,
  });
  return selected as Target[];
}
