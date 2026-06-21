# Stack pack: dotnet — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- xUnit/NUnit test with no `Assert.*` (or `Assert.True(true)`).
- `async void` test / un-awaited async in tests (xUnit expects `async Task`).
- Tests depending on `DateTime.Now` / `Guid.NewGuid()` / shared static state without injection.
- Mock-heavy test asserting only mock setups; no real behavior exercised (Moq over-use).
- EF Core tested against a mock `DbContext` that doesn't exercise query translation; integration tests skipped.
- New public method/branch/exception in the diff with no test.

## Stack-specific remedies
- `async Task` tests; inject `TimeProvider`/abstractions; assert on real behavior; test EF against an in-memory/TestContainers provider.

## Stack-specific severity guidance
- No-op assertion on a critical path: High.
- Un-awaited async test: High.
- EF mocked so queries are untested: Medium.
