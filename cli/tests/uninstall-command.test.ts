import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { uninstall } from "../src/commands/uninstall.js";
import { uninstallCore } from "../src/lib/plugin.js";
import { checkbox, confirm } from "@inquirer/prompts";

vi.mock("../src/lib/plugin.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/lib/plugin.js")>();
  return { ...actual, uninstallCore: vi.fn() };
});
vi.mock("@inquirer/prompts", () => ({ checkbox: vi.fn(), confirm: vi.fn() }));

let logs: string[], errors: string[];
beforeEach(() => {
  logs = [];
  errors = [];
  vi.spyOn(console, "log").mockImplementation((m) => void logs.push(String(m)));
  vi.spyOn(console, "error").mockImplementation((m) => void errors.push(String(m)));
  vi.mocked(uninstallCore).mockClear();
  vi.mocked(checkbox).mockClear();
  vi.mocked(confirm).mockClear();
});
afterEach(() => {
  vi.restoreAllMocks();
  restoreTty();
});

const withTty = async (fn: () => Promise<void>): Promise<void> => {
  Object.defineProperty(process.stdin, "isTTY", { value: true, configurable: true });
  try {
    await fn();
  } finally {
    restoreTty();
  }
};
const restoreTty = (): void => {
  delete (process.stdin as { isTTY?: boolean }).isTTY;
};

describe("uninstall", () => {
  it("removes the core from every resolved target, deferring cursor", async () => {
    await uninstall({ target: "all", yes: true });
    expect(uninstallCore).toHaveBeenCalledTimes(3);
    for (const t of ["opencode", "claude-code", "codex"])
      expect(uninstallCore).toHaveBeenCalledWith(t);
    expect(logs).toContain("removed review-pro core from opencode");
    expect(logs).toContain("Cursor manages its own plugins. In Cursor, run:");
    expect(logs).toContain("Stack packs live in your repo's .review-pro/ and are not removed by this command.");
  });

  it("asks for confirmation on a TTY when --yes is not given", async () => {
    vi.mocked(confirm).mockResolvedValue(true);
    await withTty(() => uninstall({ target: "opencode" }));
    expect(confirm).toHaveBeenCalled();
    expect(uninstallCore).toHaveBeenCalledWith("opencode");
  });

  it("aborts without removing anything when confirmation is declined", async () => {
    vi.mocked(confirm).mockResolvedValue(false);
    await withTty(() => uninstall({ target: "opencode" }));
    expect(logs).toContain("aborted");
    expect(uninstallCore).not.toHaveBeenCalled();
  });

  it("fails without a TTY when confirmation is required", async () => {
    const exit = vi.spyOn(process, "exit").mockImplementation((() => {
      throw new Error("process.exit");
    }) as never);
    await expect(uninstall({ target: "opencode" })).rejects.toThrow("process.exit");
    expect(exit).toHaveBeenCalledWith(2);
    expect(errors).toContain("error: non-interactive uninstall needs confirmation. Re-run with -y / --yes.");
  });
});
