# Glossary (shared)

- **triage** — Stage 1: classify files, detect relevant reviewers + active stacks, scope context, emit a dispatch plan. Does not review code.
- **fan-out** — Stage 2: only the triage-selected specialists run in parallel, each with its scoped context and composed rubric.
- **synthesis** — Stage 3: dedup, weight, resolve conflicts, calibrate severity, produce verdict + report.
- **reviewer** — a specialist subagent that owns one concern and returns structured findings.
- **dispatch plan** — triage's YAML output: active stacks + per-reviewer scoped context.
- **scoped context** — the exact files/search results a reviewer receives (diff + changed files + reviewer-specific extras).
- **effective rubric** — what a reviewer actually uses = core skill + active stack packs, composed by the orchestrator.
- **stack pack** — a per-language/framework supplement that adds concrete signals/remedies to a core reviewer rubric.
- **overlap_hints** — category roots attached to a finding so synthesis can collapse duplicates.
- **base** — the diff base branch (default `main`), configurable via `review-pro.config`.
