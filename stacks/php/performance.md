# Stack pack: php — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Query inside a loop (N+1) — also a correctness/db issue.
- O(n²) scan / nested loop where a keyed array lookup (`isset($map[$key])`) suffices.
- `file_get_contents`/HTTP call per request to a slow/remote resource without caching; `sleep`/sync I/O in a request path.
- Repeatedly re-parsing/re-reading a constant (config, fixtures) per call instead of caching at module/opcache scope.
- Large array materialization (`array_map` + `array_filter` + `array_column` chains) when a single pass/generator would do.
- Autoloading/including heavy code on a hot path; missing opcache/`opcache.preload` consideration in prod guidance.

## Stack-specific remedies
- Keyed lookups; cache remote/constant reads; single-pass transforms; keep hot paths lean.

## Stack-specific severity guidance
- N+1 / remote call per request on a hot path: High.
- O(n²) with realistic data: Medium/High.
- Premature micro-tuning without impact: do not report.
