---
name: review-pro-synthesize
description: "Stage 3 of review-pro: dedup, weight, resolve conflicts, calibrate severity, and produce the final verdict + report from specialist findings. Use to merge reviewer results into one review verdict."
version: 0.1.0
---

# Review-Pro Synthesis (Stage 3)

You are the orchestrator's final stage. You receive the structured findings from all dispatched reviewers, plus `diff_class`, `changed_files`, `spec_source`, `external_premises`, `premises_dropped`, and each dispatched reviewer's `context.changed_files` from triage's dispatch plan, and produce ONE unified review.

## Steps
1. **Collect** all finding blocks from the dispatched reviewers. Set aside each code reviewer's `## Files examined` block for **Coverage**: it is not a finding, so it is never deduped or ranked.
2. **Dedup** by `(file, line±5, category-root, overlap_hints)`: the same issue flagged by multiple reviewers collapses into one.
3. **Weight:** annotate a finding flagged by 2 or more reviewers "flagged by N reviewers". It is a note about coverage, not evidence: see `## Verification`.
4. **Resolve conflicts** by ownership: the domain owner sets severity (see table).
5. **Verification results**: the orchestrator verifies the merged Medium+ code findings at this point and hands you the results. Apply them as `## Verification` says before going on.
6. **Calibrate severity:** enforce the anti-overreporting bar. Downgrade anything not fully traced to evidence. Never upgrade beyond what a specialist justified. A verified finding is not recalibrated: see `## Verification`.
7. **Out-of-diff evidence check** (see below): a review-level confidence signal, not a per-finding gate.
8. **Coverage** (see below): which changed files the review read, from the dispatch plan and the reviewers' own declarations. Review-level, never a gate.
9. **Verdict** + prioritized findings + remediations.

When you run inline, the orchestrator runs **Collect** through **Resolve conflicts** before it dispatches the verifiers.

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

## Coverage

Which changed files the review read, from two sources that must never be confused: the dispatch plan, which says what each reviewer received, and each code reviewer's `## Files examined` block, which says what it read. The second is a statement, not evidence, and the report labels it self-reported every time.

Inputs: triage's `changed_files` and `diff_class`, each dispatched reviewer's `context.changed_files` from the dispatch plan, the code reviewers' `## Files examined` blocks, and the merged findings. **The spec reviewer is not a receiver**: it reads a file to match it against a requirement, not for defects, and counting it would show a file no code reviewer opened as examined. The receivers of a file are the dispatched code reviewers whose `context.changed_files` contains it.

Put each file in `changed_files` in exactly one state, checked in this order:

| State | Condition |
|---|---|
| sent to no reviewer | it has no receiver |
| examined | a receiver lists it under `examined` and not also under `not_examined`, or filed a finding in it |
| not examined | every receiver lists it under `not_examined` and not also under `examined` |
| not reported | anything else: some receiver gave no entry for it |

- A finding filed in a file counts as its reviewer examining that file, whatever the block says, and a refuted finding counts too: it shows the file was read, not that the finding holds. When the same reviewer also listed the file under `not_examined`, print `contradiction: <reviewer> filed a finding in <file> and declared it not examined`.
- A reviewer that returned no block, a block that leaves a file out, and a file listed in both of one reviewer's lists all leave that reviewer with no entry for the file. **A missing report is never rendered as examined.** Whenever any receiver returned no block, print `no Files examined block from: <reviewers>`, even when other reviewers examined every file it received.

Print the coverage line directly under the Spec line and above the Verification line:

```
Coverage (self-reported): <e> of <n> changed files examined by at least one reviewer[, <x> not examined][, <u> not reported][, <s> sent to no reviewer].
```

- Under it, one indented detail line per file in the `not examined` and `not reported` states: `not examined: <file> (<reviewer>: <reason>; ...)`, `not reported: <file> (<silent reviewers>)`. When a state holds more than 10 files, collapse each directory (its first two path segments) holding more than 3 of them into one line with a count and at most three distinct reasons, and list the rest by name.
- Files sent to no reviewer also get this caveat under the detail lines, on every `diff_class`, because nothing reviewed them and that does not rest on anyone's word:

  ```
  > <s> changed files were sent to no reviewer, so nothing reviewed them: <files>.
  ```

- Never write verified, confirmed, complete or full on this line. "By at least one reviewer" is the claim, and it is a claim about files, not about every axis.
- Declared skips are listed, never warned about. A reason is the reviewer's own words and the reader judges it: skipping study data or design prose is usually right.

Rules:
- It **never changes a finding**, a severity, or the verdict. It is review-level, like the out-of-diff check.
- With `diff_class: trivial`, omit the coverage line and its detail lines: the whole change fits on a screen. The sent-to-no-reviewer caveat still prints.
- If `changed_files` or the per-reviewer `context.changed_files` lists are missing from your input, print `Coverage: not computed, <what> missing from the input.` and do not guess.

## Spec axis

Spec findings arrive in the same stream as code findings and are kept apart from them from here on.

- **Partition before dedup.** Two pools, code and spec. Dedup runs within each pool and never across. A spec finding and a code finding on the same line are different claims: "this should not exist" is not "this has a bug", and merging them loses both.
- **The verdict is the worse of the two axes, and its label names the driver**, composed rather than chosen from a list: `<verdict> (<driving axis or axes>)`, where the axes are `code`, `spec`, or `code + spec`. Every combination is reachable, including `BLOCK (spec)`: a Critical or High `spec.missing` on a clean code axis blocks, because the ladder is unchanged. `spec.scope-creep` is capped at Medium, so it requests changes and never blocks.
- **Absence is always stated, and there are three states, not two.** If `spec_source.kind` is `none`: `Spec: skipped, no spec found.` If the reviewer returned `## Spec findings: abstained (no spec text)`, meaning a spec resolved but carried no readable text: `Spec: not measured, <ref> resolved but carried no text.` Only when the axis actually ran and found nothing: `Spec: no mismatch against <ref>.` **Never render an abstain as "no mismatch"**: that reports a review nobody performed as a clean result.
- **Dedup the spec pool on `(quoted requirement, file, line)`, not on `(file, line)` alone.** Two adjustments, and both matter:
  - The quoted requirement enters the key, because wholly unattempted requirements all carry the spec reference as `file` and `line: 0`. Without it the standard key gives them one identical tuple and collapses this axis's most severe class into a single finding.
  - `file` and `line` stay in the key, because one requirement is routinely unsatisfied in several places. "Every new endpoint validates input" yields one finding per endpoint, each quoting the same sentence verbatim. Keying on the requirement alone would merge them and silently drop every location but one.
  - The exception is a finding whose `file` is the non-repository spec reference with `line: 0`. Those have no location to preserve, so for them the requirement alone is the key.
- **A spec finding's `file` may be a non-repository reference** (`#412`, a PR url) when the requirement was not attempted anywhere in the diff. That is valid on this axis and nowhere else. Never downgrade or drop such a finding for failing to resolve on disk; the Calibrate severity downgrade does not apply to it.
- **Print `spec_source` verbatim** directly under the verdict and above the out-of-diff caveat, so the reader can see what the review was measured against.
- **Never re-rank a spec finding against a code finding.** Reporting them separately is what stops one axis from masking the other.

## External premises

Triage's `external_premises` names claims the diff's rationale rests on that could not be settled inside the repo. Each one comes back from its owning reviewer as a row in that reviewer's `## Premise verification` block, whatever the outcome was. Print one table, and omit the whole section when triage emitted no premises. It goes in the `## Output` template after the spec line and the out-of-diff caveat, and before the severity-grouped findings: it is review-level context like those two, not a finding, so it belongs with them and above the findings it sits over.

```
### External premises
| Premise | Cited | Settled by | Outcome |
```

When triage reported `premises_dropped` with a value above zero, add one line directly beneath the table, outside it, naming the count: for example `2 premises dropped by triage's cap; never routed, never checked.` This is not a table row. A dropped premise carries no `settled_by` or `outcome`, because no reviewer ever saw it, and folding it into the table would manufacture a verification that never happened.

Map the columns straight off the block: `Settled by` from `settled_by`, `Outcome` from `outcome`, and for `unverified` append the reason from `blocked`, for `contradicted` the category from `finding`.

List confirmed premises rather than dropping them. If a confirmed premise leaves no trace, a reader cannot tell "checked and it held" from "never checked", and removing that ambiguity is the whole purpose of the axis.

If triage reported a premise that appears in no reviewer's block, print the row anyway. A reviewer block is not the source here, because none exists, so take `Premise` from triage's own `claim` and `Cited` from triage's own `cited`. Leave `Settled by` empty, because nothing settled it, and set `Outcome` to `not reported`, appended with the owner triage assigned, the same way `blocked` and `finding` are appended above. A premise that was routed and then vanished is a reviewer contract violation, and it is the failure mode this feature exists to prevent, so it must not be the quietest line in the report.

The out-of-diff evidence check needs no exception here. Its definition already counts an upstream source as out-of-diff evidence, and these are code-axis findings, so a premise finding satisfies the tripwire because the review genuinely left the diff.

## Verification

The orchestrator's Verification step selects the findings to verify and owns the rule and the cap. You receive one reply block per verified finding; a finding it selected past the cap arrives as `not verified (cap)`, and spec-axis findings are never verified.

**Binding.** A block binds to the finding whose `file`, `line` and `title` match its `finding` key. A reply with no block, with more than one block, or with a key that matches no finding or more than one leaves that finding `not verified (error)`. A refutation without a citation is `not verified (error)` too: a `refuted` result, or a `partly_refuted` with `defect_stands: no`, needs at least one claim marked `false` whose evidence names a `file:line` or a pinned upstream path. For a `partly_refuted` with `defect_stands: no`, that claim must be the harm itself, not a supporting claim or the remedy. Doubt is not a refutation (the verifier's cite-or-stand rule).

**Resolve each result** by `verdict` and `defect_stands`. `defect_stands: no` wins over `partly_refuted`, because the verifier has said the defect falls; every other inconsistency is `not verified (error)`:

| `verdict` | `defect_stands` | treated as |
|---|---|---|
| `refuted` | `no` | refuted |
| `partly_refuted` | `yes` | partly refuted |
| `partly_refuted` | `no` | refuted |
| `stands` | `yes` | stands |
| `refuted` | `yes` | not verified (error) |
| `stands` | `no` | not verified (error) |

**Apply it:**

| treated as | Medium | High / Critical |
|---|---|---|
| stands | unchanged, marked `verified` | unchanged, marked `verified` |

A `stands` whose `unchecked` is not `none` is marked `verified, unchecked: <what>`, never plainly `verified`: the verifier could not check that claim, often because its source was out of reach, and the reader must see which part was left unchecked.
| partly refuted | severity unchanged; show what falls and its citation under the finding | same |
| refuted | leaves the verdict; moves to `### Refuted in verification` | keeps blocking; marked `disputed`, with the citation |
| not verified | unchanged, marked `not verified (<reason>)` | same |

- A refuted High or Critical keeps blocking. One refutation is not enough to ship a blocker; a human clears a `disputed` finding.
- A verified finding keeps the severity it had when it was selected. Calibrate severity never downgrades a finding because a verifier refuted part or all of it, and never downgrades a `disputed` finding at all.
- Agreement does not override a refutation. "Flagged by N reviewers" stays as a note and protects nothing.
- Not verified is never rendered as verified or standing. The reason is `cap` when the orchestrator's selection passed a finding over, `error` for anything under Binding or the inconsistent rows above, and `no independent verifier` when no verifier ran. If you run as a subagent and receive no verification results, that reason applies to every code-axis finding at Medium or above.
- `partly refuted` never changes severity. Severity is not the verifier's question.
- A `noticed` line goes under its own finding, at most one per finding, labelled `not reviewed`. It is never a finding and never enters the verdict.

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
- **BLOCK:** any unaddressed Critical or High, `disputed` ones included.
- **REQUEST CHANGES:** any Medium or above that verification did not refute.
- **APPROVE:** only Low/Nitpick, refuted Mediums, or no findings.

The verdict measures code health, not conformance to taste. A change that clearly improves the repo earns APPROVE even when it is imperfect, and "not how the reviewer would have written it" is not a finding on any axis. Withhold approval only on the scale above, never because a style preference no rubric names went unmet: a review that blocks improvements trains authors to stop improving.

## Output
A markdown report. Lead with the verdict and Critical/High. Do not restate raw specialist dumps — present the unified, deduped view.

```
## Verdict: <BLOCK | REQUEST CHANGES> (<code | spec | code + spec>)[, <N> disputed] | APPROVE

Spec: measured against <spec_source.ref>
(or: skipped, no spec found / not measured, <ref> resolved but carried no text)

Coverage (self-reported): <e> of <n> changed files examined by at least one reviewer[, <x> not examined][, <u> not reported][, <s> sent to no reviewer].
  not examined: <file> (<reviewer>: <reason>)

Verification: <N> checked (<a> stand, <b> partly refuted, <c> refuted), <M> not checked (<counts by reason>). Spec findings are not verified.

> the out-of-diff caveat, when it applies, goes here: after spec_source, before findings

> the External premises table, when triage emitted premises, goes here: after the caveat, before findings

### Critical
- [Critical] src/api/orders.ts:42 — missing ownership check
  impact: any authenticated user can update another user's order
  remedy: authorize(ctx.userId === order.userId)
  flagged by: security, backend
  verification: verified

### High
...

### Medium / Low / Nitpick
...

### Refuted in verification
- [Medium] src/cart/total.ts:30, discount is applied twice
  refuted: "applyDiscount runs again in checkout()"
  contradicted by: src/cart/checkout.ts:12 `const total = cart.total // already discounted`
  noticed (not reviewed): the discount rounding is untested

## Spec (measured against issue #412)

### Missing
- [High] src/api/orders.ts:12, absent: spec requires soft delete, handler deletes the row
  spec: "Cancelled orders must remain queryable for 90 days."
  remedy: set cancelled_at instead of deleting

### Scope creep
- [Medium] package.json:31, adds `date-fns` when no requirement asks for a date library
```

Code findings are grouped by severity, as above. Spec findings are grouped by **class** (Missing, Wrong, Scope creep) with each finding's severity beside it: on this axis the class carries more information than the level, and grouping by it makes the separation visible rather than merely stated.
