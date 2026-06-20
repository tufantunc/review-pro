# Stack pack: typescript-react — craft
extends: core/skills/craft/SKILL.md

## Stack-specific signals
- A component file crossing ~1000 lines; or a single component doing fetch + transform + render + formatting.
- Repeated effect/state logic across components → a missing custom hook.
- Prop drilling of the same value through 3+ layers → missing Context or composition.
- `any`/`as`/non-null assertions (`!`) at prop boundaries that hide the real shape.
- One-off styling objects inline when a design-token/shared variant exists.
- Returned JSX trees so large they can't be scanned → extract subcomponents.

## Stack-specific remedies
- Extract reusable effect/state logic into named custom hooks (`useX`).
- Co-locate fetch + state in a hook; keep components focused on rendering.
- Replace prop drilling with Context only when the value is truly ambient; otherwise pass props.
- Type props precisely; model unions/discriminants instead of `any` + ad-hoc checks.

## Stack-specific severity guidance
- Hook extraction opportunity that deletes duplicated effect logic across components: High (classic code-judo).
- Pervasive `any` at component prop boundaries: Medium (type-boundary cleanliness).
