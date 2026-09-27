<!-- c53 craft-reviewer; verbatim final answer -->
I found one craft issue: a Medium missed simplification in `doctor.ts`. `vitest.config.ts` and `package.json` are clean. The prompt carried no `### Repository rules` section, so there is no rules block.

- severity: Medium
  category: craft.code-judo
  file: cli/src/lib/doctor.ts
  line: 48
  title: The two pack checks share one concern, so the stray check has to consult the manifest to avoid reporting a pack twice
  evidence: |
    function checkDeclaredPacks(stack: string, packs: Set<string>, m: StackManifest, knownReviewers: string[]): Diagnosis[] {
      ...
        if (!packs.has(`${r}.md`))
          out.push({ kind: "missing-pack", ... });
        else if (!knownReviewers.includes(r))
          out.push({ kind: "unknown-reviewer", stack, detail: `${stack}: pack '${r}.md' targets unknown reviewer` });
    ...
    function checkStrayPacks(stack: string, packs: Set<string>, m: StackManifest, knownReviewers: string[]): Diagnosis[] {
      for (const f of packs) {
        const r = f.slice(0, -3);
        // A pack for a known reviewer the manifest does not declare is allowed to
        // sit in the stack dir; only packs targeting unknown reviewers are flagged.
        if (!m.reviewers.includes(r) && !knownReviewers.includes(r))
  impact: The PR splits the old loops into functions, but the logic tangle is still there. The rule "a pack file for an unknown reviewer" is split by whether the manifest declares that reviewer. Half of it lives in the `else if` of `checkDeclaredPacks`. The other half lives in `checkStrayPacks`, which then has to check `!m.reviewers.includes(r)` to avoid flagging a pack twice, and needs a comment to explain that. Both functions take the full `(stack, packs, m, knownReviewers)` argument list even though each really needs only two inputs. Pack names also go back and forth between two forms: `${r}.md` for lookups and `f.slice(0, -3)` to get the name back.
  remedy: |
    Split the checks by what they are about. Missing packs depend only on (manifest reviewers, packs). Unknown reviewers depend only on (packs, known reviewers):
      const packs = listPackReviewers(dir);   // Set of names without ".md", like listAgentNames in plugin.ts:187
      for (const r of m.reviewers) if (!packs.has(r)) -> missing-pack
      for (const r of packs) if (!knownReviewers.includes(r)) -> unknown-reviewer `pack '${r}.md'`
    This produces the same set of diagnoses. Each unknown pack is still flagged exactly once, and the detail strings are byte-identical. It removes the `else if`, the `!m.reviewers.includes(r)` guard, the explanatory comment, the `.slice(0, -3)` and the `${r}.md` lookup. It also means `checkStrayPacks` no longer needs the `m` argument. The only change is output order: unknown-reviewer entries for declared packs come after the missing-pack entries instead of mixed in with them. The only consumers are `src/commands/doctor.ts:10`, which just prints the list, and tests. None of the tests checks the order of a list with more than one entry (`tests/doctor.test.ts:65,71` both expect zero or one item).
  confidence: high
  overlap_hints: [dry.duplication]
  evidence_refs: [cli/src/lib/plugin.ts:187, cli/src/commands/doctor.ts:10, cli/tests/doctor.test.ts:71]

## Files examined
examined: [cli/src/lib/doctor.ts, cli/vitest.config.ts, cli/package.json]
not_examined: []
