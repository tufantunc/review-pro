# Stack pack: go — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Unbounded goroutine fan-out (`for x := range ch { go f(x) }`) without a semaphore/worker pool → goroutine/connection storm.
- Slice grown in a loop with `append` when the size is known → reallocation churn; prefer `make([]T, 0, n)`.
- Repeated `string`↔`[]byte` conversions in a hot loop; string concatenation via `+=` instead of `strings.Builder`.
- N+1 DB/HTTP per element (see db pack).
- Channel misuse causing goroutine piling / blocking (unbuffered where buffered needed).
- `time.Sleep`-based polling loops instead of event-driven / `context` with deadline.

## Stack-specific remedies
- Cap concurrency with a buffered channel/worker pool; preallocate slices; use `strings.Builder`/`bytes.Buffer`.
- Batch I/O; prefer event-driven over sleep loops.

## Stack-specific severity guidance
- Unbounded goroutine fan-out on a request path: High (availability).
- Slice/`[]byte` churn in a measured hot loop: Medium/High.
- Premature micro-tuning without impact: do not report.
