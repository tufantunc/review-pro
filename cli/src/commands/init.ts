import fs from "node:fs";
import path from "node:path";
import { checkbox, confirm } from "@inquirer/prompts";
import { installCore, detectInstalled, TARGETS, type Target } from "../lib/plugin.js";
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

  if (opts.stacks !== false) {
    const repoRoot = path.resolve(opts.where || process.cwd());
    if (!looksLikeProjectRoot(repoRoot)) {
      warn("This doesn't look like a project root (no .git or project manifest found).");
      warn("Stack packs install into ./.review-pro/. Run from your project root, or use --where <path>.");
      if (process.stdin.isTTY) {
        const skip = await confirm({ message: "Skip stack installation?", default: true });
        if (skip) {
          info("skipped stacks");
          printRestart();
          return;
        }
      } else {
        info("skipped stacks (not a project root)");
        printRestart();
        return;
      }
    }
    await runInteractive({ where: opts.where });
  }

  printRestart();
}

function printRestart(): void {
  info("restart your agent tool so the new skills/agents are discovered.");
  info('then trigger a review: "review this branch with review-pro" or invoke the review-pro skill.');
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

function resolveTargets(target: string): Target[] {
  if (target === "all") return [...TARGETS];
  if (target === "auto") return detectInstalled();
  if ((TARGETS as readonly string[]).includes(target)) return [target as Target];
  const parts = target.split(",").map((s) => s.trim());
  if (parts.every((p) => (TARGETS as readonly string[]).includes(p))) {
    return parts as Target[];
  }
  return [];
}
