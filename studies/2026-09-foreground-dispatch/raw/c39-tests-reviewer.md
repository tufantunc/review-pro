<!-- c39 tests-reviewer; verbatim final answer -->
## Tests findings

- severity: Medium
  category: tests.coverage
  file: scripts/build-site.js
  line: 83
  title: No test covers the new whitespace handling in loadFlags, and the fixture puts the attributes where no real flag has them
  evidence: |
    // scripts/build-site.js:83-86 (changed)
    const a = attrs
      .replace(/role="img"\s*/g, '')
      .replace(/aria-label="[^"]*"\s*/g, '')
      .trimEnd();

    // scripts/build-site.test.js:89 (fixture: flagged attributes FIRST)
    writeFileSync(join(src, 'flags', `${l}.svg`), `<?xml version="1.0"?><svg role="img" aria-label="${l}" id="${l}"/>`);

    // scripts/build-site.test.js:115-120 (checks for substrings only)
    assert.ok(enIdx.includes('aria-hidden="true"'));
    assert.ok(!enIdx.includes('role="img"'));
    assert.ok(!enIdx.includes('aria-label="en"'));

    // every real flag, docs-src/flags/*.svg (flagged attributes LAST):
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 40" role="img" aria-label="English">
  impact: The diff's behaviour change is this: the regexes now consume whitespace after an attribute instead of before it, and `.trimEnd()` removes what is left when a stripped attribute ends the tag. That trailing-attribute case is the one the code comment says `trimEnd()` exists for, and all seven real flags in docs-src/flags hit it. The test fixture puts `role`/`aria-label` first, so it never reaches that path. The assertions only check `includes`/`!includes`, so they can't see a leftover or doubled space either way. I confirmed this with two mutations in a temp copy, and all 18 tests still passed with each one: (1) removing `.trimEnd()`, which turns the real output into `viewBox="0 0 60 40" >`; (2) removing both `\s*` quantifiers. So the reordering this PR makes is not checked by any assertion.
  remedy: Export `loadFlags`, or keep using `buildAll`. Add a fixture shaped like the real files, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 40" role="img" aria-label="English">`, and assert the exact output `<svg aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 40">` so that no trailing space remains. Add a second exact-output case with the flagged attributes in the middle (`<svg xmlns="..." role="img" aria-label="x" viewBox="...">` → single spaces between `xmlns` and `viewBox`) to cover the whitespace-after consumption.
  confidence: high
  overlap_hints: [correctness.logic]

I found nothing test-related in the other three files. `cli/src/lib/catalog.ts` only drops a default that could never apply. Every caller (update.ts:12, list.ts:11, doctor.ts:16) passes `catalogDir` explicitly, and so do both existing tests (cli/tests/catalog.test.ts:28, 34). `cli/src/commands/update.ts` and `cli/src/lib/agents.ts` only remove unused imports, which changes no behaviour, so no test is needed. `node --test scripts/build-site.test.js` passes 18/18 on the branch. I made no changes to the repo; the mutation runs used a temp copy that I deleted afterwards.

## Files examined
examined: [cli/src/commands/update.ts, cli/src/lib/agents.ts, cli/src/lib/catalog.ts, scripts/build-site.js]
not_examined: []
