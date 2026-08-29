import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { installCore, uninstallCore, resolveTargets } from "../src/lib/plugin.js";

let pluginSrc = "", homes = "";
beforeEach(() => {
  pluginSrc = fs.mkdtempSync(path.join(os.tmpdir(), "rp-plug-"));
  homes = fs.mkdtempSync(path.join(os.tmpdir(), "rp-homes-"));
  fs.mkdirSync(path.join(pluginSrc, "skills", "security"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "skills", "security", "SKILL.md"), "# s");
  fs.mkdirSync(path.join(pluginSrc, "skills", "craft"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "skills", "craft", "SKILL.md"), "# c");
  fs.mkdirSync(path.join(pluginSrc, "shared"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "shared", "output-schema.md"), "# schema");
  fs.mkdirSync(path.join(pluginSrc, "agents"), { recursive: true });
  fs.writeFileSync(
    path.join(pluginSrc, "agents", "security-reviewer.md"),
    "---\nname: security-reviewer\ndescription: \"x\"\nloads_skill: security\nskills: [security]\n---\n# body\n",
  );
});
afterEach(() => {
  fs.rmSync(pluginSrc, { recursive: true, force: true });
  fs.rmSync(homes, { recursive: true, force: true });
});

const H = (t: string) => path.join(homes, t);

describe("resolveTargets", () => {
  it("all -> every target", () => {
    expect(resolveTargets("all")).toEqual(["opencode", "claude-code", "cursor", "codex"]);
  });
  it("single valid target", () => {
    expect(resolveTargets("opencode")).toEqual(["opencode"]);
  });
  it("comma-separated list", () => {
    expect(resolveTargets("opencode,codex")).toEqual(["opencode", "codex"]);
  });
  it("unknown -> empty", () => {
    expect(resolveTargets("nope")).toEqual([]);
  });
});

describe("uninstallCore per target", () => {
  it("opencode removes skills + agents, keeps parent dirs", () => {
    installCore("opencode", pluginSrc, H("opencode"));
    uninstallCore("opencode", pluginSrc, H("opencode"));
    expect(fs.existsSync(path.join(H("opencode"), "skills", "security"))).toBe(false);
    expect(fs.existsSync(path.join(H("opencode"), "skills", "craft"))).toBe(false);
    expect(fs.existsSync(path.join(H("opencode"), "agents", "security-reviewer.md"))).toBe(false);
    expect(fs.existsSync(path.join(H("opencode"), "skills"))).toBe(true);
    expect(fs.existsSync(path.join(H("opencode"), "agents"))).toBe(true);
  });

  it("removes shipped shared/ files, and leaves a user's own file alone", () => {
    const home = H("opencode");
    installCore("opencode", pluginSrc, home);
    expect(fs.existsSync(path.join(home, "shared", "output-schema.md"))).toBe(true);
    // a file we never shipped must survive, and keep the dir alive with it
    fs.writeFileSync(path.join(home, "shared", "mine.md"), "# mine");
    uninstallCore("opencode", pluginSrc, home);
    expect(fs.existsSync(path.join(home, "shared", "output-schema.md"))).toBe(false);
    expect(fs.existsSync(path.join(home, "shared", "mine.md"))).toBe(true);
  });

  it("removes the shared dir when nothing else is left in it", () => {
    const home = H("claude-code");
    installCore("claude-code", pluginSrc, home);
    uninstallCore("claude-code", pluginSrc, home);
    expect(fs.existsSync(path.join(home, "shared"))).toBe(false);
  });

  it("codex removes shared beside its skills home", () => {
    const home = H("codex");
    const sHome = path.join(home, "skills");
    installCore("codex", pluginSrc, home, sHome);
    expect(fs.existsSync(path.join(home, "shared", "output-schema.md"))).toBe(true);
    uninstallCore("codex", pluginSrc, home, sHome);
    expect(fs.existsSync(path.join(home, "shared"))).toBe(false);
  });

  it("claude-code removes skills + agents", () => {
    installCore("claude-code", pluginSrc, H("claude-code"));
    uninstallCore("claude-code", pluginSrc, H("claude-code"));
    expect(fs.existsSync(path.join(H("claude-code"), "skills", "security"))).toBe(false);
    expect(fs.existsSync(path.join(H("claude-code"), "agents", "security-reviewer.md"))).toBe(false);
  });

  it("codex removes skills + reviewer .toml", () => {
    fs.writeFileSync(path.join(pluginSrc, "agents", "notes.txt"), "not an agent");
    installCore("codex", pluginSrc, H("codex"), path.join(H("codex"), "skills"));
    uninstallCore("codex", pluginSrc, H("codex"), path.join(H("codex"), "skills"));
    expect(fs.existsSync(path.join(H("codex"), "skills", "security"))).toBe(false);
    expect(fs.existsSync(path.join(H("codex"), "agents", "security-reviewer.toml"))).toBe(false);
  });

  it("codex skips orchestrator agents that were never written", () => {
    fs.writeFileSync(
      path.join(pluginSrc, "agents", "review-pro-triage-subagent.md"),
      "---\nname: review-pro-triage-subagent\ndescription: \"x\"\nloads_skill: review-pro-triage\nskills: [review-pro-triage]\n---\n# body\n",
    );
    installCore("codex", pluginSrc, H("codex2"), path.join(H("codex2"), "skills"));
    // A user-authored file colliding with the orchestrator agent's name must
    // survive: install never wrote that .toml, so uninstall must not touch it.
    const decoy = path.join(H("codex2"), "agents", "review-pro-triage-subagent.toml");
    fs.writeFileSync(decoy, "# user's own");
    expect(() => uninstallCore("codex", pluginSrc, H("codex2"), path.join(H("codex2"), "skills"))).not.toThrow();
    expect(fs.existsSync(decoy)).toBe(true);
  });

  it("is idempotent - second call throws nothing", () => {
    installCore("opencode", pluginSrc, H("oc"));
    uninstallCore("opencode", pluginSrc, H("oc"));
    expect(() => uninstallCore("opencode", pluginSrc, H("oc"))).not.toThrow();
  });

  it("is a no-op on a home that was never installed", () => {
    expect(() => uninstallCore("opencode", pluginSrc, H("empty"))).not.toThrow();
  });

  it("codex removes skills even when plugin agents dir is absent", () => {
    const emptyPlugin = fs.mkdtempSync(path.join(os.tmpdir(), "rp-empty-"));
    fs.mkdirSync(path.join(emptyPlugin, "skills", "security"), { recursive: true });
    fs.writeFileSync(path.join(emptyPlugin, "skills", "security", "SKILL.md"), "# s");
    const codexSkills = path.join(H("codex-empty"), "skills");
    installCore("codex", pluginSrc, H("codex-empty"), codexSkills);
    expect(fs.existsSync(path.join(codexSkills, "security"))).toBe(true);
    try {
      expect(() => uninstallCore("codex", emptyPlugin, H("codex-empty"), codexSkills)).not.toThrow();
    } finally {
      fs.rmSync(emptyPlugin, { recursive: true, force: true });
    }
    expect(fs.existsSync(path.join(codexSkills, "security"))).toBe(false);
  });

  it("does not touch a user's own skill folder", () => {
    installCore("opencode", pluginSrc, H("oc"));
    fs.mkdirSync(path.join(H("oc"), "skills", "my-own-skill"), { recursive: true });
    fs.writeFileSync(path.join(H("oc"), "skills", "my-own-skill", "SKILL.md"), "# mine");
    uninstallCore("opencode", pluginSrc, H("oc"));
    expect(fs.existsSync(path.join(H("oc"), "skills", "my-own-skill", "SKILL.md"))).toBe(true);
  });

  it("cursor is a no-op (guidance-only)", () => {
    fs.mkdirSync(H("cursor"), { recursive: true });
    expect(() => uninstallCore("cursor", pluginSrc, H("cursor"))).not.toThrow();
    expect(fs.existsSync(H("cursor"))).toBe(true);
  });
});
