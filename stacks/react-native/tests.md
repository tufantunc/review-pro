# Stack pack: react-native — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- Component test rendering with React Native Testing Library but no `expect(...)` on a `toBeOnTheScreen`/`getByText`/`getByTestId` query.
- Tests depending on the real platform/`Platform.OS`/timers/network without mocks (`jest.useFakeTimers`, `fetch` mock).
- New screen/hook/reducer branch with no test; `act()` warnings left in (state update not wrapped).
- Snapshot tests committed but not regenerated after an intentional change; mocking the store so the component renders nothing real.
- E2E skipped entirely for a critical user flow; flaky tests relying on real animations (`waitFor` with no timeout bound).

## Stack-specific remedies
- Assert on queries; fake timers + mock fetch; wrap state updates in `act`; treat snapshots deliberately; cover branches.

## Stack-specific severity guidance
- No-op component test (no `expect`): High.
- New screen/hook branch with no test: High.
- Unbounded `waitFor` / snapshot drift: Medium/High.
