import { installCore, resolveOpenCodeHome, resolvePluginDir } from "../lib/plugin.js";
import { runInteractive } from "./interactive.js";
import { info } from "../lib/log.js";

// commander renders `--no-stacks` as `opts.stacks === false`.
export async function init(opts: {
  where?: string;
  stacks?: boolean;
  opencodeHome?: string;
}): Promise<void> {
  const pluginDir = resolvePluginDir();
  const ocHome = opts.opencodeHome || resolveOpenCodeHome();
  installCore(pluginDir, ocHome);
  info(`installed review-pro core into ${ocHome}`);
  if (opts.stacks !== false) {
    await runInteractive({ where: opts.where });
  }
  info("restart opencode so the new skills/agents are discovered.");
  info("then trigger a review: \"review-pro ile bu branch'i incele\" or invoke the review-pro skill.");
}
