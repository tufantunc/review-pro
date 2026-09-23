# 0008: Security content names what to flag, not what is safe

Status: accepted
Date: 2026-09-23

## Context

Borrowing from [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill), [PR #71](https://github.com/tufantunc/review-pro/pull/71) first gave every security stack pack a `## Not a finding` section: the safe forms of its own signals, meant to stop a pattern-shaped signal from firing on code that only resembles it. Each pass of the PR's dogfood sent a fresh security reviewer at the text, and each pass found an entry that told a reviewer to dismiss exploitable code:

| Pass | Medium or higher | Examples |
|---|---|---|
| 1 | 3 | HTML escaping accepted in any context; safetensors and ONNX cleared by format |
| 2 | 2 | event handlers and `srcdoc` inside "a quoted attribute"; an ONNX condition the attacker controls |
| 3 | 2 | the quote condition dropped by the pass-2 fix; `esc_js` cleared in any handler |
| 4 | 5 | client-side template roots; a JSON value placed inside quotes; DOMPurify on an unsupported DOM |
| 5 | 4 | the rubric's own escaping guidance read as a clearance; JSX text inside `<script>` |
| 6 | 4, one High | an argument-array entry that cleared an attacker-chosen executable, present since pass 1 |

Removing the escaping and sanitizer entries after pass 4 did not stop it; the failures moved to the rubric's guidance and then to the simplest shape entries. The count was not falling because the entries were the problem, not their wording. A clearance that is wrong fails toward shipping a vulnerability, and a fresh adversarial reader always finds another context. Cloudflare's per-domain files, read again, do not list safe APIs at all: their "Validation rules" state what a finding must establish before it is reported.

## Decision

The security rubric and the packs say what to flag and what a finding must establish; they do not list forms of code that are safe. Where passes 1 to 6 verified a fact that makes something a finding (an ONNX external-data traversal below 1.21.0, `TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD`, sqlx 0.9's `AssertSqlSafe`, html/template's typed-content conversions, raw-markup sinks, input taken as a program name), it moved into the pack's signals, where an error costs a false positive rather than a missed vulnerability. The rubric's guidance on fitting an escaper to its sink is a list of known mismatches and says it is not a list of safe placements.

Rejected: keeping the safe-form lists and reviewing until they converge. Six passes cost roughly thirty reviewer runs and showed no convergence.

Rejected: narrowing the lists to "shape entries" safe by the form of the call alone. Pass 6 found the High in exactly such an entry.

## Consequences

The false-positive reduction the lists were meant to buy is not delivered by the packs, and it was never measured: the one A/B in PR #71 showed the self-impact case moving from Medium to no finding, which is a rubric rule, not a pack entry. That is the evidence a future proposal to add clearances back has to bring first: measured pack signals firing on safe code in a real corpus, against a list reviewed to the same standard.

The rubric keeps a short `## Not a vulnerability` list, and it is a clearance too. It survives because its entries describe kinds of claim (no actor or boundary, self-impact, a placeholder, randomness nobody gains by predicting) rather than kinds of code. Two entries did not survive the review that followed this decision, which is the evidence for the rule: "a larger effect than the path shows" read as permission to drop a real, smaller exploit and became a severity rule instead, and the publishable-key entry drew a Medium on each of three consecutive rewrites (a Google key enabled for Gemini, a rule that only asks for a self-registered account) until it was replaced by a method for judging what a client key can reach. What remains is the part of this content most likely to need the same scrutiny again.

For the refuting verifier proposed as step 3 of these borrowings, this is evidence in both directions: a fresh refuter found a real defect in every pass, and it never ran out of things to say. That design needs a severity bar and a stopping rule, or it will not finish.
