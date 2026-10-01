# Roadmap: lessons from alibaba/open-code-review

Status: in progress. One item per session and per PR, in order. Each item is reviewed before the next one starts.

## Why this exists

[alibaba/open-code-review](https://github.com/alibaba/open-code-review) (OCR, read at `486022d`, 2026-09-26) is a Go CLI that runs its own agent loop against any configured LLM. Its team also publishes AACR-Bench, the benchmark our pre-registered study in `studies/2026-08-aacr-bench-comparison/` uses. Its README names "Claude Code with Skills" as the architecture it beats, and lists three failures of that architecture: files silently skipped on large changesets, comments that land on the wrong line, and quality that drifts with prompt wording. review-pro is that architecture, so the critique is aimed at us.

OCR answers those failures with deterministic code around the model: file selection, bundling, glob-matched rules, quote-anchored comment positioning, and a diff-only reflection filter. We keep our own architecture (host-agent skills, repository evidence bar, specialist axes, visible refutations) and borrow the parts that answer a concrete failure.

What OCR does not have and we keep: an evidence bar that requires out-of-diff evidence for claims, the spec axis, external premise verification, and a verifier that shows what it refuted instead of dropping it silently.

## Items

### 1. Coverage accounting

**Problem.** Every dispatched reviewer receives all changed files, but reviewers return only findings. "Examined and found nothing" and "never looked" produce the same empty output, so the report cannot show that a file was skipped. OCR's delegation skill requires `total_files / reviewed / skipped (with reason) / coverage_rate` and forbids silent omission (`skills/open-code-review-delegate/SKILL.md`, Step 6); its main prompt requires a separate pass per file (`internal/config/template/prompts/main_task_system.md`, "Reply limit").

**Direction.** Synthesis reports per-file coverage from triage's `changed_files`: files no dispatched reviewer received (deterministic) and files reviewers report as not examined (self-reported, labelled as such). Review-level signal only; it never changes a finding or the verdict.

**Done when.** A review of a multi-file branch prints a coverage line, a missing report renders as "not reported" and never as full coverage, and the validator guards the new contract.

**Status.** merged in #78. Measured first in `studies/2026-09-coverage-spike/` (on #74, 103 of 119 files were read by no reviewer, all data or design prose, and 0 of 42 "examined" declarations were false); decision in ADR-0010, design in `docs/superpowers/specs/2026-09-26-coverage-accounting-design.md`.

### 2. Anchor findings to the quoted code

**Problem.** `file` and `line` are mandatory, but the model supplies the line number. OCR never asks for a line: the model quotes the code (`existing_code`), code finds it in the diff with a sliding window, and a separate model call re-extracts the snippet when matching fails (`internal/config/toolsconfig/tools.json`, `internal/diff/relocation.go`).

**Direction.** Our `evidence` is already required to be a verbatim excerpt. Check it against the file at `file:line`, correct the line when the excerpt is found elsewhere in the file, and mark the finding when it is found nowhere.

**Status.** measured, not built ([`studies/2026-09-anchor-spike/`](../../../studies/2026-09-anchor-spike)). One of 70 findings cites the wrong line, 3 lines off and inside the dedup window. A naive quote check run over the same corpus raised 5 false alarms against that one real drift.

**Revisit when.** Run `studies/2026-09-anchor-spike/measure.py` over the reviewer outputs of item 5's AACR-Bench run (its corpus is listed in `sources()`; add the new outputs there). That corpus is real code in 10 languages, which this study could not see. If wrong-line findings exceed 5% there, item 2 reopens.

### 3. Path-scoped repository rules

**Problem.** Some things the repository knows cannot be discovered by reading code, only written down by a maintainer. Our own releases missed a stale `docs/llms.txt` and a hero heading stale in seven languages, and no reviewer caught either. OCR's own `.opencodereview/rule.json` holds exactly this kind of rule ("a change to `providers.go` must update the provider table in four language docs").

**Direction.** A repo-level rules file with glob-matched rules that triage hands to the reviewers of matching files. It extends the "what the repository already knows" thesis rather than competing with it. Stack packs stay as they are.

**Status.** merged in #80. Measured first in `studies/2026-09-repo-rules-spike/`: over 66 merged PRs the draft co-change rules triggered 44 times, 77% legitimate; the judgment step cleared 8 of 8 legitimate triggers and caught 3 of 4 known misses (a count spelled as a word cannot trigger a file-level rule). Decision in ADR-0011, design in `docs/superpowers/specs/2026-09-27-repo-rules-design.md`; this repository's own rules in `.review-pro/rules.md`.

### 4. Cost that scales with the change

**Problem.** We have never measured tokens per review. On OCR's leaderboard, Claude Code runs cost roughly 4 to 5.6M tokens per review against 0.35 to 0.7M for OCR. OCR skips its plan phase under 50 changed lines and stops a round early when it adds no new finding. Our only size signal is `diff_class`.

**Direction.** Measure first (tokens and wall time per review on a few real diffs of different sizes), then decide which stages scale down on small changes.

**Status.** measured; one change shipped: foreground dispatch (accepted on mechanism; the wall-time criterion was not met, re-checked in item 5). Phase A ([`studies/2026-09-cost-measurement/`](../../../studies/2026-09-cost-measurement)). A review cost 0.72M tokens on a one-file docs change, 2.42M on a 22-line code change and 2.32M on a 364-line change: cost follows the number of agents and orchestrator turns, not the change's size. None of the pre-registered levers is worth a design (narrowing the dispatch by size would have lost every Medium finding; the prompt text review-pro controls is about 3%); one post-hoc candidate, collecting agent results in one turn instead of one orchestrator turn per background agent (13 to 20% of a review), waits on a spike and the maintainer's decision. The same runs cleared item 3's triage-fidelity gate (15 of 15 rule rows) and J07 (`violated` in 6 of 6). The large diff (#78) was not run. Foreground-dispatch spike ([`studies/2026-09-foreground-dispatch/`](../../../studies/2026-09-foreground-dispatch)): dispatching every agent in one step removed the waiting turns on both diffs (0 from 5 and 6) with no stage lost, but wall time rose 32% and 47%, inside the pre-registered 25 to 50% band, so the decision was the maintainer's: accepted, because the whole increase sits in the slowest reviewer's own run time, which the dispatch mode cannot move.

### 5. Run the AACR-Bench comparison

**Problem.** The study is pre-registered and parked on the arm-isolation decision. OCR's leaderboard now gives a public Claude Code baseline on the same benchmark with the same models.

**Direction.** Resolve the isolation decision and run the study. Record wall time per stage on every run: item 4 accepted foreground dispatch without meeting its wall-time criterion, and these runs re-check it. Before running, reconcile the ground-truth count: OCR's README cites 1,505 annotated issues, our pre-registration cites 2,145 reference comments. The leaderboard is run by the benchmark's own authors, which the write-up must state. Keep the reviewer outputs: item 2's revisit condition runs the anchor-spike script over them.

**Status.** phase 1 run and scored, 2026-10-01 ([`studies/2026-08-aacr-bench-comparison/RESULTS.md`](../../../studies/2026-08-aacr-bench-comparison/RESULTS.md)). H1 is not supported: on the 12 paired instances with repo-context references, review-pro's recall was not higher than `/code-review`'s (mean delta −0.08, p = 0.56). Overall recall was 0.425 against 0.375, within the 5-point noise budget, at 9.2 times the tokens. 27 of the 30 sampled instances were reviewed; three were logged infrastructure failures. Item 2's revisit condition was checked on A2's answers: 2.9% wrong-line, so item 2 stays closed. Item 4's one-step dispatch kept reviewers concurrent on real repositories. No claim is made against the published leaderboard, which the benchmark's own authors run.
