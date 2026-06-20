# Context-gathering policy (shared)

Baseline for every reviewer: the **diff** + **full contents of changed files**.

Triage adds scoped extra context per reviewer so each subagent gets what it needs instead of the whole repo:

| Reviewer | Extra scoped context |
|---|---|
| security | callers/callees of changed security-relevant code; related tests |
| correctness | consumers of changed functions; related error paths |
| craft / ai-antipatterns | neighboring module code; existing conventions & helpers (repo search) |
| dry | repo-wide symbol & pattern search for duplicates / existing helpers |
| db | migration history; schema definitions |
| api-contract | consumers of changed APIs (frontend calls, other services) |
| tests | the production code under test |
| performance | query definitions; hot-path / render files |
| frontend / a11y | design-system tokens; shared UI primitives |

Principle: scoped, not whole-repo. Only `dry`, `craft`, and `ai-antipatterns` ever do repo-wide search, and only for symbols/patterns relevant to the diff.
