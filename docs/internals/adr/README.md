# Architecture Decision Records

Three kinds of records live in this repository, and they answer different questions:

| Record | Question it answers | Lives in |
|---|---|---|
| Spec | What are we building, and how? | `docs/superpowers/specs/` |
| Study | What did we measure, and what did it show? | `studies/` |
| **ADR** | **Why did we choose this, and what did we reject?** | here |

An ADR is written when a decision is expensive to revisit: it constrains future work, it rejected a plausible alternative, or reversing it would break a published promise. A decision that is cheap to reverse does not need one.

Format: one file, numbered, short. Context (the forces at play), Decision (one sentence, active voice), Consequences (what this makes easier, what it makes harder, what it forecloses). Link the spec, study, PR, or issue that carries the evidence; do not restate it.

Statuses: `accepted`, `superseded by NNNN`. There is no `proposed`: an ADR is written when the decision is made, and a decision still being argued lives in an issue.

Start from [0000-template.md](0000-template.md).
