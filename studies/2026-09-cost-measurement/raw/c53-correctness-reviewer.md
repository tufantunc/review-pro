<!-- c53 correctness-reviewer; verbatim final answer -->
## Correctness findings

- severity: Low
  category: correctness.logic
  file: cli/src/lib/doctor.ts
  line: 34
  title: A dangling-symlink pack is no longer reported as missing-pack, so doctor now reports a clean result for a broken install
  evidence: |
    function listPackFiles(dir: string): Set<string> {
      if (!fs.existsSync(dir)) return new Set();
      return new Set(fs.readdirSync(dir).filter((f) => f.endsWith(".md")));
    }
    ...
    if (!packs.has(`${r}.md`))
      out.push({ kind: "missing-pack", stack, detail: `${stack}: manifest declares '${r}' but ${r}.md missing` });
  evidence_refs: [cli/src/lib/doctor.ts:41, cli/src/commands/doctor.ts:11]
  impact: The old code checked each declared pack with `fs.existsSync(path.join(dir, `${r}.md`))`, which follows symlinks. The new code checks whether the name appears in `readdirSync`, which lists the link itself. I confirmed on this machine that `existsSync` returns `false` for a dangling `security.md` symlink while `readdirSync` returns `['security.md']`. Take a stack whose `security.md` is a symlink to a deleted file, with `security` as a known reviewer. The old code returned `missing-pack` and `commands/doctor.ts` exited 1. The new code returns `[]`, prints "no issues found" and exits 0, even though the pack cannot be read. This is the only divergence I found that changes the exit code. Reaching it needs a user-created symlink in `.review-pro/<stack>/`: `installStack` copies real files from the catalog, and no catalog stack ships symlinks. That is why this is Low.
  remedy: Keep a per-file existence check for declared reviewers, e.g. `packs.has(`${r}.md`) && fs.existsSync(path.join(dir, `${r}.md`))`. Or build the Set with `readdirSync(dir, { withFileTypes: true })` and drop entries where `isSymbolicLink()` is true and `fs.existsSync` fails. If the new behaviour is intended, add a test that pins it.
  confidence: high
  overlap_hints: [tests.coverage]

- severity: Nitpick
  category: correctness.logic
  file: cli/src/lib/doctor.ts
  line: 40
  title: A declared reviewer that differs only in case, or contains a path separator, now reports missing-pack instead of unknown-reviewer
  evidence: |
    if (!packs.has(`${r}.md`))
  impact: Set membership is an exact, case-sensitive string match. `existsSync` was case-insensitive on macOS/APFS and resolved path segments. Cases I traced:
    - Manifest `db`, file `Db.md`, known reviewers `["db"]`: old result was a single `unknown-reviewer` for `Db.md`. New result is `missing-pack` for `db` plus the same `unknown-reviewer`.
    - Reviewer `sub/x` with `sub/x.md` present: old result was `unknown-reviewer`. New result is `missing-pack`.

    In every case I traced, both versions return a non-empty list and exit 1. Only the reported kind and message change. The drift/orphan, then declared, then stray ordering is preserved, and stray-pack order still follows `readdir` order, because a Set keeps insertion order.
  remedy: No action needed unless the message wording matters. A test with a case-mismatched pack would document the new behaviour.
  confidence: high
  overlap_hints: []

- severity: Nitpick
  category: correctness.devex
  file: cli/package-lock.json
  line: 1015
  title: Regenerating the lockfile removed the `libc` fields from the rolldown and lightningcss Linux bindings
  evidence: |
    -      "libc": [
    -        "glibc"
    -      ],
  impact: The `libc` fields were removed from 10 optional platform packages: `@rolldown/binding-linux-*-{gnu,musl}` and `lightningcss-linux-*-{gnu,musl}`. This pattern usually means the lockfile was regenerated with an npm version that does not write `libc`. Without the field, `npm ci` cannot skip musl bindings on glibc Linux (or glibc bindings on musl). Both variants may install on CI; they are dev-only and optional, so nothing breaks. The next `npm install` with an npm that writes `libc` will add the fields back, which creates unrelated lockfile churn.
  remedy: Regenerate the lockfile with the npm version the repo normally uses (the one that wrote the `libc` fields on main), so this diff only adds the `@vitest/coverage-v8` tree.
  confidence: medium
  overlap_hints: []

Everything else I checked keeps the old behaviour:
- orphan is still reported before drift.
- A stack directory that is actually a file still throws ENOTDIR, just earlier than before.
- A directory named `*.md` counts as present in both versions.
- The two new tests pass against the old implementation as well.
- `vitest.config.ts` only adds coverage reporters. It is outside `tsconfig` `include: ["src"]`, so it does not affect `tsc` or `tsup`. The coverage output directory `cli/coverage` matches the new `.gitignore` entry.

One limit: this checkout has no `node_modules`, so I did not run the test suite. The symlink and case findings rest on direct Node checks of `existsSync` and `readdirSync`.

## Files examined
examined: [cli/src/lib/doctor.ts, cli/tests/doctor.test.ts, cli/package.json, cli/vitest.config.ts, .gitignore, cli/package-lock.json]
not_examined: []
