# Study: dispatch every agent in one step and wait for all of them

The one candidate roadmap item 4's measurement left for a spike
([`studies/2026-09-cost-measurement/`](../2026-09-cost-measurement), phase A), run on
2026-09-28. [`PRE-REGISTRATION.md`](PRE-REGISTRATION.md) was committed before the skill change
and before any run.

## Headline

The change did what it targets, on both diffs:
- **Waiting turns went to zero**, down from 5 and 6.
- **The orchestrator thread cost half to 61% less.**
- **Every call ran in the foreground, and concurrently.**
- **No stage was lost.**

Wall time rose 32% and 47%. Both land in the pre-registered "between" band (25 to 50%), so the
decision rule says to stop and report. The wall-time decomposition puts the whole increase in the
slowest reviewer's own run time, which the change does not touch. The orchestrator's own time was
flat. Two runs cannot prove that, and the maintainer decides.

## Contents

| File | What it is |
|---|---|
| [`PRE-REGISTRATION.md`](PRE-REGISTRATION.md) | The change, the measures, the decision rule, the budget |
| [`cases.py`](cases.py) | Phase A's case builder. It installs `bccb367` with only the two dispatch lines replaced by this branch's, and asserts both sides |
| [`run.sh`](run.sh), [`prompts.py`](prompts.py), [`tally.py`](tally.py), [`analyze.py`](analyze.py) | Phase A's, unchanged |
| [`compare.py`](compare.py) | Waiting turns, totals, wall time, concurrency, background flags and E1 to E4 against the phase A tallies |
| `results/` | Both runs' tallies and reports, `compare.txt`, `analysis.txt` |
| `raw/` | Each reviewer's final answer, verbatim |

## The change

Both dispatch lines of `core/skills/review-pro/SKILL.md` (steps 3.2 and 4.2) now carry one
canonical clause, and step 3.2 no longer says "background". The clause:

> all in one step: in parallel if your platform allows, else sequentially. Wait until every one
> has returned before you go on, and do not run them as background tasks that each report back on
> their own: every separate return starts a new turn that re-reads your whole context.

It names no platform parameter, and the sequential fallback stays. `scripts/validate-dispatch.sh`,
sourced by `validate.sh` like the other checks that live in their own files, pins the clause on each
line and fails on "background" outside it. Five mutation tests cover it: each line losing the clause,
a background request added, and each line removed. A sixth fails the run when the file is missing.
It lives in its own file because adding it to `validate.sh` would have taken that file past 1000 lines.

## Results, side by side with phase A

| | c39 phase A | c39 now | c53 phase A | c53 now |
|---|---|---|---|---|
| **Waiting turns (primary)** | 5 turns, 378K (16%) | **0** | 6 turns, 460K (20%) | **0** |
| Orchestrator turns (result events) | 8 | 1 | 9 | 1 |
| Orchestrator thread | 1,421K (23 messages) | 556K (12) | 1,270K (20) | 640K (12) |
| Reviewers | 820K (7) | 1,257K (7) | 935K (6) | 1,448K (7) |
| ai-antipatterns reviewer alone | 110K | 459K | 180K | 703K |
| Verifiers | 176K (2) | 107K (1) | 110K (2) | 206K (3) |
| Haiku (web tool summaries) | 0 | 32K | 0 | 0 |
| **Total tokens (secondary)** | 2.42M | 1.95M (−19%) | 2.32M | 2.29M (−1%) |
| **Wall time** | 247 s | 327 s (+32%) | 234 s | 345 s (+47%) |

**Reading the totals.** The orchestrator thread fell by 865K and 630K. That is more than the
waiting turns alone, because the thread also ran fewer messages. The reviewers rose by 437K and
513K, most of it one reviewer:
- ai-antipatterns owned the external premises about SonarQube rules. It made 15 and 18 tool calls
  this time against 3 and 6 in phase A: rule pages over WebFetch and a regex benchmark.
- In c39 its first fetch failed on DNS (`ENOTFOUND`), and it searched further.
- Phase A's report says of the same premise that "the reviewer never opened the rule's
  documentation".

The reviewer prompts and bodies are the same in both phases; that depth is reviewer variance, not
the dispatch. Each run also dispatched a slightly different set (below). One run per case cannot
separate these, which is why the waiting-turn count is the primary measure.

## Did the calls run in parallel?

Yes. The evidence comes from each subagent transcript's first and last timestamps, and from the
stream's `task_started` events:

| Run | Started in background | Reviewers: peak overlap, union vs longest vs sum | Verifiers |
|---|---|---|---|
| c39 now | 0 of 9 calls | 7 at once; 155 s vs 127 s vs 420 s: **parallel** | 1 verifier: single |
| c53 now | 0 of 13 calls | 7 at once; 177 s vs 163 s vs 393 s: **parallel** | 3 at once; 48 s vs 27 s vs 72 s: "mixed" |

- **Sequential would look different.** It would put the union near the sum: 420 s and 393 s
  instead of 155 s and 177 s.
- **The verifiers' "mixed" verdict comes from staggered starts, not from queueing.**
  - By the pre-registered 1.5× criterion, their union of 48 s is too long against the longest
    verifier's 27 s.
  - All three were running at once. They started 0, 11 and 21 s apart, because the orchestrator
    writes each verifier's prompt, the full diff included, one after another in the same message,
    and each call starts once its block is written.
  - Their union (48 s) is well under their sum (72 s).
- **Reviewer starts are staggered the same way**, 0 to 43 s on c53.

## Where the wall time went

Each run splits into reviewers' union + verifiers' union + everything else (the orchestrator's own
time):

| Run | Wall | Reviewers | Verifiers | Orchestrator only | Slowest reviewer |
|---|---|---|---|---|---|
| c39 phase A | 247 s | 81 s | 40 s | 126 s | 60 s |
| c39 now | 327 s | 155 s | 36 s | 136 s | 127 s (ai-antipatterns) |
| c53 phase A | 234 s | 83 s | 27 s | 124 s | 77 s |
| c53 now | 345 s | 177 s | 48 s | 120 s | 163 s (ai-antipatterns) |

- **The orchestrator's own time held steady:** 126 s and 124 s before, 136 s and 120 s now.
- **The increase is almost all in the reviewers' union,** +74 s and +94 s, and that union is set by
  the slowest reviewer.
- **Why the change should not add wall time.** In phase A the orchestrator also waited for the
  last reviewer before merging. Its waiting turns ran while other reviewers were still working, so
  they were off the critical path. With foreground dispatch that wait happens in one blocking step
  instead of several turns.

This is post-hoc reasoning on two runs, and the pre-registered rule is about the measured wall
time.

## Equivalence

- **E1, reviewer set.** It differs from phase A in both runs:
  - c39 ran `a11y` in place of `api-contract`; the diff touches SVG `role` and `aria-label`
    handling.
  - c53 added `performance`.

  The runs did not write their dispatch plan out; triage happened in the orchestrator's thinking.
  So "every reviewer the plan names was dispatched" cannot be checked against a written plan.
  What can be checked holds: nothing in either report or transcript names a reviewer that did not
  run. The differences follow the signal map, and this change does not touch triage.
- **E2.** Every code reviewer returned its `## Files examined` block.
- **E3.** Verification ran on every selected finding: 1 of 1 and 3 of 3, matching each report's
  Verification line.
- **E4.** Both reports carry the verdict, the Spec, Coverage and Verification lines, External
  premises, the repository-rules line, and the `## Spec` section. c53's answer opens with one line
  ("I've merged the reviewer and verifier results into the report below.") before the verdict.
  Phase A's c53 did not, and it is outside the report format.

## Decision rule, applied

| Condition | c39 | c53 |
|---|---|---|
| At most 1 waiting turn, and waiting tokens at most 25% of phase A's | 0, 0%: holds | 0, 0%: holds |
| Wall time at most +25% | +32%: fails | +47%: fails |
| Wall time over +50% (reject) | no | no |
| E1 to E4 (no stage lost) | holds | holds |
| **Outcome** | **between** | **between** |

**Between: stop and report to the maintainer.** The skill change and its validator check stay on
the branch; nothing has been reverted or shipped.

## Budget

The two runs used 4.25M tokens (1.95M + 2.29M), within the 5M estimate and under the 10M stop. The
five-hour window rose 3 and 4 points per run.

## Limits

- **One run per case.** Reviewer depth varies between runs (ai-antipatterns: 110K to 459K on the
  same diff), and so does the dispatched set.
- **The wall-time explanation is post hoc.** A clean attribution needs repeated runs of both
  versions on the same diffs.
- **Claude Code only.** The clause is written for any platform; opencode, Cursor and Codex were not
  run.
- **Phase A's setup applies:** the user's own setup left out, and the PR body passed as a spec
  argument.
- **The product measured is `bccb367` plus the two lines.** The branch also carries main's #83,
  which was not measured with this change.
