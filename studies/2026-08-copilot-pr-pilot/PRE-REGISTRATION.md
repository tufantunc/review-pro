# Pre-registration — "Reviewing AI-written code is a different problem"

Written **before** any review-pro run against the corpus. Nothing below may be
changed after the first run; changes get appended as dated amendments.

## The claim under test

Not: *"AI writes bad code."*
Not: *"AI code fails in ways human code never does."*

But: **the failure distribution shifts.** Specific categories — confidently
referencing things that don't exist, adding a dependency for something the repo
already solved, building an abstraction for one call site — occur at rates that
review rubrics written for human failure modes under-weight.

This is falsifiable. If the run surfaces few or none of these, the claim is
weakened and the article says so.

## What counts as a finding

One structured item emitted by review-pro with `file:line` + severity. Nothing
else counts — not prose in the summary, not a verdict.

## Classification (assigned by hand, after the run, per finding)

Every finding lands in exactly one bucket:

| Bucket | Test |
|---|---|
| **True positive** | The factual claim is independently verifiable AND the stated impact follows. |
| **False positive** | The factual claim is wrong (the symbol *does* exist, the config *is* defined), or the impact does not follow. |
| **Debatable** | Factually accurate, but whether it deserves flagging is a judgment call. |
| **Miss** | A real defect I find by reading the diff myself, in a category review-pro claims to cover, that it did not flag. |

**Debatable is not a hedge bucket.** It exists because the categories are not
equally falsifiable, which is the point below.

### Amendment, 2026-08-09 — added during the pilot, after case 2's tests review

A fifth bucket, because the four above could not express what actually turned up:

| Bucket | Test |
|---|---|
| **Sound finding, faulty reasoning** | The defect is real and independently verified, but a stated impact or remedy contains a factual error about the codebase. |

Recorded because forcing these into "true positive" hides a real cost — a reader
who acts on the faulty half does unnecessary work — while calling them false
positives misrepresents a correct finding. Counted and reported separately.

First instance: case 2, `tests` High #2. The core claim (no multi-page
pagination coverage) is verified true. Its supporting claim — that the
`RoutingHandler` test helper "returns one canned response for every request" and
would need reworking — is false: the helper takes a `Func<HttpRequestMessage,
HttpResponseMessage>` and existing tests already branch on the request
(lines 572, 606, 701). No harness change is needed. The reviewer's own remedy
even lists the branch-on-`after` option, contradicting its stated impact.

This bucket exists as of the pilot and applies to all cases, including case 1
retrospectively — case 1's findings are re-checked against it, not grandfathered.

## Falsifiable vs judgment categories — reported separately

This split is fixed now, not after seeing results.

**Falsifiable** — a claim that is objectively true or false:
- `ai-antipatterns.hallucination` — the symbol/import/signature exists, or it doesn't
- `ai-antipatterns.invented-config` — the key is defined somewhere, or it isn't
- `ai-antipatterns.needless-dep` — the repo already had that capability, or it didn't

**Judgment** — reasonable reviewers disagree:
- `ai-antipatterns.over-engineering`
- `ai-antipatterns.ignored-convention`
- style drift

**Strong claims in the article may only rest on the falsifiable categories.**
Judgment categories are reported, described, and explicitly not used as proof.
A false-positive rate is only computed for falsifiable categories; for judgment
categories the article reports counts and examples, not accuracy.

## Metrics reported (all of them, regardless of outcome)

1. Findings per diff, by severity and category.
2. **False-positive rate for falsifiable categories.** Published whatever it is.
3. Misses found by my own independent read.
4. Whether triage dispatched sensible reviewers per diff.
5. Any run that errored, hung, or produced malformed output.

## Corpus rules

**Corpus A — deliberate, reproducible.** A real open-source project. An agent
is given realistic feature/bugfix tasks. The resulting diff is used
**unmodified** — no cherry-picking a diff because it looks interesting, no
re-prompting because the output was too clean. Task list is fixed before the
first diff is generated.

**Corpus B — labeled real PRs.** Pull requests whose agent authorship is
documented by GitHub itself (`author:app/copilot-swe-agent`), not inferred from
vibes. If authorship cannot be evidenced, the PR is excluded.

Corpus B selection criteria, fixed now:

- **Merged only.** This is deliberate and makes the test harder: the code passed
  human review and shipped. Finding defects in *rejected* agent output would be a
  strawman.
- Diff between 30 and 400 changed lines — large enough to contain real logic,
  small enough to verify by hand.
- A language review-pro ships a stack pack for.
- A project with real users, not a scratch/demo/tutorial repo.
- Selected by recency within the query, not by browsing for promising-looking
  diffs. The first N matching the criteria are taken.

**Repos in Corpus B are anonymised in the article.** The argument is about a
pattern, not about naming maintainers who merged something. Excerpts are quoted
minimally, the repo list is kept privately and shared on request. Corpus A is
named in full, since the diffs are ours.

Selection criteria for both are fixed before results are seen.

### Amendment, 2026-08-09 (before any run)

The recency-ordered global query returns almost entirely 0–1 star personal and
scratch repositories, which fails the "project with real users" criterion already
stated above. Corpus B is therefore drawn from **merged agent-authored PRs in
established organisations** (`org:microsoft`, `org:github`, `org:dotnet`,
`org:Azure` — each has thousands), still taken by recency within the query rather
than by browsing for interesting diffs.

This tightens an existing criterion rather than introducing a new one, and is
recorded here because it was decided *before* any review-pro run. It also
strengthens the test: this is code that shipped into widely used software.

## Pilot first

Before building the full corpus, a **pilot of 3 Corpus B diffs** is run end to
end: review-pro, then hand verification. Purpose is to test the method, not to
produce the article's numbers.

The pilot's results are reported in the article regardless of outcome and are
included in all totals — it is not a discarded practice run. If the pilot shows
the falsifiable categories barely firing, that is a finding, and the article's
thesis gets weakened or rewritten rather than the pilot being buried.

## Anti-gaming rules

- **First run counts.** No re-running review-pro to get a nicer result. If a run
  is repeated for a technical reason (crash, truncation), both runs are reported.
- **No diff is dropped after seeing its findings.** A diff excluded for a
  structural reason (e.g. the agent produced nothing) is listed with the reason.
- **Self-review excluded.** review-pro is not run against review-pro's own
  repository for evidence purposes. Circular and self-serving.
- **n is small.** The article says "a pattern we observed", never "we showed" or
  "we proved". No percentages presented as population estimates.
- **Negative result gets published.** If review-pro performs poorly, or the
  falsifiable categories barely fire, that goes in the article.

## Observation recorded before the pilot run, 2026-08-09

Sizing 18 candidates from `org:dotnet` and `org:microsoft` showed the population
of *merged* agent-authored PRs in established organisations skews heavily
**mechanical**: version bumps (14 lines), dependency updates (16), lint allowlists
(16), disabling a flaky test (2), Ruff/mypy fixes (39). The rest were either
under 30 lines or well over 400 (467, 469, 1214, 2679).

This is uncomfortable for the thesis and is recorded before any run: if most
agent code that actually ships is mechanical, the surface for
"confidently references something that doesn't exist" is narrower than assumed.
It goes in the article either way.

The pilot proceeds with the three PRs selected by the stated criteria, two of
which are chores. No "substantive change only" criterion is added now, because
that decision would be made after seeing the population — any such criterion for
the main corpus will be added as a dated amendment that says exactly that.

### Pilot set (locked)

1. `dotnet/Nerdbank.GitVersioning#1438` — 72 lines, 2 files — managed Git first-parent support
2. `dotnet/extensions#7608` — 125 lines, 2 files — OpenAI dependency upgrade to 2.12.0
3. `microsoft/aspire#18671` — 48 lines, 4 files — harden daily CLI smoke tests

Excluded and worth naming: `dotnet/aspnetcore#64729` ("Fix JsonIgnore validation
bypass for write-only properties") at 408 lines — the most article-friendly title
in the pool, excluded for being 8 lines over the pre-registered ceiling.

### Amendment, 2026-08-09 — publication of the records

The corpus section above says the Corpus B repo list is "kept privately and
shared on request." Superseded at publication: the full per-case records —
including repository and PR identifiers — are published alongside this document,
because the study's claims are hand-verified and must be checkable. Two things
are kept from the original intent: the **article body** still does not name the
repositories, and the names of the human maintainers who reviewed or merged the
PRs are redacted from our records. They are visible on the public PRs; printing
them here would make the study read as being about people rather than about a
pattern.

## Conflict of interest

The article's author maintains review-pro. Stated plainly in the article, at the
top, not in a footnote.
