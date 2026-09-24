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
- Output escaped for the wrong context: `esc_attr` on an `href` lets a `javascript:` URL through, `esc_js` is built only for a value inside a single-quoted JS string in a double-quoted `on*` attribute, and `wp_json_encode` inside a `<script>` needs `JSON_HEX_TAG`.

## Stack-specific remedies
- Verify nonces + capabilities on every mutating handler; always `esc_*` output; always `$wpdb->prepare`; register sanitize callbacks; `wp_safe_redirect`.

## Stack-specific severity guidance
- Missing nonce + capability on a mutating/admin action: Critical when reachable without logging in, for example through `wp_ajax_nopriv_` or `admin_post_nopriv_`, an `admin_init` handler (it fires for anonymous requests to admin-ajax.php and admin-post.php), an `init` or `wp_loaded` handler acting on `$_POST`/`$_GET`, or a REST route with an open `permission_callback`, or when any registered user can reach it on a site with open registration; High when it needs a role the attacker must be granted.
- Unescaped output / `$wpdb` interpolation: Critical/High.
- Obfuscation (`eval`/`base64_decode(gzinflate(...))`): High when it decodes to code a request can reach, which is a backdoor; otherwise Low, a flag for review, since obfuscation on its own names no actor or boundary.
