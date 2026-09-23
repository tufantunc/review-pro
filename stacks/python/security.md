# Stack pack: python — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- `eval()` / `exec()` / `compile()` on non-static input → RCE.
- `pickle.loads` / `pickle.load` / `yaml.load(..., Loader=yaml.Loader)` (unsafe loader) / `marshal.loads` on untrusted data → deserialization RCE. Safe: `yaml.safe_load`.
- f-strings / `%` / `.format()` / `.execute("... " + x)` interpolating into SQL → SQL injection (psycopg, sqlite3, SQLAlchemy text).
- `subprocess.run(..., shell=True)` / `os.system(...)` with interpolated input → command injection.
- Django `mark_safe(user_html)` / Jinja `|safe` on untrusted content → XSS.
- `DEBUG = True` or permissive `ALLOWED_HOSTS` / wildcard `CORS_ALLOW_ALL_ORIGINS` reaching production config in the diff.
- Hardcoded `SECRET_KEY` / API keys / passwords; `random` (not `secrets`) for tokens.
- `send_file` / `open()` on user-controlled paths without confining to a base dir → path traversal.

## Stack-specific remedies
- Parameterize SQL (`cursor.execute("... WHERE id = %s", (id,))`); never f-string SQL.
- Use `subprocess.run([...], shell=False)` with arg lists + allowlists.
- Prefer `safe_load`; avoid `pickle` for untrusted input.
- Keep `DEBUG=False`, scoped hosts/CORS; load secrets from env/vault.

## Stack-specific severity guidance
- `eval`/`exec`/`pickle` on untrusted input: Critical.
- String-interpolated SQL on a mutating/public path: Critical/High.
- `DEBUG=True` shipped to prod config: High.

## Not a finding
- `yaml.safe_load`, and `yaml.load(..., Loader=yaml.SafeLoader)`.
- `subprocess.run([...])` with an argument list and no `shell=True`: there is no shell to inject into. Option injection still applies, per the rubric's injection rule.
- `cursor.execute("... WHERE id = %s", (value,))` and other driver placeholders, SQLAlchemy `text()` with bound parameters, and the ORM query API when field names, lookups, orderings, and keyword keys are fixed in code; a key, lookup, ordering, or alias taken from input is a finding unless it passes an allowlist. The finding is SQL text built from input by any means: an f-string, `+`, `.format()`, or `%`, including a `%s` filled by `%` rather than passed as the second argument.
