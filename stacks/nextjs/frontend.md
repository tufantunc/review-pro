# Stack pack: nextjs — frontend
extends: core/skills/frontend/SKILL.md

## Stack-specific signals
- Server vs Client Component boundaries drawn wrong: an interactive component kept as a Server Component, or state/effects leaking into a server module.
- Prop drilling across the server→client edge instead of colocating client state; passing non-serializable objects (Date, class instances, functions) as props to Client Components.
- Client Component re-rendering on every navigation because state lives at the route level instead of a focused component/context.
- Hardcoded user-facing strings instead of `next-intl`/`next-i18next`/message files.
- Mixing the App Router and Pages Router inconsistently within one route; misusing `layout` vs `page` for shared state.

## Stack-specific remedies
- Push `"use client"` to the smallest interactive leaf; keep server fetches server-side; pass serializable props; route user strings through i18n.

## Stack-specific severity guidance
- Wrong RSC boundary breaking interactivity/build: High.
- Prop drilling / non-serializable props across the edge: Medium/High.
