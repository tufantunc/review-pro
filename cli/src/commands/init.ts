import fs from "node:fs";
import path from "node:path";
import { checkbox, confirm } from "@inquirer/prompts";
import { installCore, detectInstalled, resolveTargets, TARGETS, type Target } from "../lib/plugin.js";
import { runInteractive } from "./interactive.js";
import { info, warn, fail } from "../lib/log.js";

const PROJECT_MARKERS = [
  ".git", "package.json", "go.mod", "Cargo.toml", "pyproject.toml",
  "requirements.txt", "pom.xml", "build.gradle", "Gemfile", "setup.py",
  ".review-pro",
];

export async function init(opts: {
  where?: string;
  stacks?: boolean;
  target?: string;
}): Promise<void> {
  const targets = await resolveInitTargets(opts);
  installCores(targets);

  if (opts.stacks !== false) {
    const repoRoot = path.resolve(opts.where || process.cwd());
    if (!looksLikeProjectRoot(repoRoot)) {
      warn("This doesn't look like a project root (no .git or project manifest found).");
      warn("Stack packs install into ./.review-pro/. Run from your project root, or use --where <path>.");
      if (await shouldSkipStacks()) return;
    }
    await runInteractive({ where: opts.where });
  }

  printRestart();
}

function printRestart(): void {
  info("restart your agent tool so the new skills/agents are discovered.");
  info('then trigger a review: "review this branch with review-pro" or invoke the review-pro skill.');
}

async function resolveInitTargets(opts: { target?: string }): Promise<Target[]> {
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
  return targets;
}

function installCores(targets: Target[]): void {
  for (const t of targets) {
    if (t === "cursor") {
      info("");
      info("Cursor uses /add-plugin. Run in Cursor:");
      info("  /add-plugin https://github.com/tufantunc/review-pro");
      info("");
    } else {
      installCore(t);
      info(`installed review-pro core for ${t}`);
    }
  }
}

/** Asks on a TTY whether to skip stack installation; without one, skips
 *  outright. True means skip (restart hint already printed). */
async function shouldSkipStacks(): Promise<boolean> {
  if (!process.stdin.isTTY) {
    info("skipped stacks (not a project root)");
    printRestart();
    return true;
  }
  if (await confirm({ message: "Skip stack installation?", default: true })) {
    info("skipped stacks");
    printRestart();
    return true;
  }
  return false;
}

async function selectPlatforms(): Promise<Target[]> {
  const detected = detectInstalled();
  const choices = TARGETS.map((t) => ({
    name: detected.includes(t) ? `${t} (detected)` : t,
    value: t,
    checked: detected.includes(t),
  }));
  const selected = await checkbox({ message: "Select platforms to install review-pro into:", choices });
  return selected as Target[];
}

function looksLikeProjectRoot(dir: string): boolean {
  return PROJECT_MARKERS.some((m) => fs.existsSync(path.join(dir, m)));
}
