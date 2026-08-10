# Pilot case 3 — microsoft/aspire#18671

Anonymised in the article as "E2E test infrastructure in a large app framework". Included in the pilot **deliberately as a noise-floor test**: a 48-line chore diff, chosen to answer the strongest objection to fan-out review — "twelve agents will produce forty findings on anything."

## The PR

| | |
|---|---|
| Author | `Copilot` (GitHub agent) |
| Reviews | one maintainer approved; 0 inline review comments; Copilot's own review bot commented |
| Merged | yes |
| Size | 48 lines (38 insertions, 10 deletions), 4 files — test infrastructure only |
| Base / head | `5552e243` / `8eeb25bd` |

What it does: E2E CLI smoke tests were flaking because a cold NuGet restore + build under CI contention exceeds the CLI's default 120s AppHost startup timeout. The PR adds `AspireRunStartupBudgetSeconds = 180` (passed as `ASPIRE_CLI_START_TIMEOUT` via a shell prefix), an `AspireRunReadyTimeout` (budget + 60s) for the terminal-side wait, and a `GetAspireRunCommand()` helper — then applies them to three call sites.

## Triage proportionality

Dispatched **4** reviewers (`tests`, `ai-antipatterns`, `correctness`, `craft`), not 7 as in case 1. `security`, `performance`, `api-contract`, `db`, `frontend`, `a11y`, `backend` were excluded — test timeout constants have no security or API surface. Every dispatch prompt carried an explicit instruction: *"this is a small chore diff; if there is little to say, say little — do not pad the review to justify the dispatch."*

## My ground truth (written before dispatch)

1. **Falsifiable categories clean.** `ASPIRE_CLI_START_TIMEOUT` exists — `src/Aspire.Cli/CliConfigNames.cs:10`. No invented config. Verified before any reviewer ran.
2. **Partial application.** My grep found 6 files still typing bare `"aspire run"` after the PR, with the PR's own rationale applying to them.
3. **(My false positive.)** I flagged the helper for hard-coding the env-var name when "a canonical constant exists" (`CliConfigNames.AppHostStartupTimeout`).

## Reviewer results

| Reviewer | Findings | Notes |
|---|---|---|
| correctness | **0** | Verified the mechanics *positively* rather than staying silent: the driven shell is genuinely bash (`.WithPtyProcess("/bin/bash", ["--norc"])`, `CliE2ETestHelpers.cs:128`), `aspire` resolves to a real binary not an alias, `"180"` parses cleanly under `NumberStyles.None`, and the polyglot wait went 180s → 240s — previously *equal* to the budget, now correctly above it. |
| craft | 3 | Plus **five explicit non-flags** (below). |
| tests | 4 | Including the sharpest instance of the partial rollout. |
| ai-antipatterns | 4 | Including full verification of the env var's read path (`AppHostStartupTimeout.cs:17`, seconds, default 120 at `WaitCommand.cs:31`, env → config via `Program.cs:299`). |

11 raw findings → **6 distinct issues** after dedup.

## Hand-verified true positives

1. **The constant is misapplied to two `dotnet run` sites** — `BundleSmokeTests.cs:97` and `:157`. Found independently by **three** reviewers (tests, craft, ai-antipatterns). Those sites launch the AppHost via `dotnet run`, so the `ASPIRE_CLI_START_TIMEOUT` the constant is calibrated against is never set; the CLI budget in play is the built-in 120s default. The constant's documented invariant — "intentionally larger than the budget so the CLI's own timeout fires first, surfacing its diagnostic" — is false at those sites: a hang now burns 4 minutes instead of 2, with no compensating diagnostic.
   *Verified:* both sites type `dotnet run ...`; `WaitCommand.DefaultTimeoutSeconds = 120`; `AspireRunReadyTimeout => TimeSpan.FromSeconds(180 + 60)`.
   ai-antipatterns added the decisive sub-claim: the awaited string is a CLI-only resource (`PressCtrlCToStopAppHost`, emitted at `RunCommand.cs:861` — confirmed via the xlf translation files), so the CLI's 120s default *does* govern the bundle path, meaning the exact flake the PR targets is unmitigated there.

2. **Partial rollout.** The fix reaches 3 call sites; the same failure mode remains at `JsReactTemplateTests.cs:37` (a near-clone of the fixed smoke test, structurally identical down to the same issue-reference guard, and *more* exposed — it adds an npm install to the cold path — and the one remaining site where the terminal wait exactly equals the CLI budget, so the two timeouts race), plus `JavaPolyglotTests.cs:71`, `TypeScriptPolyglotTests.cs:139`/`:451`, `ConfigHealingTests.cs:70`.
   *Verified* by grep and by reading the excluded sites.

3. **The doc comment inverts the precedent it cites.** The new constant claims to "mirror the explicit budget `AspireStartAsync` already sets." `AspireStartAsync` derives the budget *from* the wait (`Math.Max(1, Ceiling(effectiveTimeout.TotalSeconds))` — budget == wait, line 772); the new code derives the wait from the budget (budget + 60). Opposite couplings.
   *Verified* at `CliE2EAutomatorHelpers.cs:772/776`.

4. **The back-compat comment is unfalsifiable and misses the real hazard.** "Older published CLIs simply ignore the env var" is a claim about external binaries this repo cannot check — and a tautology. The checkable safety property is the opposite direction: a CLI that *does* read the var errors out on any value failing `int.TryParse` or ≤ 0 (`AppHostStartupTimeout.cs:23-34`); 180 satisfies it. Flagged by ai-antipatterns.

## My false positive — refuted by the tool, three ways

I claimed the helper should use the canonical `CliConfigNames.AppHostStartupTimeout` constant instead of a string literal. Three independent refutations, all verified:

1. `CliConfigNames` is an `internal static class`.
2. `InternalsVisibleTo` is granted only to `Aspire.Cli.Tests` and `Aspire.Cli.Benchmarks` (`Aspire.Cli.csproj:206-207`); the E2E test project has **no** `ProjectReference` to `Aspire.Cli` at all (its only reference is `Aspire.TestUtilities`).
3. The literal is the file's pre-existing idiom — `AspireStartAsync` builds the identical prefix by hand at line 776. These tests type shell text at a *published* CLI binary in a container; binding to the source constant would be wrong even if it were reachable.

`craft` also pre-emptively told the `dry` reviewer not to flag it. My ground truth was wrong; the tool's was right.

My ground truth was also **less precise** on the partial rollout: I counted 6 leftover sites; `tests` correctly excluded two of them — `ConfigDiscoveryTests.cs:73` accepts `"ERR:"` as a pass condition, so a CLI timeout does not fail it, and `LocalConfigMigrationTests.cs:84` polls for a config file, not the ready message.

## The five explicit non-flags (craft)

Recorded because declining with reasons is the noise-floor behaviour this case exists to measure:

1. Extracting the timeout constants is a genuine improvement — direction not flagged.
2. String interpolation for the env prefix is the house idiom (`AspireStartAsync` does exactly this), and the class doc says shell commands are deliberately kept visible.
3. The "canonical constant" is unreachable (see above) — explicitly marked *do not flag*, including a note to the dry reviewer.
4. The verbose XML docs match the file's established register (multi-line "why" comments are the norm there); both factual claims in them about defaults check out.
5. The 1k-line rule: the helper file was already 1153 lines before the PR (1178 after) — decomposition is a pre-existing conversation, not this diff's debt.

## Cross-reviewer disagreement, correctly shaped

On the partial rollout, `tests` flagged it as a finding (the PR's own theory covers the untouched sites); `correctness` saw the same facts and scoped them out (*"untouched pre-existing code, out of diff scope"*). Both positions are defensible. This is precisely the conflict the synthesis stage resolves by domain ownership — coverage and flakiness belong to `tests`, so its call prevails. A single-agent review would never surface the tension at all.

## Noise-floor verdict

The objection this case was built to test — "fan-out review buries a trivial diff in noise" — did not materialise: triage cut the panel from 7 to 4, one reviewer returned zero findings while positively verifying the mechanics, another declined five would-be findings with located reasons, and the findings that *were* returned converged (three reviewers on the `dotnet run` misapplication) rather than sprawling. The tool also out-precisioned my own ground truth on this diff, in both directions — rejecting my false positive and refining my overcounted rollout list.
