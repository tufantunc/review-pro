import { Command } from "commander";
import { runInteractive } from "./commands/interactive.js";
import { list } from "./commands/list.js";
import { add } from "./commands/add.js";
import { remove } from "./commands/remove.js";
import { update } from "./commands/update.js";
import { init } from "./commands/init.js";
import { doctor } from "./commands/doctor.js";

const program = new Command();

program
  .name("review-pro")
  .description("Install review-pro core plugin + stack packs (.review-pro/).")
  .option("--where <path>", "target repo path (default: cwd)")
  .action(async (opts) => { await runInteractive(opts); });

program.command("list").action(() => { list(program.opts()); });
program.command("add <stack>").action((stack: string) => { add(stack, program.opts()); });
program.command("remove <stack>").alias("rm").action((stack: string) => { remove(stack, program.opts()); });
program.command("update [stack]").action((stack: string | undefined) => { update(stack, program.opts()); });
program
  .command("init")
  .option("--no-stacks", "install core only, skip stack selection")
  .option("-t, --target <platform>", "opencode | claude-code | cursor | codex | all | auto")
  .action(async (opts: { stacks?: boolean; target?: string; opencodeHome?: string }) => {
    await init({ ...opts, ...program.opts() });
  });
program.command("doctor").action(() => { doctor(program.opts()); });

program.parseAsync(process.argv).catch((e) => {
  console.error(`error: ${e instanceof Error ? e.message : String(e)}`);
  process.exit(1);
});
