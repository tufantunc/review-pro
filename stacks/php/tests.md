# Stack pack: php — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- PHPUnit test with no `$this->assert*` (or `$this->assertTrue(true)`).
- Tests depending on wall-clock (`date()`, `time()`, `microtime`) / global state / `$_SESSION` / DB without fixtures/isolation.
- Mocking everything (mock the SUT's collaborators so heavily that no real behavior is exercised).
- New public method / branch / exception in the diff with no test.
- Snapshot/golden committed but not regenerated after an intended change; flaky tests relying on iteration order.
- `@codeCoverageIgnore` / `markTestSkipped` introduced and left without justification.

## Stack-specific remedies
- Assert specific values/throws; inject a clock; isolate globals/DB with fixtures; cover the new branch; regenerate snapshots deliberately.

## Stack-specific severity guidance
- No-op assertion on a critical path: High.
- Untested new behavior: High.
- Clock/global-state flakiness: Medium/High.
