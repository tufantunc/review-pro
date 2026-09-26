# 0010: Report which files the review read, and label the reviewers' part self-reported

Status: accepted
Date: 2026-09-26

## Context

Every dispatched reviewer receives the whole changed-file list and returns only findings,
so "examined and found nothing" and "never opened" produce the same empty output.
alibaba/open-code-review names silent skipping on large changesets as the first failure of
skill-based review, and answers it with a per-file checklist that must close every file
as reviewed or skipped with a reason. A pre-registered spike on #74
([studies/2026-09-coverage-spike](../../../studies/2026-09-coverage-spike)) found that three
reviewers left 103 of 119 changed files unread, all study data or design prose, each with a
reason, and that none of their 42 "examined" declarations was false against the transcripts.
The #74 report said nothing about any of it. The design is in
[the spec](../../superpowers/specs/2026-09-26-coverage-accounting-design.md).

## Decision

Every code reviewer appends a `## Files examined` block accounting for each file it received
exactly once, and synthesis prints one coverage line between Spec and Verification:
the reviewers' declarations, always labelled self-reported, counted per file as "examined by
at least one reviewer", plus a caveat, not labelled self-reported, for any file the dispatch
plan sent to no reviewer. A missing block renders as `not reported`, never as examined. The
signal never changes a finding, a severity, or the verdict.

Rejected: a file-by-axis matrix. Triage sends every reviewer every file, so most cells are
correct skips (a11y on a migration), and a matrix grows with reviewers times files.

Rejected: counting the spec reviewer. It reads a file against a requirement, not for defects,
and would make a file no code reviewer opened show as examined.

Rejected: a coverage threshold that warns. Declared skips concentrate in data and design prose,
where skipping is right; a percentage cannot tell those from a skipped handler, and a warning
that fires on every large docs-heavy PR teaches the reader to skip it.

Rejected: checking declarations against tool transcripts. No supported platform gives
synthesis a subagent's tool calls; the spike did it by hand, once.

Rejected: failing the review when a block is missing. A reviewer contract violation would then
hold a merge on its own; the report names the silent reviewer instead.

## Consequences

A reader can now see which files nobody read and why, and a reviewer that returns nothing is
named instead of reading as a clean pass. Every code reviewer's output grows by about one line
per changed file, roughly 3k tokens per reviewer on a 119-file diff against about 100k per run.

The declared layer is a statement the pipeline can never check. The spike found it honest
under the shipped wording in one run per reviewer, with one model family in every role; the
label stays because three clean runs are not evidence it stays clean. "Examined by at least one
reviewer" cannot tell a file the owning axis read from one only an unrelated axis read; that
would need per-file relevance from triage, which the plan does not carry.

Revisit the label if a larger sample, checked against transcripts, shows declarations stay
accurate across models and diff shapes. Revisit the axis rule if triage starts recording why
each reviewer was dispatched per file. Roadmap item 2 (quote-anchored locations) may exclude a
finding whose excerpt exists nowhere in its file from counting as evidence the file was read.
