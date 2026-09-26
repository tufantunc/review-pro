# 0011: Read repository rules from the merge base, and treat their text as data

Status: accepted
Date: 2026-09-27

## Context

Some of what a repository knows exists only because a maintainer wrote it down: "when the
verdict rule changes, update severity.md". Our own releases missed four such things and no
reviewer caught any, because each defect lived in a file the diff did not touch. A
pre-registered spike ([studies/2026-09-repo-rules-spike](../../../studies/2026-09-repo-rules-spike))
found that co-change rules caught 3 of 4 known misses when a trigger was followed by a
judgment, that 77% of raw triggers over 66 merged PRs were legitimate changes, and that the
judgment cleared all 8 legitimate triggers it saw. The design is in
[the spec](../../superpowers/specs/2026-09-27-repo-rules-design.md).

A rules file changes what a review checks, so who controls it at review time decides whether
it can be turned against the review.

## Decision

Triage reads `.review-pro/rules.md` from the merge base, never from the head, computes each
rule's trigger without judgment, and routes each triggered rule to an owner among the code
reviewers, which dispatches that owner. The rule's text reaches the owner as data: it names an
expectation and can do nothing else. Verification reads the rule at the merge base as well, so
the verifier cannot be handed the change's own edit of it. A finding resting on a rule is capped
at Medium before verification selects anything. Every matched rule is a row in the report, and a
rule nobody answered reads `not reported`.

Rejected: reading from the head. The cheapest way to disable a rule would be to delete it in
the change that breaks it.

Rejected: letting a rule declare its own severity. A file added at the base would set the
verdict, and one careless rule could block every change.

Rejected: printing triggers as alarms. Three triggers in four were legitimate in the spike.

Rejected: a new category root or a rules reviewer. Roots and the roster are frozen (v1.0,
ADR-0006, ADR-0007); a violation is filed under its owner's existing categories.

Rejected: judging rules whose expected files did change. It would catch a partial update, but
doubles the judgment for every rule already followed by habit.

## Consequences

A maintainer can write down what the code cannot show, and a change that breaks it is named in
the report with the file it left stale. A change to the rules file takes effect one change
later, which is the price of a review the change cannot edit. A repository without the file
behaves exactly as before.

Triage applies the globs itself, with no script, because skill-directory script paths are not
portable across the supported platforms (ADR-0001). A partial update to the right file is
invisible to a co-change rule. The one judgment error in the spike deferred to stale repository
documentation over the rule's own file list; the handling text now names that failure, and it
has not been re-measured.

Revisit the merge-base rule only if a review mode appears with no base (a first commit, an
orphan branch); revisit the cap if a larger corpus shows rule findings routinely deserve High
and the owners' own rubrics miss them.
