import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseManifest, type StackManifest } from "./manifest.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** Bundled catalog dir (dist/../catalog), else repo stacks/ in dev. */
export function resolveCatalogDir(): string {
  const bundled = path.resolve(__dirname, "..", "catalog");
  if (fs.existsSync(bundled)) return bundled;
  return path.resolve(__dirname, "..", "..", "stacks");
}

export function listCatalogStacks(catalogDir: string = resolveCatalogDir()): string[] {
  return fs
    .readdirSync(catalogDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(catalogDir, d.name, "manifest.json")))
    .map((d) => d.name);
}

export function readStackManifest(
  catalogDir: string = resolveCatalogDir(),
  stack: string,
): StackManifest | null {
  const f = path.join(catalogDir, stack, "manifest.json");
  if (!fs.existsSync(f)) return null;
  return parseManifest(JSON.parse(fs.readFileSync(f, "utf8")));
}

/** Bundled reviewers.json (build output) else repo manifest.json (dev). */
export function resolveReviewers(catalogDir: string = resolveCatalogDir()): string[] {
  const rj = path.join(catalogDir, "reviewers.json");
  if (fs.existsSync(rj)) {
    const d = JSON.parse(fs.readFileSync(rj, "utf8"));
    if (Array.isArray(d.reviewers)) return d.reviewers;
  }
  const rootManifest = path.resolve(catalogDir, "..", "manifest.json");
  if (fs.existsSync(rootManifest)) {
    const d = JSON.parse(fs.readFileSync(rootManifest, "utf8"));
    if (Array.isArray(d.skills))
      return d.skills.filter((s: any) => s.role === "reviewer").map((s: any) => s.name);
  }
  return [];
}
