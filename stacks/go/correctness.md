# Stack pack: go — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- Ignored error return (`result, _ := ...`, `foo()` where `foo` returns an error, `_ = err`) on a real failure path.
- `err` checked but not wrapped/returned (`if err != nil { log.Println(err) }` and continues) → silent partial failure.
- Goroutine leak: `go f()` with no `context.Context` cancellation / `sync.WaitGroup` / exit path → goroutines accumulate.
- `defer` inside a loop (file/lock/resource not released until function returns) → leak.
- Write to a map declared as `var m map[string]int` (nil) → panic; or concurrent map access without a mutex → data race/panic.
- Channel deadlock: send/receive on an unbuffered channel with no counterpart, or unhandled `select` default.
- Unchecked type assertion `x.(T)` (panics) instead of `x.(T)` comma-ok.
- `nil` interface holding a typed nil → surprising "non-nil nil".

## Stack-specific remedies
- Always handle/return errors; wrap with `%w`; use `errgroup`/`context` for goroutine lifecycle.
- Move `defer` out of loops; allocate maps with `make`; guard concurrent maps with `sync.Mutex`/`sync.Map`.
- Use comma-ok type assertions; return early on nil checks.

## Stack-specific severity guidance
- Ignored error on a write/IO path: High.
- Goroutine leak / concurrent map write on a server: High.
- Unhandled type assertion on a real path: High (panic).
