# Stack pack: typescript-react — performance
extends: core/skills/performance/SKILL.md

## Stack-specific signals
- Components re-rendering on every parent render because props are fresh object/array literals each time.
- Expensive inline computations re-run every render without `useMemo` (only where measurably costly).
- Callback props recreated every render breaking child memoization (`useCallback` where a memoized child depends on identity).
- Missing/incorrect `key` on lists causing full re-render on mutation.
- Heavy route/component imported eagerly instead of `React.lazy` + `Suspense`.
- Barrel imports (`import { x } from 'huge-lib'`) defeating tree-shaking → bundle bloat.
- Client-side data fetching with no dedupe (waterfall or repeated requests).

## Stack-specific remedies
- Stabilize prop identities passed to memoized children; hoist stable references.
- Memoize only measured hotspots; avoid speculative `useMemo`/`useCallback` everywhere.
- Code-split routes and large widgets with `React.lazy`; use deep/named imports for tree-shaking.
- Dedupe/parallelize data fetching; prefetch where possible.

## Stack-specific severity guidance
- Bundle bloat from a barrel import of a large library: High (measurable ship size).
- Re-render on a list due to bad `key`: High if the list is large; Medium otherwise.
- Premature micro-memoization with no measurable effect: do not report (anti-overreporting).
