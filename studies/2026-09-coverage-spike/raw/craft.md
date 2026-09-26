- severity: Medium
  category: craft.code-judo
  file: scripts/validate.sh
  line: 12
  title: New "verifier" manifest role is read by nothing; stage membership stays in two hardcoded lists that the PR deliberately lets diverge
  evidence: |
    # Pipeline-stage skills: they do not follow the reviewer section contract, and each has
    # its own required sections below. Not the CLI's ORCHESTRATOR_SKILLS, which lists the
    # stages run inline; the verifier must run as a real subagent and is not in that list.
    ORCHESTRATORS=("review-pro" "review-pro-triage" "review-pro-synthesize" "review-pro-verify")
    --- manifest.json
    +    { "name": "review-pro-verify", "role": "verifier" },
    --- cli/src/lib/plugin.ts:11 (not in diff)
    const ORCHESTRATOR_SKILLS = new Set(["review-pro-triage", "review-pro-synthesize", "review-pro"]);
  impact: The PR adds `role: "verifier"` to manifest.json, but no code reads it. A grep for `"verifier"`/`role` across cli/src and scripts/validate.sh finds only `role == "reviewer"` filters (validate.sh:379, :708; catalog.ts:45). Stage membership now lives in two lists with the same name in two languages. They hold different members on purpose, and the only thing keeping them apart is a three-line comment. The bash array is now called ORCHESTRATORS but holds a skill the manifest says is not an orchestrator. The next stage added has to be placed correctly in two lists and one comment, and neither list is checked against the manifest.
  remedy: Let the manifest role decide. In validate.sh, replace the hardcoded array and `is_orchestrator` with the skill names whose manifest role is not `reviewer`. validate.sh already loads manifest.json in its python blocks (line 379), so this is a small change. Older test fixtures that have no manifest entry for an orchestrator need one added. For the CLI, have the build emit the roles next to the reviewers.json it already produces, and define ORCHESTRATOR_SKILLS as `role === "orchestrator"`. The divergence then comes from the data and the explanatory comment can be deleted. If you defer the CLI half, at least rename the bash array to PIPELINE_STAGES so its name matches what it holds.
  confidence: medium
  evidence_refs: [cli/src/lib/plugin.ts:11, cli/src/lib/plugin.ts:144, scripts/validate.sh:379, cli/src/lib/catalog.ts:45, manifest.json:10]
  overlap_hints: [dry.duplication, api-contract.schema]

- severity: Low
  category: craft.code-judo
  file: scripts/validate.test.sh
  line: 1134
  title: Every new phrase pin is written again by hand as a mutation line, and the three case preambles are copies of each other
  evidence: |
    # validate.sh:230
      grep -qF 'keeps the severity it had when it was selected' "$SYNTH_MD" \
        || add_error "review-pro-synthesize/SKILL.md: the severity freeze is gone - ..."
    # validate.test.sh:1192
    stage_mutation "$SYN" w_synth "the severity freeze is gone"  "synthesis severity freeze"  grep -vF "keeps the severity it had when it was selected"
    # validate.sh:204 and :216: two consecutive `if [[ -f "$SYNTH_MD" ]]; then ... fi` blocks (a third is at :154)
  impact: The PR adds 22 phrase pins to validate.sh, and 21 of them are written a second time as a `stage_mutation` line. The only one without a mutation line is the harm-not-title pin, which its sed mutation removes by breaking the phrase. Each rule's phrase now sits in four places: the skill, the validator, the fixture, and the mutation line. Cases AN, AO and AP repeat the same setup (mktemp, mkdir, write_good_reviewer, a manifest heredoc, a control check), changing only the skill name and role. `stage_mutation` is a generalised copy of the existing `sec_mutation` (line 1089) and sits next to it. The SYNTH_MD guard is now split across three blocks, with the new one opening directly after the previous block's `fi`.
  remedy: Move the grep-pins into one table of `file|phrase|message` rows, with a single loop that runs `grep -qF ... || add_error`. The test can then generate one deletion mutation per row instead of listing them by hand. Keep hand-written mutations only for the ordering, anti-pattern and sed-rewrite checks. Pull the case preamble into a `stage_case <skill> <role> <writer>` helper. At a minimum, merge the new SYNTH_MD block into the one directly above it.
  confidence: medium
  evidence_refs: [scripts/validate.sh:204, scripts/validate.sh:216, scripts/validate.test.sh:1089, scripts/validate.test.sh:1185]
  overlap_hints: [dry.duplication, tests.maintainability]

- severity: Low
  category: craft.boundary
  file: core/skills/review-pro/SKILL.md
  line: 64
  title: The report template is kept in both the orchestrator and synthesis skills, and the PR changes both copies line for line
  evidence: |
    core/skills/review-pro/SKILL.md:59   ## Verdict: <BLOCK | REQUEST CHANGES> (<code | spec | code + spec>)[, <N> disputed] | APPROVE
    core/skills/review-pro/SKILL.md:64   Verification: <N> checked (<a> stand, <b> partly refuted, <c> refuted), <M> not checked (<counts by reason>). Spec findings are not verified.
    core/skills/review-pro/SKILL.md:77   ### Refuted in verification
    core/skills/review-pro-synthesize/SKILL.md:145/150/169  (the same three lines)
  impact: Synthesis owns the output format, and the orchestrator runs that same skill inline in step 5. Even so, the PR adds the disputed suffix, the Verification line and the Refuted section to both templates. The copies have already drifted: the orchestrator's Refuted block has no `noticed (not reviewed)` line, which synthesis's version has. Each future format change needs two edits, and nothing checks that the copies match.
  remedy: Replace the orchestrator's `## Output` template with a one-line pointer: "Return ONLY the report in the `review-pro-synthesize` skill's Output format." That leaves synthesis as the only owner of the format.
  confidence: medium
  evidence_refs: [core/skills/review-pro-synthesize/SKILL.md:145, core/skills/review-pro-synthesize/SKILL.md:150, core/skills/review-pro-synthesize/SKILL.md:169]
  overlap_hints: [dry.duplication]

## Files examined
examined: [README.md, cli/tests/plugin-cross.test.ts, cli/tests/uninstall.test.ts, core/agents/review-pro-synthesize-subagent.md, core/agents/review-pro-verify-subagent.md, core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro-verify/SKILL.md, core/skills/review-pro/SKILL.md, docs/internals/adr/0009-verify-findings-by-refutation.md, docs/internals/glossary.md, manifest.json, scripts/validate.sh, scripts/validate.test.sh, studies/2026-09-refuting-verifier/README.md, studies/2026-09-refuting-verifier/prompt.tmpl, studies/2026-09-refuting-verifier/SHA256SUMS]
not_examined:
  - file: docs/superpowers/plans/2026-09-24-refuting-verifier.md
    reason: 1173-line implementation plan doc; not read, no code structure to judge
  - file: docs/superpowers/specs/2026-09-24-refuting-verifier-design.md
    reason: design spec prose; not read
  - file: studies/2026-09-refuting-verifier/PRE-REGISTRATION.md
    reason: study data; not read
  - file: studies/2026-09-refuting-verifier/RESULTS.md
    reason: study data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/PRE-REGISTRATION.md
    reason: study data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/RESULTS.md
    reason: study data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/PRE-REGISTRATION.md
    reason: study data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/RESULTS.md
    reason: study data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/aspire-report.md
    reason: study data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/control-report.md
    reason: study data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-ai-antipatterns.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-correctness.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-craft.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-tests.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-verify-craft-34.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/e2e/raw/B-security.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V01.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V02.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V03.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V04.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V05.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V06.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V07.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V08.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V09.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V10.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V11.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V12.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/raw/V13.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/render/EXPECTED.md
    reason: render fixture data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/render/INPUT.md
    reason: render fixture data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/render/OUTPUT-inline.md
    reason: render fixture data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/render/OUTPUT-no-results.md
    reason: render fixture data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/PRE-REGISTRATION.md
    reason: study data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/RESULTS.md
    reason: study data; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W01.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W02.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W03.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W04.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W05.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W06.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W07.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/items/W08.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V01.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V02.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V03.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V04.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V05.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V06.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V07.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V08.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V09.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V10.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V11.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V12.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/V13.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W01.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W02.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W03.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W04.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W05.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W06.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W07.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/acceptance/run2/raw/W08.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/items/V01.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V02.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V03.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V04.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V05.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V06.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V07.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V08.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V09.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V10.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V11.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V12.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/items/V13.md
    reason: study item; not read
  - file: studies/2026-09-refuting-verifier/raw/V01-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V01-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V02-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V02-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V03-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V03-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V04-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V04-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V05-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V05-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V06-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V06-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V07-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V07-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V08-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V08-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V09-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V09-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V10-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V10-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V11-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V11-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V12-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V12-B.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V13-A.md
    reason: raw study output; not read
  - file: studies/2026-09-refuting-verifier/raw/V13-B.md
    reason: raw study output; not read