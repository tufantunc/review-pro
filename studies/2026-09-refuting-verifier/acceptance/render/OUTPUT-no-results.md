## Verdict: BLOCK (code)

Spec: skipped, no spec found.

Verification: 0 checked (0 stand, 0 partly refuted, 0 refuted), 10 not checked (10 no independent verifier). Spec findings are not verified.

> No finding in this review cites evidence outside the diff. For a change of this
> size that usually means the review never left the diff — treat the verdict with
> reduced confidence.

### Critical
- [Critical] src/a.ts:10, unauthenticated role change
  impact: the unauthenticated role change harms the caller of src/a.ts
  remedy: fix the unauthenticated role change
  flagged by: 2 reviewers (security, backend)
  verification: not verified (no independent verifier)

### High
- [High] src/a.ts:20, token logged at info level
  impact: the token logged at info level harms the caller of src/a.ts
  remedy: fix the token logged at info level
  flagged by: correctness (security owns severity in this domain but did not flag it, so the severity stays as reported)
  verification: not verified (no independent verifier)

### Medium
- [Medium] src/a.ts:30, discount applied twice
  impact: the discount applied twice harms the caller of src/a.ts
  remedy: fix the discount applied twice
  flagged by: 2 reviewers (security, backend)
  verification: not verified (no independent verifier)
- [Medium] src/a.ts:40, retry loop has no backoff
  impact: the retry loop has no backoff harms the caller of src/a.ts
  remedy: fix the retry loop has no backoff
  flagged by: correctness (performance owns severity in this domain but did not flag it, so the severity stays as reported)
  verification: not verified (no independent verifier)
- [Medium] src/a.ts:50, cache key omits tenant
  impact: the cache key omits tenant harms the caller of src/a.ts
  remedy: fix the cache key omits tenant
  flagged by: correctness
  verification: not verified (no independent verifier)
- [Medium] src/a.ts:60, error swallowed in parser
  impact: the error swallowed in parser harms the caller of src/a.ts
  remedy: fix the error swallowed in parser
  flagged by: correctness
  verification: not verified (no independent verifier)
- [Medium] src/a.ts:70, pagination skips last page
  impact: the pagination skips last page harms the caller of src/a.ts
  remedy: fix the pagination skips last page
  flagged by: correctness
  verification: not verified (no independent verifier)
- [Medium] src/a.ts:80, stale lock never released
  impact: the stale lock never released harms the caller of src/a.ts
  remedy: fix the stale lock never released
  flagged by: correctness
  verification: not verified (no independent verifier)
- [Medium] src/b.ts:5, timezone dropped on save
  impact: the timezone dropped on save harms the caller of src/b.ts
  remedy: fix the timezone dropped on save
  flagged by: correctness
  verification: not verified (no independent verifier)
- [Medium] src/c.ts:5, N+1 query in list view
  impact: the N+1 query in list view harms the caller of src/c.ts
  remedy: fix the N+1 query in list view
  flagged by: correctness (performance owns severity in this domain but did not flag it, so the severity stays as reported)
  verification: not verified (no independent verifier)

### Low
- [Low] src/c.ts:9, variable name misleading
  impact: the variable name misleading harms the caller of src/c.ts
  remedy: fix the variable name misleading
  flagged by: correctness

"Flagged by 2 reviewers" only says how many reviewers saw a finding. It is not evidence that the finding is correct. No findings were merged as duplicates: the ones that share a file and category root are at least 10 lines apart. The Critical and High findings block on their own, and none of them has been verified.
