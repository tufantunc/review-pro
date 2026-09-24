## Verdict: BLOCK (code), 1 disputed

Spec: skipped, no spec found.

Verification: 5 checked (1 stand, 1 partly refuted, 3 refuted), 5 not checked (3 error, 2 cap). Spec findings are not verified.

```
> No finding in this review cites evidence outside the diff. For a change of this
> size that usually means the review never left the diff — treat the verdict with
> reduced confidence.
```

### Critical
- [Critical] src/a.ts:10, unauthenticated role change
  impact: the unauthenticated role change harms the caller of src/a.ts
  remedy: fix the unauthenticated role change
  flagged by: security, backend
  verification: disputed
  refuted: "the whole finding: requireAdmin runs first"
  contradicted by: src/a.ts:8 `router.use(requireAdmin)`
  still blocks. One refutation does not clear a blocker, so a human must clear this finding.

### High
- [High] src/a.ts:20, token logged at info level
  impact: the token logged at info level harms the caller of src/a.ts
  remedy: fix the token logged at info level
  flagged by: correctness
  verification: verified

### Medium
- [Medium] src/a.ts:40, retry loop has no backoff
  impact: the retry loop has no backoff harms the caller of src/a.ts
  remedy: fix the retry loop has no backoff
  flagged by: correctness
  verification: partly refuted
  falls: the remedy's jitter claim
  contradicted by: src/retry.ts:3 `jitter: true`
  stands: the defect

- [Medium] src/a.ts:60, error swallowed in parser
  impact: the error swallowed in parser harms the caller of src/a.ts
  remedy: fix the error swallowed in parser
  flagged by: correctness
  verification: not verified (error)

- [Medium] src/a.ts:70, pagination skips last page
  impact: the pagination skips last page harms the caller of src/a.ts
  remedy: fix the pagination skips last page
  flagged by: correctness
  verification: not verified (error)

- [Medium] src/a.ts:80, stale lock never released
  impact: the stale lock never released harms the caller of src/a.ts
  remedy: fix the stale lock never released
  flagged by: correctness
  verification: not verified (error)

- [Medium] src/b.ts:5, timezone dropped on save
  impact: the timezone dropped on save harms the caller of src/b.ts
  remedy: fix the timezone dropped on save
  flagged by: correctness
  verification: not verified (cap)

- [Medium] src/c.ts:5, N+1 query in list view
  impact: the N+1 query in list view harms the caller of src/c.ts
  remedy: fix the N+1 query in list view
  flagged by: correctness
  verification: not verified (cap)

### Low
- [Low] src/c.ts:9, variable name misleading
  impact: the variable name misleading harms the caller of src/c.ts
  remedy: fix the variable name misleading
  flagged by: correctness

### Refuted in verification
- [Medium] src/a.ts:30, discount applied twice
  refuted: "the whole finding: checkout() reads the discounted total"
  contradicted by: src/cart/checkout.ts:12 `const total = cart.total // already discounted`
  flagged by: security, backend (a coverage note only, it does not outweigh the refutation)
  noticed (not reviewed): rounding untested

- [Medium] src/a.ts:50, cache key omits tenant
  refuted: "the tenant is in the key prefix"
  contradicted by: src/a.ts:48 `key = tenant + id`

---

How each reply was applied:
- **R1:** `refuted`/`no` means refuted. The finding is Critical, so it is marked `disputed` and still blocks.
- **R2:** `stands`/`yes` means stands, so the finding is marked verified.
- **R3:** `refuted`/`no` means refuted. The finding is Medium, so it moves to Refuted in verification. Its noticed line goes under it.
- **R4:** `partly_refuted`/`yes` means partly refuted. Severity stays the same, and what falls is shown with its citation.
- **R5:** `partly_refuted`/`no` means refuted. The finding is Medium, so it moves to Refuted in verification.
- **R6:** `stands`/`no` is an inconsistent pair, so the finding is not verified (error).
- **R7:** the reply carried two blocks, which the Binding rule treats as an error.
- **R8:** the key `src/a.ts:81` matches no finding, because the lock finding is at line 80 and binding needs an exact match. That leaves the finding at src/a.ts:80 not verified (error).
- **F9 and F10:** these were past the cap of 8, so both are not verified (cap).

Other checks:
- **Out-of-diff check:** none of the findings has an `evidence_refs` field, and every evidence excerpt cites a changed file. The count is zero on a `substantive` diff, so the caveat fires. The verifiers' citations outside the diff (src/cart/checkout.ts, src/retry.ts) are not the findings' own evidence and do not count.
- **Omitted sections:** `external_premises` is empty and `premises_dropped` is 0, so there is no External premises section. `spec_source.kind: none`, so there is no Spec section.
- **Category roots:** security, correctness, performance and craft are all on the listed roots, so there is no contract violation.
- **Em dash:** the caveat is quoted word for word from the skill's fixed text, so it keeps its em dash.
