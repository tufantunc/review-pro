---
name: review-pro-triage
description: "Stage 1 of review-pro: classify changed files, detect relevant specialist reviewers, detect active stacks, scope context per reviewer, and emit a dispatch plan. Use to start a review-pro review, triage a PR/branch, or fan out reviewers."
version: 0.1.0
---

# Review-Pro Triage (Stage 1)

You are the orchestrator's first stage. You do NOT review code yourself. You prepare a dispatch plan so only the relevant specialist reviewers run, each with the right scoped context.

## Inputs
- The diff: `git diff <base>...HEAD` (default base `main`, overridable via `review-pro.config.scope.base`).
- The changed-file list: `git diff --name-only <base>...HEAD`.
- `review-pro.config` (optional): `enabled_reviewers`, `scope.ignore`, `stack_packs`.

## Steps
1. **Gather** the diff and changed-file list (run git). Read full contents of changed files (respect `scope.ignore`).
2. **Classify each changed file** into buckets: `backend | frontend | test | db-migration | config-infra | docs | build-deps`.
3. **Detect active stacks** (once): parse manifests (`package.json`, `go.mod`, `Cargo.toml`, `requirements.txt`/`pyproject.toml`, `Gemfile`, `pom.xml`). Merge with `review-pro.config.stack_packs`. Emit `active_stacks`.
4. **Decide which reviewers to dispatch** using the signal map below. Be conservative: when relevance is uncertain, dispatch. Skipping a real issue is worse than paying for one extra subagent.
5. **Scope context per dispatched reviewer** per `core/shared/context-policy.md`: every reviewer gets diff + changed files; add the reviewer-specific scoped extras.
6. **Emit the dispatch plan** (YAML below) and hand off to Stage 2 (fan-out). Do not run the reviewers inline unless the platform adapter requires it.

## Signal map (non-exhaustive)
- migration files / `CREATE|ALTER|DROP` / schema files → `db`
- auth/session/crypto/permission symbols, secret-shaped strings → `security`
- new/changed routes, handlers, controllers, service entrypoints → `backend` + `api-contract`
- loops over collections, queries in loops, bulk data → `performance`
- `.tsx/.vue/.svelte` components, interactive elements (`button`,`form`,`input`,`nav`,`dialog`) → `frontend` + `a11y`
- `.test./__tests__/spec` files, or new public functions lacking tests → `tests`
- new abstractions, large added functions, copy-paste-shaped additions → `craft` + `dry` + `ai-antipatterns`
- any non-trivial logic change → `correctness`

## Dispatch plan format
```yaml
base: <branch>
active_stacks: [<stack>, ...]
changed_files_total: <n>
dispatch:
  <reviewer>:
    context:
      changed_files: [<paths>]
      related: [<scoped extras: callers, repo-search results, schema, consumers...>]
  # reviewers not dispatched are simply absent
```

## Output discipline
Return ONLY the dispatch plan and a one-line summary. Do not review the code. Do not invent reviewers outside the roster in `manifest.json`. If `enabled_reviewers` is set, intersect your dispatch with it.

## Effective rubric composition (for Stage 2)
For each dispatched reviewer, the orchestrator composes its effective rubric from the core skill plus the active stack packs:
```
effective_rubric(<reviewer>) = core/skills/<reviewer>/SKILL.md + Σ stacks/<active_stack>/<reviewer>.md
```
Use `scripts/compose-rubric.sh <reviewer> <stack...>` to render it (e.g. `compose-rubric.sh security typescript-react`). Pass the rendered rubric to the reviewer subagent as its `### Rubric` section. Reviewers with no pack file for an active stack simply run on their core rubric.

