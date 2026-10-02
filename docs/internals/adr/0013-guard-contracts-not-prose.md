# 0013: Guard the contracts between files, not the prose of each rule

Status: accepted
Date: 2026-10-02

## Context

On main at v1.5.1, `scripts/validate.sh` and the three files it sources held 274 check sites
(each `add_error`, each call of a pin helper, each Python finding counted once). 136 of them did
one thing: confirm that a sentence or phrase was still in a file. `validate.sh` was 1016 lines,
over the craft rubric's 1000-line rule, and `validate.test.sh` was 1915 lines with 448 assertions,
most of them one mutation per pinned sentence.

The pins did not converge. Coverage accounting (#78) found in its second dogfooding round that
three of the first round's guard fixes had only moved the hole: the new phrase also sat on another
line, so deleting the protected line still passed. Closing three Lows from the v1.5.0 release
review (#95) added 24 `add_error` lines and 38 mutation lines, and new prose there satisfied an
older file-wide pin (`External premises`) the same way. Every round found another unpinned clause.
This is the pattern of the security clearance lists in #71, which drew a new finding on every pass.

The pins also guarded the wrong thing. A pin fails when a sentence is deleted and passes when it
is weakened: qualifying a pinned line in place ("except trivial") kept every check green (#78).
What a rule means was never protected; only that its words were still on the page.

## Decision

The validator holds what a consumer reads, and only that. The question for every check is: if this
text changes, does a consumer break? A consumer is a parser, a copy of the same text in another
file, a key or line that synthesis reads, or the release process. Five kinds of check pass that
test and stay: structure (frontmatter, required sections, manifest and roster integrity,
cross-references, version fields, the published count, closed category lists); canonical copies
(ADR-0001); order and position (the report header, the prompt's last section, the rules cap before
verification); the formats a consumer reads (none-lines, verdict tables, plan keys, the canonical
coverage line); and the validator's own mechanics. A check whose only job is to show that a rule is
still written is removed, with its mutation tests. Removing or softening a rule is caught by
review instead: rule R9 in `.review-pro/rules.md` requires a change that does it to say so and why.

Rejected: keep pinning every sentence. It does not converge, it cannot see a weakened rule, and it
had already pushed the validator past the size the rubric allows.

Rejected: stop adding pins but keep the existing ones. The 136 would still demand a validator edit
and a mutation test for every edit to a pinned sentence, and would still pass a weakened rule. Two
standards in one file invite the next pin "for symmetry".

Rejected: remove every content check. The copy-drift guards, the report and prompt order, and the
formats synthesis parses do break silently when they change, and the validator is the only thing
that sees them.

## Consequences

An edit to a sentence in `core/` no longer needs a matching validator edit. The check sites drop
from 274 to 143, `validate.sh` from 1016 lines to 893, and the suite from 448 assertions to 263.

Deleting or softening a rule's sentence no longer fails CI. A dropped `must`, a `never` turned
into `usually`, or a guarantee qualified away passes the validator, and the only defence is review:
R9 asks the change to state it, and its owner judges whether it did. That defence is weaker than a
red build in two ways. A review can miss it. And R9 is read from the merge base, so it applies from
the change after the one that adds it, and its owner does not receive the PR body in its prompt: it
has to read the commit messages or the PR itself to judge the rule.

Seventeen kept checks sit at the edge: each looks at a sentence, but it is also the only guard of a
section heading, a plan key or a line that another file reads. They are kept, and the PR that made
this change lists them, so a later change can turn each into a plain structural check.

This forecloses adding a sentence pin. A new check names the consumer it protects. Revisit if a
removed or softened rule ships in a release and review, R9 included, did not catch it: that would
argue for a check on what a rule means, not for returning to pins on what it says.
