# Study status (hand-off notes)

Read this first if you pick the study up. Updated at every gate and at the end of every run day.

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

No review has run under this registration. The only earlier result file is the failed August A2
smoke attempt (`Not logged in`), in the fork's `results/aacr_bench/review-pro/smoke/`.
