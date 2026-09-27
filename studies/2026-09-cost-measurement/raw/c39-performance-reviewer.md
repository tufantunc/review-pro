<!-- c39 performance-reviewer; verbatim final answer -->
I read all four changed files and checked the PR's regex claims by timing them in node. The change adds no performance regressions.

**What the timings showed**, on a run of spaces with no match (the worst case the PR describes):

| Input size | Old `/\s*role="img"/g` | New `/role="img"\s*/g` | Old `/\s+$/` | `trimEnd()` |
|---|---|---|---|---|
| 8k | 27.1ms | 0.0ms | 35.2ms | 0.0ms |
| 16k | 111.6ms | 0.0ms | 137.0ms | 0.0ms |
| 32k | 449.2ms | 0.0ms | 540.5ms | 0.0ms |

- **Old patterns are quadratic:** time grows about 4x each time the input doubles. The PR's figure of about 500ms at 32k for `/\s+$/` matches what I got (540ms).
- **New patterns are linear:** both new regexes and `trimEnd()` stayed at 0.0ms at every size.
- **`aria-label="[^"]*"\s*` is linear too.** Its literal prefix ends in a `"`, so each scan can only run up to the next quote. Scans from different matches therefore can't overlap, and there's no quadratic case. A test with 2,666 back-to-back unterminated prefixes took 0.0ms.
- **Real-world scale:** `loadFlags` runs once per build over the 7 SVGs in `docs-src/flags/`, each with a root tag of about 90 characters (I checked `en.svg`). The old code was never slow in practice. The change only removes worst-case risk, and this is a build script outside the npm package.

**CLI files:** `cli/src/commands/update.ts` and `cli/src/lib/agents.ts` only drop unused imports. `cli/src/lib/catalog.ts` removes an unreachable default parameter from `readStackManifest`, and every caller already passes `catalogDir`. None of this changes performance.

## Performance findings: none

## Files examined
examined: [cli/src/commands/update.ts, cli/src/lib/agents.ts, cli/src/lib/catalog.ts, scripts/build-site.js]
not_examined: []
