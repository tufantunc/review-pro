<!-- lvgl__lvgl@a0067e3 performance-reviewer; verbatim final answer -->
I found one low-severity issue. The extra check costs nothing that matters on the hot path. The change in what happens at `'\0'` turns a bounded loop into a possible endless one in some callers, but no caller inside LVGL can reach it.

- severity: Low
  category: performance.blocking
  file: src/misc/lv_text.c
  line: 653
  title: No longer advancing at '\0' can make length-bounded loops spin forever when `length` is past the end of the string
  evidence: |
    /* Ensure the string is not null */
    if(txt == NULL || txt[*i] == '\0') return result;
  evidence_refs:
    - src/misc/lv_text.c:399
    - src/misc/lv_text.c:432
    - src/misc/lv_text.c:772
    - src/misc/lv_text.c:336
    - src/misc/lv_text.c:349
  impact: |
    Before this change, the ASCII branch handled '\0' as a normal character and did `(*i)++`. A loop like `while(i < length)` in `lv_text_get_width` / `lv_text_get_width_with_flags` (lines 399, 432) or `while(i < byte_id)` in `lv_text_utf8_get_char_id` (line 772) always ended, even when it read past the string. Now `i` stops at the '\0' and the loop never ends. The glyph width at '\0' is 0 and nothing else moves `i`, so the UI thread hangs. It happens whenever a caller passes `length`/`byte_id` greater than strlen(txt). These are public APIs (`lv_text_get_width`, `lv_text_encoded_get_char_id`, also aliased through `lv_txt_get_width` in lv_api_map_v8.h).
    I checked every caller in the tree and none can trigger it. The `line_end` values in draw and label code come from `lv_text_get_next_line`, which stops at '\0' (lines 336, 349). The `byte_id` values come from `lv_text_encoded_get_byte_id`, which also stops at '\0'. The dropdown `insert_pos` is at most strlen. So the risk is limited to outside callers that pass a length that is too large. Before, such a call was an out-of-bounds read; now it is an endless loop.
    The per-call cost of the new check is negligible: one NULL compare and one byte compare on a byte that is loaded anyway. That is small next to `lv_font_get_glyph_width` on every glyph, so this is not a hot-path regression.
  remedy: |
    Keep the bounded loops bounded whatever the decoder does. For example, add `&& txt[i] != '\0'` to the loop conditions in `lv_text_get_width`, `lv_text_get_width_with_flags` and `lv_text_utf8_get_char_id`. Or have those loops `break` when `i` did not change after a decode call. The NULL check can stay as it is.
  confidence: medium
  overlap_hints: [correctness.breakage, api-contract.behavior]

## Files examined
examined: [src/misc/lv_text.c, tests/src/test_cases/test_txt.c]
not_examined: []
