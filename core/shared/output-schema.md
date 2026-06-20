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
  overlap_hints: [backend.authz, correctness.logic]   # for synthesis dedup
```

## Category roots (use these as the `<domain>` prefix)

`security`, `correctness`, `craft`, `ai-antipatterns`, `dry`, `performance`, `backend`, `frontend`, `a11y`, `db`, `api-contract`, `tests`.

Rules:
- `file` + `line` are mandatory for every finding.
- `evidence` must be a real excerpt, not a paraphrase.
- `overlap_hints` lists other category roots that might flag the same spot — this is what the synthesizer uses to collapse duplicates.
