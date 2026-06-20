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

## Status (v0.1)

Working slice: foundation + validation harness + shared docs + `security` & `craft` reviewers + `triage` & `synthesize` orchestrators + subagents + the **opencode** adapter.

Roadmap: 10 more reviewers (Phase 2), stack packs `typescript-react` & `node` (Phase 3), Cursor & Claude Code adapters, SARIF / PR-comment output, pre-commit mode.

## Install (opencode)

```bash
bash adapters/opencode/install.sh
```
See `adapters/opencode/README.md` for details and agent-loading notes.

## Configure (optional, per repo)

Copy `review-pro.config.example` to `review-pro.config` and edit (enabled reviewers, severity gate, thresholds, base branch, ignore globs, stack packs).

## Validate

```bash
./scripts/validate.sh         # structural check: frontmatter, sections, manifest, references
bash scripts/validate.test.sh # validator unit tests
```

## License

MIT. See `LICENSE`.
