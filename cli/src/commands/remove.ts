import path from "node:path";
import { removeStack, listInstalled } from "../lib/repo.js";
import { info, warn } from "../lib/log.js";

export function remove(stack: string, opts: { where?: string }): void {
  const repoRoot = path.resolve(opts.where || process.cwd());
  if (!listInstalled(repoRoot).includes(stack)) {
    warn(`'${stack}' is not installed`);
    return;
  }
  removeStack(repoRoot, stack);
  info(`removed ${stack}`);
}
