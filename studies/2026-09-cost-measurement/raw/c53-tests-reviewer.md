<!-- c53 tests-reviewer; verbatim final answer -->
## Tests findings

- severity: Medium
  category: tests.coverage
  file: cli/src/lib/doctor.ts
  line: 54
  title: No test fails if the guard that stops a declared, unknown reviewer being reported twice is removed
  evidence: |
    function checkStrayPacks(stack: string, packs: Set<string>, m: StackManifest, knownReviewers: string[]): Diagnosis[] {
      ...
        if (!m.reviewers.includes(r) && !knownReviewers.includes(r))
          out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${f}' targets unknown reviewer` });

    // cli/tests/doctor.test.ts:47-51 (the only test with a declared, unknown reviewer)
      JSON.stringify({ name: "node", version: "0.1.0", reviewers: ["security", "ghost"] }));
    fs.writeFileSync(path.join(repo, ".review-pro", "node", "ghost.md"), "# pack");
    const d = diagnose(repo, catalog, ["security"]);
    expect(d.some((x) => x.kind === "unknown-reviewer" && x.stack === "node")).toBe(true);
  evidence_refs: [cli/tests/doctor.test.ts:51, cli/tests/doctor.test.ts:62-74, cli/src/lib/doctor.ts:41-42]
  impact: The two new tests check only the `!knownReviewers.includes(r)` half of the condition, and in both the reviewer is left out of the manifest. `!m.reviewers.includes(r)` is what stops a declared pack for an unknown reviewer (`ghost.md`) from being flagged by both `checkDeclaredPacks` (line 41-42) and `checkStrayPacks`. If that half is deleted, `ghost` is reported twice as `unknown-reviewer`, and the test at line 51 still passes because `.some(...)` accepts one or more matches. Every other test uses a reviewer that is known or undeclared, so the full suite stays green. This PR restructured exactly this logic across two helpers, so the gap matters now. The doubled line would also reach users, because `commands/doctor.ts:12` prints each diagnosis.
  remedy: In the "reports unknown reviewer in pack" test, change the assertion to `expect(d).toEqual([{ kind: "unknown-reviewer", stack: "node", detail: "node: pack 'ghost.md' targets unknown reviewer" }])`. That checks there is exactly one diagnosis and fails if the guard is dropped.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.assertion
  file: cli/src/lib/doctor.ts
  line: 27
  title: The re-typed drift, orphan and missing-pack messages are never checked, and the older tests only look for a matching kind
  evidence: |
    if (cv === undefined) return [{ kind: "orphan", stack, detail: `'${stack}' installed but not in catalog` }];
    if (cv !== installed.version)
      return [{ kind: "drift", stack, detail: `${stack}: installed ${installed.version} -> catalog ${cv}` }];

    // cli/tests/doctor.test.ts:34
    expect(d.some((x) => x.kind === "drift" && x.stack === "node")).toBe(true);
  evidence_refs: [cli/tests/doctor.test.ts:34, cli/tests/doctor.test.ts:42, cli/tests/doctor.test.ts:59, cli/src/commands/doctor.ts:12]
  impact: The refactor rewrote each `detail` template inside the new helpers. The CLI prints `detail` straight to the user (`fail(\`[${f.kind}] ${f.detail}\`)`). The drift, orphan and missing-pack tests only check that some diagnosis has the expected `kind` and `stack`. So swapping the two versions (`installed ${cv} -> catalog ${installed.version}`) or adding an extra diagnosis would still pass. The new stray-pack test already uses an exact `toEqual`, which shows the stronger form is easy here.
  remedy: Change lines 34, 42 and 59 to exact `toEqual([...])` assertions. For example, drift should equal `[{ kind: "drift", stack: "node", detail: "node: installed 0.1.0 -> catalog 0.2.0" }]`. Do the same for orphan (`"'ghost' installed but not in catalog"`) and missing-pack (`"node: manifest declares 'security' but security.md missing"`).
  confidence: high
  overlap_hints: []

- severity: Low
  category: tests.coverage
  file: cli/vitest.config.ts
  line: 8
  title: Coverage has no `include`, so source files no test imports may be left out of the report
  evidence: |
    coverage: {
      reporter: ["text", "html", "lcov"],
    },
  evidence_refs: [cli/package-lock.json:3460]
  impact: The lockfile resolves vitest 4.1.11. In Vitest 4, `coverage.all` was removed, and without `coverage.include` the report only lists files loaded during the test run. The tests import only `commands/list.ts` and `lib/*`. `src/cli.ts` and seven command files (`add`, `doctor`, `init`, `interactive`, `remove`, `uninstall`, `update`) are never loaded, so they would be missing from the text/html report instead of showing 0%. The local percentage would look better than it is. SonarQube may still count those files as uncovered through `sonar.sources`, so the overstatement mainly affects local runs. I could not confirm the default behaviour at runtime because node_modules is not installed.
  remedy: Add `include: ["src/**/*.ts"]` to the `coverage` block so files no test loads show up as 0%.
  confidence: medium
  overlap_hints: []

The two new tests themselves are sound. Both use exact `toEqual` assertions, give each test its own temp directories created in `beforeEach` and removed in `afterEach`, and build fixtures through the real `installStack`. The `.md` filter in `listPackFiles` is covered indirectly: without it, `manifest.json` would become the unknown reviewer `manifest.j`, and the "reports no issues when up-to-date" test would fail.

## Files examined
examined: [cli/tests/doctor.test.ts, cli/src/lib/doctor.ts, cli/vitest.config.ts, cli/package.json]
not_examined: []
