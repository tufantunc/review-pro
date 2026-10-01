<!-- microsoft__typescript-go@b970689 correctness-reviewer; verbatim final answer -->
## Correctness findings

- severity: High
  category: correctness.error-path
  file: internal/parser/reparser.go
  line: 120
  title: A JSDoc `@import` with no import clause makes the parser panic on a nil ImportClause
  evidence: |
    case ast.KindJSDocImportTag:
        importTag := tag.AsJSDocImportTag()
        importClause := importTag.ImportClause.Clone(&p.factory)
        importClause.Flags |= ast.NodeFlagsReparsed
  evidence_refs: [internal/parser/jsdoc.go:863, internal/parser/parser.go:2199-2204, internal/ast/ast.go:216]
  impact: |
    `parseImportTag` gets its clause from `tryParseImportClause`, and that returns nil unless an identifier, `*` or `{` comes next (parser.go:2199-2204). So `/** @import "./foo" */`, or a bare `/** @import */` that a user is part-way through typing, stores a nil `ImportClause`. Calling `Clone` on it runs `n.data.Clone(f)` (ast.go:216) with `n == nil`, which is a nil-pointer panic inside `ParseSourceFile`. This happens for every JS/JSX file with that comment (withJSDoc → reparseTags, jsdoc.go:59-60), so both the compiler and the language server crash while the user is still typing. The `@typedef` branch just above guards this with `if typeExpression == nil { break }`. The `@import` branch has no guard.
    I traced this in the source only. My attempt to run a small repro test was denied.
  remedy: Guard with `if importTag.ImportClause == nil { break }`, or build the declaration with a nil clause, which would need downstream support for a type-only side-effect import. Add an `@import "./foo"` test case.
  confidence: high
  overlap_hints: [tests.coverage]

- severity: High
  category: correctness.side-effect
  file: internal/parser/reparser.go
  line: 123
  title: The tag and the synthetic declaration share child nodes, and the binder's JSDoc parent pass re-points them at the JSDoc tag, whose case this PR removed from GetExternalModuleName (panics)
  evidence: |
    importClause := importTag.ImportClause.Clone(&p.factory)   // shallow: Name/NamedBindings shared
    ...
    importDeclaration := p.factory.NewJSImportDeclaration(importTag.Modifiers(), importClause, importTag.ModuleSpecifier, importTag.Attributes)
    ---- internal/binder/binder.go:757
    func (b *Binder) setJSDocParents(node *ast.Node) {
        for _, jsdoc := range node.JSDoc(b.file) {
            setParent(jsdoc, node)
            ast.SetParentInChildren(jsdoc)
    ---- internal/checker/checker.go:13800
    root := node.Parent.Parent.Parent // ImportDeclaration
    resolved := c.getExternalModuleMember(root, node, dontResolveAlias)
  evidence_refs: [internal/binder/binder.go:584, internal/binder/binder.go:1616, internal/binder/binder.go:1642-1652, internal/ast/utilities.go:886-895, internal/ast/ast.go:9565-9566, internal/ast/ast.go:4215-4216, internal/checker/checker.go:13809-13816, internal/ast/utilities.go:1678-1700, internal/checker/checker.go:14158-14177]
  impact: |
    `NamedBindings`, the import specifiers, `ModuleSpecifier` and `Attributes` belong to both the JSDocImportTag and the new JSImportDeclaration.
    1. The reparsed declaration is placed before its host statement (parser.go:478-482). The binder binds statements in order, except that function declarations go first (binder.go:1642-1652).
    2. When the host is not a function (a `const`/`let`/`var` statement, a class, an `import`, an `export default`, and so on), the JSImportDeclaration is bound first. That sets correct parents (binder.go:584).
    3. The host's `setJSDocParents` then runs `SetParentInChildren(jsdoc)`, which walks recursively (utilities.go:886-895) through the JSDocImportTag's children. It sets `NamedBindings.Parent` to the original clause and `ModuleSpecifier.Parent` to the JSDocImportTag.
    4. For `/** @import { Foo } from "./types" */ const x = 1;`, the ImportSpecifier's `Parent.Parent.Parent` is now the JSDocImportTag. `getTargetOfImportSpecifier` then calls `GetExternalModuleName(JSDocImportTag)`. This PR deleted that case, so the call hits `panic("Unhandled case in getExternalModuleName")`.
    5. `* as ns` fails the same way through `getModuleSpecifierFromNode` (checker.go:14159, panics at 14177).
    Every conformance test that reaches this path puts the tag above a `function`, which is bound first, so the parents get fixed afterwards and the baselines never hit the problem. The LS is affected too: the module specifier's parent is the tag, which `tryGetImportFromModuleSpecifier` and `getSymbolAtLocation` no longer accept.
    I traced this in the source only and could not run it (Bash was denied).
  remedy: Deep-clone the clause, specifier and attributes for the synthetic declaration, as `makeNewType` does for hosted tags. Alternatively, stop `setJSDocParents` from re-parenting nodes owned by a reparsed declaration, for example by skipping JSDocImportTag children, or by returning early like the JSExportAssignment/CommonJSExport branch at binder.go:1611-1612. Add tests with `@import` above a `const` and above a `class`.
  confidence: medium
  overlap_hints: [tests.coverage]

- severity: Medium
  category: correctness.side-effect
  file: internal/ast/utilities.go
  line: 2553
  title: An `@import` not attached to a top-level statement is no longer module-resolved, and the checker reports it as a misplaced import
  evidence: |
    -		} else if includeTypeSpaceImports && node.Kind == KindJSDocImportTag {
    -			moduleNameExpr := GetExternalModuleName(node)
    -			...
    -				if cb(node, moduleNameExpr) {
  evidence_refs: [internal/parser/parser.go:470-482, internal/parser/references.go:11-23, internal/checker/checker.go:4914-4925, internal/checker/grammarchecks.go:189-195, internal/binder/binder.go:443-444]
  impact: |
    `parseListIndex` adds reparsed nodes to whichever list is being parsed. So `@import` on a statement inside a function body or block, or on a class member, becomes a JSImportDeclaration in that nested list.
    - **Module resolution:** `collectModuleReferences` only looks at top-level statements. The JSDoc scan that used to find nested tags was removed here. The target module never gets into `file.Imports`, so it is never loaded or resolved.
    - **Checker:** `checkImportDeclaration` reports TS1473 ("An import declaration can only be used at the top level of a module") and stops.
    - **Binder:** a tag on a class member is bound with the class as container, which adds the alias to the class's members.
    Strada binds every `@import` at file scope (the file is the container), wherever the tag sits.
  remedy: Collect JSDoc imports into a separate list and add them to the SourceFile statements, as Strada does with `jsDocImports`. Otherwise keep the text-scan branch for JSImportDeclaration nodes that are not top level, and skip the grammar-context check for reparsed nodes.
  confidence: medium
  overlap_hints: [spec.requirements]

- severity: Medium
  category: correctness.logic
  file: internal/checker/checker.go
  line: 4933
  title: Valid `@import Foo, { I } from "./a"` now gets TS1363 because the synthetic node goes through TS type-only grammar checks
  evidence: |
    if importClause != nil && !c.checkGrammarImportClause(importClause.AsImportClause()) {
    ---- baseline
    +b.js(1,13): error TS1363: A type-only import can specify a default import or named bindings, but not both.
  evidence_refs: [testdata/baselines/reference/submoduleAccepted/conformance/importTag16.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=es2015).errors.txt.diff, internal/parser/reparser.go:122]
  impact: |
    Routing JSImportDeclaration through `checkImportDeclaration` applies TS `import type` rules to JSDoc syntax that Strada accepts:
    - A default plus named `@import` (importTag16) gets TS1363, a new error on code Strada accepts. With checkJs on, users see errors that tsc does not report.
    - importTag15 (es2015) also gets a TS2857 that Strada does not emit.
    - The .types baselines for importTag3 and importTag16 print `default` instead of `Foo`.
    The commit message calls the node "slightly stricter" on purpose. The TS1363 case, though, rejects valid code rather than just tightening a check.
  remedy: In `checkImportDeclaration`/`checkGrammarImportClause`, skip the TS1363 and TS2857 type-only checks when the node is KindJSImportDeclaration, to match Strada's `checkJSDocImportTag`.
  confidence: high
  overlap_hints: [spec.requirements]

- severity: Low
  category: correctness.logic
  file: internal/ast/ast.go
  line: 4056
  title: UpdateImportDeclaration and Clone always rebuild as KindImportDeclaration, dropping KindJSImportDeclaration
  evidence: |
    return updateNode(f.NewImportDeclaration(modifiers, importClause, moduleSpecifier, attributes), node.AsNode(), f.hooks)
    ...
    return cloneNode(f.AsNodeFactory().NewImportDeclaration(node.Modifiers(), node.ImportClause, node.ModuleSpecifier, node.Attributes), node.AsNode(), f.AsNodeFactory().hooks)
  evidence_refs: [internal/ast/ast.go:4069-4070, internal/ast/ast.go:4353-4370, internal/transformers/typeeraser.go:258-275, internal/transformers/transformer.go:74]
  impact: No emit problem today. The type eraser always runs first and removes the node, because the clause `IsTypeOnly` returns nil. But once any visitor or clone updates a JSImportDeclaration, it becomes a real `import`. The module transformers would then emit it instead of dropping it (their `case KindJSImportDeclaration: node = nil` would no longer match). The ExportAssignment code keeps `node.Kind` (ast.go:4355, 4369), so this is an inconsistency.
  remedy: Pass `node.Kind` through `newImportOrJSImportDeclaration` in both `UpdateImportDeclaration` and `Clone`.
  confidence: high
  overlap_hints: [craft.consistency]

## Files examined
examined: [internal/api/encoder/encoder.go, internal/ast/ast.go, internal/ast/kind.go, internal/ast/kind_stringer_generated.go, internal/ast/utilities.go, internal/checker/checker.go, internal/checker/grammarchecks.go, internal/ls/utilities.go, internal/parser/reparser.go, internal/printer/namegenerator.go, internal/printer/printer.go, internal/transformers/commonjsmodule.go, internal/transformers/esmodule.go, internal/transformers/esnext.go, internal/transformers/externalmoduleinfo.go, internal/transformers/importelision.go, internal/transformers/typeeraser.go, "testdata/baselines/reference/submodule/conformance/importTag15(module=esnext).errors.txt", testdata/baselines/reference/submodule/conformance/importTag4.errors.txt, "testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=es2015).errors.txt.diff", "testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=esnext).errors.txt.diff", testdata/baselines/reference/submoduleAccepted/conformance/importTag16.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag16.types.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag17.errors.txt.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag3.types.diff, testdata/baselines/reference/submoduleAccepted/conformance/importTag4.errors.txt.diff]
not_examined:
  - file: testdata/baselines/reference/submodule/conformance/importTag1.errors.txt
    reason: deleted baseline, diff not read (only seen in --stat)
  - file: "testdata/baselines/reference/submodule/conformance/importTag15(module=es2015).errors.txt"
    reason: only its submoduleAccepted .diff was read
  - file: testdata/baselines/reference/submodule/conformance/importTag16.errors.txt
    reason: only its submoduleAccepted .diff was read
  - file: testdata/baselines/reference/submodule/conformance/importTag16.types
    reason: only its submoduleAccepted .diff was read
  - file: testdata/baselines/reference/submodule/conformance/importTag17.errors.txt
    reason: only its submoduleAccepted .diff was read
  - file: testdata/baselines/reference/submodule/conformance/importTag18.errors.txt
    reason: deleted baseline, diff not read
  - file: testdata/baselines/reference/submodule/conformance/importTag19.errors.txt
    reason: deleted baseline, diff not read
  - file: testdata/baselines/reference/submodule/conformance/importTag2.errors.txt
    reason: deleted baseline, diff not read
  - file: testdata/baselines/reference/submodule/conformance/importTag20.errors.txt
    reason: deleted baseline, diff not read
  - file: testdata/baselines/reference/submodule/conformance/importTag3.errors.txt
    reason: deleted baseline, diff not read
  - file: testdata/baselines/reference/submodule/conformance/importTag3.types
    reason: only its submoduleAccepted .diff was read
  - file: testdata/baselines/reference/submodule/conformance/importTag5.errors.txt
    reason: deleted baseline, diff not read
  - file: testdata/baselines/reference/submodule/conformance/importTag6.errors.txt
    reason: deleted baseline, diff not read
  - file: testdata/baselines/reference/submodule/conformance/importTag7.errors.txt
    reason: deleted baseline, diff not read
  - file: testdata/baselines/reference/submodule/conformance/importTag8.errors.txt
    reason: deleted baseline, diff not read
  - file: testdata/baselines/reference/submodule/conformance/importTag9.errors.txt
    reason: deleted baseline, diff not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag1.errors.txt.diff
    reason: deleted diff, content not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag18.errors.txt.diff
    reason: deleted diff, content not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag19.errors.txt.diff
    reason: deleted diff, content not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag2.errors.txt.diff
    reason: deleted diff, content not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag20.errors.txt.diff
    reason: deleted diff, content not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag3.errors.txt.diff
    reason: deleted diff, content not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag5.errors.txt.diff
    reason: deleted diff, content not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag6.errors.txt.diff
    reason: deleted diff, content not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag7.errors.txt.diff
    reason: deleted diff, content not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag8.errors.txt.diff
    reason: deleted diff, content not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag9.errors.txt.diff
    reason: deleted diff, content not read

Notes on the triage leads:
- **Lead 4:** no finding. `IsExternalModuleIndicator` and checker.go:14330 behave like Strada, which also does not treat JSDoc imports as module indicators or ImportDeclarations there. emitresolver.go:148 only runs when import elision is on, and that excludes JS. The ls completions and ASI sites don't apply to a comment-spanning node.
- **Lead 5, importTag17:** the change comes from resolution-mode import attributes not being implemented anywhere in Corsa (the only hits are for triple-slash pragmas). That gap predates this PR, so I filed nothing for it.
- **importTag4:** now matches Strada.
- **Verification limits:** Bash was denied partway through the review, so nothing was run. The first finding (nil clause panic) is certain from the code. The second (parent re-pointing panic) is a static trace through the binder order that I could not execute, hence medium confidence.
