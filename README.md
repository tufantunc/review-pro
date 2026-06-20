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

Complete: foundation + validation harness + shared docs + **all 12 specialist reviewers** + `review-pro` one-command orchestrator + `triage` & `synthesize` skills + subagents + the **opencode** adapter + **stack packs** (`typescript-react`, `node`) + the **`review-pro` CLI** (`npx review-pro`).

Roadmap (post-MVP): Cursor & Claude Code adapters / `init` targets, remote stack registry, `--json` output, pre-commit mode, more stack packs.

## Install (opencode, one-time)

```bash
npx review-pro init          # installs core + interactive stack selection
npx review-pro add node      # or add a stack non-interactively
```
Restart opencode, then in any repo open a branch and invoke the **`review-pro`** skill (or ask the session to review it). The agent does everything else natively.

> Local dev (no published package): `cd cli && npm install && npm run build && node dist/cli.js init`

## Validate

```bash
./scripts/validate.sh         # structural check: frontmatter, sections, manifest, references
bash scripts/validate.test.sh # validator unit tests
```

## License

MIT. See `LICENSE`.
