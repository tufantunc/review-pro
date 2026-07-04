# review-pro

[![CI](https://github.com/tufantunc/review-pro/actions/workflows/ci.yml/badge.svg)](https://github.com/tufantunc/review-pro/actions/workflows/ci.yml)
[![npm version](https://img.shields.io/npm/v/review-pro)](https://www.npmjs.com/package/review-pro)
[![website](https://img.shields.io/website?url=https%3A%2F%2Ftufantunc.github.io%2Freview-pro%2F&label=site)](https://tufantunc.github.io/review-pro/)
[![license: MIT](https://img.shields.io/github/license/tufantunc/review-pro)](LICENSE)
[![node](https://img.shields.io/node/v/review-pro)](https://www.npmjs.com/package/review-pro)
[![platforms](https://img.shields.io/badge/platforms-opencode%20%7C%20Cursor%20%7C%20Claude%20Code%20%7C%20Codex-blue)](#install-one-time)

Tiered AI code-review: **triage → relevant specialist reviewers → synthesis**. Built to review code written by AI agents — catching the issues AI-generated code actually ships with (hallucinated APIs, over-engineering, ignored conventions, needless dependencies), not just generic bugs.

## Why

Most "review this" prompts hand one agent the whole diff and ask for everything. review-pro is tiered, so small changes stay cheap and large changes go deep:

- **Triage** classifies the diff, dispatches only the **relevant specialists**, and scopes each one's context — a reviewer gets exactly what it needs (callers, repo search, schema, consumers), not the whole repo.
- **12 specialist reviewers** each own a single concern — `security`, `correctness`, `craft`, `ai-antipatterns`, `dry`, `performance`, `backend`, `frontend`, `a11y`, `db`, `api-contract`, `tests` — and run in parallel, returning structured, evidence-backed findings.
- **Synthesis** dedups overlaps, resolves cross-reviewer conflicts by domain ownership, calibrates severity (anti-overreporting), and emits one verdict: **BLOCK / REQUEST CHANGES / APPROVE**.

The **AI-code anti-patterns** lens is first-class: hallucinated APIs/symbols, invented config keys, needless dependencies, and ignored existing helpers — the failure modes that come from code being written by an agent rather than a person.

## Architecture

```
triage (Stage 1) -> fan-out (Stage 2, parallel specialists) -> synthesis (Stage 3)
```

- **Triage** classifies the diff, picks relevant reviewers, scopes context, emits a dispatch plan.
- **Fan-out** runs only the selected specialists in parallel; each applies its core rubric plus any stack signals from the repo's `.review-pro/`.
- **Synthesis** dedups, weights, resolves conflicts by domain ownership, calibrates severity, emits one verdict.

See `docs/superpowers/specs/2026-06-20-review-pro-design.md` for the full design.

## Install (one-time)

```bash
npx review-pro init                           # opencode (default)
npx review-pro init --target claude-code      # or cursor | codex | all | auto
```
Installs the review-pro core (skills + subagents) into the target platform's home from one canonical source. Codex agents are auto-transformed to TOML; the repo-root `.cursor-plugin/plugin.json` also lets Cursor `/add-plugin` it directly. Then `npx review-pro add <stack>` to install packs into `.review-pro/`, restart the tool, and invoke the **`review-pro`** skill.

**Uninstall** the core with `npx review-pro uninstall --target <platform>` (removes agents + skills from the tool home; stack packs in `.review-pro/` are repo-local — see `npx review-pro remove`).

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
| `capacitor` | framework | 5 | `typescript-react` † |
| `nextjs` | framework | 4 | `typescript-react` |
| `tanstack-start` | framework | 4 | `typescript-react` |
| `react-native` | framework | 4 | `typescript-react` |
| `wordpress` | framework | 5 | `php` |
| `ai-ml` | domain | 6 | (typically `python`) |

See [`stacks/CONTRIBUTING.md`](stacks/CONTRIBUTING.md) to add your own. Every pack is catalog-curated and validated by `scripts/validate.sh`.

† `capacitor` is framework-agnostic and composes on whichever web framework pack is active (React via `typescript-react`, Angular, Vue, …).

## Validate

```bash
./scripts/validate.sh         # structural check: frontmatter, sections, manifest, references
bash scripts/validate.test.sh # validator unit tests
```

## License

MIT. See `LICENSE`.

---

## Acknowledgements

review-pro started from an idea inspired by [cursor/plugins — thermos](https://github.com/cursor/plugins/tree/main/thermos), a two-reviewer Cursor plugin. It is an independent project — not a fork or a drop-in alternative: a tiered 12-reviewer system with stack packs and a cross-platform installer CLI.
