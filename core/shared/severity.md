# Severity & Verdict (shared)

Every reviewer and the synthesizer use the same severity scale and verdict rules.

## Severity levels

| Level | Definition |
|---|---|
| Critical | Exploitable / data loss / broken core functionality in the diff |
| High | Likely bug or security issue with concrete impact in changed code |
| Medium | Real correctness/quality risk, scoped or conditional |
| Low | Minor risk or quality nit worth fixing |
| Nitpick | Style/preference, optional |

## Verdict (synthesizer)

| Verdict | Condition |
|---|---|
| BLOCK | any unaddressed Critical or High finding, `disputed` ones included |
| REQUEST CHANGES | any Medium-or-above finding that verification did not refute |
| APPROVE | only Low/Nitpick, refuted Mediums, or no findings |

A finding is refuted or `disputed` only by the verification stage (ADR-0009; the synthesis skill's `## Verification`). The synthesis skill repeats this table, because a skills-only install does not carry `core/shared/`; keep the two identical.

The synthesizer may downgrade severity only when evidence is incomplete; it never upgrades beyond what a specialist justified.
