# Pre-registration: dispatch every agent in one step and wait for all of them

Written and committed 2026-09-28, before the skill change and before any run. This is the one
candidate that roadmap item 4's measurement left for a spike
([`studies/2026-09-cost-measurement/`](../2026-09-cost-measurement), phase A).

## Why

In phase A, Claude Code ran every reviewer and verifier as a background task, because the
orchestrator's step 3.2 says "in parallel/background". Each completion opened a new orchestrator
turn, and each such turn re-read the orchestrator's whole context (70 to 90K tokens), often only
to say that one reviewer was back.

Those waiting turns were 13% of #77, 16% of #39 (5 turns, 378K tokens) and 20% of #53 (6 turns,
460K tokens).

## The change

Both dispatch lines in `core/skills/review-pro/SKILL.md` gain one canonical clause, and step 3.2
loses "background". The clause:

> all in one step: in parallel if your platform allows, else sequentially. Wait until every one
> has returned before you go on, and do not run them as background tasks that each report back on
> their own: every separate return starts a new turn that re-reads your whole context.

The two lines:

- **Step 3.2:** "**Invoke the `<reviewer>-reviewer` subagents**, every reviewer in the plan,
  <clause> Each prompt contains:"
- **Step 4.2:** "**Invoke one `review-pro-verify-subagent` per selected finding**, <clause> Its
  prompt contains:"

No platform-specific parameter is named. The sequential fallback stays.

The validator pins the clause on each line. It fails if either line lacks the clause, or carries
"background" outside it.

## Setup

Phase A's setup applies unchanged:
- one throwaway clone per case, built by `cases.py` with a fixed identity and date;
- review-pro installed at project scope;
- headless `claude -p` with `--model claude-opus-5-5 --effort high`;
- `--setting-sources project,local --strict-mcp-config`;
- the PR body passed as the spec argument.

The one difference is the product. It is phase A's `bccb367` with only the two lines above
replaced, so the comparison isolates this change. Main has since gained #83, which also edits the
orchestrator. `cases.py` asserts that the two lines it replaces are byte-identical to `bccb367`'s,
and that the replacements are byte-identical to the branch's.

## Cases

| Case | PR | Phase A baseline (`studies/2026-09-cost-measurement/results/tallies/`) |
|---|---|---|
| c39 | #39 | 2.42M tokens, 247 s, 7 reviewers, 2 verifiers, 5 waiting turns / 378K (16%) |
| c53 | #53 | 2.32M tokens, 234 s, 6 reviewers, 2 verifiers, 6 waiting turns / 460K (20%) |

One run each, c39 first.

## Measures

`tally.py` and `analyze.py` are phase A's, unchanged. `compare.py` adds the rest.

- **Primary: waiting turns.** A waiting turn is an orchestrator turn opened by a background-agent
  notification that dispatches nothing and is not the last turn (phase A's definition). Count,
  tokens and share of the total.
- **Secondary: total tokens,** read together with the waiting-turn share. One run per case
  carries reviewer variance, so a total difference is not attributed to the change unless the
  waiting-turn tokens account for it.
- **Wall time:** the wrapper's start and end.
- **Concurrency**, from the subagent transcripts. Each agent's span runs from the first to the
  last timestamp in its transcript.
  - Per group (reviewers, verifiers), the measures are the peak number of overlapping spans and
    the union of the spans, against the longest single span and against their sum.
  - A group ran **in parallel** if the peak overlap is at least 2 and the union is at most 1.5×
    the longest span. It ran **sequentially** if the union is at least 0.8× the sum.
  - Whether each agent started in the background is read from the stream's `task_started`
    events.
- **Equivalence:**
  - **E1.** Every reviewer the run's dispatch plan names was dispatched. A reviewer set that
    differs from phase A's is reported. It counts as a lost stage only when the run's own plan
    names a reviewer that never ran; a different plan is triage variance.
  - **E2.** Every code reviewer's answer ends with a `## Files examined` block.
  - **E3.** Every selected Medium+ finding (at most 8) got a verifier, or the report says why not.
  - **E4.** The report has the verdict, the Spec, Coverage and Verification lines, the Repository
    rules line or table, and the `## Spec` section.

## Decision rule (the maintainer's)

- **Accept** if all of these hold, on both diffs:
  - waiting turns fall markedly: at most 1 waiting turn, and waiting-turn tokens at most 25% of
    phase A's;
  - wall time grows by no more than 25% over phase A;
  - E1 to E4 hold.

  Then the change ships.
- **Reject** if either holds, on either diff:
  - wall time grows by more than 50% (the calls ran one after another);
  - any stage is lost (E1 to E4).

  Then the skill change and its validator check are reverted, and item 4 is recorded "measured,
  not built".
- **Anything in between:** stop and report to the maintainer. That includes waiting turns that do
  not fall, for example because the platform still backgrounds the calls.

## Budget and stops

- **Estimate:** about 5M tokens (2 × ~2.4M).
- **Stop and ask** if either holds:
  - the running total passes 10M;
  - c39 passes twice its phase A total (4.8M).
- A run that errors is reported with its partial numbers and re-run at most once.
