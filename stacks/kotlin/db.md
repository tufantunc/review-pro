# Stack pack: kotlin — db
extends: core/skills/db/SKILL.md

## Stack-specific signals
- Exposed / JDBC / Room `@Query` with string-interpolated SQL instead of bind params / typed DSL → SQL injection.
- Room: schema change without a migration (`fallbackToDestructiveMigration`) → silent data loss on the device.
- Exposed/JDBC: N+1 via lazy relation access in a loop; missing connection pool limits (HikariCP `maximumPoolSize`).
- Multi-step write without a transaction; destructive migration (drop column/table) with no rollback.
- Android: heavy DB work on the main thread → ANR.

## Stack-specific remedies
- Parameterize / typed DSL; ship proper Room migrations; eager-load / join to fix N+1; bound the pool; run DB off main thread.

## Stack-specific severity guidance
- String-interpolated SQL / `fallbackToDestructiveMigration`: Critical/High.
- DB I/O on the main thread (ANR): High.
- N+1 in a loop: High (hand impact to `performance`).
