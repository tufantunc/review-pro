# Stack pack: python — backend
extends: core/skills/backend/SKILL.md

## Stack-specific signals
- Django/Flask/FastAPI handler trusting `request.json` / `request.POST` without schema validation.
- FastAPI route with `response_model=None` or `Any`, or parameters typed `Any` → no real validation.
- Blocking I/O (`requests`, sync file/db) inside an `async def` handler → blocks the event loop.
- Unhandled exception in a handler returning a 500 with a stack trace / inconsistent error shape.
- Multi-step state mutation without a transaction (Django: `atomic()`, SQLAlchemy: session commit boundaries).
- Business logic inside a route/view instead of a service module.

## Stack-specific remedies
- Validate at the boundary with Pydantic / marshmallow / Django forms; reject 422/400.
- Move blocking I/O to a sync threadpool or make the dependency truly async.
- Wrap multi-step writes in `transaction.atomic()` / a session transaction; centralize error handling middleware.

## Stack-specific severity guidance
- Unvalidated mutating endpoint: High.
- Blocking I/O in async handler on a hot path: High (availability).
- Logic sprawled in views (layer leak): Medium.
