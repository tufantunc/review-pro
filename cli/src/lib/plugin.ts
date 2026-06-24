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

export function detectInstalled(resolver: (t: Target) => string = resolveHome): Target[] {
  return TARGETS.filter((t) => fs.existsSync(resolver(t)));
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
