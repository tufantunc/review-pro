# Pilot case 1 — dotnet/Nerdbank.GitVersioning#1438

Anonymised in the article as "a .NET versioning library". Recorded here in full for verifiability.

## The PR

| | |
|---|---|
| Author | `Copilot` (GitHub agent) |
| Approved by | project owner, `APPROVED` with an empty review body |
| Inline review comments | 0 |
| Issue comments | 0 |
| CI | 12/12 green |
| Merged | 2026-08-09 07:20 UTC |
| Size | 71 lines, 2 files |
| Fixes | a real regression (#572) — `HEAD~2` stopped resolving in the managed engine |

Selected by the pre-registered recency criteria, not by browsing. Stack pack `dotnet` installed, as a .NET user would.

## Reviewers dispatched (7)

| Reviewer | Findings |
|---|---|
| security | **0** — traced each vector, declined to report |
| performance | **0** — traced loop termination, declined; named 2 things it chose not to report |
| ai-antipatterns | 2 (both `ignored-convention`) |
| api-contract | 3 (1 High) |
| correctness | 3 (1 High) |
| craft | 4 (1 High) |
| tests | 6 (2 High) |

18 raw findings → 13 distinct issues after dedup.

## Falsifiable categories: ZERO

No hallucinated API/symbol/import. No invented config key. No needless dependency.

Verified independently twice — by hand and by the ai-antipatterns reviewer:
- `using System.Globalization` present (GitRepository.cs:7)
- `GitCommit.FirstParent` exists (GitCommit.cs:29)
- `GetCommit(GitObjectId, bool)` exists (GitRepository.cs:329)
- `System.Linq` covered by `<ImplicitUsings>enable</ImplicitUsings>`

**This is a negative result for the naive thesis** and goes in the article as such.

## Hand-verified true positives

1. **`Lookup` throws where its contract says null.** Flagged independently by api-contract (High), correctness (High), craft (Medium), ai-antipatterns (Medium). `GetCommit` throws `GitException{ObjectNotFound}` (line 334). Triggers: shallow clone at the graft boundary, annotated tag, unvalidated 40-char SHA. Consumer impact traced to `nbgv`: regresses from `BadGitRef` + "rev-parse produced no commit" to `InternalError` + raw object-not-found.
   *Verified:* GetCommit does throw; `ManagedGitContext.TrySelectCommit` has no try/catch.

2. **The repo's own shallow-clone convention was ignored.** `VersionOracle.cs:69-72` already has `catch (GitException ex) when (context.IsShallow && ex.ErrorCode == ObjectNotFound)` with the comment *"Our managed git implementation throws this on shallow clones."* The new code sits outside that guard.
   *Verified:* guard and comment exist verbatim.

3. **Annotated tags are never peeled**, so `<tag>~1` cannot resolve — arguably the headline use case for a tag-driven versioning tool, and newly advertised by the doc comment this PR edited.
   *Verified:* packed-refs loop discards the peel line (`foreach ((string line, string? _)`); `LookupTags` (line 717) *does* peel via `GitAnnotatedTagReader`, so the codebase knows how; the existing tag test uses `Tags.Add(name, tip)` — a lightweight tag — so annotated tags are untested.

4. **Chained `~` operators untested.** The `while` loop exists solely for `HEAD~1~1` / `HEAD~~`; both added test cases contain exactly one `~`, so the loop never re-enters on a success path.
   *Verified* from the diff.

## Notable methodology results

**Two of seven reviewers reported nothing**, with traced reasoning. `performance` explicitly listed two findings it considered and rejected as below the bar (Substring allocations, the new `IndexOf` on every call). No manufactured findings to justify the dispatch.

**My own false positive was rejected by two reviewers independently.** I noted "`HEAD~2000000000` is an unbounded loop" on first read. Both performance and security traced that the loop terminates at `parent is null`, i.e. bounded by history depth, and both cited the PR's own `HEAD~999` test as proof. Had I written it up unverified, the article would have shipped a false claim about false claims.

**The best evidence came from the commit history, which I had not read.** `craft` found the PR's own head commit `a31b5c3` — *"Fix net472 commitish parsing build"* — which changes `objectish.AsSpan(...)` to `objectish.Substring(...)` because the span overload of `int.TryParse` doesn't exist on net472. The hand-rolled index arithmetic had already cost a build break inside the same PR.
*Verified:* commit and diff confirmed.

**Four reviewers converged on one issue from four angles** (contract, error path, maintainability, convention) and synthesis collapsed them into one High. That is the fan-out + dedup design doing its job.

## Fairness note for the article

The PR fixes a real regression, the common path works, and the tests added are reasonable. The agent did competent work. The defects are at the edges — shallow clones, annotated tags — reachable only by tracing call chains rather than reading the diff. The honest sentence is: *twelve green checks and an approval are not the same as someone having traced the shallow-clone path.* Not a criticism of the maintainer.
