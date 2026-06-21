# Stack pack: go — backend
extends: core/skills/backend/SKILL.md

## Stack-specific signals
- `http.Handler` that writes a response without validating input or returns no status on error.
- No `context.Context` plumbed through handlers/services → no cancellation/timeout, leaked work.
- Missing graceful shutdown (no signal handling / `server.Shutdown(ctx)`) → dropped requests on deploy.
- Inconsistent error responses (mix of `http.Error`, raw JSON, panics) with no central middleware.
- Multi-step writes without a transaction (`db.BeginTx`/`tx.Commit`).
- Business logic embedded in `net/http` handlers instead of a service layer.

## Stack-specific remedies
- Thread `ctx` everywhere; validate at the handler boundary; centralize errors via middleware.
- Implement graceful shutdown; wrap multi-step writes in a tx; move logic to a service package.

## Stack-specific severity guidance
- Unvalidated mutating handler: High.
- No graceful shutdown / no context plumbing: Medium/High.
- Logic in handlers (layer leak): Medium.
