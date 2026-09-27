<!-- c53 dry-reviewer; verbatim final answer -->
- severity: Low
  category: dry.duplication
  file: cli/src/lib/doctor.ts
  line: 32
  title: listPackFiles is a third copy of the "list the .md files in a dir" helper already in plugin.ts
  evidence: |
    function listPackFiles(dir: string): Set<string> {
      if (!fs.existsSync(dir)) return new Set();
      return new Set(fs.readdirSync(dir).filter((f) => f.endsWith(".md")));
    }
    ...
    for (const f of packs) {
      const r = f.slice(0, -3);
  evidence_refs: [cli/src/lib/plugin.ts:188, cli/src/lib/plugin.ts:97]
  impact: |
    `listAgentNames` in plugin.ts:188-192 already does this: it checks that the dir exists, calls `fs.readdirSync(src).filter((f) => f.endsWith(".md")).map((f) => f.slice(0, -3))`, and returns `[]` when the dir is missing. doctor.ts rebuilds that and then strips the extension again inline at doctor.ts:51. `listSharedNames` at plugin.ts:97-103 is a third variant of the same listing. Each copy decides "what counts as a pack/agent file" on its own, and they already disagree: plugin.ts:100 keeps only regular files (`d.isFile()`), while doctor.ts and plugin.ts:188 would also match a directory whose name ends in `.md`. A fix made in one copy will not reach the others.
  remedy: |
    Move the plugin.ts:188 helper (existence guard, `.md` filter, extension strip) into a small shared fs helper in cli/src/lib and export it. Make listPackFiles `new Set(listMdNames(dir))` holding bare reviewer names. checkDeclaredPacks then uses `packs.has(r)`, and checkStrayPacks loops over names directly and puts `${r}.md` in its message, so the `slice(0, -3)` at doctor.ts:51 goes away. Have plugin.ts:188 and plugin.ts:97 call the same helper, so the `isFile()` rule lives in one place.
  confidence: medium
  overlap_hints: [craft.abstraction]

- severity: Nitpick
  category: dry.copy-paste
  file: cli/src/lib/doctor.ts
  line: 55
  title: The unknown-reviewer diagnosis is written out twice with the same wording
  evidence: |
    // doctor.ts:43 (checkDeclaredPacks)
    out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${r}.md' targets unknown reviewer` });
    // doctor.ts:55 (checkStrayPacks)
    out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${f}' targets unknown reviewer` });
  impact: The two lines produce the same diagnosis for the same file through two separate string templates. The new test at cli/tests/doctor.test.ts:71-73 pins the exact text, so if only one template is edited later, the two paths will report differently and only one of them fails the test.
  remedy: Now that the checks are split into separate functions, add one private factory, e.g. `const unknownReviewer = (stack: string, r: string): Diagnosis => ({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${r}.md' targets unknown reviewer` })`, and call it from doctor.ts:43 and doctor.ts:55.
  confidence: high
  overlap_hints: [craft.code-judo]

Notes (no findings filed):
- `readCatalogVersions` (doctor.ts) is code moved from the old `diagnose`, not new duplication. The same catalog-version loop exists in cli/src/commands/list.ts:11-12, but that was already there before this branch.
- The two new tests in cli/tests/doctor.test.ts reuse the file's existing `beforeEach` fixture and `installStack`. They add no fixture duplication. The fixture setup repeated across doctor.test.ts:9-17, list.test.ts:10-11 and repo.test.ts:11-12 predates this diff.

## Files examined
examined: [cli/src/lib/doctor.ts, cli/tests/doctor.test.ts]
not_examined: []
