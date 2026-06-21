# Stack pack: php — db
extends: core/skills/db/SKILL.md

## Stack-specific signals
- PDO/mysqli string-interpolated SQL (`$pdo->query("... " . $id)`, `mysqli_query($conn, "... $id")`) → SQL injection; use prepared statements (`prepare`/`execute`/`bind_param`).
- N+1: a query executed per iteration (`foreach ($rows as $r) { $pdo->query("SELECT ... WHERE id = " . $r['id']); }`).
- Missing transaction around multi-step writes (`beginTransaction`/`commit`/`rollback`).
- Destructive migration (drop column/table, `ALTER`) with no rollback / backfill.
- `PDO::ATTR_ERRMODE` not `ERRMODE_EXCEPTION` → errors silently ignored.
- ORM query N+1 via lazy relation access in a loop; missing index on a new WHERE/JOIN.

## Stack-specific remedies
- Prepared statements; `ERRMODE_EXCEPTION`; eager-load / `IN (...)` to fix N+1; wrap multi-step writes in a transaction; reversible migrations.

## Stack-specific severity guidance
- String-interpolated SQL: Critical (hand to `security`).
- N+1 in a loop: High (hand impact to `performance`).
- Non-exception error mode masking failures: High.
