# review-pro

Tiered AI code-review: **triage → relevant specialist reviewers → synthesis**. Reviews code written by AI agents, using AI agents. An open-source, cross-platform alternative to [cursor/plugins — thermos](https://github.com/cursor/plugins/tree/main/thermos).

## Why

`thermos` runs two reviewers on every review. review-pro runs a **triage** stage first, then dispatches only the **relevant specialists**, each with **scoped context** (not the whole diff), then **synthesizes** one verdict. This keeps small PRs cheap and large PRs deep, and adds an **AI-code anti-patterns** lens that thermos lacks.

## Architecture

```
triage (Stage 1) -> fan-out (Stage 2, parallel specialists) -> synthesis (Stage 3)
```

- **Triage** classifies the diff, picks relevant reviewers, scopes context, emits a dispatch plan.
- **Fan-out** runs only the selected specialists in parallel; each applies its core rubric plus any stack signals from the repo's `.review-pro/`.
- **Synthesis** dedups, weights, resolves conflicts by domain ownership, calibrates severity, emits one verdict.

See `docs/superpowers/specs/2026-06-20-review-pro-design.md` for the full design.

## Status (v0.1 — MVP)

Complete: foundation + validation harness + shared docs + **all 12 specialist reviewers** + `review-pro` one-command orchestrator + `triage` & `synthesize` skills + subagents + the **opencode** adapter + **stack packs** (`typescript-react`, `node`).

Roadmap (post-MVP): `npx review-pro-stack` community CLI (separate repo) for per-repo stack install across any language/framework (.NET, Flutter, Go, Rust…), Cursor & Claude Code adapters, SARIF / PR-comment output, pre-commit mode.

## Install (opencode, one-time)

```bash
bash adapters/opencode/install.sh
```
Copies `core/skills/**` and `core/agents/**` into `$OC_HOME/` for opencode discovery. Stack packs are **not** part of the plugin — they live per repo (see below).

## Install stacks (per repo)

Stack packs add language/framework-specific signals. Install them into the reviewed repo's `.review-pro/`:

```bash
# via the community CLI (separate package, when shipped):
npx review-pro-stack
# or manually for now:
mkdir -p .review-pro && cp -R ~/path/to/review-pro/stacks/node .review-pro/node
```
See `stacks/README.md`.

## Run a review (one command — no scripts required)

In opencode, open the repo you want to review (on the feature branch) and ask the session to review it, or invoke the **`review-pro`** skill. The agent runs the whole pipeline with its own tools — `git diff`, reads changed files, Globs `.review-pro/` for active stacks, dispatches reviewers (passing stack signals), and synthesizes the verdict. No env vars, no user-run scripts.

## Validate

```bash
./scripts/validate.sh         # structural check: frontmatter, sections, manifest, references
bash scripts/validate.test.sh # validator unit tests
```

## License

MIT. See `LICENSE`.
