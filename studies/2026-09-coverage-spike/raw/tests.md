## Tests findings

I ran the meta-test suite at head 8649dad: `bash scripts/validate.test.sh` gives pass=166 fail=0, and `bash scripts/validate.sh .` gives "OK: all artifacts valid". Every new `add_error` in validate.sh has a mutation test that fires alone, and each new case (AN, AO, AP) has a silent control. The CLI fixtures are rebuilt per test in beforeEach, so nothing leaks between tests. The findings below are gaps where the validator stays silent after a mutation it is supposed to catch. I confirmed each one by mutating a copy of the head tree.

- severity: Low
  category: tests.coverage
  file: scripts/validate.sh
  line: 199
  title: The re-merge guard fails open when the handoff line is reworded or deleted, and no test covers that case
  evidence: |
    grep -F 'Continue the `review-pro-synthesize` skill from' "$ORCH_MD" | grep -qi 'dedup' \
      && add_error "review-pro/SKILL.md: the synthesis step re-runs the merge after verification - ..."
    # validate.test.sh:1216, the only mutation of it:
    stage_mutation "$ORC" w_orch "re-runs the merge after verification" "orchestrator re-merge" sed 's/calibrate and emit the verdict/dedup, calibrate and emit the verdict/'
  impact: The guard only looks at a line starting with "Continue the `review-pro-synthesize` skill from". I rewrote that line in a copy of the head tree as "Resume synthesis from the top: dedup again, apply the results, ...", which is exactly the re-merge the guard is meant to stop. validate.sh still printed "OK: all artifacts valid". Deleting the line entirely also passes. The only test mutates text inside the anchored line, so it never checks the guard against the edit most likely to cause the regression.
  remedy: Add a presence check that the handoff line (or the "Do not merge again" sentence) exists. Then add stage_mutation cases in Case AP that (a) delete the Continue line and (b) reword it without the anchor. Each should expect one FAIL.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.coverage
  file: scripts/validate.sh
  line: 201
  title: The second alternative of the numbered-synthesize-step regex is never tested
  evidence: |
    grep -qE 'skill from step [0-9]|steps? [0-9]+( to [0-9]+)? of the `review-pro-synthesize`' "$ORCH_MD" \
    # validate.test.sh:1217, the only mutation:
    ... sed 's/skill from \*\*Verification results\*\*/skill from step 5/'
  impact: Only the `skill from step N` branch is tested. The `steps 1 to 4 of the `review-pro-synthesize`` branch is how the old orchestrator text phrased it, so it is the most likely way the problem comes back. A typo in that branch (for example the backtick quoting, or the `( to [0-9]+)?` group) would go unnoticed.
  remedy: In Case AP, add `stage_mutation "$ORC" w_orch "a numbered reference to a review-pro-synthesize step" "orchestrator numbered synthesize range" sed 's/first line `base: <ref>`/first line `base: <ref>`; run steps 1 to 4 of the `review-pro-synthesize` skill/'` or a similar line that only the second alternative matches.
  confidence: high
  overlap_hints: []

- severity: Low
  category: tests.coverage
  file: scripts/validate.sh
  line: 226
  title: The `refuted | yes` row of the resolution table is not guarded or tested, though the other two cautious rows are
  evidence: |
    # guarded + tested (validate.test.sh:1189-1190):
    grep -qF '| `partly_refuted` | `no` | refuted |' "$SYNTH_MD" || add_error ...
    grep -qF '| `stands` | `no` | not verified (error) |' "$SYNTH_MD" || add_error ...
    # unguarded, core/skills/review-pro-synthesize/SKILL.md:90:
    | `refuted` | `yes` | not verified (error) |
  impact: The section's own rule is that "every inconsistency resolves in the cautious direction". `refuted` with `defect_stands: yes` is the third inconsistent row. If it is lost, a self-contradicting reply can be read as a plain refutation, and a true Medium then leaves the verdict. That is the fail-toward-removing-true-findings outcome the comment above these checks names. I blanked that row in a copy of the head tree and validate.sh still printed "OK: all artifacts valid".
  remedy: Add `grep -qF '| `refuted` | `yes` | not verified (error) |' "$SYNTH_MD" || add_error ...`. Add the row to the review-pro-synthesize fixture in write_orchestrator, plus a matching `stage_mutation "$SYN" w_synth ... grep -vF '| `refuted` | `yes` | not verified (error) |'` in Case AO.
  confidence: medium
  overlap_hints: [correctness.logic]

## Files examined
examined: [README.md, cli/tests/plugin-cross.test.ts, cli/tests/uninstall.test.ts, core/agents/review-pro-synthesize-subagent.md, core/agents/review-pro-verify-subagent.md, core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro-verify/SKILL.md, core/skills/review-pro/SKILL.md, docs/internals/glossary.md, manifest.json, scripts/validate.sh, scripts/validate.test.sh]
not_examined:
  - file: docs/internals/adr/0009-verify-findings-by-refutation.md
    reason: design doc; only grepped for test references, not read
  - file: docs/superpowers/plans/2026-09-24-refuting-verifier.md
    reason: design doc; only grepped for test references, not read
  - file: docs/superpowers/specs/2026-09-24-refuting-verifier-design.md
    reason: design doc; only grepped for test references, not read
  - file: studies/2026-09-refuting-verifier/PRE-REGISTRATION.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/README.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/RESULTS.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/SHA256SUMS
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/PRE-REGISTRATION.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/RESULTS.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/PRE-REGISTRATION.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/RESULTS.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/aspire-report.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/control-report.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-ai-antipatterns.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-correctness.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-craft.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-tests.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-verify-craft-34.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/B-security.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V01.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V02.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V03.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V04.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V05.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V06.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V07.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V08.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V09.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V10.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V11.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V12.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V13.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/render/EXPECTED.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/render/INPUT.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/render/OUTPUT-inline.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/render/OUTPUT-no-results.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/PRE-REGISTRATION.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/RESULTS.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W01.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W02.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W03.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W04.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W05.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W06.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W07.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W08.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V01.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V02.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V03.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V04.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V05.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V06.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V07.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V08.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V09.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V10.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V11.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V12.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V13.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W01.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W02.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W03.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W04.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W05.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W06.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W07.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W08.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V01.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V02.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V03.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V04.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V05.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V06.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V07.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V08.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V09.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V10.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V11.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V12.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/items/V13.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/prompt.tmpl
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V01-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V01-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V02-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V02-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V03-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V03-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V04-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V04-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V05-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V05-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V06-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V06-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V07-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V07-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V08-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V08-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V09-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V09-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V10-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V10-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V11-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V11-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V12-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V12-B.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V13-A.md
    reason: study data/transcripts, no test or production code; not opened
  - file: studies/2026-09-refuting-verifier/raw/V13-B.md
    reason: study data/transcripts, no test or production code; not opened