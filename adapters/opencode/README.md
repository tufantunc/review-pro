# review-pro — opencode adapter

Installs the review-pro core (skills + subagents) into opencode.

## Install (one-time)

```bash
bash adapters/opencode/install.sh
# or, to target a custom opencode home:
OPENCODE_HOME=/path/to/.config/opencode bash adapters/opencode/install.sh
```

What it does:
- Copies each `core/skills/<name>/` to `$OC_HOME/skills/<name>/` (opencode loads `SKILL.md` from there).
- Copies each `core/agents/*.md` to `$OC_HOME/agents/`.

opencode skill loading from `$OC_HOME/skills/` is confirmed. Agent/subagent loading paths can vary by opencode version — after install, verify your agents appear; if your opencode expects agents elsewhere, copy `core/agents/*.md` there and adjust the script.

## Install stacks (per repo)

Stack packs live in the **reviewed repo**, not the plugin. Install them with the community CLI (separate package), or copy manually:

```bash
# manual (until the CLI ships):
mkdir -p .review-pro && cp -R /path/to/review-pro/stacks/node .review-pro/node
```

See `stacks/README.md`.

## Running a review (one command — no scripts required)

In opencode, open the repo you want to review (on the feature branch) and ask the session to review it — e.g. *"review-pro ile bu branch'i incele"* or invoke the **`review-pro`** skill. The agent does everything with its own tools:

1. **Prep** — runs `git diff`, reads changed files, Globs `.review-pro/*/manifest.json` for active stacks.
2. **Triage** (inline) — dispatch plan: which reviewers + scoped context.
3. **Fan-out** — for each reviewer, reads `.review-pro/<stack>/<reviewer>.md` pack files and passes them as `### Stack signals` to the `<reviewer>-reviewer` subagent (which auto-loads its core skill).
4. **Synthesize** (inline) — one verdict + report.

No `REVIEW_PRO_ROOT`, no env vars, no user-run scripts at review time. (`scripts/review.sh` exists only as an optional debug/CI helper to inspect what review-pro sees.)
