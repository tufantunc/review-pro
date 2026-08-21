# Upstream disclosure

The pilot found defects in code that is merged and shipping. Reporting them upstream
is the part that makes the study something other than a marketing exercise: if the
findings are real, the projects should have them; if they are not, the maintainers
will say so in public, on the record, next to the claim.

All four were filed on **2026-08-19**, ten days after the runs. Outcomes below, recorded 2026-08-21.

| Filed | Repo | Finding | Case |
|---|---|---|---|
| [#1474](https://github.com/dotnet/Nerdbank.GitVersioning/issues/1474) | dotnet/Nerdbank.GitVersioning | `GitRepository.Lookup` throws `GitException{ObjectNotFound}` where its signature promises `null`, so shallow clones lose the project's own diagnostic | [1](FINDINGS-case1.md) |
| [#1318](https://github.com/openai/openai-dotnet/issues/1318) | openai/openai-dotnet | `ContainerFileResource` guards `bytes` against JSON null but not `created_at`, so the `InvalidOperationException` of `#733` is still reachable | [2](FINDINGS-case2.md) |
| [#7707](https://github.com/dotnet/extensions/issues/7707) | dotnet/extensions | The removed `openai-dotnet#733` workaround defended two fields; upstream fixed one. Also corrects the PR's stated bump rationale | [2](FINDINGS-case2.md) |
| [#19540](https://github.com/microsoft/aspire/issues/19540) | microsoft/aspire | `AspireRunReadyTimeout` is applied to `dotnet run` sites where `ASPIRE_CLI_START_TIMEOUT` is never set, inverting its documented relationship | [3](FINDINGS-case3.md) |

Outcomes are not ours to write, but they are ours to record once written. As of
2026-08-21:

| | Outcome |
|---|---|
| [#1474](https://github.com/dotnet/Nerdbank.GitVersioning/issues/1474) | **Fixed.** The maintainer opened and merged [#1475](https://github.com/dotnet/Nerdbank.GitVersioning/pull/1475) the same day, "Fix shallow clone ancestor lookup diagnostics", closing this with `Fixes #1474`. He took the first of the two directions the report offered: `Lookup` keeps its nullable contract and reports a missing-ancestor cause, which the managed context converts into the project's existing shallow-clone diagnostic. He also added regression tests for both the missing ancestor and shallow commit selection. |
| [#1318](https://github.com/openai/openai-dotnet/issues/1318) | **Answered, not a defect.** `created_at` is a required property in the OpenAI REST API specification, so the service guarantees it is never null and the asymmetry with the nullable `bytes` is intentional. Throwing on a payload that violates the contract is the intended behaviour. This is the outcome the issue named as its own most likely resolution, and the maintainer answered on exactly those terms. |
| [#7707](https://github.com/dotnet/extensions/issues/7707) | **Withdrawn by us.** Its premise was that dropping the `openai-dotnet` workaround left this library exposed on `created_at`. The answer above removes that premise, so we closed it rather than leave a refuted issue open in someone else's repository. Its second point, that the version bump's stated rationale was wrong, stands but needs no code change and did not justify an open issue by itself. |
| [#19540](https://github.com/microsoft/aspire/issues/19540) | Open, awaiting an area label. |

## What the outcomes say about the method

One of four was a defect the maintainer chose to fix, within a day, taking the
remedy direction the report suggested. One was answered as not-a-defect on the
exact terms the report set out for itself. One we withdrew once that answer
landed. One is still waiting.

Read that as the honest yield: this is not four confirmed bugs. It is one fixed,
one well-formed question with a definitive answer, and one report that the answer
invalidated. The pilot's claim was about where defects live, not about how many
of them a maintainer will agree to fix, and a 1-in-4 fix rate on hand-verified
findings in mature .NET repositories is a result worth stating plainly rather
than rounding up.

The withdrawal matters more than the fix for judging the method. A study that
publishes its own false positives has to withdraw the ones that survive to
filing, too, and do it in the other project's repository where the cost is
visible.

## Every finding was re-verified before filing

The pilot ran on 2026-08-09 against the repositories as they stood. Ten days is long
enough for a fix to land, and filing an already-fixed bug spends a maintainer's
attention on nothing. So each claim was re-checked against upstream `main` on the day
of filing, at a pinned commit, and every permalink in the issues points at that SHA
rather than at a branch, so the cited line numbers cannot drift.

All four were still live. One had spread: the aspire pattern appeared at two call
sites when the pilot ran and at three by the time it was filed.

## Two things the re-check changed

Recorded because they are the substance of the exercise, not incidental to it.

**One finding was withdrawn before filing.** Case 1 reported two defects: the missing
shallow-clone guard and the failure to peel annotated tags. The second one already
exists upstream as
[#718](https://github.com/dotnet/Nerdbank.GitVersioning/issues/718), reported in 2022
by a real user with a stack trace, and closed as `NOT_PLANNED` by the maintainer
himself in August 2025 after he had earlier written "we should get this fixed". A
maintainer who declines a fix for three and a half years and then closes it has made a
decision. Re-filing it as new would have been asking him to make it again.

The filed issue therefore covers only the shallow-clone half, which is unreported, and
cites #718 as context with an explicit note that it is not asking for a reversal. The
finding in [`FINDINGS-case1.md`](FINDINGS-case1.md) stands as written: it was correct
about the code. It was simply not new.

**One finding was wrong in a way the case file did not catch.** Case 3's secondary
claim listed the `aspire run` call sites the fix had not reached, and described them as
sharing the inverted-invariant problem. Re-reading them showed otherwise: those sites
never apply the constant at all, so nothing is inverted there. What is true is narrower
and different, that the cold-start flake the original PR set out to fix is unmitigated
on those paths. One line number in the case file was also off by one.

Both were corrected in the issue rather than filed as written.

## What was deliberately left out of the issues

- **No mention that the PRs were agent-authored.** True, and central to the study, but
  in a bug report it adds nothing a maintainer can act on and invites a defensive
  reading. The question in an issue is whether the code is wrong.
- **No pitch.** One neutral sentence of disclosure at the foot of each issue, naming
  the conflict of interest and nothing else. A bug report that doubles as an
  advertisement gets read as an advertisement.
- **No claim of a reproduction that does not exist.** All four were found by reading
  source, not by triggering a failure, and each issue says so in its own words. Two go
  further and name the condition under which the report is not a bug at all: for
  openai-dotnet, that the service may never emit `"created_at": null`.

That last one matters for reading whatever happens next. A maintainer closing one of
these because the unguarded path is unreachable in practice is not a refutation of the
finding. It is the answer to a question the issue asked.
