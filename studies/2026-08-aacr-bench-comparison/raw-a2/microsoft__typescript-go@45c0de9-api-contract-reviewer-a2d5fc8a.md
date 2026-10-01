<!-- microsoft__typescript-go@45c0de9 api-contract-reviewer; verbatim final answer -->
I found one Critical issue in the only changed file, `internal/ls/diagnostics.go`. Every diagnostic is now converted with nil converters, so building its `Range` panics. Nothing in the server catches that panic, so the whole language server crashes.

- severity: Critical
  category: api-contract.serialization
  file: internal/ls/diagnostics.go
  line: 44
  title: Diagnostics are converted with nil Converters, so building any Range panics and the response is never sent
  evidence: |
    lspDiagnostics = append(lspDiagnostics, toLSPDiagnostic(diag, nil)) // converters can be nil if not needed
    ...
    Range: converters.ToLSPRange(diagnostic.File(), diagnostic.Loc()),
  evidence_refs: [internal/ls/converters.go:33, internal/ls/converters.go:210, internal/lsp/server.go:513-524, internal/lsp/server.go:187]
  impact: |
    The comment "converters can be nil if not needed" is wrong. `toLSPDiagnostic` always calls `converters.ToLSPRange` for the diagnostic's own `Range`, and again for each related-information `Location.Range`. `ToLSPRange` calls `c.PositionToLineAndCharacter`, which reads `c.getLineMap` (converters.go:210). With a nil `*Converters` that is a nil-pointer dereference.
    So for any document with at least one syntactic, semantic, suggestion or declaration diagnostic, `GetDocumentDiagnostics` panics. The consumer is the `textDocument/diagnostic` request: `Server.handleDocumentDiagnostic` (server.go:513-524) calls `GetDocumentDiagnostics` directly and has no `recover`. The only `recover()` under internal/lsp or internal/project is in `handleCompletion` (server.go:559), and `dispatchLoop` runs under an errgroup (server.go:187) with no recovery either.
    Result: the editor never receives a `DocumentDiagnosticReport` with `Items[].Range` values, and the LSP process crashes. Every client loses all diagnostics plus the rest of its session. Before this change, `l.converters` was passed through (merge base diagnostics.go:18/26/30), and `Range` was filled using the client's negotiated position encoding.
    Only files with zero diagnostics still work, because their `Items` is an empty slice.
  remedy: |
    Pass the language service's converters through. Either make `toLSPDiagnostics` take `converters *Converters` and call `toLSPDiagnostics(l.converters, diagnostics...)`, or make it a method on `*LanguageService`. Remove the misleading "converters can be nil" comment.
    Add a test that requests diagnostics for a file containing an error and checks the returned Range.
  confidence: high
  overlap_hints: [correctness.broken-functionality, backend.error-handling]

Two related points that are not findings:
- **Removing `Kind` does not change the response.** `StringLiteralFull` is an empty struct (lsp_generated.go:9577). Leaving the field out of the literal gives the same zero value as the old `lsproto.StringLiteralFull{}`. Its `MarshalJSON` always writes `"full"`, and the field is tagged `json:"kind"` without `omitempty` (lsp_generated.go:2522), so `"kind":"full"` is still sent.
- **`Items` is still a non-nil slice** (`make(..., 0, size)`), so it still serializes as `[]` and never as `null`.

## Files examined
examined: [internal/ls/diagnostics.go]
not_examined: []
