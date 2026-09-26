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
Follow the `review-pro-triage` skill. Classify the changed files, detect concern relevance, resolve the spec (emitting `spec_source`), and produce a **dispatch plan**: which reviewers to run + each one's scoped context (per `core/shared/context-policy.md`). Be conservative, when in doubt dispatch, with two exceptions: `spec` runs only when `spec_source.kind` is not `none`, because a spec reviewer with no spec is a guaranteed waste rather than a possible finding; and a reviewer that triage assigned an external premise to runs whether or not the signal map picked it, because a premise routed to a reviewer that never runs is verified by nobody.

### 3. Fan-out — reviewers (subagents, parallel)
For each reviewer in the dispatch plan:

1. **Gather its stack signals.** For each installed stack, Read `.review-pro/<stack>/<reviewer>.md` **if it exists**. Concatenate the ones you find — this is the reviewer's `### Stack signals` content. (The subagent auto-loads its own core skill, so you do NOT need to pass the core rubric — only the stack-specific signals.)
2. **Invoke the `<reviewer>-reviewer` subagent** — in parallel/background if your platform allows, else sequentially. Its prompt contains:
   - `### Stack signals` — the concatenated pack files from step 1 (omit the section if none).
   - `### Changed file contents`: the files in this reviewer's `context.changed_files` from the dispatch plan, all of them. Handing a reviewer fewer files than its plan lists is a narrowing the coverage check cannot see.
   - `### Related context` — scoped extras per context-policy (callers, consumers, schema, repo search). Omit if none.
   - `### Spec text`, for the `spec` reviewer only: the resolved spec text from triage's `spec_source`. Omit this section for every other reviewer; none of them should be measuring intent. If `spec_source.kind` is `none`, do not dispatch this reviewer at all.
   - `### External premises`, for the owning reviewer only: the entries from triage's
     `external_premises` whose `owner` is this reviewer, verbatim. Omit the section for
     every other reviewer. Verification channels and the requirement to record which
     channel settled a premise live in `core/shared/context-policy.md`.
   - `### Files examined`, for every code reviewer (never `spec`): one line asking it to end with its `## Files examined` block, `examined: [...]` then `not_examined:` entries with `file` and `reason`, accounting for each file in `### Changed file contents` exactly once. The agent body asks for the same block; repeating it here keeps coverage working when the installed agents are older than this skill.
3. **Collect** its structured finding blocks, plus its `## Premise verification` block when one comes back, and its `## Files examined` block. Neither block is a finding: never dedup them against the finding blocks and never rank them alongside them.

If a reviewer subagent is unavailable on your platform, perform that review **inline**: apply the core skill (which you Read from the plugin) plus the stack signals to the scoped context, and emit findings in the shared schema. Every inline code review ends with the same `## Files examined` block a subagent returns, accounting for each file in that reviewer's `context.changed_files` exactly once:

```
## Files examined
examined: [<path>, ...]
not_examined:
  - file: <path>
    reason: <why, one line>
```

A file counts as examined only if you read its diff or contents while applying that rubric. An accurate list with gaps is correct; a complete-looking list that overstates what you read is wrong, because synthesis reports it as the review's coverage. The spec review emits no block.

### 4. Verification (subagents, parallel)
Verification needs the merged findings, so first run the `review-pro-synthesize` skill's merge steps, **Collect** through **Resolve conflicts**, with the `diff_class`, `changed_files`, `spec_source`, `external_premises`, `premises_dropped`, and each reviewer's `context.changed_files` you determined in triage: dedup within each axis (code findings on `(file, line±5, category-root, overlap_hints)`, spec findings on `(quoted requirement, file, line)` per that skill's Spec axis section), weight overlaps, and resolve conflicts by domain ownership. Then:

1. **Select** the code-axis findings with severity Medium, High or Critical, ordered by severity and then by file and line. Take the first 8; the rest are `not verified (cap)`. Spec-axis findings are never verified.
2. **Invoke one `review-pro-verify-subagent` per selected finding**, in parallel if your platform allows, else sequentially. Its prompt contains:
   - `### Finding`: the merged finding block, verbatim.
   - `### Written by`: the reviewer that wrote it. Never how many reviewers flagged it; that count is pressure, not evidence.
   - `### Diff`: first line `base: <sha>`, then the output of `git diff <base>...HEAD`. The sha is the merge base, from `git merge-base <base> HEAD`, because that is what the diff was taken against.
   - `### Change description`: the PR body or the invocation's description, when there is one. Omit the section otherwise.
3. **Collect** each reply. A reply that errors, times out, or carries no parseable block leaves its finding `not verified (error)`.

If the verify subagent is unavailable on your platform, do **not** verify inline: a check in your own context is not independent. Mark every selected finding `not verified (no independent verifier)` and continue.

### 5. Synthesis (you, inline)
Continue the `review-pro-synthesize` skill from **Verification results**, with the verification results and the same triage values: apply the results, calibrate severity (anti-overreporting), run the out-of-diff check, compute coverage, and emit the verdict. Do not merge again: the results are bound to the merged findings as they stand.

## Output
Return ONLY the final synthesis report, in the `review-pro-synthesize` skill's `## Output` format: the verdict line, then the Spec, Coverage and Verification lines, the caveats and the External premises table when they apply, the code findings by severity, `### Refuted in verification`, and the `## Spec` section. That skill holds the only copy of the template, so follow it there rather than a summary of it here.

Do not dump raw per-reviewer outputs. Lead with the verdict.

## Rules
- **Never present a finding with unfinished research** — if you can trace it in-repo (callers, schema, consumers), do.
- **Stack signals come only from `.review-pro/`.** If it's empty, reviewers use core rubrics. Never invent stack signals.
- If triage dispatches no reviewers (e.g. docs-only change), return `APPROVE` with a one-line note that says no reviewer was dispatched, so nothing reviewed the changed files. That note stands in for the coverage caveat, and it is never left out.
- Calibrate honestly: downgrade anything you cannot fully trace; never invent severity.
- **The spec axis is reported separately and never merged into the code findings.** If no spec was resolved, say so in one line rather than omitting the section.
- **Never verify a finding in your own context.** Verification is independent or it does not happen, and the report says which.
