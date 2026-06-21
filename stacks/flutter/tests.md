# Stack pack: flutter — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- Widget test with no `expect(...)` on a `Finder` (e.g. `pumpWidget` then nothing).
- `pumpAndSettle()` misused with animations that never settle → test hangs; or with real network.
- Golden test committed without regenerating after an intentional visual change, or flaky across environments.
- Tests depending on real time (`Future.delayed`) instead of `Fake`/`Clock`/`pump(duration)`.
- Mocking the repository/data layer so the widget-under-test doesn't exercise real rendering.
- New widget behavior / branch / dialog state in the diff with no test.

## Stack-specific remedies
- Assert on `Finder`s (`find.text`, `find.byKey`); inject a fake clock; stub HTTP at one boundary; regenerate goldens deliberately.

## Stack-specific severity guidance
- No-op widget test (no `expect`): High.
- `pumpAndSettle` hanging the test / relying on real time: High.
- Over-mocked widget test rendering nothing real: Medium.
