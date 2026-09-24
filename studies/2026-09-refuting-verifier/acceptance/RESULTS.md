# Contract run: results (2026-09-24)

13 runs, one per item, general-purpose agents given `core/skills/review-pro-verify/SKILL.md`
at commit `2f1993e` and a prompt built from its Inputs section. Each agent read its prompt
from a file rather than receiving it inline (see the ledger ruling in the PR). Replies are
in `raw/`, verbatim.

| Item | Label | verdict | defect_stands | treated as | consistent | scored |
|---|---|---|---|---|---|---|
| V01 | FALSE | partly_refuted | yes | partly refuted | y | MISS |
| V06 | FALSE | refuted | no | refuted | y | HIT |
| V08 | FALSE | refuted | no | refuted | y | HIT |
| V11 | FALSE | partly_refuted | yes | partly refuted | y | MISS |
| V04 | MIXED | partly_refuted | yes | partly refuted (RoutingHandler claim falls, coverage stands) | y | HIT |
| V02 | TRUE | partly_refuted | yes | partly refuted (macOS attribution and the re-resolve aside fall) | y | OK |
| V03 | TRUE | partly_refuted | yes | partly refuted (remedy option 1 and the throw line fall) | y | OK |
| V05 | TRUE | stands | yes | stands | y | OK |
| V07 | TRUE | stands | yes | stands | y | OK |
| V09 | TRUE | partly_refuted | yes | partly refuted (the worked `-c` example falls) | y | OK |
| V12 | TRUE | stands | yes | stands | y | OK |
| V13 | TRUE | stands | yes | stands | y | OK |
| V10 | OUT | stands | yes | stands, service contract under `unchecked` | y | not scored |

## Pass conditions

1. No true finding, and not V04's core, treated as refuted: **met** (0 of 8).
2. At least 3 of 4 false findings treated as refuted: **not met** (2 of 4: V06, V08).
3. `defect_stands` consistent with `verdict` in at least 12 of 13: **met** (13 of 13).

**The contract run fails.** By the rule written before it, the skill as shipped does not
pass acceptance.

## What failed, and why

Both misses have the same shape. The finding's title is literally true and what made it a
finding is false, and the verifier reads the title as "the defect":

- V01: a second copy of the string does exist; the remedy is unreachable and the rename
  risk rests on a convention the file already follows. Same outcome as both spike runs.
- V11: the ready timeout really is applied where its budget is not set; the invariant and
  diagnostic claims fall, and the flake claim was left `unchecked`. In the spike the same
  finding was refuted once and partly refuted with nothing but a doc nit left once.

Under the design, a partly refuted finding keeps its severity, so in a real review both
would keep driving REQUEST CHANGES while their impact is shown as refuted beneath them.

## Predictions that failed

- V11 predicted refuted; it came back partly refuted with the defect standing.
- Otherwise as predicted: V06 and V08 refuted, V01 a miss, V04 a hit, every true item
  standing or partly refuted with the defect standing, 13 of 13 consistent.

## What went right, beyond the rule

Four true findings came back partly refuted, and each falling part checks out as a real
inaccuracy in the finding: V02's macOS attribution (npm 11.9.0 has no `libc` in
`pkgMetaKeys`, and no platform check), V03's cited throw line (the throw is at :616) and
remedy option 1 (it misses the final generation), V09's worked example (`-c...` starts with
`-`, which the entry's own option-injection residual still flags). None removed a defect.
