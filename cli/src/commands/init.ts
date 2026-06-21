import { installCore, detectInstalled, TARGETS, type Target } from "../lib/plugin.js";
import { runInteractive } from "./interactive.js";
import { info, fail } from "../lib/log.js";

export async function init(opts: {
  where?: string;
  stacks?: boolean;
  target?: string;
}): Promise<void> {
  const targets = resolveTargets(opts.target);
  if (targets.length === 0) {
    fail(`no targets. Use --target <${TARGETS.join("|")}|all|auto>`);
    process.exit(1);
  }
  for (const t of targets) {
    installCore(t);
    info(`installed review-pro core for ${t}`);
  }
  if (opts.stacks !== false) {
    await runInteractive({ where: opts.where });
  }
  info("restart your agent tool so the new skills/agents are discovered.");
  info("then trigger a review: \"review-pro ile bu branch'i incele\" or invoke the review-pro skill.");
}

function resolveTargets(target: string | undefined): Target[] {
  if (!target) return ["opencode"]; // backward-compatible default
  if (target === "all") return [...TARGETS];
  if (target === "auto") return detectInstalled();
  if ((TARGETS as readonly string[]).includes(target)) return [target as Target];
  return [];
}
