# Stack pack: tanstack-start — frontend
extends: core/skills/frontend/SKILL.md

## Stack-specific signals
- Server fn called during render instead of in a loader / `useServerFn` / `useQuery` → client-only data + render-phase network waterfalls.
- Wrong execution boundary: DOM/`window` code outside `createClientOnlyFn` / `<ClientOnly>` so it throws during SSR, or server-only code placed in a component that ships to the client.
- Non-serializable props (functions, class instances) passed across the server→client edge via server fn returns.
- Route-level state that should live in a focused component/context → re-render cascade on every navigation.
- Locale/timezone read non-deterministically in the component → hydration mismatch (source of truth should be a cookie set deterministically).
- Hardcoded user-facing strings instead of an i18n message layer.
- `createIsomorphicFn().server().client()` used where one deterministic helper would do — over-engineering the boundary.
- Forms that only work with JS when the server fn's `.url` could provide a no-JS progressive-enhancement fallback.

## Stack-specific remedies
- Fetch in loaders/`useServerFn`/`useQuery`, not render; wrap browser-only code in `createClientOnlyFn`/`<ClientOnly>`; return only serializable shapes; keep state at the smallest owner; read locale from a cookie; route strings through i18n; use server fn `.url` for no-JS forms.

## Stack-specific severity guidance
- Server fn in render / unguarded `window` access during SSR breaking hydration: High.
- Non-serializable edge props / route-level state causing cascade: Medium/High.
- Over-use of `createIsomorphicFn` / missing progressive enhancement: Medium.
