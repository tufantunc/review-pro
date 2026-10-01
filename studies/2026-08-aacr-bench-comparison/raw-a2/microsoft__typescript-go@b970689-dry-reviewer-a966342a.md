<!-- microsoft__typescript-go@b970689 dry-reviewer; verbatim final answer -->
## DRY findings

- severity: Medium
  category: dry.canonical-helper
  file: internal/ast/ast.go
  line: 4054
  title: UpdateImportDeclaration and Clone skip the new kind-parameterised constructor, unlike the ExportAssignment precedent they copy
  evidence: |
    func (f *NodeFactory) UpdateImportDeclaration(node *ImportDeclaration, ...) *Node {
    	if modifiers != node.modifiers || importClause != node.ImportClause || ... {
    		return updateNode(f.NewImportDeclaration(modifiers, importClause, moduleSpecifier, attributes), node.AsNode(), f.hooks)
    ...
    func (node *ImportDeclaration) Clone(f NodeFactoryCoercible) *Node {
    	return cloneNode(f.AsNodeFactory().NewImportDeclaration(node.Modifiers(), node.ImportClause, node.ModuleSpecifier, node.Attributes), ...)
  impact: The PR copies the `newExportOrJSExportAssignment(kind, ...)` pattern but only for construction. The precedent also sends Update and Clone through the private helper with `node.Kind`. Here both call the public `NewImportDeclaration`, which always sets `KindImportDeclaration`. So cloning a `KindJSImportDeclaration`, or updating it through `VisitEachChild` or `importelision.go:41` / `typeeraser.go:268`, turns it into a plain `KindImportDeclaration`. It then skips the new `case ast.KindJSImportDeclaration: node = nil` branches in the module transformers and every other JS-import-specific branch. The two halves of the pattern now behave differently, which is the kind of drift the shared helper was meant to prevent.
  remedy: Copy the precedent at internal/ast/ast.go:4355 and :4369. In UpdateImportDeclaration use `f.newImportOrJSImportDeclaration(node.Kind, modifiers, importClause, moduleSpecifier, attributes)`. In Clone use `f.AsNodeFactory().newImportOrJSImportDeclaration(node.Kind, node.Modifiers(), node.ImportClause, node.ModuleSpecifier, node.Attributes)`.
  evidence_refs: [internal/ast/ast.go:4353-4356, internal/ast/ast.go:4368-4370, internal/transformers/importelision.go:41, internal/transformers/typeeraser.go:268]
  confidence: high
  overlap_hints: [correctness.broken-functionality, craft.abstraction]

- severity: Low
  category: dry.missing-abstraction
  file: internal/checker/grammarchecks.go
  line: 550
  title: The two-kind import check is written inline with `||` several times; there is no import version of IsAnyExportAssignment
  evidence: |
    } else if (node.Kind == ast.KindImportDeclaration || node.Kind == ast.KindJSImportDeclaration || node.Kind == ast.KindImportEqualsDeclaration) && flags&ast.ModifierFlagsAmbient != 0 {
  impact: 'Is this any import declaration?' is spelled out by hand at grammarchecks.go:550, grammarchecks.go:2025 and checker.go:29386. The matching JS kind from before this PR got `IsJSExportAssignment` and `IsAnyExportAssignment` next to `IsExportAssignment` (internal/ast/ast.go:4376-4386). Imports only have `IsImportDeclaration` (internal/ast/ast.go:4080), which checks `KindImportDeclaration` alone. With no shared predicate, the four existing `ast.IsImportDeclaration` callers were not reviewed: utilities.go:1492 (IsExternalModuleIndicator), emitresolver.go:148, checker.go:14330 and completions.go:2279. Each now quietly excludes `@import` declarations, and nothing marks that as a deliberate choice.
  remedy: Next to internal/ast/ast.go:4080, add `IsJSImportDeclaration` and `IsAnyImportDeclaration`, mirroring ast.go:4380-4386. Use `IsAnyImportDeclaration` in the three `||` chains (grammarchecks.go:550, grammarchecks.go:2025, checker.go:29386). Then decide for each of the four existing `IsImportDeclaration` callers whether it should use the new predicate. Keep the Go `case A, B:` lists as they are, since that matches how KindJSExportAssignment is handled (33 sites).
  evidence_refs: [internal/ast/ast.go:4080, internal/ast/ast.go:4376-4386, internal/checker/grammarchecks.go:2025, internal/checker/checker.go:29386, internal/ast/utilities.go:1492, internal/checker/emitresolver.go:148, internal/checker/checker.go:14330, internal/ls/completions.go:2279]
  confidence: medium
  overlap_hints: [correctness.broken-functionality, ai-antipatterns.ignored-convention]

- severity: Nitpick
  category: dry.copy-paste
  file: internal/transformers/commonjsmodule.go
  line: 66
  title: The new `case KindJSImportDeclaration: node = nil` repeats the KindJSExportAssignment case in the same switch
  evidence: |
    	case ast.KindJSImportDeclaration:
    		node = nil
    	...
    	case ast.KindJSExportAssignment:
    		node = nil
  impact: In both commonjsmodule.go (lines 66 and 74) and esmodule.go (lines 42 and 48), one switch now has two separate cases with the same "drop JS-only synthetic node" body. A future JS-only kind would need a third copy in each file. There is little harm, because the block is one line.
  remedy: Merge them in both files, for example `case ast.KindJSImportDeclaration, ast.KindJSExportAssignment: node = nil` (with a short comment such as "reparsed JS-only nodes are not emitted"). Apply the same change at internal/transformers/esmodule.go:42/48.
  evidence_refs: [internal/transformers/commonjsmodule.go:74, internal/transformers/esmodule.go:42, internal/transformers/esmodule.go:48]
  confidence: high
  overlap_hints: [craft.code-judo]

Checked and not reported:
- **Repeated `case KindImportDeclaration, KindJSImportDeclaration:` lists** in encoder, checker, printer, namegenerator, the transformers and the ast utilities. The JSExportAssignment kind is handled the same way, so this is the codebase's usual style.
- **`IsAnyImportSyntax`, `GetExternalModuleName`, `GetImportAttributes` and `ModuleSpecifier`.** These were updated correctly, and folding the old JSDocImportTag branches into the shared ImportDeclaration branch removes duplication.
- **The Loc/Flags/append steps for the `@import` case in `reparser.go`.** They follow the file's existing typedef pattern at lines 114-117.

## Files examined
examined: [internal/api/encoder/encoder.go, internal/ast/ast.go, internal/ast/kind.go, internal/ast/kind_stringer_generated.go, internal/ast/utilities.go, internal/checker/checker.go, internal/checker/grammarchecks.go, internal/ls/utilities.go, internal/parser/reparser.go, internal/printer/namegenerator.go, internal/printer/printer.go, internal/transformers/commonjsmodule.go, internal/transformers/esmodule.go, internal/transformers/esnext.go, internal/transformers/externalmoduleinfo.go, internal/transformers/importelision.go, internal/transformers/typeeraser.go]
not_examined:
  - file: testdata/baselines/reference/submodule/conformance/importTag* and testdata/baselines/reference/submoduleAccepted/conformance/importTag*.diff (36 baseline files)
    reason: generated test baselines, outside the duplication/reuse concern; I only saw them in `--stat`, not their diffs
