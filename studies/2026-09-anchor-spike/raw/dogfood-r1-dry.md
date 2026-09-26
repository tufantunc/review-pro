<!-- commit read: 14c52d4; extracted verbatim from the PR #78 dogfood review's subagent final report -->
- severity: Medium
  category: dry.canonical-helper
  file: scripts/validate.sh
  line: 142
  title: The coverage guard adds a fourth body loop instead of extending the SCHEMA_KEYS parity pattern, so the block's field names are pinned nowhere
  evidence: |
    for body in "$ROOT"/core/agents/*-reviewer.md; do
      [[ -f "$body" ]] || continue
      [[ "$(fm_get "$body" "loads_skill")" == "spec" ]] && continue
      b="$(basename "$body")"
      grep -qxF '## Files examined' "$body" \
      ...
      grep -qF 'exactly once' "$body" \
      ...
    if [[ -f "$SCHEMA_DOC" ]]; then
      { grep -qxF '## Files examined' "$SCHEMA_DOC" && grep -qF 'exactly once' "$SCHEMA_DOC"; } \
  evidence_refs: [scripts/validate.sh:112, scripts/validate.sh:128, core/shared/output-schema.md:37, core/skills/review-pro/SKILL.md:40, core/skills/review-pro-synthesize/SKILL.md:52]
  impact: The repo already holds the schema doc and the bodies together with one mechanism. SCHEMA_KEYS at validate.sh:112-120 loops over a key array and checks each key in output-schema.md and in every body. BODY_INVARIANTS at validate.sh:128 does the same for body structure. The new check hand-rolls a separate loop and a separate two-grep check on the schema doc. It pins the heading and two prose phrases, but none of the tokens synthesis actually parses: `examined: [`, `not_examined:`, `- file:`, `reason:`. Synthesis's state table (review-pro-synthesize/SKILL.md, ## Coverage) keys on "lists it under `examined`" and "under `not_examined`". The block format now exists in 14 shipped copies (12 reviewer bodies, output-schema.md, review-pro/SKILL.md), and a key renamed in any one of them passes validation. ADR-0001 accepts duplication only when validator greps hold the copies together. Here they hold the heading, not the contract.
  remedy: Add a CODE_BODY_KEYS array next to SCHEMA_KEYS (validate.sh:113) holding '## Files examined', 'exactly once', 'overstates what', 'not_examined:' and 'examined: ['. Check it against SCHEMA_DOC, ORCH_MD and every non-spec body with the existing SCHEMA_KEYS loop shape, and delete the bespoke checks at :146-150, :155-158 and :233-235. The 12 body sections are byte-identical today (verified by hashing the section in each body). A cheaper and stronger option is to assert that the section hash is equal across all code reviewer bodies, which catches divergence and not just deletion, the gap ADR-0001 and #44 name.
  confidence: high
  overlap_hints: [craft.canonical-helper, tests.missing-coverage]

- severity: Medium
  category: dry.duplication
  file: core/skills/review-pro/SKILL.md
  line: 74
  title: The orchestrator's report template copies the coverage line from synthesis and has already lost the detail lines
  evidence: |
    Coverage (self-reported): <e> of <n> changed files examined by at least one reviewer[, <x> not examined][, <u> not reported][, <s> sent to no reviewer].

    Verification: <N> checked (<a> stand, <b> partly refuted, <c> refuted), ...
  evidence_refs: [core/skills/review-pro-synthesize/SKILL.md:191, core/skills/review-pro-synthesize/SKILL.md:192, core/skills/review-pro-synthesize/SKILL.md:67, scripts/validate.sh:31]
  impact: On the inline path the orchestrator runs synthesis itself ("Continue the `review-pro-synthesize` skill from **Verification results**") and is then told "Return ONLY the final synthesis report" against its own template. The two templates already disagree. Synthesis:191-192 shows the `  not examined: <file> (<reviewer>: <reason>)` detail line. The orchestrator copy at :74 does not, and it also shows no place for the sent-to-no-reviewer caveat. An inline run can follow the shorter template and drop exactly the per-file reasons that make the coverage line useful. check_header_order (validate.sh:31) pins only the 'Coverage (self-reported):' prefix and the Spec, Coverage, Verification order, so it cannot catch the drift that already exists or future drift in the counts and brackets. This copy is not covered by ADR-0001: the orchestrator is a skill that reads other skills, not a subagent body.
  remedy: Replace the fenced template under review-pro/SKILL.md `## Output` with a pointer: "Return ONLY the report in the `review-pro-synthesize` skill's `## Output` format". Then check_header_order has one template to check, and the ORCH_MD call at validate.sh:236 goes away. If the copy has to stay, pin the full coverage line and the `not examined:` detail line in both files, not just the prefix.
  confidence: high
  overlap_hints: [correctness.broken-functionality, craft.abstraction]

- severity: Low
  category: dry.duplication
  file: core/skills/review-pro/SKILL.md
  line: 37
  title: The inline path re-states the Files examined block and its rules that output-schema.md already carries for that path
  evidence: |
    Every inline code review ends with the same `## Files examined` block a subagent returns, accounting for each file in that reviewer's `context.changed_files` exactly once:
    ```
    ## Files examined
    examined: [<path>, ...]
    not_examined:
    ...
    A file counts as examined only if you read its diff or contents while applying that rubric. An accurate list with gaps is correct; a complete-looking list that overstates what you read is wrong, ...
  evidence_refs: [core/shared/output-schema.md:31, scripts/validate.sh:157, core/skills/review-pro/SKILL.md:34]
  impact: output-schema.md:31-48 defines the same block and the same four rules, and the validator's message for it (validate.sh:157) says it exists so that "rubric readers and the inline path" keep the contract. The inline path therefore has two sources, which differ slightly in wording ("overstates what was read" in one, "overstates what you read" in the other), plus a third validator pin (validate.sh:233-235). The orchestrator already defers to core/shared for other contracts ("emit findings in the shared schema", and `core/shared/context-policy.md` at :34), so ADR-0001's reason for inlining does not apply.
  remedy: Replace the fence and the rules paragraph with "ends with the `## Files examined` block defined in `core/shared/output-schema.md`, accounting for each file in that reviewer's `context.changed_files`". Keep the validator pin on the pointer phrase instead of on 'exactly once'.
  confidence: medium
  overlap_hints: [craft.abstraction]

- severity: Low
  category: dry.missing-abstraction
  file: scripts/validate.sh
  line: 265
  title: The same awk section-extraction idiom is written three times in this diff with no helper
  evidence: |
    36:  out="$(awk '/^## Output$/{s=1;next} s&&/^## [A-Z]/&&!/^## Verdict/&&!/^## Spec \(/{exit} s' "$f")"
    152:  awk '/^## Final reminder/{s=1;next} s&&/^## /{exit} s' "$body" | grep -qF '## Files examined' \
    265:  COV="$(awk '/^## Coverage$/{s=1;next} s&&/^## /{exit} s' "$SYNTH_MD")"
  evidence_refs: [scripts/validate.sh:52, scripts/validate.sh:310]
  impact: The branch introduces section scoping as a validator technique and copies it three ways. The copies already vary in anchoring (`$` on two, none on Final reminder) and in what ends a section. The next section-scoped pin will be a fourth copy. The line-number lookup in check_header_order at :37-40 (`grep -nF ... | head -1 | cut -d: -f1`) also repeats, three more times, the idiom already at :310-311 for the Resolve conflicts and Verification results order check.
  remedy: Add `section_of(){ awk -v h="$1" '$0==h{s=1;next} s&&/^## /{exit} s' "$2"; }` beside fm_get (:52), and `line_of(){ grep -nF "$1" | head -1 | cut -d: -f1; }`. Use both at :36-40, :152, :265 and :310-311. The Output case can keep its extra exclusions as a parameter or a wrapper.
  confidence: high
  overlap_hints: [craft.code-judo]

- severity: Nitpick
  category: dry.copy-paste
  file: scripts/validate.test.sh
  line: 1318
  title: The header-order swap sed is pasted twice, w_tri wraps nothing, and Case AR re-types Case V's spec fixture
  evidence: |
    1294: stage_mutation "$SYN" w_synth "Output template orders" ... sed -e 's/^Spec: measured against <ref>$/@@S@@/' -e 's/^Verification: <N> checked$/Spec: measured against <ref>/' -e 's/^@@S@@$/Verification: <N> checked/'
    1318: stage_mutation "$ORC" w_orch "Output template orders" ... sed -e 's/^Spec: measured against <ref>$/@@S@@/' -e 's/^Verification: <N> checked$/Spec: measured against <ref>/' -e 's/^@@S@@$/Verification: <N> checked/'
    1321: w_tri(){ write_stage_skill "$1"; }
  evidence_refs: [scripts/validate.test.sh:1320, scripts/validate.test.sh:683, scripts/validate.test.sh:1260]
  impact: The swap expression is identical in both places and has to change in two places if the template wording changes. w_tri is behaviourally identical to write_stage_skill, which the line above (:1320) already passes directly. Case AR's setup at :1260-1265 (mkdir, two write_good_reviewer calls, the spec printf, write_good_spec_body) repeats Case V at :683-687 line for line.
  remedy: Define `swap_spec_verification=(sed -e ... )` once and pass "${swap_spec_verification[@]}" at both call sites. Pass write_stage_skill as the writer at :1322 and drop w_tri. Extract a `spec_fixture` helper for the Case V and Case AR setup, in the same shape as stage_fixture (:307).
  confidence: high
  overlap_hints: [tests.maintainability]

## Files examined
examined: [scripts/validate.sh, scripts/validate.test.sh, core/shared/output-schema.md, core/skills/review-pro/SKILL.md, core/skills/review-pro-synthesize/SKILL.md, core/skills/review-pro-triage/SKILL.md, core/agents/review-pro-synthesize-subagent.md, core/agents/dry-reviewer.md, core/agents/a11y-reviewer.md, core/agents/ai-antipatterns-reviewer.md, core/agents/api-contract-reviewer.md, core/agents/backend-reviewer.md, core/agents/correctness-reviewer.md, core/agents/craft-reviewer.md, core/agents/db-reviewer.md, core/agents/frontend-reviewer.md, core/agents/performance-reviewer.md, core/agents/security-reviewer.md, core/agents/tests-reviewer.md, docs/internals/adr/0010-report-coverage-as-self-reported.md, docs/internals/reviewer-directive.md, docs/internals/glossary.md, docs/llms.txt, README.md, cli/README.md, studies/2026-09-coverage-spike/analyze.py]
not_examined:
  - file: docs/superpowers/plans/2026-09-26-coverage-accounting.md
    reason: implementation plan prose, not shipped; grep showed it carries the block keys but I did not read it
  - file: docs/superpowers/plans/2026-09-26-ocr-lessons-roadmap.md
    reason: roadmap prose, not shipped code or contract
  - file: docs/superpowers/specs/2026-09-26-coverage-accounting-design.md
    reason: design prose, not shipped; ADR-0010 read instead
  - file: studies/2026-09-coverage-spike/PRE-REGISTRATION.md
    reason: frozen study record, not a duplication surface
  - file: studies/2026-09-coverage-spike/README.md
    reason: frozen study record, not a duplication surface
  - file: studies/2026-09-coverage-spike/changed.txt
    reason: study data (file list)
  - file: studies/2026-09-coverage-spike/prompt.md
    reason: frozen study prompt snapshot; copying the body wording there is intentional
  - file: studies/2026-09-coverage-spike/raw/correctness.analysis.txt
    reason: raw study output data
  - file: studies/2026-09-coverage-spike/raw/correctness.md
    reason: raw study output data
  - file: studies/2026-09-coverage-spike/raw/craft.analysis.txt
    reason: raw study output data
  - file: studies/2026-09-coverage-spike/raw/craft.md
    reason: raw study output data
  - file: studies/2026-09-coverage-spike/raw/tests.analysis.txt
    reason: raw study output data
  - file: studies/2026-09-coverage-spike/raw/tests.md
    reason: raw study output data

Notes for the caller (outside the output contract): I read the dry-reviewer.md diff in full. For the other 11 code reviewer bodies I compared diffs by hash and hashed the extracted `## Files examined` section of each; all 12 are byte-identical, and spec-reviewer.md is unchanged. analyze.py has no existing counterpart; it is the only Python file in the repo, and no other study parses transcripts. The published-surface prose edits (README.md, cli/README.md, llms.txt, glossary.md) are per-surface summaries, not duplicated logic, so I did not flag them.
