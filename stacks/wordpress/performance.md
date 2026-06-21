# Stack pack: wordpress — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- `WP_Query` / `get_posts` executed per item inside a loop → N+1 (e.g. per-post lookups in a listing template).
- `query_posts` in the loop (also a correctness issue) — re-runs the main query, mutates globals, slow.
- N+1 meta queries: `get_post_meta`/`get_the_terms` per row instead of `update_post_meta` cache / `WP_Query` `meta_query` / `wp_get_object_terms`.
- Autoload options bloat: large data stored in autoloaded options/transients loaded every request.
- `wp_remote_get`/HTTP call per request without caching (transient/object cache); heavy work on every `template_redirect`.
- Rendering a list with nested `WP_Query` calls instead of a single query + loop.

## Stack-specific remedies
- One query + loop instead of per-item queries; cache remote/heavy results (transient/object cache); don't store large data in autoload options.

## Stack-specific severity guidance
- N+1 `WP_Query`/`get_post_meta` per row on a listing page: High.
- Autoload bloat / uncached remote call per request: Medium/High.
