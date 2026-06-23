// Copies stacks/ -> cli/catalog/ and core/ -> cli/plugin/, and generates
// cli/catalog/reviewers.json from the repo manifest.json. Run after tsup.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");

const catalogDst = path.join(__dirname, "catalog");
const pluginDst = path.join(__dirname, "plugin");

fs.rmSync(catalogDst, { recursive: true, force: true });
fs.rmSync(pluginDst, { recursive: true, force: true });
fs.cpSync(path.join(root, "stacks"), catalogDst, { recursive: true });
// stacks/ ships repo docs (README.md, CONTRIBUTING.md) that aren't part of the
// installer payload — drop them from the bundled catalog. (.npmignore can't,
// because `catalog` is listed as a directory in package.json `files`.)
fs.rmSync(path.join(catalogDst, "README.md"), { force: true });
fs.rmSync(path.join(catalogDst, "CONTRIBUTING.md"), { force: true });
fs.cpSync(path.join(root, "core"), pluginDst, { recursive: true });

// reviewers.json from repo manifest.json (reviewer-role skills only)
const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));
const reviewers = manifest.skills.filter((s) => s.role === "reviewer").map((s) => s.name);
fs.writeFileSync(path.join(catalogDst, "reviewers.json"), JSON.stringify({ reviewers }, null, 2) + "\n");

// Cursor plugin manifest (repo root .cursor-plugin/plugin.json) for flat-copy install.
// installCore("cursor") looks it up at <pluginDir>/../.cursor-plugin/plugin.json, i.e. cli/.cursor-plugin/.
const cursorManifestSrc = path.join(root, ".cursor-plugin", "plugin.json");
if (fs.existsSync(cursorManifestSrc)) {
  fs.mkdirSync(path.join(__dirname, ".cursor-plugin"), { recursive: true });
  fs.cpSync(cursorManifestSrc, path.join(__dirname, ".cursor-plugin", "plugin.json"));
}

console.log(`built assets: ${reviewers.length} reviewers, catalog + plugin + cursor manifest copied`);
