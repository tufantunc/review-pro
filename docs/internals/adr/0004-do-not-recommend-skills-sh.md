# 0004: Do not recommend skills.sh as an install path

Status: accepted
Date: 2026-08-21

## Context

`npx skills add tufantunc/review-pro` works today with no submission process, which made skills.sh look like free distribution. Measured before recommending: skills.sh installs skill files only. It installs zero agent bodies, so every review would run through the inline fallback, and at the time of measurement two load-bearing rules existed only in the bodies (0 files carried them in a skills.sh install). The closed [PR #37](https://github.com/tufantunc/review-pro/pull/37) records the measured gap.

## Decision

review-pro documents `npx review-pro init` as the install path and does not recommend skills.sh. A distribution channel that silently drops half the artifact is worse than absence, because a degraded review still renders a verdict and the user cannot tell.

Rejected: publishing a `shared/` SKILL.md shim to make skills.sh installs look complete (it would publish a fake seventeenth "skill" into an install-ranked directory with no honest description).

## Consequences

We forgo a zero-effort channel. Revisit if skills.sh starts installing agent directories, and re-measure PR #37's gap before doing so.
