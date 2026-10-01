<!-- microsoft__typescript-go@45c0de9 correctness-reviewer; verbatim final answer -->
## Correctness findings

- severity: Critical
  category: correctness.logic
  file: internal/ls/diagnostics.go
  line: 44
  title: A nil `*Converters` is passed to toLSPDiagnostic, so the first diagnostic causes a nil-pointer panic that kills the LSP server
  evidence: |
    lspDiagnostics = append(lspDiagnostics, toLSPDiagnostic(diag, nil)) // converters can be nil if not needed
    ...
    // toLSPDiagnostic (diagnostics.go:85)
    Range: converters.ToLSPRange(diagnostic.File(), diagnostic.Loc()),
    // converters.go:33-36
    func (c *Converters) ToLSPRange(script Script, textRange core.TextRange) lsproto.Range {
        return lsproto.Range{ Start: c.PositionToLineAndCharacter(...), ...
    // converters.go:210
    lineMap := c.getLineMap(script.FileName())
  evidence_refs: [internal/ls/converters.go:33, internal/ls/converters.go:210, internal/lsp/server.go:298-302, internal/lsp/server.go:513]
  impact: The comment saying converters "can be nil if not needed" is wrong. `toLSPDiagnostic` calls `converters.ToLSPRange` for every diagnostic, and also for every related-information entry. `ToLSPRange` calls `PositionToLineAndCharacter`, which reads the field `c.getLineMap` on a nil receiver and panics. The change also stopped using `l.converters`. As a result, any `textDocument/diagnostic` request for a file with at least one syntactic, semantic, suggestion or declaration diagnostic panics. The request runs in a goroutine started by `go handle()` (server.go:301), because diagnostics is not a blocking method. Neither `handleDocumentDiagnostic` (server.go:513) nor `handle` has a `recover`, so the panic ends the whole tsgo LSP process. Opening any file that has an error crashes the language server. Before this change, `l.converters` was passed and this worked.
  remedy: Make `toLSPDiagnostics` take the converters (`func toLSPDiagnostics(converters *Converters, diagnostics ...[]*ast.Diagnostic)`) and call it with `l.converters`. Alternatively, make it a method on `*LanguageService`. Delete the incorrect "can be nil" comment.
  confidence: high
  overlap_hints: [tests.coverage]

- severity: High
  category: correctness.concurrency
  file: internal/ls/diagnostics.go
  line: 23
  title: Declaration diagnostics in the LSP use an emit resolver whose checker has already gone back to the shared pool, so a concurrent request can use the same checker at the same time
  evidence: |
    if program.Options().GetEmitDeclarations() {
        diagnostics = append(diagnostics, program.GetDeclarationDiagnostics(ctx, file))
    }
    // emitHost.go:105-112
    // But if this ever gets used by LSP code, we'll need to thread the context properly and pass the
    // done function to the caller to ensure resources are cleaned up at the end of the request.
    checker, done := host.program.GetTypeCheckerForFile(context.TODO(), file)
    defer done()
    return checker.GetEmitResolver(file, skipDiagnostics)
  evidence_refs: [internal/compiler/program.go:419, internal/compiler/program.go:524-530, internal/compiler/emitHost.go:105-112, internal/project/checkerpool.go:170-186, internal/checker/checker.go:29988-30001, internal/lsp/server.go:301]
  impact: 'This is the first LSP caller of `getDeclarationDiagnosticsForFile`, and it reaches the path that emitHost.go warns about. The steps are: (1) `GetEmitResolver` gets a checker with `context.TODO()`, so the checker has no request ID. (2) `done()` runs before the function returns, and `createRelease` sets `inUse[checker] = false` and calls `cond.Signal()`. (3) `getDeclarationDiagnostics` then runs `declarations.NewDeclarationTransformer(...).TransformSourceFile(file)`, which queries that checker through the resolver. Diagnostic, hover, definition and completion requests run as concurrent goroutines. Any of them can now take the same checker from `fileAssociations` or `getImmediatelyAvailableChecker` and call its normal APIs. Those APIs do not take `emitResolver.checkerMu`; that lock is only taken inside resolver methods. So two goroutines mutate the same checker''s state (links, type caches, diagnostics) without synchronization, a real data race. It can corrupt results or panic, and per the first finding a panic here also crashes the process. Separately, request cancellation is not passed through, and the checker can be a different one from the checker that just ran semantic checking for this file. With `skipDiagnostics=true` that checker never checks the file, so resolver answers can be incomplete.'
  remedy: 'Pass `ctx` through `getDeclarationDiagnosticsForFile`, then `emitHost.GetEmitResolver`, then `GetTypeCheckerForFile`. Keep the checker until the declaration transform finishes: have `GetEmitResolver` return `(resolver, done)`, or get the checker in `getDeclarationDiagnosticsForFile` and `defer done()` there. With the request ID passed through, the pool''s request association also gives back the same checker that ran semantic diagnostics.'
  confidence: medium
  overlap_hints: [backend.error-handling]

## Files examined
examined: [internal/ls/diagnostics.go]
not_examined: []
