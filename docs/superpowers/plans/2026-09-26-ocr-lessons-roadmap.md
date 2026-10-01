# Roadmap: lessons from alibaba/open-code-review

Status: complete. One item per session and per PR, in order. Each item was reviewed before the next one started.

## Why this exists

[alibaba/open-code-review](https://github.com/alibaba/open-code-review) (OCR, read at `486022d`, 2026-09-26) is a Go CLI that runs its own agent loop against any configured LLM. Its team also publishes AACR-Bench, a repository-level code review benchmark. Its README names "Claude Code with Skills" as the architecture it beats, and lists three failures of that architecture: files silently skipped on large changesets, comments that land on the wrong line, and quality that drifts with prompt wording. review-pro is that architecture, so the critique is aimed at us.

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

**Revisit when.** The planned check, `studies/2026-09-anchor-spike/measure.py` over real code in other languages, was to run on item 5's outputs. Item 5 ran internally and its results are not published, so item 2 stays closed on the published evidence above.

### 3. Path-scoped repository rules

**Problem.** Some things the repository knows cannot be discovered by reading code, only written down by a maintainer. Our own releases missed a stale `docs/llms.txt` and a hero heading stale in seven languages, and no reviewer caught either. OCR's own `.opencodereview/rule.json` holds exactly this kind of rule ("a change to `providers.go` must update the provider table in four language docs").

**Direction.** A repo-level rules file with glob-matched rules that triage hands to the reviewers of matching files. It extends the "what the repository already knows" thesis rather than competing with it. Stack packs stay as they are.

**Status.** merged in #80. Measured first in `studies/2026-09-repo-rules-spike/`: over 66 merged PRs the draft co-change rules triggered 44 times, 77% legitimate; the judgment step cleared 8 of 8 legitimate triggers and caught 3 of 4 known misses (a count spelled as a word cannot trigger a file-level rule). Decision in ADR-0011, design in `docs/superpowers/specs/2026-09-27-repo-rules-design.md`; this repository's own rules in `.review-pro/rules.md`.

### 4. Cost that scales with the change

**Problem.** We have never measured tokens per review. On OCR's leaderboard, Claude Code runs cost roughly 4 to 5.6M tokens per review against 0.35 to 0.7M for OCR. OCR skips its plan phase under 50 changed lines and stops a round early when it adds no new finding. Our only size signal is `diff_class`.

**Direction.** Measure first (tokens and wall time per review on a few real diffs of different sizes), then decide which stages scale down on small changes.

**Status.** measured; one change shipped: foreground dispatch (accepted on mechanism; the wall-time criterion was not met). Phase A ([`studies/2026-09-cost-measurement/`](../../../studies/2026-09-cost-measurement)). A review cost 0.72M tokens on a one-file docs change, 2.42M on a 22-line code change and 2.32M on a 364-line change: cost follows the number of agents and orchestrator turns, not the change's size. None of the pre-registered levers is worth a design (narrowing the dispatch by size would have lost every Medium finding; the prompt text review-pro controls is about 3%); one post-hoc candidate, collecting agent results in one turn instead of one orchestrator turn per background agent (13 to 20% of a review), waits on a spike and the maintainer's decision. The same runs cleared item 3's triage-fidelity gate (15 of 15 rule rows) and J07 (`violated` in 6 of 6). The large diff (#78) was not run. Foreground-dispatch spike ([`studies/2026-09-foreground-dispatch/`](../../../studies/2026-09-foreground-dispatch)): dispatching every agent in one step removed the waiting turns on both diffs (0 from 5 and 6) with no stage lost, but wall time rose 32% and 47%, inside the pre-registered 25 to 50% band, so the decision was the maintainer's: accepted, because the whole increase sits in the slowest reviewer's own run time, which the dispatch mode cannot move.

### 5. Run the AACR-Bench comparison

**Status.** run internally (2026-09-30 to 2026-10-01). The results are not published, and the pre-registration was withdrawn from `studies/`.
