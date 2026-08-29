import fs from "node:fs";
import path from "node:path";
import { confirm } from "@inquirer/prompts";
import { installCore, type Target } from "../lib/plugin.js";
import { runInteractive } from "./interactive.js";
import { resolveCommandTargets } from "./targets.js";
import { info, warn } from "../lib/log.js";

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
  const targets = await resolveCommandTargets(opts.target, "Select platforms to install review-pro into:");
  installCores(targets);
  if (opts.stacks !== false) await installStacks(opts);
  printRestart();
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

async function installStacks(opts: { where?: string }): Promise<void> {
  const repoRoot = path.resolve(opts.where || process.cwd());
  if (!looksLikeProjectRoot(repoRoot)) {
    warn("This doesn't look like a project root (no .git or project manifest found).");
    warn("Stack packs install into ./.review-pro/. Run from your project root, or use --where <path>.");
    if (await skipStacks()) return;
  }
  await runInteractive({ where: opts.where });
}

/** Prints the skip notice and returns true when stack installation should be
 *  skipped: asks on a TTY, skips outright without one. The restart hint is
 *  the caller's — every init() exit path ends with it exactly once. */
async function skipStacks(): Promise<boolean> {
  if (!process.stdin.isTTY) {
    info("skipped stacks (not a project root)");
    return true;
  }
  if (await confirm({ message: "Skip stack installation?", default: true })) {
    info("skipped stacks");
    return true;
  }
  return false;
}

function printRestart(): void {
  info("restart your agent tool so the new skills/agents are discovered.");
  info('then trigger a review: "review this branch with review-pro" or invoke the review-pro skill.');
}

function looksLikeProjectRoot(dir: string): boolean {
  return PROJECT_MARKERS.some((m) => fs.existsSync(path.join(dir, m)));
}
