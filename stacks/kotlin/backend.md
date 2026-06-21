# Stack pack: kotlin — backend
extends: core/skills/backend/SKILL.md

## Stack-specific signals
- Ktor/Spring route trusting the request body without validation (`@RequestBody` without `@Valid` / Ktor without a plugin); no boundary DTO.
- Blocking I/O (`Thread.sleep`, JDBC sync, blocking client) inside a coroutine/Ktor route → stalls the dispatcher.
- Multi-step mutation without a transaction (Exposed `transaction { }` / Spring `@Transactional`); inconsistent error shapes across handlers.
- Business logic in the route/controller instead of a service module.
- Missing idempotency on a mutating endpoint; no rate limiting on expensive routes.

## Stack-specific remedies
- Validate at the boundary (DTO + `@Valid`/plugin); wrap multi-step writes in a transaction; move logic to a service; add idempotency/rate-limit where needed.

## Stack-specific severity guidance
- Unvalidated mutating route / blocking I/O in a coroutine: High.
- Logic in controllers (layer leak): Medium.
