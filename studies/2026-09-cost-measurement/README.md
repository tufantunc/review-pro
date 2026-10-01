# Study: what does a review cost, and where does it go?

A pre-registered measurement for roadmap item 4 (cost that scales with the change), run on
2026-09-27. Two checks left over from item 3 ran alongside it: triage fidelity and J07.
[`PRE-REGISTRATION.md`](PRE-REGISTRATION.md) was committed (`a92d584`) before any measured run.
Phase A ran; phase B (#78, the large diff) did not, and waits on the maintainer.

**Headline.** A review cost 0.72M tokens on a one-file docs change, 2.42M on a 22-line code change
and 2.32M on a 364-line change, 2 to 4 minutes each. Cost follows the number of agents and
orchestrator turns, not the size of the change.

About 55% of every review is the orchestrator's own thread, and 13 to 20% is turns in which it
only acknowledges that one background agent finished. A size-based narrowing of the dispatch
would have dropped all four Medium findings these reviews produced.

Triage applied the repository-rules grammar exactly in 15 of 15 rows. The J07 owner said
`violated` in 6 of 6 runs.

## Contents

| File | What it is |
|---|---|
| [`PRE-REGISTRATION.md`](PRE-REGISTRATION.md) | Cases, counting, decision rules, budget and stop rules |
| [`cases.py`](cases.py) | Builds each throwaway clone, with reproducible shas, and installs review-pro `bccb367` at project scope |
| [`run.sh`](run.sh), [`batch.sh`](batch.sh), [`prompts.py`](prompts.py) | The headless runs and the exact prompts |
| [`tally.py`](tally.py) | Tokens and wall time per stage, from the session transcripts |
| [`analyze.py`](analyze.py) | The pre-registered decision rules, applied |
| [`rules_ref.py`](rules_ref.py), [`fidelity.py`](fidelity.py) | The step-8 grammar as code, and the comparison with triage |
| [`anchor.py`](anchor.py) | Item 2's anchor classification on this study's reviewer answers |
| `results/` | Every run's tally, the three review reports, the eight triage plans, the six J07 answers, the analysis and fidelity output |
| `raw/` | Each reviewer's final answer, verbatim |

## Where the numbers come from

- **Per-agent tokens:** the session transcripts Claude Code writes, under
  `~/.claude/projects/<slug>/<session>.jsonl` and `<session>/subagents/agent-*.jsonl`, counted
  once per API message id.
- **Check against the result event:** each run's transcript sum is compared with the result
  event's `modelUsage` for the session model.
  - It matched exactly on every run but one: c39's output tokens differ by 815 (0.03% of the run),
    likely a small internal call the transcripts do not record.
  - `modelUsage` also carries a second model, Haiku 4.5, which summarises WebFetch and WebSearch
    results and is not in the transcripts. It is added as its own row: 25K tokens on c77, none
    elsewhere.
  - The result event's `usage` field is the main thread only.
- **Wall time:** from the wrapper's start and end. Per-stage wall time spans the first to the last
  transcript timestamp of that stage.
- **Totals** add input, cache write, cache read and output. That total is the budget measure and
  the only figure roughly comparable with OCR's leaderboard, whose metric definition we do not know.

## Phase A: cost per review

| Case | PR | Change | Reviewers | Verifiers | Total tokens | Input / cache write / cache read / output | Wall |
|---|---|---|---|---|---|---|---|
| c77 | #77 | 1 docs file, +16 -1 | 3 | 0 | **0.72M** | 24K / 107K / 577K / 16K | 136 s |
| c39 | #39 | 4 code files, +18 -4 | 7 | 2 | **2.42M** | 0.1K / 287K / 2,077K / 52K | 247 s |
| c53 | #53 | 6 files, +306 -58 (lockfile, TS) | 6 | 2 | **2.32M** | 0.1K / 273K / 1,992K / 50K | 234 s |

- **Cache reads are 80 to 86% of every total.** Every turn of every agent re-reads its whole
  context.
- **List price:** the result event puts the API list-price equivalent at $1.11, $3.14 and $3.01.
  The maintainer's subscription is not billed per token.
- **Five-hour window:** usage rose 1 to 3 points per review.

### By stage

| Stage | c77 | c39 | c53 |
|---|---|---|---|
| Orchestrator: prep + triage | 153K (21%) | 255K (11%) | 328K (14%) |
| Orchestrator: dispatch, collect, merge | 231K (32%) | 822K (34%) | 589K (25%) |
| Orchestrator: verification collect + synthesis | (in the row above: no verifier ran) | 344K (14%) | 354K (15%) |
| Reviewers, all | 315K (44%) | 820K (34%) | 935K (40%) |
| Verifiers, all | 0 | 176K (7%) | 110K (5%) |
| Haiku (web tool summaries) | 25K (3%) | 0 | 0 |
| **Orchestrator thread, all** | **53%** | **59%** | **55%** |
| of which waiting turns (post hoc, below) | 2 turns, 93K (13%) | 5 turns, 378K (16%) | 6 turns, 460K (20%) |

Per reviewer, in thousands of tokens:
- **c77:** spec 32, correctness 46, ai-antipatterns 237. The last used the web, on npm's token
  changelog.
- **c39:** craft 156, performance 63, tests 129, correctness 137, api-contract 154, spec 70,
  ai-antipatterns 110.
- **c53:** craft 152, ai-antipatterns 180, tests 147, dry 146, spec 80, correctness 231.
- **Verifiers:** 53 to 93 each.

Wall time per stage: triage 24 to 54 s; the slowest reviewer 58 to 73 s (they run in parallel);
verification collect plus synthesis 70 to 84 s.

## The decision rules, applied (`results/analysis.txt`)

- **R-flat fires.** c77 is 31% of c53 (threshold 25%) and c39 is 104% of it (threshold 50%). A
  22-line change cost as much as a 364-line one.
- **R-cheap does not hold.** c77 is 0.72M against 0.7M, and c39 is 2.42M against 1.5M.
- **S-dispatch** does not fire. Reviewers take 34 to 44% of the total, under the 50% threshold.
- **S-verify** does not fire. Verification takes 0 to 7%. A review with only Low findings
  already verifies nothing, as c77 shows.
- **S-reread** does not fire (0 to 13%), and its premise does not hold. The orchestrator does not
  paste file contents into reviewer prompts. It writes the diff and the changed files to one
  bundle file and passes its path, in a 1-2K character prompt. Each reviewer's one `Read` is that
  bundle; no reviewer re-read a changed file the bundle already held.
- **S-overhead** fires on all three (50 to 58%), but the lever it names is small.
  - Each agent's first request carries about 11K tokens of Claude Code's own subagent system
    prompt and tools. The agent body, the preloaded rubric and the prompt add only 2-5K, which is
    15 to 30% of that base.
  - Halving review-pro's own text would save about 2K tokens per agent turn. On c39 that is about
    41 turns, roughly 80K, or 3% of the review.

## What the rules did not anticipate (post hoc)

**Waiting turns.** Claude Code runs subagents in the background by default. The orchestrator never
set `run_in_background`, and every reviewer and verifier started backgrounded. Each completion
opens a new orchestrator turn, which re-reads the whole orchestrator context (70 to 90K tokens on
c39 and c53) to write one line such as "Craft is back; five reviewers are still running."

Those turns are 13%, 16% and 20% of the three reviews, and their number grows with the agent
count. The canary showed that a subagent call with `run_in_background: false` runs in the
foreground. Whether several foreground calls in one message run in parallel and return together
was not tested. Nor was how the other platforms dispatch.

**The per-agent floor.** A reviewer that finds nothing still costs 32 to 137K tokens. The floor
is the ~11K harness base re-read on every turn, plus the rubric and the bundle. The orchestrator
thread has its own floor, about 19K of harness plus 12K of review-pro's three stage skills
(48 KB), re-read on each of its 10 to 23 messages.

**Which reviewers found what** (from `raw/`):

| Case | Findings by reviewer |
|---|---|
| c77 | ai-antipatterns: one Low |
| c39 | craft: Medium, Low, Nitpick; tests: Medium, Low; ai-antipatterns: Low, Nitpick; api-contract: Low; correctness, performance, spec: nothing |
| c53 | craft: Medium; tests: Medium, Low, Low; correctness: Low, Nitpick, Nitpick; ai-antipatterns: Low, Low; dry: Low, Nitpick; spec: nothing |

All four Medium findings came from craft and tests. A narrowing that keeps correctness and spec on
small diffs, the obvious size-based cut, would have lost all four.

## Triage fidelity (item 3's release gate)

The eight triage-only runs were compared with `rules_ref.py`, a direct implementation of step 8
(`results/fidelity.txt`). **15 of 15 rule rows agree** on `state`, `owner` and `then_missing`, and
`when_matched` also agreed on every row.

The runs cover:
- R2's `{name}` over 11 bindings;
- one binding judged among ten changed alongside;
- a new pack without and with its manifest (`{name}` left open, and a then path the change adds);
- `no-target`;
- `(any)` over a glob list and over a glob, with owner `correctness`;
- #62's natural R3 miss.

In the cost runs:
- c53's report shows R3 with the same four missing manifests, judged `held` for the right reason:
  the version did not change.
- c77 and c39 correctly report that no rule matched.

The gate holds on this sample. There was one run per case, with one model.

## J07

J07 is #62's missed `.cursor-plugin` bump, which the spike's owner judged `held` because a stale
`releasing.md` listed three manifests. It was re-judged here by the `ai-antipatterns-reviewer`
subagent, with the orchestrator's owner prompt and the current handling text, in the #62 clone
where that stale document still sits.

- **J07a** (R3's current sentence): `violated` in 3 of 3, each naming `.cursor-plugin/plugin.json`
  at 0.1.0 against 1.3.0.
- **J07b** (the spike's C3 sentence): `violated` in 3 of 3, the same.

Three of the six answers also name the release document's omission as drift against the rule's
list, which is what the handling text asks for. J07b's result says the handling text, not R3's
sharper wording, made the difference. The fix holds on this case; one case, six runs.

## Anchors (item 2's revisit condition)

`anchor.py` ran item 2's classifier on the 20 findings in `raw/` (`anchor-results.csv`). The
classifier flags 6.

By hand, 5 are its own false alarms:
- evidence quoting the comment above the line cited;
- removed lockfile lines;
- a blank line;
- a quote carrying line-number prefixes;
- a deleted-line quote.

One is a real drift: c53 tests at `doctor.ts:27`, where the messages sit on 24 to 26. It is one
line off, inside the dedup window.

That is 1 of 18 locatable findings, and 2 of 88 with item 2's corpus. Item 5's AACR-Bench run
remains the gate.

Note, 2026-10-01: item 5 ran internally and its results are not published, so that gate has no
public record. Item 2 stays "measured, not built" on the published evidence above.

## Budget

All runs together used 8.51M tokens including cache reads:
- the three reviews: 5.46M
- eight triage runs: 1.28M
- six J07 runs: 1.78M
- the setup canaries: about 0.07M, not counted in the total above

The pre-registered estimate was about 13M; c53 cost a third of its size-scaled estimate, because
the orchestrator bundles files instead of pasting them. No stop rule fired. The five-hour
utilization rose from 0.18 to 0.34 over the whole phase.

## Deviations from the pre-registration

- **`tally.py` was corrected after the first run**, and every run was re-tallied from the same
  transcripts, with none re-run. The corrections:
  - it read the first result event, but a turn ends at each background notification and the last
    result carries the report;
  - it now reports Haiku as its own row;
  - it fixes a variable name clash;
  - it prints the size of a mismatch instead of a flag;
  - it records turns, for the waiting-turn measure.
- **The first launch of the triage batch failed**, because zsh does not split words. Nothing ran
  and no tokens were spent; `batch.sh` runs under bash.
- **Waiting turns, the per-agent floor and the reviewer-to-finding map are post hoc.** No rule
  was pre-registered for them, and they are labelled as such.
- **The anchor classifier's non-EXACT rows were checked by hand**, as in item 2.

## Recommendation

**The pre-registered levers:**
- **S-overhead** is the only stage rule that fired. What review-pro controls there is about 3% of
  a review, so it is not worth a design.
- **Narrowing the dispatch by size is not recommended.** It would have lost every Medium finding
  in these reviews, and S-dispatch did not fire.
- **Verification already scales:** it is 0 to 7%, and a Low-only review runs none.
- **There is nothing to de-duplicate in re-reads.**

**One post-hoc candidate is worth a spike before any spec: collect agent results in one turn.**
- Ask for parallel dispatch in one message, in the foreground where the platform allows it.
- It would remove the waiting turns, 13 to 20% here, without skipping any stage or losing a
  finding.
- The spike would check, on Claude Code:
  - that several foreground calls in one message run concurrently and return together;
  - that wall time does not grow;
  - that other platforms keep working.

  It would then re-run c39 with that one line changed.

**Phase B (#78) is not needed for this decision.** It would show how cost grows on a large diff,
where every reviewer reads a bundle of up to about 245K tokens. A calibrated estimate is 15 to 25M,
over the phase budget on its own.

## Limits

- **One run per cost case** and one per triage case, so no variance. One model (Opus 5.5, high
  effort) throughout.
- **The PR body was passed as a spec file argument**, because the clones have no route to
  `gh pr view`. External premises that triage would read from a PR body came only from commit
  messages and the argument.
- **The user's own setup was left out on purpose:** settings, plugins, hooks, MCP servers and
  CLAUDE.md. A real user's context raises every agent's floor.
- **Headless runs resumed on each background notification, as interactive sessions do.** No
  interactive run was measured to confirm the numbers match.
- **The triage and J07 runs ran four and six at a time**, so their wall times may carry
  contention. The cost runs ran alone.
- **Transcripts under `~/.claude/projects/` are not in the repository.** The tallies in `results/`
  are what remains; the clones can be rebuilt with `cases.py`.
- **The OCR comparison is placement only**, with different PRs and an unknown metric. Neither this
  study nor its numbers is a public claim.
