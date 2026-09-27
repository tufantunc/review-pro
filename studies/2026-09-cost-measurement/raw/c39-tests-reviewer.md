<!-- c39 tests-reviewer; verbatim final answer -->
## Tests findings

- severity: Medium
  category: tests.coverage
  file: scripts/build-site.js
  line: 86
  title: The `trimEnd()` step this change adds is never tested, because the only fixture puts role/aria-label first
  evidence: |
    const a = attrs
      .replace(/role="img"\s*/g, '')
      .replace(/aria-label="[^"]*"\s*/g, '')
      .trimEnd();
    return `<svg aria-hidden="true" focusable="false"${a}>`;
    --- scripts/build-site.test.js (buildAll fixture + assertions)
    writeFileSync(join(src, 'flags', `${l}.svg`), `<?xml version="1.0"?><svg role="img" aria-label="${l}" id="${l}"/>`);
    ...
    assert.ok(enIdx.includes('aria-hidden="true"'));
    assert.ok(enIdx.includes('id="en"'));
    assert.ok(!enIdx.includes('role="img"'));
    assert.ok(!enIdx.includes('aria-label="en"'));
  evidence_refs: [scripts/build-site.test.js:90, scripts/build-site.test.js:111-116, docs-src/flags/en.svg:1]
  impact: The code comment says `trimEnd()` is there for one case: a flagged attribute at the end of the attribute list. That is how all seven real flags are written, e.g. `docs-src/flags/en.svg:1` is `<svg xmlns=... viewBox="0 0 60 40" role="img" aria-label="English">`. The test fixture does the opposite. It puts role/aria-label first and ends the attributes with `id="${l}"/`, so nothing trails them. Every assertion is a substring check (`includes`), and none checks the exact output. I deleted `.trimEnd()` locally and ran `node --test scripts/build-site.test.js`: all 18 tests still passed (I reverted the file afterwards). The PR's claim that the site output is byte-identical is therefore not checked by any test. A future edit that drops the trim, or brings back a quadratic `/\s+$/`, would leave `viewBox="0 0 60 40" >` in every built page, and the tests would still pass.
  remedy: Add a flag fixture shaped like the real files, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 40" role="img" aria-label="English">`, for at least one language. Assert the exact opening tag, e.g. `assert.ok(enIdx.includes('<svg aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 40">'))`. Keep the current role-first fixture, or add a middle-position case like `a="1" role="img" b="2"`, so both whitespace-consuming directions are pinned.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.coverage
  file: scripts/build-site.js
  line: 84
  title: No test guards the linear-time behaviour the regex reorder was made for
  evidence: |
    // Literal first, quantifier after. A leading `\s*` makes the engine retry at
    // every position on a run of whitespace, which is quadratic; with the literal
    // first, both of these are linear.
    ...
    // measured at 500ms on a 32k-space input where trimEnd is 0.0ms.
  impact: The whole point of the change is to avoid quadratic regex time, and the author measured it (500ms vs 0.0ms on 32k spaces). No test records that measurement. If someone goes back to `\s*role=` or `/\s+$/`, output stays the same, so nothing fails. SonarQube might flag it again, but the test suite won't.
  remedy: Add a buildAll case whose flag has a long whitespace run in the `<svg>` tag, e.g. `<svg${' '.repeat(50000)}role="img" aria-label="x"${' '.repeat(50000)}>`. Assert the output is correct, and use a generous time limit (say under 200ms, where the quadratic forms take seconds at that size) so the test doesn't flake. loadFlags is private, but buildAll with the existing tmp-dir fixture can already express this case.
  confidence: medium
  overlap_hints: [performance.complexity]

The other three files need no new tests. The `cli/src/commands/update.ts` and `cli/src/lib/agents.ts` changes only remove unused imports. The `readStackManifest` change in `cli/src/lib/catalog.ts` removes a default parameter value that could never be used, and the existing tests at `cli/tests/catalog.test.ts:28` and `:34` already pass `catalogDir` explicitly.

## Files examined
examined: [cli/src/commands/update.ts, cli/src/lib/agents.ts, cli/src/lib/catalog.ts, scripts/build-site.js]
not_examined: []
