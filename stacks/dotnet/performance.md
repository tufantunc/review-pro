# Stack pack: dotnet — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Sync-over-async (`.Result`/`.Wait()`) on a hot path → threadpool starvation.
- LINQ enumerated multiple times / `IEnumerable` re-evaluated (e.g. `.Count()` then `foreach` on a lazy source) → repeated work.
- String concatenation with `+` in a loop instead of `StringBuilder`; LINQ in a tight loop with allocations.
- Missing `AsNoTracking()` on read-heavy queries (see db pack) — also a perf problem.
- `async void` / blocking I/O in an async pipeline.
- Allocating large buffers / `ToList()` on huge sequences to "materialize once" when streaming suffices.

## Stack-specific remedies
- Go fully async (no `.Result`); materialize once (`ToList`/`Array`) only when reused; `StringBuilder` for loops; `AsNoTracking` for reads.

## Stack-specific severity guidance
- Sync-over-async / threadpool starvation on a request path: High (availability).
- Repeated LINQ enumeration on large data: Medium/High.
- Micro-allocation tuning without impact: do not report.
