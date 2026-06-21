# Stack pack: ai-ml — tests
extends: core/skills/tests/SKILL.md

## Stack-specific signals
- No held-out eval set asserted at all, or asserting a noisy metric with zero tolerance and no seed → brittle or meaningless.
- Free-text model output compared with `==` instead of structural/semantic checks (JSON schema, parsed values, pinned fixtures).
- Golden/canary tests committed but not regenerated after an intended change, or flaky across seeds.
- Tests depend on remote model calls / GPU / wall-clock with no mocking or `seed`.
- No test for a new metric/preprocessing step; no test for tool-call argument validation in an LLM agent.
- A "smoke" notebook cell masquerading as a test.

## Stack-specific remedies
- Assert metrics with tolerance + fixed seed; parse model output and assert structurally; mock remote/GPU; treat goldens explicitly.

## Stack-specific severity guidance
- No reproducible eval assertion for a model change: High.
- Free-text `==` assertions that pass by luck: High.
- Golden drift / seedless flakiness: Medium/High.
