# 0007: A reviewer's closed category list must cover everything that reviewer flags

Status: accepted
Date: 2026-08-31

## Context

[ADR-0006](0006-one-closed-subcategory-list-per-reviewer.md) collapsed each reviewer's two subcategory lists into one and declared it **closed**: a finding outside the list means the concern belongs to another reviewer. Before that, the rubrics said "Use category roots **like** ...", so the list was a set of examples and a reviewer could coin a name when the listed ones did not fit.

Closing the list removed that escape hatch, and three flags were left with nowhere legal to go. Each rubric raises the concern in its `## What this reviewer flags` section while its own closed list refuses the label:

| Reviewer | Flag | Why no listed category holds it |
|---|---|---|
| `security` | Deserialization & eval | none of authn, authz, crypto, csrf, feature-gate, injection, redirect, secrets, ssrf covers unsafe deserialization or `eval` on user input |
| `api-contract` | Lockfile drift | none of breaking, schema, serialization, types covers a resolved lockfile contradicting the manifest |
| `ai-antipatterns` | Unreviewed dependency-bump surface | `needless-dep` is adjacent but means an unnecessary dependency, not an unexamined lockfile diff |

The last two were added one release before this, in the calibration rules borrowed from `addyosmani/agent-skills`, and shipped without categories. That was survivable while the lists were open and became a contradiction the moment ADR-0006 closed them. So this is ADR-0006's own consequence, not a legacy defect it inherited.

Measured before deciding, because one missing category and a systemic gap deserve different fixes: all thirteen reviewers were mapped flag by flag against their closed lists. A crude name match suggested nineteen gaps; hand-checking reduced that to three. The other sixteen are flags whose concept a listed category plainly holds under a different name, such as `craft`'s "1k-line rule" under `craft.size` or `ai-antipatterns`' "Hallucinated APIs" under `hallucination`.

## Decision

The closed list is total over the flags list: **whatever a rubric flags, that rubric can label.** Adding a flag without adding or identifying its category leaves the rubric contradicting itself, and a reviewer facing that contradiction has to either break the closed-list rule or file the finding somewhere it does not belong.

Three categories are added, none of which changes a category **root** or the reviewer roster: `security.deserialization`, `api-contract.lockfile`, `ai-antipatterns.unreviewed-bump`.

Rejected: annotating every flag bullet with its category inline and guarding that mechanically. It would close the class rather than the instances, and it is the right answer if this recurs, but it means editing eighty-five bullets across thirteen rubrics and it makes every rubric longer to serve a gap that appears a few times a year, at the moment a flag is added, which is exactly when this ADR gets read.

Rejected: relaxing the closed-list rule so a flag may map to an existing category by judgment. Weakening ADR-0006's central claim one release after recording it would defeat the point of recording it.

## Consequences

A flag-to-category mapping remains a judgment for the sixteen cases where a listed category holds the concept under another name, and nothing mechanically enforces that a new flag arrives with a category. The guard added by ADR-0006 catches a *body* naming a category its rubric omits, and the audit catches a `category:` or `overlap_hints:` line outside the closed list, but neither can tell that a prose flag has no label at all, because the mapping is semantic.

So the enforcement here is a rule and a habit, not a check. When adding a flag: either name the category it files under, or add one. If this is violated again, the inline-annotation guard rejected above becomes the correct fix, and the reason it was rejected once is recorded here so the argument does not have to be rebuilt.

One incidental cleanup: `security.deserialization` had been serving as the "not in the closed list" example in meta-test Case AJ. It is now a real category, so the example moved to `security.notacategory`, a name reserved for being illegal.
