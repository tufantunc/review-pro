# 0014: Read the configured base from the default branch

Status: accepted
Date: 2026-11-16

## Context

Until v1.5.1 the base of every review was `refs/heads/main`, else `refs/heads/master`. A repository
whose work merges into an integration branch (git-flow's `development`, a `trunk`, a release line)
was reviewed against `main`, so each review also re-reviewed every change already on the
integration branch but not yet released. One installation patched its installed skills to try
`development` first; that list is one team's convention, and an `npx review-pro` update would
have overwritten it. The base also decides which packs and rules apply, so whatever chooses it
must not be something the change under review can edit ([ADR-0011](0011-read-repository-rules-from-the-base.md),
[ADR-0012](0012-read-stack-signals-from-the-base.md)).

## Decision

The base is the first of: the invocation's argument; the `base` key of `.review-pro/config.json`
read from the default branch; the default branch, which is the branch `origin/HEAD` names unless
that is the branch under review; else `main`, else `master`. Every name resolves through exact ref
lookups, and the report's `Base:` line says which source chose it.

Rejected: reading the config from HEAD or the working tree, because a change could point its own
review at a branch that already contains most of it. Taking the integration branch's name from
CLAUDE.md or AGENTS.md, because that is free text, read by interpretation, and editable by the
change. A fixed list such as `development`, `main`, `master`, because it encodes one team's naming.
The open PR's target from `gh pr view`, because it adds a network dependency and a host-specific
tool to the one step every review runs, and it is absent for a branch with no PR.

## Consequences

A repository with an integration branch commits one line of configuration, to its default branch,
and every review on every clone uses it. A configured name that does not resolve, or that a tag
shadows, stops the review instead of falling back, so a typo is seen rather than reviewed against
the wrong branch. A change to `.review-pro/config.json` dispatches `security`, because once merged
it decides what every later review compares against. The config is read from the default branch,
not from the base it names, so a repository whose default branch lacks the file gets no
configured base, even if the integration branch has one. `scripts/review.sh` restates the rule
and the validator holds the two together.
