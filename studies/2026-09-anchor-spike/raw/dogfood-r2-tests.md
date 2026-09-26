<!-- commit read: c610017; extracted verbatim from the PR #78 dogfood review's subagent final report -->
Both suites pass. `bash scripts/validate.test.sh` ends `pass=211 fail=0`, every line is `ok`, and all new AR/AS/AU cases fire. `./scripts/validate.sh` prints `OK: all artifacts valid`.

**Verdict on each hole:**
- **M1 (emptied `## Coverage` passed): fixed.** An empty section fires one error.
- **M2 (caveat pin satisfied by other lines): moved.** The new phrase appears twice inside `## Coverage`.
- **M3 (header-order check skipped silently): moved.** A present but hidden `## Output` section still skips without an error.
- **M4 (inline-block check satisfied by prose): moved.** The new prompt bullet at line 35 satisfies two of the pins.
- **M5 (block keys and body copies): drift fixed, key pinning partial.** All 12 bodies checksum identically, the spec body is skipped, and the drift case is proven. The `file` key is pinned nowhere, and 2 of the 3 key checks have no test.

**`section()` against the real files:** it handles the 2-space-indented fences in Coverage and the `## Verdict` / `## Spec (` lines inside the Output fence. It reads the last section of a file to EOF correctly (Output in the synthesis skill, Final reminder in the bodies). No `~~~` or 4-backtick fences exist in the repo. Its one weak spot is an unbalanced fence (finding 2).

**Old guards that now pass vacuously:** the orchestrator's `exactly once` and `examined: [` checks (finding 3). No others found.

Every mutation below was run on a copy under the scratchpad with `validate.sh <copy>`. Each passed as `OK: all artifacts valid` with no `FAIL`.

- severity: Medium
  category: tests.assertion
  file: scripts/validate.sh
  line: 287
  title: M2 moved, not removed. The 'nothing reviewed them' pin matches two lines in ## Coverage, so either line can be deleted silently.
  evidence: |
    cov_pin 'nothing reviewed them'               "the sent-to-no-reviewer caveat is gone from ## Coverage ..."
    # real core/skills/review-pro-synthesize/SKILL.md, both inside ## Coverage (grep count in section = 2):
    68: - Files sent to no reviewer also get this caveat under the detail lines, on every `diff_class`, because nothing reviewed them ...
    71:   > <s> changed files were sent to no reviewer, so nothing reviewed them: <files>.
  impact: Deleting only line 71 (the caveat text the report prints) passes. Deleting only line 68 (the rule "on every diff_class") also passes. The test fixture (validate.test.sh ~214) carries only the template line, so the "synthesis coverage deterministic" case can't see that a second line also satisfies the pin.
  remedy: Pin the text that appears only in the template, 'nothing reviewed them: <files>'. Separately pin the rule, e.g. 'also get this caveat' or 'on every `diff_class`'. Add line 68's bullet to the w_synth fixture, with one mutation per line.
  confidence: high
  overlap_hints: []

- severity: Medium
  category: tests.coverage
  file: scripts/validate.sh
  line: 296
  title: M3 moved. A `## Output` heading that section() can't see (unbalanced fence earlier in the file) disables the whole header-order check without an error.
  evidence: |
    out="$(section "$SYNTH_MD" '## Output')"
    if [[ -n "$out" ]]; then # a missing section is the required-section check's error
  impact: The required-section check greps `## Output` as a whole line and passes. section() then returns empty, because the heading sits inside what it thinks is an open fence, so the skip is silent. Proof: dropping only the ``` at synthesize SKILL.md:101 (Verification section) passes. Dropping it plus swapping the Spec and Verification template lines also passes, while the swap alone fails with "orders the header lines wrong". So does dropping it plus deleting every `Coverage (self-reported):` template line. By contrast, the `## Coverage` check fails loudly in the same situation ("section is empty").
  remedy: When `grep -qxF '## Output'` succeeds but section() is empty, call add_error (e.g. "the Output section is unreadable, check for an unbalanced fence before it"). Or check that the file's fence count is even. Add a mutation case that deletes one fence between Coverage and Output.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.assertion
  file: scripts/validate.sh
  line: 239
  title: M4 moved. The inline-block 'exactly once' check and the `examined: [` key check are both satisfied by the new step-2 prompt bullet, not by the inline block.
  evidence: |
    { grep -qxF '## Files examined' "$ORCH_MD" && grep -qF 'exactly once' "$ORCH_MD"; } \
    # core/skills/review-pro/SKILL.md:35 (the new `### Files examined` prompt bullet):
    ... `examined: [...]` then `not_examined:` entries with `file` and `reason`, accounting for each file in `### Changed file contents` exactly once.
  impact: Two single-line edits pass, each on its own. Removing " exactly once" from the inline paragraph (line 38) passes. Renaming the inline block key `examined: [<path>, ...]` to `read: [<path>, ...]` (line 42) passes, because has_block_keys finds `examined: [` on line 35. The fixture's prompt line (validate.test.sh:287, "a one-line reminder to end with the block.") contains neither phrase. So "orchestrator inline once" is detected in the fixture only because its sed rewrites every occurrence, and the real file has a second one.
  remedy: Scope both checks to the inline text: extract from "perform that review **inline**" through the closing fence and run the grep and has_block_keys on that. Or pin text only the inline block has, e.g. "`context.changed_files` exactly once" and a whole-line `^examined: \[`. Copy line 35's real wording into the w_orch fixture so the cases exercise this collision.
  confidence: high
  overlap_hints: []

- severity: Medium
  category: tests.coverage
  file: scripts/validate.sh
  line: 130
  title: has_block_keys has 2 of its 3 conditions untested, and the `file` key is checked nowhere
  evidence: |
    { grep -qF 'examined: [' "$1" && grep -qxF 'not_examined:' "$1" && grep -qF 'reason:' "$1"; } \
    # validate.test.sh:1291, 1300, 1343 - all three key cases mutate the same one:
    sed 's/^not_examined:$/skipped:/'
  impact: The `examined: [` and `reason:` conditions could be removed or broken and the suite stays green. This is the same class of gap as round-1 M4, which was an untested condition. Renaming `  - file: <path>` to `  - path: <path>` in all 12 bodies, output-schema.md and the orchestrator passes, since byte-identity only catches drift between bodies, not a uniform rename. Synthesis reads the block by these keys. Separately, the three copies (body section, schema, orchestrator block) are compared only through these keys, never to each other.
  remedy: Add one mutation per condition (drop `reason:`, rename `examined: [`) for at least one of the three call sites. Add `- file:` to has_block_keys, or compare the orchestrator's fenced block with the body's fenced block the same way the bodies are compared with each other.
  confidence: high
  overlap_hints: []

## Files examined
examined: [scripts/validate.sh, scripts/validate.test.sh, core/skills/review-pro/SKILL.md, core/skills/review-pro-synthesize/SKILL.md, README.md, docs-src/i18n/en.json, studies/2026-09-coverage-spike/analyze.py]
not_examined:
  - file: docs-src/i18n/de.json
    reason: translated prose string, no test logic; en.json read as the source
  - file: docs-src/i18n/fr.json
    reason: translated prose string, no test logic
  - file: docs-src/i18n/hi.json
    reason: translated prose string, no test logic
  - file: docs-src/i18n/nl.json
    reason: translated prose string, no test logic
  - file: docs-src/i18n/tr.json
    reason: translated prose string, no test logic
  - file: docs-src/i18n/zh.json
    reason: translated prose string, no test logic
  - file: docs/docs.html
    reason: generated site output, no test logic
  - file: docs/de/docs.html
    reason: generated site output, no test logic
  - file: docs/fr/docs.html
    reason: generated site output, no test logic
  - file: docs/hi/docs.html
    reason: generated site output, no test logic
  - file: docs/nl/docs.html
    reason: generated site output, no test logic
  - file: docs/tr/docs.html
    reason: generated site output, no test logic
  - file: docs/zh/docs.html
    reason: generated site output, no test logic
  - file: docs/superpowers/specs/2026-09-26-coverage-accounting-design.md
    reason: design prose, outside test-quality scope; not read
