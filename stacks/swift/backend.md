# Stack pack: swift — backend
extends: core/skills/backend/SKILL.md

## Stack-specific signals
- Vapor route trusting `req.content.decode` without validation; no DTO; errors mapped to a generic 500.
- Blocking work (`URLSession` sync, heavy compute) on the EventLoop → stalls the server; should be offloaded to a `NIOThreadPool`/async.
- Multi-step mutation without a transaction (Fluent `db.transaction`); inconsistent error shapes.
- Business logic in the controller instead of a service/domain module.
- Missing idempotency on mutating endpoints; no rate limiting / timeout on expensive routes.

## Stack-specific remedies
- Validate DTOs at the boundary; offload blocking; wrap multi-step writes in a Fluent transaction; centralize errors; move logic to services.

## Stack-specific severity guidance
- Blocking work on the EventLoop / unvalidated mutating route: High.
- Logic in controllers (layer leak): Medium.
