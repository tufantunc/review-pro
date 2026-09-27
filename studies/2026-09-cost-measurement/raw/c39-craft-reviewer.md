<!-- c39 craft-reviewer; verbatim final answer -->
Three craft findings. There was no repository-rules section in the prompt, so there is no rules block.

- severity: Medium
  category: craft.code-judo
  file: scripts/build-site.js
  line: 73
  title: A 9-line comment and a subtle regex dance guard a strip step that editing the source SVGs would remove
  evidence: |
    svg = svg.replace(/<svg\b([^>]*)>/, (_, attrs) => {
      // Literal first, quantifier after. A leading `\s*` makes the engine retry at
      // ...
      // the same quadratic shape this reorder exists to remove, measured at 500ms on
      // a 32k-space input where trimEnd is 0.0ms. The trim is needed at all because
      // reordering consumes the whitespace *after* a flagged attribute rather than
      // before it, so an attribute at the end of the string would leave one behind.
      const a = attrs
        .replace(/role="img"\s*/g, '')
        .replace(/aria-label="[^"]*"\s*/g, '')
        .trimEnd();
    -- docs-src/flags/en.svg:1 (same shape in all 7 flags):
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 40" role="img" aria-label="English">
  evidence_refs: [docs-src/flags/en.svg:1, scripts/build-site.test.js:87]
  impact: The build rewrites markup that the repo itself owns. `loadFlags` is the only thing that reads `docs-src/flags/*.svg`, and `docs/` has no `flags/` directory, so the SVGs are never published standalone. The fix adds a benchmark number, a whitespace-ordering rule and a `trimEnd` that has to stay put to a 137-line file whose other comments are one line each. Anyone who later edits this regex has to understand the ReDoS reasoning and the trailing-space rule first. That is PR-description material sitting in code, and it goes stale as soon as the regex changes again.
  remedy: Remove `role="img"` and `aria-label` from the 7 source SVGs and add `aria-hidden="true" focusable="false"` there. Then delete the whole `<svg\b...>` replace callback, its comment and the `trimEnd`. `loadFlags` shrinks to reading the file and stripping the XML prolog. Update the "realistic flags" fixture in `scripts/build-site.test.js:87` to match. If you keep the transform anyway, cut the comment to one line, such as "literal-first patterns avoid quadratic backtracking; trimEnd drops the trailing gap", and put the measurement in the commit message.
  confidence: medium
  overlap_hints: [a11y.aria, performance.complexity]

- severity: Low
  category: craft.abstraction
  file: cli/src/lib/catalog.ts
  line: 22
  title: The "every caller passes catalogDir" rule is applied to one of three sibling functions, and the removal is justified by a history comment
  evidence: |
    export function listCatalogStacks(catalogDir: string = resolveCatalogDir()): string[] {
    ...
    /** `catalogDir` has no default: every caller passes one, and a default sitting
     *  before a required parameter can never fire, so it read as available while
     *  being unreachable. */
    export function readStackManifest(
      catalogDir: string,
    ...
    export function resolveReviewers(catalogDir: string = resolveCatalogDir()): string[] {
  evidence_refs: [cli/src/commands/add.ts:9, cli/src/commands/list.ts:10, cli/src/commands/interactive.ts:15, cli/src/lib/doctor.ts:15, cli/src/commands/doctor.ts:9]
  impact: Every production and test caller of `listCatalogStacks` and `resolveReviewers` also passes `catalogDir` explicitly, so those two defaults are unused too. After this change the module has two conventions: sometimes the catalog dir is resolved inside the signature, sometimes the caller must pass it. The new docblock describes a parameter default that no longer exists. That is a changelog entry, and it will confuse readers once nobody remembers the old signature. Nearby docblocks like `resolveCatalogDir` and `resolveReviewers` describe what the function does, not its history.
  remedy: Make the three signatures consistent. Remove the `= resolveCatalogDir()` defaults from `listCatalogStacks` and `resolveReviewers` too, since callers already resolve the dir once at the command layer. Then delete the three-line docblock, or replace it with a one-line description of what the function does, matching `resolveReviewers`.
  confidence: high
  overlap_hints: [api-contract.signature]

- severity: Nitpick
  category: craft.abstraction
  file: cli/src/lib/agents.ts
  line: 1
  title: Removing the import left a blank first line
  evidence: |
    -import path from "node:path";
     
     export interface CanonicalAgent {
  impact: This is left over from the import removal. No other file in `cli/src/lib/` starts with a blank line.
  remedy: Delete line 1 so the file starts at `export interface CanonicalAgent`.
  confidence: high
  overlap_hints: []

## Files examined
examined: [cli/src/commands/update.ts, cli/src/lib/agents.ts, cli/src/lib/catalog.ts, scripts/build-site.js]
not_examined: []
