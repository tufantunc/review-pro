# Study status (hand-off notes)

Read this first if you pick the study up. Updated at every gate and at the end of every run day.

## 2026-09-28: gate 1 (Amendment 2 drafted, awaiting the maintainer)

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

**Adapter freeze: not ready,** for the same reasons. The freeze fills Amendment 2 item 12.

## Run log

No review has run under this registration. The only earlier result file is the failed August A2
smoke attempt (`Not logged in`), in the fork's `results/aacr_bench/review-pro/smoke/`.
