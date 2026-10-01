<!-- microsoft__typescript-go@b970689 craft-reviewer; verbatim final answer -->
- severity: Medium
  category: craft.abstraction
  file: internal/ast/ast.go
  line: 4056
  title: UpdateImportDeclaration and Clone lose KindJSImportDeclaration, unlike the newExportOrJSExportAssignment pattern this change copies
  evidence: |
    func (f *NodeFactory) UpdateImportDeclaration(node *ImportDeclaration, ...) *Node {
    	if modifiers != node.modifiers || importClause != node.ImportClause || ... {
    		return updateNode(f.NewImportDeclaration(modifiers, importClause, moduleSpecifier, attributes), node.AsNode(), f.hooks)
    	}
    ...
    func (node *ImportDeclaration) Clone(f NodeFactoryCoercible) *Node {
    	return cloneNode(f.AsNodeFactory().NewImportDeclaration(node.Modifiers(), node.ImportClause, node.ModuleSpecifier, node.Attributes), ...)
    // sibling (ast.go:4355, 4369):
    	return updateNode(f.newExportOrJSExportAssignment(node.Kind, modifiers, node.IsExportEquals, expression), ...)
    	return cloneNode(f.AsNodeFactory().newExportOrJSExportAssignment(node.Kind, node.Modifiers(), ...), ...)
  impact: The change adds `newImportOrJSImportDeclaration(kind, ...)` but only applies it to the two New* constructors. Any `VisitEachChild` or `Clone` of a JSImportDeclaration quietly turns it into a plain `KindImportDeclaration`. typeeraser.go:268 and importelision.go:38 both call `UpdateImportDeclaration` on the JS kind. If one of those rewrites a JS import, it reaches the module transformers as a real import: the `case ast.KindJSImportDeclaration: node = nil` guards in esmodule.go:42 and commonjsmodule.go:66 no longer match, and it is emitted like a normal import. So the new kind only holds until the first tree rewrite.
  remedy: Do what ExportAssignment does. Call `f.newImportOrJSImportDeclaration(node.Kind, ...)` in both `UpdateImportDeclaration` and `ImportDeclaration.Clone`, so the kind is kept by construction and no caller has to pick the right constructor.
  confidence: high
  evidence_refs: [internal/ast/ast.go:4070, internal/ast/ast.go:4355, internal/ast/ast.go:4369, internal/transformers/typeeraser.go:268, internal/transformers/importelision.go:38]
  overlap_hints: [correctness]

- severity: Medium
  category: craft.code-judo
  file: internal/ast/ast.go
  line: 4080
  title: About 20 case labels and boolean chains list both kinds by hand instead of using a shared predicate, and some IsImportDeclaration callers were not audited
  evidence: |
    // grammarchecks.go:550
    } else if (node.Kind == ast.KindImportDeclaration || node.Kind == ast.KindJSImportDeclaration || node.Kind == ast.KindImportEqualsDeclaration) && ...
    // checker.go:29386
    ((parent.Kind == ast.KindImportDeclaration || parent.Kind == ast.KindJSImportDeclaration || parent.Kind == ast.KindExportDeclaration) && ...
    // unchanged, single-kind:
    func IsImportDeclaration(node *Node) bool { return node.Kind == KindImportDeclaration }
    // emitresolver.go:145-150 — sibling explicitly skipped, JS import not:
    if ast.IsJSExportAssignment(n) { return false }
    if ast.IsImportDeclaration(n) { return false }
  impact: The sibling kinds each have an either-kind predicate (`IsAnyExportAssignment`, `IsTypeOrJSTypeAliasDeclaration`, 10 call sites between them). This change adds none. Every site had to be found by grepping for the kind. The five `ast.IsImportDeclaration(...)` callers were left as they were with no reason given: emitresolver.go:148, checker.go:14330 (resolveESModuleSymbol), utilities.go:1492 (IsExternalModuleIndicator), completions.go:2279, and the ASI kind list at ls/utilities.go:198. That leaves some real inconsistencies. For example, emitresolver skips JSExportAssignment and ImportDeclaration during MarkLinkedReferencesRecursively, but it now walks into JSImportDeclaration. Each future import-related change will have to track down these sites again.
  remedy: Add `IsAnyImportDeclaration(node) bool` (or `IsImportOrJSImportDeclaration`) next to `IsImportDeclaration`, following `IsAnyExportAssignment`. Use it in the boolean-chain sites (grammarchecks.go:550, grammarchecks.go:2025, checker.go:29386). Go through the five remaining `IsImportDeclaration` callers and switch each to the new predicate, or add a one-line comment saying why the JS kind is excluded. emitresolver.go:148 should almost certainly switch.
  confidence: high
  evidence_refs: [internal/checker/grammarchecks.go:550, internal/checker/grammarchecks.go:2025, internal/checker/checker.go:29386, internal/checker/emitresolver.go:148, internal/checker/checker.go:14330, internal/ast/utilities.go:1492, internal/ls/completions.go:2279, internal/ls/utilities.go:198, internal/ast/ast.go:4384]
  overlap_hints: [dry.duplication, correctness]

- severity: Medium
  category: craft.spaghetti
  file: internal/transformers/typeeraser.go
  line: 258
  title: JS-import elision relies on the IsTypeOnly path in the type eraser, which leaves the edits in importelision, esnext, externalmoduleinfo and the module transformers unreachable and in conflict with each other
  evidence: |
    // typeeraser.go:98 — sibling is elided explicitly:
    case ast.KindJSExportAssignment:
    	// reparsed commonjs are elided
    	return nil
    // typeeraser.go:258 — new kind goes through the generic path:
    case ast.KindImportDeclaration, ast.KindJSImportDeclaration:
    	...
    	importClause := tx.visitor.VisitNode(n.ImportClause)   // KindImportClause: if n.IsTypeOnly { return nil }
    // externalmoduleinfo.go:50 — treats it as a real import:
    case ast.KindImportDeclaration, ast.KindJSImportDeclaration:
    	// @import versions of above
    	c.addExternalImport(node)
    // commonjsmodule.go:66 / esmodule.go:42 — treats it as nothing:
    case ast.KindJSImportDeclaration:
    	node = nil
  impact: transformer.go:74 always runs the type eraser first. Every reparsed `@import` has a type-only clause, so the eraser removes it before any later pass sees it. That makes the JS-kind labels in importelision.go:31/169, esnext.go:371, externalmoduleinfo.go:50, and the `node = nil` arms in commonjsmodule.go/esmodule.go dead code. Those dead arms also disagree: externalmoduleinfo would record the node as an external import (require/import-star helper decisions), while the CJS/ESM visitors would drop it. Removal depends on the implicit link that reparsed `@import` implies an IsTypeOnly clause (see the redundant assignment below). Combined with the Update kind-loss above, if that link breaks the failure is silent.
  remedy: Make the JS kind's handling match JSExportAssignment. Add `ast.KindJSImportDeclaration` to the explicit `return nil` arm at typeeraser.go:98 (comment: "reparsed JSDoc @import are type-only"). Remove it from the shared ImportDeclaration arm at typeeraser.go:258, from importelision.go (both sites), esnext.go:371 and externalmoduleinfo.go:50. The `node = nil` arms in the module transformers can stay, since they match the existing JSExportAssignment defensive arms, but then treat both kinds the same way.
  confidence: high
  evidence_refs: [internal/transformers/transformer.go:74, internal/transformers/typeeraser.go:98, internal/transformers/typeeraser.go:273, internal/transformers/importelision.go:31, internal/transformers/importelision.go:169, internal/transformers/esnext.go:371, internal/transformers/externalmoduleinfo.go:50, internal/transformers/commonjsmodule.go:66, internal/transformers/esmodule.go:42]
  overlap_hints: [correctness]

- severity: Low
  category: craft.abstraction
  file: internal/parser/reparser.go
  line: 120
  title: The @import reparse clones and edits only the ImportClause, sets an IsTypeOnly value the parser already set, and passes through always-nil modifiers
  evidence: |
    importClause := importTag.ImportClause.Clone(&p.factory)
    importClause.Flags |= ast.NodeFlagsReparsed
    importClause.AsImportClause().IsTypeOnly = true
    importDeclaration := p.factory.NewJSImportDeclaration(importTag.Modifiers(), importClause, importTag.ModuleSpecifier, importTag.Attributes)
    // jsdoc.go:864
    importClause := p.tryParseImportClause(identifier, afterImportTagPos, true /*isTypeOnly*/, true /*skipJSDocLeadingAsterisks*/)
  impact: `parseImportTag` already builds the clause with `isTypeOnly=true`, so line 122 does nothing and suggests an invariant the code does not actually need here. The clause is cloned while ModuleSpecifier and Attributes are shared with the tag. The typedef branch shares all of its children, so this asymmetry has no stated reason. `tryParseImportClause` returns nil for a clause-less `@import "mod"`, and `(*Node).Clone` dereferences `n.data`, so this line also panics on that input. `importTag.Modifiers()` is always nil for a JSDoc tag. The sibling `NewJSExportAssignment` hard-codes `nil /*modifiers*/` instead.
  remedy: Delete the `IsTypeOnly = true` line. Either share the clause as the typedef branch does, or keep the clone behind a nil check with a comment saying why only the clause is cloned. Drop the `modifiers` parameter from `NewJSImportDeclaration`, as `NewJSExportAssignment` does, and pass nil internally.
  confidence: high
  evidence_refs: [internal/parser/jsdoc.go:864, internal/parser/parser.go:2195, internal/ast/ast.go:216, internal/ast/ast.go:4349]
  overlap_hints: [correctness]

- severity: Nitpick
  category: craft.abstraction
  file: internal/ast/ast.go
  line: 1673
  title: Comments still say JSDocImportTag is an import/re-export form after its consumers were removed
  evidence: |
    AnyValidImportOrReExport    = Node // (ImportDeclaration | ExportDeclaration | JSDocImportTag) & { moduleSpecifier: StringLiteral } | ...
    // binder.go:1595
    // case *JSDocImportTag:
    // 	b.bindJSDocImportTag(node)
  impact: The change removes JSDocImportTag from `ModuleSpecifier`, `GetExternalModuleName`, `IsDefaultImport`, `isExclusivelyTypeOnlyImportOrExport`, `tryGetImportFromModuleSpecifier` and `ForEachDynamicImportOrRequireCall`, but these comments still list the tag as a module-reference node. The struct fields themselves are still used (by the reparser and encoder.go:675), so they are not dead.
  remedy: Replace `JSDocImportTag` with `JSImportDeclaration` in the `AnyValidImportOrReExport` comment, and delete the stale `bindJSDocImportTag` placeholder in binder.go.
  confidence: high
  evidence_refs: [internal/binder/binder.go:1595]
  overlap_hints: []

## Files examined
examined: [internal/api/encoder/encoder.go, internal/ast/ast.go, internal/ast/kind.go, internal/ast/kind_stringer_generated.go, internal/ast/utilities.go, internal/checker/checker.go, internal/checker/grammarchecks.go, internal/ls/utilities.go, internal/parser/reparser.go, internal/printer/namegenerator.go, internal/printer/printer.go, internal/transformers/commonjsmodule.go, internal/transformers/esmodule.go, internal/transformers/esnext.go, internal/transformers/externalmoduleinfo.go, internal/transformers/importelision.go, internal/transformers/typeeraser.go]
not_examined:
  - file: testdata/baselines/reference/submodule/conformance/importTag1.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag15(module=es2015).errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag15(module=esnext).errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag16.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag16.types
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag17.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag18.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag19.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag2.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag20.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag3.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag3.types
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag4.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag5.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag6.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag7.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag8.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submodule/conformance/importTag9.errors.txt
    reason: generated test baseline, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag1.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=es2015).errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=esnext).errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag16.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag16.types.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag17.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag18.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag19.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag2.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag20.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag3.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag3.types.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag4.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag5.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag6.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag7.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag8.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag9.errors.txt.diff
    reason: generated baseline diff, outside craft concern; not read
