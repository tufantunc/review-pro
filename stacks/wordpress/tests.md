# Stack pack: wordpress — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- New hook/REST route/`WP_Query` branch/`save_post` handler with no `WP_UnitTestCase`/integration test.
- Tests depending on global `$wpdb`/options/posts state without setUp/tearDown fixtures (`factory`), → cross-test contamination.
- No test for the nonce/capability/sanitize behavior added in the diff (security-critical, easily regressed).
- Mocking the whole WP API so the integration isn't exercised; flaky tests relying on real HTTP or wall-clock.
- Snapshot/golden of generated markup committed but not regenerated after an intended change.

## Stack-specific remedies
- Use the WP test suite + `$factory`; isolate with setUp/tearDown; assert nonce/capability/sanitize behavior; mock only true external HTTP.

## Stack-specific severity guidance
- New mutating hook/REST route with no test (esp. authz): High.
- No fixture isolation → cross-test contamination: High.
