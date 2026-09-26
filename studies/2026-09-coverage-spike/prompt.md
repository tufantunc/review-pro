### Changed file contents
You are reviewing PR #74 of review-pro. The repository at the PR's head is checked out at:
<spike>/wt
Base: c33da43. Head: 8649dad. Do NOT use `main` as the base in that checkout; use these two commits.
The change touches 119 files (5386 insertions, 16 deletions). It is too large to paste here, so read it yourself:
- a file's diff: `git -C <spike>/wt diff c33da43 8649dad -- <path>`
- a file's full contents at head: Read `<spike>/wt/<path>`
The changed-file list:
- README.md
- cli/tests/plugin-cross.test.ts
- cli/tests/uninstall.test.ts
- core/agents/review-pro-synthesize-subagent.md
- core/agents/review-pro-verify-subagent.md
- core/skills/review-pro-synthesize/SKILL.md
- core/skills/review-pro-verify/SKILL.md
- core/skills/review-pro/SKILL.md
- docs/internals/adr/0009-verify-findings-by-refutation.md
- docs/internals/glossary.md
- docs/superpowers/plans/2026-09-24-refuting-verifier.md
- docs/superpowers/specs/2026-09-24-refuting-verifier-design.md
- manifest.json
- scripts/validate.sh
- scripts/validate.test.sh
- studies/2026-09-refuting-verifier/PRE-REGISTRATION.md
- studies/2026-09-refuting-verifier/README.md
- studies/2026-09-refuting-verifier/RESULTS.md
- studies/2026-09-refuting-verifier/SHA256SUMS
- studies/2026-09-refuting-verifier/acceptance/PRE-REGISTRATION.md
- studies/2026-09-refuting-verifier/acceptance/RESULTS.md
- studies/2026-09-refuting-verifier/acceptance/e2e/PRE-REGISTRATION.md
- studies/2026-09-refuting-verifier/acceptance/e2e/RESULTS.md
- studies/2026-09-refuting-verifier/acceptance/e2e/aspire-report.md
- studies/2026-09-refuting-verifier/acceptance/e2e/control-report.md
- studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-ai-antipatterns.md
- studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-correctness.md
- studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-craft.md
- studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-tests.md
- studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-verify-craft-34.md
- studies/2026-09-refuting-verifier/acceptance/e2e/raw/B-security.md
- studies/2026-09-refuting-verifier/acceptance/raw/V01.md
- studies/2026-09-refuting-verifier/acceptance/raw/V02.md
- studies/2026-09-refuting-verifier/acceptance/raw/V03.md
- studies/2026-09-refuting-verifier/acceptance/raw/V04.md
- studies/2026-09-refuting-verifier/acceptance/raw/V05.md
- studies/2026-09-refuting-verifier/acceptance/raw/V06.md
- studies/2026-09-refuting-verifier/acceptance/raw/V07.md
- studies/2026-09-refuting-verifier/acceptance/raw/V08.md
- studies/2026-09-refuting-verifier/acceptance/raw/V09.md
- studies/2026-09-refuting-verifier/acceptance/raw/V10.md
- studies/2026-09-refuting-verifier/acceptance/raw/V11.md
- studies/2026-09-refuting-verifier/acceptance/raw/V12.md
- studies/2026-09-refuting-verifier/acceptance/raw/V13.md
- studies/2026-09-refuting-verifier/acceptance/render/EXPECTED.md
- studies/2026-09-refuting-verifier/acceptance/render/INPUT.md
- studies/2026-09-refuting-verifier/acceptance/render/OUTPUT-inline.md
- studies/2026-09-refuting-verifier/acceptance/render/OUTPUT-no-results.md
- studies/2026-09-refuting-verifier/acceptance/run2/PRE-REGISTRATION.md
- studies/2026-09-refuting-verifier/acceptance/run2/RESULTS.md
- studies/2026-09-refuting-verifier/acceptance/run2/items/W01.md
- studies/2026-09-refuting-verifier/acceptance/run2/items/W02.md
- studies/2026-09-refuting-verifier/acceptance/run2/items/W03.md
- studies/2026-09-refuting-verifier/acceptance/run2/items/W04.md
- studies/2026-09-refuting-verifier/acceptance/run2/items/W05.md
- studies/2026-09-refuting-verifier/acceptance/run2/items/W06.md
- studies/2026-09-refuting-verifier/acceptance/run2/items/W07.md
- studies/2026-09-refuting-verifier/acceptance/run2/items/W08.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V01.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V02.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V03.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V04.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V05.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V06.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V07.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V08.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V09.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V10.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V11.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V12.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/V13.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/W01.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/W02.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/W03.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/W04.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/W05.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/W06.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/W07.md
- studies/2026-09-refuting-verifier/acceptance/run2/raw/W08.md
- studies/2026-09-refuting-verifier/items/V01.md
- studies/2026-09-refuting-verifier/items/V02.md
- studies/2026-09-refuting-verifier/items/V03.md
- studies/2026-09-refuting-verifier/items/V04.md
- studies/2026-09-refuting-verifier/items/V05.md
- studies/2026-09-refuting-verifier/items/V06.md
- studies/2026-09-refuting-verifier/items/V07.md
- studies/2026-09-refuting-verifier/items/V08.md
- studies/2026-09-refuting-verifier/items/V09.md
- studies/2026-09-refuting-verifier/items/V10.md
- studies/2026-09-refuting-verifier/items/V11.md
- studies/2026-09-refuting-verifier/items/V12.md
- studies/2026-09-refuting-verifier/items/V13.md
- studies/2026-09-refuting-verifier/prompt.tmpl
- studies/2026-09-refuting-verifier/raw/V01-A.md
- studies/2026-09-refuting-verifier/raw/V01-B.md
- studies/2026-09-refuting-verifier/raw/V02-A.md
- studies/2026-09-refuting-verifier/raw/V02-B.md
- studies/2026-09-refuting-verifier/raw/V03-A.md
- studies/2026-09-refuting-verifier/raw/V03-B.md
- studies/2026-09-refuting-verifier/raw/V04-A.md
- studies/2026-09-refuting-verifier/raw/V04-B.md
- studies/2026-09-refuting-verifier/raw/V05-A.md
- studies/2026-09-refuting-verifier/raw/V05-B.md
- studies/2026-09-refuting-verifier/raw/V06-A.md
- studies/2026-09-refuting-verifier/raw/V06-B.md
- studies/2026-09-refuting-verifier/raw/V07-A.md
- studies/2026-09-refuting-verifier/raw/V07-B.md
- studies/2026-09-refuting-verifier/raw/V08-A.md
- studies/2026-09-refuting-verifier/raw/V08-B.md
- studies/2026-09-refuting-verifier/raw/V09-A.md
- studies/2026-09-refuting-verifier/raw/V09-B.md
- studies/2026-09-refuting-verifier/raw/V10-A.md
- studies/2026-09-refuting-verifier/raw/V10-B.md
- studies/2026-09-refuting-verifier/raw/V11-A.md
- studies/2026-09-refuting-verifier/raw/V11-B.md
- studies/2026-09-refuting-verifier/raw/V12-A.md
- studies/2026-09-refuting-verifier/raw/V12-B.md
- studies/2026-09-refuting-verifier/raw/V13-A.md
- studies/2026-09-refuting-verifier/raw/V13-B.md

### Related context
The PR adds a verification stage (Stage 3b) to review-pro's pipeline: skills, an agent, validator checks and tests, docs, and the study data that measured it.

### Files examined (temporary addendum, measurement only)
Review exactly as you normally would; this addendum does not change your task. After your findings (or your none-line), append one more block:

```
## Files examined
examined: [<path>, ...]
not_examined:
  - file: <path>
    reason: <why, one line>
```

Account for every file in the changed-file list above, each exactly once, in one of the two lists. A file counts as examined only if you actually read its diff or contents; a file you know only from the list is not_examined. An accurate list with gaps is the correct answer; a complete-looking list that overstates what you read is the wrong one.
