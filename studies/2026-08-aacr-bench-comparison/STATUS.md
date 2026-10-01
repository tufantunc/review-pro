# Study status (hand-off notes)

Read this first if you pick the study up. Updated at every gate and at the end of every run day.

## 2026-09-30, after gate 2 decision 1: Amendment 3 committed; waiting on the go-ahead

- **Amendment 3 committed.** `Bash(git ls-tree:*)` is in both arms' allowlist. Fork
  `32d213c`; `git ls-tree` runs, and `git -C` and `gh` stay denied, checked with the pinned
  binary.
- **Duration estimate for the scored run,** 27 instances, from the smoke's measured wall time
  including preparation: A1 97 s and A2 349 s per instance.
  - **Review stage:** A1 about 45 to 65 min, A2 about 2.6 to 3.9 h. The high ends allow for the
    smoke's small changes: the sample's median is 77 lines, against the smoke's 12 to 142.
  - **Judge:** about 400 requests at about 7 s, 45 to 60 min.
  - **Total machine time:** about 4.5 to 6 h.
  - **Subscription load:** about 90 points of a five-hour window, so two sittings.
- **Waiting on:** the maintainer's go-ahead for the scored run.

## 2026-09-30: gate 2 (smoke done, waiting on the maintainer before the scored run)

**Freeze.** Fork `e899595` (Amendment 2 item 13, committed `8cb26e9`). Since the freeze, one
plumbing change, parsing only and published: `b1c5283`. When the report tool gets no call, A2's
report-parse fallback reads the `## Verdict` message from the transcript.

**Smoke** (run id `smoke-amend2`, instances 1 to 5, both arms, mock judge; excluded from every
metric; outputs in `smoke/`):
- **Instances:** #5 was skipped as a logged failure in both arms; the other four were reviewed
  in each arm, all with exit 0.
- **Leak check:** every instance logged "leak check: <default-branch tip> absent".
  `smoke/leak-proof.txt` shows it on #1: in the isolated repository, `git show` of the cache's
  tip is a bad object, `git log --all` ends at head, and 9,221 commits against the cache's 24,991.
- **A1:** 6, 10, 10 and 10 findings, all through the stdout-JSON path; `/code-review` never
  called the report tool.
- **A2:** 3, 8, 8 and 14 findings through the report tool. Each count equals its final report's
  findings: 3 by parse of the final answer, and lvgl's 8 against the report in its transcript,
  same (file, line) set.
- **Effort and binary:** effort `high` on every message of every session; CLI 2.1.283 recorded
  on every result.
- **Denied tool calls.** A1 made 2 (grep, awk). A2 made 55 over four instances:
  - `gh` 4 and WebFetch 2: ground-truth protection working;
  - `git -C <path> ...` forms, which do not match the allowlist. That is also what keeps the
    cache out of reach;
  - `git ls-tree`, which v1.5.0's stack-signal step uses and the allowlist lacks;
  - compound commands that contain a non-allowed part.
- **Mock evaluation, 3 rounds:** 4 instances and 14 references per arm; 36 and 33 generated,
  matching the result files. The judge ran 27 and 33 requests. The context join in `primary.py`
  is exact on the 14.
- **A2 stages** (`smoke/a2-stages.json`): triage 40 to 79 s; reviewers all concurrent, union 34 to
  124 s; verifiers up to 4 concurrent, union 19 to 78 s; synthesis 50 to 170 s.
- **Judge probe:** one fabricated pair (`canary/judge-probe.json`). `glm-5.3` at the z.ai
  endpoint, not mock, answered "yes" in 6.6 s, and the key is absent from the response.

**Cost of the smoke.**
- **A1:** 0.77M tokens and 5.4 review-minutes for 4 instances, a mean of 0.19M and 81 s.
- **A2:** 9.53M tokens and 21.7 minutes, a mean of 2.38M and 325 s.

**Estimate for the scored run** (27 instances, both arms, three judge rounds):
- **The smoke sits on the small side of the sample.** Its changes are 12 to 142 lines; the
  sample's median is 77 and its maximum 894.
- **Tokens:** A1 about 5M (range 3 to 12M), A2 about 65M (range 40 to 100M).
- **Review time:** about 3.5 hours. Judge: about 400 requests, about 50 minutes.
- **Subscription load, by roadmap item 4's calibration** (about 1.25 points of the five-hour
  window per 1M tokens): about 85 points. Planned as two sittings.

**Waiting on the maintainer:**
1. **[DECISION] `git ls-tree`.** Add `Bash(git ls-tree:*)` to both arms' allowlist by a dated
   Amendment 3 before the scored run, or keep item 5's list as registered. `git -C` stays out
   either way, because it would reach the cache.
2. **Approval of the scored run and its pacing.** Proposed: two sittings (instances 1 to 15,
   then the rest, both arms each), same `--run-id`, under `caffeinate -is`.

## 2026-09-30: item 12 check complete, 3 infrastructure failures logged, waiting on the maintainer

**Item 12 check (no LLM), all 30 instances:**
- **27 pass.** On each, the merge base resolves, nothing after head is present, and the isolated
  repository is not shallow. Per-instance output: `isolation_check.json`. The fork's
  `tools/check_isolation.py` ran on 29; #19 could not be prepared.
- **3 infrastructure failures,** logged with evidence in `INFRA-FAILURES.md`:
  - **#5 uv and #13 ComfyUI:** the head commits are gone from GitHub.
  - **#19 ClickHouse:** its history could not be downloaded; 45 transfer attempts over two days
    broke at about 80 minutes. Recorded as a failure on the maintainer's decision.
- **The scorable set is 27 instances and 167 references.** The primary test has at most 12
  instances (21 repo-context references). None is re-sampled.

**Fork:** `05aee87` on `feat/review-pro-reviewer`, added on top of `433c304`:
- the cache's network fetch is skipped when both commits are cached;
- a shallow isolated repository is rejected.

The fork is not frozen yet.

**Waiting on the maintainer before the smoke run.** Open points:
1. **At run time, the review stage would still try the three failed instances.**
   - #5 and #13 fail in seconds.
   - #19 would retry a transfer that breaks after about 80 minutes, in each arm.
   - The proposed plumbing reads `INFRA-FAILURES.md`'s three ids and skips them in both arms,
     logging each skip. The alternative is to let them fail naturally.
2. **Then the freeze** (Amendment 2 item 13), the smoke run (instances 1 to 5; #5 is logged, not
   reviewed), the judge probe, and gate 2.

The two broken ClickHouse caches (`evaluation/repo/ClickHouse__ClickHouse` and `.new`, 6.1 GB)
were deleted on the maintainer's instruction. The cache now holds the other 22 repositories.

## 2026-09-28, after gate 1: Amendment 2 committed, plumbing written, waiting on clones

**Gate 1 decisions (maintainer):**
- Permissions: option (b) for both arms.
- History after head removed, and ground-truth leakage is the stated reason `gh` and the web
  are off.
- 16 instances without a repo reference are out of the primary test; the test is two-sided;
  pooled repo recall is descriptive.
- The judge key was not rotated, on purpose, and may be used. Its presence is checked only with
  `grep -c '^export JUDGE_API_KEY=..*' evaluation/.env`, and the file is never read.

**Done:**
- Amendment 2 appended to `PRE-REGISTRATION.md` and committed (`4cfb950`, review-pro
  `study/aacr-bench-phase1`). That commit is the lock.
- Fork plumbing committed and pushed: `433c304` on `feat/review-pro-reviewer`.
  - `study_isolation.py`: flags, allowlist, the isolated instance repository with its leak and
    merge-base checks, transcripts.
  - A2 installs from the vendored `vendor/review-pro-1.5.0.tgz`, with its integrity checked, and
    parses the report when the tool got no call.
  - `evaluate.py` gains the review-pro mapping and a judge that cannot silently fall back to the
    mock.
  - Serial runs keep the seed order. Before this, the pipeline grouped instances by repository
    even at concurrency 1, which broke the prefix rule.
  - `tools/check_isolation.py`, and parser tests on three real reports (5 of 5 pass).
- Probes:
  - The allowlist works: git runs, `gh` and WebFetch are denied. Claude Code auto-allows
    read-only commands such as `ls` in both arms; recorded.
  - The sentence form of the A2 prompt passes the 40-character sha alone as the skill argument.
- The isolation check passed on instances 1 and 2 (vllm, lvgl).

**In progress:** cloning the 23 repositories (23.1 GB) into the framework cache
(`evaluation/repo/`). Three parallel `git clone` workers; roughly 1 MB/s per connection.

**Next, in order:**
1. `.venv/bin/python -m tools.check_isolation` over all 30. Every one must pass (Amendment 2
   item 12).
2. Freeze: record the fork commit and the file sha256s in Amendment 2 item 13, and commit.
3. Smoke: instances 1 to 5, `JUDGE_USE_MOCK=true`, run id `smoke-a2` / `smoke-a1`. The leak
   proof on one smoke instance is the self-check the plumbing logs.
4. The judge probe: one fabricated pair, with the response checked for the key.
5. Gate 2.

**How to run** (from `evaluation/`):

```
set -a && source .env && source tools/study_env.sh && set +a
```

## 2026-09-28: gate 1 (Amendment 2 drafted; superseded by the entry above)

**Done:**
- **Read:** the locked design (`PRE-REGISTRATION.md` with Amendment 1), `INSTANCES.md`, and the
  fork `tufantunc/aacr-bench` @ `73e9b3f` (`feat/review-pro-reviewer`).
- **Checked the review-pro pin:** npm `review-pro@1.5.0` and GitHub Release `v1.5.0` both exist,
  and the tarball's plugin tree equals `core/` at tag `v1.5.0` (`5a4c599`).
- **Ran the canary on both arms** with the proposed flags. There is no leak either way: A1 sees no
  review-pro, and A2 sees only the project-scope v1.5.0. Evidence is in `canary/`; summary in the
  draft's item 4.
- **Reconciled the ground truth:**
  - 1,505 is the positive set, the one the framework scores.
  - 640 is the negative set.
  - 2,145 is the union over 200 PRs.
  - 190 is this sample: Diff 84, File 82, Repo 24.
- **Checked the context join:** the study-side join of scored references back to their context
  labels is exact on all 190.
- **Checked the instance heads:** none of the 30 carries `.claude/`, `CLAUDE.md`, `AGENTS.md` or
  `.review-pro/`.

**Waiting on the maintainer:**
1. Approval of `AMENDMENT-2-DRAFT.md`. It is uncommitted on purpose. Once approved, append it to
   `PRE-REGISTRATION.md` and commit it; that commit is the lock before the smoke run.
2. [DECISION] items 5 (permissions) and 8 (the primary test's handling of instances with no repo
   references, and its sidedness).
3. Whether the z.ai judge key has been rotated. Do not call the judge before the answer.

**Smoke readiness: not ready.** These adapter changes are needed first, all before freeze:
- the flags for both arms (draft item 3);
- A2 installing from the pinned tarball into the checkout, with `.claude/` excluded and no
  `CLAUDE_CONFIG_DIR`;
- the permission policy (item 5);
- the A2 prompt and the fallback parser (item 6);
- `evaluate.py` mapping `review-pro` to the Claude parser and token path (item 6). Without it,
  every A2 finding scores 0;
- recording the CLI version and the review-pro tree hash per instance;
- keeping each instance's session transcripts;
- the judge's mock fail-fast (item 10);
- disabling auto-update.

**Already working under the new flags** (canary): subscription auth (`apiKeySource: none`), the
findings MCP server (connected), and `/code-review`, whose findings arrived through the framework's
stdout-JSON path.

**Adapter freeze: not ready,** for the same reasons. The freeze fills Amendment 2 item 13.

## Run log

**Scored run `phase1`, sitting 1** (instances 1 to 15 of the seed order; #5 and #13 are logged
failures and skipped, so 13 reviews per arm):
- A1 (`claude`) started 2026-09-30, the first scored run. Fork `32d213c`; the log is
  `evaluation/results/aacr_bench/_study/phase1-s1-claude.log`.
- **A1 sitting 1 done,** 19:06 to 19:32: 13 reviews, all with exit 0, 6.53M tokens.
  - #6's answer had one JSON syntax error, so it scores zero findings as registered. That
    triggered Amendment 4, the maintainer's decision (a): a post-hoc sensitivity analysis.
- **A2 sitting 1 started** 2026-09-30, right after. Its log is `phase1-s1-review-pro.log`.
- **A2 sitting 1 was interrupted** at 2026-10-01 00:05:37.
  - **Cause:** the orchestrating session's 30-minute limit on background commands stopped the
    pipeline. Infrastructure, not the model or the benchmark.
  - **Where:** 4 of 13 instances were done (#1 to #4). #6 (`microsoft__typescript-go@b970689`) had
    run for about 9 minutes and wrote no result and no report-tool call.
  - **Evidence:** its session transcript (`e929f90f`) is kept under
    `evaluation/results/aacr_bench/_study/interrupted/`, and it is not scored.
- **A2 resumed the same night,** with the same command and run id, now as a detached process
  outside that limit.
  - Resume skips the four finished instances and runs #6 from the start. That is the first
    complete attempt for #6 in A2, not a re-review.
  - A1 was not affected, and nothing is re-run in A1.
- **A2 sitting 1 done** 2026-10-01 00:59:53: 13 reviews, all with exit 0, 47.3M tokens, 73
  review-minutes.
  - **Reported findings match the reports on every instance.** On 12 of 13 the report-tool
    findings equal the transcript report's findings.
  - **#7 valkey** is an APPROVE with 0 findings, taken through the report-parse fallback.
  - **#6 printed no full report message.** Its 14 report-tool findings (2 High, 4 Medium, 6 Low,
    2 Nitpick) equal the counts in the final answer.
- **Sitting 1 is complete for both arms** (instances 1 to 15). A1 used 6.5M tokens, A2 47.3M:
  3.6M per A2 instance, above the smoke's 2.4M.
- **Sitting 2 done for both arms** 2026-10-01 (instances 16 to 30, #19 skipped). A1 ran
  04:09 to 04:33 and A2 04:33 to 05:55, as one detached process, uninterrupted.
- **The review stage is complete:** 27 instances per arm, every one with exit 0, all on CLI
  2.1.283.

  | Arm | Generated findings | Tokens | Review-minutes |
  |---|---|---|---|
  | A1 | 217 | 9.6M | 45 |
  | A2 | 259 | 88.4M | 153 |

  - **A1's #6** stays unparsed: zero findings as registered, and the Amendment 4 sensitivity
    applies.
  - **A2's report-tool findings equal the transcript report on every instance that printed one.**
    The fallback parser read only 3 of laravel's 11, because the report shortened repeated paths to
    `:<line>`. A parser limitation, recorded; the fallback was used only on #7 (APPROVE, 0
    findings), so no score depends on it.
- **Scored evaluation done** 2026-10-01 08:05 to 09:34: GLM-5.3, 3 rounds per arm, 0 judge call
  errors (A1 234 requests, A2 257). The Amendment 4 sensitivity was scored separately (6
  requests).
- **Results in `RESULTS.md`.**
  - H1 is not supported. On 12 paired instances the mean delta is −0.08, Wilcoxon two-sided
    p = 0.56.
  - H0-guard within budget, at +1.5 points.
  - A2 recall overall 0.425 against 0.375, at 9.2× the tokens.
- **Outputs** (without transcripts) are in `phase1/`.
- **Open:** the session transcripts, 64 MB for A2 and 5 MB for A1, are too large for this
  repository. Per the registration's "Where the work lives", they go to a release asset on the
  fork, which waits on the maintainer.
- To resume after an interruption, run the same command with the same `--run-id phase1`:

```
set -a && source .env && source tools/study_env.sh && set +a
caffeinate -is .venv/bin/python -m pipeline run --stage review --reviewer <claude|review-pro> \
  --dataset data/aacr_bench.jsonl --run-id phase1 --limit <15 for sitting 1, 30 for sitting 2> \
  --timeout-minutes 45
```

  Existing result files are skipped; resume never re-reviews. Only a logged infrastructure
  failure is re-run, in both arms (registration, Amendment 1).

No review has run under this registration. The only earlier result file is the failed August A2
smoke attempt (`Not logged in`), in the fork's `results/aacr_bench/review-pro/smoke/`.
