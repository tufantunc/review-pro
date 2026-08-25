# Replay of case 2, without a hand-written mandate

The acceptance test for [#13](https://github.com/tufantunc/review-pro/issues/13).

In the [original pilot](FINDINGS-case2.md), two reviewers left the repository to check
whether the removed workaround's premise held, and one of them, `ai-antipatterns`, had
been **explicitly told to** in a hand-written dispatch prompt. Only `correctness` went on
its own initiative. That hand is the whole of what #13 removes, so the test is the same
diff with no mandate written anywhere.

## What was replayed

[dotnet/extensions#7608](https://github.com/dotnet/extensions/pull/7608), merged
2026-07-08, base `7e8c785`, head `868c710`. Two files: `eng/packages/General.props` bumps
`OpenAI` from 2.11.0 to 2.12.0, and `OpenAIHostedFileClient.cs` deletes 96 lines of
hand-rolled raw-JSON parsing in favour of the SDK's typed APIs.

The premise appears in **both** channels the hybrid design splits between, which makes
this a better test than expected:

- Commit `78798963`, "Remove workaround for openai-dotnet/issues/733". A commit message
  is triage's channel, because reviewers never see one.
- The deleted code's own comments, citing `openai-dotnet#733` and the claim that "the
  SDK's typed deserialization crashes on container files with a null `bytes` value". Code
  comments are the reviewer's channel, since the diff is already in its context.

Inputs were reconstructed from the live PR rather than by cloning the monorepo: the diff,
both changed files at the head SHA, the commit messages, and the PR body, all fetched
through `gh`.

## The first attempt was a false negative, and the reason matters

Stage A was first run by dispatching the `review-pro-triage-subagent` agent type. It
returned a plan with no `external_premises` at all. Read at face value, that says the
feature does not fire.

It says nothing of the kind. That agent type auto-loads the `review-pro-triage` skill
from the **installed** plugin, and the installed copy is v1.0.0:

```
$ grep -c external_premises ~/.claude/skills/review-pro-triage/SKILL.md
0
```

The branch's step 7 was never in the subagent's context. Worth recording as its own
lesson: **when dogfooding a change to a skill, the subagent path loads the installed
copy, not the working tree.** A reviewer's silence about a brand-new rule is the expected
result of testing the old rule, and it is indistinguishable from the rule failing.

The replay was re-run by pointing a general-purpose agent at the branch's skill files and
telling it that those files win over anything already in its context. That is the same
inline path `review-pro/SKILL.md` already documents for platforms without subagents. The
user's global install was deliberately left alone.

**So this replay exercises the branch's rubric text and does not exercise the packaging
or install path.** That a real install carries the new sections is a separate check, owed
at release time.

## Stage A: triage, with no mandate

Triage emitted three premises and dispatched the two reviewers it assigned them to:

```yaml
external_premises:
  - claim: "Remove workaround for openai-dotnet/issues/733"
    cited: openai-dotnet#733
    source: commit-message
    pinned: OpenAI 2.11.0 -> 2.12.0
    owner: correctness
  - claim: "`ContainerClient.GetContainerFilesAsync` changed its signature from five flat parameters to a `ContainerFileCollectionOptions` object."
    source: pr-body
    owner: api-contract
  - claim: "The other 2.12.0 breaking changes ... are all in experimental APIs not referenced by this codebase."
    source: pr-body
    owner: api-contract
```

Three things went right that the design specifically calls for. The `#733` premise came
out of a **commit message**, the channel no reviewer can see. Its owner is `correctness`,
which the owner table assigns for a behaviour-equivalence claim across a dependency
change, rather than the `ai-antipatterns` default. And `pinned` was filled from the diff,
so the version the claim has to hold at was fixed before any reviewer looked.

Three premises is exactly the cap, and nothing was dropped, so `premises_dropped` was
correctly absent.

## Stage B: the owning reviewer, still with no mandate

`correctness` was handed the diff, the changed files, and its one premise. It was told
nothing about going upstream.

It worked the channel order in order, and recorded where it ended up:

```
## Premise verification
- premise: "Remove workaround for openai-dotnet/issues/733"
  cited: openai-dotnet#733, pinned OpenAI 2.11.0 -> 2.12.0
  settled_by: network
  outcome: contradicted
  finding: correctness.error-path
```

The local package cache had no `OpenAI` package. `General.props` fixes the version but
cannot say whether the bug is gone. Only then did it reach for the network, and it said
so rather than leaving the reader to guess whether the answer was reproducible.

What it found is the pilot's hand-verified conclusion, reached without the hand:

- Issue #733 was closed by
  [openai-dotnet#1054](https://github.com/openai/openai-dotnet/pull/1054), and that fix
  is contained in the `OpenAI_2.10.0` tag, so it was already present in 2.11.0, the
  version the repo was on before this bump.
- **PR #1054 hardened only the `bytes` field.** In `ContainerFileResource.Serialization.cs`
  at tag `OpenAI_2.12.0`, `created_at` at line 174 calls `.GetInt64()` with no null
  guard, while `bytes` at lines 179 to 187 has the `JsonValueKind.Null` guard the fix
  added. The deleted workaround defended every field individually, `created_at` included.

Both claims were verified independently of the reviewer before this was written:
`gh api repos/openai/openai-dotnet/compare/5031620...OpenAI_2.10.0` returns
`behind_by: 0`, and the two line numbers are exact.

The finding was filed as Medium under an existing root, with `confidence: medium` and
`evidence_refs` naming the upstream file at the tag rather than a bare issue number.

## Verdict against the issue's acceptance criterion

The criterion was: a diff whose justification cites an external artifact gets either a
finding grounded in that artifact's actual source, or an explicit statement that it could
not be verified externally.

Met, by the first branch. The premise was extracted from a channel no reviewer can see,
routed to one owner, verified against upstream source at a pinned tag, and reported as
contradicted with the channel that settled it named. In the pilot this required telling a
reviewer to do it.

## One drift worth recording

The reviewer filed under `correctness.error-path`. The five subcategories the rubric
lists are `logic`, `error-handling`, `concurrency`, `devex`, and `feature-gate`. Nothing
breaks, because the dedup key and the registry both work on the **root**, and
`correctness` is a registered root. The rubric also introduces subcategories as "category
roots like ...", so they were never a closed set. Left alone rather than tightened:
enumerating them would fight a deliberate looseness in the existing design.
