import fs from "node:fs";
import path from "node:path";
import { parseManifest, type StackManifest } from "./manifest.js";

/** Printed after any command that installs or changes a pack. A review reads packs from the
 *  merge base, never the working tree (ADR-0012), so a pack installed here applies only once
 *  it is committed to the base branch. */
export const PACKS_FROM_BASE_NOTE =
  "a review reads packs from the merge base: commit .review-pro/ to your base branch, and changes branched after that apply them.";

export function reviewProDir(repoRoot: string): string {
  return path.join(repoRoot, ".review-pro");
}

export function listInstalled(repoRoot: string): string[] {
  const dir = reviewProDir(repoRoot);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(dir, d.name, "manifest.json")))
    .map((d) => d.name);
}

export function getInstalledManifest(repoRoot: string, stack: string): StackManifest | null {
  const f = path.join(reviewProDir(repoRoot), stack, "manifest.json");
  if (!fs.existsSync(f)) return null;
  return parseManifest(JSON.parse(fs.readFileSync(f, "utf8")));
}

/** Copy catalogDir/<stack> -> repoRoot/.review-pro/<stack> (overwrite). Returns installed version. */
export function installStack(repoRoot: string, catalogDir: string, stack: string): string {
  const src = path.join(catalogDir, stack);
  if (!fs.existsSync(path.join(src, "manifest.json")))
    throw new Error(`stack '${stack}' not found in catalog`);
  const dest = path.join(reviewProDir(repoRoot), stack);
  fs.mkdirSync(reviewProDir(repoRoot), { recursive: true });
  fs.rmSync(dest, { recursive: true, force: true });
  fs.cpSync(src, dest, { recursive: true });
  const m = parseManifest(JSON.parse(fs.readFileSync(path.join(dest, "manifest.json"), "utf8")));
  return m.version;
}

export function removeStack(repoRoot: string, stack: string): void {
  const dest = path.join(reviewProDir(repoRoot), stack);
  fs.rmSync(dest, { recursive: true, force: true });
}
