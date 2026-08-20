# Context-gathering policy (shared)

Baseline for every reviewer: the **diff** + **full contents of changed files**.

Triage adds scoped extra context per reviewer so each subagent gets what it needs instead of the whole repo:

| Reviewer | Extra scoped context |
|---|---|
| security | callers/callees of changed security-relevant code; related tests |
| correctness | consumers of changed functions; related error paths; in-repo traces of any env var / flag / config key the change reads (definition, other read sites, CI workflows, deployment manifests, Dockerfiles, `.env` examples, config schemas) |
| craft / ai-antipatterns | neighboring module code; existing conventions & helpers (repo search) |
| dry | repo-wide symbol & pattern search for duplicates / existing helpers |
| db | migration history; schema definitions |
| api-contract | consumers of changed APIs (frontend calls, other services) |
| tests | the production code under test |
| spec | the resolved spec text (issue body, PR body, or file), passed as `### Spec text`; no repo-wide search |
| performance | query definitions; hot-path / render files |
| frontend / a11y | design-system tokens; shared UI primitives |

The `spec` row is the only one whose extra context is a document rather than code, and in the `issue` and `pr-body` cases it comes from outside the repository entirely. That asymmetry is the point of the axis, and it is why its findings are excluded from the out-of-diff evidence check in Stage 3.

Principle: scoped, not whole-repo. Only `dry`, `craft`, `ai-antipatterns`, and — for config-key traces only — `correctness` ever do repo-wide search, and only for symbols/patterns relevant to the diff.
