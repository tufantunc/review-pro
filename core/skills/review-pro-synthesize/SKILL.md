---
name: review-pro-synthesize
description: "Stage 3 of review-pro: dedup, weight, resolve conflicts, calibrate severity, and produce the final verdict + report from specialist findings. Use to merge reviewer results into one review verdict."
version: 0.1.0
---

# Review-Pro Synthesis (Stage 3)

You are the orchestrator's final stage. You receive the structured findings from all dispatched reviewers, plus `diff_class`, `changed_files`, and `spec_source` from triage's dispatch plan, and produce ONE unified review.

## Steps
1. **Collect** all finding blocks from the dispatched reviewers.
2. **Dedup** by `(file, line±5, category-root, overlap_hints)`: the same issue flagged by multiple reviewers collapses into one.
3. **Weight:** a finding flagged by ≥2 reviewers gets a conviction boost — annotate it "flagged by N reviewers".
4. **Resolve conflicts** by ownership — the domain owner sets severity (see table).
5. **Calibrate severity:** enforce the anti-overreporting bar. Downgrade anything not fully traced to evidence. Never upgrade beyond what a specialist justified.
6. **Out-of-diff evidence check** (see below) — a review-level confidence signal, not a per-finding gate.
7. **Verdict** + prioritized findings + remediations.

## Out-of-diff evidence check

Count the **code-axis findings only** whose `evidence_refs` name at least one path **not** in triage's `changed_files`: a caller, an existing guard, a canonical helper, a schema, an upstream source. A finding with no `evidence_refs` does not count toward the total.

Spec-axis findings are excluded from this count and it is not a detail. A spec finding's evidence is the spec document or issue, which is outside the diff in the `issue` and `pr-body` cases and may well be inside it for a `file` source (a design doc committed alongside its implementation). Either way the exclusion holds: counting spec findings would satisfy this check on most reviews where the axis ran and quietly disable it.

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

## Spec axis

Spec findings arrive in the same stream as code findings and are kept apart from them from here on.

- **Partition before dedup.** Two pools, code and spec. Dedup runs within each pool and never across. A spec finding and a code finding on the same line are different claims: "this should not exist" is not "this has a bug", and merging them loses both.
- **The verdict is the worse of the two axes, and its label names the driver**, composed rather than chosen from a list: `<verdict> (<driving axis or axes>)`, where the axes are `code`, `spec`, or `code + spec`. Every combination is reachable, including `BLOCK (spec)`: a Critical or High `spec.missing` on a clean code axis blocks, because the ladder is unchanged. `spec.scope-creep` is capped at Medium, so it requests changes and never blocks.
- **Absence is always stated, and there are three states, not two.** If `spec_source.kind` is `none`: `Spec: skipped, no spec found.` If the reviewer returned `## Spec findings: abstained (no spec text)`, meaning a spec resolved but carried no readable text: `Spec: not measured, <ref> resolved but carried no text.` Only when the axis actually ran and found nothing: `Spec: no mismatch against <ref>.` **Never render an abstain as "no mismatch"**: that reports a review nobody performed as a clean result.
- **Dedup the spec pool on `(quoted requirement, file, line)`, not on `(file, line)` alone.** Two adjustments, and both matter:
  - The quoted requirement enters the key, because wholly unattempted requirements all carry the spec reference as `file` and `line: 0`. Without it the standard key gives them one identical tuple and collapses this axis's most severe class into a single finding.
  - `file` and `line` stay in the key, because one requirement is routinely unsatisfied in several places. "Every new endpoint validates input" yields one finding per endpoint, each quoting the same sentence verbatim. Keying on the requirement alone would merge them and silently drop every location but one.
  - The exception is a finding whose `file` is the non-repository spec reference with `line: 0`. Those have no location to preserve, so for them the requirement alone is the key.
- **A spec finding's `file` may be a non-repository reference** (`#412`, a PR url) when the requirement was not attempted anywhere in the diff. That is valid on this axis and nowhere else. Never downgrade or drop such a finding for failing to resolve on disk; step 5's downgrade rule does not apply to it.
- **Print `spec_source` verbatim** directly under the verdict and above the out-of-diff caveat, so the reader can see what the review was measured against.
- **Never re-rank a spec finding against a code finding.** Reporting them separately is what stops one axis from masking the other.

## External premises

Triage's `external_premises` names claims the diff's rationale rests on that could not be settled inside the repo. Each one comes back from its owning reviewer as a row in that reviewer's `## Premise verification` block, whatever the outcome was. Print one table, and omit the whole section when triage emitted no premises:

```
### External premises
| Premise | Cited | Settled by | Outcome |
```

Map the columns straight off the block: `Settled by` from `settled_by`, `Outcome` from `outcome`, and for `unverified` append the reason from `blocked`, for `contradicted` the category from `finding`.

List confirmed premises rather than dropping them. If a confirmed premise leaves no trace, a reader cannot tell "checked and it held" from "never checked", and removing that ambiguity is the whole purpose of the axis.

If triage reported a premise that appears in no reviewer's block, print the row with outcome `not reported` and name the owner triage assigned. A premise that was routed and then vanished is a reviewer contract violation, and it is the failure mode this feature exists to prevent, so it must not be the quietest line in the report.

The out-of-diff evidence check needs no exception here. Its definition already counts an upstream source as out-of-diff evidence, and these are code-axis findings, so a premise finding satisfies the tripwire because the review genuinely left the diff.

## Category roots

The dedup key's namespace, one root per reviewer. Stated here because Stage 3 is what
dedups on it, and because an installer that copies only skill directories leaves
`shared/output-schema.md` unreachable, taking the registry with it.

`security`, `correctness`, `craft`, `ai-antipatterns`, `dry`, `performance`, `backend`, `frontend`, `a11y`, `db`, `api-contract`, `tests`, `spec`.

A root that is not in this list is not a root. Normalising an unknown root into a
listed one would merge findings the axes deliberately keep apart, so treat an
unrecognised prefix as a reviewer contract violation and report it rather than
guessing which neighbour it meant.

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
## Verdict: <BLOCK | REQUEST CHANGES> (<code | spec | code + spec>) | APPROVE

Spec: measured against <spec_source.ref>
(or: skipped, no spec found / not measured, <ref> resolved but carried no text)

> the out-of-diff caveat, when it applies, goes here: after spec_source, before findings

### Critical
- [Critical] src/api/orders.ts:42 — missing ownership check
  impact: any authenticated user can update another user's order
  remedy: authorize(ctx.userId === order.userId)
  flagged by: security, backend

### High
...

### Medium / Low / Nitpick
...

## Spec (measured against issue #412)

### Missing
- [High] src/api/orders.ts:12, absent: spec requires soft delete, handler deletes the row
  spec: "Cancelled orders must remain queryable for 90 days."
  remedy: set cancelled_at instead of deleting

### Scope creep
- [Medium] package.json:31, adds `date-fns` when no requirement asks for a date library
```

Code findings are grouped by severity, as above. Spec findings are grouped by **class** (Missing, Wrong, Scope creep) with each finding's severity beside it: on this axis the class carries more information than the level, and grouping by it makes the separation visible rather than merely stated.
