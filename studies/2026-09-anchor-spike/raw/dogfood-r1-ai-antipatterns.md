<!-- commit read: 14c52d4; extracted verbatim from the PR #78 dogfood review's subagent final report -->
- severity: Low
  category: ai-antipatterns.ignored-convention
  file: core/skills/review-pro/SKILL.md
  line: 63
  title: The orchestrator's inline-synthesis step lists every remaining synthesis step except the new Coverage step
  evidence: |
    Continue the `review-pro-synthesize` skill from **Verification results**, with the verification results and the same triage values: apply the results, calibrate severity (anti-overreporting), run the out-of-diff check, and emit the verdict. Do not merge again: the results are bound to the merged findings as they stand.
  evidence_refs: [core/skills/review-pro-synthesize/SKILL.md:20, core/skills/review-pro-synthesize/SKILL.md:19]
  impact: The earlier review-level signal was wired into this sentence. `git log -S'run the out-of-diff check'` shows 8649dad (ADR-0009) added "run the out-of-diff check" to this exact step when that check was introduced. The synthesis skill now puts step 8 **Coverage** between step 7 (out-of-diff) and step 9 (Verdict). But the orchestrator's summary of what it does after verification still ends at "run the out-of-diff check, and emit the verdict". The branch updated step 4 of the same file to carry `context.changed_files` and missed this sentence. On the inline path, the only instruction to compute coverage is now the Output template line (SKILL.md:74) and the "continue from Verification results" pointer. The step enumeration does not name it. No validator pin covers it: validate.sh pins step 3, the inline block and the template order, but not step 5.
  remedy: Change the list to "... run the out-of-diff check, compute coverage, and emit the verdict". If you want it guarded like the other orchestrator sentences, add a matching `grep -qF` pin with a mutation case in Case AU.
  confidence: medium
  overlap_hints: [correctness.logic]

- severity: Nitpick
  category: ai-antipatterns.over-engineering
  file: scripts/validate.test.sh
  line: 1321
  title: w_tri is a one-line alias for write_stage_skill with no argument added
  evidence: |
    stage_fixture review-pro-triage orchestrator write_stage_skill; TRI="$STAGE"
    w_tri(){ write_stage_skill "$1"; }
    stage_mutation "$TRI" w_tri "the coverage comparison is gone" "triage coverage comparison" grep -vF "coverage check compares against it"
  evidence_refs: [scripts/validate.test.sh:317, scripts/validate.test.sh:165]
  impact: The existing wrappers `w_verify`, `w_synth` and `w_orch` (validate.test.sh:317-319) exist to pass a second argument. `write_stage_skill` already defaults to review-pro-triage (line 169: `local name="${2:-review-pro-triage}"`), and the line directly above passes `write_stage_skill` to `stage_fixture` without a wrapper. `stage_mutation` calls `"$writer" "$file"` the same way, so the alias adds nothing.
  remedy: Drop `w_tri` and pass `write_stage_skill` as the writer to `stage_mutation`, as the `stage_fixture` call on line 1320 already does.
  confidence: high
  overlap_hints: [craft.code-judo]

- severity: Nitpick
  category: ai-antipatterns.over-engineering
  file: studies/2026-09-coverage-spike/analyze.py
  line: 79
  title: non_studies is computed and never used
  evidence: |
    non_studies = [f for f in changed if not f.startswith("studies/")]
    print(f"not_examined outside studies/: {sorted(f for f in not_ex if not f.startswith('studies/'))}")
  impact: This is a dead variable. The next line recomputes the same "outside studies/" filter inline. It is harmless in a one-off study script, but a reader may assume a count is missing from the output.
  remedy: Delete line 79, or use it on the next line.
  confidence: high
  overlap_hints: [dry.copy-paste]

Checked against the requested conventions, no finding:
- The new block keys (`examined`, `not_examined`, `file`, `reason`) follow the snake_case YAML style of `## Premise verification`.
- The output-schema.md addition is additive. It changes no existing field, which fits the frozen v1.0 contract.
- The validator pins use the same `grep -qF` phrase plus `add_error "<file>: <what> - <consequence>"` form as the External premises and out-of-diff pins. Each pin has an isolated `stage_mutation` test.
- `context.changed_files` already existed in triage's dispatch plan template, so it is not an invented key.
- The `## Files examined` section is byte-identical across all 12 code reviewer bodies. None of those bodies contains a backslash or `"""`, which would break the Codex TOML embedding.
- The directory-collapse rule (more than 10 files, first two path segments) looks specific. It is justified in the design spec by the #74 data (103 lines become 3), so it is not speculative.
- The section-scoping awk appears three times in validate.sh (lines 36, 152, 265). No existing helper was ignored, since main had none. That is a duplication question for dry.

## AI-Antipatterns findings (3 above; none Critical/High/Medium)

## Files examined
examined: [README.md, cli/README.md, core/agents/a11y-reviewer.md, core/agents/ai-antipatterns-reviewer.md, core/agents/correctness-reviewer.md, core/agents/craft-reviewer.md, core/agents/dry-reviewer.md, core/agents/security-reviewer.md, core/agents/tests-reviewer.md, core/agents/review-pro-synthesize-subagent.md, core/shared/output-schema.md, core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro-triage/SKILL.md, core/skills/review-pro/SKILL.md, docs/internals/adr/0010-report-coverage-as-self-reported.md, docs/internals/glossary.md, docs/internals/reviewer-directive.md, docs/llms.txt, docs/superpowers/plans/2026-09-26-ocr-lessons-roadmap.md, docs/superpowers/specs/2026-09-26-coverage-accounting-design.md, scripts/validate.sh, scripts/validate.test.sh, studies/2026-09-coverage-spike/PRE-REGISTRATION.md, studies/2026-09-coverage-spike/README.md, studies/2026-09-coverage-spike/analyze.py, studies/2026-09-coverage-spike/raw/craft.analysis.txt]
not_examined:
  - file: core/agents/api-contract-reviewer.md
    reason: only hash-compared its extracted Files examined section against the ai-antipatterns body (identical); diff not read
  - file: core/agents/backend-reviewer.md
    reason: only hash-compared its extracted Files examined section (identical); diff not read
  - file: core/agents/db-reviewer.md
    reason: only hash-compared its extracted Files examined section (identical); diff not read
  - file: core/agents/frontend-reviewer.md
    reason: only hash-compared its extracted Files examined section (identical); diff not read
  - file: core/agents/performance-reviewer.md
    reason: only hash-compared its extracted Files examined section (identical); diff not read
  - file: docs/superpowers/plans/2026-09-26-coverage-accounting.md
    reason: read only the header and Global Constraints (lines 1-40) plus a heading grep; the task bodies were not read
  - file: studies/2026-09-coverage-spike/changed.txt
    reason: study data (file list), saw only the first 5 lines
  - file: studies/2026-09-coverage-spike/prompt.md
    reason: study input prose, saw only the first 20 lines
  - file: studies/2026-09-coverage-spike/raw/correctness.md
    reason: raw study output, saw only the first 3 lines
  - file: studies/2026-09-coverage-spike/raw/craft.md
    reason: raw study output, saw only the first 3 lines
  - file: studies/2026-09-coverage-spike/raw/tests.md
    reason: raw study output, saw only the first 3 lines
  - file: studies/2026-09-coverage-spike/raw/correctness.analysis.txt
    reason: generated analyzer output, not read
  - file: studies/2026-09-coverage-spike/raw/tests.analysis.txt
    reason: generated analyzer output, not read
