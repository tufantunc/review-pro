<!-- commit read: 14c52d4; extracted verbatim from the PR #78 dogfood review's subagent final report -->
- severity: Medium
  category: tests.assertion
  file: scripts/validate.sh
  line: 268
  title: the seven ## Coverage pins pass silently when the section heading stays but its body is deleted
  evidence: |
    COV="$(awk '/^## Coverage$/{s=1;next} s&&/^## /{exit} s' "$SYNTH_MD")"
    # An absent section is reported once by the required-section check; pinning its phrases
    # too would turn one deletion into eight errors.
    cov_pin(){ [[ -n "$COV" ]] || return 0; printf '%s\n' "$COV" | grep -qF "$1" || add_error ...; }
  evidence_refs: [scripts/validate.test.sh:1285]
  impact: The guard treats "section empty" the same as "section absent". The required-section check only looks for the heading, so if `## Coverage` is kept with nothing under it, COV is empty, every cov_pin returns 0, and no error is raised. I checked this on a git-archive copy of HEAD: I deleted all body lines under `## Coverage` in review-pro-synthesize/SKILL.md, left the heading, and `validate.sh <copy>` printed "OK: all artifacts valid" with exit 0. Case AS only tests renaming the heading (line 1285), which is the one path the guard was written for, so the empty-body gap has no test.
  remedy: Gate on whether the heading exists, not on whether COV has content (`grep -qxF '## Coverage' "$SYNTH_MD" || return 0`). The single-error-on-deletion goal still holds. Add a Case AS mutation that empties the body with `awk '/^## Coverage$/{print;s=1;next} s&&/^## /{s=0} !s'`, and expect the seven pin errors, or one dedicated "section is empty" error if that is added.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.test-data
  file: scripts/validate.sh
  line: 273
  title: the sent-to-no-reviewer caveat pin is satisfied by the state table and the coverage template, so the caveat itself can be deleted
  evidence: |
    cov_pin 'sent to no reviewer'                 "the sent-to-no-reviewer caveat is gone from ## Coverage - a narrowed dispatch is never reported"
    # fixture, validate.test.sh:208, the only occurrence in the fixture section:
    Caveat: changed files were sent to no reviewer.
    # real ## Coverage section also contains, outside the caveat:
    | sent to no reviewer | it has no receiver |
    Coverage (self-reported): ... [, <s> sent to no reviewer].
  evidence_refs: [scripts/validate.test.sh:208, scripts/validate.test.sh:1290, core/skills/review-pro-synthesize/SKILL.md:53, core/skills/review-pro-synthesize/SKILL.md:64]
  impact: In the fixture the phrase appears once, so the Case AS mutation "synthesis coverage deterministic" passes. In the real section it appears three times, and only one of them is the caveat. On a HEAD copy I deleted the whole caveat (the "- Files sent to no reviewer also get this caveat" bullet and its fenced `> <s> changed files were sent to no reviewer, so nothing reviewed them` block). `grep -c 'nothing reviewed them'` returned 0 and validate.sh still printed OK. This is the one coverage signal that does not depend on a reviewer's own report, and its error message claims it is protected, but the fixture is unrealistic enough to hide that it is not.
  remedy: Pin a phrase found only in the caveat, for example `nothing reviewed them` or `on every \`diff_class\``. Make the fixture's `## Coverage` include the table row `| sent to no reviewer | it has no receiver |` and the template line, so Case AS runs against the same collisions as the real file.
  confidence: high
  overlap_hints: []

- severity: Medium
  category: tests.coverage
  file: scripts/validate.sh
  line: 35
  title: check_header_order silently skips the orchestrator when its `## Output` heading is renamed, and no test covers that path
  evidence: |
    # No Output section at all is its own failure (a required section for synthesis);
    # the order question only exists once there is a template to order.
    grep -qxF '## Output' "$f" || return 0
  evidence_refs: [scripts/validate.sh:89, scripts/validate.sh:237]
  impact: The comment's safety argument covers synthesis only. The `case "$name"` required-section list (validate.sh:89 area) has no entry for `review-pro`, so nothing requires the orchestrator to keep `## Output`. On a HEAD copy I renamed `## Output` to `## Report` in core/skills/review-pro/SKILL.md and deleted its `Coverage (self-reported):` line, and validate.sh printed OK. Both the coverage-line check and the order check go quiet. Case AU's mutations all keep `## Output`, so this early return is never exercised.
  remedy: For the orchestrator call, report a missing `## Output` as an error instead of returning 0, for example with a third argument that makes the section mandatory. Add a Case AU mutation `sed 's/^## Output$/## Report/'` that expects one error.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.assertion
  file: scripts/validate.test.sh
  line: 1316
  title: the orchestrator inline-block mutation removes both conjuncts at once, so the `## Files examined` half of the check is never tested
  evidence: |
    stage_mutation "$ORC" w_orch "inline reviews no longer end with the Files examined block" "orchestrator inline block" grep -vF 'exactly once'
    # fixture line 277 carries both phrases on one line:
    Every inline code review ends with the `## Files examined` block, each file exactly once.
    # validate.sh:234
    { grep -qF '## Files examined' "$ORCH_MD" && grep -qF 'exactly once' "$ORCH_MD"; } \
  evidence_refs: [scripts/validate.test.sh:277, scripts/validate.sh:234]
  impact: I copied validate.sh and validate.test.sh to a temp dir and cut line 234 down to `grep -qF 'exactly once' "$ORCH_MD"`. The suite still reported pass=203 fail=0. Case AR and Case AT each isolate both conjuncts of their checks, but Case AU does not. The unanchored `-F` match makes this worse in the real file: step 3 prose at lines 35 and 37 already contains "`## Files examined` block". On a HEAD copy I renamed the template heading at line 40, and validate.sh still passed.
  remedy: Add a second mutation that removes only the heading phrase, for example `sed 's/`## Files examined` block/block/'`, and expects the same message alone. Consider pinning the template heading with `grep -qxF '## Files examined'`, as the schema check does, so the step-3 prose cannot satisfy it.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.coverage
  file: scripts/validate.sh
  line: 41
  title: the header-order check passes vacuously when the Spec or Verification anchor line is missing or reworded
  evidence: |
    s=$(printf '%s\n' "$out" | grep -nF 'Spec: measured against' | head -1 | cut -d: -f1)
    v=$(printf '%s\n' "$out" | grep -nF 'Verification: <N> checked' | head -1 | cut -d: -f1)
    if [[ -n "$s" && -n "$v" ]] && ! [[ "$s" -lt "$c" && "$c" -lt "$v" ]]; then
  impact: Nothing else in validate.sh pins either anchor string; lines 39-40 are their only occurrences. On a HEAD copy I removed the Spec header line from the synthesis Output template and moved the Coverage line below Verification. validate.sh printed OK. Any edit to the Spec or Verification header wording turns the order check off, and no test documents or guards that.
  remedy: When `c` is found but `s` or `v` is not, raise an error that names the missing anchor, rather than skipping the comparison. Add a Case AS mutation that deletes the Spec line (`grep -vF 'Spec: measured against'`) and expects that error.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.test-data
  file: scripts/validate.test.sh
  line: 232
  title: fixture Output templates omit the `## Verdict:` and `## Spec (` lines, so the awk section-end exemptions are exercised only by the real-tree run
  evidence: |
    ## Output
    Spec: measured against <ref>
    Coverage (self-reported): <e> of <n> changed files examined by at least one reviewer.
    Verification: <N> checked
    # validate.sh:36
    out="$(awk '/^## Output$/{s=1;next} s&&/^## [A-Z]/&&!/^## Verdict/&&!/^## Spec \(/{exit} s' "$f")"
  evidence_refs: [scripts/validate.test.sh:278, scripts/validate.sh:36, core/skills/review-pro-synthesize/SKILL.md:186]
  impact: In a validate.sh copy I stripped `&&!/^## Verdict/&&!/^## Spec \(/`. The suite stayed at 203/203, while the real-tree run failed both files with "no coverage line". CI runs both (`.github/workflows/ci.yml:36-37`), so the regression would be caught today. But the unit suite does not describe the real template's shape, where a `## Verdict: ...` line comes before the header lines.
  remedy: Start both fixture Output templates with a `## Verdict: <BLOCK | ...> | APPROVE` line and end them with a `## Spec (measured against <ref>)` line, as the real templates do.
  confidence: high
  overlap_hints: []

## Files examined
examined: [scripts/validate.sh, scripts/validate.test.sh, core/agents/tests-reviewer.md, core/agents/security-reviewer.md, core/agents/review-pro-synthesize-subagent.md, core/shared/output-schema.md, core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro-triage/SKILL.md, core/skills/review-pro/SKILL.md]
not_examined:
  - file: README.md
    reason: published prose, outside test quality
  - file: cli/README.md
    reason: published prose, outside test quality
  - file: core/agents/a11y-reviewer.md
    reason: diff not read; its checks were exercised through validate.sh on the real tree
  - file: core/agents/ai-antipatterns-reviewer.md
    reason: diff not read; its checks were exercised through validate.sh on the real tree
  - file: core/agents/api-contract-reviewer.md
    reason: diff not read; its checks were exercised through validate.sh on the real tree
  - file: core/agents/backend-reviewer.md
    reason: diff not read; its checks were exercised through validate.sh on the real tree
  - file: core/agents/correctness-reviewer.md
    reason: diff not read; its checks were exercised through validate.sh on the real tree
  - file: core/agents/craft-reviewer.md
    reason: diff not read; its checks were exercised through validate.sh on the real tree
  - file: core/agents/db-reviewer.md
    reason: diff not read; its checks were exercised through validate.sh on the real tree
  - file: core/agents/dry-reviewer.md
    reason: diff not read; its checks were exercised through validate.sh on the real tree
  - file: core/agents/frontend-reviewer.md
    reason: diff not read; its checks were exercised through validate.sh on the real tree
  - file: core/agents/performance-reviewer.md
    reason: diff not read; its checks were exercised through validate.sh on the real tree
  - file: docs/internals/adr/0010-report-coverage-as-self-reported.md
    reason: design prose, outside test quality
  - file: docs/internals/glossary.md
    reason: design prose, outside test quality
  - file: docs/internals/reviewer-directive.md
    reason: design prose, outside test quality
  - file: docs/llms.txt
    reason: published prose, outside test quality
  - file: docs/superpowers/plans/2026-09-26-coverage-accounting.md
    reason: plan prose, outside test quality
  - file: docs/superpowers/plans/2026-09-26-ocr-lessons-roadmap.md
    reason: plan prose, outside test quality
  - file: docs/superpowers/specs/2026-09-26-coverage-accounting-design.md
    reason: spec prose, outside test quality
  - file: studies/2026-09-coverage-spike/PRE-REGISTRATION.md
    reason: study record, outside test quality
  - file: studies/2026-09-coverage-spike/README.md
    reason: study record, outside test quality
  - file: studies/2026-09-coverage-spike/analyze.py
    reason: one-off study script with no tests expected; not reached
  - file: studies/2026-09-coverage-spike/changed.txt
    reason: study data
  - file: studies/2026-09-coverage-spike/prompt.md
    reason: study data
  - file: studies/2026-09-coverage-spike/raw/correctness.analysis.txt
    reason: study data
  - file: studies/2026-09-coverage-spike/raw/correctness.md
    reason: study data
  - file: studies/2026-09-coverage-spike/raw/craft.analysis.txt
    reason: study data
  - file: studies/2026-09-coverage-spike/raw/craft.md
    reason: study data
  - file: studies/2026-09-coverage-spike/raw/tests.analysis.txt
    reason: study data
  - file: studies/2026-09-coverage-spike/raw/tests.md
    reason: study data
