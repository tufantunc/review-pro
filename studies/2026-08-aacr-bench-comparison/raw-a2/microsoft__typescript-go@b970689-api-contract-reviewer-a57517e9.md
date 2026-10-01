<!-- microsoft__typescript-go@b970689 api-contract-reviewer; verbatim final answer -->
I found two contract findings. The one that matters for API consumers is that `@import` now produces a new node kind (348) in the tree sent to the TS client, and that client has no entry for it. The client reads 348 as a different kind and throws when a consumer reads the import's fields.

- severity: Medium
  category: api-contract.schema
  file: internal/ast/kind.go
  line: 384
  title: New `KindJSImportDeclaration` (348) goes out over the API protocol, but the TS client's `SyntaxKind` and `childProperties` don't know it and `ProtocolVersion` wasn't bumped
  evidence: |
    	KindCommonJSExport
    +	KindJSImportDeclaration
    	// Transformation nodes
    	KindNotEmittedStatement
    ...
    // internal/api/encoder/encoder.go:277
    nodes = appendUint32s(nodes, uint32(node.Kind), uint32(node.Pos()), uint32(node.End()), 0, parentIndex, getNodeData(node, strs, &extendedData))
    // internal/api/encoder/encoder.go:462
    case ast.KindImportDeclaration, ast.KindJSImportDeclaration:
  evidence_refs: [internal/ast/kind_stringer_generated.go:359, internal/parser/reparser.go:118, internal/parser/parser.go:478, internal/api/encoder/encoder.go:48, _packages/ast/src/syntaxKind.ts:350, _packages/api/src/node.ts:49, _packages/api/src/node.ts:417]
  impact: |
    - The reparser now adds a `JSImportDeclaration` to the statement list for every JSDoc `@import` in a JS file (reparser.go:118-126, parser.go:478-480). `EncodeSourceFile` visits those statements and writes the raw number 348.
    - On the TS side, `_packages/ast/src/syntaxKind.ts` maps 348 to `SyntheticReferenceExpression`. So a client sees an unknown or wrong kind.
    - `childProperties` in `_packages/api/src/node.ts` has no entry for 348, only `[SyntaxKind.ImportDeclaration]`. `RemoteNode.getNamedChild` then assumes the node has one child. A reparsed `@import` has both `importClause` and `moduleSpecifier`, so reading `.importClause`, `.moduleSpecifier` or `.attributes` throws `"Expected only one child"`.
    - The change also shifts `NotEmittedStatement` through `Count` by one (348→349 … 352→353). The encoder only sends parsed files, so those kinds don't appear on the wire today.
    - `ProtocolVersion` stays at 1, so a client can't detect the change.
    - Context, which is why this is Medium and not High: the TS mirror was already out of date at the merge base. It lacks `JSTypeAliasDeclaration`, `JSExportAssignment` and `CommonJSExport`, and `NotEmittedStatement` is 345 there versus 348 in Go. Both packages are private (`"private": true`). This change makes the existing gap wider rather than creating it.
  remedy: |
    - Update `_packages/ast/src/syntaxKind.enum.ts` and `syntaxKind.ts` to match the Go `Kind` order. That means adding `JSTypeAliasDeclaration`, `JSExportAssignment`, `CommonJSExport` and `JSImportDeclaration`, and renumbering the transformation kinds.
    - Add `[SyntaxKind.JSImportDeclaration]: ["modifiers", "importClause", "moduleSpecifier", "attributes"]` to `childProperties`.
    - Bump `encoder.ProtocolVersion`. Better still, generate the TS enum from `kind.go` so the two can't drift again.
  confidence: high
  overlap_hints: [correctness.cross-file]

- severity: Low
  category: api-contract.types
  file: internal/ast/ast.go
  line: 4054
  title: `UpdateImportDeclaration` and `ImportDeclaration.Clone` silently turn `KindJSImportDeclaration` into `KindImportDeclaration`
  evidence: |
    func (f *NodeFactory) UpdateImportDeclaration(node *ImportDeclaration, modifiers *ModifierList, importClause *ImportClauseNode, moduleSpecifier *Expression, attributes *ImportAttributesNode) *Node {
    	if modifiers != node.modifiers || importClause != node.ImportClause || moduleSpecifier != node.ModuleSpecifier || attributes != node.Attributes {
    		return updateNode(f.NewImportDeclaration(modifiers, importClause, moduleSpecifier, attributes), node.AsNode(), f.hooks)
    ...
    func (node *ImportDeclaration) Clone(f NodeFactoryCoercible) *Node {
    	return cloneNode(f.AsNodeFactory().NewImportDeclaration(node.Modifiers(), node.ImportClause, node.ModuleSpecifier, node.Attributes), node.AsNode(), f.AsNodeFactory().hooks)
    // compare, same file line 4355 / 4369:
    return updateNode(f.newExportOrJSExportAssignment(node.Kind, modifiers, node.IsExportEquals, expression), node.AsNode(), f.hooks)
  evidence_refs: [internal/ast/ast.go:4065, internal/ast/ast.go:4069, internal/ast/ast.go:4355, internal/ast/ast.go:4369, internal/transformers/typeeraser.go:268, internal/transformers/importelision.go:41, internal/transformers/commonjsmodule.go:64, internal/transformers/transformer.go:59]
  impact: |
    - The PR adds the new private helper `newImportOrJSImportDeclaration(kind, …)` but doesn't use it in Update or Clone. The sibling `ExportAssignment` family does preserve `node.Kind` in both.
    - Any caller that rebuilds or clones a JS `@import` declaration gets a real `KindImportDeclaration` back. Callers that do this: `VisitEachChild` via ast.go:4065, typeeraser.go:268, and importelision.go:41, which the PR itself routes `KindJSImportDeclaration` into.
    - The module transformers only drop the JS kind (`case ast.KindJSImportDeclaration: node = nil`). A converted node would instead reach `visitTopLevelImportDeclaration` and could be emitted as a runtime `require`/`import` of a type-only module.
    - Nothing reaches this today. The reparser forces `IsTypeOnly = true`, so the type eraser returns nil before calling Update. Import elision is turned off for JS files (transformer.go:59). The API is still inconsistent, and nothing guards against a future caller hitting it.
  remedy: Call `f.newImportOrJSImportDeclaration(node.Kind, …)` in both `UpdateImportDeclaration` and `ImportDeclaration.Clone`, the same way `UpdateExportAssignment` and `ExportAssignment.Clone` do.
  confidence: high
  overlap_hints: [correctness.side-effect, craft.consistency]

Checked and not filed:
- **`ast.IsImportDeclaration` excluding the new kind:** this matches the existing split between `IsExportAssignment` and `IsJSExportAssignment` (ast.go:4376). Its callers either want real ES imports only (the external-module indicator) or only run on TS files (emitresolver.go:148 runs under import elision, which is off for JS).
- **`GetExternalModuleName` and `Node.ModuleSpecifier()` now panicking on a `JSDocImportTag`:** I found no remaining caller that passes one. The only one outside the reparser and encoder was `ForEachDynamicImportOrRequireCall`, and this PR removes that branch.

## Files examined
examined: [internal/api/encoder/encoder.go, internal/ast/ast.go, internal/ast/kind.go, internal/ast/kind_stringer_generated.go, internal/ast/utilities.go, internal/checker/checker.go, internal/checker/grammarchecks.go, internal/ls/utilities.go, internal/parser/reparser.go, internal/printer/namegenerator.go, internal/printer/printer.go, internal/transformers/commonjsmodule.go, internal/transformers/esmodule.go, internal/transformers/esnext.go, internal/transformers/externalmoduleinfo.go, internal/transformers/importelision.go, internal/transformers/typeeraser.go]
not_examined:
  - file: testdata/baselines/reference/submodule/conformance/importTag1.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag15(module=es2015).errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag15(module=esnext).errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag16.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag16.types
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag17.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag18.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag19.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag2.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag20.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag3.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag3.types
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag4.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag5.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag6.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag7.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag8.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submodule/conformance/importTag9.errors.txt
    reason: test baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag1.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=es2015).errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag15(module=esnext).errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag16.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag16.types.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag17.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag18.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag19.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag2.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag20.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag3.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag3.types.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag4.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag5.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag6.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag7.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag8.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
  - file: testdata/baselines/reference/submoduleAccepted/conformance/importTag9.errors.txt.diff
    reason: accepted-diff baseline; not part of the API contract (only seen in --stat)
