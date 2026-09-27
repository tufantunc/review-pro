<!-- c53 performance-reviewer; verbatim final answer -->
## Performance findings: none

This change doesn't make performance worse. It slightly improves it.

- **Fewer filesystem calls:** before, `diagnose()` checked each declared reviewer with its own `fs.existsSync`, then listed the stack directory separately. Now `listPackFiles` (`/private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/99075928-604e-433b-bc82-95e9c121edc8/scratchpad/fd/work/c53/repo/cli/src/lib/doctor.ts:32-35`) makes one `existsSync` and one `readdirSync` per stack. Both pack checks then use the same in-memory `Set`, so a stack with R declared reviewers goes from R+2 calls to 2.
- **Loop cost is unchanged:** `checkDeclaredPacks` and `checkStrayPacks` still do linear `knownReviewers.includes` / `m.reviewers.includes` lookups, as the old code did. These lists hold a handful of reviewers and stacks, so the cost is negligible.
- **Spreading results into `out.push(...)`:** each helper returns an array with at most a few entries, so this has no realistic cost.
- **Not a hot path:** `diagnose()` has one caller, `cli/src/commands/doctor.ts:10`, which runs once per `doctor` command. Nothing here runs per request or per render, reads unbounded data, or leaves listeners or timers behind.

## Files examined
examined: [cli/src/lib/doctor.ts]
not_examined: []
