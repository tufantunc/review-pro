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

## Verifying a premise that points outside the repo

When a change's rationale cites a specific external artifact, verify it in this order
and stop at the first channel that settles it:

1. **The locally resolved dependency source.** `node_modules`, `~/.nuget/packages`,
   `~/.cargo/registry`, `vendor/`. Offline, deterministic, and the one place where "at
   the pinned version" is literally true, because it is what the build resolved to.
2. **Lockfile and manifest**, to establish the version the claim must hold at.
3. **The network.** Upstream issue, PR, changelog, release notes.
4. Nothing.

Prefer the first channel even when the third looks easier. In the pilot that motivated
this rule, both halves of the centerpiece finding were visible in the installed package
source, and the one claim that went unsettled was blocked by the package being absent
from the local cache rather than by any lack of network.

Record **which channel settled** the premise, not merely the outcome. A network answer
is not reproducible: the same diff reviewed tomorrow can reach a different conclusion,
and a reader who cannot tell a durable verification from a perishable one cannot judge
either.
