---
name: review-pro
description: "One-command AI code review. Run the full review-pro pipeline — triage -> relevant specialist reviewers with composed stack-aware rubrics -> synthesis — and return the final verdict + report. Use to review a branch or PR with review-pro."
version: 0.1.0
---

# Review-Pro (one-command review)

You are the **orchestrator**. Run the entire review-pro pipeline on the current branch in ONE pass and return the final verdict + report. Do not hand off to the user between stages.

## Inputs
- **Repo under review** = your current working directory.
- **Base branch** = `main` by default (override via `review-pro.config.scope.base`).
- **REVIEW_PRO_ROOT** = the review-pro plugin directory that contains `scripts/` and `stacks/`. It is printed by `review.sh prep` as `REVIEW_PRO_ROOT:`. If you don't know it, ask the user once, or read it from the `$REVIEW_PRO_ROOT` env var.

## Procedure

### 1. Prep (mechanical)
From the repo under review, run:
```
$REVIEW_PRO_ROOT/scripts/review.sh prep
```
This prints `REVIEW_PRO_ROOT`, `BASE`, `ACTIVE_STACKS`, the changed-file list, and the full labeled contents of every changed file. Capture this bundle.

### 2. Triage (you, inline)
Follow the `review-pro-triage` skill. Using the prep bundle, classify files, detect concern relevance, and produce a **dispatch plan**: which reviewers to run + each one's scoped context (per `core/shared/context-policy.md`). Be conservative — when in doubt, dispatch. Intersect with `review-pro.config.enabled_reviewers` if present.

### 3. Fan-out — reviewers (subagents, parallel)
For each reviewer in the dispatch plan:

1. **Compose its effective rubric** (core + active stack packs):
   ```
   $REVIEW_PRO_ROOT/scripts/compose-rubric.sh <reviewer> <active_stack...>
   ```
   (Use the `ACTIVE_STACKS` from prep, e.g. `compose-rubric.sh security typescript-react node`.)
2. **Invoke the `<reviewer>-reviewer` subagent** — in parallel / background if your platform allows, else sequentially. Its prompt MUST contain three labeled sections:
   - `### Rubric` — the composed rubric output from step 1. **This overrides the subagent's default core-only skill** and carries the stack-specific signals (e.g. `dangerouslySetInnerHTML` = XSS for ts-react).
   - `### Changed file contents` — the changed files relevant to this reviewer (from the prep bundle / scoped context).
   - `### Related context` — scoped extras per context-policy (callers, repo search, schema, consumers). Omit the section if none.
3. **Collect** its structured finding blocks.

If a reviewer subagent is unavailable on your platform, perform that review **inline** by applying the composed rubric to the scoped context yourself, and emit findings in the shared schema.

### 4. Synthesis (you, inline)
Follow the `review-pro-synthesize` skill over ALL collected findings: dedup by `(file, line±5, category-root, overlap_hints)`, weight overlaps, resolve conflicts by domain ownership, calibrate severity (anti-overreporting), and emit the verdict.

## Output
Return ONLY the final synthesis report:

```
## Verdict: BLOCK | REQUEST CHANGES | APPROVE

### Critical
- [Critical] <file>:<line> — <title>
  impact: ...
  remedy: ...
  flagged by: <reviewer>, <reviewer>

### High
...
### Medium / Low / Nitpick
...
```

Do not dump raw per-reviewer outputs. Lead with the verdict.

## Rules
- **Never present a finding with unfinished research** — if you can verify it in the repo, do (read callers, schema, consumers).
- **Always compose rubrics with ACTIVE_STACKS** so stack-specific signals reach the reviewers; a reviewer run on its core skill alone will miss stack patterns.
- If triage dispatches no reviewers (e.g. docs-only change), return `APPROVE` with a one-line note.
- Calibrate honestly: downgrade anything you cannot fully trace; never invent severity.
