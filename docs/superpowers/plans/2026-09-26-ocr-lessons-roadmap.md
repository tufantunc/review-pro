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

**Status.** implemented on `feat/coverage-accounting`, in review. Measured first in `studies/2026-09-coverage-spike/` (on #74, 103 of 119 files were read by no reviewer, all data or design prose, and 0 of 42 "examined" declarations were false); decision in ADR-0010, design in `docs/superpowers/specs/2026-09-26-coverage-accounting-design.md`.

### 2. Anchor findings to the quoted code

**Problem.** `file` and `line` are mandatory, but the model supplies the line number. OCR never asks for a line: the model quotes the code (`existing_code`), code finds it in the diff with a sliding window, and a separate model call re-extracts the snippet when matching fails (`internal/config/toolsconfig/tools.json`, `internal/diff/relocation.go`).

**Direction.** Our `evidence` is already required to be a verbatim excerpt. Check it against the file at `file:line`, correct the line when the excerpt is found elsewhere in the file, and mark the finding when it is found nowhere.

**Status.** not started

### 3. Path-scoped repository rules

**Problem.** Some things the repository knows cannot be discovered by reading code, only written down by a maintainer. Our own releases missed a stale `docs/llms.txt` and a hero heading stale in seven languages, and no reviewer caught either. OCR's own `.opencodereview/rule.json` holds exactly this kind of rule ("a change to `providers.go` must update the provider table in four language docs").

**Direction.** A repo-level rules file with glob-matched rules that triage hands to the reviewers of matching files. It extends the "what the repository already knows" thesis rather than competing with it. Stack packs stay as they are.

**Status.** not started

### 4. Cost that scales with the change

**Problem.** We have never measured tokens per review. On OCR's leaderboard, Claude Code runs cost roughly 4 to 5.6M tokens per review against 0.35 to 0.7M for OCR. OCR skips its plan phase under 50 changed lines and stops a round early when it adds no new finding. Our only size signal is `diff_class`.

**Direction.** Measure first (tokens and wall time per review on a few real diffs of different sizes), then decide which stages scale down on small changes.

**Status.** not started

### 5. Run the AACR-Bench comparison

**Problem.** The study is pre-registered and parked on the arm-isolation decision. OCR's leaderboard now gives a public Claude Code baseline on the same benchmark with the same models.

**Direction.** Resolve the isolation decision and run the study. Before running, reconcile the ground-truth count: OCR's README cites 1,505 annotated issues, our pre-registration cites 2,145 reference comments. The leaderboard is run by the benchmark's own authors, which the write-up must state.

**Status.** not started
