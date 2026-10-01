# Anchor check on A2's reviewer answers (Amendment 2 item 9; roadmap item 2's revisit condition)

`anchor_a2.py` ran item 2's classifier (`studies/2026-09-anchor-spike/measure.py`, unchanged) on
the 157 reviewer answers A2 produced in the scored run (`raw-a2/`): 427 findings, 418 of them
locatable.

| Class | Count |
|---|---|
| EXACT | 391 |
| NEAR | 13 |
| ELSEWHERE | 14 |
| REFS | 5 |
| BASE | 2 |
| NOWHERE | 2 |

The classifier flags 27 of 418 (6.5%) as on the wrong line.

**The 27, checked by hand.** One rule throughout: the cited line is correct when it lies inside
the construct the finding is about, such as the statement, the block, the function signature or
the new check itself. Otherwise it is wrong.

| # | Instance | Reviewer | Cited | Verdict |
|---:|---|---|---|---|
| 1 | cherry-studio | tests | OpenAIProvider.ts:548 | correct: the comment that opens the dispatch block the finding covers |
| 2 | cherry-studio | tests | getPotentialIndex.ts:7 | correct: the untested function's signature |
| 3 | FreeCAD | tests | Parameter.cpp:1913 | **wrong, 2 off:** a closing brace above the error path |
| 4 | spring-ai-alibaba | correctness | MoveToAndClickAction.java:59 | correct: same multi-line statement |
| 5 | spring-ai-alibaba | tests | InputTextAction.java:62 | correct: the `try` that opens the fallback |
| 6 | spring-ai-alibaba | craft | InputTextAction.java:62 | correct: the same `try` |
| 7 | spring-ai-alibaba | ai-antipatterns | MoveToAndClickAction.java:57 | correct: the statement's first line |
| 8 | elasticsearch@a6a4623 | craft | QueryMaxAnalyzedOffset.java:12 | correct: the class the finding is about |
| 9 | elasticsearch@e38d20c | tests | AsyncSearchErrorTraceIT.java:754 | **wrong:** beyond the file's end |
| 10 | elasticsearch@e38d20c | tests | SearchServiceTests.java:501 | **wrong:** beyond the file's end |
| 11 | elasticsearch@e38d20c | tests | SearchService.java:353 | **wrong:** 463 lines from the code |
| 12 | elasticsearch@e38d20c | tests | SearchServiceTests.java:479 | **wrong:** beyond the file's end |
| 13 | elasticsearch@e38d20c | tests | MockLog.java:641 | **wrong:** beyond the file's end |
| 14 | elasticsearch@e38d20c | dry | AsyncSearchErrorTraceIT.java:727 | **wrong:** beyond the file's end |
| 15 | elasticsearch@e38d20c | dry | SearchErrorTraceIT.java:123 | **wrong, 6 off:** the end of the previous test |
| 16 | elasticsearch@e38d20c | dry | AsyncSearchErrorTraceIT.java:57 | **wrong, 1 off:** the blank line above the function |
| 17 | elasticsearch@e38d20c | dry | SearchServiceTests.java:481 | **wrong:** beyond the file's end |
| 18 | laravel | craft | ValidationEmailRuleTest.php:325 | correct: a test method holding the loops |
| 19 | lvgl@4a57db3 | craft | test_txt.c:142 | correct: the test function |
| 20 | lvgl@4a57db3 | correctness | lv_text.c:653 | correct: the new check the finding is about |
| 21 | lvgl@4a57db3 | security | lv_text.c:653 | correct: the same new check, the cause |
| 22 | lvgl@4a57db3 | tests | test_txt.c:155 | correct: the nearest existing test |
| 23 | typescript-go@b970689 | tests | commonjsmodule.go:392 | **wrong:** an unrelated function; the branch is at 66 |
| 24 | waveterm | tests | blockcontroller.go:252 | correct: the function signature, which the evidence also quotes |
| 25 | waveterm | api-contract | shellexec.go:512 | correct: where the swap token is packed |
| 26 | waveterm | craft | blockcontroller.go:873 | **wrong, 1 off:** the brace above the check |
| 27 | waveterm | craft | blockcontroller.go:218 | correct: the function signature |

**Result: 12 of 418 locatable findings are on the wrong line, 2.9%.**
- 3 are 1 to 2 lines off, inside the dedup window.
- 9 are outside it.
- 9 of the 12 come from one instance, elasticsearch@e38d20c, whose tests and dry reviewers cited
  six line numbers past the end of the files at head.

**Against item 2's revisit condition (more than 5% reopens it): below, so item 2 stays measured,
not built.**

Across all the data:

| Source | Wrong-line findings |
|---|---|
| Item 2 | 1 of 70 |
| Item 4 | 1 of 18 |
| This run | 12 of 418 |
| **All** | **14 of 506 (2.8%)** |

The concentration on one instance is new and is worth a look if item 2 is ever reopened.
