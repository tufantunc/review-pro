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

Complete: foundation + validation harness + shared docs + **12 specialist reviewers** + `review-pro` one-command orchestrator + `triage` & `synthesize` skills + subagents + the **`review-pro` CLI** (`npx review-pro`) + **cross-platform `init`** (opencode, Claude Code, Cursor, Codex) + **14 stack packs**.

Roadmap (post-MVP): `npx review-pro` npm publish (currently local build), pre-commit mode, CI/headless execution mode (the prerequisite for `--json`/SARIF output), more stack packs.

## Install (one-time)

```bash
npx review-pro init                           # opencode (default)
npx review-pro init --target claude-code      # or cursor | codex | all | auto
```
Installs the review-pro core (skills + subagents) into the target platform's home from one canonical source. Codex agents are auto-transformed to TOML; the repo-root `.cursor-plugin/plugin.json` also lets Cursor `/add-plugin` it directly. Then `npx review-pro add <stack>` to install packs into `.review-pro/`, restart the tool, and invoke the **`review-pro`** skill.

## Stack packs (catalog)

Packs add language/framework-specific signals to reviewers. Install into a repo with `npx review-pro add <stack>`. **Framework/domain packs compose on top of a language pack** (e.g. a Next.js repo activates `typescript-react` + `nextjs`).

| Pack | Type | Reviewers | Composes on |
|---|---|---:|---|
| `typescript-react` | language | 8 | — |
| `node` | language | 7 | — |
| `python` | language | 8 | — |
| `go` | language | 6 | — |
| `dotnet` | language | 6 | — |
| `rust` | language | 6 | — |
| `php` | language | 7 | — |
| `kotlin` | language | 6 | — |
| `swift` | language | 6 | — |
| `flutter` | framework | 4 | — |
| `nextjs` | framework | 4 | `typescript-react` |
| `react-native` | framework | 4 | `typescript-react` |
| `wordpress` | framework | 5 | `php` |
| `ai-ml` | domain | 6 | (typically `python`) |

See `stacks/CONTRIBUTING.md` to add your own. Every pack is catalog-curated and validated by `scripts/validate.sh`.

## Validate

```bash
./scripts/validate.sh         # structural check: frontmatter, sections, manifest, references
bash scripts/validate.test.sh # validator unit tests
```

## License

MIT. See `LICENSE`.
