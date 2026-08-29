import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { list } from "../src/commands/list.js";
import { installStack } from "../src/lib/repo.js";

let repo = "", catalog = "";
beforeEach(() => {
  repo = fs.mkdtempSync(path.join(os.tmpdir(), "rp-repo-"));
  catalog = fs.mkdtempSync(path.join(os.tmpdir(), "rp-cat-"));
  fs.mkdirSync(path.join(catalog, "node"), { recursive: true });
  fs.writeFileSync(path.join(catalog, "node", "manifest.json"),
    JSON.stringify({ name: "node", version: "0.2.0", reviewers: ["security"] }));
});
afterEach(() => {
  fs.rmSync(repo, { recursive: true, force: true });
  fs.rmSync(catalog, { recursive: true, force: true });
  vi.restoreAllMocks();
});

const runList = (): string[] => {
  const log = vi.spyOn(console, "log").mockImplementation(() => {});
  list({ where: repo, catalogDir: catalog });
  const out = log.mock.calls.map((c) => String(c[0]));
  log.mockRestore();
  return out;
};

const setInstalledVersion = (stack: string, version: string) => {
  const m = path.join(repo, ".review-pro", stack, "manifest.json");
  const parsed = JSON.parse(fs.readFileSync(m, "utf8"));
  fs.writeFileSync(m, JSON.stringify({ ...parsed, version }));
};

describe("list", () => {
  it("marks uninstalled catalog stacks with an em dash", () => {
    expect(runList()).toContain("node                 catalog=0.2.0  installed=—  —");
  });

  it("marks matching installed versions with =", () => {
    installStack(repo, catalog, "node");
    expect(runList()).toContain("node                 catalog=0.2.0  installed=0.2.0  =");
  });

  it("marks stale installed versions with <", () => {
    installStack(repo, catalog, "node");
    setInstalledVersion("node", "0.1.0");
    expect(runList()).toContain("node                 catalog=0.2.0  installed=0.1.0  <");
  });

  it("lists installed stacks missing from the catalog", () => {
    fs.mkdirSync(path.join(repo, ".review-pro", "ghost"), { recursive: true });
    fs.writeFileSync(path.join(repo, ".review-pro", "ghost", "manifest.json"),
      JSON.stringify({ name: "ghost", version: "0.1.0", reviewers: [] }));
    expect(runList()).toContain("ghost                (installed, not in catalog)");
  });
});
