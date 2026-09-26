<!-- commit read: 14c52d4; extracted verbatim from the PR #78 dogfood review's subagent final report -->
- severity: Low
  category: spec.missing
  file: core/skills/review-pro/SKILL.md
  line: 0
  title: absent - the sent-to-no-reviewer caveat never prints when triage dispatches no reviewers (docs-only trivial diff), because the unchanged Rules line 107 returns APPROVE before synthesis runs
  evidence: |
    "Files sent to no reviewer get a caveat block under the coverage line, printed on every diff class:"
    "`diff_class: trivial`: omit the coverage line and its detail lines. [...] The caveat above still prints."
    From the maintainer request: "diff_class trivial olduğunda ve docs dosyalarında ne yapılır?" and "eksik bir rapor asla tam kapsam gibi görünmemeli."
  evidence_refs: [docs/superpowers/specs/2026-09-26-coverage-accounting-design.md:177, docs/superpowers/specs/2026-09-26-coverage-accounting-design.md:186, maintainer request (branch brief)]
  impact: The branch leaves `core/skills/review-pro/SKILL.md:107` ("If triage dispatches no reviewers (e.g. docs-only change), return `APPROVE` with a one-line note.") as it was. Triage marks a docs-only change as `diff_class: trivial` (review-pro-triage/SKILL.md:21). When no reviewer is dispatched for such a change, every changed file is sent to no reviewer. That is exactly the deterministic case the design says still prints on trivial diffs, yet the orchestrator short-circuits before the synthesis Coverage step can print it. The same docs-only diff with a resolved spec (spec reviewer dispatched, and it is not a receiver) does print the caveat for every file, so the output depends on whether a spec happened to resolve.
  remedy: Make the no-dispatch rule print the deterministic caveat (`> <n> changed files were sent to no reviewer, so nothing reviewed them: ...`) next to its APPROVE note, or state in the design and the synthesis Coverage section that a zero-dispatch review is exempt and why.
  confidence: medium
  overlap_hints: []

- severity: Low
  category: spec.missing
  file: core/skills/review-pro/SKILL.md
  line: 0
  title: partial - inline synthesis (step 5, line 63) lists the synthesis steps it runs after verification but leaves out the new Coverage step
  evidence: |
    From the maintainer request: "Hem subagent yolu hem inline yol aynı davranmalı."
    From the design: "Both paths behave the same: a subagent reviewer takes the rule from its body; an inline reviewer takes it from the orchestrator skill; subagent synthesis takes the inputs from its body and the rule from the synthesis skill; inline synthesis takes both from the skills."
  evidence_refs: [maintainer request (branch brief), docs/superpowers/specs/2026-09-26-coverage-accounting-design.md:217]
  impact: The unchanged `core/skills/review-pro/SKILL.md:63` says "Continue the `review-pro-synthesize` skill from **Verification results** [...]: apply the results, calibrate severity (anti-overreporting), run the out-of-diff check, and emit the verdict." That was a complete list of the old steps 5 to 8. The branch inserts **Coverage** as step 8 of the synthesis skill, so the list is now incomplete. An inline orchestrator that follows the list can skip the Coverage computation (the contradiction line, `no Files examined block from`, the not-reported state). It would then print only the bare template line, while a subagent synthesis that follows the skill runs the full computation.
  remedy: Add "compute Coverage" to the step 5 list, between the out-of-diff check and the verdict.
  confidence: medium
  overlap_hints: []

Notes (not findings): Every other stated requirement is met in the diff:
- The deterministic layer and the self-reported layer carry separate labels, and the report never uses the words verified, confirmed, complete or full.
- A missing block renders as `not reported` and the silent reviewer is named.
- Examined means "by at least one reviewer".
- The coverage line sits between Spec and Verification.
- A trivial diff gets no coverage line, but the caveat stays.
- The contradiction check (a finding in a file declared not examined) is in place.
- Coverage is review-level only.
- The block is optional and additive.
- All 12 code reviewer bodies carry the same section and it is named in each Final reminder. The spec reviewer is excluded explicitly per design decision 3.
- The inline reviewer block is in the orchestrator.
- The validator has checks with mutation tests, and `scripts/validate.sh` exits 0.
- README, cli/README and llms.txt are updated. docs-src and the npm description were checked and left alone, per plan step 3.
- ADR-0010 exists.
- The roadmap file is added with item 1's Status updated.
- The design leaves room for item 2.
- New text adds no em dash (the 11 em dashes in `+` lines are all on lines that already had one), and new agent-body text has no backslash or `"""`, so the Codex TOML is safe.
