# Render check: expected (written before the run)

Inline run (results given):
- Verdict line: `## Verdict: BLOCK (code), 1 disputed`
- Verification line: `Verification: 5 checked (1 stand, 1 partly refuted, 3 refuted), 5 not checked (3 error, 2 cap). Spec findings are not verified.`
  (checked: F1, F3, F5 refuted, F5 through the partly_refuted/no row; F4 partly refuted; F2 stands.
  not checked: F6 inconsistent, F7 two blocks, F8 unbound, all `error`; F9, F10 `cap`.)
- F1 stays under Critical, marked disputed, with its citation.
- F2 under High, marked verified.
- F3 and F5 under `### Refuted in verification`; F3 carries `noticed (not reviewed): rounding untested`.
- F4 under Medium at Medium, with the falling part and its citation beneath it.
- F6, F7, F8 under Medium, each `not verified (error)`; F9, F10 `not verified (cap)`.
- F11 under Low, with no verification marker.

No-results run (same findings, no replies, as a subagent):
- `## Verdict: BLOCK (code)` with no disputed counter.
- `Verification: 0 checked, 10 not checked (10 no independent verifier). Spec findings are not verified.`
- F1 to F10 each `not verified (no independent verifier)`; no `### Refuted in verification` section.
