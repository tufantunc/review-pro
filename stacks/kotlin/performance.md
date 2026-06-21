# Stack pack: kotlin — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Android: allocations/gson reflection/`ViewModel` work on the main thread causing jank; missing `RecyclerView` recycling (`onCreateViewHolder` reuse), heavy work in `onBindViewHolder`.
- Default `Dispatchers` misuse: CPU work on `Dispatchers.Main`, or blocking I/O on `Default`.
- Allocating large collections / repeated `map`/`filter` chains that create intermediate lists instead of `Sequence`.
- N+1 DB/IO in a loop (see db pack).
- Unbounded concurrency (`List(1000).map { async { } }`) instead of a bounded dispatcher/semaphore.

## Stack-specific remedies
- Move heavy work off main; use `Sequence` for multi-step transforms; bound concurrency with a fixed dispatcher; recycle views.

## Stack-specific severity guidance
- Main-thread allocations/heavy work causing jank: High.
- Unbounded `async` fan-out: High (availability).
- Premature micro-tuning without measurement: do not report.
