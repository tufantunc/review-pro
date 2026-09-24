# End-to-end run: results (2026-09-24)

Reports: `aspire-report.md`, `control-report.md`. Every agent reply: `raw/`.

## Pass conditions

- **A, the `dotnet run` claim: not produced at Medium or above.** No reviewer claimed the
  flake is unmitigated at the `dotnet run` sites or that the invariant is inverted there.
  `craft` raised the same sites as a Low (BundleSmokeTests.cs:97), resting in part on a false
  supporting claim, that a direct `dotnet run` does not go through the CLI. Being Low, it
  was not selected, which is the design. `correctness` explained the `--no-build` hand-off
  correctly on its own. Recorded, not a failure, as pre-registered.
- **A, the Verification line and markers: met.** The line is present, and the one code-axis
  finding at Medium or above carries its verification marker.
- **A and B, no verification in the orchestrator's own context: met.** The one selected
  finding went to a dispatched verifier; B selected nothing.
- **B, `Verification: 0 checked` and an intact report: met.**

## What the verifier did on a finding it had not seen before

The one Medium (craft, `CliE2EAutomatorHelpers.cs:34`) came back partly refuted with the
defect standing. Both falling parts check out: JsReactTemplateTests.cs:50 waits 2 minutes,
not 3, and ConfigDiscoveryTests and LocalConfigMigrationTests do not wait for the ready text,
so the proposed helper would change what they accept. The report shows both under the
finding; its severity and the verdict (REQUEST CHANGES) do not move, as the design says.

## Cost

Four reviewers on A at 86k to 96k subagent tokens each, one on B at 69k, and one verifier
at 78k tokens and 82 s. Verification added about 20 % to this review's token cost and ran
while nothing else was pending, so it added its full 82 s to wall time.
