# Stack pack: swift — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- New public API/branch/`throws` path with no XCTest `func test...`; only the happy path covered.
- `XCTestAssertEqual` with no message on non-obvious comparisons; optional unwrap (`try!`) in tests masking real errors.
- Async code not awaited (`async throws` test without `await`) → silently skipped.
- Flaky tests depending on wall-clock (`Date()`) / `UUID()` / dispatch ordering without injection.
- Snapshot/UI tests committed but not regenerated after an intended change; mocking everything so no real behavior runs.

## Stack-specific remedies
- Cover the error/optional branch; await async tests; inject a clock/seed; treat snapshots deliberately; assert real behavior.

## Stack-specific severity guidance
- New behavior with no test / un-awaited async test: High.
- Dispatch/clock flakiness: Medium/High.
