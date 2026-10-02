# 0013: Guard the contracts between files, not the prose of each rule

Status: accepted
Date: 2026-10-02

## Context

On main at v1.5.1, `scripts/validate.sh` and the three files it sources held 274 check sites
(each `add_error`, each call of a pin helper, each Python finding counted once). `validate.sh` was
1016 lines, over the craft rubric's 1000-line rule, and `validate.test.sh` was 1915 lines with 448
assertions, most of them one mutation per pinned sentence. Many of the checks did one thing:
confirm that a sentence or phrase was still in a file.

The pins did not converge. Coverage accounting (#78) found in its second dogfooding round that
three of the first round's guard fixes had only moved the hole: the new phrase also sat on another
line, so deleting the protected line still passed. Closing three Lows from the v1.5.0 release
review (#95) added 24 `add_error` lines and 38 mutation lines, and new prose there satisfied an
older file-wide pin (`External premises`) the same way. Every round found another unpinned clause.
This is the pattern of the security clearance lists in #71, which drew a new finding on every pass.

The pins also guarded the wrong thing. A pin fails when a sentence is deleted and passes when it
is qualified in place, a limit #78 recorded: what a rule means was never protected, only that its
words were still on the page.

## Decision

The validator holds what a consumer reads, and only that. The question for every check is: if this
text changes, does a consumer break? A consumer is a parser, a copy of the same text in another
file, a key or line that another stage reads, or the release process. Five kinds of check pass that
test and stay: structure (frontmatter, required sections, manifest and roster integrity,
cross-references, version fields, the published count, closed category lists); canonical copies
(ADR-0001's rubric and body pairs, the blocks held once in the validator, rules another file
declares it repeats); order and position (the report header, the prompt's last section, the rules
cap before verification); the formats a consumer reads (none-lines, verdict tables and labels, plan
keys and the lines printed for them); and the validator's own mechanics. A check whose only job is
to show that a rule is still there is removed, with its mutation tests, when the rule is written
in one place or only paraphrased elsewhere with no file saying the two must agree.
Removing or softening such a rule is left to review: rule R9 in `.review-pro/rules.md` asks a
change that does it to say so and why.

Rejected: keep pinning every sentence. It does not converge, it cannot see a weakened rule, and it
had already pushed the validator past the size the rubric allows.

Rejected: stop adding pins but keep the existing ones. The prose pins would still demand a
validator edit and a mutation test for every edit to a pinned sentence, and would still pass a
weakened rule. Two standards in one file invite the next pin "for symmetry".

Rejected: remove every content check. The copy-drift guards, the report and prompt order, and the
formats another stage parses do break silently when they change, and the validator is the only
thing that sees them.

## Consequences

An edit to a sentence that lives in one file of `core/` no longer needs a matching validator edit.
89 of the 274 check sites go, `validate.sh` drops from 1016 lines to 919, and the suite from 448
assertions to 334.

Deleting or softening such a sentence no longer fails CI. A dropped `must`, a `never` turned into
`usually`, or a guarantee qualified away passes the validator. That includes rules that carry
earlier decisions where they are written once: the verifier's cite-or-stand, no-memory,
one-finding, author's-claim and harm-not-title rules and synthesis's agreement rule (ADR-0009);
triage and the orchestrator reading packs and rules at the merge base and never the working tree,
the uncommitted rules and pack states, the `behind` pack state, the dispatch a pack or rules edit
compels, and the rules cap's handling of a finding located in `rules.md` or merged by dedup
(ADR-0011, ADR-0012). A change that, say, has triage glob packs
in the working tree again now passes CI and is caught only if review catches it.

That defence is weaker than a red build. A review can miss it. R9 is read from the merge base, so
it applies from the change after the one that adds it. And its owner, `correctness`, does not
receive the PR body in its prompt: it has to read the commit messages or the PR itself, which its
handling text (decide a rule in the matched files, cite a path or a diff line) does not invite,
and a verifier treats the change description as the author's claim. Passing the change
description to rule owners would close that gap; it is a change to `core/`, outside this one.

Fifty-nine kept checks sit at the edge, listed in the PR that made this change: each looks at a
sentence but is the only guard of a section heading, a plan key, a line another file reads, or a
rule another file repeats. Forty-two of them were first removed and were restored when that PR's
own review found the consumer each one guards. They stay pins, not identity checks, so they catch
a deleted copy and not a reworded one; a later change can turn each into a structural or
canonical-text check. Two of them, the security rubric's calibration headings, have no consumer
and are kept only because they are section checks.

This forecloses adding a sentence pin. A new check names the consumer it protects. Revisit if a
removed or softened rule ships in a release and review, R9 included, did not catch it: that would
argue for a check on what a rule means, not for returning to pins on what it says.
