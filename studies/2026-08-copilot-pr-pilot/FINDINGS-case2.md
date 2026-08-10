# Pilot case 2 — dotnet/extensions#7608

Anonymised in the article as "a Microsoft AI extensions library".

## The PR

| | |
|---|---|
| Author | `Copilot` (GitHub agent) |
| Reviews | **two maintainers approved**, 3 inline comments, Copilot's own review bot commented |
| Merged | yes |
| Size | 125 lines (28 insertions, 97 deletions), 2 files |
| Test files changed | **none** |

Contrast with case 1: this PR got *genuine* human review — two independent approvals and inline discussion. Case 1 had zero comments. Both merged.

## What the PR does

Bumps `OpenAI` 2.11.0 → 2.12.0 and deletes ~97 lines of hand-rolled raw-JSON parsing and manual pagination from `OpenAIHostedFileClient.cs`, replacing them with the SDK's typed APIs. The deleted code carried comments citing `openai/openai-dotnet#733` — "the SDK's typed deserialization crashes on container files with a null `bytes` value".

## Reviewers dispatched (4)

| Reviewer | Findings |
|---|---|
| ai-antipatterns | 2 (1 Medium `needless-dep`, 1 Low `confidently-wrong`) |
| correctness | 1 Low + a long list of explicitly verified non-findings |
| api-contract | 5 (2 Medium, 3 Low) + 4 explicitly rejected concerns |
| tests | 6 (2 High, 3 Medium, 1 Low) |

## The centerpiece finding — verified from upstream source by hand

Two reviewers independently went to the OpenAI SDK sources at both tags and converged on the same thing. I verified it myself from `raw.githubusercontent.com` at `OpenAI_2.11.0` and `OpenAI_2.12.0`:

```csharp
// bytes — null guard present in BOTH 2.11.0 and 2.12.0
if (prop.NameEquals("bytes"u8))
{
    if (prop.Value.ValueKind == JsonValueKind.Null) { sizeInBytes = null; continue; }

// created_at — NO guard in either version
if (prop.NameEquals("created_at"u8))
{
    createdAt = DateTimeOffset.FromUnixTimeSeconds(prop.Value.GetInt64());
```

And the type declarations in 2.12.0: `public long? SizeInBytes` (nullable) vs `public DateTimeOffset CreatedAt` (**non-nullable**).

Two consequences, both verified:

1. **The bump's stated rationale is false.** The #733 fix was already in 2.11.0 — the version the repo was on. The bump is required only because `ListFilesAsync` was reshaped to 2.12.0's `ContainerFileCollectionOptions(string containerId)` ctor form; 2.11.0 exposes the same typed auto-paginating API with `containerId` as a separate argument. The dependency change is self-inflicted, and it raises the floor for every downstream consumer of a shipped package.

2. **The removed guard was broader than the upstream fix.** The deleted code defended `created_at` too, with a `ValueKind is JsonValueKind.Number` check. Upstream fixed exactly one field. A `"created_at": null` on the wire now reproduces the identical `InvalidOperationException` that #733 was filed for. An absent `created_at` silently becomes `0001-01-01` instead of null.

This is the sharpest illustration of the thesis in the pilot: an agent removed a broad defensive guard on the strength of a narrow upstream fix, and framed the dependency bump with a rationale that does not hold — while two human reviewers approved it.

## Why CI could not catch it

`tests` established, and I verified: **no fixture anywhere in the test project sends `"bytes": null`** — `grep -rn '"bytes"[[:space:]]*:[[:space:]]*null' test/` returns nothing. Fixtures only *omit* the field, which is a different deserializer path. So the suite passes identically whether the SDK bug is fixed or not. It gives the rewrite a green light on the one risk it exists to manage.

Also verified: the only `has_more` in the project is `false`, so the pagination rewrite has zero multi-page coverage — and #733 was reported as crashing *during auto-pagination* specifically.

## Reviewers rejecting the interviewer's premises

I deliberately planted two hypotheses in the api-contract prompt. It investigated and rejected both, with evidence I verified:

- **Experimental `OPENAI001` dependency** — not a finding. ~35 existing suppressions across the library (`OpenAIChatClient.cs` alone has 18), file-level ones at `OpenAISpeechToTextClient.cs:17` and `OpenAITextToSpeechClient.cs:16`, the class is itself `internal sealed` + `[Experimental(...AIFiles)]`, and the only `.csproj` `NoWarn` is `CA1063` — never a blanket OPENAI001 suppression. The diff follows the established convention.
- **Silent `MissingMethodException` from a resolved-down dependency** — not a finding. Central Package Management, single `PackageVersion` source, and a downgrade surfaces as NU1605 (a build error), not a runtime failure.

It also set `confidence: low` on the one finding it could not settle offline, stating plainly that the OpenAI package was not in the local NuGet cache.

## Classification

**Falsifiable categories: 1 finding** — `ai-antipatterns.needless-dep` (the unnecessary version bump). Verified true. Contrast with case 1, which had zero.

**Hand-verified true positives:** the `created_at` regression (2 reviewers), the false bump rationale (2 reviewers), the missing `"bytes": null` fixture, the missing multi-page coverage.

**Sound finding, faulty reasoning: 1.** `tests` High #2 claimed the `RoutingHandler` helper "returns one canned response for every request" and would need reworking to script a second page. False — it takes a `Func<HttpRequestMessage, HttpResponseMessage>` and existing tests already branch on the request (lines 572, 606, 701). The core claim (no multi-page coverage) is true; the harness-limitation rationale is not. A reader acting on it would do an unnecessary refactor.

**A real limitation, worth stating in the article:** `tests` and `api-contract` both flagged the #733 premise as *unverified by the repo* — correct — but neither went upstream to check whether it was actually true. Only `ai-antipatterns` and `correctness` did, and `ai-antipatterns` had been explicitly told to. So repo-grounded verification is reliable; external fact-checking depends on the reviewer's mandate rather than being automatic.
