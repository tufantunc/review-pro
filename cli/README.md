# review-pro

[![npm version](https://img.shields.io/npm/v/review-pro)](https://www.npmjs.com/package/review-pro)
[![CI](https://github.com/tufantunc/review-pro/actions/workflows/ci.yml/badge.svg)](https://github.com/tufantunc/review-pro/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/github/license/tufantunc/review-pro)](https://github.com/tufantunc/review-pro/blob/main/LICENSE)

> **review-pro** is a tiered AI code-review system: **triage → relevant specialist reviewers → synthesis**. It reviews code written by AI agents, using AI agents — built to catch the failure modes AI-generated code actually ships with (hallucinated APIs, over-engineering, ignored conventions, needless dependencies).
>
> **This package** is the installer CLI (`npx review-pro`). It installs the review-pro core (skills + subagents) into your agent tool, and the stack packs into your repo's `.review-pro/`.

🌐 **Landing page:** https://tufantunc.github.io/review-pro/
📦 **Source & full docs:** https://github.com/tufantunc/review-pro

---

## Install (one-time)

Installs the review-pro core — 12 specialist reviewer skills + subagents + the `review-pro` orchestrator — into your agent tool's home, from one canonical source.

```bash
npx review-pro init                           # opencode (default)
npx review-pro init --target claude-code      # or cursor | codex | all | auto
```

Supported targets: **opencode · Claude Code · Cursor · Codex**. Codex agents are auto-transformed to TOML; Cursor can also `/add-plugin` the repo directly.

**No Node.js?** review-pro is plain markdown skills and agents — you can copy them into your tool's folder and it works the same. See the [manual install steps](https://github.com/tufantunc/review-pro#readme) for each platform.

## Add stack packs

Stack packs layer language/framework-specific signals onto the reviewers at review time. Install the ones you use into the repo you review:

```bash
npx review-pro                # interactive multi-select
npx review-pro add python     # or: node, go, rust, typescript-react, dotnet, php,
                              #     kotlin, swift, flutter, nextjs, react-native,
                              #     wordpress, ai-ml
npx review-pro list           # show catalog + installed versions
npx review-pro doctor         # check drift / roster integrity
```

Packs land in the reviewed repo's `.review-pro/` and carry their own version.

## Run a review

Restart your tool so the new skills/agents are discovered, then in the repo you want to review:

- open a branch and ask the session to **"review this branch with review-pro"**, or
- invoke the **`review-pro`** skill directly.

The agent runs the whole pipeline natively (`git diff`, reads changed files, Globs `.review-pro/` for active stacks, dispatches the relevant reviewer subagents with their stack signals, and synthesizes one verdict: **BLOCK / REQUEST CHANGES / APPROVE**). No env vars, no scripts to run at review time.

## Commands

| Command | What it does |
| --- | --- |
| `npx review-pro` | interactive — select stacks to install into `.review-pro/` |
| `init [--target <platform>]` | install the core plugin into a tool's home |
| `add <stack>` | install one stack pack (non-interactive, CI-safe) |
| `remove <stack>` | remove an installed pack |
| `update [stack]` | refresh installed packs to the catalog version |
| `list` | show catalog stacks + installed versions + drift |
| `doctor` | validate installed packs (version drift, roster integrity, orphans) |

## Requirements & license

- Node ≥ 18 (for this CLI only; manual install needs no Node).
- MIT — see [LICENSE](https://github.com/tufantunc/review-pro/blob/main/LICENSE).

## 12 specialist reviewers

`security` · `correctness` · `craft` · `ai-antipatterns` · `dry` · `performance` · `backend` · `frontend` · `a11y` · `db` · `api-contract` · `tests`

The **`ai-antipatterns`** reviewer is first-class: hallucinated APIs/symbols/imports, invented config/env keys, needless dependencies, and ignored existing helpers — the failure modes that come from code being written by an agent rather than a person.
