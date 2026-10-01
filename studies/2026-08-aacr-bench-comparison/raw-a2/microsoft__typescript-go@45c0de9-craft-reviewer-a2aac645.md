<!-- microsoft__typescript-go@45c0de9 craft-reviewer; verbatim final answer -->
- severity: High
  category: craft.boundary
  file: internal/ls/diagnostics.go
  line: 44
  title: The new package-level toLSPDiagnostics drops the Converters dependency and passes nil to toLSPDiagnostic, which calls through it
  evidence: |
    func toLSPDiagnostics(diagnostics ...[]*ast.Diagnostic) []*lsproto.Diagnostic {
    ...
    			lspDiagnostics = append(lspDiagnostics, toLSPDiagnostic(diag, nil)) // converters can be nil if not needed
    ...
    func toLSPDiagnostic(diagnostic *ast.Diagnostic, converters *Converters) *lsproto.Diagnostic {
    ...
    		Range: converters.ToLSPRange(diagnostic.File(), diagnostic.Loc()),
  impact: The old code passed `l.converters` at every call site. The new helper is a free function with no LanguageService receiver, so it has no converters to pass, and the comment says nil is fine. It is not. `ToLSPRange` calls `PositionToLineAndCharacter`, which immediately calls `c.getLineMap(...)` (internal/ls/converters.go:210). With a nil `*Converters`, that dereferences nil and panics, and every diagnostic in the file hits that path. The comment hides a dependency that is actually required, and the next reader will trust it.
  remedy: Pass the dependency in explicitly. Either make the helper a method, `func (l *LanguageService) toLSPDiagnostics(...)`, that calls `toLSPDiagnostic(diag, l.converters)`, or give it a `converters *Converters` parameter. Delete the "converters can be nil" comment. `toLSPDiagnostic` cannot work without converters, so the type should not suggest they are optional.
  confidence: high
  evidence_refs: [internal/ls/converters.go:33, internal/ls/converters.go:207-210]
  overlap_hints: [correctness.logic]

- severity: Low
  category: craft.code-judo
  file: internal/ls/diagnostics.go
  line: 14
  title: A slice of slices, a variadic helper and a two-pass size count stand in for appending into one flat slice
  evidence: |
    	diagnostics := make([][]*ast.Diagnostic, 0, 3)
    	...
    func toLSPDiagnostics(diagnostics ...[]*ast.Diagnostic) []*lsproto.Diagnostic {
    	size := 0
    	for _, diagSlice := range diagnostics {
    		size += len(diagSlice)
    	}
  impact: There are at most three source slices, yet the code adds a `[][]` intermediate, a variadic signature, a pre-count loop and a nested loop. The two-pass preallocation saves almost nothing at this size, and the extra steps hide what the function really does: gather diagnostics, then map each one.
  remedy: Collect into one `[]*ast.Diagnostic` with `append(diags, program.GetX(ctx, file)...)` and convert it in one pass with `core.Map(diags, func(d *ast.Diagnostic) *lsproto.Diagnostic { return toLSPDiagnostic(d, l.converters) })` (core.Map is in internal/core/core.go:50). For the flattening, `core.Flatten` is in internal/core/core.go:381. That removes the helper's size-count loop and the nested loop. One catch: `core.Map` returns nil for a nil input, so keep `Items` non-nil if the protocol requires an array.
  confidence: medium
  evidence_refs: [internal/core/core.go:50, internal/core/core.go:381]
  overlap_hints: [dry.canonical-reuse, ai-antipatterns.over-engineering]

## Files examined
examined: [internal/ls/diagnostics.go]
not_examined: []
