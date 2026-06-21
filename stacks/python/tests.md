# Stack pack: python — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- `assert True` / `assert result` (truthy) with no specific assertion on the expected value.
- Tests that mock everything and assert only mocks (no real behavior exercised).
- `unittest.mock.patch` at the wrong boundary, masking contract drift.
- Tests depending on wall-clock (`datetime.now()` without freezegun/time-machine) or `random` without a seed.
- Network/filesystem touched in unit tests without fixtures/`tmp_path`/`responses`/`respx`.
- A new public function/branch/edge case in the diff with no test.
- `pytest` test silently skipped (`@pytest.mark.skip` / `xfail` introduced and left).

## Stack-specific remedies
- Assert specific values/raises; use `pytest.raises` for error paths.
- Inject a clock; seed/monkeypatch randomness; stub HTTP at a single boundary (`respx`/`responses`); use `tmp_path`.

## Stack-specific severity guidance
- Truthy/no-op assertion on a critical path: High.
- Untested new branch with real impact: High.
- Flaky time/random dependency: Medium/High.
