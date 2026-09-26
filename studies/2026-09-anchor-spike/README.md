# Study: how often does a finding's `line` miss the code its evidence quotes?

A pre-registered measurement, run 2026-09-26, before any design work on roadmap item 2
(anchor findings to the quoted code). No model runs: a script searched each existing
finding's `evidence` in the repository at the commit its reviewer read.

**Headline:** after hand-checking, 1 of 70 non-exempt findings (1.4%) cites a line other
than the one its quote sits on, and that one is 3 lines off. Every quote exists verbatim in
the finding's own file. Under the pre-registered rule (stop below 5%), item 2 is not
designed; the decision goes back to the maintainer.

## Contents

| File | What it is |
|---|---|
| [`PRE-REGISTRATION.md`](PRE-REGISTRATION.md) | Corpus, search rules, classes, decision rule; committed (`4e4e143`) before the script ran |
| [`measure.py`](measure.py) | The script, as run |
| [`results-script.csv`](results-script.csv) | The script's class for every finding |
| [`raw/dogfood-*.md`](raw) | The PR #78 dogfood reviews, extracted verbatim from this session's subagent transcripts |

## Corpus

72 findings: 51 real reviewer output (coverage spike 8, verifier e2e 5, PR #78 dogfood 38)
and 21 curated verifier items (V01-V13, W01-W08). Two are exempt (spec axis, `line: 0`),
leaving 70. The brief expected about 45 from the committed studies; those hold 34, so the
PR #78 dogfood reviews, which have known commits and use the current reviewer bodies, were
added to the corpus in the pre-registration, before the run.

## Results

| Class | Script | Hand-checked |
|---|---|---|
| EXACT | 64 | 68 |
| NEAR (1-5 lines) | 1 | 1 |
| ELSEWHERE (> 5 lines) | 1 | 0 |
| multi-location, labelled (not drift) | | 1 |
| REFS | 0 | 0 |
| BASE | 0 | 0 |
| NOWHERE | 4 | 0 |
| exempt | 2 | 2 |

| Measure | Script | Hand-checked |
|---|---|---|
| Wrong line, all | 2/66 = 3.0% | 1/70 = 1.4% (2/70 = 2.9% if the multi-location finding counts) |
| Wrong line, real output only | 2/45 = 4.4% | 1/48 = 2.1% |
| Breaks the `line±5` dedup window | 1/66 | 0/70 |
| Quote not found anywhere | 4/70 = 5.7% | 0/70 |

### The six findings outside EXACT, by hand

| Finding | Script | By hand | Why |
|---|---|---|---|
| coverage-spike correctness, `review-pro-verify/SKILL.md:16` | NEAR, d=3 | NEAR | the quoted sentence is on line 19; line 16 is the related `### Diff` input. The one real drift. |
| coverage-spike craft, `validate.test.sh:1134` | ELSEWHERE, d=58 | multi-location | the evidence quotes three places, each labelled with its own `path:line` (`# validate.test.sh:1192`, `# validate.sh:230`); `line` points at the `stage_mutation` helper the impact is about. Moving `line` to the quote would make it wrong. |
| coverage-spike tests, `validate.sh:226` | NOWHERE | EXACT | the quote joins a line and its `\|\| add_error` continuation (225-226) into one line; 226 is inside the span |
| dogfood r1 craft, `validate.sh:36` | NOWHERE | EXACT | each quoted line carries a bare line-number prefix (`36:`), which the pre-registered rules do not strip |
| dogfood r1 craft, `validate.test.sh:1321` | NOWHERE | EXACT | same prefix form (`1321:`) |
| dogfood r1 dry, `validate.sh:265` | NOWHERE | EXACT | same prefix form (`265:`) |

Two EXACT matches rested on a short piece and were checked too: W02's `"bytes": 140,` (the
quote occurs three times in the file; `line` is one of them) and a dogfood `## Output`
(correct). Both stand.

## What this says about item 2

- **Position drift is rare here.** One finding in 70 is off, by 3 lines, inside the dedup
  window. OCR's position-drift failure is about a comment landing on the wrong line of a
  PR; review-pro's reviewers quote and cite the same line almost every time.
- **A naive anchor check would do more harm than good on this corpus.** The script is that
  check. It flagged 4 quotes as missing that are all present (line-number prefixes, a quote
  joining two lines) and would have "corrected" the multi-location finding to a wrong line:
  5 false alarms against 1 real drift. A design that ships would need to handle labelled
  multi-location evidence, joined lines, line-number prefixes, and quotes that occur more
  than once in a file (W02) before it could be trusted to move a line.
- **Nothing was unanchorable.** No quote came from an `evidence_refs` file alone, none only
  from deleted code, none was paraphrased beyond recognition. The questions the brief
  raises for those cases (search refs, search base) have no instance to design against.

## Limits

- 70 findings, most from review-pro's own diffs (markdown and bash), where reviewers quote
  whole lines. A codebase with long functions and many near-identical lines could drift
  more; this corpus cannot show it.
- 21 of the 70 are curated verifier items, some written by construction; the real-output
  subset (48) gives the same answer (2.1%).
- The dogfood findings were written by general-purpose agents following the branch's
  reviewer bodies, not by the installed reviewer agents.
- One model family wrote every finding.
