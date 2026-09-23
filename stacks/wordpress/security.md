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

## Not a finding
- `$wpdb->prepare()` with `%s`, `%d`, and `%i` placeholders. The finding is SQL text concatenated before it reaches `prepare`, or a `prepare` call with no placeholders at all.
- A handler that only reads and returns public data, without a nonce. CSRF needs a state change; a nonce is required on writes, not on public reads.
- `'permission_callback' => '__return_true'` on a REST route that serves only public data. WordPress requires the callback to be explicit, and this is the documented form for public routes.
- Output escaped for its context at the point it is echoed: `esc_html` in element text, `esc_attr` in a quoted attribute that takes plain text, `esc_url` in a URL attribute, `esc_js` only for a value inside a single-quoted JS string in a double-quoted `on*` attribute, `wp_json_encode($v, JSON_HEX_TAG | JSON_HEX_AMP)` inside inline script, and `wp_kses_post` for HTML meant to keep safe tags. Any other pairing follows the rubric's rule on fitting the escaper to the sink; `esc_attr` on an `href`, for one, lets a `javascript:` URL through.
- `wp_safe_redirect` to a host the site allows, or `wp_redirect` to a constant URL.
