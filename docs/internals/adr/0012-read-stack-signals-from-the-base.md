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
tree. The base is the branch `refs/heads/main` (or `master`), and a base named in the argument
is `refs/heads/<name>` or `refs/remotes/<name>`, refused when a tag shares the name; each is
resolved to a sha with exact lookups (`git show-ref --verify`), and a sha must be full. git's
name lookup prefers a tag named `main` or `origin/main`, and falls through from `refs/heads/x` to a
tag named `refs/heads/x` when that branch is missing, so a change could push a tag at its own
commit and become its own merge base. That protects ADR-0011's rules too. Triage emits `stack_signals` in two layers: what the change commits
(`added`, `removed`, `changed`, from the merge base to `HEAD`) and what is only in the working tree
(`uncommitted`), plus what the base branch changed after the branch point (`behind`), since the
author chooses the branch point and the review applies the older pack. Synthesis prints one line per entry, saying the review used the merge base's
version, and prints them on the no-reviewer path too. A pack new in this change applies from the
next change, like a new rules file. A committed pack edit dispatches `security` and the pack's own
reviewer: the merge base keeps a change from weakening its own review, but a merged edit is what
every later review applies. Every reviewer body, and the orchestrator's `### Stack signals`
section for bodies installed before this release, says that everything under `### Changed file
contents` is under review, never a signal, whatever its path or headings. The verifier reads
every pack at the merge base, whether a finding cites it or a search finds it, except the pack a
finding is about, which is the code under review.

Rejected: applying the head's packs on a first install, when the merge base has none. That is
the attack itself: a change adds a pack directory and its text reaches its own reviewer.

Rejected: applying a head pack when it is byte-identical to the catalog pack the CLI ships. It
would make a first install work at once, but the catalog lives in the npm package, not in the
installed skill directories, so no reviewer can reach it portably (ADR-0001).

Rejected: applying the union of both versions. An added line saying a pattern is safe would
still reach the reviewer.

Rejected: one comparison of the merge base with the working tree. It reported an uncommitted
`npx review-pro update` as part of the change (round 2 of this branch's review).

Rejected: reading packs from the base branch's tip instead of the merge base. It would close the
branch-point choice outright, but it splits packs from rules (ADR-0011) and from the diff the
review reads; the `behind` line names the gap instead.

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

`.review-pro/rules.md` has the same branch-point property and no `behind` line yet; ADR-0011's
report says only whether the change edited it. Each of four rounds of this branch's own review
found that a fix had moved a problem rather than removed it (the base ref three times: to a tag,
to the argument, to git's name lookup; the uncommitted state; the verifier's reading of packs), so
a fifth reader will likely find more. The known limit no pin closes: a qualifier added in place to a pinned line still passes.

## Amendment, 2026-09-28 (v1.5.0 release review)

If `git merge-base` prints nothing, the review stops instead of reading packs: `git show` with an
empty revision reads the index, the change's own copy. The orchestrator also sends
`### Changed file contents` as the last section of every reviewer prompt, because the data line
this ADR introduced makes everything under that heading the change; the sections other PRs added
after it would otherwise have been read as change content. See ADR-0011's amendment for the rest.
