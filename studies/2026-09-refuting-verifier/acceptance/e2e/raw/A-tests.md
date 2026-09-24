- severity: Low
  category: tests.assertion
  file: tests/Aspire.Cli.EndToEnd.Tests/Helpers/CliE2EAutomatorHelpers.cs
  line: 41
  title: The ready waits never check for the CLI's own startup timeout, so the extra 60s margin only makes failures slower
  evidence: |
    /// Intentionally larger than <see cref="AspireRunStartupBudgetSeconds"/> so the CLI's own startup timeout fires
    /// (surfacing its diagnostic) before this wait gives up on a genuine hang.
    internal static TimeSpan AspireRunReadyTimeout => TimeSpan.FromSeconds(AspireRunStartupBudgetSeconds + 60);

    // SmokeTests.cs:50-61 (the predicate that consumes it)
            if (s.ContainsText("Select an AppHost to use:"))
            { throw new InvalidOperationException(...); }
            return s.ContainsText("Press CTRL+C to stop the AppHost and exit.");
        }, timeout: CliE2EAutomatorHelpers.AspireRunReadyTimeout, description: "Press CTRL+C message (aspire run started)");
  evidence_refs: [tests/Aspire.Cli.EndToEnd.Tests/SmokeTests.cs:61, tests/Aspire.Cli.EndToEnd.Tests/SmokeTests.cs:104, tests/Aspire.Cli.EndToEnd.Tests/DotnetToolSmokeTests.cs:101, src/Aspire.Cli/Commands/RunCommand.cs:316, src/Aspire.Cli/Resources/RunCommandStrings.resx:233, tests/Aspire.Cli.EndToEnd.Tests/Helpers/CliE2EAutomatorHelpers.cs:789-797, tests/Aspire.Cli.EndToEnd.Tests/ConfigDiscoveryTests.cs:85-86]
  impact: At 180s the CLI stops and prints "Timed out waiting {0}s for AppHost to start..." (RunCommand.cs:316). It then exits to an ERR prompt. None of the three new `aspire run` predicates look for that text or for the ERR prompt. So the wait keeps polling a dead shell for another 60s. It then fails with the generic "Press CTRL+C message (aspire run started)" timeout. The CLI's diagnostic is on screen, but the test never uses it, which is the whole stated point of the margin. Any other early CLI exit (build failure, bad env value) also costs the full 240s, up from the previous 120s at two of the three sites. The failure message never says why the run failed.
  remedy: In the three `aspire run` ready predicates (SmokeTests.cs:50-61 and :93-104, DotnetToolSmokeTests.cs:92-101), throw when the screen shows the CLI timeout text ("Timed out waiting") or when the counter's ERR prompt appears. The ERR check can reuse `new CellPatternSearcher().FindPattern(counter.Value.ToString()).RightText(" ERR:")`, the way AspireStartAsync does at CliE2EAutomatorHelpers.cs:789-797. ConfigDiscoveryTests.cs:86 already does the looser `|| s.ContainsText("ERR:")`. The test then fails as soon as the CLI gives up, with the real cause.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.flakiness
  file: tests/Aspire.Cli.EndToEnd.Tests/Helpers/CliE2EAutomatorHelpers.cs
  line: 47
  title: Other E2E tests in the same project still run plain `aspire run` and remain exposed to the 120s default
  evidence: |
    internal static string GetAspireRunCommand()
    {
        return $"ASPIRE_CLI_START_TIMEOUT={AspireRunStartupBudgetSeconds.ToString(CultureInfo.InvariantCulture)} aspire run";
    }

    // JsReactTemplateTests.cs:37 / :50
    await auto.TypeAsync("aspire run");
    }, timeout: TimeSpan.FromMinutes(2), description: "Press CTRL+C message (aspire run started)");
  evidence_refs: [tests/Aspire.Cli.EndToEnd.Tests/JsReactTemplateTests.cs:37, tests/Aspire.Cli.EndToEnd.Tests/TypeScriptPolyglotTests.cs:139, tests/Aspire.Cli.EndToEnd.Tests/TypeScriptPolyglotTests.cs:451, tests/Aspire.Cli.EndToEnd.Tests/JavaPolyglotTests.cs:71, tests/Aspire.Cli.EndToEnd.Tests/ConfigHealingTests.cs:70, tests/Aspire.Cli.EndToEnd.Tests/LocalConfigMigrationTests.cs:84, src/Aspire.Cli/Commands/AppHostStartupTimeout.cs:15]
  impact: These tests are outside the changed files. They run `aspire new` and then `aspire run` on the same Docker/CI setup the PR blames for the flake. Their ready waits are 2-3 minutes, so the CLI's default 120s budget (AppHostStartupTimeout.cs:15, `WaitCommand.DefaultTimeoutSeconds`) still ends the run first. The fix covers three call sites, and the same intermittent failure is left in at least six others. JsReactTemplateTests.cs:37 has the same starter-template-plus-2-minute shape as the SmokeTests site that was changed. I have not confirmed that each of these suites restores from the daily feed while cold, hence medium confidence.
  remedy: Replace `"aspire run"` with `CliE2EAutomatorHelpers.GetAspireRunCommand()` and the ready-wait timeout with `CliE2EAutomatorHelpers.AspireRunReadyTimeout` at JsReactTemplateTests.cs:37, TypeScriptPolyglotTests.cs:139 and :451, JavaPolyglotTests.cs:71, ConfigHealingTests.cs:70 and LocalConfigMigrationTests.cs:84. If they are left out on purpose, say so in the PR description.
  confidence: medium
  overlap_hints: [dry.canonical-reuse, spec.partial]
