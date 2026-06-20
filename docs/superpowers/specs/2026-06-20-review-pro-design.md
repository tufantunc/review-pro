# Review-Pro — Design Spec

**Date:** 2026-06-20
**Status:** Approved (brainstormed)
**Author:** Review-Pro project
**Inspiration:** [cursor/plugins — thermos](https://github.com/cursor/plugins/tree/main/thermos) (thermo-nuclear review)

---

## 1. Purpose

Review-Pro is an open-source, cross-platform **AI-code-review** plugin. Its job: review code **written by AI agents**, using AI agents, through a **tiered (triage → fan-out → synthesis)** architecture.

It is a deliberate, more capable alternative to the `thermos` plugin:

| | thermos | review-pro |
|---|---|---|
| Architecture | 2 parallel subagents, always both | Tiered: triage → relevant specialists → synthesis |
| Concerns | 2 (security/correctness, maintainability) | 12 specialist reviewers |
| Cost on small PRs | Pays for both every time | Pays only for relevant specialists |
| Context | Whole diff to every subagent | Scoped context per specialist; repo-wide where needed (DRY) |
| AI-code lens | No | First-class (`ai-antipatterns-reviewer`) |
| Stack awareness | None | Optional stack packs per language/framework |
| Platforms | Cursor only | Cross-platform (agnostic core + adapters) |

### Goals

- High-quality, high-conviction rubrics (skills) — the core asset of the project.
- Review concerns that matter for **AI-generated code**: hallucinated APIs, over-engineering, ignored conventions, needless dependencies.
- Cheap on small PRs, deep on large ones.
- Works across Cursor, Claude Code, and opencode from one agnostic core.

### Non-goals (for v0.1)

- SARIF emission, automated PR-comment posting (post-MVP adapter hooks).
- Pre-commit light mode (post-MVP).
- Observability and dependency/supply-chain reviewers (deferred — not selected for v0.1).
- CI/CD hosting; Review-Pro runs inside an agent session, not as a standalone service.

---

## 2. Architecture — 3-stage pipeline

```
 ┌─────────────────┐     dispatch plan +      ┌─────────────────────────┐
 │  Stage 1        │     scoped context        │  Stage 2                │
 │  TRIAGE         │ ───────────────────────▶  │  FAN-OUT (parallel,     │
 │  (1 subagent)   │                           │  background specialists)│
 │  - classify     │                           │  - each loads effective │
 │  - detect       │                           │    rubric (core+packs)  │
 │    relevance    │                           │  - receives scoped ctx  │
 │  - scope ctx    │                           │  - returns evidence     │
 │  - detect stack │                           │    findings             │
 └─────────────────┘                           └─────────────┬───────────┘
                                                             │ findings
                                                             ▼
                                               ┌─────────────────────────┐
                                               │  Stage 3                │
                                               │  SYNTHESIS              │
                                               │  - dedup (loc+category) │
                                               │  - weight overlaps      │
                                               │  - resolve conflicts    │
                                               │  - severity calibration │
                                               │  - verdict + report     │
                                               └─────────────────────────┘
```

### Stage 1 — Triage (`review-pro-triage`)

A single, cheap subagent. Inputs: the diff (vs base branch, default `main`) and the list of changed files.

Responsibilities:

1. **Classify each changed file** into one or more buckets: `backend | frontend | test | db-migration | config-infra | docs | build-deps`.
2. **Detect concern relevance** from diff signals, and decide which specialists to dispatch. Signal map (non-exhaustive, heuristic + symbol/keyword sniff):
   - migration files, `CREATE/ALTER/DROP`, schema files → `db`
   - auth/session/crypto/permission symbols, secret-looking strings → `security`
   - new/changed routes, handlers, controllers, service entrypoints → `backend` + `api-contract`
   - loops over collections, queries in loops, large data → `performance`
   - new `.tsx/.vue/.svelte` components, interactive elements (`button`, `form`, `input`, `nav`) → `frontend` + `a11y`
   - `.test./__tests__/spec` files, or new public functions lacking tests → `tests`
   - new abstractions, large added functions, copy-paste-shaped additions → `craft` + `dry` + `ai-antipatterns`
   - any non-trivial logic change → `correctness`
3. **Detect active stack(s)** for the repo (deterministic, once per review): parse `package.json`, `go.mod`, `Cargo.toml`, `requirements.txt`, `pyproject.toml`, `Gemfile`, `pom.xml`, etc. Merge with `review-pro.config.stack_packs` overrides.
4. **Scope context per dispatched specialist** (see §6) and produce the **dispatch plan**.

**Output of triage:** a structured dispatch plan:

```yaml
base: main
active_stacks: [typescript-react, node]
changed_files_total: 17
dispatch:
  security:
    reviewers: [security]
    context:
      changed_files: [...]
      related: [callers of auth helpers, ...]
  correctness:
    reviewers: [correctness]
    context: { changed_files: [...] }
  frontend:
    reviewers: [frontend, a11y]
    context:
      changed_files: [src/components/*.tsx]
      related: [design-system tokens, ...]
  dry:
    reviewers: [dry]
    context:
      changed_files: [...]
      repo_search: [symbol: validateEmail, pattern: useState(...)]
  # reviewers NOT dispatched are simply absent
```

> Triage must be conservative: when in doubt about relevance, **dispatch** the specialist rather than skip. Skipping a real issue is worse than paying for one extra subagent.

### Stage 2 — Fan-out (specialists, parallel, background)

Only the specialists selected by triage run. For each, the orchestrator **composes the effective rubric**:

```
effective_rubric(<reviewer>) = core/skills/<reviewer>/SKILL.md
                             + Σ stacks/<active_stack>/<reviewer>.md
```

and passes it to the subagent as the rubric section of the prompt, alongside that specialist's scoped context. Each specialist returns prioritized, evidence-backed findings in the shared output schema (§5). Specialists never spawn nested subagents.

### Stage 3 — Synthesis (`review-pro-synthesize`)

Collects all specialist findings and produces a single report:

1. **Dedup** by `(location, category, overlap_hints)` — collapse the same issue flagged by multiple specialists into one.
2. **Weight** — findings flagged by ≥2 specialists get a conviction boost.
3. **Resolve conflicts** by category ownership: on security-relevant items, `security`'s severity wins; on maintainability, `craft` wins; etc. (See §5 cross-reviewer handoff notes.)
4. **Severity calibration** — enforce the anti-overreporting bar (thermos rule): never let a Low be reported as High; downgrade anything that cannot be fully traced to evidence.
5. **Verdict** + prioritized findings + remediation hints. Optionally write to PR/SARIF via adapter hook.

---

## 3. Specialist roster (12 reviewers)

Each maps to one selected concern. Triage decides which subset runs per review, so 12 specialists do **not** mean 12× cost every time.

| # | Subagent | Owns | Scope |
|---|----------|------|-------|
| 1 | `security-reviewer` | Vulnerabilities, authn/authz bypass, secret/PII leaks, injection, unsafe deserialization | diff + callers/callees of security-relevant code |
| 2 | `correctness-reviewer` | Bugs, logic errors, breaking existing functionality, cross-file side effects, race conditions, error-path gaps, devex regressions, feature-gate leaks | diff + related code |
| 3 | `craft-reviewer` | code-judo, 1k-line rule, spaghetti, abstraction/boundary quality, layer leaks, type-boundary cleanliness | diff + neighboring modules |
| 4 | `ai-antipatterns-reviewer` | Hallucinated APIs/symbols/imports, over-engineering, needless deps, ignored existing conventions/helpers/config, invented env/config keys | diff + repo search (existing helpers/conventions) |
| 5 | `dry-reviewer` | Repo-wide duplicate / near-duplicate detection, existing-helper & canonical-utility reuse, copy-paste | diff + repo-wide symbol/pattern search |
| 6 | `performance-reviewer` | Algorithmic complexity, N+1, unnecessary re-render, memory leaks, bundle size, blocking work, caching | diff + hot-path/query files |
| 7 | `backend-reviewer` | API design, error handling, transactional/atomic boundaries, validation, idempotency, rate-limiting | diff + related services |
| 8 | `frontend-reviewer` | Component structure, state management, prop drilling, UI consistency, i18n-readiness | diff + design-system/state files |
| 9 | `a11y-reviewer` | Semantic HTML, ARIA correctness, focus management, keyboard nav, contrast, name/role/value. **Conditionally dispatched** only when diff touches interactive UI. | diff + component files |
| 10 | `db-reviewer` | Migration safety (destructive ops, data loss, reversibility), missing indexes, constraints, query correctness | diff + migration history + schema |
| 11 | `api-contract-reviewer` | Schema/type contracts, request/response shapes, versioning/back-compat, serialization, `any`/cast leaks across the wire | diff + API consumers |
| 12 | `tests-reviewer` | Assertion quality, branch/edge coverage, flakiness, test-data realism, missing tests for new behavior | diff + code under test |

---

## 4. Rubric anatomy (quality contract)

**Every** reviewer's `SKILL.md` follows this structure. This is the project's central quality asset — consistency across reviewers is mandatory.

1. **Frontmatter** — `name`, `description` (trigger-rich, lists the keywords that should activate it), `version`.
2. **Role & mandate** — one sentence: who this reviewer is and the single question it answers.
3. **Scope** — diff-only vs repo-wide; the "only added/modified code" rule; explicit in-scope / out-of-scope.
4. **What this reviewer flags** — the substantive, concern-specific rubric: concrete signals, patterns, anti-patterns, with minimal code examples.
5. **Evidence & severity rules** — every finding must carry `file:line` + a code excerpt + *why* it matters. Full severity definitions (§7). The **anti-overreporting rule**: never misreport severity; high bar to claim High/Critical.
6. **No-unresearched-findings rule** — never present an issue with unfinished research when it can be verified in-repo (e.g., don't say "the client has X, but maybe the backend handles it" if the backend is reachable — go check).
7. **Ambition clause** (craft / dry / ai-antipatterns) — push for structural simplification and code-judo moves, not cosmetic nits.
8. **Approval bar** — explicit list of what blocks approval for this reviewer.
9. **Output schema** — the structured findings block (§5), machine-readable so synthesis can dedup.
10. **Cross-reviewer handoff notes** — "if you also see X, defer severity/ownership to `<other-reviewer>`", enabling clean dedup.
11. **Tone** — direct, serious, high-conviction; no nits while structural issues exist; never rude.

---

## 5. Output schema & finding format

Every specialist returns zero or more findings, each as a structured block:

```
- severity: High                 # Critical | High | Medium | Low | Nitpick
  category: security.authz       # <domain>.<subdomain>
  file: src/api/orders.ts
  line: 42
  title: missing ownership check on order update
  evidence: |
    app.put('/orders/:id', (req, res) => {
      updateOrder(req.params.id, req.body)   // no userId check
    })
  impact: any authenticated user can update another user's order
  remedy: authorize(ctx.userId === order.userId) before update
  confidence: high               # high | medium | low
  overlap_hints: [backend.authz, correctness.logic]  # for synthesis dedup
```

### Cross-reviewer conflict resolution (synthesis)

Ownership by domain (winner sets severity when two reviewers disagree on the *same* finding):

| Finding domain | Severity authority |
|---|---|
| security/auth/secrets | `security-reviewer` |
| data integrity / migrations | `db-reviewer` |
| contract / back-compat | `api-contract-reviewer` |
| maintainability / structure | `craft-reviewer` |
| performance | `performance-reviewer` |
| test correctness | `tests-reviewer` |
| accessibility | `a11y-reviewer` |

---

## 6. Context-gathering policy

Default baseline (all reviewers): the **diff** + **full contents of changed files** (thermos pattern).

Triage adds **scoped** extra context per specialist, so each subagent gets exactly what it needs instead of the whole repo:

| Specialist | Extra scoped context |
|---|---|
| `security` | callers/callees of changed auth/security-relevant code; related tests |
| `correctness` | consumers of changed functions; related error paths |
| `craft` / `ai-antipatterns` | neighboring module code; existing conventions & helpers (repo search) |
| `dry` | repo-wide symbol & pattern search for duplicates / existing helpers |
| `db` | migration history; schema definitions |
| `api-contract` | consumers of changed APIs (frontend calls, other services) |
| `tests` | the production code under test |
| `performance` | query definitions; hot-path / render files |
| `frontend` / `a11y` | design-system tokens; shared UI primitives |

Principle: **scoped, not whole-repo**, keeps each subagent fast and focused. Only `dry`, `craft`, and `ai-antipatterns` ever do repo-wide search, and only for the symbols/patterns relevant to the diff.

---

## 7. Severity & verdict model

### Severity levels

| Level | Definition | Example |
|---|---|---|
| **Critical** | Exploitable / data loss / broken core functionality in the diff | auth bypass; destructive non-reversible migration |
| **High** | Likely bug or security issue with concrete impact in changed code | missing ownership check; N+1 on a hot path |
| **Medium** | Real correctness/quality risk, scoped or conditional | missing edge-case handling; file approaching size limit |
| **Low** | Minor risk or quality nit worth fixing | unclear naming; small duplication |
| **Nitpick** | Style/preference, optional | formatting, phrasing |

### Verdict

| Verdict | Condition |
|---|---|
| **BLOCK** | any unaddressed Critical or High finding |
| **REQUEST CHANGES** | any Medium-or-above finding |
| **APPROVE** | only Low/Nitpick, or no findings |

Synthesis may downgrade severity only when evidence is incomplete; it never upgrades beyond what a specialist justified.

---

## 8. Stack packs

### Concept

A **stack pack** supplements a core reviewer rubric with language/framework-specific signals, examples, and remedies. The core rubric defines the *lens*; the stack pack makes it *concrete for this stack*.

### Composition (runtime)

```
effective_rubric(<reviewer>) = core/skills/<reviewer>/SKILL.md
                             + Σ stacks/<active_stack>/<reviewer>.md
```

- The **orchestrator (triage)** composes the effective rubric and passes it to each subagent as the rubric section of its prompt.
- **Subagents stay generic and global** ("receive a rubric + scoped context → return findings"). The platform-specific files never contain stack-specific content.
- Active stacks are **repo-based**: `active_stacks = detected(manifests) ∪ review-pro.config.stack_packs`.

### Why compose at runtime (not pre-bake at install)

Pre-rendering `reviewer × stack` skills causes an N×M file explosion and drift whenever core is updated. Runtime composition from the orchestrator keeps a single source of truth (core) and works identically on every platform.

### Stack pack file format

```
stacks/<stack>/<reviewer>.md
```

Only files for reviewers where the stack adds value exist (e.g., a `go` pack has no `frontend.md`/`a11y.md`). Each pack file mirrors the relevant sections of the core rubric (signals, remedies, severity notes, examples) and explicitly states `extends: core/skills/<reviewer>/SKILL.md`. A `manifest.json` per stack lists reviewer→file mappings.

### Concrete example

`core/skills/security/SKILL.md` (agnostic):
> "Injection, authn/authz bypass, secret/PII exposure, unsafe deserialization…"

`stacks/typescript-react/security.md` (additions):
> - `dangerouslySetInnerHTML` + user input → XSS (High)
> - secret exposed via `NEXT_PUBLIC_*` env or `localStorage` token
> - `target="_blank"` without `rel="noopener"`
> - remedy: DOMPurify sanitizer, httpOnly cookies, CSP header

`stacks/typescript-react/a11y.md` (additions):
> - `<img>` missing `alt`; interactive `<div>` without `role`/`tabindex`; missing focus trap in modals.

---

## 9. Configurability

`review-pro.config.{json,yaml,toml}` (one per repo, optional — everything has a sensible default):

```yaml
enabled_reviewers: [security, correctness, craft, ai-antipatterns, dry, performance,
                    backend, frontend, a11y, db, api-contract, tests]   # default: all
severity_gate: low        # minimum severity to report (nitpick | low | medium | high)
thresholds:
  max_file_lines: 1000    # thermos default
  max_function_lines: 150
  max_cyclomatic: 15
scope:
  base: main              # diff base branch
  ignore: [dist/**, vendor/**, *.generated.*]
stack_packs: []           # override/extend detected stacks
output:
  format: markdown        # markdown | json | sarif (post-MVP)
  target: terminal        # terminal | pr-comments (post-MVP) | sarif-file (post-MVP)
triggers:
  mode: full-pr           # full-pr | pre-commit (post-MVP, lighter subset)
```

---

## 10. Cross-platform adapters

### Agnostic core (`/core`)

- `core/skills/` — 12 reviewer rubrics + `triage` + `synthesize` orchestrator skills (plain markdown).
- `core/agents/` — one global subagent role definition per reviewer (loads its effective rubric; stable).
- `core/shared/` — `severity.md`, `output-schema.md`, `context-policy.md`, `glossary.md`.
- `manifest.json` — plugin manifest: lists skills, agents, version.

### Adapters (`/adapters/{opencode,cursor,claude-code}`)

Each adapter is a **thin shim** that maps the agnostic orchestration model onto platform primitives:

| Concern | opencode | Cursor | Claude Code |
|---|---|---|---|
| Parallel specialist invocation | subagents / `@mention` | `subagent_type` + `run_in_background: true` | `Task` tool (parallel calls) |
| Context gathering | bash/explore/grep | shell + explore subagents | Read/Glob/Grep tools |
| Output rendering | terminal markdown | Cursor chat | terminal markdown |
| Install | copy to `~/.config/opencode` (skills/agents) | `/add-plugin`-compatible files | skills + subagents dirs |

The adapter translates the **dispatch plan** into the platform's invocation mechanism and wires synthesis output to the platform's surface. Each adapter ships its own **install script**.

### MVP order of adapters

1. **opencode** (v0.1 — first fully-working adapter).
2. Cursor (v0.2).
3. Claude Code (v0.3).

---

## 11. Repository structure

```
review-pro/
  README.md
  LICENSE                         # MIT
  manifest.json                   # plugin manifest: skills, agents, version
  review-pro.config.example       # sample config with comments

  core/
    skills/
      review-pro-triage/SKILL.md            # Stage 1 orchestrator
      review-pro-synthesize/SKILL.md        # Stage 3 orchestrator
      security/SKILL.md
      correctness/SKILL.md
      craft/SKILL.md
      ai-antipatterns/SKILL.md
      dry/SKILL.md
      performance/SKILL.md
      backend/SKILL.md
      frontend/SKILL.md
      a11y/SKILL.md
      db/SKILL.md
      api-contract/SKILL.md
      tests/SKILL.md
    agents/
      <one subagent .md per reviewer + triage + synthesize>   # global role defs
    shared/
      severity.md
      output-schema.md
      context-policy.md
      glossary.md

  stacks/
    typescript-react/{manifest.json, security.md, correctness.md, craft.md,
                      ai-antipatterns.md, frontend.md, a11y.md, performance.md,
                      api-contract.md, tests.md}
    node/{manifest.json, security.md, backend.md, db.md, api-contract.md, tests.md, ...}
    python/...
    go/...

  adapters/
    opencode/{install.sh, README.md, ...}   # v0.1
    cursor/{plugin.json, install.sh, ...}   # v0.2
    claude-code/{install.sh, ...}           # v0.3

  docs/
    superpowers/specs/2026-06-20-review-pro-design.md   # this file

  scripts/
    install.sh                    # detects platform, runs matching adapter
```

---

## 12. MVP scope (v0.1)

**In scope:**
- `core/` in full: 12 reviewer skills + `triage` + `synthesize` + 4 shared docs.
- Global subagent definitions for all reviewers.
- **opencode adapter** fully working (install, dispatch, synthesis, terminal output).
- `manifest.json` + `review-pro.config.example`.
- **2 stack packs** as proof of the mechanism: `typescript-react` and `node`.
- `README.md`, `LICENSE`, install script.

**Explicitly out of scope for v0.1** (post-MVP):
- Cursor & Claude Code adapters.
- SARIF output and PR-comment automation.
- Pre-commit light mode.
- Additional stack packs (python, go, rust, ...).
- Observability and dependency/supply-chain reviewers.

---

## 13. Open questions / future

- **Deterministic vs LLM triage:** v0.1 uses a single LLM subagent for triage. A deterministic classifier (file-glob + manifest parsing + keyword rules) could make Stage 1 nearly free and more predictable — candidate for a fast path once signal map stabilizes.
- **Near-duplicate detection depth:** v0.1 `dry-reviewer` uses symbol/pattern search. A future version could use AST/normalization-based similarity for true near-duplicate detection across the repo.
- **Severity learnings:** consider an optional "review log" so projects can calibrate reviewer strictness over time.
- **Additional reviewers** deferred from selection: `observability`, `dependency/supply-chain`.
