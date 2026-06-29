import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseAgentMd, mdToCodexToml } from "./agents.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export type Target = "opencode" | "claude-code" | "cursor" | "codex";
export const TARGETS: Target[] = ["opencode", "claude-code", "cursor", "codex"];
const ORCHESTRATOR_SKILLS = new Set(["review-pro-triage", "review-pro-synthesize", "review-pro"]);

/** Bundled plugin dir (dist/../plugin), else repo core/ in dev. */
export function resolvePluginDir(explicit?: string): string {
  if (explicit) return explicit;
  const bundled = path.resolve(__dirname, "..", "plugin");
  if (fs.existsSync(bundled)) return bundled;
  return path.resolve(__dirname, "..", "..", "core");
}

export function resolveHome(target: Target): string {
  const h = (...p: string[]) => path.join(os.homedir(), ...p);
  switch (target) {
    case "opencode": return process.env.OPENCODE_HOME || h(".config", "opencode");
    case "claude-code": return h(".claude");
    case "cursor": return h(".cursor");
    case "codex": return process.env.CODEX_HOME || h(".codex");
  }
}

const PLATFORM_BINARIES: Record<Target, string> = {
  opencode: "opencode",
  "claude-code": "claude",
  cursor: "cursor",
  codex: "codex",
};

function isBinaryInPath(binary: string): boolean {
  const sep = process.platform === "win32" ? ";" : ":";
  const exts = process.platform === "win32" ? [".exe", ".cmd", ".bat", ""] : [""];
  const pathVar = process.env.PATH || process.env.Path || "";
  return pathVar.split(sep).some(function (dir) {
    return exts.some(function (ext) {
      return fs.existsSync(path.join(dir, binary + ext));
    });
  });
}

function isMacOsAppInstalled(appName: string): boolean {
  return process.platform === "darwin" && (
    fs.existsSync(path.join("/Applications", appName)) ||
    fs.existsSync(path.join(os.homedir(), "Applications", appName))
  );
}

export function detectInstalled(): Target[] {
  return TARGETS.filter(function (t) {
    if (t === "cursor") {
      return isBinaryInPath("cursor") || isMacOsAppInstalled("Cursor.app");
    }
    return isBinaryInPath(PLATFORM_BINARIES[t]);
  });
}

export function resolveTargets(target: string): Target[] {
  if (target === "all") return [...TARGETS];
  if (target === "auto") return detectInstalled();
  if ((TARGETS as readonly string[]).includes(target)) return [target as Target];
  const parts = target.split(",").map((s) => s.trim());
  if (parts.every((p) => (TARGETS as readonly string[]).includes(p))) {
    return parts as Target[];
  }
  return [];
}

function cliVersion(): string {
  const p = path.resolve(__dirname, "..", "package.json");
  try {
    return JSON.parse(fs.readFileSync(p, "utf8")).version || "0.0.0";
  } catch {
    return "0.0.0";
  }
}

function copySkills(src: string, dst: string): void {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dst, { recursive: true });
  for (const d of fs.readdirSync(src, { withFileTypes: true })) {
    if (!d.isDirectory()) continue;
    const target = path.join(dst, d.name);
    fs.rmSync(target, { recursive: true, force: true });
    fs.cpSync(path.join(src, d.name), target, { recursive: true });
  }
}

function copyAgentsMd(src: string, dst: string): void {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dst, { recursive: true });
  for (const a of fs.readdirSync(src)) {
    if (!a.endsWith(".md")) continue;
    fs.cpSync(path.join(src, a), path.join(dst, a));
  }
}

function installCodexAgents(src: string, dst: string): void {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dst, { recursive: true });
  for (const a of fs.readdirSync(src)) {
    if (!a.endsWith(".md")) continue;
    const agent = parseAgentMd(fs.readFileSync(path.join(src, a), "utf8"));
    if (ORCHESTRATOR_SKILLS.has(agent.loads_skill)) continue;
    fs.writeFileSync(path.join(dst, `${agent.name}.toml`), mdToCodexToml(agent));
  }
}

export function installCore(
  target: Target,
  pluginDir: string = resolvePluginDir(),
  home: string = resolveHome(target),
  skillsHome?: string,
): void {
  const skillsSrc = path.join(pluginDir, "skills");
  const agentsSrc = path.join(pluginDir, "agents");

  switch (target) {
    case "opencode":
    case "claude-code": {
      copySkills(skillsSrc, path.join(home, "skills"));
      copyAgentsMd(agentsSrc, path.join(home, "agents"));
      return;
    }
    case "cursor": {
      // Cursor plugins are installed via /add-plugin, not filesystem copy.
      // The caller (init.ts) prints the guidance message.
      return;
    }
    case "codex": {
      const sHome = skillsHome || path.join(os.homedir(), ".agents", "skills");
      copySkills(skillsSrc, sHome);
      installCodexAgents(agentsSrc, path.join(home, "agents"));
      return;
    }
  }
}

function listSkillNames(src: string): string[] {
  if (!fs.existsSync(src)) return [];
  return fs.readdirSync(src, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);
}

function listAgentNames(src: string): string[] {
  if (!fs.existsSync(src)) return [];
  return fs.readdirSync(src)
    .filter((f) => f.endsWith(".md"))
    .map((f) => f.slice(0, -3));
}

export function uninstallCore(
  target: Target,
  pluginDir: string = resolvePluginDir(),
  home: string = resolveHome(target),
  skillsHome?: string,
): void {
  const skillsSrc = path.join(pluginDir, "skills");
  const agentsSrc = path.join(pluginDir, "agents");
  const skillNames = listSkillNames(skillsSrc);

  switch (target) {
    case "opencode":
    case "claude-code": {
      for (const s of skillNames) fs.rmSync(path.join(home, "skills", s), { recursive: true, force: true });
      for (const a of listAgentNames(agentsSrc)) fs.rmSync(path.join(home, "agents", `${a}.md`), { force: true });
      return;
    }
    case "cursor": {
      return;
    }
    case "codex": {
      if (!fs.existsSync(agentsSrc)) return;
      const sHome = skillsHome || path.join(os.homedir(), ".agents", "skills");
      for (const s of skillNames) fs.rmSync(path.join(sHome, s), { recursive: true, force: true });
      for (const a of fs.readdirSync(agentsSrc)) {
        if (!a.endsWith(".md")) continue;
        const agent = parseAgentMd(fs.readFileSync(path.join(agentsSrc, a), "utf8"));
        if (ORCHESTRATOR_SKILLS.has(agent.loads_skill)) continue;
        fs.rmSync(path.join(home, "agents", `${agent.name}.toml`), { force: true });
      }
      return;
    }
  }
}
