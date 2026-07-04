# Stack pack: tanstack-start — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Route fully SSR-rendered when it could be `ssr: 'data-only'` / `ssr: false` (Selective SSR) for an expensive or client-only component → wasted SSR work + larger payload.
- Waterfall data fetching: sequential `await` in nested loaders instead of `Promise.all`, or loader not preloading via TanStack Query `ensureQueryData`/`preload`.
- Module-level heavy work (DB pool init, large JSON parse) inside isomorphic code that re-runs; should live in a server-only fn.
- Server fn returning the whole DB row / an unbounded list instead of paginating/projecting → large serialized payload across the wire.
- Client bundle bloat: large client-only lib imported eagerly instead of `lazy()`/code-split; server code leaking because `.server.ts` wasn't import-protected.
- `gcTime: 0` on TanStack Query during SSR → hydration error; incompatible with `HydrationBoundary`.
- Public GET server fn with no `Cache-Control`/CDN headers that could be cached; conversely a long cache on per-user data.
- Re-fetching in a component data the loader already fetched (double fetch + hydration cost).
- Unstable `generateFunctionId` (non-deterministic seed) causing cache busting / unnecessary re-deploys.

## Stack-specific remedies
- Use Selective SSR where SSR adds cost without value; parallelize and preload loader data; move heavy init into server-only fns; paginate/project server fn output; code-split client libs; set cache headers per data freshness; keep a stable function ID.

## Stack-specific severity guidance
- Whole route forced SSR for client-only content / waterfall fetching on a hot route / oversized server fn payload: High.
- Missing CDN cache on public GET / client bundle bloat from unprotected server code: Medium/High.
- Micro cache-tuning without measured impact: do not report.
