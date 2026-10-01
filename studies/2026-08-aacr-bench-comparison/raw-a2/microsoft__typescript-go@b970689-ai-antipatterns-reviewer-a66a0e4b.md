<!-- microsoft__typescript-go@b970689 ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: Medium
  category: ai-antipatterns.ignored-convention
  file: internal/ast/ast.go
  line: 4056
  title: The JSImportDeclaration factory copies only half of the JSExportAssignment precedent, so Update and Clone turn a JS import back into a plain ImportDeclaration
  evidence: |
    func (f *NodeFactory) newImportOrJSImportDeclaration(kind Kind, ...) *Node {   // added, :4037
    ...
    func (f *NodeFactory) UpdateImportDeclaration(node *ImportDeclaration, ...) *Node {
        if modifiers != node.modifiers || importClause != node.ImportClause || ... {
            return updateNode(f.NewImportDeclaration(modifiers, importClause, moduleSpecifier, attributes), node.AsNode(), f.hooks)
    ...
    func (node *ImportDeclaration) Clone(f NodeFactoryCoercible) *Node {
        return cloneNode(f.AsNodeFactory().NewImportDeclaration(node.Modifiers(), ...), ...)   // :4070
  evidence_refs: [internal/ast/ast.go:4355, internal/ast/ast.go:4369, internal/transformers/importelision.go:41, internal/transformers/typeeraser.go:269, internal/transformers/esmodule.go:42, internal/transformers/commonjsmodule.go:66]
  impact: |
    Assumed: adding a `newXOrJSX(kind, ...)` helper is all a JS-synthetic kind needs. In the repo, the precedent this copies also makes Update and Clone keep the node's kind. `UpdateExportAssignment` calls `f.newExportOrJSExportAssignment(node.Kind, ...)` (ast.go:4355), and `ExportAssignment.Clone` does the same (ast.go:4369).
    This PR sends `KindJSImportDeclaration` into two callers of `UpdateImportDeclaration`: importelision.go:41 and typeeraser.go:269. When the import clause changes, the node that comes back is a `KindImportDeclaration`. That node no longer matches the new `case ast.KindJSImportDeclaration: node = nil` in esmodule.go and commonjsmodule.go, so it would be printed as a real `import` statement in the JS output. `Clone`, and the `VisitEachChild` that goes through `UpdateImportDeclaration`, lose the kind in the same way.
    Today typeeraser drops the clause because `IsTypeOnly = true`, which hides the problem. That makes the damage conditional, not certain.
  remedy: Follow the ExportAssignment pattern. Have `UpdateImportDeclaration` call `f.newImportOrJSImportDeclaration(node.Kind, ...)`, and have `ImportDeclaration.Clone` call `f.AsNodeFactory().newImportOrJSImportDeclaration(node.Kind, ...)`.
  confidence: medium
  overlap_hints: [correctness.side-effect, craft.abstraction]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: internal/ast/ast.go
  line: 4080
  title: No IsJSImportDeclaration or IsAnyImportDeclaration predicate and no struct doc note, unlike the ExportAssignment precedent
  evidence: |
    func IsImportDeclaration(node *Node) bool {
        return node.Kind == KindImportDeclaration
    }
  evidence_refs: [internal/ast/ast.go:4327, internal/ast/ast.go:4380, internal/ast/ast.go:4384]
  impact: |
    The precedent for a JS-synthetic kind that shares a data struct includes three things:
    - a struct doc line: "If Kind is KindJSExportAssignment, it is a synthetic declaration for `module.exports =`" (ast.go:4327)
    - `IsJSExportAssignment` (ast.go:4380)
    - `IsAnyExportAssignment` (ast.go:4384)
    This PR adds none of them. Instead it widens about 25 `case`/`||` sites by hand across 15 files. Every existing caller of `ast.IsImportDeclaration` now silently excludes `@import` declarations. With no "any" predicate, the next call site is likely to miss the new kind too.
  remedy: Add `IsJSImportDeclaration` and `IsAnyImportDeclaration`, and add a comment on `ImportDeclaration` saying that `KindJSImportDeclaration` is the reparsed `@import`. Then check the `IsImportDeclaration` callers and switch the ones that should include it.
  confidence: medium
  overlap_hints: [craft.canonical-helper, dry.canonical-helper, correctness.side-effect]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: internal/parser/reparser.go
  line: 123
  title: importTag.Modifiers() is always nil because JSDocImportTag has no ModifiersBase
  evidence: |
    importDeclaration := p.factory.NewJSImportDeclaration(importTag.Modifiers(), importClause, importTag.ModuleSpecifier, importTag.Attributes)
  evidence_refs: [internal/ast/ast.go:9541, internal/ast/ast.go:1591, internal/ast/ast.go:4350]
  impact: |
    Assumed: a JSDoc import tag carries modifiers to pass on. In the repo, `JSDocImportTag` has only `JSDocTagBase`, `ImportClause`, `ModuleSpecifier` and `Attributes` (ast.go:9541-9546). The call therefore resolves to `NodeDefault.Modifiers()`, which is `return nil` (ast.go:1591). It looks meaningful but always passes nil. The precedent `NewJSExportAssignment` passes `nil /*modifiers*/` explicitly (ast.go:4350).
  remedy: Pass `nil /*modifiers*/`, or drop the parameter from `NewJSImportDeclaration` as `NewJSExportAssignment` does.
  confidence: high
  overlap_hints: [craft.clarity]

- severity: Nitpick
  category: ai-antipatterns.ignored-convention
  file: internal/ast/ast.go
  line: 1673
  title: The AnyValidImportOrReExport alias comment still names JSDocImportTag after its handling was removed
  evidence: |
    AnyValidImportOrReExport    = Node // (ImportDeclaration | ExportDeclaration | JSDocImportTag) & { moduleSpecifier: StringLiteral } | ...
  impact: The PR removed `KindJSDocImportTag` from `ModuleSpecifier`, `GetExternalModuleName`, `IsDefaultImport` and `ForEachDynamicImportOrRequireCall`, and updated the `IsDefaultImport` comment (utilities.go:2365). This union comment was not updated and now describes a shape that no longer occurs. The line is not in the diff, but the change is what made it stale.
  remedy: Replace `JSDocImportTag` with `JSImportDeclaration` in the comment.
  confidence: high
  overlap_hints: [craft.clarity]

I checked the generated stringer against kind.go and found nothing to report. `KindJSImportDeclaration` is 348, between `KindCommonJSExport` (347) and `KindNotEmittedStatement` (349). The offsets 6659/6682/6712/6735/6767/6776 match the name lengths 23/23/30/23/32/9. Every symbol the change references exists: `NewJSImportDeclaration`, `AsJSDocImportTag`, `Node.Clone(NodeFactoryCoercible)`, and `p.factory` as an `ast.NodeFactory` value. Bash was denied, so I could not build the change or grep for callers. I checked everything with Read instead, which is why the caller impact in finding 2 has medium confidence.

## Files examined
examined: [internal/api/encoder/encoder.go, internal/ast/ast.go, internal/ast/kind.go, internal/ast/kind_stringer_generated.go, internal/ast/utilities.go, internal/checker/checker.go, internal/checker/grammarchecks.go, internal/ls/utilities.go, internal/parser/reparser.go, internal/printer/namegenerator.go, internal/printer/printer.go, internal/transformers/commonjsmodule.go, internal/transformers/esmodule.go, internal/transformers/esnext.go, internal/transformers/externalmoduleinfo.go, internal/transformers/importelision.go, internal/transformers/typeeraser.go, "testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=es2015).errors.txt.diff", testdata/baselines/reference/submoduleAccepted/conformance/importTag16.types.diff]
not_examined:
  - file: testdata/baselines/reference/submodule/conformance/importTag1.errors.txt
    reason: generated baseline, seen only in --stat (Bash denied after that)
  - file: "testdata/baselines/reference/submodule/conformance/importTag15(module=es2015).errors.txt"
    reason: generated baseline, seen only in --stat
  - file: "testdata/baselines/reference/submodule/conformance/importTag15(module=esnext).errors.txt"
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag16.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag16.types
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag17.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag18.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag19.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag2.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag20.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag3.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag3.types
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag4.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag5.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag6.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag7.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag8.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submodule/conformance/importTag9.errors.txt
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag1.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
  - file: "testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=esnext).errors.txt.diff"
    reason: generated baseline (deleted), seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag16.errors.txt.diff
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag17.errors.txt.diff
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag18.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag19.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag2.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag20.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag3.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag3.types.diff
    reason: generated baseline, seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag4.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag5.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag6.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag7.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag8.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag9.errors.txt.diff
    reason: generated baseline (deleted), seen only in --stat
