# Stack pack: rust — backend
extends: core/skills/backend/SKILL.md

## Stack-specific signals
- axum/actix-web handler returning `impl IntoResponse` with no validation of the request body, or mapping every error to `500` with no detail/shape consistency.
- No cancellation `CancellationToken` / request-scoped timeout plumbed into handlers/services → slow work can't be aborted.
- Missing graceful shutdown (`axum::serve(...).with_graceful_shutdown`) → dropped requests on deploy.
- Blocking (`std::fs`, CPU-heavy sync work) inside an `async` handler → stalls the runtime; should be `tokio::task::spawn_blocking`.
- Multi-step writes without a transaction; business logic embedded in handlers instead of a service module.

## Stack-specific remedies
- Validate at the boundary (`axum::extract::Json<T>` with a typed request); thread `CancellationToken`; graceful shutdown; offload blocking work; centralize errors.

## Stack-specific severity guidance
- Blocking sync work in an async handler: High (availability).
- Unvalidated mutating handler: High.
- Logic in handlers (layer leak): Medium.
