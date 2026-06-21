# Stack pack: python — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- O(n²) loops / nested scans where a `set`/`dict` lookup or a single comprehension suffices.
- Building a list when a generator / lazy iteration would avoid materializing everything.
- N+1 ORM access in a loop (see db pack) — also a performance problem.
- CPU-heavy work inside an `async` event loop (GIL + blocks the loop) instead of offloading.
- `pandas.DataFrame.iterrows()` for row-wise computation instead of vectorized ops.
- Re-reading/re-parsing a constant file on every call instead of caching at module scope.

## Stack-specific remedies
- Replace membership/lookup loops with `set`/`dict`; prefer vectorized pandas ops; precompute module-level constants.
- Offload blocking/CPU work to a thread/process pool or out of the async loop.

## Stack-specific severity guidance
- N+1 / O(n²) on a hot path with realistic data size: High.
- `iterrows()` on a large DataFrame: High.
- Premature micro-optimization without measurable impact: do not report (anti-overreporting).
