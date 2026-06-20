import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** Bundled plugin dir (dist/../plugin), else repo core/ in dev. */
export function resolvePluginDir(explicit?: string): string {
  if (explicit) return explicit;
  const bundled = path.resolve(__dirname, "..", "plugin");
  if (fs.existsSync(bundled)) return bundled;
  return path.resolve(__dirname, "..", "..", "core");
}

export function resolveOpenCodeHome(): string {
  return process.env.OPENCODE_HOME || path.join(os.homedir(), ".config", "opencode");
}

/** Copy <pluginDir>/skills/** and <pluginDir>/agents/** into <ocHome>/. */
export function installCore(
  pluginDir: string = resolvePluginDir(),
  ocHome: string = resolveOpenCodeHome(),
): void {
  fs.mkdirSync(path.join(ocHome, "skills"), { recursive: true });
  fs.mkdirSync(path.join(ocHome, "agents"), { recursive: true });
  const skillsSrc = path.join(pluginDir, "skills");
  for (const d of fs.readdirSync(skillsSrc, { withFileTypes: true })) {
    if (!d.isDirectory()) continue;
    const dest = path.join(ocHome, "skills", d.name);
    fs.rmSync(dest, { recursive: true, force: true });
    fs.cpSync(path.join(skillsSrc, d.name), dest, { recursive: true });
  }
  const agentsSrc = path.join(pluginDir, "agents");
  if (fs.existsSync(agentsSrc)) {
    for (const a of fs.readdirSync(agentsSrc)) {
      if (!a.endsWith(".md")) continue;
      fs.cpSync(path.join(agentsSrc, a), path.join(ocHome, "agents", a));
    }
  }
}
