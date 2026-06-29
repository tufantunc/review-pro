# review-pro — opencode adapter

Installs the review-pro core (skills + subagents) into opencode via the `review-pro` CLI.

## Install (one-time)

```bash
npx review-pro init                 # installs core + interactive stack selection
npx review-pro init --no-stacks     # core only
```

For local development (no published package yet):
```bash
cd cli && npm install && npm run build
node dist/cli.js init
```

`init` copies each `core/skills/<name>/` to `$OC_HOME/skills/<name>/` and each `core/agents/*.md` to `$OC_HOME/agents/` (`$OPENCODE_HOME` or `~/.config/opencode`). It is cross-platform (Node, no bash) and replaces the old `install.sh`.

> opencode skill loading from `$OC_HOME/skills/` is confirmed. Agent/subagent loading paths can vary by opencode version — after `init`, restart opencode and verify your agents appear.

## Uninstall

```bash
npx review-pro uninstall --target opencode   # removes core skills + agents from $OC_HOME
```

Mirrors `init`'s `--target` logic (`all` / `auto` / comma-list). Removes every `core/skills/<name>/` and `core/agents/*.md` `init` copied into `$OPENCODE_HOME`; leaves your own skills/agents and the `skills/`/`agents/` dirs themselves untouched. Stack packs (`.review-pro/`) are repo-local — `npx review-pro remove <stack>` or `rm -rf .review-pro`.

## Install stacks (per repo)

```bash
npx review-pro             # interactive
npx review-pro add node    # non-interactive
```
Stacks land in the reviewed repo's `.review-pro/`. See `stacks/README.md`.

## Running a review (one command — no scripts required)

In opencode, open the repo you want to review (on the feature branch) and ask the session to review it — e.g. *"review this branch with review-pro"* or invoke the **`review-pro`** skill. The agent does everything with its own tools:

1. **Prep** — runs `git diff`, reads changed files, Globs `.review-pro/*/manifest.json` for active stacks.
2. **Triage** (inline) — dispatch plan: which reviewers + scoped context.
3. **Fan-out** — for each reviewer, reads `.review-pro/<stack>/<reviewer>.md` pack files and passes them as `### Stack signals` to the `<reviewer>-reviewer` subagent (which auto-loads its core skill).
4. **Synthesize** (inline) — one verdict + report.

No `REVIEW_PRO_ROOT`, no env vars, no user-run scripts at review time. (`scripts/review.sh` exists only as an optional debug/CI helper to inspect what review-pro sees.)
