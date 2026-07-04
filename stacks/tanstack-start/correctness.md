# Stack pack: tanstack-start — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- **Hydration mismatch**: server HTML differs from client — `Date.now()`, `Math.random`, `Intl`/locale/timezone, `new Date().toLocaleString()`, or `window`/`localStorage` read during render.
- Route `loader` assumed server-only — loaders are **isomorphic** (run on server during SSR and on client during navigation); reading `process.env`/DB directly in a loader exposes/leaks it.
- Server fn with no `.validator(...)` accepting untrusted input across the network boundary; always validate (e.g. Zod).
- Dynamic import of a server fn (`await import('….functions')`) → bundler issues; server fns must be **statically** imported (the build replaces the impl with an RPC stub).
- `Cache-Control`/CDN headers set but never invalidated after a write, or mutating flow missing `no-store` → stale data served post-mutation.
- Calling a server fn directly in a component instead of via `useServerFn(...)` → loses automatic redirect/not-found/error handling in the component lifecycle.
- FormData POST server fn whose validator doesn't assert `instanceof FormData` → silently `undefined` fields.
- Returning non-serializable values (class instances, Maps, functions) from a server fn → runtime serialization error under the default `strict` mode.
- Module-level side effects (DB pool open, env read) in a `.server.ts` that breaks under edge/worker SSR where modules load per-isolate.
- `createMiddleware().server()` context assumed transactional across separate server fn calls — no shared request state between them.

## Stack-specific remedies
- Keep SSR output deterministic (cookies for locale/tz, `<ClientOnly>`, Selective SSR `ssr: 'data-only'`, or sparing `suppressHydrationWarning`); fetch secrets/data via `createServerFn`; always `.validator(...)`; import server fns statically; invalidate cache after mutation; call with `useServerFn`; assert FormData and return only serializable shapes.

## Stack-specific severity guidance
- Hydration mismatch on a real route / secret read in an isomorphic loader / unvalidated server fn input: High.
- Missing cache invalidation after mutation / non-serializable return: Medium/High.
- Dynamic-import of a server fn / module-scope side effects under edge SSR: Medium.
