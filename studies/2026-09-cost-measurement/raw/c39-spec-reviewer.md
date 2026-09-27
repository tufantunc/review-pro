<!-- c39 spec-reviewer; verbatim final answer -->
## Spec findings: none

I checked each requirement in the PR body (`pr-body.md`) against the diff, and each one is met:

- **Regex reorder in `scripts/build-site.js`:** `\s*role="img"` became `role="img"\s*`, and `\s*aria-label="[^"]*"` became `aria-label="[^"]*"\s*`. The trailing trim is `.trimEnd()`, not `/\s+$/`, as the body says. All seven flag SVGs in `docs-src/flags/` share the same `<svg ...>` attribute layout, which fits the body's claim that the regenerated site is byte-identical.
- **Default parameter in `cli/src/lib/catalog.ts`:** the default on `readStackManifest`'s `catalogDir` is gone, and the reason is written above the signature. There are five call sites, three in `cli/src` and two in `cli/tests/catalog.test.ts`, and all of them pass both arguments.
- **Dead imports:** `listCatalogStacks` is gone from `cli/src/commands/update.ts` and `path` is gone from `cli/src/lib/agents.ts`.
- **False positive:** no SonarQube ignore config was added or changed. The diff touches only the four listed files, as the body intends.
- **Out of scope:** the five complexity and nested-ternary findings are left alone as the body says. That's deferred work, not missing work, so I didn't flag it.

The only mismatch is in the text, not the code. The first commit message says "all three callers" and the PR body says five; the body explains that correction itself. Nothing in the diff goes beyond what the spec asks for.
