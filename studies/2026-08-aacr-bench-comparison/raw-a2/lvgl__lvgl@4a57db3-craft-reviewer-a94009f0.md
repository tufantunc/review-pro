<!-- lvgl__lvgl@4a57db3 craft-reviewer; verbatim final answer -->
I found three craft problems. The biggest is that the new public `text_size` field feeds a value the draw layer never uses, so it can be deleted outright.

- severity: High
  category: craft.code-judo
  file: src/draw/lv_draw_label.c
  line: 221
  title: The new public `text_size` field only feeds a width that `lv_text_get_next_line` ignores under EXPAND, so the field and the branch can both be deleted
  evidence: |
    if((dsc->flag & LV_TEXT_FLAG_EXPAND) == 0) {
        /*Normally use the label's width as width*/
        w = lv_area_get_width(coords);
    }
    else {
        /*If EXPAND is enabled then not limit the text's width to the object's width*/
        w = dsc->text_size.x;
    }
    ...
    /* src/misc/lv_text.c:336-344 */
    if((flag & LV_TEXT_FLAG_EXPAND) || (flag & LV_TEXT_FLAG_FIT)) {
        uint32_t i;
        for(i = 0; i < len && txt[i] != '\n' && txt[i] != '\r' && txt[i] != '\0'; i++) {
        }
        ...
        return i;
    }
  evidence_refs: [src/misc/lv_text.c:336, src/misc/lv_text.c:346, src/draw/lv_draw_label.c:259, src/draw/lv_draw_label.c:265, src/draw/lv_draw_label.c:509, src/draw/lv_draw_label.h:39]
  impact: The only reader of `w` is `lv_text_get_next_line` (lines 259, 265, 509). When EXPAND is set, that function returns before it looks at `max_width`, and its own later `if(flag & LV_TEXT_FLAG_EXPAND) max_width = LV_COORD_MAX;` (lv_text.c:346) can never run. So the old `lv_text_get_size` call bought nothing. Instead of deleting it, the PR swapped it for a widget-maintained cache and put that cache in the public `lv_draw_label_dsc_t`. That adds a public field, a producer obligation on every widget, and a dependency from the draw layer on widget state, all to supply a value that is thrown away.
  remedy: Remove the whole EXPAND branch. Set `w = (dsc->flag & LV_TEXT_FLAG_EXPAND) ? LV_COORD_MAX : lv_area_get_width(coords);`, or just always pass `lv_area_get_width(coords)`. Then drop `text_size` from `lv_draw_label_dsc_t` and remove the `label_draw_dsc.text_size = ...` assignment in lv_label.c:826. Make the same one-line change at src/draw/nema_gfx/lv_draw_nema_gfx_label.c:433-443. Every producer then gets the speedup (lv_label, plus lv_table.c:836, lv_textarea.c:1405 and lv_roller.c:583, which use EXPAND too), with no new API. Keep the separate draw_main change that reuses `label->text_size` instead of calling `lv_text_get_size` twice; that part is valid.
  confidence: high
  overlap_hints: [api-contract.breaking-change, performance.redundant-work, correctness.logic]

- severity: Medium
  category: craft.layer-leak
  file: src/draw/lv_draw_label.h
  line: 39
  title: A widget's cached layout result is exposed as a generic draw-descriptor field that only one producer fills and only one backend reads
  evidence: |
    /**The text to draw*/
    const char * text;

    /**The size of the text*/
    lv_point_t text_size;

    /**The font to use. Fallback fonts are also handled.*/
    const lv_font_t * font;
  evidence_refs: [src/widgets/label/lv_label.c:826, src/draw/lv_draw_label.c:77, src/draw/nema_gfx/lv_draw_nema_gfx_label.c:440]
  impact: The doc comment says "The size of the text", but the value is really `lv_label`'s `lv_text_get_size(..., max_w = content width, flag)` from `lv_label_refr_text`. Other producers (table, textarea, roller, and user code calling `lv_draw_label`) leave it at the zero from `lv_memzero` in `lv_draw_label_dsc_init`, so the field is silently `{0,0}` for them. Only the software backend reads it; the nema_gfx copy of the same iterate function still recomputes with `lv_text_get_size`. The result is a field that means different things per producer and per backend. The field is also inserted mid-struct, between `text` and `font`, which shifts the layout of a public struct.
  remedy: Apply the code-judo fix above and delete the field. If a size hint is ever really needed in the draw layer, make it an explicit optional hint with a sentinel (for example `-1` meaning "not provided") and a comment naming the width it was measured at. Put it next to `hint`, append it at the end of the struct, and use it in both iterate implementations.
  confidence: high
  overlap_hints: [api-contract.breaking-change, dry.duplication]

- severity: Low
  category: craft.abstraction
  file: src/widgets/label/lv_label_private.h
  line: 54
  title: A second, undocumented text-size cache sits next to `size_cache` with no note on how the two differ
  evidence: |
    lv_point_t size_cache;              /**< Text size cache */
    ...
    uint8_t invalid_size_cache : 1;     /**< 1: Recalculate size and update cache */

    lv_point_t text_size;
  evidence_refs: [src/widgets/label/lv_label.c:792, src/widgets/label/lv_label.c:967]
  impact: `lv_label_t` now has two `lv_point_t` text-size caches. `size_cache` is computed lazily in `LV_EVENT_GET_SELF_SIZE`, with a width derived from style max-width and with `max_height` clamping. `text_size` is computed eagerly in `lv_label_refr_text` with the content width. Only one has a comment, and "text size cache" fits both. The next person to touch this will likely read the wrong one, or keep them in sync by hand.
  remedy: Rename it to something like `refr_text_size` or `layout_size` and add a doc comment saying it is the `lv_text_get_size` result at content width, refreshed in `lv_label_refr_text`. Place it next to `size_cache` and point out how the two differ. Once the draw-descriptor field is removed, this cache has one job: letting draw_main skip its two `lv_text_get_size` calls.
  confidence: medium
  overlap_hints: []

## Files examined
examined: [src/draw/lv_draw_label.c, src/draw/lv_draw_label.h, src/widgets/label/lv_label.c, src/widgets/label/lv_label_private.h]
not_examined: []

Note: the git commands (`git diff`, `git show`) needed approval and were blocked, so I never saw the actual diff. I read each changed file at HEAD and inferred what changed by grepping for `text_size` and comparing against the untouched nema_gfx copy of the iterate function.
