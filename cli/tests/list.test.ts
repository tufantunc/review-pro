import { describe, it, expect } from "vitest";
import { versionMark } from "../src/commands/list.js";

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
});
