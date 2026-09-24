```
finding: tests/Aspire.Cli.EndToEnd.Tests/Helpers/CliE2EAutomatorHelpers.cs:34 The run startup budget is split into three public members that callers must pair by hand, when AspireStartAsync already has a one-parameter shape for this
verdict: partly_refuted
defect_stands: yes
claims:
  - claim: The PR adds three separate members for one budget (a constant, a ready timeout, a command builder), and nothing ties the command to the wait at a call site.
    status: true
    evidence: CliE2EAutomatorHelpers.cs:34 "internal const int AspireRunStartupBudgetSeconds = 180;", :41 "internal static TimeSpan AspireRunReadyTimeout => ...", :47 "internal static string GetAspireRunCommand()". All three are internal, not public as the title says, but that does not change the claim.
  - claim: AspireStartAsync already takes one budget parameter, turns it into ASPIRE_CLI_START_TIMEOUT and uses the same value for the terminal wait.
    status: true
    evidence: CliE2EAutomatorHelpers.cs:755 "TimeSpan? startTimeout = null", :759 "var effectiveTimeout = startTimeout ?? TimeSpan.FromMinutes(3);", :772 "var startupTimeoutSeconds = Math.Max(1, (int)Math.Ceiling(effectiveTimeout.TotalSeconds));", :776 "ASPIRE_CLI_START_TIMEOUT={startupTimeoutSeconds...} aspire start"
  - claim: BundleSmokeTests uses AspireRunReadyTimeout without GetAspireRunCommand.
    status: true
    evidence: BundleSmokeTests.cs:91 "dotnet run --no-launch-profile --project ..." followed by :96 "timeout: CliE2EAutomatorHelpers.AspireRunReadyTimeout"; the same pattern at :151 and :156 with "dotnet run apphost.cs"
  - claim: Each call site in the PR repeats the same sequence by hand: TypeAsync, EnterAsync, WaitUntilAsync with a ready predicate, Ctrl+C, then WaitForSuccessPromptAsync.
    status: true
    evidence: SmokeTests.cs:46-65, SmokeTests.cs:92-108 and DotnetToolSmokeTests.cs:87-105 each run TypeAsync(GetAspireRunCommand()), EnterAsync, WaitUntilAsync(... AspireRunReadyTimeout), Ctrl().KeyAsync(Hex1bKey.C), WaitForSuccessPromptAsync(counter)
  - claim: Seven other sites still launch a raw "aspire run", so the fix is not applied everywhere.
    status: true
    evidence: grep for TypeAsync(.*aspire run finds exactly JsReactTemplateTests.cs:37, JavaPolyglotTests.cs:71, TypeScriptPolyglotTests.cs:139 and :451, ConfigHealingTests.cs:70, ConfigDiscoveryTests.cs:73 ("aspire run --apphost {projectName}"), LocalConfigMigrationTests.cs:84. None of them sets ASPIRE_CLI_START_TIMEOUT.
  - claim: All seven of those sites use a hardcoded 3-minute wait for the ready message.
    status: false
    evidence: JsReactTemplateTests.cs:50 "}, timeout: TimeSpan.FromMinutes(2), description: \"Press CTRL+C message (aspire run started)\");". LocalConfigMigrationTests.cs:91 "var deadline = DateTime.UtcNow.AddMinutes(3);" is a poll for aspire.config.json to appear, not a wait for the ready message.
  - claim: The remedy says the other aspire run sites can adopt the proposed helper, which waits for "Press CTRL+C..." and throws when failIf matches.
    status: false
    evidence: ConfigDiscoveryTests.cs:86-88 treats an error as success: "return s.ContainsText(\"Press CTRL+C to stop the AppHost and exit.\") || s.ContainsText(\"ERR:\");". LocalConfigMigrationTests.cs:87-95 never waits for the ready message; it polls for a file and then sends Ctrl+C. The helper as described would change what both tests accept.
falls: Two details in the impact and remedy. Not all seven raw sites use a 3-minute ready wait: JsReactTemplateTests.cs:50 uses 2 minutes, and LocalConfigMigrationTests.cs:91 polls for a file instead of waiting for the ready message. The helper as described also cannot be dropped into every other site: ConfigDiscoveryTests.cs:87 accepts "ERR:" as an outcome, and LocalConfigMigrationTests never waits for ready.
stands_part: The core defect. One startup budget is spread over three separately called members (internal, not public) that each call site must pair by hand, while AspireStartAsync already uses a single budget parameter. BundleSmokeTests uses the timeout without the command, the launch sequence is repeated at every site, and seven aspire run sites still skip the budget, so there are two ways to launch aspire run.
unchecked: none
noticed: none
```
