# Stack pack: wordpress — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- **Missing nonce check** on a form/AJAX/`admin-post` handler — `wp_verify_nonce`/`check_admin_referer`/`check_ajax_referer` absent → CSRF.
- **Missing capability check** on a privileged action — no `current_user_can('...')` / `user_can(...)` before mutating.
- **Unescaped output** of dynamic data: `echo $foo`, `<?= $bar ?>` instead of `esc_html` / `esc_attr` / `esc_url` / `wp_kses_post` → XSS.
- `$wpdb->query`/`$wpdb->get_results("... " . $_GET['x'])` string-interpolated instead of `$wpdb->prepare("... %s", $x)` → SQL injection.
- `register_setting` without a `sanitize_callback`; Customizer `add_setting` without `sanitize_js_callback`/sanitize.
- `eval` / `base64_decode` / `gzinflate(str_rot13(...))` obfuscation (common in malicious/low-quality themes).
- Untrusted `$_GET`/`$_POST`/`$_REQUEST` read directly into output/SQL/`include` without `map_meta_cap`/sanitization.
- `wp_redirect($_GET['url'])` / `wp_safe_redirect` missing → open redirect; enqueuing user-controlled URLs.

## Stack-specific remedies
- Verify nonces + capabilities on every mutating handler; always `esc_*` output; always `$wpdb->prepare`; register sanitize callbacks; `wp_safe_redirect`.

## Stack-specific severity guidance
- Missing nonce + capability on a mutating/admin action: Critical.
- Unescaped output / `$wpdb` interpolation: Critical/High.
- Obfuscation (`eval`/`base64_decode(gzinflate(...))`): High.
