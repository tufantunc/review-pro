<!-- lvgl__lvgl@4a57db3 tests-reviewer; verbatim final answer -->
## Tests findings

Only the default-left-aligned, horizontally overflowing scroll cases are covered. `test_label_scroll_mid_update` (`tests/src/test_cases/widgets/test_label.c:641-664`) drives one `LV_LABEL_LONG_MODE_SCROLL` label and one `LV_LABEL_LONG_MODE_SCROLL_CIRCULAR` label through 20 screenshots, swapping the text with `lv_label_set_text`. That exercises the cached `label->text_size` for the anim start/end, the first draw and the horizontal circular re-draw (`lv_label.c:897-903`). It also checks that the cache refreshes when the text changes. The other `draw_main` branches that now read the cache have no test. Three gaps:

- severity: Medium
  category: tests.coverage
  file: src/widgets/label/lv_label.c
  line: 854
  title: Center/right-align override for scroll modes now uses cached text_size, but no test covers it
  evidence: |
    if((label->long_mode == LV_LABEL_LONG_MODE_SCROLL || label->long_mode == LV_LABEL_LONG_MODE_SCROLL_CIRCULAR) &&
       (label_draw_dsc.align == LV_TEXT_ALIGN_CENTER || label_draw_dsc.align == LV_TEXT_ALIGN_RIGHT)) {
        lv_point_t size = label->text_size;
        if(size.x > lv_area_get_width(&txt_coords)) {
  evidence_refs: [tests/src/test_cases/widgets/test_label.c:648-658]
  impact: The only scroll test leaves the labels at the default (left) align, so this branch never runs under test. The align center/right tests (`test_label_get_letter_pos_align_*`) use the default WRAP mode and only check letter positions, not rendered output. If `text_size` were stale or zero here, the override would be skipped and a scrolling center/right label would draw misaligned (the misalignment the code comment warns about). No screenshot would catch it.
  remedy: Add a screenshot test like `test_label_scroll_mid_update` with `lv_obj_set_style_text_align(label, LV_TEXT_ALIGN_CENTER, 0)` on one SCROLL label and one SCROLL_CIRCULAR label, plus a RIGHT-aligned pair. Take at least one screenshot at t=0 and one after `lv_test_wait(...)`. Also add a short-text center-aligned scroll label (text narrower than the widget) to pin the `size.x <= width` side, where the align must stay centered.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.coverage
  file: src/widgets/label/lv_label.c
  line: 906
  title: Vertical circular re-draw offset (size.y > height) is not tested
  evidence: |
    /*Draw the text again below the original to make a circular effect */
    if(size.y > lv_area_get_height(&txt_coords)) {
        label_draw_dsc.ofs_x = label->offset.x;
        label_draw_dsc.ofs_y = label->offset.y + size.y + lv_font_get_line_height(label_draw_dsc.font);
  evidence_refs: [tests/src/test_cases/widgets/test_label.c:654-658]
  impact: The circular test label is one line with only its width fixed (150), so its height fits the content and `size.y > height` is never true. The second-copy `ofs_y`, which now comes from the cached `text_size.y`, is never rendered under test. A wrong cached height would put the wrapped copy in the wrong place and nothing would notice.
  remedy: Add a SCROLL_CIRCULAR label with multi-line text (e.g. "Line1\nLine2\nLine3\nLine4") and a fixed height shorter than the text (`lv_obj_set_size(label, 150, 30)`). Take screenshots at several `lv_test_wait` points so the second copy below the original shows up in the images.
  confidence: high
  overlap_hints: []

- severity: Medium
  category: tests.coverage
  file: src/widgets/label/lv_label.c
  line: 826
  title: No test checks that the cached text_size is refreshed after a style change on a scrolling label
  evidence: |
    label_draw_dsc.text_size = label->text_size;
  evidence_refs: [src/widgets/label/lv_label.c:762-763, src/widgets/label/lv_label.c:967-968, tests/src/test_cases/widgets/test_label.c:629-639]
  impact: Before this change, draw time re-measured the text with the current font and letter spacing. Now the draw trusts `label->text_size`, which is updated only in `lv_label_refr_text`. For style changes that happens via `LV_EVENT_STYLE_CHANGED` / `LV_EVENT_SIZE_CHANGED` (lines 762-763). The mid-scroll test only changes the text. No test changes `text_font` or `text_letter_space` (or resizes the label) on a scrolling or circular label and then checks the render. If that invalidation broke, for example on a style path that doesn't send STYLE_CHANGED, the circular copy offset and align override would use the old width. Every current screenshot would still pass.
  remedy: In a new scroll test, after the first screenshot, call `lv_obj_set_style_text_letter_space(label2, 5, 0)` (or switch to a larger font) on the SCROLL_CIRCULAR label and on a center-aligned SCROLL label. Then call `lv_obj_set_width(label, 120)` and take another screenshot. The gap before the circular copy and the anim end must match the new text width.
  confidence: medium
  overlap_hints: [correctness.logic]

The new public `lv_draw_label_dsc_t.text_size` field doesn't need a test for callers other than the label. Table crop, roller and the one-line textarea placeholder all set `LV_TEXT_FLAG_EXPAND` without filling it in, so `w = dsc->text_size.x` is 0 for them (`lv_draw_label.c:221`). But the only place `w` is used is `lv_text_get_next_line` (`lv_draw_label.c:258/265/509`), and that function ignores `max_width` when EXPAND is set (`src/misc/lv_text.c:336-344`). So output doesn't change for them.

## Files examined
examined: [/Users/tufantunc/Desktop/Projects/Personal/aacr-bench/evaluation/work/lvgl__lvgl@4a57db3/src/draw/lv_draw_label.c, /Users/tufantunc/Desktop/Projects/Personal/aacr-bench/evaluation/work/lvgl__lvgl@4a57db3/src/draw/lv_draw_label.h, /Users/tufantunc/Desktop/Projects/Personal/aacr-bench/evaluation/work/lvgl__lvgl@4a57db3/src/widgets/label/lv_label.c, /Users/tufantunc/Desktop/Projects/Personal/aacr-bench/evaluation/work/lvgl__lvgl@4a57db3/src/widgets/label/lv_label_private.h]
not_examined: []

The git commands (`git diff` / `git show`) were denied for approval, so I never saw the diff itself. I read the HEAD contents of all four files at the changed regions, which is what the list above records. I worked out the old draw-time behaviour from the changed code and from the NemaGFX backend at `src/draw/nema_gfx/lv_draw_nema_gfx_label.c:433-441`, which still has the old `lv_text_get_size(..., LV_COORD_MAX, ...)` pattern.
