<!-- microsoft__typescript-go@b970689 tests-reviewer; verbatim final answer -->
- severity: High
  category: tests.coverage
  file: internal/parser/reparser.go
  line: 120
  title: The new @import reparse branch has no test for a tag without an import clause, and that input crashes the parser
  evidence: |
    case ast.KindJSDocImportTag:
        importTag := tag.AsJSDocImportTag()
        importClause := importTag.ImportClause.Clone(&p.factory)
        importClause.Flags |= ast.NodeFlagsReparsed
  evidence_refs: [internal/parser/parser.go:2199, internal/parser/jsdoc.go:863, internal/ast/ast.go:216, testdata/baselines/reference/submoduleAccepted/conformance/importTag10.errors.txt.diff:3, testdata/baselines/reference/submoduleAccepted/conformance/importTag13.errors.txt.diff:3]
  impact: |
    `tryParseImportClause` returns nil when the tag has no identifier, `*` or `{` (parser.go:2199-2204). So `/** @import "./mod" */` placed before a statement gives a nil `ImportClause`. `Node.Clone` then runs `n.data.Clone(f)` on a nil node, which is a nil-pointer panic. The malformed-tag tests importTag10 to importTag14 never reach this branch. Each test file holds only a JSDoc comment with no statement after it, so no host exists for `reparseTags`. Their baselines stay `<no content>` against Strada's parse errors, and this PR did not change them. No other test in the change has an `@import` without a clause.
  remedy: |
    Add a local compiler test (testdata/tests/cases/compiler/) with checkJs and allowJs. It should contain `/** @import "./a" */` followed by `export function f() {}`, and a malformed `/** @import */` or `/** @import foo */` followed by a statement. The error and types baselines must be produced without a panic. Give the reparser a nil guard for `ImportClause` (side-effect-only form); that is handed to correctness.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: High
  category: tests.coverage
  file: internal/parser/parser.go
  line: 478
  title: No test covers @import on a nested statement or class member, where the synthetic import lands in the wrong list and its module is no longer collected
  evidence: |
    elt := parseElement(p, i)
    if len(p.reparseList) > 0 {
        list = append(list, p.reparseList...)
        p.reparseList = nil
    }
  evidence_refs: [internal/parser/parser.go:1062, internal/parser/parser.go:1633, internal/parser/references.go:12, internal/ast/utilities.go:2553]
  impact: |
    `parseListIndex`/`parseList` also parses block statements (parser.go:1062) and class members (parser.go:1633). An `@import` in a JSDoc on a statement in a function body therefore becomes a block-level `KindJSImportDeclaration`. On a class method it becomes an entry in the class member list. Strada treats every `@import` as file-scoped. The PR also removed the `KindJSDocImportTag` branch from `ForEachDynamicImportOrRequireCall`. `collectExternalModuleReferences` only walks `file.Statements` (references.go:12), so the module specifier of a nested `@import` is no longer added to `file.Imports`. Every changed importTag baseline puts `@import` in a top-level comment, so nothing checks nested placement.
  remedy: |
    Add a local test with an `@import { Foo } from "./types"` in a JSDoc on a statement inside a function body, used by an `@param {Foo}` elsewhere in the file. Add a second case with the `@import` in the JSDoc of a class method. Assert that the error baseline has no TS2304 or TS1232 (non-top-level import) error and that the .types baseline resolves `Foo`. Add a find-references or go-to-definition fourslash case if module resolution for nested tags matters to the language service.
  confidence: medium
  overlap_hints: [correctness.logic, correctness.side-effects]

- severity: Medium
  category: tests.assertion
  file: testdata/baselines/reference/submodule/conformance/importTag16.types
  line: 16
  title: The accepted .types baselines for importTag3 and importTag16 now print `default` instead of `Foo` for a default-imported type
  evidence: |
    ->foo : (a: Foo, b: I) => void
    ->a : Foo
    +>foo : (a: default, b: I) => void
    +>a : default
  evidence_refs: [testdata/baselines/reference/submodule/conformance/importTag3.types:18, testdata/baselines/reference/submoduleAccepted/conformance/importTag3.types.diff:1, testdata/baselines/reference/submoduleAccepted/conformance/importTag16.types.diff:1, internal/testrunner/compiler_runner.go:346, internal/compiler/program.go:164]
  impact: |
    Before this PR, importTag3.types and importTag16.types matched Strada. This PR creates new .types.diff files, so it adds a type-printing regression for `@import Foo from` (visible in hover, quick info and error messages) and stores it as the reference. Every test with a .js file goes to submoduleAccepted automatically: `containsUnsupportedOptions` is true because `UnsupportedExtensions` includes all JS extensions. So nothing prompts anyone to review the diff, and the baseline test now passes while asserting the wrong type name.
  remedy: |
    Treat the new importTag3.types.diff and importTag16.types.diff as a failing expectation. Name the alias symbol created for the reparsed default import after its local name, not `default`, so that both .diff files go away. If the regression is deferred, keep the diff but record it as a known gap (TODO or issue link) in the PR, not as silently accepted output.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.assertion
  file: testdata/baselines/reference/submodule/conformance/importTag16.errors.txt
  line: 1
  title: importTag16 now accepts a false-positive TS1363 on `@import Foo, { I }`, which Strada does not report
  evidence: |
    +b.js(1,13): error TS1363: A type-only import can specify a default import or named bindings, but not both.
  evidence_refs: [testdata/baselines/reference/submoduleAccepted/conformance/importTag16.errors.txt.diff:6, internal/checker/grammarchecks.go:2120, internal/parser/reparser.go:122]
  impact: |
    Strada's baseline for this test is `<no content>` (the old side of the .diff). The reparser forces `IsTypeOnly = true`, and `checkGrammarImportClause` then rejects the mixed default-plus-named form, which is legal in JSDoc. The accepted baseline swaps one wrong result (TS2304) for another (TS1363), and the change is recorded as accepted. Users writing valid `@import A, { B }` get a new error.
  remedy: |
    Do not accept this baseline. Skip `checkGrammarImportClause`'s TS1363 check for `KindJSImportDeclaration` (handed to correctness) until importTag16.errors.txt.diff shows only the header lines, as for importTag1 and the others. After that fix, the diff for this test should be deleted.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.assertion
  file: testdata/baselines/reference/submodule/conformance/importTag15(module=es2015).errors.txt
  line: 2
  title: importTag15 (es2015) accepts duplicate diagnostics, TS2823 plus TS2857, where Strada reports only TS2823
  evidence: |
     1.js(1,30): error TS2823: Import attributes are only supported when the '--module' option is set to 'esnext', 'nodenext', or 'preserve'.
    +1.js(1,30): error TS2857: Import attributes cannot be used with type-only imports or exports.
  evidence_refs: [testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=es2015).errors.txt.diff:5, internal/checker/checker.go:5067, internal/checker/checker.go:5069]
  impact: |
    In `checkImportAttributes`, the TS2823 branch (checker.go:5067) does not return, so the `isTypeOnly` branch (5069) also fires. Strada returns early. The esnext variant now matches Strada and its diff was deleted, but the es2015 diff was rewritten to accept the extra error rather than flag it. The test now fixes the double reporting in place.
  remedy: |
    Return after the module-kind diagnostic in `checkImportAttributes`, matching Strada (handed to correctness). Regenerate so that importTag15(module=es2015).errors.txt.diff is deleted.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.assertion
  file: testdata/baselines/reference/submodule/conformance/importTag17.errors.txt
  line: 1
  title: The rewritten importTag17 baseline still ignores resolution-mode on @import, but the new diff reads like progress
  evidence: |
    +/a.js(1,15): error TS2305: Module '"/node_modules/@types/foo/index"' has no exported member 'Import'.
    +/a.js(12,15): error TS2749: 'Require' refers to a value, but is being used as a type here. Did you mean 'typeof Require'?
  evidence_refs: [testdata/baselines/reference/submoduleAccepted/conformance/importTag17.errors.txt.diff:3, testdata/baselines/reference/submoduleAccepted/conformance/importTag17.types.diff:7]
  impact: |
    Strada reports TS2322 against `"module"` and `"script"`. Its import-mode and require-mode imports resolve to different declarations. The Go output resolves both through `@types/foo/index`, so `'resolution-mode': 'import'` is not honored. The .types.diff still shows `() => Import` against `() => "module"`. The regenerated diff replaces "cannot find name" with other wrong errors, which can look like a partial fix during review.
  remedy: |
    Keep the diff, but mark it in the PR as a known gap: resolution-mode for reparsed JSDoc imports is not wired through module resolution. Or pass the attributes' resolution-mode override into the `file.Imports` resolution for `KindJSImportDeclaration` and re-baseline.
  confidence: medium
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.coverage
  file: internal/transformers/commonjsmodule.go
  line: 392
  title: The new emit-path branches for KindJSImportDeclaration have no JS emit baseline
  evidence: |
    case ast.KindJSImportDeclaration:
        node = nil
  evidence_refs: [internal/transformers/esmodule.go:405, internal/transformers/externalmoduleinfo.go:50, internal/transformers/importelision.go:31, internal/transformers/typeeraser.go:258, internal/testrunner/compiler_runner.go:351]
  impact: |
    No importTag test produces a `.js` output baseline. The runner's `verifyJavaScriptOutput` exists, but none of the changed or existing importTag baselines is a `.js` file. So nothing checks that a JS file with `@import` emits no runtime `import` or `require`. The risk is concrete: `externalmoduleinfo.go` now counts `KindJSImportDeclaration` as an external import and calls `getImportNeedsImportStarHelper`. Under CommonJS, a type-only `@import * as ns` or a default import could trigger `__importStar`/`__importDefault` helpers or an `__esModule` marker. The PR description's "no runtime import emitted" claim is untested. The declaration-emit case does not apply here: `internal/transformers` has no declaration transformer at this commit.
  remedy: |
    Add a local compiler test with allowJs, checkJs, outDir and module=commonjs, plus a second variant with module=esnext (no noEmit). Include `@import { A } from "./a"`, `@import * as ns from "./a"` and `@import D from "./a"` in a JS file. The .js baseline must show no `require("./a")`/`import`, no `__importStar`/`__importDefault` helpers, and no extra `__esModule` define unless the file has other ESM syntax.
  confidence: medium
  overlap_hints: [correctness.side-effects]

## Files examined
examined: [internal/api/encoder/encoder.go, internal/ast/ast.go, internal/ast/kind.go, internal/ast/kind_stringer_generated.go, internal/ast/utilities.go, internal/checker/checker.go, internal/checker/grammarchecks.go, internal/ls/utilities.go, internal/parser/reparser.go, internal/printer/namegenerator.go, internal/printer/printer.go, internal/transformers/commonjsmodule.go, internal/transformers/esmodule.go, internal/transformers/esnext.go, internal/transformers/externalmoduleinfo.go, internal/transformers/importelision.go, internal/transformers/typeeraser.go, "testdata/baselines/reference/submodule/conformance/importTag15(module=es2015).errors.txt", "testdata/baselines/reference/submodule/conformance/importTag15(module=esnext).errors.txt", testdata/baselines/reference/submodule/conformance/importTag16.errors.txt, testdata/baselines/reference/submodule/conformance/importTag16.types, testdata/baselines/reference/submodule/conformance/importTag17.errors.txt, testdata/baselines/reference/submodule/conformance/importTag3.types, testdata/baselines/reference/submodule/conformance/importTag4.errors.txt, testdata/baselines/reference/submoduleAccepted/conformance/importTag1.errors.txt.diff, "testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=es2015).errors.txt.diff", "testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=esnext).errors.txt.diff", testdata/baselines/reference/submoduleAccepted/conformance/importTag16.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag16.types.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag17.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag18.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag19.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag2.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag20.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag3.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag3.types.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag4.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag5.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag6.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag7.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag8.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag9.errors.txt.diff]
not_examined:
  - file: testdata/baselines/reference/submodule/conformance/importTag1.errors.txt
    reason: deleted file; its diff was not read, only the paired deleted .diff
  - file: testdata/baselines/reference/submodule/conformance/importTag18.errors.txt
    reason: deleted file; its diff was not read, only the paired deleted .diff
  - file: testdata/baselines/reference/submodule/conformance/importTag19.errors.txt
    reason: deleted file; its diff was not read, only the paired deleted .diff
  - file: testdata/baselines/reference/submodule/conformance/importTag2.errors.txt
    reason: deleted file; its diff was not read, only the paired deleted .diff
  - file: testdata/baselines/reference/submodule/conformance/importTag20.errors.txt
    reason: deleted file; its diff was not read, only the paired deleted .diff
  - file: testdata/baselines/reference/submodule/conformance/importTag3.errors.txt
    reason: deleted file; its diff was not read, only the paired deleted .diff
  - file: testdata/baselines/reference/submodule/conformance/importTag5.errors.txt
    reason: deleted file; its diff was not read, only the paired deleted .diff
  - file: testdata/baselines/reference/submodule/conformance/importTag6.errors.txt
    reason: deleted file; its diff was not read, only the paired deleted .diff
  - file: testdata/baselines/reference/submodule/conformance/importTag7.errors.txt
    reason: deleted file; its diff was not read, only the paired deleted .diff
  - file: testdata/baselines/reference/submodule/conformance/importTag8.errors.txt
    reason: deleted file; its diff was not read, only the paired deleted .diff
  - file: testdata/baselines/reference/submodule/conformance/importTag9.errors.txt
    reason: deleted file; its diff was not read, only the paired deleted .diff

Notes for synthesis:
- **Checkout gaps:** `_submodules/TypeScript` is not checked out, so I could not list the Strada test sources in `tests/cases/conformance/jsdoc/`. The local baselines exist for importTag1–20 and importTag22; there are none for 21, 23 or 24. None of these tests produces a `.js` emit baseline, which fits the tests using `@noEmit`.
- **Tests now matching Strada:** importTag1, 2, 3 (errors), 4 (duplicate-identifier errors), 5–9, 18–20 and 15 (esnext) now match Strada, so their `.diff` files were deleted.
- **Not regenerated:** importTag10–14 (malformed tags) and importTag22 did not change.
