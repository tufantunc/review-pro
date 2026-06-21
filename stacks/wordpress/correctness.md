# Stack pack: wordpress — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- **Wrong hook timing**: running logic on `init` that needs `template_redirect`/`wp`, or enqueuing on `admin_enqueue_scripts` instead of `wp_enqueue_scripts` (and vice versa).
- **Direct DB / `WP_Query` in a template** instead of the request lifecycle; `query_posts` (mutates globals) instead of `WP_Query`/`get_posts`.
- Child-theme path confusion: `get_template_directory_uri()` (parent) vs `get_stylesheet_directory_uri()` (child) used wrong for assets.
- `wp_localize_script` / REST response returning non-`rest_`-prefixed/unsanitized data; missing `rest_pre_serve_request`/permission_callback.
- `add_action`/`add_filter` with wrong priority/arg count (mismatched accepted args).
- Theme template hierarchy misuse (`front-page.php` vs `page.php`); assuming `the_post`/`have_posts` state.

## Stack-specific remedies
- Use the right hook for the stage; never `query_posts`; use `get_stylesheet_directory_*` for child-theme assets; declare REST `permission_callback` + sanitize; match `add_action`/`add_filter` arg counts.

## Stack-specific severity guidance
- `query_posts` / wrong lifecycle hook breaking state on a real page: High.
- Child-theme URI used wrong → broken assets: Medium.
