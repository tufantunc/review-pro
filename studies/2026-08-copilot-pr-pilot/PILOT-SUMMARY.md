# Pilot summary — 3 merged agent-authored PRs in established .NET orgs

15 reviewer runs. ~43 raw findings. Every finding used in the article was verified by hand against the repo or upstream source.

## The corpus

All three: authored by `Copilot`, **merged**, green CI, selected by pre-registered recency criteria from `org:dotnet` / `org:microsoft`.

| | Case 1 | Case 2 | Case 3 |
|---|---|---|---|
| Repo | Nerdbank.GitVersioning | dotnet/extensions | microsoft/aspire |
| Change | core objectish parsing | shipped library + dep bump | E2E test infra |
| Lines | 71 | 125 | 48 |
| Human review | **0 comments**, empty approval | 3 inline, **2 approvals** | 0 inline, 1 approval |
| Reviewers dispatched | **7** | 4 | 4 |
| Reviewers reporting nothing | **2** (security, performance) | 0 | **1** (correctness) |
| Raw findings | 18 | 14 | 11 |
| Distinct after dedup | 13 | 10 | 6 |

Triage proportionality is real: 7 reviewers on core parsing logic, 4 on test infrastructure. `security`, `performance`, `api-contract`, `db`, `frontend`, `a11y`, `backend` were all correctly excluded from the test-infra diff.

## The thesis result — the naive version does not survive

**Falsifiable AI-antipattern categories fired once in three cases.**

| Category | Case 1 | Case 2 | Case 3 |
|---|---|---|---|
| hallucinated API/symbol/import | 0 | 0 | 0 |
| invented config key | 0 | 0 | 0 |
| needless dependency | 0 | **1** | 0 |

Every symbol, import, and config key these agents wrote **existed**. Verified twice per case — by hand and by the reviewer. "AI hallucinates APIs" is not what shipped agent code in serious repos looks like.

**What did fire, repeatedly and substantively, was `ignored-convention`.** The agents didn't invent things. They failed to notice what the repository already knew:

- **Case 1** — the repo has a canonical shallow-clone guard at `VersionOracle.cs:69-72`, with the comment *"Our managed git implementation throws this on shallow clones."* The new code sits outside it, so `nbgv get-version -v HEAD~1` in a shallow CI clone regresses from a clean `BadGitRef` to a raw `InternalError`. The repo also knows how to peel annotated tags (`LookupTags`, line 717) — the new code doesn't, so `<release-tag>~1` cannot resolve at all, arguably the headline use case for a tag-driven versioning tool.
- **Case 2** — the deleted workaround defended `created_at` as well as `bytes`. Upstream fixed exactly one field. Verified from `raw.githubusercontent.com` at both tags: `bytes` has `if (prop.Value.ValueKind == JsonValueKind.Null)`, `created_at` has `DateTimeOffset.FromUnixTimeSeconds(prop.Value.GetInt64())` with no guard, against a non-nullable `DateTimeOffset CreatedAt`. The exact exception class of the bug being "fixed" is still reachable, on a different field.
- **Case 3** — the constant's own doc comment claims it "mirrors the explicit budget `AspireStartAsync` already sets." It inverts it: `AspireStartAsync` derives budget *from* wait (`budget == wait`), the new code derives wait from budget (`budget + 60`). Opposite couplings.

**This is a better thesis than the one we started with, and the data earned it.** The failure mode of shipped agent code is not invention. It is *plausible local correctness with no memory of the codebase's accumulated knowledge* — and that is precisely what a diff-reading reviewer cannot catch, because the evidence lives in files the diff never touches.

## Case 2's bump rationale was false

The PR frames `OpenAI 2.11.0 → 2.12.0` as the enabler for dropping the `openai-dotnet#733` workarounds. Verified: the null-`bytes` guard is **already present in 2.11.0**, the version the repo was on. The bump is needed only because `ListFilesAsync` was reshaped to 2.12.0's `ContainerFileCollectionOptions(string containerId)` ctor. Two reviewers independently went upstream, cloned both tags, and reached this; I verified it myself.

Two human approvals did not catch it.

## Why green CI proved nothing

Case 2's test suite is real — 922 lines driving the actual SDK over a fake `HttpMessageHandler`. It still could not test the PR's central premise:

- `grep -rn '"bytes"[[:space:]]*:[[:space:]]*null' test/` → **zero hits.** Fixtures only *omit* the field. Omission and explicit null are different deserializer paths, and #733 was specifically about explicit null.
- The only `has_more` in the project is `false`. The pagination rewrite has **no multi-page coverage** — and #733 was reported as crashing *during auto-pagination*.

So the suite passes identically whether the SDK bug is fixed or not. Twelve green checks in case 1, green CI in cases 2 and 3, and in no case did CI touch the actual risk.

## Against the tool — recorded because the article needs it

**One sound finding with faulty reasoning.** Case 2, `tests` High #2: the core claim (no multi-page coverage) is true; its supporting claim — that the `RoutingHandler` helper returns one canned response and needs reworking — is false. It takes a `Func<HttpRequestMessage, HttpResponseMessage>` and existing tests already branch on the request (lines 572, 606, 701). A reader acting on it does an unnecessary refactor.

**A real limitation: external fact-checking is not automatic.** In case 2, `tests` and `api-contract` both correctly flagged the #733 premise as unverified *by the repo* — but neither went upstream to check whether it was true. Only `ai-antipatterns` and `correctness` did, and `ai-antipatterns` had been explicitly told to. Repo-grounded verification is reliable; leaving the repo depends on the reviewer's mandate.

**One cross-reviewer disagreement, correctly shaped.** On case 3's partial rollout, `tests` flagged it; `correctness` saw the same thing and scoped it out as pre-existing. Both defensible — this is what synthesis exists to resolve by domain ownership. A single agent would never surface the tension.

## For the tool — the part that surprised me

**It corrected the author twice.** Both of my own findings, written before dispatch, were wrong:

| My claim | Refuted by | Why I was wrong |
|---|---|---|
| `HEAD~2000000000` is an unbounded loop (case 1) | `performance`, `security` | The loop exits at `parent is null` — bounded by history depth. Both cited the PR's own `HEAD~999` test. |
| The helper hard-codes an env-var name when a canonical constant exists (case 3) | `craft`, `ai-antipatterns` | `CliConfigNames` is `internal`; `InternalsVisibleTo` grants only `Aspire.Cli.Tests`/`Benchmarks`; the test csproj has no reference. Unreachable — and the literal is the file's pre-existing idiom. |

My ground truth was also **less precise** than the tool's on case 3's partial rollout: I grepped 6 sites, the reviewer correctly excluded two (`ConfigDiscoveryTests` accepts `"ERR:"` as a pass; `LocalConfigMigrationTests` polls for a file, not the ready message).

**It found what I missed.** `craft` read the PR's own commit history and found head commit `a31b5c3` — *"Fix net472 commitish parsing build"* — changing `AsSpan(...)` to `Substring(...)` because the span overload of `int.TryParse` doesn't exist on net472. The hand-rolled index arithmetic had already cost a build break inside the same PR. I had read the diff, not the history.

**Silence with reasoning, not silence by omission.** `performance` listed two findings it considered and rejected as below the bar. `craft` on case 3 explicitly declined five, including telling the `dry` reviewer not to flag the constant. `api-contract` investigated two hypotheses I planted in its prompt and rejected both with evidence I verified.

**Calibrated uncertainty.** `api-contract` set `confidence: low` on the one thing it couldn't settle, stating plainly that the OpenAI package was absent from the local NuGet cache.

## Conflict of interest

The author maintains review-pro. Stated at the top of the article, not in a footnote. The pre-registration, the corpus selection, and the two author-side false positives are published with it.
