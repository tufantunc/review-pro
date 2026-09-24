# 0009: Verify each blocking-level finding by trying to refute it

Status: accepted
Date: 2026-09-24

## Context

Synthesis merged findings but never re-checked one, and it treated agreement as
strength. The #51 libc claim and the pilot's case-3 `dotnet run` finding were both
several readers agreeing on something none of them traced to its source; the second was
filed upstream as microsoft/aspire#19540 before anyone noticed. A pre-registered spike
([studies/2026-09-refuting-verifier](../../../studies/2026-09-refuting-verifier)) gave
13 labelled findings to fresh agents told to refute each one from source: 6 of 8 runs on
known-false findings refuted them, none added new findings, and the only true-labelled
finding they refuted turned out to be labelled wrong.

## Decision

One fresh agent per Medium+ code finding, after dedup and conflict resolution and before
the verdict, tries to refute it and must cite the line that contradicts it. A refuted
Medium leaves the verdict and stays visible; a refuted High or Critical keeps blocking
and is marked disputed. A partly refuted finding keeps its severity, with what fell shown
under it.

Rejected: verifying each reviewer's findings as they arrive, which verifies duplicates and
makes a cap meaningless.

Rejected: one verifier for all findings in one context, which was never measured and lets
one judgement bleed into the next.

Rejected: letting a refutation remove a High or Critical. The evidence is small, one model
family plays every role, and the labels were wrong in 2 of 13; a wrong refutation there
ships a blocker.

Rejected, for now: letting synthesis re-rate a partly refuted finding from the part that
stands. It would close the gap below, but the only examples of that gap are the two
findings the wording was already tuned on, so it could not be measured out of sample.

## This merges against a failed acceptance condition, on purpose

The acceptance runs were pre-registered with three conditions. Two held in both runs:
no true finding was refuted (0 of 8, then 0 of 16, 8 of them never seen before), and every
`defect_stands` matched its verdict (13 of 13, then 21 of 21). The third, that at least 3
of 4 known-false findings come out refuted, failed twice at 2 of 4. Between the runs the
skill was changed to define the defect as the harm a finding asserts rather than its title,
and the rule then forbade a third wording change on the same four findings.

The maintainer chose to merge anyway. The two misses (V01, V11) are not verifier errors:
the verifier refuted the harm each finding claimed and left standing a real residue that
is at most Low (a hypothetical rename risk; a genuine hang failing at 240s instead of
120s). The design keeps severity off the verifier's table, so that residue keeps the
finding at Medium.

## Consequences

A wholly false Medium no longer costs the author a REQUEST CHANGES, and a false blocker is
flagged for a human instead of silently holding a merge. A mostly false finding whose
harm shrinks to a small true residue still requests changes at its original severity; the
report shows what fell, but the verdict does not move. That is the known limit this merges
with.

Up to 8 extra agents per review, about 70k tokens each. Spec findings are not verified.
Where no independent subagent exists, nothing is verified and the report says so. A wrong
refutation can still take a real Medium out of the verdict; the asymmetry bounds that to
non-blocking findings and does not remove it.

Revisiting the limit needs held-out false findings of the "true title, false harm" shape,
which earlier sessions did not yield. Revisiting the High/Critical rule needs a larger
corpus, with labels checked by someone other than the maintainer, showing refutations of
blockers are reliably right.
