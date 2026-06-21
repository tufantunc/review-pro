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
