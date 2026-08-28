# 0006: Keep one closed subcategory list per reviewer, in the rubric

Status: accepted
Date: 2026-08-27

## Context

[#44](https://github.com/tufantunc/review-pro/issues/44) measured that 12 of 13 reviewers listed different finding subcategories in their rubric than in their agent body. Some divergence was harmless, the body simply listing more. Some was two names for one concept: `error-handling` against `error-path`, `canonical-reuse` against `canonical-helper`, `api-design` against `api-shape`, `assertions` against `assertion`. Whichever copy the running path happened to load decided the label, so the same defect could be reported under either name and no reader could tell.

Two facts settled the decision, and both were verified rather than assumed.

An agent body states that its one declared skill **is auto-loaded into its context**. So a subagent sees its rubric as well as its body, and the rubric is also what the documented inline path applies. The rubric therefore reaches both paths on its own, and [ADR-0001](0001-inline-the-schema-into-agent-bodies.md)'s duplication rule does not apply here: that rule exists because bodies cannot reach `core/shared/`, not because they cannot reach their own rubric.

The rubrics' own `## What this reviewer flags` prose describes concepts their category lists omit, and the bodies carry those names. The `backend` rubric flags "API shape" while listing `api-design`; the `correctness` rubric flags "Error-path gaps" while listing `error-handling`; the `security` rubric flags authn, crypto, CSRF, SSRF and open redirect while listing three categories against the body's nine. The bodies were the maintained inventory and the rubric lists had gone stale.

## Decision

One list per reviewer, in the rubric's `## Output schema`, declared closed: a finding outside it means the concern belongs to another reviewer or the roster needs an ADR. Agent bodies stop enumerating and point at their skill. The unified content is the union of both lists, with each naming conflict decided by the name the rubric's own flags prose supports: four went to the body's name, one (`concurrency` over `race`) to the rubric's.

A validator guard enforces the subset rule rather than the absence of enumeration: every `<root>.<sub>` a body still names must exist in that root's rubric. Re-adding a list is allowed; contradicting the rubric is not.

Rejected: aligning two lists and locking them with a parity check. Thirteen pairs of synchronised lists are more fragile than one list, and pairwise synchronisation is the mechanism that produced #44 in the first place.

## Consequences

The divergence class cannot recur, because there is no second list to drift. Reports use one label per defect regardless of which path ran, which is a precondition for two things this project already depends on: the pilot study counts category frequency to support its thesis, and the README promises calibration from reported false positives. Both silently split their counts while one concept had two names.

The rubric is now the only place a category is declared, so a new subcategory is one edit rather than two, and forgetting the body is no longer possible.

Two gaps were found and deliberately left out of scope. The `security` rubric flags "Deserialization & eval" with no category in either list, which is a missing category rather than a divergence. And `core/shared/output-schema.md` illustrated `overlap_hints` with `backend.authz`, a category that never existed in any list; that example was corrected here because it would have taught the wrong shape, but auditing every example against every closed list is separate work.
