# Contributing to review-pro

Thanks for looking. review-pro is a tiered AI code-review system — **triage → relevant specialist reviewers → synthesis** — built to catch what AI-written code actually ships with.

Most of it is plain markdown. You do not need to be a TypeScript developer to make it meaningfully better.

## Where things live

| Path | What it is |
|---|---|
| `core/skills/` | The 13 reviewer rubrics + the 3 orchestrator skills. **The product.** |
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
./scripts/validate.sh          # frontmatter, sections, manifest, cross-references, .review-pro/rules.md format
bash scripts/validate.test.sh  # validator's own tests
cd cli && npm test             # CLI tests
```

If you touched `docs-src/`, rebuild and commit the generated site — CI asserts there is no drift:

```bash
node scripts/build-site.js
git add docs
```

CI runs all of the above plus CodeQL. A red check is a blocked merge.

## What the validator guards

`scripts/validate.sh` holds the contracts between files, not the wording of each rule ([ADR-0013](docs/internals/adr/0013-guard-contracts-not-prose.md)). Before adding a check, ask one question: **if this text changes, does a consumer break?** A consumer is a parser, a copy of the same text in another file, a key or line that synthesis reads, or the release process. Five kinds of check pass that test:

1. **Structure:** frontmatter, required sections, manifest and roster integrity, cross-references and file existence, version fields, the published reviewer count, the closed category lists (ADR-0006, ADR-0007).
2. **Canonical copies:** text that must stay the same in several files (ADR-0001): a block held once in the validator, such as the `## Files examined` block or the pack-file-is-data line, a rule an agent body repeats from its rubric, or a rule another file says it repeats, such as `core/shared/severity.md`'s verdict table.
3. **Order and position:** the report's header order, the changed files as the prompt's last section, the rules cap before verification.
4. **Formats a consumer reads:** none-lines, verdict tables and labels, plan keys, the canonical `Coverage (self-reported):` line.
5. **The validator's own mechanics:** an error is counted, an unreadable section is reported, a sourced file is present.

Do not add a check whose only job is to show that a sentence is still there. It catches a deleted rule but not a weakened one, and every later edit to that sentence then needs a validator edit too. Removing or softening an instruction in `core/` is left to review instead: under rule R9 in `.review-pro/rules.md`, its owner reports each one from the diff, quoting the sentence before and after, as a finding capped at Medium that a maintainer accepts when the change is deliberate. That is a weaker guard than a red build, because a reviewer can miss a softening. Each check that does pass the question gets a mutation test in `scripts/validate.test.sh` that breaks it alone.

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

The bar: the concern must not already be owned by one of the 13, and triage must be able to tell when it is relevant. Reviewers that fire on everything make the whole system noisier.

## Releasing

Maintainers only, see [`docs/internals/releasing.md`](docs/internals/releasing.md).

## Reporting security issues

Do **not** open a public issue. See [`SECURITY.md`](SECURITY.md).

## License

By contributing you agree your contributions are licensed under the [MIT License](LICENSE).

Decisions that were expensive to make are recorded in [docs/internals/adr/](docs/internals/adr/); read the relevant ADR before proposing to reverse one, and add an ADR when your change makes such a decision.
