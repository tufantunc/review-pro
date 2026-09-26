<!-- commit read: 14c52d4; extracted verbatim from the PR #78 dogfood review's subagent final report -->
- severity: Low
  category: correctness.logic
  file: scripts/validate.sh
  line: 268
  title: cov_pin skips every pin when the ## Coverage section is present but empty, so a gutted section validates clean
  evidence: |
    COV="$(awk '/^## Coverage$/{s=1;next} s&&/^## /{exit} s' "$SYNTH_MD")"
    ...
    cov_pin(){ [[ -n "$COV" ]] || return 0; printf '%s\n' "$COV" | grep -qF "$1" || add_error "review-pro-synthesize/SKILL.md: $2"; }
  impact: The guard is meant to stop errors piling up when the heading is missing (the comment says "An absent section is reported once by the required-section check"). But it tests whether the extracted text is empty, not whether the heading exists. I tested this on a scratch copy of the real repo: I kept `## Coverage` and deleted its whole body, and `scripts/validate.sh .` printed no FAIL. The required-section check passed because the heading is still there, and all 7 pins returned 0. So moving the Coverage text under another `## ` heading, or emptying the section, strips the whole coverage contract with no error. Pinning single phrases (for example 'never rendered as examined') on the real file does fail correctly.
  remedy: Guard on the heading itself, for example `grep -qxF '## Coverage' "$SYNTH_MD" || return 0`. Then a section that is present but empty fails all the pins.
  confidence: high
  overlap_hints: [tests.coverage]

- severity: Low
  category: correctness.logic
  file: scripts/validate.sh
  line: 35
  title: check_header_order turns itself off silently when the orchestrator's ## Output heading or the Spec/Verification anchor lines are reworded
  evidence: |
    # No Output section at all is its own failure (a required section for synthesis);
    grep -qxF '## Output' "$f" || return 0
    ...
    if [[ -n "$s" && -n "$v" ]] && ! [[ "$s" -lt "$c" && "$c" -lt "$v" ]]; then
  impact: The comment only holds for synthesis. Nothing requires `## Output` in core/skills/review-pro/SKILL.md, and that file carries the template the inline pipeline actually returns (step 5 runs synthesis inline). On a scratch copy I renamed the orchestrator's `## Output` to `## Report` and also deleted its `Coverage (self-reported):` line, and validate.sh reported no FAIL. Separately, the order check needs both anchors, and neither `Spec: measured against` nor `Verification: <N> checked` is pinned anywhere else. Renaming either line in either template (for example `Verified: <N> checked`) also gave no FAIL, so after a reword the order can drift unchecked. The caller asked whether this can silently pass, and it can.
  remedy: Make a missing `## Output` in the file being checked an add_error rather than `return 0`. Also add_error when `s` or `v` is empty, or pin those two lines separately, so the order check cannot turn itself off.
  confidence: high
  overlap_hints: [tests.coverage]

- severity: Low
  category: correctness.logic
  file: core/skills/review-pro-synthesize/SKILL.md
  line: 54
  title: The ordered state table marks a file in both of one reviewer's lists as examined, against the rule that it counts as no entry
  evidence: |
    Put each file in `changed_files` in exactly one state, checked in this order:
    | examined | a receiver lists it under `examined`, or filed a finding in it |
    ...
    - A reviewer that returned no block, a block that leaves a file out, and a file listed in both of one reviewer's lists all leave that reviewer with no entry for the file. **A missing report is never rendered as examined.**
  impact: Take a sole receiver that lists X under both `examined` and `not_examined`. It literally "lists it under `examined`", and the table says to check states in order, so the `examined` row matches before line 59's no-entry rule can apply. Line 59 wants `not reported`. The two instructions conflict, and following the table as written overstates coverage, which is the one outcome the section forbids. It is a rare trigger: the spike found no both-lists case in 3 runs. It cannot change a finding or the verdict.
  remedy: Put the exclusion into the row itself, for example "a receiver lists it under `examined` and not under `not_examined`, or filed a finding in it". Or say explicitly that line 59's normalization runs before the table.
  confidence: high
  overlap_hints: []

- severity: Low
  category: correctness.side-effect
  file: core/skills/review-pro/SKILL.md
  line: 63
  title: The orchestrator's inline synthesis step lists the remaining synthesis steps but leaves out the new Coverage step
  evidence: |
    Continue the `review-pro-synthesize` skill from **Verification results**, with the verification results and the same triage values: apply the results, calibrate severity (anti-overreporting), run the out-of-diff check, and emit the verdict.
  impact: Before this branch the list matched synthesis steps 5 to 8 exactly. The branch inserts step 8 **Coverage** (synthesize SKILL.md:19) between the out-of-diff check and the verdict, but this list, which the orchestrator reads last, still goes straight from the out-of-diff check to the verdict. The orchestrator's Output template does show the Coverage line, but it has no detail lines (`not examined: ...`) and no sent-to-no-reviewer caveat. An orchestrator that follows this summary and its own template can therefore print a bare or guessed coverage line, where running the skill in full would give detail lines and the caveat. The inline path and the synthesis-subagent path can then produce different output.
  remedy: Add "compute Coverage" between "run the out-of-diff check" and "emit the verdict". Optionally add the detail-line placeholder to the orchestrator template, as synthesize SKILL.md:192 does.
  confidence: medium
  overlap_hints: [craft.structure]

- severity: Low
  category: correctness.logic
  file: studies/2026-09-coverage-spike/analyze.py
  line: 46
  title: Substring path matching marks root README.md as in view whenever a command names a nested README.md, which can hide an overclaim
  evidence: |
    named = [f for f in changed if f in cmd]
    in_view.update(named)
  impact: In changed.txt there is exactly one substring collision: `README.md` < `studies/2026-09-refuting-verifier/README.md`. I computed this. All three reviewers declared root README.md examined. A Bash call that named only the nested README would still put root README.md in `in_view`, so a real overclaim on it would go uncounted under Q4, and D3 rests on Q4. The bias only ever lowers the overclaim count. I could not check whether it fired, because the transcripts are not in the repo.
  remedy: Match on path boundaries, for example `re.search(r'(^|[\s/"\'])' + re.escape(f) + r'($|[\s"\'])', cmd)` with the leading `/` handled so `a/README.md` does not match. Or resolve the paths the command names before comparing.
  confidence: medium
  overlap_hints: [tests.assertions]

Other checks, none of which produced a finding:
- `bash scripts/validate.sh` passes on the branch.
- `scripts/validate.test.sh` gives pass=203 fail=0.
- On the real files, dropping or moving the Output coverage line and removing each of the 7 pinned phrases one at a time each fires the intended error.
- The awk section extraction scopes correctly on both real templates. The `## Verdict` and `## Spec (` exclusions work, and no fenced `## ` line ends a section early.
- Codex install still works. `mdToCodexToml` embeds the body raw in `"""`, and no agent body contains a backslash or `"""`.
- The `## Files examined` section is byte-identical across all 12 code reviewer bodies. Every step 4 and Final reminder names the block, and the spec body is correctly exempt through `loads_skill`.
- Triage, orchestrator step 3/4 and the synthesis inputs agree on per-reviewer `context.changed_files`.

## Files examined
examined: [README.md, cli/README.md, core/agents/a11y-reviewer.md, core/agents/ai-antipatterns-reviewer.md, core/agents/api-contract-reviewer.md, core/agents/backend-reviewer.md, core/agents/correctness-reviewer.md, core/agents/craft-reviewer.md, core/agents/db-reviewer.md, core/agents/dry-reviewer.md, core/agents/frontend-reviewer.md, core/agents/performance-reviewer.md, core/agents/review-pro-synthesize-subagent.md, core/agents/security-reviewer.md, core/agents/tests-reviewer.md, core/shared/output-schema.md, core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro-triage/SKILL.md, core/skills/review-pro/SKILL.md, docs/internals/glossary.md, docs/internals/reviewer-directive.md, docs/llms.txt, scripts/validate.sh, scripts/validate.test.sh, studies/2026-09-coverage-spike/analyze.py, studies/2026-09-coverage-spike/changed.txt, studies/2026-09-coverage-spike/raw/correctness.analysis.txt]
not_examined:
  - file: docs/internals/adr/0010-report-coverage-as-self-reported.md
    reason: decision prose, not executable behavior; not reached
  - file: docs/superpowers/plans/2026-09-26-coverage-accounting.md
    reason: implementation plan prose; only grep hits seen
  - file: docs/superpowers/plans/2026-09-26-ocr-lessons-roadmap.md
    reason: roadmap prose, outside correctness concern
  - file: docs/superpowers/specs/2026-09-26-coverage-accounting-design.md
    reason: design prose; only one grep hit seen
  - file: studies/2026-09-coverage-spike/PRE-REGISTRATION.md
    reason: only grepped a few lines for Q4/D3 wording
  - file: studies/2026-09-coverage-spike/README.md
    reason: only grepped overclaim lines
  - file: studies/2026-09-coverage-spike/prompt.md
    reason: study input data; only one grep hit seen
  - file: studies/2026-09-coverage-spike/raw/correctness.md
    reason: raw study transcript output; only grep hits seen
  - file: studies/2026-09-coverage-spike/raw/craft.analysis.txt
    reason: only grepped three summary lines
  - file: studies/2026-09-coverage-spike/raw/craft.md
    reason: raw study output; only grep hits seen
  - file: studies/2026-09-coverage-spike/raw/tests.analysis.txt
    reason: only grepped three summary lines
  - file: studies/2026-09-coverage-spike/raw/tests.md
    reason: raw study output; only grep hits seen
