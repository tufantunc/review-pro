import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { init } from "../src/commands/init.js";
import { runInteractive } from "../src/commands/interactive.js";
import { installCore } from "../src/lib/plugin.js";

vi.mock("../src/lib/plugin.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/lib/plugin.js")>();
  return { ...actual, installCore: vi.fn() };
});
vi.mock("../src/commands/interactive.js", () => ({ runInteractive: vi.fn() }));

let logs: string[], errors: string[], tmpdirs: string[];
beforeEach(() => {
  logs = [];
  errors = [];
  tmpdirs = [];
  vi.spyOn(console, "log").mockImplementation((m) => void logs.push(String(m)));
  vi.spyOn(console, "error").mockImplementation((m) => void errors.push(String(m)));
  vi.mocked(installCore).mockClear();
  vi.mocked(runInteractive).mockClear();
});
afterEach(() => {
  vi.restoreAllMocks();
  for (const d of tmpdirs) fs.rmSync(d, { recursive: true, force: true });
});

const tmpdir = (): string => {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), "rp-init-"));
  tmpdirs.push(d);
  return d;
};

describe("init", () => {
  it("installs the core for every resolved target, deferring cursor", async () => {
    await init({ target: "all", stacks: false });
    expect(installCore).toHaveBeenCalledTimes(3);
    for (const t of ["opencode", "claude-code", "codex"])
      expect(installCore).toHaveBeenCalledWith(t);
    expect(logs).toContain("installed review-pro core for opencode");
    expect(logs).toContain("  /add-plugin https://github.com/tufantunc/review-pro");
    expect(logs).not.toContain("installed review-pro core for cursor");
  });

  it("fails without a TTY when no --target is given", async () => {
    // A real process.exit terminates; the mock must throw so execution
    // doesn't continue past the failure branch.
    const exit = vi.spyOn(process, "exit").mockImplementation((() => {
      throw new Error("process.exit");
    }) as never);
    await expect(init({ stacks: false })).rejects.toThrow("process.exit");
    expect(exit).toHaveBeenCalledWith(2);
    expect(errors).toContain("error: interactive platform selection needs a TTY. Use --target <platform|all|auto>.");
  });

  it("fails when --target resolves to nothing", async () => {
    const exit = vi.spyOn(process, "exit").mockImplementation((() => {
      throw new Error("process.exit");
    }) as never);
    await expect(init({ target: "bogus", stacks: false })).rejects.toThrow("process.exit");
    expect(exit).toHaveBeenCalledWith(1);
    expect(errors).toContain("error: no targets. Use --target <opencode|claude-code|cursor|codex|all|auto>");
  });

  it("skips stacks outside a project root without a TTY", async () => {
    const dir = tmpdir();
    await init({ target: "opencode", where: dir });
    expect(runInteractive).not.toHaveBeenCalled();
    expect(logs).toContain("skipped stacks (not a project root)");
    expect(logs).toContain("restart your agent tool so the new skills/agents are discovered.");
    expect(errors).toContain("warn: This doesn't look like a project root (no .git or project manifest found).");
  });

  it("runs interactive stack setup inside a project root", async () => {
    const dir = tmpdir();
    fs.mkdirSync(path.join(dir, ".git"));
    await init({ target: "opencode", where: dir });
    expect(runInteractive).toHaveBeenCalledWith({ where: dir });
    expect(logs).not.toContain("skipped stacks (not a project root)");
  });
});
