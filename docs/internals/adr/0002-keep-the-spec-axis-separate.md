# 0002: Report the spec axis apart from the code axis, and never merge them

Status: accepted
Date: 2026-08-20

## Context

A diff can follow every convention and still implement the wrong thing. The Spec axis (the 13th reviewer) measures the diff against the issue or spec it came from. The tempting design was to pool its findings with code findings and dedup once. The argument against pooling is borrowed, with credit, from the `code-review` skill in [mattpocock/skills](https://github.com/mattpocock/skills), which runs Standards and Spec as two axes and refuses to merge them.

## Decision

Spec findings and code findings are partitioned before dedup, deduped on different keys, never re-ranked against each other, and reported in separate sections. Absence is stated in three distinct forms: skipped (no spec found), abstained (spec resolved but carried no text), and no mismatch (measured and clean).

Rejected: one pooled dedup ("this should not exist" and "this has a bug" on the same line are different claims, and merging them loses both); rendering an abstain as "no mismatch" (reports a review nobody performed as a clean result).

## Consequences

The report is longer and synthesis is more complex: two pools, two keys, three absence states, each guarded. In exchange, one axis cannot mask the other, which is the point. Design: [2026-08-20-spec-axis-design.md](../../superpowers/specs/2026-08-20-spec-axis-design.md).
