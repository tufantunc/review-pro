# Anchor spike: pre-registration (written 2026-09-26, before the script ran on any finding)

Question: how often does a reviewer's `line` miss the code its own `evidence` quotes? Roadmap
item 2 (`docs/superpowers/plans/2026-09-26-ocr-lessons-roadmap.md`) proposes checking each
quote against the file and correcting or marking the line. It is worth building only if the
line is often wrong.

No model runs. A script reads findings that already exist and searches each quote in the
repository at the commit the reviewer read.

## Corpus

Every finding block with a `file` and `line` in these sources. Nothing else, nothing dropped.

| Source | Commit read | Kind |
|---|---|---|
| `studies/2026-09-coverage-spike/raw/{correctness,craft,tests}.md` | review-pro `8649dad` (base `c33da43`) | real reviewer output |
| `studies/2026-09-refuting-verifier/acceptance/e2e/raw/A-*.md` | aspire `8eeb25bd` (base `5552e243`) | real reviewer output |
| `studies/2026-09-refuting-verifier/acceptance/e2e/raw/B-security.md` | probe-p4-control `7e99a37` | real reviewer output |
| `studies/2026-09-refuting-verifier/items/V01-V13.md`, `acceptance/run2/items/W01-W08.md` | the checkout each item names, at its head | curated corpus items (some verbatim reviewer output, some written by construction) |
| PR #78 dogfood reviews, extracted verbatim from this session's subagent transcripts into `raw/dogfood-*.md` | review-pro `14c52d4` (round 1), `c610017` (round 2), `6e81028` (round 3) | real reviewer output, current agent bodies |

Excluded: `studies/2026-09-refuting-verifier/acceptance/render/INPUT.md`, which says its
findings are fictional. Verifier outputs, which are not findings.

Exempt from the drift metric and counted separately: spec-axis findings (category `spec.*`)
and any finding with `line: 0`, because their line is not a code location by contract.

## How a quote is searched (fixed now)

1. Split `evidence` into lines. Strip each; collapse runs of whitespace to one space.
2. Drop: empty lines; lines that are only an ellipsis (`...`, `…`, `[...]`); reviewer
   annotation lines (a line that starts with `#`, `//`, `--` or `*` followed by a
   `path:line` label, or that is only a `path:line` label). Remove a leading `path:line`
   label from a line that carries code after it.
3. Split a line on an internal ellipsis into pieces.
4. A piece is usable if it has at least 8 characters. Each usable piece is also tried with a
   leading diff marker (`+` or `-`) removed.
5. A piece matches a file line when, after the same whitespace normalisation, it equals the
   file line or is a substring of it.
6. Git is called through its absolute path from inside the script. The shell's RTK hook
   rewrites git output in the agent's own shell and produced false results in the coverage
   spike; a subprocess of the script does not pass through it.

## Classes (one per finding, checked in this order)

| Class | Condition |
|---|---|
| EXACT | some usable piece matches the line numbered `line` in `file` at the commit read |
| NEAR | not EXACT; the nearest match in `file` is 1 to 5 lines from `line` (the dedup window is `line±5`) |
| ELSEWHERE | a match exists in `file`, more than 5 lines from `line` |
| REFS | no match in `file`; a match in one of the `evidence_refs` files |
| BASE | no match at the commit read in `file` or refs; a match in the diff's removed lines or the base version of `file` |
| NOWHERE | none of the above |

## Measures

- **Wrong line** (primary) = (NEAR + ELSEWHERE) / (EXACT + NEAR + ELSEWHERE), over non-exempt
  findings. The quote is in the finding's own file, so the right line is knowable.
- **Breaks dedup** = ELSEWHERE / the same denominator.
- **Unanchorable** = (REFS + BASE + NOWHERE) / all non-exempt findings. These cannot be
  corrected by searching `file` at head, which decides what an anchor check must search.
- Each reported for all findings, and for real reviewer output alone.

## Hand check

Every finding the script puts outside EXACT is checked by hand against the file (the coverage
spike's analyzer was wrong on 4 of 4 flagged items). A hand check may move a finding to another
class, with the reason written next to it. Both the script's numbers and the hand-checked
numbers are reported; the decision uses the hand-checked ones.

## Decision rule (fixed now)

- Wrong line under 5%: stop, report to the maintainer, and do not design. Report the
  unanchorable share with it, since it is a separate question the maintainer may still want
  answered.
- Wrong line 5% or more: proceed to design.

## Predictions

- EXACT for most findings: reviewers usually copy the line they cite.
- The NEAR cases, if any, point at a function header or the first line of a hunk while
  quoting a line inside it.
- REFS for a few findings whose evidence is a caller or helper (dry and ai-antipatterns
  findings with `evidence_refs`).
- NOWHERE for findings whose evidence merges or paraphrases several places, like the
  coverage spike's second correctness finding.
- Wrong line: 5 to 15%. This is a guess; the design depends on the measured value, not on it.
