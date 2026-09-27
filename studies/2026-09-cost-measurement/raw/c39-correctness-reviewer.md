<!-- c39 correctness-reviewer; verbatim final answer -->
I found no correctness bugs in this change. On the key question, the new regex order plus `trimEnd()` is not byte-for-byte identical to the old stripping, but every difference is only whitespace between attributes, which doesn't change how the HTML parses. On the real flag files and on the test fixture it gives exactly the old output.

**What I checked (build-site.js):** I ran the old and new transforms side by side on 11 attribute strings.
- **Same output:**
  - The test fixture ` role="img" aria-label="de" id="de"/` (the self-closing case) gives ` id="de"/` both ways.
  - The real root-tag shape ` xmlns=… viewBox="0 0 60 40" role="img" aria-label="Deutsch"` gives the same result.
  - Reversed attribute order, a lone `role="img"`, `/` and an empty string all match too.
- **Real inputs:** all 7 files in `docs-src/flags/*.svg` give the same output under both versions.
- **Whitespace-only differences:**
  - ` a="1" role="img"/` becomes ` a="1" /` (old: ` a="1"/`).
  - Whitespace already at the end, as in ` a="1" `, is now trimmed off.
  - A multi-line attribute block now ends in `""` where the old code left `"\n"`.
- **Not in any real input:** a substring such as `data-role="img" b="2"` was already broken under the old code (it produced `data- b="2"`). The new code produces `data-b="2"`, which is still broken, just differently. No flag file contains it, so I didn't file it.
- **Tests:** `node --test scripts/build-site.test.js` passes 18 of 18.

**CLI files:**
- `readStackManifest` no longer has a default for `catalogDir`. All 5 call sites already pass both arguments: `doctor.ts:16`, `list.ts:11`, `update.ts:12`, and `catalog.test.ts:28` and `:34`. The CLI only ships a `bin`, so nothing outside the package calls it.
- In `update.ts`, `listCatalogStacks` was imported but never used. The other files that import it are untouched.
- In `agents.ts`, nothing referred to the removed `path` import.
- I couldn't run a TypeScript type check because `cli/node_modules` isn't installed.

## Correctness findings: none

## Files examined
examined: [cli/src/commands/update.ts, cli/src/lib/agents.ts, cli/src/lib/catalog.ts, scripts/build-site.js]
not_examined: []
