# Finding output schema (shared)

Every specialist returns zero or more finding blocks in this exact shape so the synthesizer can dedup and weight them.

```
- severity: High                 # Critical | High | Medium | Low | Nitpick
  category: security.authz       # <domain>.<subdomain>
  file: src/api/orders.ts
  line: 42
  title: missing ownership check on order update
  evidence: |
    <minimal code excerpt proving the issue>
  impact: <concrete, traced impact>
  remedy: <actionable fix>
  confidence: high               # high | medium | low
  evidence_refs: [src/auth/guard.ts:88]   # optional; files the evidence came FROM
  overlap_hints: [backend.authz, correctness.logic]   # for synthesis dedup
```

## Category roots (use these as the `<domain>` prefix)

`security`, `correctness`, `craft`, `ai-antipatterns`, `dry`, `performance`, `backend`, `frontend`, `a11y`, `db`, `api-contract`, `tests`, `spec`.

Rules:
- `file` + `line` are mandatory for every finding.
- `evidence` must be a real excerpt, not a paraphrase.
- On the **spec axis only**, `file` may be a non-repository reference (`#412`, a PR url) with `line: 0`, for a requirement the diff never attempted. Synthesis accepts it and must not downgrade the finding for failing to resolve on disk.
- `evidence_refs` is optional and lists `<path>:<line>` for every file the evidence was **located in**, when that differs from `file` — a caller, an existing guard, a canonical helper, a schema, an upstream source. `file`/`line` stays the finding's own location. Populate it whenever you left the diff to establish the finding; synthesis counts it.
- `impact` and `remedy` are held to the same evidence bar as the finding itself. If either asserts that something **cannot** be done — an API is unavailable, a helper cannot express a case, a constant is unreachable — locate that too, or drop the assertion. A correct finding with an unverified rationale sends the reader into unnecessary work.
- `overlap_hints` lists other category roots that might flag the same spot — this is what the synthesizer uses to collapse duplicates.
