import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { diagnose } from "../src/lib/doctor.js";
import { installStack } from "../src/lib/repo.js";

let repo = "", catalog = "";
beforeEach(() => {
  repo = fs.mkdtempSync(path.join(os.tmpdir(), "rp-repo-"));
  catalog = fs.mkdtempSync(path.join(os.tmpdir(), "rp-cat-"));
  fs.mkdirSync(path.join(catalog, "node"), { recursive: true });
  fs.writeFileSync(path.join(catalog, "node", "manifest.json"),
    JSON.stringify({ name: "node", version: "0.1.0", reviewers: ["security"] }));
  fs.writeFileSync(path.join(catalog, "node", "security.md"), "# pack");
  fs.writeFileSync(path.join(catalog, "reviewers.json"), JSON.stringify({ reviewers: ["security"] }));
});
afterEach(() => {
  fs.rmSync(repo, { recursive: true, force: true });
  fs.rmSync(catalog, { recursive: true, force: true });
});

describe("doctor", () => {
  it("reports no issues when up-to-date", () => {
    installStack(repo, catalog, "node");
    expect(diagnose(repo, catalog, ["security"])).toEqual([]);
  });

  it("reports version drift", () => {
    installStack(repo, catalog, "node");
    fs.writeFileSync(path.join(catalog, "node", "manifest.json"),
      JSON.stringify({ name: "node", version: "0.2.0", reviewers: ["security"] }));
    const d = diagnose(repo, catalog, ["security"]);
    expect(d.some((x) => x.kind === "drift" && x.stack === "node")).toBe(true);
  });

  it("reports orphan (installed but not in catalog)", () => {
    fs.mkdirSync(path.join(repo, ".review-pro", "ghost"), { recursive: true });
    fs.writeFileSync(path.join(repo, ".review-pro", "ghost", "manifest.json"),
      JSON.stringify({ name: "ghost", version: "0.1.0", reviewers: [] }));
    const d = diagnose(repo, catalog, ["security"]);
    expect(d.some((x) => x.kind === "orphan" && x.stack === "ghost")).toBe(true);
  });

  it("reports unknown reviewer in pack", () => {
    fs.mkdirSync(path.join(repo, ".review-pro", "node"), { recursive: true });
    fs.writeFileSync(path.join(repo, ".review-pro", "node", "manifest.json"),
      JSON.stringify({ name: "node", version: "0.1.0", reviewers: ["security", "ghost"] }));
    fs.writeFileSync(path.join(repo, ".review-pro", "node", "ghost.md"), "# pack");
    const d = diagnose(repo, catalog, ["security"]);
    expect(d.some((x) => x.kind === "unknown-reviewer" && x.stack === "node")).toBe(true);
  });

  it("reports missing pack file declared in manifest", () => {
    fs.mkdirSync(path.join(repo, ".review-pro", "node"), { recursive: true });
    fs.writeFileSync(path.join(repo, ".review-pro", "node", "manifest.json"),
      JSON.stringify({ name: "node", version: "0.1.0", reviewers: ["security"] }));
    const d = diagnose(repo, catalog, ["security"]);
    expect(d.some((x) => x.kind === "missing-pack" && x.stack === "node")).toBe(true);
  });

  it("passes silently over stray packs for known reviewers the manifest does not declare", () => {
    installStack(repo, catalog, "node");
    fs.writeFileSync(path.join(repo, ".review-pro", "node", "db.md"), "# pack");
    expect(diagnose(repo, catalog, ["security", "db"])).toEqual([]);
  });

  it("flags stray packs targeting unknown reviewers", () => {
    installStack(repo, catalog, "node");
    fs.writeFileSync(path.join(repo, ".review-pro", "node", "mystery.md"), "# pack");
    expect(diagnose(repo, catalog, ["security"])).toEqual([
      { kind: "unknown-reviewer", stack: "node", detail: "node: pack 'mystery.md' targets unknown reviewer" },
    ]);
  });
});
