# Design: a Spec axis for review-pro

**Status:** approved in brainstorming 2026-08-20, not yet implemented.

## The gap

review-pro has twelve reviewers. Every one of them answers a variant of "is this
code good?" None of them asks "is this the code that was asked for?"

That is a hole in the product and an awkward one, because the project's own thesis
is that the evidence lives outside the diff. The originating issue is the most
obvious piece of evidence outside the diff, and the tool ignores it completely.

The pilot study shows the cost. In case 2 the finding that mattered most was that
the PR's stated rationale for a dependency bump was false. That is a spec finding,
and it was caught only because `ai-antipatterns` and `correctness` happened to
wander upstream. Nothing in the design made it their job.

The idea is borrowed from [`mattpocock/skills`](https://github.com/mattpocock/skills)
`skills/engineering/code-review`, which runs exactly two axes, Standards and Spec,
and refuses to merge them. The Spec axis is the part worth taking.

## What this adds

A thirteenth reviewer, `spec`, reviewing the diff against the originating
issue or spec document along three finding classes:

| Class | What it means | Severity ceiling |
|---|---|---|
| `missing` | the spec asked for something absent or partial | Critical |
| `wrong` | the requirement looks implemented but does not behave as asked | Critical |
| `scope-creep` | behaviour in the diff nobody asked for | **Medium, hard cap** |

The cap is the whole product decision on scope creep. Under the existing ladder
(`core/shared/severity.md`) BLOCK requires a Critical or High, so a Medium ceiling
means scope creep can request changes and can never block. No new mechanism in
synthesis is needed to enforce that; the rubric's cap is sufficient.

## Where the spec comes from

Resolution happens once, in triage, which already runs git and so is the natural
place for `gh`. Order:

1. **An explicit argument** from the user (a path, or an issue URL). An explicit
   instruction always beats auto-discovery: if the user names a spec, triage must
   not go hunting for a different one.
2. **The PR body and issue references in commit messages** (`#123`, `Closes #45`),
   fetched with `gh`.
3. **A file** under `docs/`, `specs/`, or `.scratch/` matching the branch name.
4. **Nothing.** The axis is skipped and the report says so.

Every link fails silently to the next one. `gh` absent, not authenticated, the
repo not on GitHub, or the branch not being a PR at all are all ordinary
conditions, not errors. Most people who install review-pro will be in at least one
of them.

Multiple references are all used, not chosen between. The intent of a PR that
closes three issues is the sum of the three.

Triage emits `spec_source` carrying what was found, not merely whether something
was:

```yaml
spec_source:
  kind: argument | pr-body | issue | file | none
  ref: <issue number, path, or url>   # omitted when kind is none
```

**Dispatch is conditional on resolution, and this is the one place the new
reviewer breaks triage's existing shape.** The signal map dispatches on file
types; `spec` relevance has nothing to do with which files changed. The rule is
therefore separate: dispatch `spec` if and only if `spec_source.kind` is not
`none`. It is not added to the signal map, and the "when in doubt, dispatch"
default does not apply to it, because dispatching a spec reviewer with no spec
guarantees a wasted subagent rather than a possible finding.

The report states this verbatim. A reader who cannot see what the review was
measured against cannot judge a spec finding, and "Spec: measured against issue
#412" versus "Spec: skipped, no spec found" is the entire difference between a
readable report and a confusing one.

## The rubric

`core/skills/spec/SKILL.md`, carrying the nine sections the validator requires.

**Evidence is two-part.** `evidence` is a verbatim quote of the spec line.
`evidence_refs` is where in the repo the requirement is or is not satisfied. The
mandatory spec quote is also the mitigation for the stale-spec limitation below.

**`missing` findings and the mandatory `file`+`line`.** The output schema requires
`file` and `line` on every finding, and an absence has no line. Rather than carve
an exemption into a rule that is inlined in twelve agent bodies, `missing` findings
point `file` at the changed file where the requirement would have landed and state
plainly that this is an absence. Where no plausible candidate exists, `file` is the
spec source itself.

**Scope creep needs a bar or the axis becomes a noise source.** Only excess that
carries cost or risk is flagged: a new dependency, a new public API, a new config
key, a behaviour change outside the spec's area. Refactors done in passing, added
tests, comments, and formatting are not flagged. Without this bar every good PR
produces a spec finding.

**Explicit non-flags**, following the precedent of the `craft` rubric:

- The spec being badly written is not a finding.
- Something the spec implies but does not state is not a missing requirement.
- Work explicitly deferred in the PR body ("follow-up in #500") is not missing.

**The anti-derailment trap, named.** Per `core/shared/reviewer-directive.md` each
agent body names its own likely drift. This one is obvious: reviewing code
*quality* is the other twelve's job. The body forbids `correctness` and `craft` by
name. This reviewer compares intent against implementation and says nothing about
whether the code is good.

**Approval bar:** no missing requirements, and any scope creep is low risk.

**Its context differs from every other reviewer's.** `core/shared/context-policy.md`
gives a row per reviewer, and this one needs the baseline (diff plus full contents
of changed files) plus one thing no other reviewer receives: the resolved spec text
itself. It does no repo-wide search. The closing principle of that file lists which
reviewers search repo-wide and must not gain a new name.

Note the asymmetry this creates. Every other reviewer's extra context is *code*;
this one's is a *document*, and it arrives from outside the repository in the `issue`
and `pr-body` cases. That is the point of the axis, and it is also why its findings
must stay out of the out-of-diff tripwire below.

## Synthesis

**Partition before dedup.** Two pools, code and spec. Dedup runs within each and
never across. A spec finding and a code finding on the same line are different
claims: "this should not exist" is not "this has a bug", and merging them loses
both.

**The verdict is the worse of the two axes, and the label says which drove it:**
`## Verdict: BLOCK (code)`, `REQUEST CHANGES (spec)`, `BLOCK (code + spec)`. One
top line is retained; the axis that caused it becomes visible.

**The out-of-diff tripwire counts code-axis findings only.** This is the sharpest
interaction in the feature. The v0.6.0 tripwire counts findings whose
`evidence_refs` fall outside `changed_files`. A spec finding's evidence is outside
the diff *by definition*, since the spec document or issue is not part of the diff.
Left unstated, this feature would satisfy the tripwire on every review and silently
kill a check shipped two weeks earlier.

**Absence is always stated, never silent.** `spec_source.kind: none` produces a
one-line note. So does a spec axis that ran and found nothing: "Spec: no mismatch
against issue #412." A positive statement is worth more than silence, and this
mirrors the rule that already governs a missing `diff_class`.

**Report layout.** Code findings stay under the existing severity headings,
unchanged. Spec findings get a `## Spec` heading, grouped **by class** rather than
by severity, with each finding's severity shown beside it. The class is more
informative than the severity on this axis, and grouping by it reinforces the
separation visually.

No row is added to the conflict-ownership table: cross-axis conflict is
structurally impossible because the pools never merge.

## What the CLI and validator need

Verified rather than assumed:

- **The CLI needs no change.** `installCore` enumerates directories dynamically
  (`copySkills` walks every dir, `copyAgentsMd` every `.md`), and
  `installCodexAgents` filters orchestrators by `loads_skill`, so a new skill and
  agent ship on all targets for free.
- **Three validator checks come free:** the nine required sections (the loop covers
  every non-orchestrator skill), the inline-schema parity check (it loops
  `core/agents/*-reviewer.md`), and the orphan-skill check that fails when a skill
  directory is missing from `manifest.json`.

Three checks must be added, in the shape of the existing `SCHEMA_KEYS` parity
guard, each protecting a load-bearing rule from silent deletion:

1. The synthesize skill contains the code-axis-only tripwire rule.
2. The triage skill emits `spec_source`.
3. The spec rubric carries the scope-creep Medium cap.

Plus one negative test in `scripts/validate.test.sh`, in the shape of cases H and
I: remove the rule, watch the validator go red. To be demonstrated, not asserted.

## Limitations

- **A stale spec cannot be detected.** An issue edited after implementation, or a
  PR body written afterwards, reads as ground truth. The mitigation is the
  mandatory spec quote on every finding, which lets a reader see a wrong premise at
  a glance instead of being quietly misled.
- **The axis does not run without a spec**, so on many repositories it will be
  silently inactive. Whether the resolution chain finds specs in practice is an
  open question to be measured, not assumed. It is deliberately not answered here.
- **`gh` is a dependency of the strongest link** in the chain. The fallbacks exist
  precisely because it often will not be there.

## Out of scope

The three smaller items ranked behind this one are separate, bounded changes and
are not part of this design: fixed-point validation with fail-fast before dispatch,
a named Fowler smell vocabulary in `craft` and `dry`, and a "skip what tooling
enforces" rule.
