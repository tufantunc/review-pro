# Stack pack: kotlin — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- `!!` (force-unwrap) on a nullable that can realistically be null (intent extras, API responses, `findViewById`) → `NullPointerException`.
- `runBlocking` on the UI/main thread or inside a coroutine → blocks the thread / deadlock.
- Coroutine leak: `GlobalScope.launch` / `scope.launch` with no structured concurrency / cancellation → work outlives its lifecycle (Android: survives Activity destroy).
- Swallowed exception: `runCatching { }.getOrNull()` / empty `catch (e: Exception) {}` on a real failure path.
- `!!`/`.let{}` confusion around platform types (Java interop nullability); mutable shared state across coroutines without a mutex/`Mutex`.
- Android lifecycle: touching UI/DB after the owner is destroyed; observing without lifecycle scope.
- Concurrent `MutableList`/`MutableMap` access from multiple coroutines/threads → `ConcurrentModificationException` / races.

## Stack-specific remedies
- Handle nulls explicitly (`?.let`, safe defaults); prefer `viewModelScope`/structured concurrency; never `runBlocking` on UI; propagate/`throw` real errors; use thread-safe collections / `kotlinx.coroutines.sync.Mutex`.

## Stack-specific severity guidance
- `!!` on user/API input or `runBlocking` on UI: High.
- `GlobalScope`/unstructured coroutine leaking past lifecycle: High.
- Swallowed exception on a write: High.
