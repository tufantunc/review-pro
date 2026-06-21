# Stack pack: dotnet — db
extends: core/skills/db/SKILL.md

## Stack-specific signals
- `FromSqlRaw`/`ExecuteSqlRaw` with concatenated SQL instead of parameterized form → SQL injection.
- EF Core N+1: accessing navigation properties in a loop / in a view without `.Include` / `.Select` projection / `AsSplitQuery`.
- Missing `AsNoTracking()` on read-only queries → unnecessary change-tracking overhead + state growth.
- `DbContext` used as a long-lived singleton/shared across threads (not thread-safe) → corruption/exceptions.
- Migration drops a column/table, or destructive `ExecuteSqlRaw`, with no rollback / data backfill.
- Multi-step writes without `using var tx = await db.Database.BeginTransactionAsync()`.

## Stack-specific remedies
- Parameterize; `.Include`/`.Select` projection to fix N+1; `AsNoTracking` for reads; scope a `DbContext` per unit-of-work.
- Reversible migrations; wrap multi-step writes in a transaction.

## Stack-specific severity guidance
- `FromSqlRaw` concatenation: Critical (hand to `security`).
- N+1 via navigation access on a list endpoint: High (hand impact to `performance`).
- Singleton `DbContext`: High.
