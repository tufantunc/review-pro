# Pre-registration — AACR-Bench paired comparison: standard harness review vs. review-pro

Status: **LOCKED** as of this file's commit to `main`. Changes from here on only as
dated amendments appended to this document. No scored run happens before this lock;
the adapter does not exist yet at lock time.

## The claim under test

The article's thesis, operationalized: review-pro's architecture (triage → specialist
reviewers with a located-evidence requirement → synthesis) exists to catch what a
diff-scoped review misses — findings whose evidence lives outside the diff.

AACR-Bench labels every expert-verified reference comment with a context level:
**diff / file / repo**. That makes the thesis directly falsifiable:

> **H1 (primary):** at the same harness and model, review-pro achieves higher recall
> than the harness's standard review command on **repo-context-labeled** reference
> comments.
>
> **H0-guard (secondary):** it does so without degrading overall precision or noise
> rate beyond the stated budget (see Endpoints).

If repo-context recall does not improve, the architectural claim of the article is
weakened, and we publish that.

## Why this benchmark

- External, expert-verified ground truth (200 real PRs, 50 projects, 10 languages,
  2,145 reference comments) — we do not construct our own labels, removing the
  largest COI lever.
- Apache-2.0 code **and** data (verified on the repo and the HuggingFace card).
- The framework's built-in Claude reviewer runs the **official `/code-review`
  slash command** headlessly — the "standard review" arm is the framework's own,
  unmodified. We did not define our opponent.

## Design: paired, within-model

Each instance is reviewed by both arms at the same harness + model. The defended
readout is the **within-instance paired delta**, not absolute scores.

### Phase 1 arms (this registration)

| Arm | Harness | Model | Reviewer |
|---|---|---|---|
| A1 | Claude Code (pinned version) | `claude-opus-5`, reasoning effort **high** | framework's built-in `claude` reviewer (`/code-review`), **unmodified** |
| A2 | Claude Code (same pin) | same | review-pro via custom adapter (see Adapter rules) |

### Later phases (separate amendments, not covered by this lock)

Additional harnesses (opencode, Codex) with their arm models fixed per-phase by
dated amendment **before** any of that phase's scored runs — including a per-phase
definition of what that harness's "standard review" is (it is not uniform across
harnesses). Standing constraint: **GLM-family models are permanently ineligible
as arms** in any phase, because GLM-5.2 is the judge (see Judge protocol).

## Corpus and sampling

- Dataset: AACR-Bench v1.0, via the framework's converter.
- Subset: **n = 30**, drawn with the framework's own reproducible sampler:
  `--limit 30 --seed 42`, committed here **before** anyone looks at which
  instances the seed selects. The resulting instance list is published verbatim.
- The sample's language/category composition is reported as-is; no re-drawing.
  If the seed produces a skewed sample, that is reported, not fixed.
- Instance order within the run follows the converted file; a partial run (see
  Budget) truncates in that fixed order — no post-hoc instance selection.

## Adapter rules (A2)

The review-pro arm must differ from A1 **only** in the reviewer:

1. review-pro core is installed into an **isolated agent home** per run
   (`CLAUDE_CONFIG_DIR` sandbox), pinned to a named release/commit (see Pinning).
2. The session is invoked headlessly with the review-pro skill on the same
   `base...head` target A1 gets.
3. Findings are reported through the **same MCP finding contract** as A1
   (path, line range, text). The text field carries the finding's
   title + impact; severity is included in the text, not used for filtering.
4. **Everything the synthesis stage emits is reported** — including Low/Nitpick.
   No severity floor, no post-hoc pruning. Anti-overreporting is the product's
   job at synthesis time, not the adapter's job after the fact.
5. The mapping code is frozen before the scored run and published.

## Endpoints

Primary:
- **Recall on repo-context references** (per-instance, paired delta A2 − A1).

Secondary (all reported, none promoted post-hoc):
- Recall on file-context and diff-context references.
- Overall precision, recall, line precision, noise rate (framework definitions).
- Per-category (Security / Defect / Maintainability / Performance) recall.
- **Cost per arm**: wall-clock per instance; token usage if obtainable from the
  harness. review-pro is expected to cost a multiple of A1 — that asymmetry is a
  finding, reported with the same prominence as quality metrics.

Noise budget (H0-guard): A2's overall noise rate may not exceed A1's by more than
**5 percentage points** in the headline claim. If it does, H1 is reported as
"recall bought with noise," not as a win.

Statistics: descriptive, plus **one** pre-named test — Wilcoxon signed-rank on the
per-instance primary deltas, α = 0.05, no other tests. n = 30 is small; language
stays "pattern observed," never "proved."

## Judge protocol

- One judge model for **all** arms and **all** phases: **GLM-5.2**.
- **Family-exclusion rule:** the judge may not share a model family with any arm's
  reviewer model, in any phase. Phase 1 arms are Anthropic → satisfied. The rule
  is enforced forward by construction: GLM-family models are permanently excluded
  from being arms (stated under Later phases).
- **Pre-lock connectivity probe:** the judge may be exercised with 2–3 fabricated
  finding pairs (never with benchmark instances) to validate wiring; probe
  transcripts are published.
- `--eval-rounds 3`, metrics averaged; per-round outputs published.
- `--line-k` stays at the framework default (1). Stated here so it cannot drift.
- Judge prompts/config: framework defaults, unmodified. If any judge behaviour
  looks broken mid-run, the run completes anyway; concerns go in the report.

## Anti-gaming rules

- **Freeze before smoke.** review-pro (core skills, agents, prompts) is frozen at
  the pinned commit before the smoke run. Between smoke and scored run, **only
  adapter plumbing** (process handling, MCP wiring, parsing) may change — never
  review-pro core, never prompts, never the A1 arm. Plumbing diffs are published.
- **Smoke run:** ≤ 5 instances, judge mocked (`JUDGE_USE_MOCK=true`), exists to
  validate the pipeline. Its outputs are published but excluded from headline
  metrics regardless of how they look.
- **First scored run counts.** Reruns only for infrastructure failures (clone
  errors, API outages), applied symmetrically to both arms, each rerun logged
  with its reason.
- **Timeouts:** same per-instance timeout for both arms — **45 minutes** (the
  framework default 30 raised because A2 fans out; applying the raise to both
  arms keeps symmetry). A timed-out arm scores its findings as reported up to
  the timeout (the MCP server reports incrementally); the timeout is logged.
- **No metric shopping.** The primary endpoint is fixed above. If secondary
  metrics look better, they are reported as secondary.
- **Negative result ships.** Same as the pilot: if A2 loses, that is the article.

## Contamination note

These are public PRs; arm models have plausibly seen them in training. This
inflates absolute scores for both arms. The paired within-model design is the
defense: contamination pushes both arms of the same model equally, and the
readout is the delta. We therefore make **no claims** against AACR-Bench's
published absolute leaderboard numbers — only within-model paired comparisons.

Residual risk, stated honestly: contamination could interact with arm design
(e.g., a model that memorized the PR's actual review comments might surface them
under one prompting style more than another). We cannot rule this out at n = 30;
it is listed as a limitation, and the per-instance data we publish lets anyone
check suspicious cases.

## Pinning

Fixed at lock time. Rows marked *(at freeze)* are filled by amendment when the
adapter is frozen — before the smoke run, and therefore still before any scored run.

| Component | Pin |
|---|---|
| aacr-bench upstream | `alibaba/aacr-bench` @ `b3072489eace` (2026-08-04), fork: `tufantunc/aacr-bench` |
| Dataset | AACR-Bench v1.0 — `positive_samples.json`, sha256 `d8683cb240249bc4e0aff6428802bdffa7b7573ace600552cab1cd0cb7e905c9` (from the upstream `.meta.json`; the framework verifies this on download) |
| review-pro | `v0.5.0` @ `26341fe` |
| Claude Code CLI | `2.1.208` |
| A1/A2 model | `claude-opus-5` — reasoning effort **high**; the mechanism for fixing effort in headless mode is verified and documented at freeze, and if it cannot be fixed, the arm is recorded as "harness default effort" rather than claimed |
| Judge | GLM-5.2 (exact model id + endpoint recorded *(at freeze)*) |
| Fork branch + commit | *(at freeze)* |
| Adapter file sha | *(at freeze)* |

## Stopping rule

If a run must pause or stop early for any resource reason (quota, rate limits,
outage), instances are processed in the fixed order defined by the seed, pacing
across days is logged, and a stopped run is published as a **partial run over
that fixed-order prefix**, labeled as such, with the reason stated.

## Where the work lives

- **`tufantunc/aacr-bench`** (public fork of `alibaba/aacr-bench`): all framework
  code — the A2 adapter, any plumbing fixes — on a dedicated branch, pinned by
  commit sha in this document at lock time. Public so the pin is verifiable.
- **`tufantunc/review-pro` → `studies/<date>-aacr-bench-comparison/`**: this
  registration (its commit is the lock), the instance list, run summaries,
  hand-verification notes, and the write-up — same pattern as the pilot.
- **Raw per-instance outputs** (both arms, all judge rounds): committed to the
  studies directory if size permits, otherwise attached as a release asset on
  the fork; either way linked from the study README.
- **Local only:** API keys (`.env`), repo clone caches, virtualenvs. Nothing
  scored lives only on a laptop.

## Conflict of interest

The study author maintains review-pro. Same posture as the pilot: pre-committed
design, external ground truth, everything published including losses, and the
instance-level raw outputs available for independent re-scoring.

## Publication

Everything lands in `studies/<date>-aacr-bench-comparison/` in the review-pro
repo: this document with amendments, the instance list, per-instance raw findings
for both arms, judge outputs per round, metrics, costs, adapter code reference,
and the write-up. AACR-Bench is cited (repo + arXiv:2601.19494).
