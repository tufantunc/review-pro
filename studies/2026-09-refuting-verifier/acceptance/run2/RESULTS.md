# Contract run 2: results (2026-09-24)

21 runs, the skill at commit `33e122e` (the defect is the harm, not the title). Replies
are in `raw/`, verbatim.

| Item | Label | verdict | defect_stands | run 1 | scored |
|---|---|---|---|---|---|
| V01 | FALSE | partly_refuted | yes | partly_refuted, yes | MISS |
| V06 | FALSE | refuted | no | refuted, no | HIT |
| V08 | FALSE | refuted | no | refuted, no | HIT |
| V11 | FALSE | partly_refuted | yes | partly_refuted, yes | MISS |
| V04 | MIXED | partly_refuted | yes | same | HIT (core stands) |
| V02 | TRUE | stands | yes | partly_refuted, yes | OK |
| V03 | TRUE | stands | yes | partly_refuted, yes | OK |
| V05, V07, V12, V13 | TRUE | stands | yes | same | OK |
| V09 | TRUE | partly_refuted | yes | same (the `-c` example falls) | OK |
| W01, W02, W04, W06, W07, W08 | TRUE, held out | stands | yes | not run | OK |
| W03 | TRUE, held out | partly_refuted | yes | not run | OK (the npm-install aside falls) |
| W05 | TRUE, held out | partly_refuted | yes | not run | OK (the "at new versions" mechanism falls) |
| V10 | OUT | stands | yes | same | not scored |

## Pass conditions

1. No true finding treated as refuted: **met** (0 of 16, 0 of the 8 held out).
2. At least 3 of 4 false findings refuted: **not met** (2 of 4, unchanged from run 1).
3. `defect_stands` consistent with `verdict`: **met** (21 of 21).

**Run 2 fails condition 2.** By the rule written before it, the result is reported and no
further wording change is tried on these four false findings.

## What the definition change did and did not do

It did not move V01 or V11. Both verifiers now reason in terms of harm, and V11's reply
refutes every harm the finding names as its impact: the invariant, the missing
diagnostic, and the unmitigated flake. It keeps a residue as the standing defect, that a
genuine hang now fails at 240s instead of about 120s. V01 keeps the rename risk, a
hypothetical nothing in the tree can contradict, which rule 1 keeps standing.

In both cases the residue is real and small. What the finding said was a Medium harm
falls, and what is left is at most a Low. The verifier is told severity is not its
question (rule 4), and synthesis keeps a partly refuted finding's severity, so the
residue keeps the finding at Medium.

That locates the gap outside the verifier's wording. The verifier's reports on V01 and
V11 are accurate; the design has no step that re-rates a finding whose standing part is
much smaller than what it claimed.

## Side effects of the change

- V02 and V03 moved from partly refuted to stands: with the defect read as the harm, the
  verifiers no longer spent a `falls` on a wrong line number or an attribution detail.
  Their run-1 corrections were real, so this is information the report no longer shows.
- The held-out true findings produced two partial refutations, both checked here and
  both correct: W03's npm install runs as an AppHost resource after the CLI's startup
  window, and W05's mechanism is wrong in detail, since the lightningcss entries regained
  `libc` in 12e0023 at an unchanged version. Neither removed a defect.

## Predictions that failed

- V11 was predicted to flip to refuted; it did not.
- The likeliest kills were predicted to be W08 and W04; both stood.
