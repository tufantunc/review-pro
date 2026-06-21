# Releasing

review-pro ships as the **`review-pro`** npm package (source in `cli/`).

## Catalog is snapshotted at build time

`npm run build` copies `stacks/` → `cli/catalog/`, and that catalog is what the published package ships. **A new stack pack is NOT visible to `npx review-pro` users until a new version is published.** Plan releases around meaningful batches rather than per-pack.

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
4. The Publish action builds, tests, and runs `npm publish` using the `NPM_TOKEN` repo secret. Watch the **Actions** tab; the package appears on npmjs.com.

> The tag must match `cli/package.json` `version`. The action does not rewrite versions.

## One-time setup

1. **npm token** — on npmjs.com → Access Tokens → create a **Granular Access Token** (publish permission, scoped to this package) or a classic **Automation** token.
2. **GitHub secret** — repo Settings → Secrets and variables → Actions → New repository secret → name `NPM_TOKEN`, paste the token.
3. **Package name** — confirm `npm view review-pro` is free; if taken, publish under a scope (`@tufantunc/review-pro`) and keep the `bin` name `review-pro`.

## Provenance (optional, recommended)

For a security tool, [npm provenance](https://docs.npmjs.com/generating-provenance-statements) ties the package to this GitHub build. To enable: add `id-token: write` to the publish job's permissions, append `--provenance` to the publish command, and configure the package on npmjs.com. (See the comment in `.github/workflows/publish.yml`.)
