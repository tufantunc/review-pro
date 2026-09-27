<!-- c39 api-contract-reviewer; verbatim final answer -->
I found one Low finding: the doc comment added to `readStackManifest` misstates what removing the default does. No caller breaks.

- severity: Low
  category: api-contract.breaking
  file: cli/src/lib/catalog.ts
  line: 22
  title: Doc comment says the removed `catalogDir` default could never fire, but it fired whenever a caller passed `undefined`, so removing it narrows the signature
  evidence: |
    /** `catalogDir` has no default: every caller passes one, and a default sitting
     *  before a required parameter can never fire, so it read as available while
     *  being unreachable. */
    export function readStackManifest(
    -  catalogDir: string = resolveCatalogDir(),
    +  catalogDir: string,
       stack: string,
  evidence_refs: [local Node v24.14.0 runtime: `function f(a = "DEFAULT", b) { return a + ":" + b }; f(undefined, "x")` printed `DEFAULT:x`]
  impact: In JS, a default parameter fires whenever its argument is `undefined`, wherever it sits in the list. So `readStackManifest(undefined, stack)` used to resolve the bundled catalog. The change is a real narrowing of what the exported function accepts, not removal of dead code, and the comment tells future maintainers the opposite. No caller breaks today. All four call sites pass a `catalogDir` value (cli/src/lib/doctor.ts:16, cli/src/commands/list.ts:11, cli/src/commands/update.ts:12, cli/tests/catalog.test.ts:28,34). cli/package.json has no `main` or `exports`, so there are no outside library users. Any future `undefined` caller would now get `path.join(undefined, …)` at runtime (a TypeError) instead of the bundled catalog.
  remedy: Keep the signature change and fix the comment. Something like "`catalogDir` has no default: every caller passes one. A leading default only fires on an explicit `undefined`, and no caller relies on that." Alternatively, move `catalogDir` after `stack` if an optional form is wanted.
  confidence: high
  overlap_hints: [craft.docs, correctness.logic]

The other changes are outside the API contract:
- **update.ts:** removes the unused `listCatalogStacks` import.
- **agents.ts:** removes the unused `path` import. Nothing in the file uses `path.`.
- **build-site.js:** reorders the regexes inside the private `loadFlags`, which only changes generated HTML attributes and touches no exported API.

## Premise verification
- premise: "A default sitting before a required parameter can never fire"
  cited: SonarQube rule S1788 (commit message, PR body, and the doc comment at cli/src/lib/catalog.ts:22-24)
  settled_by: local Node v24.14.0 runtime. This fits none of the allowed channels, and none was needed because no package is involved. I ran `node -e 'function f(a = "DEFAULT", b) { return a + ":" + b } console.log(f(undefined, "x"))'` and it printed `DEFAULT:x`. There is no local TypeScript: cli/node_modules is not installed and none is on the machine. So the claim that TS types this parameter as `string | undefined` for callers is not checked locally, but the runtime result alone settles the premise.
  outcome: contradicted
  finding: api-contract.breaking

## Files examined
examined: [/private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/99075928-604e-433b-bc82-95e9c121edc8/scratchpad/cost/work/c39/repo/cli/src/commands/update.ts, /private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/99075928-604e-433b-bc82-95e9c121edc8/scratchpad/cost/work/c39/repo/cli/src/lib/agents.ts, /private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/99075928-604e-433b-bc82-95e9c121edc8/scratchpad/cost/work/c39/repo/cli/src/lib/catalog.ts, /private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/99075928-604e-433b-bc82-95e9c121edc8/scratchpad/cost/work/c39/repo/scripts/build-site.js]
not_examined: []
