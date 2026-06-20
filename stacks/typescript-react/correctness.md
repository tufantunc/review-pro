# Stack pack: typescript-react — correctness
extends: core/skills/correctness/SKILL.md

## Stack-specific signals
- `useEffect` with a wrong/missing dependency array → stale closure or skipped effect.
- Async work in an effect that sets state after unmount (no cleanup/abort) → warning + memory leak.
- `key` props using array index for mutable lists → wrong component reuse on reorder/insert.
- Conditional/late hook calls violating the Rules of Hooks.
- Reading state immediately after `setState` expecting the new value.
- `useEffect` running on mount when it should only run on a dependency change (missing the dependency, or should be an event handler).
- `await`-free reads of suspense/lazy boundaries that throw unhandled.

## Stack-specific remedies
- Match the dependency array to every external value the effect closes over; extract to `useCallback`/`useMemo` only when it clarifies.
- Abort fetches / cancel subscriptions in the effect cleanup; use `AbortController`.
- Use stable IDs as `key`, not array indices, for dynamic lists.

## Stack-specific severity guidance
- Hook-order violation: High (crashes the component tree on render).
- Stale-closure effect bug: High if it affects correctness of data writing; Medium otherwise.
