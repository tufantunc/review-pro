# Stack pack: typescript-react — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- Tests using `container.querySelector('custom-class')` instead of accessible queries (`getByRole`, `getByLabelText`).
- `fireEvent` used where `userEvent` is the realistic interaction (typing, clicking with focus).
- Missing `await`/`act()` around async state updates → false passes or warnings.
- Tests asserting component internals (state, refs, private methods) instead of rendered behavior.
- Mocking fetch/data layer per-test inconsistently; no MSW-style boundary mock, causing drift.
- Snapshot tests that pass while regressing real behavior (over-broad snapshots).
- Rendered component with no assertion on the user-observable outcome.

## Stack-specific remedies
- Query by role/label/text; reserve test-id queries for cases with no accessible name.
- Prefer `userEvent` for user input; wrap async interactions in `await`/`findBy*`.
- Mock network at a single boundary (MSW); assert on observable behavior, not internals.
- Replace over-broad snapshots with targeted assertions on the behavior that matters.

## Stack-specific severity guidance
- Test that passes for the wrong reason (missing `await`, assertion after early return): Critical/High.
- Testing implementation details that will break on harmless refactors: Medium.
