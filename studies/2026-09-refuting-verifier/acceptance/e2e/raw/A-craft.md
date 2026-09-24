- severity: Medium
  category: craft.code-judo
  file: tests/Aspire.Cli.EndToEnd.Tests/Helpers/CliE2EAutomatorHelpers.cs
  line: 34
  title: The run startup budget is split into three public members that callers must pair by hand, when AspireStartAsync already has a one-parameter shape for this
  evidence: |
    internal const int AspireRunStartupBudgetSeconds = 180;
    ...
    internal static TimeSpan AspireRunReadyTimeout => TimeSpan.FromSeconds(AspireRunStartupBudgetSeconds + 60);
    ...
    internal static string GetAspireRunCommand()
    {
        return $"ASPIRE_CLI_START_TIMEOUT={AspireRunStartupBudgetSeconds.ToString(CultureInfo.InvariantCulture)} aspire run";
    }

    // existing sibling, same file line 761-776:
    var effectiveTimeout = startTimeout ?? TimeSpan.FromMinutes(3);
    ...
    var startupTimeoutSeconds = Math.Max(1, (int)Math.Ceiling(effectiveTimeout.TotalSeconds));
    await auto.TypeAsync($"(set -o pipefail; ASPIRE_CLI_START_TIMEOUT={startupTimeoutSeconds...} aspire start...
  impact: The invariant the PR documents ("terminal wait is larger than the CLI budget, so the CLI's own timeout fires first") only holds if every call site uses GetAspireRunCommand() and AspireRunReadyTimeout together. Nothing enforces that, and BundleSmokeTests already uses one without the other (next finding). Each call site still copies the same sequence by hand: TypeAsync, EnterAsync, WaitUntilAsync with a ready predicate, Ctrl+C, then WaitForSuccessPromptAsync. At least seven other `aspire run` sites (JsReactTemplateTests.cs:37, JavaPolyglotTests.cs:71, TypeScriptPolyglotTests.cs:139 and :451, ConfigHealingTests.cs:70, ConfigDiscoveryTests.cs:73, LocalConfigMigrationTests.cs:84) keep the raw `"aspire run"` with a hardcoded 3-minute wait. So there are now two ways to launch `aspire run`, and the fix is not applied to all of them.
  remedy: Replace the three members with one `AspireRunAsync(this Hex1bTerminalAutomator auto, TimeSpan? startTimeout = null, string? apphost = null, Func<Hex1bTerminalSnapshot, bool>? failIf = null)` extension, a sibling of AspireStartAsync/AspireStopAsync. It takes a single budget, writes `ASPIRE_CLI_START_TIMEOUT` from it, waits for "Press CTRL+C to stop the AppHost and exit." for budget + 60s, and throws when `failIf` matches (which covers the selection-prompt and polyglot Capability Error checks). Make the budget constant private and delete GetAspireRunCommand. The three call sites in this PR then shrink to one call each, and the other `aspire run` sites can adopt the same helper.
  confidence: high
  evidence_refs: [tests/Aspire.Cli.EndToEnd.Tests/Helpers/CliE2EAutomatorHelpers.cs:752, tests/Aspire.Cli.EndToEnd.Tests/Helpers/CliE2EAutomatorHelpers.cs:776, tests/Aspire.Cli.EndToEnd.Tests/JsReactTemplateTests.cs:37, tests/Aspire.Cli.EndToEnd.Tests/ConfigHealingTests.cs:70]
  overlap_hints: [dry.duplication, spec.partial]

- severity: Low
  category: craft.boundary
  file: tests/Aspire.Cli.EndToEnd.Tests/BundleSmokeTests.cs
  line: 97
  title: AspireRunReadyTimeout is applied to `dotnet run` launches that never set the budget it is defined against
  evidence: |
    await auto.TypeAsync($"dotnet run --no-launch-profile --project {quotedAppHostProjectPath} -- --from-dotnet-run");
    await auto.EnterAsync();

    await auto.WaitUntilAsync(
        s => s.ContainsText("Press CTRL+C to stop the AppHost and exit."),
        timeout: CliE2EAutomatorHelpers.AspireRunReadyTimeout,
  impact: The helper's doc defines the wait as "Intentionally larger than AspireRunStartupBudgetSeconds so the CLI's own startup timeout fires (surfacing its diagnostic) before this wait gives up". Here, and at line 157 (`dotnet run apphost.cs`), no `ASPIRE_CLI_START_TIMEOUT` prefix is typed. The only readers of that setting are in src/Aspire.Cli (DotNetCliRunner.cs:626, AppHostStartupTimeout.cs:17), which a direct `dotnet run` of the AppHost does not go through. So the budget + 60s value is an unrelated 4-minute constant at these sites, and its name and doc mislead anyone who later tunes it.
  remedy: Keep an explicit local `TimeSpan.FromMinutes(4)` for the two `dotnet run` sites, or a separately named constant with its own reason. Don't borrow the `aspire run`-specific value. Once the value lives inside an `AspireRunAsync` helper (finding above), it can't be reached from here at all.
  confidence: medium
  evidence_refs: [tests/Aspire.Cli.EndToEnd.Tests/BundleSmokeTests.cs:157, src/Aspire.Cli/DotNet/DotNetCliRunner.cs:626, src/Aspire.Cli/Commands/AppHostStartupTimeout.cs:17]
  overlap_hints: [correctness.logic, tests.flaky]
