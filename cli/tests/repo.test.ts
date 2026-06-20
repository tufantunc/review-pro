import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  listInstalled, installStack, removeStack, getInstalledManifest,
} from "../src/lib/repo.js";

let repo = "", catalog = "";
beforeEach(() => {
  repo = fs.mkdtempSync(path.join(os.tmpdir(), "rp-repo-"));
  catalog = fs.mkdtempSync(path.join(os.tmpdir(), "rp-cat-"));
  fs.mkdirSync(path.join(catalog, "node"), { recursive: true });
  fs.writeFileSync(path.join(catalog, "node", "manifest.json"),
    JSON.stringify({ name: "node", version: "0.1.0", reviewers: ["security"] }));
  fs.writeFileSync(path.join(catalog, "node", "security.md"), "# pack");
});
afterEach(() => {
  fs.rmSync(repo, { recursive: true, force: true });
  fs.rmSync(catalog, { recursive: true, force: true });
});

describe("repo (.review-pro/)", () => {
  it("installStack copies into .review-pro/<stack>", () => {
    const v = installStack(repo, catalog, "node");
    expect(v).toBe("0.1.0");
    expect(fs.existsSync(path.join(repo, ".review-pro", "node", "security.md"))).toBe(true);
    expect(listInstalled(repo)).toEqual(["node"]);
  });

  it("installStack overwrites existing", () => {
    installStack(repo, catalog, "node");
    fs.writeFileSync(path.join(catalog, "node", "manifest.json"),
      JSON.stringify({ name: "node", version: "0.2.0", reviewers: ["security"] }));
    const v = installStack(repo, catalog, "node");
    expect(v).toBe("0.2.0");
    expect(getInstalledManifest(repo, "node")?.version).toBe("0.2.0");
  });

  it("removeStack deletes the dir", () => {
    installStack(repo, catalog, "node");
    removeStack(repo, "node");
    expect(listInstalled(repo)).toEqual([]);
    expect(fs.existsSync(path.join(repo, ".review-pro", "node"))).toBe(false);
  });

  it("removeStack is a no-op when absent", () => {
    expect(() => removeStack(repo, "ghost")).not.toThrow();
  });

  it("getInstalledManifest returns null when missing", () => {
    expect(getInstalledManifest(repo, "ghost")).toBeNull();
  });
});
