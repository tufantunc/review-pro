# Stack pack: go — db
extends: core/skills/db/SKILL.md

## Stack-specific signals
- `db.Query(fmt.Sprintf(...))` / `db.Exec("... " + x)` → SQL injection.
- Missing `db.SetMaxOpenConns` / `SetMaxIdleConns` / `SetConnMaxLifetime` → unbounded pool exhaustion.
- Multi-statement write without `db.BeginTx`/`Commit`/`Rollback` → partial state on failure.
- Migration drops a column/table, or a destructive `Exec` with no rollback path.
- `rows.Next()` loop without `rows.Close()` / `defer rows.Close()` / error check on `rows.Err()` → leak + missed error.
- N+1: per-row query inside a loop instead of a set-based query / `IN (...)`.

## Stack-specific remedies
- Parameterize (`$1`/`?`); `defer rows.Close()` and check `rows.Err()`; bound the pool.
- Wrap multi-step writes in a tx with rollback; write reversible migrations; batch N+1 into one query.

## Stack-specific severity guidance
- String-built SQL: Critical (hand to `security`).
- Missing `rows.Close()` / unbounded pool: High.
- N+1 in a loop: High (hand impact to `performance`).
