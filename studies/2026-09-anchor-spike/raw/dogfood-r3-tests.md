<!-- commit read: 6e81028; extracted verbatim from the PR #78 dogfood review's subagent final report -->
- severity: Medium
  category: tests.coverage
  file: scripts/validate.test.sh
  line: 1362
  title: the honesty-rule mutation removes both phrases at once, so neither half of the `&&` check is tested on its own
  evidence: |
    validate.sh:268  elif ! { printf '%s' "$reminder" | grep -qF 'examined only if it read' && printf '%s' "$reminder" | grep -qF 'overstates what it read'; }; then
    validate.test.sh:1362  stage_mutation ... "orchestrator reminder honesty"  sed 's/; a file counts as examined only if it read the file.s diff or contents, and a complete-looking list that overstates what it read is wrong//'
  impact: I proved this on a copy of validate.sh. I changed the `&&` on line 268 to `||`, so the check only errors when BOTH phrases are gone, and `bash validate.test.sh` still printed pass=217 fail=0. The check works today: removing only the overstating clause from the real core/skills/review-pro/SKILL.md:35 fires "lost its honesty rule". But the suite would not catch a later edit that weakens the check so an older agent is told only one half of the honesty rule.
  remedy: split the case into two stage_mutations on the fixture reminder at validate.test.sh:294. One removes only `, and a complete-looking list that overstates what it read is wrong`. The other rewords only `examined only if it read`. Each expects "lost its honesty rule" alone.
  confidence: high
  overlap_hints: []

- severity: Medium
  category: tests.coverage
  file: scripts/validate.test.sh
  line: 1327
  title: the caveat-rule mutation deletes the whole line, so the `on every diff_class` half, the part the error message names, is never tested
  evidence: |
    validate.sh:315  printf '%s\n' "$COV" | grep -F 'also get this caveat' | grep -qF 'on every `diff_class`' \
          || add_error "...the caveat rule is gone from ## Coverage - nothing says the caveat prints on trivial diffs too"
    validate.test.sh:1327  stage_mutation "$SYN" w_synth "the caveat rule is gone" "synthesis coverage caveat rule" grep -vF 'also get this caveat'
  impact: I proved this on a copy of validate.sh. I reduced line 315 to `grep -qF 'also get this caveat'`, which drops the `on every diff_class` requirement, and the suite still printed pass=217 fail=0. The live check does catch a real edit: deleting ` on every \`diff_class\`,` from review-pro-synthesize/SKILL.md:68 fires "the caveat rule is gone". But nothing guards the check itself against losing that half, which is the part this round made line-scoped.
  remedy: add a stage_mutation `sed 's/, on every `diff_class`//'` on the fixture line at validate.test.sh:217, expecting "the caveat rule is gone" alone.
  confidence: high
  overlap_hints: []

- severity: Low
  category: tests.coverage
  file: scripts/validate.sh
  line: 264
  title: the reminder check protects the honesty rule but not the format or the exactly-once rule, although its comment says the reminder is the whole contract, "not only the format"
  evidence: |
    validate.sh:263  # Line-scoped: for an agent older than this release the reminder is the whole contract,
    validate.sh:264  # so it must carry the honesty rule the spike measured, not only the format.
    validate.sh:258  grep -qF "accounting for each file in that reviewer's \`context.changed_files\` exactly once"   # matches the inline sentence (SKILL.md:38) only
  impact: I proved this on a temp copy. One edit to core/skills/review-pro/SKILL.md:35 deletes "`examined: [...]` then `not_examined:` entries with `file` and `reason`, accounting for each file in `### Changed file contents` exactly once; ". The reminder is left with only the heading name and the honesty rule, and `./scripts/validate.sh` prints "OK: all artifacts valid", exit 0. This round moved the `exactly once` pin to the inline sentence, so nothing reads the reminder's exactly-once or keys any more. The failure is safe: synthesis renders a missing or partial block as not reported, never as examined. But the coverage signal is lost for exactly the old-agent case the reminder exists for.
  remedy: in the `elif` branch, also require `exactly once` and `not_examined:` on the `$reminder` line. Add a mutation for each (the fixture line at validate.test.sh:294 already carries both).
  confidence: high
  overlap_hints: []

- severity: Low
  category: tests.coverage
  file: core/skills/review-pro/SKILL.md
  line: 48
  title: the inline path's honesty rule has no guard, although its twin in the prompt reminder got a line-scoped pin this round
  evidence: |
    A file counts as examined only if you read its diff or contents while applying that rubric. An accurate list with gaps is correct; a complete-looking list that overstates what you read is wrong, because synthesis reports it as the review's coverage. The spec review emits no block.
  impact: I deleted this one line on a temp copy (a single-line-deletion sweep of the guarded regions) and `./scripts/validate.sh` passed. On a skills-only install the orchestrator writes the block itself, and this line is the only place that tells it an overstated list is wrong. This round's pins cover the inline sentence (exactly once) and the canonical block, not this rule. The line was added on this branch (`git diff main...HEAD`).
  remedy: pin it the same way as the reminder: a whole-line grep of this sentence or a check scoped to the line containing 'overstates what you read', plus a stage_mutation that removes it.
  confidence: medium
  overlap_hints: []

## Files examined
examined: [scripts/validate.sh, scripts/validate.test.sh, core/skills/review-pro/SKILL.md, README.md, docs-src/i18n/de.json, docs/de/docs.html, docs/superpowers/specs/2026-09-26-coverage-accounting-design.md]
not_examined: []

Verification notes for the caller (everything below was run, and the tracked tree is still clean):
- Both runs pass. `bash scripts/validate.test.sh` gives pass=217 fail=0, exit 0, and the output has no `not ok` lines. `./scripts/validate.sh` gives "OK: all artifacts valid", exit 0.
- No add_error runs inside a `$(...)` subshell. The functions that call add_error (has_canonical_block, read_section, cov_pin) are always called directly. The remaining `$(...)` hits are arguments to add_error, and the line 752 pipeline calls add_error in the main shell.
- The new exit-status test is real. When I wrapped read_section's add_error in `( … )` on a copy, the suite failed with "not ok - unreadable-section error does not fail the run".
- These holes are closed:
  - Canonical block: renaming any single key in one body, in the schema or in the orchestrator fails.
  - Fence-aware heading checks: deleting the real `## Files examined` heading fails for the body and the schema, even though a copy of the heading survives inside the fence.
  - Caveat template line: fails when removed; the rule line's phrase no longer satisfies the pin.
  - read_section: deleting any single fence line in review-pro-synthesize/SKILL.md (32, 36, 63, 65, 70, 72, 101, 104, 185) fails.
  - Body edits: the byte-identity drift check catches any single-body edit, fence edits included.
- One single-line deletion passes but is harmless: deleting a fence line around a canonical block (output-schema.md:36/42, review-pro/SKILL.md:40/46, synthesize:228) still passes. The block text stays intact and none of the orchestrator's checks depend on fence parity, so I did not treat it as a contract break.
- There is one limit that no text pin can close: qualifying a pinned line in place (for example appending "except `trivial`" to the caveat rule) still passes.
