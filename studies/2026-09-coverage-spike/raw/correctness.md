- severity: Low
  category: correctness.logic
  file: core/skills/review-pro-verify/SKILL.md
  line: 16
  title: Deleted files are re-read from the base branch tip, not from the merge-base the diff was taken against
  evidence: |
    You work in the repository's working tree, which is the branch under review. A file the diff deletes is read from the base with `git show <base>:<path>`.
  evidence_refs: [core/skills/review-pro/SKILL.md:46, core/skills/review-pro/SKILL.md:14]
  impact: |
    The orchestrator (review-pro/SKILL.md:46) builds `### Diff` as `base: <ref>` followed by `git diff <base>...HEAD`, and step 1 sets `<base>` to the branch name `main` (or `master`). The three-dot diff compares against merge-base(main, HEAD), but `git show main:<path>` reads the tip of main. This only breaks when the branch is behind main. If main edited the deleted file after the branch point, the verifier reads, and may cite as a "contradiction", content the diff never removed. If main has itself deleted or renamed the file, `git show` fails and the finding cannot be re-read. Because the verifier cites that file as its evidence, a wrong refutation can take a real Medium out of the verdict. The trigger is narrow: the finding must sit in a deleted file, and main must have changed that file since the branch point.
  remedy: Have the orchestrator resolve the ref once and pass it on, e.g. `base: $(git merge-base <base> HEAD)`, so that `git show <base>:<path>` reads the same tree the diff was computed from. Or have the verifier skill say to run `git show $(git merge-base <base> HEAD):<path>`. The validator's `base: <ref>` literal check still passes with either change.
  confidence: medium
  overlap_hints: []

- severity: Low
  category: correctness.side-effect
  file: core/agents/review-pro-synthesize-subagent.md
  line: 13
  title: The synthesize subagent now accepts verification results but still re-runs dedup, so the "do not merge again" invariant does not hold on this path
  evidence: |
    1. Receive the structured findings from all dispatched reviewers, ... and the verification results when the orchestrator ran the verifiers. ...
    2. Dedup, weight overlapping findings, resolve conflicts by domain ownership, calibrate severity.
  evidence_refs: [core/skills/review-pro/SKILL.md:53, core/skills/review-pro-synthesize/SKILL.md:80, scripts/validate.sh:199]
  impact: |
    Verification results bind by the merged finding's `file`, `line` and `title` (synthesize/SKILL.md:80). The orchestrator path deliberately skips a second merge ("Do not merge again: the results are bound to the merged findings as they stand"), and validate.sh:199 guards that, but only in review-pro/SKILL.md. The subagent's input is the raw reviewer findings, and its step 2 tells it to dedup them again. A second LLM dedup can pick a different representative line or title, so some or all verifier blocks stop binding and fall to `not verified (error)`. This fails in the cautious direction, so no false blocker ships, but the verification work is silently wasted. No in-repo caller dispatches this subagent today (the orchestrator synthesizes inline), so this is latent.
  remedy: When verification results are present, step 2 should take the already-merged findings the verifiers saw and continue from **Verification results** without re-running Collect through Resolve conflicts, mirroring review-pro/SKILL.md step 5. Alternatively, drop the verification-results input from the subagent and keep only the "no results means not verified (no independent verifier)" sentence.
  confidence: medium
  overlap_hints: [craft]

## Files examined
examined: [README.md, cli/tests/plugin-cross.test.ts, cli/tests/uninstall.test.ts, core/agents/review-pro-synthesize-subagent.md, core/agents/review-pro-verify-subagent.md, core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro-verify/SKILL.md, core/skills/review-pro/SKILL.md, docs/internals/adr/0009-verify-findings-by-refutation.md, docs/internals/glossary.md, manifest.json, scripts/validate.sh, scripts/validate.test.sh, studies/2026-09-refuting-verifier/SHA256SUMS]
not_examined:
  - file: docs/superpowers/plans/2026-09-24-refuting-verifier.md
    reason: 1173-line implementation plan (prose); only a grep for base-ref wording, not read
  - file: docs/superpowers/specs/2026-09-24-refuting-verifier-design.md
    reason: design prose; only a grep for base/merge-base wording hit one line, not read
  - file: studies/2026-09-refuting-verifier/PRE-REGISTRATION.md
    reason: study data, not executable pipeline code
  - file: studies/2026-09-refuting-verifier/README.md
    reason: only grepped for checksum lines, not read
  - file: studies/2026-09-refuting-verifier/RESULTS.md
    reason: study data, not executable pipeline code
  - file: studies/2026-09-refuting-verifier/acceptance/PRE-REGISTRATION.md
    reason: study data
  - file: studies/2026-09-refuting-verifier/acceptance/RESULTS.md
    reason: study data
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/PRE-REGISTRATION.md
    reason: study data
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/RESULTS.md
    reason: study data
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/aspire-report.md
    reason: study data
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/control-report.md
    reason: study data
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-ai-antipatterns.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-correctness.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-craft.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-tests.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-verify-craft-34.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/B-security.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V01.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V02.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V03.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V04.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V05.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V06.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V07.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V08.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V09.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V10.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V11.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V12.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V13.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/render/EXPECTED.md
    reason: study render fixture
  - file: studies/2026-09-refuting-verifier/acceptance/render/INPUT.md
    reason: study render fixture
  - file: studies/2026-09-refuting-verifier/acceptance/render/OUTPUT-inline.md
    reason: study render fixture
  - file: studies/2026-09-refuting-verifier/acceptance/render/OUTPUT-no-results.md
    reason: study render fixture
  - file: studies/2026-09-refuting-verifier/acceptance/run2/PRE-REGISTRATION.md
    reason: study data
  - file: studies/2026-09-refuting-verifier/acceptance/run2/RESULTS.md
    reason: study data
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W01.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W02.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W03.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W04.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W05.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W06.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W07.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W08.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V01.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V02.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V03.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V04.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V05.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V06.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V07.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V08.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V09.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V10.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V11.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V12.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V13.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W01.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W02.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W03.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W04.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W05.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W06.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W07.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W08.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/items/V01.md
    reason: study item; only its sha256 was computed, contents not read
  - file: studies/2026-09-refuting-verifier/items/V02.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/items/V03.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/items/V04.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/items/V05.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/items/V06.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/items/V07.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/items/V08.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/items/V09.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/items/V10.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/items/V11.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/items/V12.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/items/V13.md
    reason: study item
  - file: studies/2026-09-refuting-verifier/prompt.tmpl
    reason: study prompt template; only its sha256 was computed, contents not read
  - file: studies/2026-09-refuting-verifier/raw/V01-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V01-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V02-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V02-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V03-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V03-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V04-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V04-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V05-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V05-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V06-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V06-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V07-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V07-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V08-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V08-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V09-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V09-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V10-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V10-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V11-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V11-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V12-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V12-B.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V13-A.md
    reason: raw study output
  - file: studies/2026-09-refuting-verifier/raw/V13-B.md
    reason: raw study output