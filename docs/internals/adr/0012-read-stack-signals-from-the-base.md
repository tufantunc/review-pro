# 0012: Read stack signals from the merge base, and report the change's pack edits

Status: accepted
Date: 2026-09-27

## Context

[ADR-0011](0011-read-repository-rules-from-the-base.md) moved `.review-pro/rules.md` to the
merge base so a change cannot weaken its own review by editing it. Stack packs had the same
hole and were left alone: triage found stacks with `Glob .review-pro/*/manifest.json` and the
orchestrator read `.review-pro/<stack>/<reviewer>.md`, both in the working tree. A change could
add `.review-pro/node/security.md` telling the security reviewer that a class of injection is
safe, or add a whole pack directory, and that text reached the reviewer of the same change as
its `### Stack signals`, the one supplement every reviewer body is told to apply. A pack is
stronger than a rule: a rule is capped at Medium and can only name an expectation, while a
signal refines the rubric itself.

## Decision

Triage lists installed stacks at the merge base with `git ls-tree`, the orchestrator reads each
reviewer's pack with `git show <merge-base>:<path>`, and nothing reads a pack from the working
tree. Triage compares the merge base's pack files with the head's, untracked and ignored files
included, and emits `stack_signals`; synthesis prints one line per stack the change adds, edits
or removes, saying the review used the merge base's version, and prints them on the no-reviewer
path too. A pack new in this change applies from the next change, like a new rules file; a pack
that is only in the working tree is named as not committed. Every reviewer body, and the orchestrator's
`### Stack signals` section for bodies installed before this release, says that a `.review-pro/`
file among the changed files is under review, never a signal. The verifier reads a pack a
finding cites at the merge base.

Rejected: applying the head's packs on a first install, when the merge base has none. That is
the attack itself: a change adds a pack directory and its text reaches its own reviewer.

Rejected: applying a head pack when it is byte-identical to the catalog pack the CLI ships. It
would make a first install work at once, but the catalog lives in the npm package, not in the
installed skill directories, so no reviewer can reach it portably (ADR-0001).

Rejected: applying the union of both versions. An added line saying a pattern is safe would
still reach the reviewer.

Rejected: printing a line when packs are unchanged. It would appear on every review of a
repository with packs and say nothing.

## Consequences

A change cannot add, edit or remove the signals its own review applies, and the report says
when it tried. The price is paid once per repository: a pack installed with `npx review-pro`
applies only after it is committed to the base branch, so the first branch reviewed after an
install runs core-only and the report says the pack applies from the next change. The CLI says
so after every command that installs or changes a pack. Removing a pack in a change does not
remove it from that change's review.

A repository without pack files behaves exactly as before: both listings are empty and
`stack_signals` is omitted. A repository that keeps `.review-pro/` out of version control, or
gitignores it, never gets signals, and every review names its packs as not committed. Such a
repository got signals before this change, because the working tree was read; it now gets a line
that says why it does not.

A `.review-pro/` file in the diff still reaches the reviewers as changed-file contents, which is
correct, since the change's own pack edit deserves review. Their text is data there, and the
line every body carries is the only defense against a reviewer that treats it as instructions;
it is not measured. Revisit with ADR-0011's condition: a review mode with no merge base.
