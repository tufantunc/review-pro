# Design: an independent refuting verifier for review-pro

**Status:** approved in brainstorming 2026-09-24, not yet implemented.

## The gap

Synthesis merges, weights and calibrates findings, but nothing ever re-checks one.
Worse, it treats agreement as evidence: a finding flagged by two reviewers gets a
conviction boost. The #51 libc episode and the pilot's case-3 `dotnet run` finding
were both several readers agreeing on something nobody had traced to its source.

This is step 3 of the ideas borrowed from
[cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill),
whose rule is that the agent checking a finding is never the agent that found it.

## The evidence this design rests on

A pre-registered spike (2026-09-24, committed as `studies/2026-09-refuting-verifier/`)
gave 13 findings with known labels to fresh agents told to refute each one from
source, two runs per finding:

- 6 of 8 runs on known-false findings refuted them, which met the pre-registered
  threshold exactly.
- 0 of 26 runs added new findings (the stop rule held).
- The out-of-repo item was left standing both times, with the missing fact named.
- Both runs "killed" one finding labelled true. Hand-checking showed the label was
  wrong: the pilot's case-3 finding, filed as microsoft/aspire#19540, does not hold.
  A second label (#51's libc claim) had already been found wrong while the corpus was
  being built.

On the corrected labels, no true finding was refuted. The sample is small, one model
family played every role, and the labels were wrong in 2 of 13 items. Those limits
shape the decisions below: the verifier may take a finding out of the verdict only
where a wrong refutation does not ship a blocker.

## Decisions

1. **Asymmetric effect.** A refuted Medium leaves the verdict. A refuted High or
   Critical keeps blocking and is marked disputed.
2. **Scope.** Code-axis findings at Medium or above, after dedup, in severity order,
   at most 8 per review. Nothing beyond the cap is skipped silently.
3. **Placement.** Inside synthesis, after dedup and before calibration and verdict:
   one fresh agent per finding, dispatched in parallel.

Rejected: verifying each reviewer's findings as they arrive, which verifies
duplicates and makes a cap meaningless; and one verifier for all findings in one
context, which was never measured and lets one judgement bleed into the next.

## Pipeline

Stage 3 splits in three:

- **3a Merge.** Unchanged: collect, partition into code and spec pools, dedup, weight.
- **3b Verify (new).** The orchestrator selects the findings and dispatches one
  `review-pro-verify-subagent` per finding, in parallel.
- **3c Calibrate, verdict, report.** The rest of today's synthesis, with the
  verification results as an extra input.

The orchestrator owns 3b because subagents cannot spawn subagents. When synthesis
runs as a subagent it receives the results as input; if none arrive, it treats every
finding as not verified, never as standing.

### Selection

- Code-axis findings with severity Medium, High or Critical.
- Order by severity, then by file and line. The first 8 are verified.
- Spec-axis findings are not verified in v1, because the spike measured none. The
  report says so in one line.

### What each verifier receives

- The merged finding block verbatim, including `evidence_refs`.
- The name of the reviewer that wrote it. Not how many reviewers flagged it: that
  count is pressure, and the libc and case-3 errors were agreement.
- The diff (`<base>...HEAD`) and the change description when there is one.
- The working tree, read-only.
- Network per `core/shared/context-policy.md`: pinned upstream source is allowed;
  issues, pull requests and discussions are not.

### Failure handling

A verifier that errors, times out, or returns a block that does not parse leaves its
finding **not verified**. So does the cap. Where no independent subagent is available
(a skills-only install), verification does not run and the report says so in one
line. The orchestrator must not verify inline: a check in the same context is not
independent, and it is the opposite of what the spike measured.

## The verifier contract

The skill carries the prompt measured in the spike, changed only where the setting
forces it: the evidence cutoff is gone, and "the checkout" becomes "the working
tree". The rules stay as measured:

1. A refutation is a positive contradiction the verifier can cite, not doubt. "I
   could not confirm it" is `stands`.
2. A claim that depends on runtime behaviour, a tool's behaviour, or a fact outside
   what the verifier can read stands unless a citable source contradicts it, and is
   listed under `unchecked`. Never settle it from memory.
3. Judge only this finding. New issues get at most one line under `noticed` and are
   not part of the verdict.
4. Severity is not the verifier's question.

Verdicts: `refuted`, `partly_refuted` (a supporting claim or the remedy falls, the
defect stands), `stands`.

One field is new and was **not** measured:

```
defect_stands: yes | no
```

The spike's V11 run B answered `partly_refuted` while leaving only a doc-comment nit
standing, which misuses the label. The field is a consistency check, and every
inconsistency resolves in the cautious direction:

| verdict | defect_stands | treated as |
|---|---|---|
| `refuted` | `no` | refuted |
| `partly_refuted` | `yes` | partly refuted |
| `partly_refuted` | `no` | refuted |
| `stands` | `yes` | stands |
| `refuted` | `yes` | not verified |
| `stands` | `no` | not verified |

The output block adds a `finding` key (`file:line` plus title) so synthesis binds each
result to the right finding. A result that binds to no finding is discarded and that
finding is not verified.

Tools: Read, Grep, Glob, Bash and WebFetch; no Edit or Write. "Do not build, run the
project or install packages" stays in the prompt, since no portable mechanism
restricts Bash per command. On Codex the installed agent is `sandbox_mode = "read-only"`.

## Verdict and report

| result | Medium | High / Critical |
|---|---|---|
| stands | unchanged, marked verified | unchanged, marked verified |
| partly refuted | severity unchanged; the falling part and its citation shown under the finding | same |
| refuted | leaves the verdict; moves to `### Refuted in verification` | keeps blocking; marked disputed, with the citation |
| not verified | unchanged, marked | unchanged, marked |

Severity is untouched by a partial refutation: rule 4 keeps severity off the
verifier's table, and in the spike the falling part was a remedy or a supporting
claim (V01, V04), which the reader needs to see next to the finding.

Agreement does not override a refutation. "Flagged by N reviewers" stays as a
coverage note and protects nothing.

Report layout:

- The verdict line counts disputed blockers: `BLOCK (code), 1 disputed`.
- Under it, one line:
  `Verification: 6 checked (4 stand, 1 partly refuted, 1 refuted), 2 not checked (cap). Spec findings are not verified.`
- After the Medium, Low and Nitpick groups, `### Refuted in verification`. Each entry
  gives the finding, the refuted claim, and the contradicting `file:line` with its
  excerpt.
- A `noticed` line appears under its own finding, at most one per finding, labelled
  not reviewed. It never enters the verdict.

Unchanged: the out-of-diff evidence check counts as it does today, because it measures
whether the review left the diff, not whether a finding is right. The external
premise ledger is unchanged; a finding born from a premise is verified like any other.

## Packaging

New:
- `core/skills/review-pro-verify/SKILL.md`
- `core/agents/review-pro-verify-subagent.md` (`loads_skill: review-pro-verify`)

The verifier is neither an orchestrator skill nor a reviewer. It stays out of
`ORCHESTRATOR_SKILLS` (`cli/src/lib/plugin.ts`), so it is installed as a real subagent
on every target, Codex included. It has no category root and no stack signals, so the
reviewer count and the closed lists of ADR-0006 and ADR-0007 are untouched.

Changed:
- `core/skills/review-pro/SKILL.md`: a step between fan-out and synthesis that merges,
  selects, dispatches and collects.
- `core/skills/review-pro-synthesize/SKILL.md`: the steps split after dedup; the
  verdict table and report layout above.
- `core/agents/review-pro-synthesize-subagent.md`: verification results as an input.
- README pipeline description and `docs/internals`.

The finding schema does not change; verification is a report-level annotation. The
report gains lines and a section, which is additive, so this is a minor release when
one is cut.

`docs/internals/adr/0009-*.md` records the decision, the spike's evidence including
both label errors, the rejected placements, and the open risks.

## Validator guards

Each with a mutation meta-test that turns red when the guard is removed:

- `review-pro-verify/SKILL.md` required sections, the cite-or-stand rule, and the
  judge-only-this-finding rule.
- Synthesis: a refuted High or Critical keeps blocking; agreement does not override a
  refutation; not verified is never rendered as standing; the `defect_stands` table.
- Orchestrator: the dispatch step, and the ban on inline verification.

CLI (vitest): the verifier installs on all four targets, as `.toml` on Codex, is not
filtered by the orchestrator set, and uninstall removes it.

## Acceptance, pre-registered before merge

Predictions and decision rules are written before any run.

1. **Contract run.** The new skill text on the 13-item corpus with corrected labels,
   one run per item. Pass: 0 true findings refuted, at least 3 of 4 false findings
   refuted, `defect_stands` consistent with the verdict in at least 12 of 13.
2. **End to end.** The working-tree pipeline on pilot case 3 (aspire) and on a clean
   control diff. If the reviewers reproduce the `dotnet run` finding, it must come out
   refuted or disputed. The control must render `0 checked` and an intact report.
3. **Render check.** Synthesis given 10 hand-built findings and 8 verification
   results: the cap, the not-verified mark, the disputed counter and the refuted
   section must all render correctly.

The implementation PR is reviewed with review-pro, verifier on.

## Limitations

- One model family wrote, refuted and adjudicated every finding in the evidence.
- 13 findings, and a corpus whose hand-verified labels were wrong in 2 of them.
- Parallel subagents on opencode and Cursor are unverified; without them the fallback
  is "not verified".
- Cost: about 70k tokens per verified finding, up to about 560k per review at the cap.
- A wrong refutation can still take a Medium out of the verdict. The asymmetry bounds
  the damage to non-blocking findings; it does not remove it.

## Out of scope

- Verifying spec-axis findings.
- A second verifier for disputed High or Critical findings, or any refute-until-agreed
  loop. ADR-0008 records that a refuter never runs out of things to say.
- Letting the verifier change severity.
