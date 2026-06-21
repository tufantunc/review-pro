# Stack pack: dotnet — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- `async void` (except event handlers) → unobservable failure, can crash the process.
- `.Result` / `.Wait()` / `.GetAwaiter().GetResult()` on an async path → deadlock / sync-over-async.
- Fire-and-forget un-awaited `Task` (`_ = DoAsync()` without handling exceptions).
- Nullable reference types ignored: `!` (null-forgiving), `.Value` on `Nullable<T>`, suppressing `CS8602` → `NullReferenceException`.
- Empty `catch (Exception) {}` swallowing failures; `throw ex` losing the stack (use `throw;`).
- Missing `using`/`Dispose` on an `IDisposable` (files/streams/connections/`DbContext`).
- Culture-sensitive parsing (`int.Parse` / `ToString`) of machine data without `InvariantCulture`.

## Stack-specific remedies
- `async Task` (not `async void`); `await` everywhere; `using`/`await using` disposables.
- Preserve stack with `throw;`; honor NRTs; use `CultureInfo.InvariantCulture` for machine I/O.

## Stack-specific severity guidance
- `async void` / `.Result` deadlock on a request path: High.
- Swallowed exception on a write: High.
- Null-forgiving `!` on a real null path: High (NRE).
