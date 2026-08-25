---
name: review-pro-triage
description: "Stage 1 of review-pro: classify changed files, detect relevant specialist reviewers, detect active stacks, scope context per reviewer, and emit a dispatch plan. Use to start a review-pro review, triage a PR/branch, or fan out reviewers."
version: 0.1.0
---

# Review-Pro Triage (Stage 1)

You are the orchestrator's first stage. You do NOT review code yourself. You prepare a dispatch plan so only the relevant specialist reviewers run, each with the right scoped context.

## Inputs
- The diff: `git diff <base>...HEAD` (base = `main`, falling back to `master`).
- The changed-file list: `git diff --name-only <base>...HEAD`.
- An optional spec argument forwarded by the orchestrator: a file path or an issue URL.

## Steps
1. **Gather** the diff and changed-file list (run git). Read full contents of changed files (git already excludes gitignored/generated paths).
2. **Classify each changed file** into buckets: `backend | frontend | test | db-migration | config-infra | docs | build-deps`.
3. **Detect active stacks**: `Glob .review-pro/*/manifest.json` — each match is a stack the user installed (via `npx review-pro`). These are the repo's `active_stacks`. (No auto-detection from `package.json` — stacks are explicitly installed per repo.) If `.review-pro/` is absent/empty, `active_stacks: []` and reviewers run core-only.
4. **Decide which reviewers to dispatch** using the signal map below. Be conservative: when relevance is uncertain, dispatch. Skipping a real issue is worse than paying for one extra subagent.
5. **Classify the diff's weight** as `diff_class`: `trivial` if the changed-file set is docs-only (every file in the `docs` bucket) or the whole diff is a single file under ~20 changed lines; `substantive` otherwise. Emit it in the plan — Stage 3 reads it and must not re-derive it.
6. **Resolve the spec.** Find what the change was supposed to do, trying these in order and falling through on any failure:
   1. An **explicit argument** forwarded by the orchestrator: a file path, or an issue URL. An explicit instruction always wins; if the user named a spec, do not go looking for a different one.
   2. The **PR body and issue references in commit messages** (`#123`, `Closes #45`), via `gh pr view` and `gh issue view`.
   3. A **file** under `docs/`, `specs/`, or `.scratch/`. Match the branch's last path segment as a substring of the filename, ignoring any leading date prefix: branch `feat/spec-axis` matches `docs/superpowers/specs/2026-08-20-spec-axis-design.md`. These directories are conventions, not guarantees, and often none exists. If more than one file matches, prefer `specs/` over `plans/` over `.scratch/`, then the longest match; an implementation plan is not a requirements document, and measuring a diff against one turns every deliberate deviation into a finding. If two still tie, record `kind: none` rather than picking arbitrarily.
   4. **Nothing.**

   Every link falls through silently to the next. `gh` missing, `gh` not authenticated, the repo not hosted on GitHub, and the branch not being a PR are all ordinary conditions, not errors. Use every reference you find rather than choosing between them: the intent of a change closing three issues is the sum of the three.

   Emit `spec_source` recording what you found, not merely whether you found something. Stage 3 prints it verbatim, because a reader who cannot see what the review was measured against cannot judge a spec finding.

   **Dispatch `spec` if and only if `spec_source.kind` is not `none`.** This is the one dispatch decision that does not come from the signal map, because spec relevance has nothing to do with which files changed. The "when in doubt, dispatch" default in step 4 does **not** apply here: dispatching a spec reviewer with no spec is a guaranteed waste, not a possible finding.

7. **Extract external premises.** Gather your own sources; do not hang this on step 6,
   whose chain stops at the first hit and therefore never reads the PR body when the
   user passed a spec by hand.

   Sources, in the two channels a reviewer cannot see for itself:
   - **Commit messages** on the branch (`git log <base>..HEAD`). No `gh` needed.
   - **The PR body**, via `gh pr view`. Its absence is an ordinary condition.

   Code comments in changed files are **not** yours: they are already in every
   reviewer's baseline context, and scanning them here would route the same premise
   twice.

   A premise qualifies only when the rationale points at a **specific, addressable
   external artifact**: an upstream issue or PR number, a changelog entry, a CVE, a
   release note, an RFC. "Fixed upstream" with no number qualifies, because which fix
   is determinable from the package version. A claim that is merely ungrounded in the
   repo does **not** qualify; that threshold would turn every review into a web crawl.

   Assign exactly one `owner`:

   | The premise justifies | Owner |
   |---|---|
   | Adding, removing, or bumping a dependency | `ai-antipatterns` |
   | A behaviour-equivalence claim across a dependency change | `correctness` |
   | An API surface or version-floor claim | `api-contract` |
   | Anything else | `ai-antipatterns` |

   **Assigning a premise to a reviewer dispatches that reviewer**, whatever the signal
   map in step 4 concluded. Otherwise a premise can be routed to a reviewer that never
   runs, and nothing reports the gap.

   **Triage does not verify the premise itself.** Extract, route, stop. A triage that
   settles a premise breaks the one-owner rule and produces a verification no reader can
   attribute to a reviewer.

   At most **three** premises, chosen by what the diff most depends on. State any
   dropped count in the plan: a silent cap reads to the next reader as complete
   coverage. Emit nothing when there are none.
8. **Scope context per dispatched reviewer** per `core/shared/context-policy.md`: every reviewer gets diff + changed files; add the reviewer-specific scoped extras.
9. **Emit the dispatch plan** (YAML below) and hand off to Stage 2 (fan-out). Do not run the reviewers inline unless the platform adapter requires it.

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
changed_files: [<paths>]        # the full changed-file list; Stage 3 needs it
diff_class: trivial | substantive
spec_source:
  kind: argument | pr-body | issue | file | none
  ref: <issue number, path, or url>   # omit when kind is none
external_premises:                    # omit the key entirely when there are none
  - claim: "<the rationale, quoted>"
    cited: <upstream ref, changelog entry, CVE, or version>
    source: commit-message | pr-body
    pinned: <package old -> new>      # optional; when the diff pins the version
    owner: ai-antipatterns | correctness | api-contract
premises_dropped: <n>                 # omit when zero
dispatch:
  <reviewer>:
    context:
      changed_files: [<paths>]
      related: [<scoped extras: callers, repo-search results, schema, consumers...>]
  # reviewers not dispatched are simply absent
```

## Output discipline
Return ONLY the dispatch plan and a one-line summary. Do not review the code. Do not invent reviewers outside the roster in `manifest.json`.

## Stack signals (for Stage 2)
For each dispatched reviewer and each active stack, the orchestrator (see the `review-pro` skill) Reads `.review-pro/<stack>/<reviewer>.md` if it exists, and passes the concatenated pack files to the reviewer subagent as its `### Stack signals` section. The subagent auto-loads its own core skill, so it gets core + stack signals. A reviewer with no pack file for any active stack simply runs core-only.

