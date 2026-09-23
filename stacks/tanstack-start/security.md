# Stack pack: tanstack-start — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- `createServerFn()` that reads/writes private data with no authz check — server functions are same-origin RPC endpoints callable independently of the route that renders the UI; `beforeLoad` is route UX, **not** the data boundary.
- Custom `src/start.ts` defined without `createCsrfMiddleware()` — CSRF protection is auto-installed **only** when there's no `src/start.ts`; a custom one drops it, allowing cross-site server-fn calls.
- `process.env` / secrets read at module scope → value inlined into the client bundle AND undefined under per-request-env runtimes (Cloudflare Workers); must read inside `.handler()` / `createServerOnlyFn()`.
- `Cache-Control: public` (or CDN-cache) on a server fn that reads a session/cookie/identity → cross-tenant cache leak; authenticated responses must be `private` + `Vary: Cookie, Authorization`, or `no-store`.
- Secret shipped via a `VITE_`-prefixed var — the `VITE_` prefix is client-exposed by design.
- `.server.ts` / server-only module imported into client code without import protection → server code (DB URLs, keys) leaks into the client bundle.
- Server fn returning raw errors / stack / internal details; errors are serialized and sent to the client across the wire.
- Open redirect via `throw redirect({ to: userInput })` with an unvalidated URL.
- `createServerFn({ strict: false })` disabling serialization type checks at a trust boundary instead of validating input with a Zod `.validator(...)`.
- Permissive CORS on a server fn — server fns are same-origin by design; public cross-origin endpoints should be server routes.

## Stack-specific remedies
- Enforce auth inside every server fn that touches private data (middleware or in-handler check); install `createCsrfMiddleware()` in any custom `src/start.ts`; read secrets only inside server-only/handler scope; use `private`/`no-store` for authenticated responses; validate input with Zod; keep server code behind `.server.ts` import protection.

## Stack-specific severity guidance
- Unauthenticated private-data server fn / missing CSRF with custom `src/start.ts` / secret in client bundle: Critical/High.
- `Cache-Control: public` on authenticated response / module-scope `process.env` read: High.
- `strict: false` at a trust boundary / open redirect: Medium/High.
