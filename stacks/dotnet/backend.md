# Stack pack: dotnet — backend
extends: core/skills/backend/SKILL.md

## Stack-specific signals
- ASP.NET Core controller action trusting request body without `[ApiController]` validation / data annotations.
- No `CancellationToken` plumbed into long-running handlers/services → no request-abort propagation.
- DI lifetime misuse: singleton capturing a scoped/Transient dependency (e.g. `DbContext`) → captive dependency + concurrency bugs.
- Inconsistent error responses; no exception-handling middleware; leaking stack traces.
- Multi-step writes without a transaction / `IExecutionStrategy` (EF Core) → partial state.
- Business logic in controllers instead of a service/handler layer.

## Stack-specific remedies
- `[ApiController]` + validation attributes; thread `CancellationToken`; register services with correct lifetimes.
- Add exception-handling middleware with a consistent `ProblemDetails` response; wrap multi-step writes in a transaction.

## Stack-specific severity guidance
- Unvalidated mutating action: High.
- Captive dependency (singleton holding scoped): High.
- Logic in controllers (layer leak): Medium.
