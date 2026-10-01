<!-- microsoft__typescript-go@45c0de9 tests-reviewer; verbatim final answer -->
## Tests findings

- severity: High
  category: tests.coverage
  file: internal/ls/diagnostics.go
  line: 44
  title: No test calls GetDocumentDiagnostics, so the nil-converters panic on every reported diagnostic goes unnoticed
  evidence: |
    lspDiagnostics = append(lspDiagnostics, toLSPDiagnostic(diag, nil)) // converters can be nil if not needed
    ...
    Range: converters.ToLSPRange(diagnostic.File(), diagnostic.Loc()),
  evidence_refs: [internal/ls/converters.go:33, internal/ls/converters.go:210, internal/ls/completions_test.go:2031, internal/lsp/server.go:518]
  impact: The refactor replaced `l.converters` with `nil`, but `toLSPDiagnostic` still calls `converters.ToLSPRange(...)` on line 86 for every diagnostic, and on line 68 for each related-information entry. That reaches `PositionToLineAndCharacter`, which reads `c.getLineMap(...)` on a nil `*Converters` at converters.go:210. Any file with at least one syntactic, semantic, suggestion or declaration diagnostic will therefore panic in the `textDocument/diagnostic` handler (server.go:518). Only files with zero diagnostics work. The repo has no test of `GetDocumentDiagnostics` or `toLSPDiagnostic`. The only test files in internal/ls and internal/lsp are `completions_test.go`, `converters_test.go` and `lsproto/baseproto_test.go`, and none of them mention diagnostics. So CI passes and this regression ships.
  remedy: Add `internal/ls/diagnostics_test.go`. Reuse the existing `createLanguageService(ctx, fileName, files)` harness from completions_test.go:2031, which wraps `projecttestutil.Setup`. Open a file such as `let x: number = "s";`, call `languageService.GetDocumentDiagnostics(ctx, ls.FileNameToDocumentURI("/index.ts"))`, and `assert.DeepEqual` the `Items`: code 2322, severity Error, source "ts", and a concrete `Range` (line 0, the exact start and end characters). Add a second case with a syntax error, e.g. `let = ;`, to cover the syntactic branch. The fix itself (pass `l.converters` through `toLSPDiagnostics`) belongs to correctness.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.coverage
  file: internal/ls/diagnostics.go
  line: 22
  title: The new declaration-diagnostics branch and the syntactic short-circuit have no test
  evidence: |
    if syntaxDiagnostics := program.GetSyntacticDiagnostics(ctx, file); len(syntaxDiagnostics) != 0 {
    	diagnostics = append(diagnostics, syntaxDiagnostics)
    } else {
    	...
    	if program.Options().GetEmitDeclarations() {
    		diagnostics = append(diagnostics, program.GetDeclarationDiagnostics(ctx, file))
    	}
    }
  evidence_refs: [internal/core/compileroptions.go:258, internal/ls/completions_test.go:2031]
  impact: The behavior this change adds is to report declaration-emit diagnostics when `GetEmitDeclarations()` is true. No test checks it. These regressions could all ship unnoticed:
    - Declaration diagnostics dropped.
    - Declaration diagnostics reported when `declaration` is off.
    - Declaration diagnostics leaking into the syntax-error path.
    - Duplicate diagnostics when the semantic and declaration passes report overlapping errors.
  remedy: In the same new test file, use a tsconfig with `"declaration": true` and source that only fails at declaration emit, e.g. `export function f() { class C {} return new C(); }` (TS4060-family "return type of exported function has or is using private name"). Assert that the declaration diagnostic's code and range appear in `Items`. Run the same source with `"declaration": false` and assert the code is absent. Add a file with both a syntax error and `declaration: true`, and assert that only the syntactic diagnostics come back.
  confidence: high
  overlap_hints: [correctness.logic, spec]

## Files examined
examined: [internal/ls/diagnostics.go]
not_examined: []
