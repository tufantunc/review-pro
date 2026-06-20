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
1. In your repo, run the **triage** skill on the current branch's diff. It detects active stacks (e.g. `typescript-react`, `node`) and emits a dispatch plan.
2. For each dispatched reviewer, compose its **effective rubric** from the core skill + active stack packs, then run the reviewer subagent in parallel with its scoped context:
   ```bash
   scripts/compose-rubric.sh security typescript-react   # core security + ts-react pack
   ```
   Pass the rendered rubric to the subagent as its `### Rubric` section, plus the scoped context from the dispatch plan.
3. Pass all reviewer outputs to the **synthesize** subagent for the final verdict + report.

> Stack packs live under `stacks/`. A pack only contributes for reviewers where it has a file; reviewers without a pack file run on their core rubric alone. See `stacks/README.md`.
