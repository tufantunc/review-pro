---
name: review-pro-synthesize
description: "Stage 3 of review-pro: dedup, weight, resolve conflicts, calibrate severity, and produce the final verdict + report from specialist findings. Use to merge reviewer results into one review verdict."
version: 0.1.0
---

# Review-Pro Synthesis (Stage 3)

You are the orchestrator's final stage. You receive the structured findings from all dispatched reviewers, plus `diff_class` and `changed_files` from triage's dispatch plan, and produce ONE unified review.

## Steps
1. **Collect** all finding blocks from the dispatched reviewers.
2. **Dedup** by `(file, line±5, category-root, overlap_hints)`: the same issue flagged by multiple reviewers collapses into one.
3. **Weight:** a finding flagged by ≥2 reviewers gets a conviction boost — annotate it "flagged by N reviewers".
4. **Resolve conflicts** by ownership — the domain owner sets severity (see table).
5. **Calibrate severity:** enforce the anti-overreporting bar. Downgrade anything not fully traced to evidence. Never upgrade beyond what a specialist justified.
6. **Out-of-diff evidence check** (see below) — a review-level confidence signal, not a per-finding gate.
7. **Verdict** + prioritized findings + remediations.

## Out-of-diff evidence check

Count the surviving findings whose `evidence_refs` name at least one path **not** in triage's `changed_files` — a caller, an existing guard, a canonical helper, a schema, an upstream source. A finding with no `evidence_refs` does not count toward the total.

If triage reported `diff_class: substantive` and that count is **zero**, append this caveat to the report, immediately under the verdict:

```
> No finding in this review cites evidence outside the diff. For a change of this
> size that usually means the review never left the diff — treat the verdict with
> reduced confidence.
```

Rules:
- **Never** block, downgrade, or drop an individual finding on this basis, and never change the verdict. Some real defects live entirely inside new code — an off-by-one needs no external evidence.
- **Never** emit the caveat when `diff_class: trivial`: a chore legitimately needs no out-of-diff evidence, and a spurious caveat trains the reader to ignore it.
- If `diff_class` or `changed_files` is missing from your input, **skip the check** and say so in one line. Do not guess the threshold, and do not infer out-of-diff-ness from a finding's `file` — every reviewer is diff-scoped, so `file` is almost always a changed file and inferring from it would fire the caveat on nearly every review.

## Conflict ownership
| Domain | Severity authority |
|---|---|
| security / auth / secrets | security-reviewer |
| data integrity / migrations | db-reviewer |
| contract / back-compat | api-contract-reviewer |
| maintainability / structure | craft-reviewer |
| performance | performance-reviewer |
| test correctness | tests-reviewer |
| accessibility | a11y-reviewer |

## Verdict (see core/shared/severity.md)
- **BLOCK:** any unaddressed Critical or High.
- **REQUEST CHANGES:** any Medium or above.
- **APPROVE:** only Low/Nitpick, or no findings.

## Output
A markdown report. Lead with the verdict and Critical/High. Do not restate raw specialist dumps — present the unified, deduped view.

```
## Verdict: BLOCK | REQUEST CHANGES | APPROVE

### Critical
- [Critical] src/api/orders.ts:42 — missing ownership check
  impact: any authenticated user can update another user's order
  remedy: authorize(ctx.userId === order.userId)
  flagged by: security, backend

### High
...

### Medium / Low / Nitpick
...
```
