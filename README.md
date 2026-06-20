# review-pro

Tiered AI code-review: **triage → relevant specialist reviewers → synthesis**. Reviews code written by AI agents, using AI agents. An open-source, cross-platform alternative to [cursor/plugins — thermos](https://github.com/cursor/plugins/tree/main/thermos).

## Why

`thermos` runs two reviewers on every review. review-pro runs a **triage** stage first, then dispatches only the **relevant specialists**, each with **scoped context** (not the whole diff), then **synthesizes** one verdict. This keeps small PRs cheap and large PRs deep, and adds an **AI-code anti-patterns** lens that thermos lacks.

## Architecture

```
triage (Stage 1) -> fan-out (Stage 2, parallel specialists) -> synthesis (Stage 3)
```

- **Triage** classifies the diff, picks relevant reviewers, detects active stacks, scopes context, emits a dispatch plan.
- **Fan-out** runs only the selected specialists in parallel; each loads an effective rubric = core skill + active stack packs.
- **Synthesis** dedups, weights, resolves conflicts by domain ownership, calibrates severity, emits one verdict.

See `docs/superpowers/specs/2026-06-20-review-pro-design.md` for the full design.

## Status (v0.1 — MVP)

Complete: foundation + validation harness + shared docs + **all 12 specialist reviewers** + `review-pro` one-command orchestrator + `triage` & `synthesize` skills + subagents + the **opencode** adapter + **stack packs** (`typescript-react`, `node`).

Roadmap (post-MVP): Cursor & Claude Code adapters, SARIF / PR-comment output, pre-commit mode, more stack packs (python, go, rust), and a self-contained installed-plugin layout.

## Install (opencode)

```bash
bash adapters/opencode/install.sh
```
The shim copies `core/skills/**` and `core/agents/**` into `$OC_HOME/` for opencode discovery. Stack packs and the `review.sh` / `compose-rubric.sh` helpers live in the plugin repo and are used from there (the directory layout must stay intact for cross-references and composition). See `adapters/opencode/README.md`.

## Run a review (one command)

In opencode, open the repo you want to review (on the feature branch) and ask the session to review it, or invoke the **`review-pro`** skill:

```bash
export REVIEW_PRO_ROOT=~/Desktop/Projects/Personal/review-pro   # so the agent finds scripts/ + stacks/
```

The orchestrator runs: prep → triage → fan-out (composed stack-aware rubrics per reviewer) → synthesis → verdict.

## Configure (optional, per repo)

Copy `review-pro.config.example` to `review-pro.config` and edit (enabled reviewers, severity gate, thresholds, base branch, ignore globs, stack packs).

## Validate

```bash
./scripts/validate.sh         # structural check: frontmatter, sections, manifest, references
bash scripts/validate.test.sh # validator unit tests
```

## License

MIT. See `LICENSE`.
