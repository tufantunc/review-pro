# Stack pack: php — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- `eval()` / `assert()` (legacy, evaluates strings) / `create_function` on non-static input → RCE.
- `unserialize($userInput)` → object-injection RCE (POP chains); never on untrusted data.
- SQL via string interpolation in PDO/mysqli/SQLi: `$db->query("SELECT ... WHERE id = " . $_GET['id'])` → SQL injection; must use prepared statements (`prepare`/`execute`/`bind_param`).
- `include`/`require`/`include_once` with user-influenced path → LFI/RFI (especially with `allow_url_include`).
- `system`/`exec`/`shell_exec`/`passthru`/`proc_open`/backticks with interpolated input → command injection.
- `echo $_GET['x']` / `print` of untrusted data without `htmlspecialchars(.., ENT_QUOTES)` → XSS.
- File upload (`move_uploaded_file`) trusting `$_FILES['type']`/name; `md5`/`sha1` for passwords (use `password_hash`/`password_verify`).
- `display_errors = On` / `ini_set('display_errors', 1)` reaching production → leaks stack/secrets.

## Stack-specific remedies
- Prepared statements; `htmlspecialchars(..., ENT_QUOTES, 'UTF-8')` on output; `password_hash`; `move_uploaded_file` + verify; disable `display_errors` in prod.

## Stack-specific severity guidance
- `eval`/`unserialize`/string-built SQL/`include` on input: Critical/High.
- Unescaped echo of `$_GET/$_POST`: High (XSS).
- `display_errors` in prod config: Medium/High.
