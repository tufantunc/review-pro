import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { installCore, resolvePluginDir } from "../src/lib/plugin.js";

let pluginSrc = "", ocHome = "";
beforeEach(() => {
  pluginSrc = fs.mkdtempSync(path.join(os.tmpdir(), "rp-plug-"));
  ocHome = fs.mkdtempSync(path.join(os.tmpdir(), "rp-oc-"));
  fs.mkdirSync(path.join(pluginSrc, "skills", "security"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "skills", "security", "SKILL.md"), "# s");
  fs.mkdirSync(path.join(pluginSrc, "shared"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "shared", "output-schema.md"), "# schema");
  fs.mkdirSync(path.join(pluginSrc, "agents"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "agents", "security-reviewer.md"), "# a");
});
afterEach(() => {
  fs.rmSync(pluginSrc, { recursive: true, force: true });
  fs.rmSync(ocHome, { recursive: true, force: true });
});

describe("plugin", () => {
  it("installCore copies skills + agents into oc home", () => {
    installCore("opencode", pluginSrc, ocHome);
    expect(fs.existsSync(path.join(ocHome, "skills", "security", "SKILL.md"))).toBe(true);
    expect(fs.existsSync(path.join(ocHome, "agents", "security-reviewer.md"))).toBe(true);
  });

  it("installCore ships shared/ beside skills/ so `shared/<file>.md` pointers resolve", () => {
    installCore("opencode", pluginSrc, ocHome);
    // rubrics reference `shared/output-schema.md` relative to the skills root's
    // parent, mirroring the repo's core/ layout — so it must land here, not
    // inside a skill dir.
    expect(fs.existsSync(path.join(ocHome, "shared", "output-schema.md"))).toBe(true);
    expect(fs.existsSync(path.join(ocHome, "skills", "shared"))).toBe(false);
  });

  it("installCore is idempotent", () => {
    installCore("opencode", pluginSrc, ocHome);
    expect(() => installCore("opencode", pluginSrc, ocHome)).not.toThrow();
  });

  it("resolvePluginDir returns the provided arg", () => {
    expect(resolvePluginDir(pluginSrc)).toBe(pluginSrc);
  });
});
