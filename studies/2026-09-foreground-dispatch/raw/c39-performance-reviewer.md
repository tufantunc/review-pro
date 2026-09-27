<!-- c39 performance-reviewer; verbatim final answer -->
## Performance findings

- severity: Nitpick
  category: performance.complexity
  file: scripts/build-site.js
  line: 79
  title: The comment's `/\s+$/` benchmark leaves out the input shape that makes it slow
  evidence: |
    // The trailing trim is `trimEnd()` and not `/\s+$/` on purpose: that regex is
    // the same quadratic shape this reorder exists to remove, measured at 500ms on
    // a 32k-space input where trimEnd is 0.0ms.
  impact: |
    The code is right. The comment is incomplete. I measured on Node v24.14.0, and `/\s+$/` is only slow when the whitespace run is followed by a non-space character:
    - `' '.repeat(32000)` (all spaces): 0.02ms. The match succeeds on the first try.
    - `' '.repeat(32000) + 'x'`: 483ms, and it roughly quadruples each time the input doubles (8k: 32ms, 16k: 119ms, 32k: 483ms, 64k: 1894ms).
    Someone who tries to reproduce the claim with a string of only spaces will see no problem and may decide the warning is wrong.
    All the other claims hold under measurement:
    - The old `\s*role="img"` and `\s*aria-label="[^"]*"` are quadratic on whitespace followed by a non-space (32k: 477ms and 494ms; 64k: about 1950ms).
    - The new `role="img"\s*` and `aria-label="[^"]*"\s*` stay linear, at no more than 0.31ms up to 64k. That includes the adversarial cases: an unclosed `aria-label="` with 64k characters after it, repeated unclosed labels, and repeated `role="img"` each followed by a run of spaces.
    - `trimEnd()` is linear, at 0.00 to 0.02ms.
    The patterns can't blow up, for these reasons. Each one starts with a literal, so every position that doesn't start with it fails in O(1). The trailing `\s*` has nothing after it, so it never backtracks. `[^"]*` stops at the next `"`, so a later `aria-label="` closes the earlier one instead of rescanning. Runtime impact is nil: `loadFlags` runs once per build over 7 trusted SVGs totalling 5,042 bytes (build-site.js:111).
  remedy: Change "on a 32k-space input" to something like "on 32k spaces followed by a non-space character". That names the case that actually triggers the slow behaviour.
  confidence: high
  overlap_hints: [craft]

No other performance issues:
- `cli/src/commands/update.ts` only drops an unused import.
- `cli/src/lib/agents.ts` only drops an unused `path` import.
- `cli/src/lib/catalog.ts` removes a parameter default that could never apply. `update.ts:8` already calls `resolveCatalogDir()` once, outside the loop, and passes the result in.

The unchanged outer `/<svg\b([^>]*)>/` is outside the diff, so I didn't assess it.

## Files examined
examined: [cli/src/commands/update.ts, cli/src/lib/agents.ts, cli/src/lib/catalog.ts, scripts/build-site.js]
not_examined: []
