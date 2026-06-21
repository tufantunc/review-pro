# Stack pack: swift — db
extends: core/skills/db/SKILL.md

## Stack-specific signals
- GRDB / Fluent raw query with string interpolation (`"WHERE id = \(id)"`) instead of bind parameters / `Filter` → SQL injection.
- Core Data / Fluent: schema change without a migration (`Migration`) → crash on existing stores / devices.
- N+1 via lazy relationship access in a loop instead of a fetch/prefetch/join.
- Multi-step write without a transaction; destructive migration (drop attribute/table) with no rollback.
- Main-thread DB/Core Data fetch blocking the UI → hang.

## Stack-specific remedies
- Parameterize / typed filters; ship proper migrations; prefetch/join to fix N+1; wrap multi-step writes in a transaction; background context for heavy fetches.

## Stack-specific severity guidance
- String-interpolated SQL / missing migration: Critical/High.
- Main-thread DB fetch (UI hang): High.
- N+1 in a loop: High (hand impact to `performance`).
