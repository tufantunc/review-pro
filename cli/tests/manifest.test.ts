import { describe, it, expect } from "vitest";
import { parseManifest, versionMark } from "../src/lib/manifest.js";

describe("parseManifest", () => {
  it("parses a valid manifest", () => {
    const m = parseManifest({ name: "node", version: "0.1.0", reviewers: ["security", "db"] });
    expect(m).toEqual({ name: "node", version: "0.1.0", reviewers: ["security", "db"] });
  });

  it("throws on missing name", () => {
    expect(() => parseManifest({ version: "0.1.0", reviewers: [] })).toThrow(/name/);
  });

  it("throws on missing version", () => {
    expect(() => parseManifest({ name: "x", reviewers: [] })).toThrow(/version/);
  });

  it("throws on non-array reviewers", () => {
    expect(() => parseManifest({ name: "x", version: "1.0.0", reviewers: "nope" })).toThrow(/reviewers/);
  });

  it("throws on malformed version", () => {
    expect(() => parseManifest({ name: "x", version: "latest", reviewers: [] })).toThrow(/version/);
  });
});

describe("versionMark", () => {
  it("marks uninstalled stacks with an em dash", () => {
    expect(versionMark(undefined, "1.2.0")).toBe("—");
  });

  it("marks matching versions with =", () => {
    expect(versionMark("1.2.0", "1.2.0")).toBe("=");
  });

  it("marks older installed versions with <", () => {
    expect(versionMark("1.1.9", "1.2.0")).toBe("<");
  });

  it("marks newer installed versions with >", () => {
    expect(versionMark("1.3.0", "1.2.0")).toBe(">");
  });

  it("compares lexically, so 1.10 reads as older than 1.9 like the original chain", () => {
    expect(versionMark("1.10.0", "1.9.0")).toBe("<");
  });

  it("compares lexically, so a prerelease suffix reads as newer than its release", () => {
    expect(versionMark("1.2.0-rc.1", "1.2.0")).toBe(">");
  });
});
