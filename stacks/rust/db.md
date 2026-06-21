# Stack pack: rust — db
extends: core/skills/db/SKILL.md

## Stack-specific signals
- `sqlx::query(&format!("... {x}"))` / `diesel` with `format!`-built SQL → SQL injection (the compile-time `sqlx::query!` macro or bind params are the fix).
- Missing connection pool limits (`sqlx::PgPoolOptions::max_connections` unbounded) → pool exhaustion under load.
- Multi-statement write without a transaction (`pool.begin()` / `Transaction`) → partial state on failure.
- Destructive migration (drop column/table, `sqlx::migrate!` with irreversible steps) with no rollback path.
- N+1: per-row query inside a loop instead of a set-based query / `IN` / join.
- `sqlx::Row::get` with wrong/untyped column index; ignoring migration checksum mismatches.

## Stack-specific remedies
- Use `sqlx::query!`/`query_as!` (compile-time checked) or bind params; bound pool size; wrap multi-step writes in a tx; reversible migrations; batch N+1.

## Stack-specific severity guidance
- `format!`-built SQL: Critical (hand to `security`).
- Unbounded pool / missing tx on multi-step write: High.
- N+1 in a loop: High (hand impact to `performance`).
