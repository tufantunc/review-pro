# Contract run 2: pre-registration (written before any run)

Run 1 failed its second condition (2 of 4 false findings refuted). Both misses had a
literally true title and a false impact. The skill now says the defect is the harm a
finding asserts, not its title (commit `33e122e`). This run measures that change.

Two questions, kept apart because they have different standing:

1. **Does the change fix the misses?** Measured on V01 and V11, the items the change was
   written for. That is an in-sample result and is reported as one.
2. **Does the change kill true findings?** Measured on the 8 true findings from run 1 and
   on 8 true findings never shown to any verifier (`items/W01` to `W08`). The held-out
   half is the out-of-sample test.

There are no held-out false findings. None of the right shape could be recovered from
earlier review sessions, and writing them by hand, knowing the design, would bias them.

## Items

- V01 to V13: the run-1 prompts, unchanged except that the skill file they point at now
  carries the new paragraph.
- W01 to W08, all TRUE:
  - W01, W02, W03: pilot findings verified by hand in 2026-08 and not used in the spike
    (case 1 chained `~` coverage, case 2 missing `"bytes": null` fixture, case 3 partial
    rollout). W03's four sites were re-checked today: each waits for the CLI's ready text,
    and bare `aspire run` builds inside the CLI budget.
  - W04: the step-2 probe P1, true by construction.
  - W05: the fact-check finding on the first draft of #72, verbatim; the history confirms
    it (Dependabot bumps after a strip stayed at 0 until a re-resolve).
  - W06, W07, W08: three #71 pass-6 findings, verbatim; each was accepted and fixed.
- Excluded: the pilot's case-3 "doc comment inverts the precedent" finding. Re-read today,
  the comment says only that the new constant mirrors the practice of setting an explicit
  budget, so its label is contestable, and contestable labels are what broke run 1.

## Labels

- FALSE: V01, V06, V08, V11. MIXED: V04 (core true). TRUE: V02, V03, V05, V07, V09, V12,
  V13, W01 to W08. OUT-OF-REPO, not scored: V10.

## Pass, all three

1. No TRUE item, and not V04's core, treated as refuted (0 of 16).
2. At least 3 of the 4 FALSE items treated as refuted.
3. `defect_stands` consistent with `verdict` in at least 20 of 21 replies.

If condition 1 fails, the change is reverted and the result reported. If only condition 2
fails, the result is reported and no further wording change is tried on these items: a
third iteration on the same four false findings would be tuning to them.

## Predictions

- V11 refuted. V01 still partly refuted with the defect standing: its harm, a future
  rename silently breaking the tests, is a hypothetical the verifier cannot contradict,
  and rule 1 keeps it standing. So condition 2 passes at exactly 3 of 4.
- V06, V08 refuted, as before. V04 partly refuted with its core standing.
- Every TRUE item stands or is partly refuted with the defect standing. Likeliest kill:
  W08, whose rubric line opens with a qualifier ("acting with their own authority") a
  verifier could read as already covering setuid; then W04, where the README limits
  exposure to the VPC.
- 21 of 21 consistent.
