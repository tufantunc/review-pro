<!-- c39 craft-reviewer; verbatim final answer -->
Neither change needs structural rework. There are two low-severity findings, both about how much text went into small edits.

- severity: Low
  category: craft.code-judo
  file: scripts/build-site.js
  line: 74
  title: the two-pass regex reorder needs a `trimEnd()` fix and a 9-line comment; one linear regex needs neither
  evidence: |
      // Literal first, quantifier after. A leading `\s*` makes the engine retry at
      // every position on a run of whitespace, which is quadratic; with the literal
      // first, both of these are linear.
      //
      // The trailing trim is `trimEnd()` and not `/\s+$/` on purpose: that regex is
      // the same quadratic shape this reorder exists to remove, measured at 500ms on
      // a 32k-space input where trimEnd is 0.0ms. The trim is needed at all because
      // reordering consumes the whitespace *after* a flagged attribute rather than
      // before it, so an attribute at the end of the string would leave one behind.
      const a = attrs
        .replace(/role="img"\s*/g, '')
        .replace(/aria-label="[^"]*"\s*/g, '')
        .trimEnd();
  impact: Moving the quantifier after the literal causes a side effect: whitespace left at the end of the string. `trimEnd()` is there to fix that side effect, and a benchmark paragraph explains why the fix isn't a regex. The result is 9 lines of comment for a 4-line expression. The comment also records a one-time benchmark (500ms / 0.0ms) that will go stale. Anyone who edits the attribute stripping later has to work through all of that reasoning first.
  remedy: |
    Put one single whitespace character before an alternation and drop the trim:
      const a = attrs.replace(/\s(?:role="img"|aria-label="[^"]*")/g, '');
    With no leading quantifier, each start position is checked in constant time, so this is linear. It removes whitespace *before* the attribute, as the original did, so nothing is left at the end and `trimEnd()` is not needed. I checked it with node: it gives the same output as both the old and new code for `role`/`aria-label` in first, middle, last and both-attributes positions, including the real flag header `viewBox="0 0 60 40" role="img" aria-label="Deutsch"`. It ran in 0ms on a 32k-space input, where the old `\s*role` took 964ms. The only difference is a run of several spaces before an attribute, which now leaves the extra spaces in place. That's harmless in an HTML tag, and none of the flags in docs-src/flags/*.svg have it. A one-line comment ("single `\s`, not `\s*`: stays linear") is enough.
  confidence: high
  overlap_hints: [performance.complexity, ai-antipatterns.over-engineering]

- severity: Low
  category: craft.abstraction
  file: cli/src/lib/catalog.ts
  line: 22
  title: the new docstring explains why a default was removed instead of saying what the function does
  evidence: |
    /** `catalogDir` has no default: every caller passes one, and a default sitting
     *  before a required parameter can never fire, so it read as available while
     *  being unreachable. */
    export function readStackManifest(
      catalogDir: string,
      stack: string,
    ): StackManifest | null {
  impact: The other docstrings in this file and its neighbours are one-line "what" notes (catalog.ts:8 `Bundled catalog dir (dist/../catalog), else repo stacks/ in dev.`, catalog.ts:34, repo.ts:24, plugin.ts:13). This one is a 3-line history note about a parameter default that no longer exists, and it is the function's only doc. Its reason, "every caller passes one", is also true of `listCatalogStacks` and `resolveReviewers`. Every call site passes `catalogDir` to those too (doctor.ts:9/15, add.ts:9, interactive.ts:15, list.ts:10/17, tests). Yet those two keep their `= resolveCatalogDir()` defaults with no comment, so the note reads as if this function is special when it isn't.
  remedy: Put the explanation in the commit message. Replace the docstring with a one-line "what" in the file's style, e.g. `/** Parsed <catalogDir>/<stack>/manifest.json, or null if absent. */`, or delete it. The fix is correct: the default before a required `stack` could never fire. The signature says that on its own.
  confidence: medium
  overlap_hints: [ai-antipatterns.over-engineering]

The other two files are fine:
- **`cli/src/commands/update.ts`**: removing the unused `listCatalogStacks` import is correct.
- **`cli/src/lib/agents.ts`**: removing the unused `path` import is correct. The file now starts with a blank line; delete it (nitpick).

## Files examined
examined: [cli/src/commands/update.ts, cli/src/lib/agents.ts, cli/src/lib/catalog.ts, scripts/build-site.js]
not_examined: []
