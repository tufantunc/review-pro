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
fs.cpSync(path.join(root, "core"), pluginDst, { recursive: true });

// reviewers.json from repo manifest.json (reviewer-role skills only)
const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));
const reviewers = manifest.skills.filter((s) => s.role === "reviewer").map((s) => s.name);
fs.writeFileSync(path.join(catalogDst, "reviewers.json"), JSON.stringify({ reviewers }, null, 2) + "\n");

console.log(`built assets: ${reviewers.length} reviewers, catalog + plugin copied`);
