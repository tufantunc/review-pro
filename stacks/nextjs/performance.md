# Stack pack: nextjs — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Un-optimized images via plain `<img>` instead of `next/image` (no resize/WebP/lazy); oversized hero `next/image` without `priority`/`sizes`.
- Over-using dynamic rendering / `cookies()`/`headers()` reads that opt a whole route out of static generation → every request is SSR.
- Waterfall data fetching (sequential `await` in a component tree) instead of parallel `Promise.all` or server-side batch.
- Heavy client bundle: large client component, missing `dynamic(() => import, { ssr: false })` for a big/interactive-only lib.
- `revalidate: 0` / `cache: 'no-store'` on data that could be static; or the opposite — long `revalidate` on data that changes per user.
- Client-side refetch that duplicates server-fetched data (double fetch + hydration cost).

## Stack-specific remedies
- Use `next/image` with `sizes`; keep routes static where possible; parallelize fetches; code-split heavy client libs; set `revalidate` per data freshness.

## Stack-specific severity guidance
- Whole route opted out of static on a hot page: High.
- Un-optimized hero images / large client bundle: Medium/High.
- Premature caching micro-tuning without measurement: do not report.
