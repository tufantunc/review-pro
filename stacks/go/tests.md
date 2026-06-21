# Stack pack: go — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- Table-driven test missing the obvious edge case (empty/zero/nil/error) row.
- `t.Fatal(err)` inside a goroutine (does not stop the test correctly) instead of `t.Error` + channel back.
- Tests not run with `-race` covering concurrent code, or a genuine data race left in.
- `testify` mocking everything so no real behavior is exercised.
- Tests depending on wall-clock (`time.Now()`) / network without injection.
- New exported function/branch/error path in the diff with no test.

## Stack-specific remedies
- Add table rows for empty/zero/nil/error; use `t.Errorf` from goroutines (collect + assert in main).
- Run `-race`; inject a clock; stub network at one boundary; assert on real behavior, not mocks.

## Stack-specific severity guidance
- Missing edge/error case for critical behavior: High.
- `t.Fatal` in goroutine / unflagged race: High.
- Over-mocking that hides a contract drift: Medium.
