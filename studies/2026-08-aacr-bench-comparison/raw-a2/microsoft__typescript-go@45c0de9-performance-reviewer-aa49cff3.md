<!-- microsoft__typescript-go@45c0de9 performance-reviewer; verbatim final answer -->
## Performance findings

- severity: Medium
  category: performance.blocking
  file: internal/ls/diagnostics.go
  line: 23
  title: The declaration transform now runs on every pull-diagnostics request, can't be cancelled, and isn't cached
  evidence: |
    if program.Options().GetEmitDeclarations() {
        diagnostics = append(diagnostics, program.GetDeclarationDiagnostics(ctx, file))
    }
  evidence_refs:
    - internal/lsp/server.go:513
    - internal/compiler/program.go:524
    - internal/compiler/emitHost.go:105
    - internal/compiler/emitter.go:476
  impact: |
    `handleDocumentDiagnostic` (server.go:513) calls `GetDocumentDiagnostics` on every `textDocument/diagnostic` pull. VS Code sends one after edits and when a tab gets focus. For any project with `declaration`/`composite` set, which is common for libraries and project references, each request now runs `getDeclarationDiagnosticsForFile`. That builds a new `emitHost` and runs `declarations.NewDeclarationTransformer(...).TransformSourceFile(file)` (emitter.go:476-477) over the whole file. The cost grows with the file's AST size, and it runs again even when the program hasn't changed.

    Checker diagnostics work differently: the checker keeps them per file and checks `ctx` for cancellation. This path keeps nothing between requests. It also drops the request context in two places: `getDeclarationDiagnosticsForFile(_ctx context.Context, ...)` ignores it, and `GetEmitResolver` gets its checker with `context.TODO()` (emitHost.go:105). When the client cancels or replaces a diagnostics request because the user keeps typing, the transform still runs to the end and holds the language service. For a large file (thousands of declarations), that puts a full extra AST walk and rewrite on the request path for every superseded request.
  remedy: |
    Pass `ctx` through `getDeclarationDiagnosticsForFile` into `GetEmitResolver` (replace `context.TODO()`) and check `ctx.Err()` before and after the transform. Then either cache declaration diagnostics per (program, file), the way the checker already caches its diagnostics, or only compute them when the program has changed since the last pull for that file.
  confidence: medium
  overlap_hints: [correctness.race, backend.cancellation]

## Files examined
examined: [internal/ls/diagnostics.go]
not_examined: []
