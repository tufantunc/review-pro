# review-pro — opencode adapter

Installs the review-pro agnostic core into opencode.

## Install

```bash
bash adapters/opencode/install.sh
# or, to target a custom opencode home:
OPENCODE_HOME=/path/to/.config/opencode bash adapters/opencode/install.sh
```

## What it does
- Copies each `core/skills/<name>/` to `$OC_HOME/skills/<name>/` (opencode loads `SKILL.md` from there).
- Copies each `core/agents/*.md` to `$OC_HOME/agents/`.

## Confirming agent loading
opencode skill loading from `$OC_HOME/skills/` is confirmed. Agent/subagent loading paths can vary by opencode version — after install, verify your agents appear (e.g., list available agents in your opencode session). If your opencode expects agents elsewhere, copy `core/agents/*.md` to that location and adjust this script.

## Running a review (one command)
In opencode, open the repo you want to review (on the feature branch), then just ask the session to review it — e.g. *"review-pro ile bu branch'i incele"* or invoke the **`review-pro`** skill. The main agent runs the whole pipeline:

1. **Prep** — `scripts/review.sh prep` (from the repo under review) prints `REVIEW_PRO_ROOT`, base, active stacks, changed files + contents.
2. **Triage** (inline) — dispatch plan: which reviewers + scoped context.
3. **Fan-out** — for each reviewer, `scripts/compose-rubric.sh <reviewer> <stacks>` renders the effective rubric (core + stack packs), then the `<reviewer>-reviewer` subagent runs with that rubric + scoped context.
4. **Synthesize** (inline) — one verdict + report.

> The orchestrator needs `REVIEW_PRO_ROOT` (the dir with `scripts/` + `stacks/`). It's auto-printed by `review.sh prep`; you can also `export REVIEW_PRO_ROOT=~/Desktop/Projects/Personal/review-pro` so the agent always knows it.

> Stack packs live under `stacks/` and are composed at runtime — they are NOT copied by install. See `stacks/README.md`.
