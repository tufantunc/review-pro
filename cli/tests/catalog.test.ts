import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { listCatalogStacks, readStackManifest, resolveReviewers } from "../src/lib/catalog.js";

let tmp = "";
beforeEach(() => { tmp = fs.mkdtempSync(path.join(os.tmpdir(), "rp-cat-")); });
afterEach(() => { fs.rmSync(tmp, { recursive: true, force: true }); });

function writeStack(name: string, reviewers: string[] = ["security"]) {
  fs.mkdirSync(path.join(tmp, name), { recursive: true });
  fs.writeFileSync(
    path.join(tmp, name, "manifest.json"),
    JSON.stringify({ name, version: "0.1.0", reviewers }),
  );
  fs.writeFileSync(path.join(tmp, name, "security.md"), "# pack");
}

describe("catalog", () => {
  it("lists stacks", () => {
    writeStack("node"); writeStack("go");
    expect(listCatalogStacks(tmp).sort()).toEqual(["go", "node"]);
  });

  it("reads a stack manifest", () => {
    writeStack("node", ["security", "db"]);
    expect(readStackManifest(tmp, "node")).toEqual({
      name: "node", version: "0.1.0", reviewers: ["security", "db"],
    });
  });

  it("returns null for missing stack", () => {
    expect(readStackManifest(tmp, "ghost")).toBeNull();
  });

  it("resolves reviewers from reviewers.json if present", () => {
    fs.writeFileSync(path.join(tmp, "reviewers.json"),
      JSON.stringify({ reviewers: ["security", "craft"] }));
    expect(resolveReviewers(tmp).sort()).toEqual(["craft", "security"]);
  });

  it("resolves reviewers from manifest.json fallback (dev: manifest in catalog parent)", () => {
    const devRoot = fs.mkdtempSync(path.join(os.tmpdir(), "rp-dev-"));
    const stacksDir = path.join(devRoot, "stacks");
    fs.mkdirSync(stacksDir);
    fs.writeFileSync(path.join(devRoot, "manifest.json"),
      JSON.stringify({ skills: [
        { name: "security", role: "reviewer" },
        { name: "review-pro-triage", role: "orchestrator" },
      ] }));
    expect(resolveReviewers(stacksDir).sort()).toEqual(["security"]);
    fs.rmSync(devRoot, { recursive: true, force: true });
  });
});
