# Stack pack: wordpress — craft
extends: core/skills/craft/SKILL.md

## Stack-specific signals
- `functions.php` as a dumping ground (theme) — init + enqueues + helpers + DB + admin customizations in one file; or a single huge plugin main file.
- Direct `$wpdb` queries / `get_option` sprawl instead of the WP API (post types, taxonomies, metadata, REST controllers).
- Repeated sanitization/escaping logic instead of a single helper; copy-pasted `WP_Query` argument arrays.
- No namespace / class structure (procedural globals everywhere); configuration mixed into logic.
- Inline `add_action`/`add_filter` sprawl with no registration grouping; theme assets hardcoded instead of `wp_enqueue_*`.

## Stack-specific remedies
- Split `functions.php` / the god plugin into focused modules; use the WP API; reuse sanitize/escape helpers; enqueue assets properly; group registrations.

## Stack-specific severity guidance
- `functions.php`/god-plugin blocking a clear split: High.
- Direct DB / `get_option` sprawl bypassing the WP API: Medium/High.
