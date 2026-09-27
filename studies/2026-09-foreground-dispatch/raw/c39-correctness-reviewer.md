<!-- c39 correctness-reviewer; verbatim final answer -->
I found one Nitpick-level correctness issue and nothing that breaks. Every committed page in the regenerated site is byte-identical to `docs/`.

- severity: Nitpick
  category: correctness.logic
  file: scripts/build-site.js
  line: 84
  title: When `role="img"` or `aria-label="..."` sits inside a longer attribute name, the next attribute now gets glued onto what's left and is renamed
  evidence: |
      const a = attrs
        .replace(/role="img"\s*/g, '')
        .replace(/aria-label="[^"]*"\s*/g, '')
        .trimEnd();
  impact: Neither pattern checks where an attribute name starts, so both the old and new code match inside names like `data-role="img"`. They leave different debris. I tested both regexes on the same input with node. For ` data-role="img" x="1"`, the old code gives ` data- x="1"`, which keeps `x`. The new code eats the whitespace after the match and gives ` data-x="1"`, which silently turns `x` into `data-x`. None of the 7 files in docs-src/flags/*.svg has such an attribute. Each opening tag is exactly `<svg xmlns=... viewBox="0 0 60 40" role="img" aria-label="...">`, so no current input triggers this. It only matters if a future flag SVG uses a `*-role` or `*-aria-label` attribute.
  remedy: Require a boundary before the name, but without bringing back a leading `\s*`. For example, use `/(^|\s)role="img"\s*/g` and replace with `'$1'`, and do the same for `aria-label`. That is still linear: each match starts at a single fixed character, not a run of whitespace.
  confidence: high
  overlap_hints: [tests.coverage]

What I checked:
- **Old vs new stripping:** I compared them with node on 13 inputs:
  - **Identical:** the attribute in the middle, at the start or at the end of the string, the whole string, next to another attribute with no whitespace, split across lines, and attributes ending in `/`.
  - **Whitespace-only differences:** runs of several spaces collapse differently. Attributes ending in whitespace or a newline lose it to `trimEnd()`, even when neither attribute is present. HTML ignores both.
  - **The one real difference:** the `data-role` case above.
- **Build and tests:**
  - `node --test scripts/build-site.test.js`: 18 of 18 pass.
  - I ran `buildAll` into /tmp/site39 and compared it with `cmp` against `docs/`: all 14 pages match exactly.
- **`readStackManifest`:** every caller passes a string first argument: doctor.ts:16, list.ts:11, update.ts:12 and catalog.test.ts:28,34. The CLI package only exposes a `bin` (`dist/cli.js`), so no outside code depends on the old default.
- **Removed imports:** `listCatalogStacks` no longer appears anywhere in update.ts, and there are no `path.` references left in agents.ts. Both removals are safe.
- **Not done:** I couldn't run `tsc`, because `cli/node_modules` isn't installed. The signature change is still valid TypeScript (two required parameters).

## Files examined
examined: [cli/src/commands/update.ts, cli/src/lib/agents.ts, cli/src/lib/catalog.ts, scripts/build-site.js]
not_examined: []
