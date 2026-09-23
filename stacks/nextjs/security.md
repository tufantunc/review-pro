# Stack pack: nextjs — security
extends: core/skills/security/SKILL.md

## Stack-specific signals
- **Server Action** without an authz check — Server Actions are public POST endpoints; `export async function action(...)` callable by anyone unless it verifies identity/permissions.
- `cookies()`/`headers()` read in a Server Component without an auth check; or a route guarded by middleware that can be bypassed (matcher misconfiguration).
- Secrets shipped to the client: referenced via `NEXT_PUBLIC_*` or read in a Client Component (`"use client"`).
- `next.config.js` `images.dangerouslyAllowSVG` / `remotePatterns: [{hostname: "**"}]`; open redirect via `redirect(userInput)` / `next/navigation`.
- `generateStaticParams` / `revalidate` exposing per-user data in a cached/static route (data leakage across users).
- API route returning raw errors / stack / internal prompt; CORS `*` on a credentialed route.

## Stack-specific remedies
- Verify authz inside every Server Action / loader; never put secrets in client code; scope image/CORS; scope caching per-user.

## Stack-specific severity guidance
- Unauthenticated Server Action / middleware bypass on a mutating action: Critical/High.
- Secret via `NEXT_PUBLIC_*` / leaked cached per-user data: High.

## Not a finding
- A Server Action that checks the session and the caller's permission on the resource before acting. Look for that check at the top of the action, or in a helper it calls, before flagging the action as public.
- A `NEXT_PUBLIC_*` variable holding a publishable value by design: an analytics ID, a Stripe `pk_` key, a Firebase web config. Severity follows what the value grants.
- `redirect()` to a constant path, or to a value checked against an allowlist of internal paths.
- A statically generated or cached route that renders only data every visitor may see.
