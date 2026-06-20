export interface StackManifest {
  name: string;
  version: string;
  reviewers: string[];
}

const SEMVER = /^\d+\.\d+\.\d+(?:[-+].+)?$/;

export function parseManifest(raw: unknown): StackManifest {
  if (typeof raw !== "object" || raw === null) throw new Error("manifest: not an object");
  const r = raw as Record<string, unknown>;
  if (typeof r.name !== "string" || r.name.length === 0) throw new Error("manifest: missing 'name'");
  if (typeof r.version !== "string" || !SEMVER.test(r.version))
    throw new Error(`manifest: invalid 'version' (expected semver): ${String(r.version)}`);
  if (!Array.isArray(r.reviewers) || !r.reviewers.every((x) => typeof x === "string"))
    throw new Error("manifest: 'reviewers' must be a string array");
  return { name: r.name, version: r.version, reviewers: r.reviewers };
}
