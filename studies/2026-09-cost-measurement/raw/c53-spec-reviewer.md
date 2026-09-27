<!-- c53 spec-reviewer; verbatim final answer -->
## Spec findings: none

I checked every requirement in the PR body (`/private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/99075928-604e-433b-bc82-95e9c121edc8/scratchpad/cost/work/c53/pr-body.md`) against `git diff main...HEAD`. Each one is met.

- **The split:** `cli/src/lib/doctor.ts` now has `readCatalogVersions`, `checkDrift`, `checkDeclaredPacks` and `checkStrayPacks`. Both pack checks read from one `listPackFiles` set. `diagnose()` now only loops over the installed stacks and collects what the helpers return.
- **Stray-pack rules pinned by tests:** `cli/tests/doctor.test.ts` adds two tests:
  - a known reviewer the manifest does not declare (`db.md`) must return `[]`, so it passes silently;
  - an undeclared, unknown reviewer (`mystery.md`) must produce exactly one `unknown-reviewer` diagnosis, so it is flagged.
- **Coverage setup:**
  - `@vitest/coverage-v8` is added to devDependencies, and `cli/package-lock.json` has matching entries.
  - The new `cli/vitest.config.ts` includes `lcov` in its coverage reporters.
  - `cli/package.json` gains `"coverage": "vitest run --coverage"`.
  - Vitest writes to `coverage/` under `cli/` by default, which gives `cli/coverage/lcov.info`. That is the path `sonar-project.properties` points at, according to the config comment.

Two other changes aren't in the spec, and I didn't count either as scope creep:
- **`.gitignore`:** the new `cli/coverage/` entry is housekeeping for the requested coverage output.
- **`cli/package.json` description:** the `\u2192` escape is swapped for a literal `→` character. It's cosmetic and doesn't change behaviour.

The lockfile also dropped some `libc` fields. That looks like a side effect of the npm version used, not new behaviour.
