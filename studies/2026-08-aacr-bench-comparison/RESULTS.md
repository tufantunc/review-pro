# Results, phase 1: `/code-review` (A1) vs review-pro (A2) on AACR-Bench

**H1 is not supported.** At the same harness and model, review-pro did not find more of the
repo-context reference comments than Claude Code's own `/code-review`.

| Measure | A1 | A2 |
|---|---|---|
| Mean per-instance delta, 12 instances | | **−0.08** |
| Wilcoxon, two-sided | | **p = 0.56** |
| Pooled repo-context recall (21 references) | 0.381 | 0.365 |

Elsewhere, review-pro found more:

| Recall | A1 | A2 |
|---|---|---|
| Overall | 0.375 | 0.425 |
| Diff context | 0.367 | 0.405 |
| File context | 0.383 | 0.468 |

Its noise rate stayed within the registered budget: +1.5 points against a 5-point budget. It cost
9.2 times the tokens and 3.4 times the review time.

The article's architectural claim, that review-pro catches what lives outside the diff, is not
borne out on this benchmark, and that is what this study reports.

Everything below follows `PRE-REGISTRATION.md` (Amendments 1 to 4). Per-instance outputs for both
arms and all three judge rounds are in `phase1/`. The scripts that compute every number are
`primary.py` and `secondary.py`, with outputs in `results/`.

## The run

| | |
|---|---|
| Harness | Claude Code 2.1.283, pinned binary; `claude-opus-5-5`, effort `high` on every message |
| A1 | the framework's own `claude` reviewer, `/code-review <base>...<head>` |
| A2 | review-pro 1.5.0 (npm integrity verified) at project scope |
| Isolation, both arms | `--setting-sources project,local --strict-mcp-config`; read-only git allowlist (Amendments 2 and 3); no `gh`, no web; an isolated repository holding no history after head, checked on every instance |
| Instances | 30 sampled; **27 reviewed by both arms**. Three were infrastructure failures logged before the smoke run and never reviewed (`INFRA-FAILURES.md`): #5 and #13, whose head commits are gone from GitHub, and #19, whose history could not be downloaded |
| References scored | 167: Diff 79, File 67, Repo 21 |
| Judge | GLM-5.3 (`glm-5.3`, z.ai), 3 rounds per arm, metrics averaged; 0 judge call errors |
| When | Sitting 1 on 2026-09-30 and 2026-10-01; sitting 2 on 2026-10-01; scored evaluation on 2026-10-01 |

**Every review exited 0.** One A2 sitting was interrupted by the orchestrating session's
background time limit. The unfinished instance had written nothing, and it was resumed from the
start (`STATUS.md`, run log). No result was deleted or re-run.

## Primary endpoint: repo-context recall, paired (Amendment 2 item 8)

There are 12 instances with at least one repo-context reference. Recall per instance is averaged
over the three judge rounds.

| Instance | Repo refs | A1 | A2 | Δ (A2 − A1) |
|---|---:|---:|---:|---:|
| FreeCAD@ec3da2e | 1 | 0.67 | 0.00 | −0.67 |
| spring-ai-alibaba@4bc7305 | 3 | 1.00 | 1.00 | 0.00 |
| aspnetcore@8ac940f | 1 | 0.33 | 0.00 | −0.33 |
| elasticsearch@a6a4623 | 2 | 0.00 | 0.00 | 0.00 |
| elasticsearch@e38d20c | 1 | 0.00 | 0.00 | 0.00 |
| react@b045f18 | 4 | 0.00 | 0.50 | +0.50 |
| gemini-cli@c6e6248 | 2 | 1.00 | 0.50 | −0.50 |
| laravel@180c25f | 1 | 1.00 | 1.00 | 0.00 |
| linera-protocol@024925d | 1 | 0.00 | 0.00 | 0.00 |
| lvgl@4a57db3 | 2 | 0.33 | 0.00 | −0.33 |
| typescript-go@892b4a3 | 1 | 0.33 | 0.67 | +0.33 |
| mpv@dbd327d | 2 | 0.00 | 0.00 | 0.00 |

- **Mean delta:** −0.083.
- **Deltas:** 6 are zero; of the 6 non-zero ones, 2 are positive and 4 negative.
- **Wilcoxon signed-rank:** two-sided, zero deltas dropped (`zero_method="wilcox"`), as
  registered. W = 6.5 on 6 pairs, **p = 0.5625**. The non-zero absolute deltas tie, so scipy's
  exact method is computed with ties present. For robustness only: the normal approximation gives
  p = 0.40, and scipy's `auto` method p = 0.53. None is near α = 0.05.
- **Descriptive, not a test: pooled repo-context recall** over the 21 references is A1 0.381
  and A2 0.365.

**H1 is not supported.** The direction, if anything, favours A1. With 12 pairs the test has
little power, as registered before the run. The defensible reading is "no pattern of higher
repo-context recall was shown", not "review-pro is worse on repo context".

## H0-guard: noise rate

The noise rate follows AACR-Bench's definition: unmatched generated comments over all generated
comments (README, "Core Metrics"; `docs/metrics.md`, `unmatched_rate`). The framework documents
it but does not compute it. `secondary.py` does, from the judge's `matched_note`.

| | A1 | A2 |
|---|---:|---:|
| Noise rate | 0.711 | 0.726 |

**A2 − A1 = +1.5 points, within the 5-point budget.** This guard concerns whether gains are
bought with noise. Since there is no primary gain, it constrains nothing here, and it is
reported as registered.

## Secondary endpoints (reported, none promoted)

Framework metrics, averaged over three rounds:

| | A1 | A2 |
|---|---:|---:|
| Generated comments | 217 | 259 |
| Semantic recall | 0.375 | 0.425 |
| Semantic precision (matched / generated) | 0.289 | 0.274 |
| Line recall | 0.421 | 0.465 |
| Line precision | 0.324 | 0.300 |

Recall by context:

| Context | References | A1 | A2 |
|---|---:|---:|---:|
| Diff | 79 | 0.367 | 0.405 |
| File | 67 | 0.383 | 0.468 |
| Repo | 21 | 0.381 | 0.365 |

Recall by category:

| Category | References | A1 | A2 |
|---|---:|---:|---:|
| Code Defect | 86 | 0.395 | 0.453 |
| Maintainability and Readability | 58 | 0.259 | 0.379 |
| Performance | 13 | 0.590 | 0.487 |
| Security Vulnerability | 10 | 0.600 | 0.367 |

**The judge varies by round.** Matched references were 63, 59 and 66 for A1, and 72, 69 and 72
for A2.

## Cost per arm

| | A1 | A2 | Ratio |
|---|---:|---:|---:|
| Tokens, input + cache + output | 9.56M | 88.41M | 9.2× |
| Review time, summed | 45 min | 153 min | 3.4× |
| Per instance | 354K tokens, 99 s | 3.27M tokens, 340 s | |

**review-pro costs a multiple of A1, as the registration expected.** That asymmetry belongs next
to the quality numbers: on this benchmark, about 9 times the tokens bought +5 points of overall
recall, and no repo-context gain.

## Sensitivity analysis (Amendment 4, post hoc, labelled)

**What it corrects.** On #6, A1's answer held 10 findings in a JSON list with one stray quote. As
registered, the framework scored them as zero. With only that quote removed, the judge matched 2
of #6's 15 references in each round, both diff-context.

**What changes for A1:**

| A1 | Registered | Corrected |
|---|---:|---:|
| Recall | 0.375 | 0.387 |
| Diff recall | 0.367 | 0.392 |
| Noise rate | 0.711 | 0.715 |

The H0-guard difference becomes +1.1 points. #6 has no repo-context reference, so the primary
endpoint is unchanged. A2 had no malformed list.

## Recorded alongside (Amendment 2 item 9)

- **A2 stage timing** (`results/a2-stages.json`):
  - median wall time per instance 316 s (range 109 to 758 s);
  - triage median 51 s; synthesis median 108 s;
  - reviewers ran concurrently on 24 of 27 instances, and their union was 1.09× the slowest
    reviewer at the median.

  So one-step dispatch keeps the reviewers parallel on real repositories, and the slowest
  reviewer sets the wall time (roadmap item 4).
- **Anchors** (`results/anchor-a2-review.md`): 12 of 418 locatable A2 findings are on the wrong
  line after hand review (2.9%), 9 of them on one instance. This is below item 2's 5% revisit
  line, so roadmap item 2 stays "measured, not built".

## Observations and limitations

- **Power.** 12 paired instances, 21 repo-context references. A null primary result is
  consistent with a small effect either way.
- **A1's 10-finding ceiling.** `/code-review` returned exactly 10 findings on 12 of its 26
  parsed instances and never more. A2 ranged from 0 to 27. This ceiling is part of the arm as
  shipped. It may cap A1's recall and helps A1's precision; it was not tuned by us.
- **Parser asymmetry.** A2's fallback parser is lenient and A1's framework parser is strict
  JSON. It mattered once, against A1, on #6, which the sensitivity analysis covers. A2's fallback
  was used once, on #7, a report with 0 findings.
- **One run per arm.** Reviewer output varies between runs; the judge varies between rounds, as
  shown above.
- **Contamination.** These are public PRs. The paired within-model design limits this but cannot
  exclude it.
- **Coverage.** One harness, one model. The other phases (opencode, Codex) are separate and
  unregistered.
- **Instances lost.** Three of the 30 sampled instances could not be reviewed, for reasons
  unrelated to either arm. They are logged, not re-sampled.

## No leaderboard claims

These are within-model paired comparisons only. **We make no claim against AACR-Bench's published
absolute numbers, nor against OCR's leaderboard.** The AACR-Bench leaderboard is published by the
benchmark's own authors.
