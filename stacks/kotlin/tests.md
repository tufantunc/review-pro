# Stack pack: kotlin — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- New public function/branch/error path with no test; `@Test` only for the happy path.
- Coroutines tested with `runBlocking` but no `runTest` / virtual time → flaky timing tests.
- Android: no `Robolectric`/instrumentation for lifecycle/DB-dependent code; mocking everything so no real behavior runs.
- Flaky tests relying on `System.currentTimeMillis()` / dispatchers / order without injection (`MainDispatcherRule`, `InstantTaskExecutorExtension`).
- JUnit assertion on a nullable with `assertEquals(null, x)` masking type; `assertNotNull` then ignoring the smart-cast.

## Stack-specific remedies
- Use `runTest` + dispatcher rules; inject a clock; assert real behavior; cover the error/null branch.

## Stack-specific severity guidance
- New behavior with no test / `runTest` missing for time-sensitive code: High.
- Order/timing flakiness: Medium/High.
