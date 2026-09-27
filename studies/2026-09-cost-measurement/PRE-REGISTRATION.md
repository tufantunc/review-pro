# Pre-registration: what does a review-pro review cost, and where?

Written and committed 2026-09-27, before any measured run. The setup checks already run, and
their results, are listed under "Setup checks"; no review, triage or J07 run has been made.

## Questions

1. **Cost.** How many tokens and how much wall time does one review take, per size class, and
   which stage takes what share: triage, each reviewer, verification, synthesis?
2. **Triage fidelity** (a gate on the repository-rules release, roadmap item 3). Does the triage
   model apply the step-8 grammar the way a script would?
3. **J07.** In the spike, the owner judged #62's missed `.cursor-plugin` bump `held`, deferring to
   a stale `releasing.md`. Does the current handling text fix that?

## What is measured

The product is review-pro at `bccb367` (main after #80). `cases.py` builds one throwaway clone per
case with a fixed git identity and date, so every sha is reproducible. It installs `core/skills`,
`core/agents` and `core/shared` at project scope (`.claude/`), which mirrors what the CLI copies to
`~/.claude` for Claude Code. The user's global install (v1.4.0) is not touched.

`run.sh` runs `claude -p` in the clone with these settings:

- **Model:** the user's model and effort, `--model claude-opus-5-5 --effort high`.
- **User setup left out:** `--setting-sources project,local --strict-mcp-config`. This drops the
  user's settings, plugins, hooks, MCP servers and `~/.claude/CLAUDE.md`, so the numbers are
  review-pro's own.
- **Permissions:** `--permission-mode bypassPermissions`. It is safe here because each clone is a
  throwaway with no remote; `gh` falls through, and nothing is pushed.

## Setup checks (done before this file was committed)

- **Project scope wins.** A canary line in the clone's `.claude/skills/review-pro-verify` and
  `.claude/agents/review-pro-verify-subagent` was returned by both the skill and the subagent.
  The skill loaded from the clone's path.
- **Only built-in plugins load.** With the flags above: `agents-md` and `telemetry`, no MCP
  servers. A question about `RuntimePulse`, `CodeGraph` and `superpowers` (all three are in the
  user's CLAUDE.md or plugins) came back "no" for each. An empty session costs about 19K tokens
  of context.
- **Token sources.** The result event's `usage` is the main thread only. Its `modelUsage` includes
  subagents. The transcripts (`~/.claude/projects/<slug>/<session>.jsonl` and
  `<session>/subagents/agent-*.jsonl`) sum exactly to `modelUsage`. On the canary run that was
  6 / 23,844 / 29,683 / 525 (input, cache write, cache read, output). Per-stage numbers therefore
  come from the transcripts, and `tally.py` checks each run's sum against `modelUsage`.

## Cases

**Cost runs (phase A)**, each `/review-pro` on the case branch, with the PR body as the spec
argument (the clone has no GitHub route for `gh pr view`):

| Case | PR | Class | Changed | Size (head content + diff) | Estimate, all tokens incl. cache read |
|---|---|---|---|---|---|
| c77 | #77 | trivial | 1 docs file, +16 -1 | ~2K tokens | 0.5M |
| c39 | #39 | small code | 4 files, +18 -4 | ~2K tokens | 2M |
| c53 | #53 | medium code | 6 files, +306 -58 (a lockfile, TS) | ~36K tokens | 6.5M |

**Phase B, only with the user's go-ahead:** c78, PR #78 (large: 53 files, ~245K tokens). A
size-scaled estimate is ~30M. It is re-estimated from phase A's measured numbers before asking.

**Triage-only runs**, each `/review-pro-triage` on the case branch. The reference rows below come
from `rules_ref.py` (no model), a direct implementation of step 8 at `bccb367`, and were computed
before any triage run:

| Case | What it is | Grammar case | Reference rows |
|---|---|---|---|
| t62 | #62, natural | R3 judge (the J07 miss) | R3 judge, missing `.cursor-plugin/plugin.json` |
| t71 | #71, natural | R2 `{name}`, 11 bindings | R2 changed-alongside; R4 judge `docs/llms.txt`; R5 judge `cli/README.md` |
| v71-nomanifest | #71 without `stacks/go/manifest.json`'s bump | R2 binding union: one binding judge | R2 judge `stacks/go/manifest.json`; R4, R5 judge |
| v-newpack | main + a new pack with no manifest | `{name}` left open | R2 judge `stacks/newpack/manifest.json` |
| v-newpack-manifest | the same, with a manifest | a then path this change adds | R2 changed-alongside |
| v-notarget | a base without `docs/llms.txt`, then a security rubric edit | no-target | R4 no-target; R5 judge `cli/README.md` |
| v-schema | main + an output-schema edit | (any), owner `correctness` | R4, R5 judge; R7 judge `core/agents/*-reviewer.md`, owner correctness |
| v-docsrc | main + one i18n string | (any) over globs | R1 judge, the four site globs |

Secondary fidelity observations come from the cost runs, when their answers show the rows (c53's
reference: R3 judge, four manifests missing; c77 and c39: no rows).

**J07 runs.** These use the #62 clone. A thin main session forwards the orchestrator's owner
prompt (`prompts.py j07`) verbatim to the `ai-antipatterns-reviewer` subagent. The prompt carries
the changed file contents, the Files examined reminder, and the R3 row followed by the handling
text between the markers. The stale `releasing.md` that misled J07 is in the clone.

- **J07a**, 3 runs: R3's sentence as `.review-pro/rules.md` has it now.
- **J07b**, 3 runs: the spike's C3 sentence, so that a change in outcome can be told apart from
  R3's sharper wording.

## Counting

- **Tokens** are reported four ways (input, cache write, cache read, output) plus their total. The
  total is the budget measure. It is also the only figure roughly comparable with OCR's
  leaderboard, whose metric definition we do not know; that comparison is placement, not a claim.
- **Stages.** The main thread is cut at the orchestrator's own tool calls:
  - before the first reviewer dispatch is prep + triage;
  - from that message to the first verifier dispatch is dispatch + collect + merge;
  - the rest is verification collect + synthesis.
  Subagents are attributed by their `agentType`.
- **Wall time.** The result event's `duration_ms` and the wrapper's start and end give the total.
  Per stage, the span from the first to the last transcript timestamp.
- **Per reviewer**, two more measures:
  - **Re-read:** characters of `Read` results on files the reviewer's prompt already carried.
  - **Fixed overhead:** the first request's input, minus the prompt.
- **Subscription load:** the five-hour utilization reported by each run's rate-limit events.

## Decision rules

Each rule is applied to phase A, and again with c78 if phase B runs.

- **R-flat.** Cost does not scale with the change if either holds: c77 ≥ 25% of c53, or
  c39 ≥ 50% of c53.
- **R-cheap.** If c77 ≤ 0.7M, c39 ≤ 1.5M and no stage rule fires on c53, the result is "measured,
  not built". 0.7M is the top of OCR's per-review range; 1.5M allows about twice that for a small
  code change.
- **Stage rules.** A stage becomes a candidate on c77 or c39 when its trigger holds:

  | Stage rule | Fires when | Candidate |
  |---|---|---|
  | S-dispatch | reviewers take ≥ 50% of the total and ≥ 4 reviewers ran | narrow dispatch on trivial and small diffs |
  | S-verify | verifiers take ≥ 25% of the total | scale verification down on small diffs; a Low-only review already verifies nothing |
  | S-reread | re-read characters / 4 ≥ 20% of the reviewers' input plus cache write | do not re-read what triage handed over |
  | S-overhead | fixed overhead × turns ≥ 30% of reviewer tokens | shorten repeated prompt text |

  On c53 the same rules are reported but do not by themselves justify design.
- **Proposal.** At most two candidates, the largest shares first. None if R-cheap holds.
- **Triage fidelity.** Every rule row must agree on `state`, `owner` and `then_missing`.
  - Anything less is reported as a release-gate finding under its own heading, apart from the
    cost proposal, with the options: simplify the grammar, or move matching to a script (ADR-0011
    rejected the script for portability).
  - `when_matched` differences are reported but do not gate.
- **J07.** The fix holds on this case if J07a says `violated` naming the Cursor manifest in at
  least 2 of 3 runs, and does not hold at 1 of 3 or fewer.
  - J07b is read the same way. J07a holding and J07b not would credit R3's wording over the
    handling text.

## Budget and stop rules

- **Phase A estimate.** About 13M tokens including cache reads:
  - c77: 0.5M
  - c39: 2M
  - c53: 6.5M
  - eight triage runs: ~2.4M
  - six J07 runs: ~1.8M
- **Budget stops.** Stop and ask the user if any of these holds:
  - phase A's running total passes 15M;
  - the first review (c77) passes twice its estimate (1.0M);
  - any single run passes twice its estimate.
- **Subscription stop.** If a run reports five-hour utilization ≥ 0.85, pause until the window
  resets and say so.
- **Order.** c77 first (calibration), then the triage runs, J07, c39 and c53.
- **What each outcome does.**
  - A failed triage run is reported, not re-run.
  - A cost run that errors is reported with its partial numbers, and re-run at most once.
- **After phase A,** report and stop. Phase B runs only on the user's approval. Design runs only
  after the user approves a spec.

## Extra: anchors

Each reviewer's final answer is kept verbatim under `raw/`. `studies/2026-09-anchor-spike/`'s
classification (`measure.py`'s functions, run on these files and clones) gives more wrong-line
data for item 2's revisit condition. The gate for that item stays item 5's AACR-Bench run.
