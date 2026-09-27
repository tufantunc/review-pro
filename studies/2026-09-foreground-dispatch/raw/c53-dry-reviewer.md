<!-- c53 dry-reviewer; verbatim final answer -->
- severity: Low
  category: dry.duplication
  file: cli/src/lib/doctor.ts
  line: 32
  title: The new listPackFiles helper repeats listAgentNames in cli/src/lib/plugin.ts:187
  evidence: |
    function listPackFiles(dir: string): Set<string> {
      if (!fs.existsSync(dir)) return new Set();
      return new Set(fs.readdirSync(dir).filter((f) => f.endsWith(".md")));
    }
    // ...and its caller strips the extension again, doctor.ts:51
    const r = f.slice(0, -3);
  evidence_refs: [cli/src/lib/plugin.ts:187, cli/src/lib/plugin.ts:96]
  impact: The repo now has a third private helper that lists the `.md` files in a directory. `listAgentNames` (plugin.ts:187-192) does the same thing: an `existsSync` guard, then `readdirSync(src).filter((f) => f.endsWith(".md")).map((f) => f.slice(0, -3))`. `listSharedNames` (plugin.ts:96-103) is a variant that sorts its results. `doctor.ts` also re-implements the `slice(0, -3)` step at line 51. These copies can drift apart, for example if one of them adds the `isFile()` filter that `listSharedNames` already has (a directory named `x.md` would count as a pack here but not there). The pattern was already inline in the base `diagnose()`. This change only promotes it to a named helper, which is why the severity is Low.
  remedy: Move `listAgentNames` into one exported helper, for example `listMdNames(dir): string[]` next to `reviewProDir` in cli/src/lib/repo.ts or in a small fs util. Use it from both plugin.ts and doctor.ts. In doctor.ts, build `new Set(listMdNames(dir))` of reviewer names. Then `checkDeclaredPacks` can test `packs.has(r)` and `checkStrayPacks` no longer needs `slice(0, -3)`. Don't add a fourth variant.
  confidence: medium
  overlap_hints: [craft.abstraction]

- severity: Low
  category: dry.copy-paste
  file: cli/src/lib/doctor.ts
  line: 55
  title: checkDeclaredPacks and checkStrayPacks each build the unknown-reviewer diagnosis separately
  evidence: |
    // doctor.ts:42-43 (checkDeclaredPacks)
    else if (!knownReviewers.includes(r))
      out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${r}.md' targets unknown reviewer` });
    // doctor.ts:54-55 (checkStrayPacks)
    if (!m.reviewers.includes(r) && !knownReviewers.includes(r))
      out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${f}' targets unknown reviewer` });
  impact: The `knownReviewers.includes` check, the diagnosis object and the message template are written twice, one in each new helper. The new test at cli/tests/doctor.test.ts:71-73 matches the exact `detail` string, so changing the wording in only one copy would make that path's output inconsistent without the other path's tests noticing. Taken together, the two helpers check "every pack file present whose reviewer is unknown", which is one loop over `packs`. Splitting that into two functions leaves the duplication in place instead of removing it. It was inline in the base too, so this is Low.
  remedy: Check unknown reviewers once in a single loop over `packs` (for each file present, if `!knownReviewers.includes(r)`, push the diagnosis). Keep `checkDeclaredPacks` for `missing-pack` only. The declared-and-present case and the stray case then share one condition and one message. If you keep both helpers, pull the push into a single `unknownReviewer(stack, file)` constructor.
  confidence: medium
  overlap_hints: [craft.code-judo]

Other candidates I checked and did not report:
- `readCatalogVersions` has no existing equivalent. `list.ts:12` and `update.ts:12` call `readStackManifest(...)?.version` per stack inline.
- `checkDrift` does not duplicate `versionMark` in manifest.ts:21. That function compares versions lexically to produce a display hint, which is a different job.
- The two new tests reuse the file's existing inline setup pattern.
- `listInstalled` and `listCatalogStacks` look alike, but that predates this change and is outside the diff.

## Files examined
examined: [cli/src/lib/doctor.ts, cli/tests/doctor.test.ts]
not_examined: []
