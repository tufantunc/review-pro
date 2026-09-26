<!-- commit read: c610017; extracted verbatim from the PR #78 dogfood review's subagent final report -->
- severity: Medium
  category: correctness.logic
  file: core/skills/review-pro/SKILL.md
  line: 35
  title: The step-3 reminder gives stale agents the block's format but not its honesty rule, so the stale-agent case goes from "not reported" to possibly overstated "examined"
  evidence: |
    - `### Files examined`, for every code reviewer (never `spec`): one line asking it to end with its `## Files examined` block, `examined: [...]` then `not_examined:` entries with `file` and `reason`, accounting for each file in `### Changed file contents` exactly once. The agent body asks for the same block; repeating it here keeps coverage working when the installed agents are older than this skill.
  impact: The reminder exists for agents older than the skill. A 1.4.0 body (`git show main:core/agents/craft-reviewer.md`) has no `## Files examined` section, so for that agent this one line is the whole contract. The line says "each file exactly once", which pushes toward a complete list. It leaves out both guards the contract depends on: "a file counts as examined only if you read its diff or contents" and "an accurate list with gaps is the correct answer; a complete-looking list that overstates what you read is the wrong one". The current bodies carry both guards, and so does the inline path at SKILL.md:48. The spike this feature rests on measured honesty only with those words present. studies/2026-09-coverage-spike/README.md:31-34 says the addendum given to unmodified bodies carried "an accurate list with gaps is the correct answer", and "honesty was measured under it"; prompt.md:143 also has the definition of examined. Synthesis counts any `examined` entry as examined (review-pro-synthesize/SKILL.md:54), and nothing downstream checks it (agent body: "nothing downstream can check it"). Before this commit a stale agent produced `not reported` plus `no Files examined block from`, which is honest. After it, a stale agent can produce a clean-looking "N of N examined" that no measurement backs, and the design itself ranks that as the worse outcome. So the round-1 problem has moved rather than gone away. Blast radius: stale installs only, and coverage never changes a finding or the verdict.
  remedy: Add the two guards to the reminder line, e.g. "a file counts as examined only if you read its diff or contents; an accurate list with gaps is correct, a complete-looking list that overstates what you read is wrong". Then pin `overstates what you read` in ORCH_MD's reminder the same way validate.sh pins it in the bodies.
  confidence: medium
  overlap_hints: [ai-antipatterns]

- severity: Low
  category: correctness.logic
  file: README.md
  line: 99
  title: The example's not-examined line still leaves out receivers that the example's own findings imply
  evidence: |
    not examined: fixtures/cart-large.json (security: fixture data; backend: fixture data; performance: generated fixture data; frontend: not UI; tests: fixture, no test logic)
    ...
    - [Medium] src/lib/retry.ts:1, reimplements the existing `withRetry` helper
  impact: The commit says "README example lists every receiver". A "reimplements the existing helper" finding belongs to dry, craft or ai-antipatterns (triage signal map: "copy-paste-shaped additions -> craft + dry + ai-antipatterns"). None of the five reviewers listed owns reuse. `backend` implies routes, which also dispatches `api-contract`, and "any non-trivial logic change -> correctness". context-policy.md:3 gives every reviewer the full changed files, so each of those reviewers received the fixture. Under the new table (synthesize SKILL.md:55), one receiver missing from the reasons makes the file `not reported`, not `not examined`. The illustrative report therefore still contradicts the rule it demonstrates.
  remedy: Add the reuse reviewer (and api-contract and correctness, if they are meant to be in the example) to the reason list, or name the reviewer on the refuted finding so the receiver set can be read off the example.
  confidence: medium
  overlap_hints: []

Answers to the four related-context questions (no other findings):
1. **Report paths.** Every path still has a complete format to follow. Inline step 5 continues the synthesize skill, whose `## Output` template plus `## Coverage` section is complete. The synthesis subagent loads the same skill. The no-subagent platform runs synthesis inline as before. plugin.ts `copySkills` copies every skill directory for opencode, claude-code and codex, so review-pro-synthesize always ships next to review-pro. Cursor installs the whole plugin via .cursor-plugin (`skills: ./core/skills/`). Steps 4 and 5 already depended on that skill, so there is no new dependency. The zero-dispatch path never had a template and is governed by the Rules line, as before. Nothing else refers to the removed template: the CLI has no references, the ADRs and adapters are clean, validate.sh dropped `check_header_order` for the orchestrator, and the test fixture now carries the pointer. The only references left are in the historical plan doc and study raw output. `validate.sh` prints OK and `validate.test.sh` passes 211 of 211. All 7 locale `docs.run.final` strings appear verbatim in their generated docs.html.
2. **Step-3 reminder.** It says "never `spec`", and the inline spec review "emits no block", so it cannot reach the spec reviewer. It agrees with the current bodies on scope, placement and format. A 1.4.0 body does conflict with it ("output exactly `## Craft findings: none` and stop"). But the spike ran unmodified bodies with a similar addendum and got blocks. The heading and keys the reminder names are the ones synthesis reads, so the output is parseable. The gap is honesty, not parseability (finding 1).
3. **State table.** For each reviewer, a file's entry is one of: examined only, not examined only, both, or none. Checked against every combination: any receiver with examined only, or with a finding, gives `examined`. A finding plus a `not_examined` listing (the both case included) also prints the contradiction line. All receivers not examined only gives `not examined`. Any receiver with both or none gives `not reported`, unless another receiver examined the file. No receiver gives `sent to no reviewer`, which is checked first, so spec findings never count. Each combination lands in exactly one state, and none shows a missing report as examined.
4. **Zero-dispatch note.** It agrees with synthesis's sent-to-no-reviewer caveat, which prints on every diff_class, trivial included, and with triage SKILL.md:72 ("a file on no code reviewer's list is reported as sent to no reviewer"). The spec-only dispatch case runs synthesis, where every file is "sent to no reviewer" and the caveat prints, so it stays consistent.

## Files examined
examined: [README.md, core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro/SKILL.md, docs-src/i18n/en.json, docs/docs.html, docs/superpowers/specs/2026-09-26-coverage-accounting-design.md, scripts/validate.sh, scripts/validate.test.sh, studies/2026-09-coverage-spike/analyze.py]
not_examined:
  - file: docs-src/i18n/de.json
    reason: translated copy; only checked by script that its string appears in the generated page, text not read
  - file: docs-src/i18n/fr.json
    reason: translated copy; only checked by script that its string appears in the generated page, text not read
  - file: docs-src/i18n/hi.json
    reason: translated copy; only checked by script that its string appears in the generated page, text not read
  - file: docs-src/i18n/nl.json
    reason: translated copy; only checked by script that its string appears in the generated page, text not read
  - file: docs-src/i18n/tr.json
    reason: translated copy; only checked by script that its string appears in the generated page, text not read
  - file: docs-src/i18n/zh.json
    reason: translated copy; only checked by script that its string appears in the generated page, text not read
  - file: docs/de/docs.html
    reason: generated page; only the script-level string match, not read
  - file: docs/fr/docs.html
    reason: generated page; only the script-level string match, not read
  - file: docs/hi/docs.html
    reason: generated page; only the script-level string match, not read
  - file: docs/nl/docs.html
    reason: generated page; only the script-level string match, not read
  - file: docs/tr/docs.html
    reason: generated page; only the script-level string match, not read
  - file: docs/zh/docs.html
    reason: generated page; only the script-level string match, not read
