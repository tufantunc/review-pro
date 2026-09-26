<!-- commit read: 14c52d4; extracted verbatim from the PR #78 dogfood review's subagent final report -->
- severity: Low
  category: craft.code-judo
  file: scripts/validate.sh
  line: 36
  title: three hand-rolled awk section extractors, one with a hard-coded list of template headings to skip
  evidence: |
    36:  out="$(awk '/^## Output$/{s=1;next} s&&/^## [A-Z]/&&!/^## Verdict/&&!/^## Spec \(/{exit} s' "$f")"
    152:  awk '/^## Final reminder/{s=1;next} s&&/^## /{exit} s' "$body" | grep -qF '## Files examined' \
    265:  COV="$(awk '/^## Coverage$/{s=1;next} s&&/^## /{exit} s' "$SYNTH_MD")"
  impact: This PR adds the only three section-scoping extractors in validate.sh, and they already stop at different places. The Output one carries a hand-kept list of headings that live inside the fenced report template (`## Verdict`, `## Spec (`, see core/skills/review-pro/SKILL.md:69,94 and core/skills/review-pro-synthesize/SKILL.md:186,219). If someone adds another `## ` heading to either template above the Coverage line, the scope gets cut short and check_header_order reports a missing coverage line even though the line is there. The next section-scoped pin will copy one of these three variants rather than a named helper.
  remedy: Replace all three with one fence-aware helper defined next to add_error, e.g. `section(){ awk -v h="$2" '$0==h{s=1;next} s&&/^```/{f=!f} s&&!f&&/^## /{exit} s' "$1"; }`, and call `section "$f" '## Output'`, `section "$body" '## Final reminder'` and `section "$SYNTH_MD" '## Coverage'`. This deletes the `!/^## Verdict/&&!/^## Spec \(/` special case and the `[A-Z]` quirk, because headings inside the template fence can no longer end the section.
  confidence: medium
  evidence_refs: [scripts/validate.sh:152, scripts/validate.sh:265, core/skills/review-pro/SKILL.md:94, core/skills/review-pro-synthesize/SKILL.md:219]
  overlap_hints: [dry.duplication]

- severity: Nitpick
  category: craft.abstraction
  file: scripts/validate.test.sh
  line: 1321
  title: w_tri is a pass-through wrapper around a writer the line above already passes directly
  evidence: |
    1320: stage_fixture review-pro-triage orchestrator write_stage_skill; TRI="$STAGE"
    1321: w_tri(){ write_stage_skill "$1"; }
    1322: stage_mutation "$TRI" w_tri "the coverage comparison is gone" ...
  impact: It adds one more global writer name to a 1328-line test file for no reason. write_stage_skill already defaults to review-pro-triage (validate.test.sh:166-169), and stage_mutation calls "$writer" "$file", so the wrapper adds nothing.
  remedy: Delete w_tri and pass `write_stage_skill` to stage_mutation, the same way line 1320 passes it to stage_fixture.
  confidence: high
  overlap_hints: []

Notes (not findings): The Files examined sections are byte-identical across all 12 code-reviewer bodies (md5 of each section), and spec-reviewer.md is correctly exempt. Per ADR-0001 that duplication is policy. validate.sh grows from 747 to 817 lines, well under 1k. validate.test.sh was already over 1k before this branch (1237 to 1328), so the PR does not push it across. The new `## Coverage` section follows the structure of Out-of-diff evidence check (a lead paragraph, a table, then `Rules:`). `bash scripts/validate.sh` exits 0 on the branch. I did not wait for the validate.test.sh run to finish, so I have no result for it.

## Files examined
examined: [README.md, cli/README.md, core/agents/craft-reviewer.md, core/agents/security-reviewer.md, core/agents/review-pro-synthesize-subagent.md, core/shared/output-schema.md, core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro-triage/SKILL.md, core/skills/review-pro/SKILL.md, docs/internals/adr/0010-report-coverage-as-self-reported.md, docs/internals/glossary.md, docs/internals/reviewer-directive.md, docs/llms.txt, scripts/validate.sh, scripts/validate.test.sh, studies/2026-09-coverage-spike/analyze.py, studies/2026-09-coverage-spike/raw/craft.analysis.txt]
not_examined:
  - file: core/agents/a11y-reviewer.md
    reason: compared mechanically only, Files examined section md5-identical to craft-reviewer.md; diff not read line by line
  - file: core/agents/ai-antipatterns-reviewer.md
    reason: compared mechanically only, Files examined section md5-identical to craft-reviewer.md; diff not read line by line
  - file: core/agents/api-contract-reviewer.md
    reason: compared mechanically only, Files examined section md5-identical to craft-reviewer.md; diff not read line by line
  - file: core/agents/backend-reviewer.md
    reason: compared mechanically only, Files examined section md5-identical to craft-reviewer.md; diff not read line by line
  - file: core/agents/correctness-reviewer.md
    reason: compared mechanically only, Files examined section md5-identical to craft-reviewer.md; diff not read line by line
  - file: core/agents/db-reviewer.md
    reason: compared mechanically only, Files examined section md5-identical to craft-reviewer.md; diff not read line by line
  - file: core/agents/dry-reviewer.md
    reason: compared mechanically only, Files examined section md5-identical to craft-reviewer.md; diff not read line by line
  - file: core/agents/frontend-reviewer.md
    reason: compared mechanically only, Files examined section md5-identical to craft-reviewer.md; diff not read line by line
  - file: core/agents/performance-reviewer.md
    reason: compared mechanically only, Files examined section md5-identical to craft-reviewer.md; diff not read line by line
  - file: core/agents/tests-reviewer.md
    reason: compared mechanically only, Files examined section md5-identical to craft-reviewer.md; diff not read line by line
  - file: docs/superpowers/plans/2026-09-26-coverage-accounting.md
    reason: implementation plan prose, outside code structure
  - file: docs/superpowers/plans/2026-09-26-ocr-lessons-roadmap.md
    reason: roadmap prose, outside code structure
  - file: docs/superpowers/specs/2026-09-26-coverage-accounting-design.md
    reason: design prose, outside code structure
  - file: studies/2026-09-coverage-spike/PRE-REGISTRATION.md
    reason: study prose
  - file: studies/2026-09-coverage-spike/README.md
    reason: study prose
  - file: studies/2026-09-coverage-spike/changed.txt
    reason: study data (file list)
  - file: studies/2026-09-coverage-spike/prompt.md
    reason: study prompt fixture
  - file: studies/2026-09-coverage-spike/raw/correctness.analysis.txt
    reason: study output data
  - file: studies/2026-09-coverage-spike/raw/correctness.md
    reason: study transcript data
  - file: studies/2026-09-coverage-spike/raw/craft.md
    reason: study transcript data
  - file: studies/2026-09-coverage-spike/raw/tests.analysis.txt
    reason: study output data
  - file: studies/2026-09-coverage-spike/raw/tests.md
    reason: study transcript data
