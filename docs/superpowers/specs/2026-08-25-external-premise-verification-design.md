# Design: automatic verification of external premises

Closes [#13](https://github.com/tufantunc/review-pro/issues/13).

## The gap

Case 2 of the [pilot study](../../../studies/2026-08-copilot-pr-pilot/FINDINGS-case2.md)
reviewed a PR that deleted ~97 lines of defensive code, justified by "upstream SDK bug
fixed in the new version". Two reviewers, `tests` and `api-contract`, correctly flagged
that premise as unverified by the repo. Neither left the repo to check whether it was
true. The two that did go upstream found it false twice over: the fix was already
present in the version the repo was on, and the deleted guard also covered a second
field upstream never fixed.

Of those two, `ai-antipatterns` had been **explicitly told** to check upstream in a
hand-written dispatch prompt. Only `correctness` went on its own initiative.

So repo-grounded verification is reliable, because the "no unresearched findings" rule
in every rubric works. Leaving the repo is not: it depends on the mandate a dispatch
happens to carry.

### The gap is a plumbing gap, not a wording gap

The issue reads as a rubric problem, and it is not, or not only. A change's rationale
lives in one of three places, and two of them never reach the reviewer:

| Where the rationale lives | In the reviewer's context? |
|---|---|
| Code comments in changed files | Yes. Baseline is diff + full contents of changed files. |
| Commit messages | **No.** |
| PR body | **No.** |

Triage reads commit messages and the PR body (step 6.2, via `gh`), but only to resolve
the spec, and passes the result only to `spec` as `### Spec text`. So a reviewer asked
to verify a premise stated in a commit message currently cannot see the premise. Adding
a clause to three rubrics would have produced a rule with no input.

## What this adds

Three outcomes for any external premise, each with exactly one home:

1. **Contradicted.** A normal finding, under the owning reviewer's existing category
   root. No new root.
2. **Confirmed.** No finding. One line in a synthesis ledger.
3. **Unverifiable.** Not a finding. A row in the ledger, carrying the reason.

All three are accounted for in one `## Premise verification` block per reviewer, one row
per premise it was handed. Silence is not a fourth outcome: a premise routed to a
reviewer that then leaves no trace is indistinguishable from one nobody checked, which
is the ambiguity this whole axis exists to remove. The first draft of this design gave
the block to the unverifiable case alone, and synthesis then had nothing to build a
`confirmed` row from and no way to detect a premise that vanished after routing.

Nothing is added to the finding schema. `confidence: high | medium | low` already
exists in all thirteen rubrics, and the third outcome reuses it.

## Threshold: what counts as an external premise

A rationale that points at a **specific, addressable external artifact**: an upstream
issue or PR number, a changelog entry, a CVE, a release note, an RFC. "Fixed upstream"
with no number counts, because which fix is determinable from the package version.

Not in scope: any claim the reviewer merely cannot ground in the repo. That threshold
would turn every review into a web crawl, make the request count unpredictable, and
take time from the reviewer's actual concern.

Expected volume: 0 to 2 premises on a typical review.

## Channel order

The issue treats "go outside the repo" as one act. It is two, and the cheaper one is
better. A premise is verified in this order, stopping at the first channel that settles
it:

1. **The locally resolved dependency source.** `node_modules`, `~/.nuget/packages`,
   `~/.cargo/registry`, `vendor/`. Offline, deterministic, and this is where "at the
   pinned versions" is literally true, because it is what the build resolved to.
2. **Lockfile and manifest**, to establish the version the claim must hold at.
3. **The network.** Upstream issue, PR, changelog, release notes.
4. Nothing. Say so.

Why this order and not the issue's undifferentiated one: in the pilot, both halves of
the centerpiece finding were visible in the installed package source. The one claim
`api-contract` could not settle was blocked by the **package being absent from the local
NuGet cache**, not by lack of network. So the portable, reproducible part of external
verification is "read the dependency you actually resolved to"; the network is the
unreliable remainder.

The reviewer must record which channel settled the premise. A network answer is not
reproducible: the same diff reviewed tomorrow can reach a different conclusion, and a
reader who cannot see which channel was used cannot tell a durable verification from a
perishable one.

## Routing: hybrid, split by what each stage can see

Triage owns the channels a reviewer cannot see. Reviewers own the channel already in
their baseline. The split does not overlap, which is the point: if both scanned code
comments, the same premise would be routed twice.

| Channel | Gathered by | Needs `gh` |
|---|---|---|
| Commit messages (`git log base..HEAD`) | triage | no |
| PR body | triage | yes, best-effort |
| Code comments in changed files | the reviewer | no |

### Why this is its own triage step, not part of step 6

Step 6 is a fallthrough chain: if 6.1 (an explicit spec argument) wins, triage never
reads the PR body at all. Hanging premise extraction off step 6 would make the feature
die silently whenever a user passes a spec by hand. Premise extraction gathers its own
sources.

Commit messages come from `git log` and need no `gh`. Only the PR body depends on `gh`,
and its absence is an ordinary condition, as everywhere else in triage.

### Plan field

```yaml
external_premises:                    # omitted entirely when there are none
  - claim: "upstream SDK bug fixed in the new version"
    cited: openai-dotnet#733
    source: commit-message | pr-body
    pinned: openai 2.11.0 -> 2.12.0   # optional; when the diff pins the version
    owner: ai-antipatterns
```

`pinned` is optional but load-bearing when present. The version bump is inside the diff,
so triage already has it, and the issue's "at the pinned versions" requirement only
becomes concrete once a version is named. The reviewer could read it from the diff
itself; triage stating it makes the obligation precise and auditable.

### Owner selection

The owner is the reviewer whose concern the premise is load-bearing for. Exactly one
owner per premise.

| Premise justifies | Owner |
|---|---|
| Adding, removing, or bumping a dependency | `ai-antipatterns` |
| A behaviour-equivalence claim across a dependency change | `correctness` |
| An API surface or version-floor claim | `api-contract` |
| Anything else | `ai-antipatterns` (default) |

`ai-antipatterns` is the default because claims that do not hold are already its
concern: `needless-dep` and confidently-wrong code.

**Assigning a premise to a reviewer dispatches that reviewer.** Without this, triage can
assign a premise to `api-contract`, the signal map can decline to dispatch
`api-contract`, and the premise is orphaned with nothing reporting that it was. This
parallels `spec_source` forcing the `spec` dispatch.

### Triage does not verify

Triage extracts and routes. It does not check.

The existing output discipline already says "Return ONLY the dispatch plan. Do not
review the code." Premise extraction gives triage a new reason to be curious, so the
prohibition needs to be explicit: a triage that checks the premise itself breaks the
one-owner rule and produces a verification nobody can attribute.

### Cap

At most three premises, chosen by what the diff most depends on. A dropped count is
stated in the plan. A silent cap reads to the next reader as complete coverage.

### Reaching the reviewer

The orchestrator (`review-pro` skill, step 2) adds an `### External premises` section,
exactly parallel to `### Spec text`, to the owning reviewer's prompt only. Omitted for
every other reviewer.

## The reviewer's contract

### Contradicted premise

A normal finding under the owner's **existing** subcategory, chosen by what the false
premise damages, not by the fact that a premise was false. In the pilot that was
`ai-antipatterns.needless-dep` for the unnecessary bump; the deleted guard leaving
`created_at` exposed is a `correctness` concern.

A dedicated "false premise" category would be wrong: every axis would drain into one
bucket and dedup on the category root would stop separating the axes it exists to keep
apart.

`evidence_refs` names the external source **with its channel and version**, because a
versionless upstream citation cannot be checked:

```
evidence_refs: [~/.nuget/packages/openai/2.12.0/lib/.../ContainerFileResource.cs:41]
evidence_refs: [openai/openai-dotnet@OpenAI_2.12.0]
```

Severity comes from the existing bar. `confidence: high`, because the question was
settled.

### Every premise, in one block

One `## Premise verification` block per reviewer, one row per premise it was handed,
whatever the outcome. Named distinctly from the `### External premises` input section on
purpose: an output block sharing its input's heading makes any guard on either of them
satisfiable by the other.

```
## Premise verification
- premise: dependency bump justified by "upstream SDK bug fixed in the new version"
  cited: openai-dotnet#733
  settled_by: none
  outcome: unverified
  blocked: openai 2.12.0 absent from ~/.nuget/packages; no network access
```

`settled_by` is one of `local-package-cache`, `lockfile`, `network`, `none`. `outcome`
is `contradicted`, `confirmed`, or `unverified`. A contradicted row adds `finding` naming
the category it was filed under; an unverified row adds `blocked`.

And the hard rule: **a finding that rests on a premise you could not settle carries
`confidence: low`, and the block states why. Never silently skip, never silently
trust.**

This codifies observed behaviour rather than inventing one. In the pilot, `api-contract`
set `confidence: low` on the one claim it could not settle and stated plainly that the
package was absent from the local cache. That is the standard; it was simply not
required of anyone.

## Synthesis

### The ledger

The acceptance criterion is written against the reviewer's output, but the reader reads
the report. If synthesis drops the block, the criterion is satisfied in a place nobody
looks. So Stage 3 prints a compact ledger, omitted entirely when there were no external
premises:

```
### External premises
| Premise | Cited | Settled by | Outcome |
```

`Settled by` names the channel: local package cache, lockfile, network, or none.
`Outcome` is contradicted (referencing the finding), confirmed, or unverified (with the
reason).

Confirmed premises are listed, not dropped. If a confirmed premise leaves no trace, a
reader cannot distinguish "checked and it held" from "never checked". That is the exact
ambiguity this issue exists to remove.

### The out-of-diff tripwire needs no change

Its definition already names "an upstream source" among the out-of-diff evidence it
counts. An external-premise finding therefore satisfies the tripwire, which is correct:
the review genuinely left the diff. These are code-axis findings, so the `spec`
exclusion has no analogue here and inventing one would be work for its own sake.

## Validation

### Load-bearing greps

The bar for this repo: a single line whose silent deletion disables a feature without
failing any other check.

| File | Grep | Deleting it |
|---|---|---|
| triage | `external_premises` | triage cannot route; the feature is entirely dead |
| triage | the assign-dispatches rule | premises are orphaned and silently unverified |
| triage | the no-verification prohibition | triage self-checks; the one-owner rule collapses |
| `review-pro` (orchestrator) | the `### External premises` prompt section | triage routes premises the orchestrator never passes on; the chain runs and verifies nothing |
| 3 rubrics + 3 bodies | `## Premise verification` | a premise routed to a reviewer can vanish without the report showing it |
| 3 rubrics + 3 bodies | the `confidence: low` rule | findings on unsettled premises report at full confidence |
| synthesize | the ledger section | the reviewer's statement dies before the report |
| context-policy | `which channel settled` | a network answer becomes indistinguishable from a local one; reviews stop being reproducible |
| context-policy | `locally resolved dependency source` | the local-first channel goes, and reviewers reach for the network on premises the installed dependency already settles |

Rubric **and** body, both, per the rule the spec axis taught: the body is the copy that
reaches the running subagent, and the rubric is the copy the inline path documented in
`review-pro/SKILL.md` applies. A rule present in only one silently disables the feature
on the other path.

### Meta-tests

Nine guards, each with a positive control before the negative mutation, per the
discipline established in Case K: without the positive control, a passing assertion can
come from the fixture never having contained the string. Twenty-two assertions, taking
the suite from 73 to 95.

The context-policy row became two during Task 1's review. One string cannot guard both
halves of that rule: a reviewer deleted the ordered channel list while leaving "record
which channel settled" in place, and the validator stayed silent. The order and the
record-keeping are separate rules and need separate anchors.

The orchestrator row was missed on the first pass through this table and found while
proving the guards in a sandbox. It is the reason the count is eight: the design said
the orchestrator adds the prompt section, and nothing would have failed if that line
were deleted, which is the exact bar this table is written against.

### One fixture, not eleven

Adding a load-bearing grep on the triage or synthesize skill makes the meta-test
fixtures in `write_orchestrator` invalid. The blast radius is one case, not eleven:
almost every case asserts that a *specific* error message appears, and extra errors do
not disturb that. Only Case A asserts a clean pass. The fixture still has to be updated
for both orchestrator branches, and the guards on the three owning rubrics and their
bodies need no fixture at all, because they name specific paths behind `[[ -f ]]` and no
fixture creates those files.

### Files touched

`core/skills/review-pro-triage/SKILL.md`, `core/skills/review-pro/SKILL.md`,
`core/skills/review-pro-synthesize/SKILL.md`, `core/shared/context-policy.md`,
`core/skills/{ai-antipatterns,correctness,api-contract}/SKILL.md`,
`core/agents/{ai-antipatterns,correctness,api-contract}-reviewer.md`,
`scripts/validate.sh`, `scripts/validate.test.sh`. Twelve files.

### Published surfaces

The reviewer count stays at thirteen, so the published-count guard is unaffected. Two
surfaces are checked explicitly rather than waiting for a reviewer to raise them,
because both were missed last release: `docs/llms.txt`, which is hand-written and
therefore never read by the site drift check, and the npm package page, which lives in
`cli/` and was overlooked for being outside `core/`.

### The acceptance test

The greps prove a line is present. They do not prove the feature works.

The real test is available: pilot case 2 is a known diff with a known false premise and
a hand-verified correct answer. If this works, reviewing that diff surfaces the false
premise **with nobody hand-writing the mandate**. The whole of the test is that the hand
comes away.

Feasibility is confirmed during implementation, since the diff was in an upstream PR and
the study may not carry enough to replay it. If it does not, that is stated and a
synthetic fixture is built instead, not skipped quietly.

## Version

1.1.0. Reviewer behaviour changes; the finding schema, the category roots, and the
reviewer roster do not. All three manifest versions move together, as always.

## Limitations

**Reviews stop being fully reproducible.** A premise settled over the network can be
settled differently tomorrow. This is inherent to external verification, not a defect of
this design, and it is why the channel that settled a premise is recorded rather than
merely the outcome.

**Triage remains a single point of failure for two of the three channels.** A premise in
a commit message that triage does not extract is verified by nobody. The rubric clause
covers only what the reviewer can see for itself. The mitigation is that the missed
channels degrade to today's behaviour rather than to something worse.

**A premise can be addressable and still unreachable**, most often for a private
upstream repository or an air-gapped environment. That path is the unverifiable outcome,
which is why it is a first-class outcome and not an error.

## Out of scope

- An opt-out switch for external verification. No evidence yet that anyone wants one,
  and the cheapest channel is offline anyway.
- Caching verification results across reviews.
- Extending the obligation to `tests`, which noticed the premise in the pilot but does
  not own claims about dependency behaviour. Adding owners multiplies the same fetch
  and invites contradictory conclusions about one premise.
