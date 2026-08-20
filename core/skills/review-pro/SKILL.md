---
name: review-pro
description: "One-command AI code review. Runs triage -> relevant specialist reviewers -> synthesis on the current branch and returns the verdict + report. Stack-specific signals are loaded automatically from the repo's .review-pro/ directory. Use to review a branch or PR with review-pro."
version: 0.2.0
---

# Review-Pro (one-command review)

You are the **orchestrator**. Run the entire pipeline on the current branch in ONE pass and return the final verdict + report. Do everything with your own native tools — shell for git, Read/Glob/Grep for files. **Do NOT ask the user to run any scripts.** Do not hand off between stages.

## Procedure

### 1. Prep (native — you do this, not the user)
- **Base branch:** `main`, falling back to `master` if `main` doesn't exist.
- **Changed files:** run `git diff --name-only <base>...HEAD` in your shell. Read each changed file's full contents with Read. (git already excludes gitignored/generated paths from the diff.)
- **Argument (optional):** if the invocation carried an argument, it is either a base branch or ref, or a spec to review against (a file path or an issue URL). Forward a spec argument to triage as the first link of its spec resolution.
- **Installed stacks:** `Glob .review-pro/*/manifest.json`. Each match is a stack the user installed (via `npx review-pro`). These are the repo's **active stacks**. If `.review-pro/` is absent or empty, reviewers run on their core rubric only.

### 2. Triage (you, inline)
Follow the `review-pro-triage` skill. Classify the changed files, detect concern relevance, resolve the spec (emitting `spec_source`), and produce a **dispatch plan**: which reviewers to run + each one's scoped context (per `core/shared/context-policy.md`). Be conservative, when in doubt dispatch, with one exception: `spec` runs only when `spec_source.kind` is not `none`, because a spec reviewer with no spec is a guaranteed waste rather than a possible finding.

### 3. Fan-out — reviewers (subagents, parallel)
For each reviewer in the dispatch plan:

1. **Gather its stack signals.** For each installed stack, Read `.review-pro/<stack>/<reviewer>.md` **if it exists**. Concatenate the ones you find — this is the reviewer's `### Stack signals` content. (The subagent auto-loads its own core skill, so you do NOT need to pass the core rubric — only the stack-specific signals.)
2. **Invoke the `<reviewer>-reviewer` subagent** — in parallel/background if your platform allows, else sequentially. Its prompt contains:
   - `### Stack signals` — the concatenated pack files from step 1 (omit the section if none).
   - `### Changed file contents` — the changed files relevant to this reviewer (from your prep).
   - `### Related context` — scoped extras per context-policy (callers, consumers, schema, repo search). Omit if none.
   - `### Spec text`, for the `spec` reviewer only: the resolved spec text from triage's `spec_source`. Omit this section for every other reviewer; none of them should be measuring intent. If `spec_source.kind` is `none`, do not dispatch this reviewer at all.
3. **Collect** its structured finding blocks.

If a reviewer subagent is unavailable on your platform, perform that review **inline**: apply the core skill (which you Read from the plugin) plus the stack signals to the scoped context, and emit findings in the shared schema.

### 4. Synthesis (you, inline)
Follow the `review-pro-synthesize` skill over ALL collected findings, passing it the `diff_class`, `changed_files`, and `spec_source` you determined in triage: dedup by `(file, line±5, category-root, overlap_hints)` within each axis, weight overlaps, resolve conflicts by domain ownership, calibrate severity (anti-overreporting), and emit the verdict.

## Output
Return ONLY the final synthesis report:

```
## Verdict: <BLOCK | REQUEST CHANGES> (<code | spec | code + spec>) | APPROVE

Spec: measured against <spec_source.ref>
(or: skipped, no spec found / not measured, <ref> resolved but carried no text)

### Critical
- [Critical] <file>:<line> — <title>
  impact: ...
  remedy: ...
  flagged by: <reviewer>, <reviewer>

### High
...
### Medium / Low / Nitpick
...

## Spec (measured against <spec_source.ref>; or skipped, no spec found; or not measured, resolved but empty)

### Missing / Wrong / Scope creep
- [<severity>] <file>:<line>, <title>
  spec: "<the quoted requirement>"
  remedy: ...
```

Do not dump raw per-reviewer outputs. Lead with the verdict.

## Rules
- **Never present a finding with unfinished research** — if you can verify it in-repo (callers, schema, consumers), do.
- **Stack signals come only from `.review-pro/`.** If it's empty, reviewers use core rubrics. Never invent stack signals.
- If triage dispatches no reviewers (e.g. docs-only change), return `APPROVE` with a one-line note.
- Calibrate honestly: downgrade anything you cannot fully trace; never invent severity.
- **The spec axis is reported separately and never merged into the code findings.** If no spec was resolved, say so in one line rather than omitting the section.
