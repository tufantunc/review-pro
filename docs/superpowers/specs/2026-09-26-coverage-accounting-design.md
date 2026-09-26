# Design: coverage accounting for review-pro

**Status:** designed 2026-09-26 from the brief for roadmap item 1
([`docs/superpowers/plans/2026-09-26-ocr-lessons-roadmap.md`](../plans/2026-09-26-ocr-lessons-roadmap.md)).

## The gap

Triage hands every dispatched reviewer the full changed-file list, and reviewers
return only findings. "I examined this file and found nothing" and "I never opened
this file" produce the same empty output, so a report cannot show that a file was
skipped. alibaba/open-code-review (OCR, read at `486022d`) names this as the first
failure of skill-based review on large changesets. Its answer is a per-file checklist:
every file closes as reviewed or as skipped with a reason, and the report must carry
`total_files / reviewed_files / skipped_files / coverage_rate`
(`skills/open-code-review-delegate/SKILL.md`, Steps 4 and 6), with a separate pass per
file confirmed before the task ends (`internal/config/template/prompts/main_task_system.md`,
"Reply limit").

We borrow the discipline, not the template. OCR's model is one agent with a file list.
Ours is several specialists over the same list, so "was this file reviewed" has a
second dimension (by whom) that OCR does not have.

## What was measured first

A pre-registered spike ([`studies/2026-09-coverage-spike/`](../../../studies/2026-09-coverage-spike))
ran `correctness`, `craft` and `tests` on #74 (119 changed files, 102 of them study
data) with a temporary addendum asking each for the block specified below. Each
declaration was then checked against the subagent's transcript.

- 3 of 3 reviewers emitted the block. No file was left out of a declaration.
- 16 of 119 files were examined by at least one reviewer, 12 by all three.
- The 103 files nobody examined were 101 study data files and 2 design documents, each
  with a reason. No code, skill, test or validator file was skipped by all three.
- 0 of 42 "examined" declarations were false. Four "not examined" declarations named
  files the reviewer had only grepped, and said so: the error ran in the safe direction.
- No finding sat in a file its reviewer declared unexamined.

What this settles for the design: silent skipping of code did not occur on this diff,
so the signal's value here is making visible that 87% of a changed-file list was read by
nobody, which the #74 report never said. Declared skips concentrate in data and design
prose, where skipping is right, so they must not raise a warning. The declarations were
honest under the wording that ships, which is what the self-reported layer rests on,
and one run per reviewer is too little to drop the label. The block costs about one
line per changed file per reviewer, roughly 3k tokens on #74 against about 100k per
reviewer run.

## Decisions

1. **Two layers, labelled differently.** A deterministic layer from the dispatch plan
   (files sent to no reviewer) and a declared layer from the reviewers (files each one
   says it examined or did not). The first is computed from triage's own output and is
   not labelled self-reported. The second is always labelled self-reported and never
   uses the words verified, confirmed, complete or full.
2. **A file counts as examined when at least one code reviewer examined it.** The unit is
   the file, not the file per axis. The line says "by at least one reviewer" so it is
   not read as "by every axis".
3. **Coverage is a code-axis measure.** The spec reviewer does not emit the block and is
   not counted as a receiver.
4. **A missing report is never rendered as examined.** A reviewer with no block, or a
   block that leaves a file out, makes that file `not reported` unless another reviewer
   examined it, and the reviewer is named.
5. **Declared skips are listed, not warned about.** Only the deterministic gap gets a
   caveat block. A reason is the reviewer's own words, and the reader judges it.
6. **Trivial diffs print no self-reported line.** The deterministic caveat still prints.
7. **Review-level only.** The coverage signal never changes a finding, a severity, or
   the verdict, the same rule as the out-of-diff check.

Rejected:

- **A file-by-axis matrix** ("security did not look at README.md"). Most cells are
  irrelevant by design: triage sends every reviewer every file, and an a11y reviewer
  skipping a SQL migration is correct. A matrix would be mostly noise, and its size
  grows with reviewers times files.
- **Counting the spec reviewer.** Reading a file to match it against a requirement is
  not reading it for defects. Counting it would let a file no code reviewer opened show
  as examined whenever a spec resolved.
- **A coverage threshold that warns** (for example "under 80% examined"). The measurement
  shows declared skips concentrate in data and design documents, where skipping is
  right. A percentage cannot tell those from a skipped handler, and a warning that fires
  on every large docs-heavy PR trains the reader to ignore it.
- **Checking declarations against tool transcripts.** Synthesis has no access to a
  subagent's tool calls on any supported platform. The measurement did this by hand, once;
  it is not something the pipeline can do.
- **Making a missing block fail the review.** Coverage is a signal about the review, not
  a finding about the code. A blocking missing block would let a reviewer contract
  violation hold a merge on its own.
- **Re-deriving file classes in synthesis** (to exempt docs by extension). Triage owns
  classification, and the existing rule forbids Stage 3 from re-deriving `diff_class`.
  Grouping by path, below, keeps large skipped sets readable without it.

## The reviewer block

Every code reviewer appends one block after its findings or its none-line, always,
including when it has findings:

```
## Files examined
examined: [<path>, ...]
not_examined:
  - file: <path>
    reason: <why, one line>
```

- Every file under `### Changed file contents` appears **exactly once**, in one of the
  two lists. An empty list is written `[]`.
- A file counts as examined only if the reviewer read its diff or its contents while
  applying its rubric. A file it knows only from the list or from a `--stat` is
  not examined.
- Any reason is acceptable: outside this reviewer's concern, generated data, not reached.
  A missing entry is not.
- An accurate list with gaps is the correct answer; a complete-looking list that
  overstates what was read is the wrong one.
- The block is not a finding. It never replaces the none-line, and the none-line never
  replaces it. It sits beside `## Premise verification` for the three reviewers that
  carry that block.

This is an optional, additive output: a reviewer from an older install that does not
emit it is handled by the `not reported` rule, and no existing field changes meaning.

## Synthesis: the coverage computation

Inputs, all already produced by triage except the last: `changed_files`, `diff_class`,
each dispatched reviewer's `context.changed_files` from the dispatch plan, and each code
reviewer's `## Files examined` block. The receivers of a file are the dispatched code
reviewers whose `context.changed_files` contains it.

Each file in `changed_files` lands in exactly one state, checked in this order:

| State | Condition | Source |
|---|---|---|
| sent to no reviewer | no receiver | dispatch plan |
| examined | at least one receiver lists it under `examined`, or filed a finding in it | reviewers |
| not examined | every receiver lists it under `not_examined` | reviewers |
| not reported | anything else: a receiver gave no entry for it | reviewers |

A finding filed in a file counts as examined for that reviewer whatever its block
says: the finding is better evidence of reading than the declaration. When the same
reviewer also listed that file under `not_examined`, the report names the contradiction.
A file a reviewer lists in both of its own lists has no usable entry from that reviewer.

## Report

The coverage line sits after the Spec line and before the Verification line. The
header lines follow the pipeline: what the review was measured against (Spec), what it
read (Coverage), what it re-checked (Verification), then the caveats computed over the
findings (out-of-diff, External premises).

```
## Verdict: REQUEST CHANGES (code)

Spec: skipped, no spec found.

Coverage (self-reported): 16 of 119 changed files examined by at least one reviewer, 103 not examined.
  not examined: studies/2026-09-refuting-verifier/ (101 files; study data; raw study output; study item)
  not examined: docs/superpowers/plans/2026-09-24-refuting-verifier.md (correctness: implementation plan prose, only grepped; craft: plan doc, no code structure; tests: design doc, not read)
  not examined: docs/superpowers/specs/2026-09-24-refuting-verifier-design.md (correctness: design prose; craft: design spec prose; tests: design doc, not read)

Verification: ...
```

Rules:

- The count line always states `<e> of <n> changed files examined by at least one
  reviewer`, then only the non-zero states among `not examined`, `not reported` and
  `sent to no reviewer`.
- One detail line per file in each non-empty state, with each receiver's reason for
  `not examined` and the silent receivers for `not reported`. When a state holds more
  than 10 files, each directory (first two path segments) holding more than 3 of them
  collapses into one line with a count and at most three distinct reasons; the rest stay
  listed by name. On #74 that turns 103 lines into 3.
- `no Files examined block from: <reviewers>` whenever any receiver returned no block,
  even when other reviewers examined every file it received. A reviewer contract
  violation must not be the quietest line in the report, the same rule as External
  premises' `not reported`.
- `contradiction: <reviewer> filed a finding in <file> and declared it not examined`
  whenever that happens.
- Files sent to no reviewer get a caveat block under the coverage line, printed on every
  diff class:

  ```
  > 2 changed files were sent to no reviewer, so nothing reviewed them: a.ts, b.ts.
  ```

  Under today's context policy this is expected to be empty. It is the only place that
  would notice triage or the orchestrator narrowing what a reviewer receives.
- `diff_class: trivial`: omit the coverage line and its detail lines. The whole change
  fits on a screen, and a self-reported line there adds nothing but length. The caveat
  above still prints.
- If `changed_files` or the dispatch plan's per-reviewer lists are missing from the input,
  print `Coverage: not computed, <what> missing from the input.` and do not guess.

## Keeping the deterministic layer honest

The deterministic layer compares triage's `changed_files` with the per-reviewer lists in
the same plan. It measures what reviewers received only if the orchestrator hands each
reviewer exactly its `context.changed_files`. Today the orchestrator's step 3 says "the
changed files relevant to this reviewer", which invites a silent narrowing the plan
would never show. That line changes to "the files in this reviewer's
`context.changed_files`", which is what the context policy already requires.

## Packaging

| Surface | Change |
|---|---|
| 12 code reviewer bodies | mandate line, Work step 4, a `## Files examined` section, Final reminder |
| `spec-reviewer.md` | none (not a receiver) |
| `core/shared/output-schema.md` | the block and its rules, for rubric readers and the inline path |
| `review-pro/SKILL.md` | step 3 hands `context.changed_files`, collects the block, inline reviewers emit it; synthesis gets the per-reviewer lists; Output template line |
| `review-pro-synthesize/SKILL.md` | `## Coverage` section, a Coverage step, Output template line |
| `review-pro-synthesize-subagent.md` | the two new inputs |
| `review-pro-triage/SKILL.md` | `context.changed_files` is what Stage 3 compares against |
| Rubrics (`core/skills/<reviewer>/SKILL.md`) | none: they point at `shared/output-schema.md`, and the inline path takes the block from the orchestrator skill, which inlines the format (ADR-0001) |
| Adapters | none: opencode and Cursor read `core/agents/` verbatim; Codex embeds each body verbatim as `developer_instructions`, so the new text must carry no `"""` and no backslash (TOML basic string) |
| README, `docs/llms.txt`, `cli/README.md` | example report and one sentence each |
| ADR-0010 | the decision and the rejected alternatives |

Both paths behave the same: a subagent reviewer takes the rule from its body; an inline
reviewer takes it from the orchestrator skill; subagent synthesis takes the inputs from
its body and the rule from the synthesis skill; inline synthesis takes both from the
skills.

## Validator

Every check has its own mutation test in `scripts/validate.test.sh`:

- Each code reviewer body (every `*-reviewer.md` whose `loads_skill` is not `spec`)
  carries the `## Files examined` heading, the exactly-once rule and the overstating
  rule, and names the block inside its `## Final reminder`, which is the terminal
  restatement a reviewer obeys.
- `core/shared/output-schema.md` carries the block and the exactly-once rule.
- The synthesis skill has a `## Coverage` section carrying the not-reported rule, the
  no-effect rule, the spec exclusion, the contradiction line and the trivial rule, and
  its Output template orders Spec, Coverage, Verification.
- The orchestrator hands `context.changed_files`, carries the block for inline reviewers,
  and its Output template carries the coverage line.
- The synthesis subagent body names both new inputs.
- Triage states that Stage 3 compares against `context.changed_files`.

## Room for roadmap item 2

Item 2 will check each finding's `evidence` against the file at `file:line` and correct
or mark the line. Coverage keys on `file` only and never on `line`, so relocating a line
within a file cannot move a finding between coverage states. One rule is likely to need
an amendment then: "a finding filed in a file counts as examined". If item 2 marks a
finding whose excerpt exists nowhere in its file, that finding is weak evidence the
reviewer read the file, and item 2 may exclude it. The rule is one sentence in the
Coverage section so the amendment stays local.

## Known limits

- The declared layer is a statement, not evidence. The measurement found it accurate in
  one run per reviewer; one model family did every role, and nothing in the pipeline
  can check it later.
- "Examined by at least one reviewer" cannot tell a file that the owning axis read from
  one only an unrelated axis read. Detecting that needs per-file relevance from triage,
  which the plan does not carry.
- The layer adds about one path per changed file to each code reviewer's output.
