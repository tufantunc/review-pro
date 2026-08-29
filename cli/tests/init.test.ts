import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { init } from "../src/commands/init.js";
import { installCore } from "../src/lib/plugin.js";

vi.mock("../src/lib/plugin.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/lib/plugin.js")>();
  return { ...actual, installCore: vi.fn() };
});

let logs: string[], errors: string[];
beforeEach(() => {
  logs = [];
  errors = [];
  vi.spyOn(console, "log").mockImplementation((m) => void logs.push(String(m)));
  vi.spyOn(console, "error").mockImplementation((m) => void errors.push(String(m)));
  vi.mocked(installCore).mockClear();
});
afterEach(() => {
  vi.restoreAllMocks();
});

describe("init", () => {
  it("installs the core for each resolved --target", async () => {
    await init({ target: "opencode", stacks: false });
    expect(installCore).toHaveBeenCalledWith("opencode");
    expect(logs).toContain("installed review-pro core for opencode");
    expect(logs).toContain('then trigger a review: "review this branch with review-pro" or invoke the review-pro skill.');
  });

  it("points cursor at /add-plugin instead of installing", async () => {
    await init({ target: "cursor", stacks: false });
    expect(installCore).not.toHaveBeenCalled();
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
});
