# 0005: Release 1.0.0 when directories start judging readiness, and mean it

Status: accepted
Date: 2026-08-21

## Context

Plugin directories and marketplaces read a 0.x version as unfinished, and review-pro was being submitted to them. The version was also carrying real semver information: two files had just left the install, which 0.x semantics let pass quietly.

## Decision

1.0.0, released with the submissions, as a commitment rather than a costume: the reviewer roster, the finding schema, the category roots, and the triage/synthesis contracts are stable, and breaking any of them requires 2.0.

Rejected: staying 0.x until "feature complete" (a moving target that reads as unready in every directory listing meanwhile).

## Consequences

Additions stay minor (1.1.0 added a reviewer obligation, 1.2.0 added calibration rules; neither touched schema, roots, or roster). The constraint has already shaped design twice: the external-premise work reused the existing `confidence` field and filed contradicted premises under existing roots specifically to stay minor.
