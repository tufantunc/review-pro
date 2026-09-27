<!-- c53 tests-reviewer; verbatim final answer -->
- severity: Medium
  category: tests.coverage
  file: cli/src/lib/doctor.ts
  line: 54
  title: No test pins the stray-pack guard that stops a declared unknown-reviewer pack being reported twice
  evidence: |
    // cli/src/lib/doctor.ts:54-55 (checkStrayPacks)
    if (!m.reviewers.includes(r) && !knownReviewers.includes(r))
      out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${f}' targets unknown reviewer` });

    // cli/tests/doctor.test.ts:46-51 (only test with a declared unknown reviewer)
    JSON.stringify({ name: "node", version: "0.1.0", reviewers: ["security", "ghost"] }));
    fs.writeFileSync(path.join(repo, ".review-pro", "node", "ghost.md"), "# pack");
    const d = diagnose(repo, catalog, ["security"]);
    expect(d.some((x) => x.kind === "unknown-reviewer" && x.stack === "node")).toBe(true);
  evidence_refs: [cli/tests/doctor.test.ts:51]
  impact: The refactor splits one loop into `checkDeclaredPacks` and `checkStrayPacks`. The `!m.reviewers.includes(r)` clause is the only thing that stops a pack flagged by the declared check from being flagged again by the stray check. If that clause is deleted, `ghost.md` is reported twice, and every test still passes. The "up-to-date" test and the new "passes silently" test only contain known reviewers. The new "flags stray" test only has an undeclared reviewer. The one test with a declared unknown reviewer uses `.some(...)`, so it cannot tell one report from two. The PR says behaviour is unchanged, and nothing checks this path.
  remedy: Make the "reports unknown reviewer in pack" test use exact equality. Write `security.md` too, so the fixture has only the problem under test, then assert `toEqual([{ kind: "unknown-reviewer", stack: "node", detail: "node: pack 'ghost.md' targets unknown reviewer" }])`. That pins exactly one report.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.assertion
  file: cli/tests/doctor.test.ts
  line: 34
  title: The rewritten drift, orphan and missing-pack paths are only checked for kind and stack, not for the detail text users see
  evidence: |
    // cli/tests/doctor.test.ts
    34: expect(d.some((x) => x.kind === "drift" && x.stack === "node")).toBe(true);
    42: expect(d.some((x) => x.kind === "orphan" && x.stack === "ghost")).toBe(true);
    59: expect(d.some((x) => x.kind === "missing-pack" && x.stack === "node")).toBe(true);

    // cli/src/lib/doctor.ts:24-26 (moved and rewritten in this diff)
    if (cv === undefined) return [{ kind: "orphan", stack, detail: `'${stack}' installed but not in catalog` }];
    if (cv !== installed.version)
      return [{ kind: "drift", stack, detail: `${stack}: installed ${installed.version} -> catalog ${cv}` }];
  evidence_refs: [cli/src/lib/doctor.ts:24, cli/src/lib/doctor.ts:41, cli/src/commands/doctor.ts:12]
  impact: The PR moves every detail template into new helpers and renames the variable from `m` to `installed`. `detail` is what users see, because `cli/src/commands/doctor.ts:12` prints `fail(\`[${f.kind}] ${f.detail}\`)`. These assertions only check that some entry of the right kind exists, so they miss several regressions, for example: a wrong interpolation such as `installed ${cv} -> catalog ${cv}`, a changed message, extra diagnoses, or changed order. The only exact assertions in the diff are in the two new stray-pack tests. So the "behaviour is identical" claim is checked only for the stray path.
  remedy: Switch the four older tests to `toEqual([...])` with the full expected diagnoses. The two new tests already do this. For drift, expect `{ kind: "drift", stack: "node", detail: "node: installed 0.1.0 -> catalog 0.2.0" }`. For orphan, expect `"'ghost' installed but not in catalog"`. For missing-pack, expect `"node: manifest declares 'security' but security.md missing"`.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.coverage
  file: cli/vitest.config.ts
  line: 8
  title: The coverage config has no `include`, so files the tests never import are missing from lcov.info and the SonarQube figure is too high
  evidence: |
    coverage: {
      reporter: ["text", "html", "lcov"],
    },
  impact: The lockfile resolves vitest 4.1.11. As I understand Vitest 4, `coverage.all` is gone and the report only lists files loaded during the test run unless `coverage.include` is set. I took that from the Vitest 4 migration notes; `node_modules` is not installed here, so I could not check it locally. A grep of `cli/tests/*.ts` shows `src/cli.ts` is never imported, and `tests/list.test.ts` is the only test that references `commands/`. So `cli.ts`, and likely most of `src/commands/*` (including `commands/doctor.ts`, the caller of `diagnose`), would be left out of `cli/coverage/lcov.info`. SonarQube would then report coverage over tested files only, not over the CLI.
  remedy: Add `include: ["src/**/*.ts"]` to `test.coverage` so files with no tests show up as 0% instead of being left out.
  confidence: medium
  overlap_hints: [correctness.logic, spec.requirement]

## Repository rules
- rule: R3
  outcome: held
  because: The diff changes cli/package.json scripts, devDependencies and a description encoding, but not the `version` field (still 1.2.0), and R3 says dependency or description changes need no mirroring.
  evidence: cli/package.json:4 `"version": "1.2.0",` (unchanged)

## Files examined
examined: [cli/tests/doctor.test.ts, cli/src/lib/doctor.ts, cli/vitest.config.ts, cli/package.json]
not_examined: []
