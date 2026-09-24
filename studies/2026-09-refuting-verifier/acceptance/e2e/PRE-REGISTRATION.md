# End-to-end run: pre-registration (written before any run)

Pipeline: this branch's `core/skills/review-pro/SKILL.md`, followed by the session
agent as orchestrator; reviewers and verifiers are general-purpose agents told to
read this branch's rubric and verify skill files (the installed copies predate them).

Diffs:
- A: microsoft/aspire#18671, base 5552e243, head 8eeb25bd (pilot case 3).
- B (control): the step-2 probe `p4-control` branch, where the only expected finding is a
  Low citing kong.yml.

Pass:
- A: if any finding claims the `dotnet run` sites leave the flake unmitigated or the
  timeout invariant inverted, it comes out refuted (if Medium) or disputed (if High).
  If no reviewer produces it, record that; it is not a failure.
- A: the report carries the Verification line, and every Medium+ code finding carries a
  verification marker.
- A and B: no finding is verified in the orchestrator's own context.
- B: `Verification: 0 checked` and an otherwise intact report.
