<!-- c53 craft-reviewer; verbatim final answer -->
## Craft findings

- severity: Medium
  category: craft.code-judo
  file: cli/src/lib/doctor.ts
  line: 48
  title: The two pack checks run one unknown-reviewer rule twice, joined by a hidden dedup guard. Merging them removes a helper.
  evidence: |
    function checkDeclaredPacks(stack: string, packs: Set<string>, m: StackManifest, knownReviewers: string[]): Diagnosis[] {
      const out: Diagnosis[] = [];
      for (const r of m.reviewers) {
        if (!packs.has(`${r}.md`))
          out.push({ kind: "missing-pack", stack, detail: `${stack}: manifest declares '${r}' but ${r}.md missing` });
        else if (!knownReviewers.includes(r))
          out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${r}.md' targets unknown reviewer` });
      }
      ...
    function checkStrayPacks(stack: string, packs: Set<string>, m: StackManifest, knownReviewers: string[]): Diagnosis[] {
      ...
        // A pack for a known reviewer the manifest does not declare is allowed to
        // sit in the stack dir; only packs targeting unknown reviewers are flagged.
        if (!m.reviewers.includes(r) && !knownReviewers.includes(r))
          out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${f}' targets unknown reviewer` });
  impact: Whether a reviewer is declared doesn't change the unknown-reviewer rule. Every `.md` pack on disk whose reviewer is not in `knownReviewers` gets flagged, with the same `detail` string, because `pack '${r}.md'` and `pack '${f}'` come out identical. The only job of `!m.reviewers.includes(r)` in `checkStrayPacks` is to avoid reporting a finding twice when `checkDeclaredPacks` has already reported it. So the two helpers depend on each other without saying so. Someone who edits either one alone, for example by dropping the `else` in `checkDeclaredPacks`, gets duplicate or missing findings. The comment on that line describes the known-reviewer half of the condition and leaves the dedup half unexplained. The refactor made the tangle easier to see but kept it, and it now spans two functions that each take four parameters.
  remedy: |
    Model the check as two independent rules, one over the manifest and one over the directory, and replace both helpers with a single `checkPacks`:
      function checkPacks(stack: string, packs: Set<string>, m: StackManifest, knownReviewers: string[]): Diagnosis[] {
        const missing = m.reviewers.filter((r) => !packs.has(`${r}.md`))
          .map((r): Diagnosis => ({ kind: "missing-pack", stack, detail: `${stack}: manifest declares '${r}' but ${r}.md missing` }));
        const unknown = [...packs].filter((f) => !knownReviewers.includes(f.slice(0, -3)))
          .map((f): Diagnosis => ({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${f}' targets unknown reviewer` }));
        return [...missing, ...unknown];
      }
    This removes the `else if`, the cross-helper guard and its comment, and one of the two duplicated `unknown-reviewer` literals. The findings stay the same. Only their order changes for a declared pack with an unknown reviewer: it moves from manifest order to directory order. `cli/src/commands/doctor.ts` just prints each finding. Every existing test in `cli/tests/doctor.test.ts` uses `some()` or expects zero or one element, so none depends on the order.
  confidence: high
  overlap_hints: [dry.duplication]

## Files examined
examined: [cli/src/lib/doctor.ts, cli/tests/doctor.test.ts, cli/vitest.config.ts, cli/package.json]
not_examined: []
