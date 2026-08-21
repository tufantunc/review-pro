# Releasing

review-pro ships as the **`review-pro`** npm package (source in `cli/`).

## Catalog is snapshotted at build time

`npm run build` copies `stacks/` → `cli/catalog/`, and that catalog is what the published package ships. **A new stack pack is NOT visible to `npx review-pro` users until a new version is published.** Plan releases around meaningful batches rather than per-pack.

## Site (GitHub Pages)

The marketing/docs site under `docs/` is **generated** from `docs-src/` (tokenized templates + `i18n/*.json` dictionaries + flags + `detect.js`) by `scripts/build-site.js`. After editing any source, rebuild and commit the output:

```bash
node scripts/build-site.js
git add docs
git commit -m "feat(site): rebuild generated site"
```

CI runs `node --test scripts/build-site.test.js` and asserts `git diff --exit-code docs` is clean (no uncommitted drift between `docs-src/` and `docs/`). English lives at the root (`/review-pro/`); other languages in `docs/<lang>/`.

## Version policy (semver)

| Change | Bump | Example |
|---|---|---|
| Bug fix, docs, pack-content tweak (signal/severity refinement) | patch (`0.1.0 → 0.1.1`) | sharpen a security signal |
| New stack pack, new CLI command/flag, new reviewer | minor (`0.1.0 → 0.2.0`) | `php` + `wordpress` packs |
| Breaking: pack/reviewer rename or removal, CLI behavior/schema break | major (`0.x → 1.0.0`) | splitting a reviewer |

## Publish flow (tag-triggered)

Publishing is triggered by a `v*` tag, never by a branch push. CI (`.github/workflows/ci.yml`) runs build + tests on every push; only `.github/workflows/publish.yml` publishes, and only on a tag.

1. Bump `cli/package.json` `version`.
2. Commit: `git commit -am "release: vX.Y.Z"`.
3. Tag and push:
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
4. The Publish action builds, tests, verifies the tag matches `cli/package.json`, runs `npm publish --provenance`, and creates the **GitHub Release** with generated notes. Watch the **Actions** tab; the package appears on npmjs.com.

> The tag must match `cli/package.json` `version` — the workflow fails fast if it doesn't. The action never rewrites versions.

Release notes come from `--generate-notes`, which groups merged PRs by title. Conventional Commit titles (`feat(cli): …`, `fix(reviewers): …`) are what make that output readable.

## Plugin manifests to bump alongside the version

Four files carry a version and are **not** bumped automatically:

| File | Field |
|---|---|
| `cli/package.json` | `version` |
| `.claude-plugin/marketplace.json` | `version` and `plugins[0].version` |
| `core/.claude-plugin/plugin.json` | `version` |
| `core/.codex-plugin/plugin.json` | `version` |

`scripts/validate.sh` fails when these disagree, so a forgotten one is a red build
rather than a wrong number in a directory listing.

`.cursor-plugin/plugin.json` carries its own independent version. Validate the Claude Code manifests after editing:

```bash
claude plugin validate .        # marketplace manifest
claude plugin validate ./core   # plugin manifest
```

## One-time setup

1. **npm token** — on npmjs.com → Access Tokens → create a **Granular Access Token** (publish permission, scoped to this package) or a classic **Automation** token.
2. **GitHub secret** — repo Settings → Secrets and variables → Actions → New repository secret → name `NPM_TOKEN`, paste the token.
3. **Package name** — confirm `npm view review-pro` is free; if taken, publish under a scope (`@tufantunc/review-pro`) and keep the `bin` name `review-pro`.

## Provenance (enabled)

[npm provenance](https://docs.npmjs.com/generating-provenance-statements) is on: the publish job has `id-token: write` and publishes with `--provenance`, so every release carries a signed attestation tying the tarball to this repo and workflow. npmjs.com shows a **Provenance** section on the package page.

If a publish fails with an OIDC or provenance error, check that (a) the job still has `id-token: write`, and (b) the `repository.url` in `cli/package.json` still matches this repo — provenance verification compares them.
