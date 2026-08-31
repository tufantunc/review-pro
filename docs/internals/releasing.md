# Cutting a release

Eight releases were cut before this file existed, each from whatever the maintainer remembered at the time. Three things went stale that way and each was found later by accident: `cli/package-lock.json` sat five releases behind at `0.7.0`, `docs/llms.txt` described the wrong reviewer count, and the npm package page did too. None of them broke anything. All three happened because there was no list, so a skipped step left no trace.

What follows is the list. Most of it is already enforced; the value here is the part that is not.

## What is already guarded, and where

Do not re-check these by hand. If one is wrong the run fails and tells you.

| Guarded | By |
|---|---|
| The tag matches `cli/package.json` | `publish.yml`, "Verify tag matches cli/package.json version" |
| All five version fields agree | `scripts/validate.sh`, the version-alignment block |
| The published reviewer count and roster | `scripts/validate.sh`, the published-count guard |
| No fixable Critical vulnerability ships | `publish.yml`, the Grype gate, which blocks the publish |
| The SBOM is generated, signed, and attached | `publish.yml`, the `sbom` and `sbom-assets` jobs |

## The steps

### 1. Bump the version

Five fields across four files. Do `cli/package.json` and the lockfile together, or they drift:

```bash
cd cli && npm version <new-version> --no-git-tag-version
```

That writes `cli/package.json`, `cli/package-lock.json`'s top-level `version`, and its `packages[""].version`. Use `npm version` rather than editing `package.json` by hand: hand-editing is exactly how the lockfile reached `0.7.0` while the package said `1.2.0`.

Then the three plugin manifests, by hand, to the same value:

- `.claude-plugin/marketplace.json`, **two** fields: the top-level `version` and `plugins[0].version`
- `core/.claude-plugin/plugin.json`
- `core/.codex-plugin/plugin.json`

The validator will fail if any of the five disagree, so this is checked, not trusted.

### 2. Decide what the version means

Since 1.0.0 the reviewer roster, the finding schema, the category roots, and the triage and synthesis contracts are stable. Breaking any of them needs a major and an ADR. See [ADR-0005](adr/0005-version-one-point-oh-timing.md).

### 3. Update the surfaces no check reads

Two files describe behaviour and no automated check will notice when they go stale. Both have.

- **`docs/llms.txt`** is hand-written, so the site drift check never reads it.
- **`cli/README.md`** is what npm renders on the package page, and it lives outside `core/`, which is where attention goes.

For the marketing site (`docs-src/i18n/*.json`), the rule is narrower: a change in the **reviewer count** is mandatory, because the published-count guard checks it in seven locales including the ones that spell the number as a word. A change in **behaviour** is not, because the site has never described an axis in prose. That precedent is recorded in [ADR-0006](adr/0006-one-closed-subcategory-list-per-reviewer.md)'s consequences.

### 4. Run everything

```bash
bash scripts/validate.sh
bash scripts/validate.test.sh
cd cli && npm ci && npm test && npx tsc --noEmit && npm run build
node scripts/build-site.js && git status --porcelain docs/
```

The site build must leave no `docs/` drift. `npm run build` snapshots `stacks/` into `cli/catalog/` and `core/` into `cli/plugin/`, so a new stack pack or a changed rubric reaches users only through a release.

### 5. Review the release with review-pro, and read this first

Non-negotiable: it has caught something on every release. But there is a trap that has already produced a false negative, and it will again.

**Reviewer subagents load their skill from the installed plugin, not from your working tree.** Dispatching `review-pro` on a branch that changes a rubric reviews the *old* rubric. The failure is silent and looks exactly like the new rule not working: the reviewer says nothing about a rule it never saw.

Check what is installed before trusting a review of a rubric change:

```bash
grep -c "<a distinctive string from your change>" ~/.claude/skills/*/SKILL.md
```

When the installed copy is behind, dispatch a general-purpose agent instead and tell it to read the branch's rubric and agent body by absolute path, and that those files win over anything already in its context. That is the same inline path `core/skills/review-pro/SKILL.md` documents for platforms without subagents.

One more hazard from experience: a review subagent can leave the working tree on another branch. Check `git branch --show-current` before trusting any verification you run after a review.

### 6. Merge, then tag

The tag is what publishes. Nothing before it does.

```bash
git tag -a v<new-version> -m "<what changed and why>"
git push origin v<new-version>
```

Release notes come from commit history via `--generate-notes`, which is why Conventional Commits matter here specifically.

### 7. Verify what actually shipped

A local build proving the content is present is not the same claim as the published package carrying it. Install from npm into a throwaway home and look:

```bash
H=$(mktemp -d); mkdir -p "$H/repo" && cd "$H/repo" && git init -q
HOME="$H" npx -y review-pro@<new-version> init --no-stacks -t claude-code
grep -rl "<a distinctive string from your change>" "$H/.claude" | wc -l
```

Also confirm npm shows the new version as `latest` and that provenance was attested:

```bash
npm view review-pro version
npm view review-pro dist.attestations.provenance
```

## There is no rollback

npm versions are immutable and a published version cannot be replaced. A broken release is fixed by publishing the next patch, never by deleting a tag or a version. Deleting the tag leaves the bad version on npm and removes the only record of where it came from.

The `sbom` job is deliberately separate from `publish` for the same reason: anything that can fail *after* `npm publish` returns has to be re-runnable without going near the publish path again.

## What the numbers should look like

Read these as a shape, not a target. They are here so an unexpected drop is visible:

- validator: `OK: all artifacts valid`
- meta-tests: 119 assertions at the time of writing, only ever growing
- CLI tests: 72 at the time of writing
- site: 14 pages across 7 languages, no drift
