# Stack pack: nextjs — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- **Hydration mismatch**: server-rendered output differs from client (e.g. `Date`, `Math.random`, `window`/`localStorage` read during render) → React tears/re-renders.
- Client-only state/effects in a Server Component, or `useState`/`useEffect`/event handlers placed above a missing `"use client"` boundary → runtime errors.
- Mixing Server Component async data fetch with client interactivity without a clean boundary (passing non-serializable props across the server→client edge).
- `useSearchParams`/`cookies`/`headers` used without the required `Suspense` boundary → build/runtime errors.
- `revalidate`/`cache` set inconsistently so stale data is served after a mutation, or a mutation doesn't invalidate the right tag.
- Async params type in app-router changed (`params: Promise<{id}>`) without awaiting → silent `undefined`.

## Stack-specific remedies
- Guard client-only reads behind `useEffect`/`typeof window`; mark client modules with `"use client"`; wrap `useSearchParams` in `Suspense`; invalidate the right cache tags after mutation.

## Stack-specific severity guidance
- Hydration mismatch on a real page: High.
- Missing `"use client"` causing runtime errors: High.
- Stale-data/cache-tag mismatch: Medium/High.
