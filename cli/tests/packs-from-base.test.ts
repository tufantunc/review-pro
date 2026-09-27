import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

// A review reads packs from the merge base (ADR-0012), so every command that installs or
// changes a pack tells the user to commit it; otherwise a fresh install reads as ignored.
let repo = "", catalog = "";
vi.mock("../src/lib/catalog.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/lib/catalog.js")>();
  return { ...actual, resolveCatalogDir: () => catalog };
});
vi.mock("@inquirer/prompts", () => ({ checkbox: vi.fn(async () => ["node"]) }));

import { add } from "../src/commands/add.js";
import { update } from "../src/commands/update.js";
import { runInteractive } from "../src/commands/interactive.js";
import { PACKS_FROM_BASE_NOTE } from "../src/lib/repo.js";
import { checkbox } from "@inquirer/prompts";

let logs: string[];
const writeCatalog = (version: string) =>
  fs.writeFileSync(path.join(catalog, "node", "manifest.json"),
    JSON.stringify({ name: "node", version, reviewers: ["security"] }));
beforeEach(() => {
  repo = fs.mkdtempSync(path.join(os.tmpdir(), "rp-repo-"));
  catalog = fs.mkdtempSync(path.join(os.tmpdir(), "rp-cat-"));
  fs.mkdirSync(path.join(catalog, "node"), { recursive: true });
  writeCatalog("0.1.0");
  fs.writeFileSync(path.join(catalog, "node", "security.md"), "# pack");
  logs = [];
  vi.spyOn(console, "log").mockImplementation((m) => void logs.push(String(m)));
});
afterEach(() => {
  vi.restoreAllMocks();
  delete (process.stdin as { isTTY?: boolean }).isTTY;
  fs.rmSync(repo, { recursive: true, force: true });
  fs.rmSync(catalog, { recursive: true, force: true });
});

describe("packs apply from the merge base", () => {
  it("names the base branch", () => {
    expect(PACKS_FROM_BASE_NOTE).toContain("merge base");
    expect(PACKS_FROM_BASE_NOTE).toContain("commit .review-pro/ to your base branch");
  });

  it("add prints the note after installing", () => {
    add("node", { where: repo });
    expect(logs[logs.length - 1]).toBe(PACKS_FROM_BASE_NOTE);
  });

  it("update prints the note only when a pack changed", () => {
    add("node", { where: repo });
    logs.length = 0;
    update(undefined, { where: repo });
    expect(logs).not.toContain(PACKS_FROM_BASE_NOTE);
    writeCatalog("0.2.0");
    update(undefined, { where: repo });
    expect(logs[logs.length - 1]).toBe(PACKS_FROM_BASE_NOTE);
  });

  it("interactive install prints the note only when something was selected", async () => {
    Object.defineProperty(process.stdin, "isTTY", { value: true, configurable: true });
    await runInteractive({ where: repo });
    expect(logs[logs.length - 1]).toBe(PACKS_FROM_BASE_NOTE);
    logs.length = 0;
    vi.mocked(checkbox).mockResolvedValueOnce([]);
    await runInteractive({ where: repo });
    expect(logs).toEqual(["nothing selected"]);
  });
});
