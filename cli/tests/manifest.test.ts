import { describe, it, expect } from "vitest";
import { parseManifest } from "../src/lib/manifest.js";

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
