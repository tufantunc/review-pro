# Pilot study: review-pro vs. merged Copilot PRs (August 2026)

A pre-registered pilot: review-pro run against **three merged, agent-authored pull requests** in established .NET organisations, with every finding used in the write-up verified by hand against the repository or upstream source.

**Headline result:** the falsifiable AI-antipattern categories (hallucinated APIs, invented config, needless dependencies) fired **once across three cases**. What fired repeatedly was `ignored-convention` — locally plausible code written without the codebase's accumulated knowledge: an existing shallow-clone guard, an upstream deserializer's actual nullability, a sibling helper's coupling direction. The full argument lives in [the article](https://dev.to/tufan_tunc/the-agent-didnt-hallucinate-it-ignored-what-the-repo-already-knew-2m44); the evidence lives here.

## Contents

| File | What it is |
|---|---|
| [`PRE-REGISTRATION.md`](PRE-REGISTRATION.md) | The claim under test, corpus criteria, classification buckets, anti-gaming rules — written before the first run, with mid-study decisions recorded as dated amendments |
| [`PILOT-SUMMARY.md`](PILOT-SUMMARY.md) | Cross-case results, including the negative result and the author's own false positives |
| [`FINDINGS-case1.md`](FINDINGS-case1.md) | A .NET versioning library — 71 lines, merged with zero review comments |
| [`FINDINGS-case2.md`](FINDINGS-case2.md) | An AI extensions library — 125 lines, merged with two human approvals |
| [`FINDINGS-case3.md`](FINDINGS-case3.md) | E2E test infrastructure — 48-line chore, included as a noise-floor test |
| [`UPSTREAM-DISCLOSURE.md`](UPSTREAM-DISCLOSURE.md) | The four issues filed upstream, what the pre-filing re-check changed, and the one finding withdrawn as already-declined |

## Timeline, honestly

This study was designed and run in a single working session on **2026-08-09**. The pre-registration was written **before the first review-pro run** and maintained during the study; the decisions taken mid-study (the corpus-source tightening, the fifth classification bucket, the publication of these records) are dated amendments in the document, not silent edits.

These files were committed to this repository **at publication time, after the runs**. The git timestamp therefore does not prove pre-registration, and we are not claiming it does. The evidence for the discipline is internal: the document records decisions that cut against the tool (the mechanical-skew observation, a finding with faulty reasoning, two author false positives) which no one polishing a marketing narrative would have kept.

## Conflict of interest

The study's author maintains review-pro. The instrument was evaluating itself, run by the person with the most to gain — which is why the method leans on pre-committed criteria, hand verification of every claim, and publication of everything that went against the tool.

## Naming

The case records identify the repositories and PRs in full, because "verified by hand" must be checkable. The **article** built on this study does not name them, and the human maintainers who reviewed or merged the PRs are not named in these records — they are visible on the public PRs, but this study is about a pattern in agent-written code, not about the people who merged it. All three PRs fix real problems and do competent work; the defects are at the edges, reachable only by tracing call chains the diff never shows.

## Tool version

review-pro core at repository commit `646a007` (v0.4.1 skills/agents), run with the `dotnet` stack pack installed in each corpus repo, orchestrated from Claude Code. Reviewer subagents received scoped prompts recorded in the case files; each dispatch on the chore diff carried an explicit "if there is little to say, say little" instruction.

## Replication

The protocol is deliberately reproducible: `PRE-REGISTRATION.md` contains the corpus query (`author:app/copilot-swe-agent`, merged, 30–400 lines, established orgs, recency-ordered), the classification buckets, and the anti-gaming rules. If you run it on a different language corpus — especially if your results disagree — open an issue; disagreement is the most useful thing this study can attract.
