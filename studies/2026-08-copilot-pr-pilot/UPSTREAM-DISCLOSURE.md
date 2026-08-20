# Upstream disclosure

The pilot found defects in code that is merged and shipping. Reporting them upstream
is the part that makes the study something other than a marketing exercise: if the
findings are real, the projects should have them; if they are not, the maintainers
will say so in public, on the record, next to the claim.

All four were filed on **2026-08-19**, ten days after the runs.

| Filed | Repo | Finding | Case |
|---|---|---|---|
| [#1474](https://github.com/dotnet/Nerdbank.GitVersioning/issues/1474) | dotnet/Nerdbank.GitVersioning | `GitRepository.Lookup` throws `GitException{ObjectNotFound}` where its signature promises `null`, so shallow clones lose the project's own diagnostic | [1](FINDINGS-case1.md) |
| [#1318](https://github.com/openai/openai-dotnet/issues/1318) | openai/openai-dotnet | `ContainerFileResource` guards `bytes` against JSON null but not `created_at`, so the `InvalidOperationException` of `#733` is still reachable | [2](FINDINGS-case2.md) |
| [#7707](https://github.com/dotnet/extensions/issues/7707) | dotnet/extensions | The removed `openai-dotnet#733` workaround defended two fields; upstream fixed one. Also corrects the PR's stated bump rationale | [2](FINDINGS-case2.md) |
| [#19540](https://github.com/microsoft/aspire/issues/19540) | microsoft/aspire | `AspireRunReadyTimeout` is applied to `dotnet run` sites where `ASPIRE_CLI_START_TIMEOUT` is never set, inverting its documented relationship | [3](FINDINGS-case3.md) |

Outcomes are not recorded above, because they are not ours to write. Follow the links.

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
