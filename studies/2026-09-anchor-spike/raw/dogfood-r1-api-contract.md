<!-- commit read: 14c52d4; extracted verbatim from the PR #78 dogfood review's subagent final report -->
- severity: Low
  category: api-contract.breaking
  file: core/skills/review-pro-synthesize/SKILL.md
  line: 59
  title: A version-skewed install with 1.4.0 reviewer agents reports every reviewer as a contract violator and gives no hint that the cause is a stale install
  evidence: |
    - A reviewer that returned no block, a block that leaves a file out, and a file listed in both of one reviewer's lists all leave that reviewer with no entry for the file. **A missing report is never rendered as examined.** Whenever any receiver returned no block, print `no Files examined block from: <reviewers>`, even when other reviewers examined every file it received.
  impact: |
    Only the agent bodies ask for the `## Files examined` block (core/agents/*-reviewer.md, `## Files examined`). The reviewer prompt the orchestrator builds does not ask for it (core/skills/review-pro/SKILL.md:26-33). So the block's only producer is the agent body. Take a user whose skills are newer than their agents: for example, `claude plugin update review-pro` refreshed the plugin, but an older `npx review-pro init --target claude-code` copy is still in ~/.claude/agents. The README "Updating" section documents both paths, and `doctor` checks stack packs only (cli/src/commands/doctor.ts), so it will not catch this.
    Every code reviewer in that setup comes back without a block. The report then reads roughly "Coverage (self-reported): k of N changed files examined ..., N-k not reported" (k is the number of files that got a finding). It adds a `not reported:` line per file and `no Files examined block from: <every reviewer>`. That wording reads as reviewers skipping work, not as a stale install, and nothing tells the user to refresh their agents.
    The degradation is safe in every way that matters. No file shows as examined when it was not. Findings, severities and the verdict are unchanged, as the design intends (specs/2026-09-26-coverage-accounting-design.md:117-118). The only cost is a misleading report, hence Low.
    The reverse skew is clean: new agents with 1.4.0 skills. The old orchestrator and old synthesis collect only finding blocks and the premise block, and ignore the extra trailing block. None-lines are unchanged in all 12 code agents. output-schema.md only appends a section. Roster, finding schema, category roots and the triage plan fields are untouched. Codex TOML conversion is unaffected, since the new text contains no `"""` or backslash (cli/src/lib/agents.ts mdToCodexToml).
  remedy: Make the missing-block line name the likely cause. When every receiver is silent, add something like "(agent definitions older than this release do not emit it; refresh with `npx review-pro@latest init` or `claude plugin update review-pro`)". Alternatively, have the orchestrator's reviewer prompt carry a one-line reminder to end with `## Files examined`, so the requirement ships with the skill version and not only with the agent version.
  confidence: medium
  overlap_hints: [correctness.devex]
  evidence_refs: [core/skills/review-pro/SKILL.md:28, README.md:151-161, cli/src/commands/doctor.ts:1-14, docs/superpowers/specs/2026-09-26-coverage-accounting-design.md:117]

- severity: Low
  category: api-contract.schema
  file: README.md
  line: 99
  title: The published example's coverage detail line names 2 receivers for a file that every dispatched code reviewer received
  evidence: |
    Coverage (self-reported): 6 of 7 changed files examined by at least one reviewer, 1 not examined.
      not examined: fixtures/cart-large.json (performance: generated fixture data; tests: fixture, no test logic)
  impact: |
    A file is in the `not examined` state only when every receiver lists it under `not_examined`. The detail line format lists every receiver: `not examined: <file> (<reviewer>: <reason>; ...)` (core/skills/review-pro-synthesize/SKILL.md:67). Every dispatched reviewer receives every changed file: context-policy.md:3 says "Baseline for every reviewer: the diff + full contents of changed files", and ADR-0010:28 says "Triage sends every reviewer every file".
    The same example report shows findings flagged by security, backend and frontend, so at least those three were also receivers of fixtures/cart-large.json, yet the detail line leaves them out. Either they declared it not examined and the line drops them, or one of them read it and the file should be `examined`.
    This is the flagship published example of the new report line. It teaches readers that only the relevant reviewers are listed, which is not the documented format.
  remedy: List every dispatched code reviewer in the detail line with its reason (e.g. add `security: fixture data; backend: fixture data; frontend: not UI`). Or shrink the example to a dispatch where performance and tests are the only code reviewers, and adjust the `flagged by` lines to match.
  confidence: high
  overlap_hints: []
  evidence_refs: [core/skills/review-pro-synthesize/SKILL.md:67, core/shared/context-policy.md:3, docs/internals/adr/0010-report-coverage-as-self-reported.md:28, README.md:104-114]

- severity: Low
  category: api-contract.schema
  file: docs-src/i18n/en.json
  line: 96
  title: The docs site's copy of the "runs the whole pipeline" sentence was not updated with cli/README and stays silent on the new report line (all 7 locales)
  evidence: |
    "docs.run.final": "The agent runs the whole pipeline natively — <code>git diff</code>, reads changed files, Globs <code>.review-pro/</code> for active stacks, dispatches the relevant reviewer subagents with their stack signals, and synthesizes one verdict: <strong>BLOCK / REQUEST CHANGES / APPROVE</strong>. No env vars, no scripts to run at review time.",
  impact: |
    This string is the site's version of cli/README.md:53. This branch edited that README line to add "reports which changed files the reviewers say they examined", and it already said "has an independent verifier try to refute up to 8 ...". The site string (rendered at docs/docs.html via docs-src/docs.html:130) and its six translations in de/fr/hi/nl/tr/zh.json now omit both. That is the only place on the site that lists what a review run produces, so a site reader will not learn about the Coverage line.
    Nothing on the site is false, and the verification gap predates this branch (since 1.4.0). No drift check catches it: validate.sh checks only reviewer counts in the locale files. Hence Low.
  remedy: Add the coverage clause, and the verification clause it already lacks, to `docs.run.final` in all seven dictionaries, then rebuild docs/*.html. Or note in the PR that the site is deliberately kept at pipeline level.
  confidence: high
  overlap_hints: []
  evidence_refs: [cli/README.md:53, docs-src/docs.html:130, scripts/validate.sh:447-571]

## Files examined
examined: [README.md, cli/README.md, core/agents/a11y-reviewer.md, core/agents/ai-antipatterns-reviewer.md, core/agents/api-contract-reviewer.md, core/agents/backend-reviewer.md, core/agents/correctness-reviewer.md, core/agents/craft-reviewer.md, core/agents/db-reviewer.md, core/agents/dry-reviewer.md, core/agents/frontend-reviewer.md, core/agents/performance-reviewer.md, core/agents/review-pro-synthesize-subagent.md, core/agents/security-reviewer.md, core/agents/tests-reviewer.md, core/shared/output-schema.md, core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro-triage/SKILL.md, core/skills/review-pro/SKILL.md, docs/internals/adr/0010-report-coverage-as-self-reported.md, docs/internals/glossary.md, docs/internals/reviewer-directive.md, docs/llms.txt, scripts/validate.sh]
not_examined:
  - file: docs/superpowers/plans/2026-09-26-coverage-accounting.md
    reason: grepped for back-compat wording only; implementation plan prose, not a published contract
  - file: docs/superpowers/plans/2026-09-26-ocr-lessons-roadmap.md
    reason: roadmap prose, outside the contract surface; not read
  - file: docs/superpowers/specs/2026-09-26-coverage-accounting-design.md
    reason: only the back-compat paragraph (lines 110-125) read via grep; design prose otherwise not read
  - file: scripts/validate.test.sh
    reason: test harness for the validator, not a published contract; seen only in grep hits
  - file: studies/2026-09-coverage-spike/PRE-REGISTRATION.md
    reason: study data, outside api-contract concern
  - file: studies/2026-09-coverage-spike/README.md
    reason: study data, outside api-contract concern
  - file: studies/2026-09-coverage-spike/analyze.py
    reason: one-off study script, not shipped or consumed by any install
  - file: studies/2026-09-coverage-spike/changed.txt
    reason: study data
  - file: studies/2026-09-coverage-spike/prompt.md
    reason: study data
  - file: studies/2026-09-coverage-spike/raw/correctness.analysis.txt
    reason: study raw output
  - file: studies/2026-09-coverage-spike/raw/correctness.md
    reason: study raw output
  - file: studies/2026-09-coverage-spike/raw/craft.analysis.txt
    reason: study raw output
  - file: studies/2026-09-coverage-spike/raw/craft.md
    reason: study raw output
  - file: studies/2026-09-coverage-spike/raw/tests.analysis.txt
    reason: study raw output
  - file: studies/2026-09-coverage-spike/raw/tests.md
    reason: study raw output
