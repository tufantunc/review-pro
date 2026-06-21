# Stack pack: python — db
extends: core/skills/db/SKILL.md

## Stack-specific signals
- SQLAlchemy `text(f"... {x}")` / `session.execute(text("... " + x))` → SQL injection.
- Django `.extra(select=...)` / `.raw()` with interpolated SQL.
- N+1 via lazy relationship access in a loop (Django ORM `o.related_set.all()` per row; SQLAlchemy lazy load per row) instead of `select_related`/`prefetch_related` / `selectinload`.
- Session/connection not closed (`Session` not disposed, `engine.dispose()` missing) → leaks.
- Destructive migration: dropping a column/table, `RunPython` that deletes data, with no reverse / backfill.
- sqlite3 / psycopg with `%` or f-string interpolation instead of placeholders.

## Stack-specific remedies
- Always bind parameters (`text("... :id").bindparams(id=...)`, `%s` placeholders).
- Eager-load relations (`select_related`/`prefetch_related`, `selectinload`/`joinedload`) to fix N+1.
- Write reversible migrations; back up data before destructive steps; scope writes in a transaction.

## Stack-specific severity guidance
- String-interpolated SQL (raw): Critical (hand severity to `security`).
- N+1 lazy load on a list endpoint: High (hand impact to `performance`).
- Non-reversible destructive migration: High.
