# 0001: Inline the output schema and shared rules into every agent body

Status: accepted
Date: 2026-08-18 (recorded 2026-08-27)

## Context

Reviewer subagents load their own agent body and their declared skill, and nothing else. They do not load `core/shared/`. Every release before v0.6.0 shipped rubrics whose `shared/<file>.md` pointers dangled in a real install, found by dogfooding and fixed in [#25](https://github.com/tufantunc/review-pro/issues/25): the CLI now installs `shared/` beside `skills/`. That fixed the rubric path. The agent-body path has no such fix available: a body cannot Read a file relative to another install directory across every platform review-pro supports.

## Decision

Any rule a running subagent must obey is written into the agent body itself, even when the rubric states the same rule. The rubric may point at `shared/`; the body inlines what it needs. The validator holds the two copies together with load-bearing greps on both.

Rejected: a body that Reads `shared/` at run time (path is not portable across harnesses); a single-source body generated at build time from the rubric (a build step for markdown was judged heavier than the duplication until the duplication demonstrably drifts).

## Consequences

Rules exist twice, and drift is real: [#44](https://github.com/tufantunc/review-pro/issues/44) measures 12 of 13 rubric/body pairs already disagreeing on finding subcategories. The guards catch deletion, not divergence. Revisit if #44's resolution produces a single-source mechanism that survives the constraint above; until then, every new rule lands in both copies by policy.
