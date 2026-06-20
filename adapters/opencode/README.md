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

## Running a review
1. In your repo, run the **triage** skill on the current branch's diff.
2. From triage's dispatch plan, invoke the listed reviewer subagents in parallel, passing each its scoped context and its effective rubric (core skill + active stack packs).
3. Pass all reviewer outputs to the **synthesize** subagent for the final verdict + report.

> Stack packs (Phase 3) are layered onto reviewer rubrics at dispatch time. Until then, reviewers run on their core rubric only.
