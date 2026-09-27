import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { listInstalled, installStack, removeStack } from "../src/lib/repo.js";
import { diagnose } from "../src/lib/doctor.js";
import { list } from "../src/commands/list.js";
import { remove } from "../src/commands/remove.js";

// .review-pro/rules.md is the maintainer's own file, beside the stack packs the CLI manages.
// Every command that reads .review-pro/ must treat it as not a stack and leave it in place.
const RULES = "# Review rules\n\n## R1: example\n- when: `src/**`\n- rule: An example.\n";

let repo = "", catalog = "", logs: string[] = [];
const rulesPath = () => path.join(repo, ".review-pro", "rules.md");
beforeEach(() => {
  repo = fs.mkdtempSync(path.join(os.tmpdir(), "rp-repo-"));
  catalog = fs.mkdtempSync(path.join(os.tmpdir(), "rp-cat-"));
  fs.mkdirSync(path.join(catalog, "node"), { recursive: true });
  fs.writeFileSync(path.join(catalog, "node", "manifest.json"),
    JSON.stringify({ name: "node", version: "0.1.0", reviewers: ["security"] }));
  fs.writeFileSync(path.join(catalog, "node", "security.md"), "# pack");
  fs.mkdirSync(path.join(repo, ".review-pro"), { recursive: true });
  fs.writeFileSync(rulesPath(), RULES);
  logs = [];
  vi.spyOn(console, "log").mockImplementation((m) => void logs.push(String(m)));
  vi.spyOn(console, "error").mockImplementation((m) => void logs.push(String(m)));
});
afterEach(() => {
  vi.restoreAllMocks();
  fs.rmSync(repo, { recursive: true, force: true });
  fs.rmSync(catalog, { recursive: true, force: true });
});

describe(".review-pro/rules.md beside the stack packs", () => {
  it("is not listed as an installed stack", () => {
    installStack(repo, catalog, "node");
    expect(listInstalled(repo)).toEqual(["node"]);
  });

  it("survives installing and removing a stack", () => {
    installStack(repo, catalog, "node");
    removeStack(repo, "node");
    expect(fs.readFileSync(rulesPath(), "utf8")).toBe(RULES);
  });

  it("raises no doctor finding", () => {
    installStack(repo, catalog, "node");
    expect(diagnose(repo, catalog, ["security"])).toEqual([]);
  });

  it("is not printed by list", () => {
    list({ where: repo, catalogDir: catalog });
    expect(logs.join("\n")).not.toContain("rules");
  });

  it("cannot be removed as if it were a stack", () => {
    remove("rules.md", { where: repo });
    expect(logs.join("\n")).toContain("'rules.md' is not installed");
    expect(fs.readFileSync(rulesPath(), "utf8")).toBe(RULES);
  });
});
