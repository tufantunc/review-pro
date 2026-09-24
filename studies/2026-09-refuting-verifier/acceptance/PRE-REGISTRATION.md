# Contract run: pre-registration (written before any run)

Question: does the shipped `review-pro-verify` skill, with `defect_stands` and the
working-tree wording, behave as the spike's prompt did on the same 13 findings?

Labels, corrected after the spike (see ../RESULTS.md):
- FALSE: V01, V06, V08, V11 (V11's defect falls; only a doc-comment inaccuracy stands).
- MIXED: V04 (the RoutingHandler claim falls, the coverage gap stands).
- TRUE: V02, V03, V05, V07, V09, V12, V13.
- OUT-OF-REPO, not scored: V10.

One run per item, general-purpose agent, prompt built from the skill's Inputs section.

Pass, all three:
1. No TRUE item and not V04's core treated as refuted (per the synthesis resolution table).
2. At least 3 of the 4 FALSE items treated as refuted.
3. `defect_stands` consistent with `verdict` in at least 12 of 13 replies.

Predictions: V06, V08, V11 refuted; V01 partly_refuted with defect_stands yes (a miss,
as in the spike); V04 partly_refuted with defect_stands yes; every TRUE item stands or
partly_refuted with defect_stands yes; 13 of 13 consistent.
