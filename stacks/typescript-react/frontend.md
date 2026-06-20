# Stack pack: typescript-react — frontend
extends: core/skills/frontend/SKILL.md

## Stack-specific signals
- Server/asynchronous data stored in component `useState` instead of a data layer (React Query / SWR / cache) → no dedupe, no invalidation, race conditions.
- Derived values stored as state instead of computed during render.
- `useEffect` used for derived data that should be computed inline (`useMemo` or plain render-time calc).
- Re-implemented UI primitives (buttons, inputs, dialogs) that duplicate a design-system component.
- Hardcoded colors/spacing/typography instead of design tokens.
- Missing loading/empty/error states for async UI.
- Hardcoded user-facing strings instead of the i18n layer.

## Stack-specific remedies
- Move server state into a data-fetching cache; keep local state for UI-only concerns.
- Compute derived values in render / `useMemo`; don't mirror props into state.
- Reuse design-system primitives and tokens; extend the system rather than fork it.
- Route all user-facing copy through the i18n function/component.

## Stack-specific severity guidance
- Server data in `useState` causing race/stale bugs: High.
- Bypassing the design system for a one-off component: Medium.
