<!-- c39 ai-antipatterns-reviewer; verbatim final answer -->
I found one Low finding. The external premise is contradicted: I ran the regex locally and its runtime grows quadratically. There is also one Nitpick.

- severity: Low
  category: ai-antipatterns.hallucination
  file: cli/src/lib/agents.ts
  line: 19
  title: The S8786 "false positive" is a real quadratic regex, and the claim that it "measured flat" is wrong
  evidence: |
    const m = lines[i].match(/^([a-zA-Z_]+):\s*(.*)$/);
  impact: |
    Commit 9ad6c6d marks this S8786 hit as a false positive and leaves it unchanged. Its reasons are that the regex is "anchored and measured flat at n=32000" and that it matches the rule's compliant `/^a+b/` shape. Both reasons are wrong.
    - The `^` anchor only fixes where the match starts. The problem is the tail: `\s*` and `(.*)` sit next to each other and both match spaces, followed by `$`.
    - When a line has a run of spaces followed by a character `.` cannot match but that is not at the end, the engine retries every way of splitting the spaces between `\s*` and `.*`. `\r` inside a line is such a character.
    - Timed locally in Node on `"a:" + " ".repeat(n) + "x\ry"`: 11.2 / 49.4 / 175.5 / 715.7 ms at n = 5k / 10k / 20k / 40k. Doubling the input quadruples the time, so it is O(n^2).
    - The "flat" measurement only happened because its test input let `$` match on the first try. This is the same mistake the commit's own second part admits for `/\s+$/`.
    Real-world risk is small because the input is the repo's own agent `.md` files, read at cli/src/lib/plugin.ts:141 and :223. The damage is the wrong decision: a correct finding was recorded as a false positive in SonarQube.
    Side effect for correctness: the same pattern returns `null` on CRLF lines (`"name: foo\r".match(re)` gives null). An agent file saved with CRLF line endings would fail with "agent: missing name".
  remedy: |
    Remove the overlapping quantifier and trim afterwards. This is linear (0.02-0.05 ms at n up to 40k) and also fixes CRLF:
    `const m = lines[i].trimEnd().match(/^([a-zA-Z_]+):(.*)$/); if (m) fm[m[1]] = m[2].trim();`
    Then withdraw the false-positive resolution in SonarQube.
  confidence: high
  evidence_refs: [cli/src/lib/plugin.ts:141, cli/src/lib/plugin.ts:223, "local node runtime reproduction (no external doc consulted)"]
  overlap_hints: [performance.regex, correctness.error-path]

- severity: Nitpick
  category: ai-antipatterns.ignored-convention
  file: cli/src/lib/agents.ts
  line: 1
  title: Deleting the only import left a blank first line
  evidence: |
         1	
         2	export interface CanonicalAgent {
  impact: No other file in cli/src/lib starts with a blank line (log.ts, manifest.ts and catalog.ts all start with code). It looks like one line was cut out instead of the file being tidied.
  remedy: Delete the empty line 1.
  confidence: high
  overlap_hints: [craft.style]

Everything else I checked holds:
- **update.ts:** the removed `listCatalogStacks` import really was unused.
- **catalog.ts:** all three callers do pass `catalogDir` (cli/src/lib/doctor.ts:16, cli/src/commands/update.ts:12, cli/src/commands/list.ts:11). A multi-line doc comment also has precedent at cli/src/lib/plugin.ts:85.
- **build-site.js:** the reordered regexes and `trimEnd()` are real, built-in string methods, and no new dependency or config key was added.

## Premise verification
- premise: "S8786 also fired on `/^([a-zA-Z_]+):\s*(.*)$/` in agents.ts ... the rule's own documentation gives `/^a+b/` as its compliant example, so it fired on a pattern matching its own prescribed fix."
  cited: SonarQube rule S8786 documentation
  settled_by: none
  outcome: contradicted
  finding: ai-antipatterns.hallucination
  note: I did not open the rule documentation, so I cannot say whether it really gives `/^a+b/`. That doesn't matter, because the claim that decided the outcome (the regex has no super-linear backtracking, so the hit is a false positive) is settled by the regex itself. Run in the local Node runtime, time grows 4x each time n doubles, which is O(n^2). The pattern is not `/^a+b/`-shaped: its `\s*(.*)$` tail has overlapping quantifiers.

## Files examined
examined: [cli/src/commands/update.ts, cli/src/lib/agents.ts, cli/src/lib/catalog.ts, scripts/build-site.js]
not_examined: []
