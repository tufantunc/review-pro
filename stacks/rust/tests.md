# Stack pack: rust — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- No `#[test]` (or only `#[ignore]`) for a new public function / branch / error variant in the diff.
- `unwrap()` in tests masking the real error message; asserting only "it didn't panic" (`let _ = f();`).
- `assert_eq!` with no message on a non-obvious comparison; flaky tests relying on wall-clock / iteration order / map order without determinism.
- No test exercising the `unsafe`/error/panic path; `cargo test` not covering the new module.
- Async tests not using `#[tokio::test]` / `.await` (test silently doesn't run the future).
- Property/fuzz boundary missing for parser/numeric code.

## Stack-specific remedies
- Add `#[test]`/`#[tokio::test]` per new behavior; assert specific values with context messages; test the `Err`/`unsafe` paths.

## Stack-specific severity guidance
- New public behavior with no test: High.
- `#[ignore]` or non-awaited async test left in the diff: High.
- Order-dependent flakiness: Medium/High.
