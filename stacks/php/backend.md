# Stack pack: php — backend
extends: core/skills/backend/SKILL.md

## Stack-specific signals
- Route/handler trusting `$_GET`/`$_POST`/`$_REQUEST`/`php://input` without validation/sanitization.
- No central error handling — fatal errors leak to the client; inconsistent response shapes across endpoints.
- Multi-step mutation without a transaction; or a long blocking operation inside a request handler (PHP-FPM worker held).
- Session handling: `session_start` without secure/httponly/samesite cookie settings; session fixation; sticky timeouts.
- Business logic embedded in a route/controller instead of a service layer.
- Missing idempotency on a mutating endpoint; CSRF token absent on a state-changing form/endpoint.

## Stack-specific remedies
- Validate at the boundary; centralize errors with a consistent response shape; wrap multi-step writes in a DB transaction; harden session cookie; move logic to services; add CSRF tokens.

## Stack-specific severity guidance
- Unvalidated mutating handler / CSRF on a state-changing endpoint: High.
- Blocking long operation in an FPM worker: High (availability).
- Logic in controllers (layer leak): Medium.
