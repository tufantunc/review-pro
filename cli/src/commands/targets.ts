import { checkbox } from "@inquirer/prompts";
import { detectInstalled, resolveTargets, TARGETS, type Target } from "../lib/plugin.js";
import { fail } from "../lib/log.js";

/** Resolve the platforms a command acts on: from an explicit --target value,
 *  or an interactive checkbox when a TTY is available; fails and exits when
 *  neither applies or nothing resolves. The message is the calling command's
 *  own copy for the checkbox prompt. */
export async function resolveCommandTargets(target: string | undefined, selectMessage: string): Promise<Target[]> {
  let targets: Target[];
  if (target) {
    targets = resolveTargets(target);
  } else if (process.stdin.isTTY) {
    targets = await selectPlatforms(selectMessage);
  } else {
    fail("interactive platform selection needs a TTY. Use --target <platform|all|auto>.");
    process.exit(2);
  }
  if (targets.length === 0) {
    fail(`no targets. Use --target <${TARGETS.join("|")}|all|auto>`);
    process.exit(1);
  }
  return targets;
}

async function selectPlatforms(selectMessage: string): Promise<Target[]> {
  const detected = detectInstalled();
  const choices = TARGETS.map((t) => ({
    name: detected.includes(t) ? `${t} (detected)` : t,
    value: t,
    checked: detected.includes(t),
  }));
  const selected = await checkbox({ message: selectMessage, choices });
  return selected as Target[];
}
