# Contributing to review-pro

Thanks for looking. review-pro is a tiered AI code-review system — **triage → relevant specialist reviewers → synthesis** — built to catch what AI-written code actually ships with.

Most of it is plain markdown. You do not need to be a TypeScript developer to make it meaningfully better.

## Where things live

| Path | What it is |
|---|---|
| `core/skills/` | The 12 reviewer rubrics + the 3 orchestrator skills. **The product.** |
| `core/agents/` | Subagent definitions that load a skill each |
| `stacks/<pack>/` | Language/framework signal packs layered on top of a reviewer rubric |
| `adapters/` | Per-platform transforms (e.g. Codex TOML) |
| `cli/` | The `npx review-pro` installer (TypeScript, published to npm) |
| `docs-src/` → `docs/` | The site. **`docs/` is generated** — never edit it by hand |
| `scripts/` | `validate.sh`, `build-site.js`, and their tests |
| `studies/` | Pre-registered evaluations of review-pro against real agent-authored PRs — methodology and hand-verified findings |

## The four kinds of contribution

### 1. Sharpen a reviewer rubric — highest value

A signal earns its place if it is **concrete and falsifiable**. "Be careful with error handling" is noise; "`await` inside a `for` loop over a query result → N+1" is a signal.

Edit `core/skills/<reviewer>/SKILL.md`. If the signal is stack-specific, it belongs in a stack pack instead.

### 2. Add or improve a stack pack

See **[`stacks/CONTRIBUTING.md`](stacks/CONTRIBUTING.md)** for the full pack format, manifest rules, and authoring checklist.

Note the release coupling: `npm run build` snapshots `stacks/` → `cli/catalog/`, so a new pack reaches `npx review-pro` users only on the next published version.

### 3. Report a false positive or a miss

These are the most useful bug reports this project gets, and they need no code. Open an issue with the code that was flagged (or missed) and what the correct call would have been. Rubrics get calibrated from real examples, not from theory.

### 4. Fix the CLI

```bash
cd cli
npm ci
npm run build
npm test          # vitest
```

## Before you open a PR

```bash
./scripts/validate.sh          # frontmatter, sections, manifest, cross-references
bash scripts/validate.test.sh  # validator's own tests
cd cli && npm test             # CLI tests
```

If you touched `docs-src/`, rebuild and commit the generated site — CI asserts there is no drift:

```bash
node scripts/build-site.js
git add docs
```

CI runs all of the above plus CodeQL. A red check is a blocked merge.

## Commit messages

Conventional Commits, because release notes are generated from history:

```
feat(cli): add uninstall command
fix(reviewers): harden subagent bodies against derailment
docs(site): add uninstall to commands table
chore(deps): bump commander
```

Scopes in use: `cli`, `reviewers`, `stacks`, `site`, `docs`, `ci`, `deps`.

## Adding a new reviewer

A new reviewer is a larger change — open an issue first. It requires a skill in `core/skills/`, an agent in `core/agents/`, entries in `manifest.json`, triage dispatch rules, synthesis domain-ownership rules, and a decision about which existing packs should cover it.

The bar: the concern must not already be owned by one of the 12, and triage must be able to tell when it is relevant. Reviewers that fire on everything make the whole system noisier.

## Releasing

Maintainers only — see [`RELEASING.md`](RELEASING.md).

## Reporting security issues

Do **not** open a public issue. See [`SECURITY.md`](SECURITY.md).

## License

By contributing you agree your contributions are licensed under the [MIT License](LICENSE).
