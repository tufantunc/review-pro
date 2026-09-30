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
as arms** in any phase, because a GLM model is the judge (see Judge protocol).

## Corpus and sampling

- Dataset: AACR-Bench v1.0, via the framework's converter.
- Subset: **n = 30**, drawn with the framework's own reproducible sampler:
  `--limit 30 --seed 42`, committed here **before** anyone looks at which
  instances the seed selects. The resulting instance list is published verbatim.
- The sample's language/category composition is reported as-is; no re-drawing.
  If the seed produces a skewed sample, that is reported, not fixed.
- Instance order within the run follows the converted file; a partial run (see
  Stopping rule) truncates in that fixed order — no post-hoc instance selection.

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

- One judge model for **all** arms and **all** phases: **GLM-5.3**
  (amended from 5.2 — see Amendment 1).
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
| Judge | GLM-5.3 (exact model id + endpoint recorded *(at freeze)*) |
| Fork branch + commit | `feat/review-pro-reviewer` — head at freeze *(at freeze)*; resume landed in `e491d7b` |
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

## Amendment 1, 2026-08-13 — judge version, resumable runs, execution environment

Made before the smoke run and therefore before any scored run. Nothing about the
hypotheses, endpoints, sampling, or judge *family* changes.

**1. Judge is GLM-5.3, not 5.2.** A newer version of the same family became
available. The family-exclusion rule is unaffected: GLM-family models remain
permanently ineligible as arms. All references above read as GLM-5.3.

**2. Review runs are resumable, and stopping is expected.** The framework
originally re-reviewed every instance unconditionally; the fork now skips
instances whose result file already exists
([`e491d7b`](https://github.com/tufantunc/aacr-bench/commit/e491d7b)). This was
added *before* the smoke run so it is part of the frozen state, not a mid-study
change. Properties, all verified against the code by driving the stage with a
stubbed reviewer:

- Skipping never reorders — the remaining instances keep the order fixed by the
  sampling seed, so a resumed run cannot become a re-sampled run.
- Skipped instances still appear in the run summary, so counts stay honest.
- The check is symmetric across arms: it changes no arm's behaviour, only whether
  finished work is repeated.

**This opens one gaming route, and it is closed here:** with resume available,
someone could delete a result they disliked and re-review that instance.
Therefore — **resume may only skip or continue. Deleting a result and
re-reviewing (including via `--force`) is permitted solely for infrastructure
failures, and every such instance is logged with its reason in the published
run record.** This is the resume-aware form of "first scored run counts."

Practical consequence: the arms run against subscription quotas (Anthropic for
the arms, z.ai for the judge), both of which have rolling windows. A run that
exhausts a window **stops**; the study continues on a later day with the same
command and the same `--run-id`. Elapsed calendar time is therefore not a
methodological quantity, and `n = 30` stands rather than being reduced to fit a
single sitting.

**3. Execution environment is the host, not a container — stated for
reproducibility.** The framework clones the benchmark's repositories onto the
host and invokes the harness CLI as a subprocess; there is no container
isolation. Two consequences recorded honestly:

- The only isolation we add is credential/config isolation: the review-pro arm
  installs into a throwaway `CLAUDE_CONFIG_DIR` per instance, so the operator's
  real agent home is never read or written.
- Reviewers operate inside checkouts of third-party repositories with edit
  permission enabled, and the worktree is cleaned after each instance. Anyone
  replicating this should decide for themselves whether to add container
  isolation; the corpus is 50 established open-source projects rather than
  arbitrary code, which is why we accepted the host-level run.

**4. Sleep is a hazard during a run, not between runs.** Per-instance timeouts
are wall-clock, so a machine sleeping mid-review longer than the timeout will
time that instance out (findings already reported through MCP survive; the rest
is lost and the instance is recorded as a timeout — never silently re-run, per
the rule above). Runs are therefore launched under `caffeinate -is`. Sleeping
between runs is harmless.

## Amendment 2, 2026-09-28: pins, arm isolation, permissions, reporting, ground truth, and the primary endpoint's arithmetic

Approved by the maintainer at gate 1 (2026-09-28), with the decisions recorded in items 5, 8
and 10. Committed before the adapter freeze, the smoke run and every scored run.

**What this amendment does not change:**
- the hypotheses (H1, and the H0-guard with its 5-point noise budget);
- the endpoints;
- the sample (`--limit 30 --seed 42`, the 30 instances in `INSTANCES.md`, 190 references);
- the judge family, and GLM's exclusion as an arm;
- the single pre-named test;
- the anti-gaming rules and the 45-minute timeout for both arms.

No instance has been reviewed by either arm yet. The only prior contact is the August smoke
attempt, which never ran a review ("Not logged in", item 3 below).

### 1. review-pro pin: v1.5.0

| | |
|---|---|
| Release | `v1.5.0` (GitHub Release, 2026-09-27; tag commit `5a4c599`) |
| npm | `review-pro@1.5.0`, integrity `sha512-9Ct43124Ix4TBGmN7K+e3PcO4b1r0UEKB4ri38rVJKustAqknPrT1u3ANEQl1kLXsMpZiAt/U9ssVANMLB9oxg==`, shasum `d1d0240e8f4a2c1b37e06a429465fec8702a3cb6` |
| Installed tree | the tarball's `plugin/agents`, `plugin/skills`, `plugin/shared`. These are byte-identical to `core/agents`, `core/skills` and `core/shared` at tag `v1.5.0` (`diff -rq`, 2026-09-28) |

The adapter installs from that tarball and checks the integrity before use. It records the
sha256 of the installed tree in every result envelope.

**Replaces:** `v0.5.0 @ 26341fe`. The lock-time pin was never exercised; no instance was
reviewed. Since v0.5.0, review-pro gained:
- coverage accounting;
- independent verification of Medium+ findings;
- repository rules;
- stack signals read from the merge base;
- one-step dispatch of reviewers and verifiers.

We pin the current release, not an unreleased commit.

**Stated plainly:** those changes were made by the study's author while this study was pending.
None was developed or tuned on AACR-Bench instances, and no instance has been reviewed by either
arm. The dates are checkable:
- `INSTANCES.md` was published on 2026-08-14 (#21), before v1.1.0 (2026-08-25) and every later
  release.
- The only result file from either arm is the failed A2 smoke attempt of item 3.

The fork's template pinned "v0.5.0 @ 26341fe", but the `v0.5.0` tag is `d1c82ad`. `26341fe` is one
docs-only commit later, and `core/` is identical between them. This is moot now, and recorded for
accuracy.

### 2. Harness and model

| | |
|---|---|
| Claude Code CLI | `2.1.283`, recorded per instance from the session's init event. Auto-update is disabled for the run's duration (the mechanism is verified at freeze), so the pin holds across days |
| Model, both arms | `claude-opus-5-5`, passed as `--model claude-opus-5-5` (and `ANTHROPIC_MODEL`) |
| Effort, both arms | `--effort high` |

**Replaces `claude-opus-5`.** The model changes identically for both arms. The paired design
compares arms, not models.

**Effort is fixed, and it is checked, not assumed.** Roadmap item 4 ran review-pro headlessly with
`--effort high` (`studies/2026-09-cost-measurement/run.sh` and its pre-registration's "Model"
line). This amendment adds the check:
- Each assistant message in a Claude Code session transcript records `"effort":"high"`.
- In the gate-1 canary (item 4 below), every assistant message of every session carried it.
  That includes A1: `/code-review` runs as a forked `general-purpose` subagent, and all four of
  its messages were `claude-opus-5-5` with `"effort":"high"`.
- The run keeps these transcripts (item 9), so the effort level is checkable for every instance.

The lock's fallback ("harness default effort") is therefore not needed.

### 3. Arm isolation: `--setting-sources`, not `CLAUDE_CONFIG_DIR`

**What is replaced.** Adapter rule 1 and Amendment 1 item 3 isolated the review-pro arm in a
throwaway `CLAUDE_CONFIG_DIR` per instance.

**Why it changes.** The operator runs on a subscription. Its login is stored for the operator's
own configuration home, and a fresh `CLAUDE_CONFIG_DIR` has no credentials. The August smoke
attempt shows this: `results/aacr_bench/review-pro/smoke/vllm-project__vllm@6217b0c.json` records
exit code 1 after 2.79 s, with the output "Not logged in · Please run /login".

The old mechanism also isolated only A2. A1 ran with the operator's whole `~/.claude`:
- its settings, plugins, hooks, MCP servers and `CLAUDE.md`;
- review-pro v1.4.0's own skills and agents, installed at user scope.

So A1 could have loaded review-pro.

**The new mechanism, identical for both arms:**

```
--setting-sources project,local --strict-mcp-config --model claude-opus-5-5 --effort high
```

These flags are added to the framework's existing flags, which stay as they are:
`-p`, `--add-dir <repo>`, `--permission-mode acceptEdits`, `--output-format json`, `--mcp-config`
(the findings server only), `--allowed-tools`, `--append-system-prompt` (the findings
instruction) and `--settings` (the StopFailure hook).

This excludes the operator's user-scope settings, plugins, hooks, MCP servers, `CLAUDE.md`, and
user-scope skills and agents. Item 4 below is the proof.

`--strict-mcp-config` keeps the framework's own findings server, which arrives through
`--mcp-config`.

**A2 alone** additionally gets review-pro installed at project scope inside each instance
checkout: `.claude/agents`, `.claude/skills`, `.claude/shared`, from the item 1 tarball.
- `.claude/` is listed in the checkout's `.git/info/exclude`, so neither `git diff` nor
  `git status` shows it.
- The framework's own `git clean -fdx` between instances removes it, and the adapter reinstalls
  it for the next instance.

**Both arms review an isolated instance repository, never the framework's clone cache.** The
details are in item 5. The cache stays outside every session's working directories.

**No instance brings its own project settings.** At all 30 instances' head commits there is no
`.claude/`, `CLAUDE.md`, `AGENTS.md` or `.review-pro/` (GitHub contents API, 2026-09-28). Project
scope therefore adds nothing instance-specific to either arm, and A2's install collides with
nothing.

**What stays shared with the operator, stated honestly:**
- The subscription credentials. They are the point of the change.
- The session transcripts that every Claude Code session writes under `~/.claude/projects/`. They
  are kept, because they are the source for item 9's per-stage numbers, and copied into the study.
  Nothing under `~/.claude` that configures Claude Code is read or written.

### 4. Canary evidence (both arms)

The canary ran on 2026-09-28 in a throwaway two-commit repository. It used the framework's own
builders (`build_mcp_config`, `build_findings_system_prompt`, `build_hook_settings`) and item 3's
flags. The global install holds review-pro v1.4.0 at user scope, in `~/.claude/skills` and
`~/.claude/agents`. Two strings tell the versions apart:
- only v1.4.0 contains "in parallel/background" and the description "One-command AI code review";
- only v1.5.0 contains "all in one step".

| Probe | Result |
|---|---|
| **P1, A1 environment** (no project install) | Init lists only built-in agents (`claude`, `Explore`, `general-purpose`, `Plan`, `statusline-setup`), only built-in skills (`code-review` among them), plugins `agents-md` and `telemetry`, and MCP `findings` connected. `Skill review-pro` returned `Unknown skill: review-pro`. `Agent correctness-reviewer` returned `Agent type 'correctness-reviewer' not found`. Neither v1.4.0 string is in context |
| **P2, A1 running `/code-review <base>...<head>`** | Same agent and skill lists, so no review-pro was visible to the arm. It reviewed the change, and every message was `claude-opus-5-5`, `"effort":"high"` |
| **P3, A2 environment** (v1.5.0 installed at project scope, with a marker line added to the copy's `review-pro` skill and `correctness-reviewer` agent) | Each review-pro agent and skill is listed exactly once. The loaded skill returned the marker `CANARY-A2-SKILL-PROJECT-v150-Q7` and both "all in one step" lines, and does not contain "in parallel/background". The `correctness-reviewer` subagent's system prompt carries `CANARY-A2-AGENT-PROJECT-v150-K4` |

**No leak in either direction.** Evidence: `canary/` (each session's stream and summary).

### 5. Permissions and ground-truth leakage

**Decided at gate 1: option (b).** Both arms get the same read-only git allowlist, added to the
framework's `--allowed-tools`:
`Bash(git diff:*)`, `Bash(git show:*)`, `Bash(git log:*)`, `Bash(git merge-base:*)`,
`Bash(git rev-parse:*)`, `Bash(git show-ref:*)`, `Bash(git ls-files:*)`, `Bash(git grep:*)`,
`Bash(git blame:*)`, `Bash(git status:*)`, `Bash(git cat-file:*)`. The permission mode stays the
framework's `acceptEdits`.

**Why this is needed.** Before item 3, the operator's own permission rules reached A1 through
`~/.claude/settings.json`. Without them, Bash is denied in both arms: in the canary's P2,
`/code-review`'s `git diff` was refused, and it fell back to reading files.

**`gh`, WebFetch and WebSearch stay unavailable, so the ground truth cannot leak.** AACR-Bench's
references are real PR review comments on public GitHub PRs:
- `gh pr view --comments` would fetch them;
- a web search for the PR would find them.

No arm gets `gh` or the web. As a consequence, A2's external-premise verification cannot use the
network, and those premises stay unverified in its report. That is recorded, not scored.

**The history after `head` is removed, for the same reason.** The framework keeps a full clone
of each repository as a cache: every branch and tag, fetched again on every run. It includes the
default branch as it is today, which holds the merged PR and any commit that answered the review
comments. In such a checkout, `git log --all` or `git show main:<path>` would show the answer
key. Deleting refs alone is not enough, because the read-only `git cat-file --batch-all-objects`
still lists unreachable objects.

So before every instance, in both arms, the plumbing builds a fresh **isolated instance
repository**:
1. `git init`, with automatic gc turned off.
2. A `file://` fetch from the cache of exactly two refs, with `--no-tags`. It transfers only the
   objects reachable from `head` and from `base`, and nothing after `head` exists there to find.
   The refs are `pr-head` (at `head`, checked out) and `pr-base` (at `base`).
3. No remote is configured and no tags come across. `FETCH_HEAD` is removed, and the reflog is
   expired.

The session's working directory and `--add-dir` point at this repository. The cache lies outside
every directory the session is allowed to read. A2's `.claude/` install (item 3) goes into this
repository, which is deleted after the instance.

**Every instance checks itself, with no LLM.** The plumbing asserts that the cache's current
default-branch tip is absent from the isolated repository, by all three of:
- `git cat-file -e`;
- `git rev-list --all`;
- `git cat-file --batch-all-objects`.

It also asserts that `git merge-base <base> <head>` resolves (item 12). An instance that fails
either check is not reviewed, and is recorded as an infrastructure failure for both arms.

### 6. A2 invocation and the finding contract

These are pre-freeze adapter changes, and the mapping code is frozen and published (adapter
rule 5).

- **Prompt:** "Run the review-pro skill with exactly this argument, the base commit:
  `<base_commit>`." The argument is the full 40-character sha, because review-pro's orchestrator
  stops and asks when it gets a short one.
  - The slash form is not used. A headless probe on 2026-09-28 showed that
    `/<skill> <arg>` followed by more lines passes every following line as part of the argument.
    The sentence form passed the sha alone.
  - The prompt is followed by the reporting instruction:
  - A finding is confirmed only when it appears in the final report, so nothing is reported
    before the report is written.
  - After synthesis, call the report tool once for every finding in the final report: every code
    finding at every severity, Low and Nitpick included, and every spec-axis finding.
  - Report nothing from "Refuted in verification". The product's synthesis output lists those as
    refuted, not as findings.
  - Fields:
    - `file` and `line` are the finding's own; omit `line` when it is 0.
    - `summary` is `[<Severity>] <title>`.
    - `failure_scenario` is the finding's impact, then its remedy.
- **Fallback, the analogue of A1's stdout-JSON fallback:** if the report tool received no call,
  the adapter parses the final report's finding lines deterministically. The format is the one
  fixed in `core/skills/review-pro-synthesize/SKILL.md` at v1.5.0.
- **Scoring:** the framework's evaluation stage has no parser for `review-pro`. It falls through
  to another harness's parser and scores every A2 finding as zero. The evaluation stage maps
  `review-pro` to the Claude parser, which has the same MCP contract, and to the Claude token
  accounting.
- **Unchanged and shared with A1:** the appended findings system prompt, the MCP server, the hook
  and the retry settings.

### 7. Ground truth: 2,145, 1,505 and 190

These are three different sets, and all three are right:

| Set | PRs | Comments |
|---|---|---|
| **Positive samples** (`positive_samples.json`) | 196 | **1,505** |
| **Negative samples** (`negative_samples.json`) | 155 | 640 |
| **Union** | 200 (151 in both) | **2,145** |
| **This study's sample** (`--limit 30 --seed 42`, drawn from the positive set) | 30 | **190** |

- **2,145** is positive plus negative. It is the number the AACR-Bench README and this
  registration's "Why this benchmark" section cite.
- **1,505 is what the framework scores.** Its converter reads only `positive_samples.json` and
  never loads the negative set, and it keeps every comment, AI-written and human alike, dropping
  only an empty path or note. This is the "1,505" in OCR's README.
- **190 is this study's sample.** Its context split is Diff 84, File 82, Repo 24.

The registration's "2,145 reference comments" is therefore the dataset's size, not the scored
set; every metric in this study is computed over the sample's 190. The positive set's own
context split is Diff 754, File 518, Repo 233.

### 8. The primary endpoint's arithmetic, fixed before any scored run

The lock names the endpoint and the test but not the arithmetic below. It is filled in here,
before any instance has been reviewed.

- **Context labels.** The framework's converter discards each reference's `context` label, so the
  judge output does not carry it. A study-side script, published with the results, joins each
  scored reference in the judge's per-instance output (`eval_res[].comments[]`) back to
  `positive_samples.json`.
  - The join key is the head commit, the path and note (both stripped, as the converter does),
    and `from_line`/`to_line`.
  - On the 190 references it is exact: 0 unjoined, 0 ambiguous.
- **Per-instance repo-context recall** is the instance's repo-labeled references the judge marks
  `semantic_match`, divided by its repo-labeled references. `semantic_match` is the framework's
  own recall numerator. The value is averaged over the three judge rounds.
- **Instances with no repo-labeled reference have no primary delta.** 16 of the 30 are such
  instances.
  - Decided at gate 1: they are left out of the primary test, and every secondary endpoint still
    counts them.
  - The primary test therefore runs on at most **n = 14** instances, holding 24 references, 1 to 4
    each, before zero deltas.
- **Test:** Wilcoxon signed-rank on the per-instance deltas (A2 − A1), α = 0.05, zero deltas
  dropped (`zero_method="wilcox"`) with their count reported, and the exact distribution.
  - **Two-sided**, decided at gate 1, because the lock names no side.
- **Descriptive, not a test:** each arm's pooled repo-context recall over all 24 repo-labeled
  references. It is the sum of their `semantic_match` over the 24, averaged over the three judge
  rounds, reported with both arms side by side. It is a descriptive statistic of the kind the
  lock allows, and carries no second test.
- **Power, stated before the fact.** With at most 14 pairs and coarse per-instance values, the
  test has little power. A non-significant result means "no pattern shown", not "no effect".
  The per-instance table is published either way.
- **One of the 190 references is on the diff's left side, and it can never match in either arm.**
  The framework marks every generated comment as right side, and the judge rejects a side
  mismatch. The framework is left as is, and this is recorded.

### 9. Additional recordings (secondary; not endpoints; never promoted)

These are recorded, and none of them is an endpoint:
- **A2 stage timing and tokens.** Wall time and tokens per stage for every A2 instance: triage,
  each reviewer, the verifiers, synthesis. The numbers come from the session transcripts by
  roadmap item 4's method (`studies/2026-09-cost-measurement/tally.py`). They re-check item 4's
  acceptance of one-step dispatch, which was accepted without meeting its wall-time criterion.
- **A2's raw reviewer answers,** kept verbatim. `studies/2026-09-anchor-spike/measure.py` runs on
  them, with hand review as in item 2. A wrong-line rate above 5% reopens roadmap item 2.
- **Tokens for both arms:** the framework's per-instance `modelUsage`, plus the transcript tally.

### 10. Judge

- **The judge is unchanged:** GLM-5.3, id `glm-5.3`, at `https://api.z.ai/api/coding/paas/v4` (the
  fork's environment template). z.ai still lists it (docs.z.ai, 2026-09-28).
- **The API key was not rotated, by the maintainer's deliberate decision** (gate 1). A previous
  key had appeared in a session transcript.
- **The key is kept out of every output.** It lives only in the fork's `evaluation/.env` as
  `JUDGE_API_KEY`. That file is never read, printed or logged by the study's tooling. Its presence
  is checked only by a count that shows no value: `grep -c '^export JUDGE_API_KEY=..*'`.
- **Access is tested once before any scored evaluation.** After the smoke run and before gate 2,
  the judge gets one fabricated finding pair, never a benchmark instance, as the lock's probe
  rule allows. The response is checked for the key's absence.
- **A mocked judge cannot pass as the scored one.** The framework's judge falls back to a mock
  silently when `JUDGE_API_KEY` is missing. The scored evaluation adds a fail-fast check (plumbing)
  for that case.

### 11. Running order

- **Both arms run over the same block of instances each sitting,** in the seed's fixed order,
  with concurrency 1. This way model or service drift across days touches both arms of an
  instance together.
- **The smoke run** is instances 1 to 5 of that order, with `JUDGE_USE_MOCK=true`, under a
  separate run id, excluded from every metric.

### 12. Checks before the smoke run, with no LLM

For all 30 instances, the isolated instance repository of item 5 is built from the cache. Two
things are checked there:
- **`git merge-base <base> <head>` resolves.** review-pro v1.5.0 stops when there is no merge
  base, so on a shallow or unrelated history A2 would report nothing.
- **The leak assertion holds.**

The result is published before the smoke run. An instance that fails is an infrastructure
failure and is logged. It is not re-sampled.

### 13. Filled at freeze (before the smoke run), 2026-09-30

| Component | Pin |
|---|---|
| Fork branch + commit | `tufantunc/aacr-bench` `feat/review-pro-reviewer` @ `e899595e2ebaf6fa05a7c7b79e6f574aaed60888` |
| Claude Code binary, both arms | `2.1.283`, run from `evaluation/bin/claude-2.1.283` (sha256 `d8cb1e5c79684cc12a8bfc813e3a2073406921b6245744b3009be3ab5651d21e`, checked at start), named by `CLAUDE_BIN` in `tools/study_env.sh`. The CLI on `PATH` had updated itself to 2.1.285 on 2026-09-30, so the pinned binary is copied out of reach of the updater |
| review-pro tarball | `evaluation/vendor/review-pro-1.5.0.tgz` (sha256 `291c90c396c68a78e1a78c79800dc580dda156bcad5054a299c530a6c4b9a716`; npm integrity as in item 1, checked before every run and every install) |
| Sample file | `data/aacr_bench.jsonl` sha256 `a8bfbc86644c60243f43cf8f8ac0c603fb00837e16e8dc78e6b8491fb9c79455` |
| Logged infrastructure failures, skipped in both arms | `study_infra_failures.json`: #5, #13, #19 (`INFRA-FAILURES.md`) |
| Judge model id + endpoint | `glm-5.3` @ `https://api.z.ai/api/coding/paas/v4`, confirmed by the one-pair probe before gate 2 |

Adapter file sha256s, under `evaluation/`:

| File | sha256 |
|---|---|
| `reviewers/claude_reviewpro.py` | `b3ddc75532f558e88b1d29634f0153dd9226ae56a2e993f9c6fe504e134ab0d9` |
| `reviewers/claude.py` | `61942121fe98311695bb90dbbd5f782440a4e78f4447ba2f9fdc70a139249f0a` |
| `study_isolation.py` | `2cae31a410882bc2ba78fb9901348f4e95bc7767fa34014dc25309d1e4ab132c` |
| `tools/check_isolation.py` | `6bacb1e95385d4ab78f9095230b829607f8d887f3cbf4832425dbd7af5bfaeb6` |
| `tools/study_env.sh` | `3ba28026f40621392e6988169b24a7ccdf9fa66b7984390b032464432e7fc44a` |
| `study_infra_failures.json` | `2cdfdfa41c7ea397a01bffb50069518259866798b00f80f1d9e2dc1cfadb098c` |
| `mcp_finding_server.py` | `328ef85186711c6b5a9c39771de6de47557254a262393b7967e6aac359c34b4e` |
| `hooks/on_stop_failure.py` | `7c3157f70c54e3838cb87596385d1ed680bc5b40ad1c60c51310df53c83469b5` |
| `config.py` | `d0ea689bb925187729bcd16e236c61dd565f850eefe57c268f9768d68130b79c` |
| `pipeline.py` | `f31a10d30a5dd1c8d8fa74e58a340c66ad57c7dc5e12a7b41945c9b64d21a17e` |
| `repo_utils.py` | `25ba5dc1933f7e3ececd27b1500179748c4d29e82e4ce46715b58b35216d2b09` |
| `evaluate.py` | `4560edb9e0cb9bbe8978250c2f817ffd02743f1579f9273d54b17169b1a939a1` |
| `judge.py` | `c5305284ae895d7d184a181bc3eb1ba6c3aee1d163cf37435138cd3dd7af663a` |
| `schema.py` | `55310e814bbb649170a17acd5f76889ff032b81ce9722f5f3c26e04a809cb68f` |
| `converters/aacr_bench.py` | `ff91d08efbfc72ad39d7b863eebeecb9bc653ab4f46dfed7ab1352fc479582d3` |

**Plumbing between this amendment's lock (`4cfb950`) and the freeze.** All of it predates the smoke
run. The fork diff from `73e9b3f` is published.
- `433c304`:
  - the shared `study_isolation.py`: flags, the allowlist, the isolated instance repository with
    its checks, transcripts;
  - A2's install from the tarball, its prompt and its report parse;
  - `evaluate.py`'s `review-pro` mapping and the fail-fast on a silent mock judge;
  - serial runs keep the seed order. Before this, the pipeline grouped instances by repository
    even at concurrency 1, which would have broken the prefix rule;
  - `tools/check_isolation.py`, and the parser tests.
- `05aee87`: the cache's network fetch is skipped when both commits are cached, and a shallow
  isolated repository is rejected.
- `e899595`:
  - the logged infrastructure failures are skipped in every arm;
  - the pinned Claude Code binary;
  - the tarball is checked before the first instance.

**Observed at freeze.** Claude Code auto-allows read-only shell commands such as `ls` in both arms,
beyond the git allowlist. `gh`, WebFetch and WebSearch were confirmed denied.

## Amendment 3, 2026-09-30: `git ls-tree` in both arms' allowlist

Made after the smoke run and before any scored run, by the maintainer's decision at gate 2. It
changes one thing, the same way for both arms. The hypotheses, endpoints, sample, judge, test and
every other item of Amendment 2 stand.

**The change.** `Bash(git ls-tree:*)` is added to Amendment 2 item 5's read-only git allowlist, in
both arms.

**Why.** In the smoke run, review-pro v1.5.0's own stack-signal step ran
`git ls-tree -r --name-only <merge-base> .review-pro`, which reads the merge base's pack files
(ADR-0012). It was denied, because the registered list lacked that read-only command. A1 made no
such call. `git ls-tree` reads only objects already in the isolated instance repository, which
holds nothing after head.

**What stays closed.** `git -C <path>`, which the smoke also saw denied. Allowing it would let a
session point git at the framework's clone cache, whose history runs past head. `gh`, WebFetch
and WebSearch stay unavailable too (item 5).

**Checked 2026-09-30** with the pinned 2.1.283 binary and the new list: `git ls-tree` ran;
`git -C <path> log` and `gh --version` were denied.

**Freeze table update (item 13).**

| | |
|---|---|
| Fork commit | `32d213cf645bae4ae748922e74aedcb6960c5077`. On top of `e899595` it adds `b1c5283`, the post-smoke parse fallback (plumbing, published), and this amendment's allowlist change |
| `study_isolation.py` | `1f9a888b9db59ef1e44e98cfaa803595e45ae2925bda60be6e79973143862444` |
| `reviewers/claude_reviewpro.py` | `9169b536875f9613b4cffd0171c6320f8896f763ac4ca6c2a3efa74488e8ffaf` (`b1c5283`) |

Every other file keeps its item 13 sha256.

## Conflict of interest

The study author maintains review-pro. Same posture as the pilot: pre-committed
design, external ground truth, everything published including losses, and the
instance-level raw outputs available for independent re-scoring.

## Publication

Everything lands in `studies/<date>-aacr-bench-comparison/` in the review-pro
repo: this document with amendments, the instance list, per-instance raw findings
for both arms, judge outputs per round, metrics, costs, adapter code reference,
and the write-up. AACR-Bench is cited (repo + arXiv:2601.19494).
