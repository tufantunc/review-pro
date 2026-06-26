import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { installCore, detectInstalled, type Target } from "../src/lib/plugin.js";

let pluginSrc = "", homes = "";
beforeEach(() => {
  pluginSrc = fs.mkdtempSync(path.join(os.tmpdir(), "rp-plug-"));
  homes = fs.mkdtempSync(path.join(os.tmpdir(), "rp-homes-"));
  fs.mkdirSync(path.join(pluginSrc, "skills", "security"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "skills", "security", "SKILL.md"), "# s");
  fs.mkdirSync(path.join(pluginSrc, "agents"), { recursive: true });
  fs.writeFileSync(path.join(pluginSrc, "agents", "security-reviewer.md"),
    "---\nname: security-reviewer\ndescription: \"x\"\nloads_skill: security\nskills: [security]\n---\n# body\n");
});
afterEach(() => {
  fs.rmSync(pluginSrc, { recursive: true, force: true });
  fs.rmSync(homes, { recursive: true, force: true });
});

const H = (t: string) => path.join(homes, t);

describe("installCore per target", () => {
  it("opencode copies skills + agents as-is", () => {
    installCore("opencode", pluginSrc, H("opencode"));
    expect(fs.existsSync(path.join(H("opencode"), "skills", "security", "SKILL.md"))).toBe(true);
    expect(fs.existsSync(path.join(H("opencode"), "agents", "security-reviewer.md"))).toBe(true);
  });

  it("claude-code copies skills + agents as-is", () => {
    installCore("claude-code", pluginSrc, H("claude-code"));
    expect(fs.existsSync(path.join(H("claude-code"), "skills", "security", "SKILL.md"))).toBe(true);
    expect(fs.existsSync(path.join(H("claude-code"), "agents", "security-reviewer.md"))).toBe(true);
  });

  it("codex copies skills to skillsHome and transforms agents to .toml", () => {
    installCore("codex", pluginSrc, H("codex"), path.join(H("codex"), "skills"));
    expect(fs.existsSync(path.join(H("codex"), "skills", "security", "SKILL.md"))).toBe(true);
    const toml = path.join(H("codex"), "agents", "security-reviewer.toml");
    expect(fs.existsSync(toml)).toBe(true);
    const content = fs.readFileSync(toml, "utf8");
    expect(content).toContain('name = "security-reviewer"');
    expect(content).not.toContain('[[skills.config]]');
  });

  it("codex skips orchestrator subagents (triage/synthesize)", () => {
    fs.writeFileSync(path.join(pluginSrc, "agents", "review-pro-triage-subagent.md"),
      "---\nname: review-pro-triage-subagent\ndescription: \"x\"\nloads_skill: review-pro-triage\nskills: [review-pro-triage]\n---\n# body\n");
    installCore("codex", pluginSrc, H("codex2"), path.join(H("codex2"), "skills"));
    expect(fs.existsSync(path.join(H("codex2"), "agents", "review-pro-triage-subagent.toml"))).toBe(false);
  });

  it("cursor is a no-op (installed via /add-plugin)", () => {
    installCore("cursor", pluginSrc, H("cursor"));
    expect(fs.existsSync(path.join(H("cursor"), "plugins"))).toBe(false);
  });

  it("detectInstalled finds binaries in PATH (not stale dirs)", () => {
    const origPath = process.env.PATH;
    const binDir = fs.mkdtempSync(path.join(os.tmpdir(), "rp-bin-"));
    const ext = process.platform === "win32" ? ".exe" : "";
    fs.writeFileSync(path.join(binDir, "opencode" + ext), "");
    fs.writeFileSync(path.join(binDir, "codex" + ext), "");
    process.env.PATH = binDir;
    const found = detectInstalled();
    expect(found).toContain("opencode");
    expect(found).toContain("codex");
    expect(found).not.toContain("claude-code");
    process.env.PATH = origPath;
    fs.rmSync(binDir, { recursive: true, force: true });
  });
});
