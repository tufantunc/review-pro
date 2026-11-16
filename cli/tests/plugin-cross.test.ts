import { describe, it, expect, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { installCore, uninstallCore, detectInstalled, RETIRED_AGENTS, type Target } from "../src/lib/plugin.js";

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

  it.each(["claude-code", "opencode"] as const)("%s install removes agents a past release shipped and this one retired", (t) => {
    const agents = path.join(H(t), "agents");
    fs.mkdirSync(agents, { recursive: true });
    for (const a of RETIRED_AGENTS) fs.writeFileSync(path.join(agents, `${a}.md`), "# stale");
    fs.writeFileSync(path.join(agents, "my-own-agent.md"), "# mine");
    installCore(t, pluginSrc, H(t));
    for (const a of RETIRED_AGENTS) expect(fs.existsSync(path.join(agents, `${a}.md`))).toBe(false);
    expect(fs.existsSync(path.join(agents, "my-own-agent.md"))).toBe(true);
    expect(fs.existsSync(path.join(agents, "security-reviewer.md"))).toBe(true);
  });

  it.each(["claude-code", "opencode"] as const)("%s uninstall removes retired agents too", (t) => {
    const agents = path.join(H(t), "agents");
    installCore(t, pluginSrc, H(t));
    for (const a of RETIRED_AGENTS) fs.writeFileSync(path.join(agents, `${a}.md`), "# stale");
    uninstallCore(t, pluginSrc, H(t));
    for (const a of RETIRED_AGENTS) expect(fs.existsSync(path.join(agents, `${a}.md`))).toBe(false);
  });

  it("codex skips orchestrator subagents (triage/synthesize)", () => {
    fs.writeFileSync(path.join(pluginSrc, "agents", "review-pro-triage-subagent.md"),
      "---\nname: review-pro-triage-subagent\ndescription: \"x\"\nloads_skill: review-pro-triage\nskills: [review-pro-triage]\n---\n# body\n");
    fs.writeFileSync(path.join(pluginSrc, "agents", "review-pro-synthesize-subagent.md"),
      "---\nname: review-pro-synthesize-subagent\ndescription: \"x\"\nloads_skill: review-pro-synthesize\nskills: [review-pro-synthesize]\n---\n# body\n");
    fs.writeFileSync(path.join(pluginSrc, "agents", "review-pro-subagent.md"),
      "---\nname: review-pro-subagent\ndescription: \"x\"\nloads_skill: review-pro\nskills: [review-pro]\n---\n# body\n");
    installCore("codex", pluginSrc, H("codex2"), path.join(H("codex2"), "skills"));
    for (const a of ["review-pro-triage-subagent", "review-pro-synthesize-subagent", "review-pro-subagent"]) {
      expect(fs.existsSync(path.join(H("codex2"), "agents", `${a}.toml`))).toBe(false);
    }
  });

  const VERIFY_AGENT =
    "---\nname: review-pro-verify-subagent\ndescription: \"x\"\nloads_skill: review-pro-verify\nskills: [review-pro-verify]\n---\n# body\n";

  it("claude-code copies the verifier subagent (smoke test; the codex cases pin ORCHESTRATOR_SKILLS)", () => {
    fs.writeFileSync(path.join(pluginSrc, "agents", "review-pro-verify-subagent.md"), VERIFY_AGENT);
    installCore("claude-code", pluginSrc, H("cc-verify"));
    expect(fs.existsSync(path.join(H("cc-verify"), "agents", "review-pro-verify-subagent.md"))).toBe(true);
  });

  it("codex installs the verifier as a read-only subagent, unlike the inline stages", () => {
    fs.writeFileSync(path.join(pluginSrc, "agents", "review-pro-verify-subagent.md"), VERIFY_AGENT);
    installCore("codex", pluginSrc, H("codex-verify"), path.join(H("codex-verify"), "skills"));
    const toml = path.join(H("codex-verify"), "agents", "review-pro-verify-subagent.toml");
    expect(fs.existsSync(toml)).toBe(true);
    expect(fs.readFileSync(toml, "utf8")).toContain('sandbox_mode = "read-only"');
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
