<!-- lvgl__lvgl@4a57db3 dry-reviewer; verbatim final answer -->
- severity: Medium
  category: dry.copy-paste
  file: src/draw/lv_draw_label.c
  line: 221
  title: The EXPAND-width change went into lv_draw_label_iterate_characters but not its copy in nema_gfx, so the two copies now differ
  evidence: |
    // src/draw/lv_draw_label.c:215-222 (changed)
    if((dsc->flag & LV_TEXT_FLAG_EXPAND) == 0) {
        /*Normally use the label's width as width*/
        w = lv_area_get_width(coords);
    }
    else {
        /*If EXPAND is enabled then not limit the text's width to the object's width*/
        w = dsc->text_size.x;
    }

    // src/draw/nema_gfx/lv_draw_nema_gfx_label.c:433-443 (unchanged copy)
    if((dsc->flag & LV_TEXT_FLAG_EXPAND) == 0) {
        /*Normally use the label's width as width*/
        w = lv_area_get_width(coords);
    }
    else {
        /*If EXPAND is enabled then not limit the text's width to the object's width*/
        lv_point_t p;
        lv_text_get_size(&p, dsc->text, dsc->font, dsc->letter_space, dsc->line_space, LV_COORD_MAX,
                         dsc->flag);
        w = p.x;
    }
  evidence_refs: [src/draw/nema_gfx/lv_draw_nema_gfx_label.c:418, src/draw/nema_gfx/lv_draw_nema_gfx_label.c:433-443, src/draw/nema_gfx/lv_draw_nema_gfx_label.c:140]
  impact: The static `_draw_label_iterate_characters` in the NemaGFX backend (called at line 140) is a line-for-line copy of `lv_draw_label_iterate_characters`, down to the prologue and comments. The PR changed the EXPAND branch in one copy only. NemaGFX builds therefore get none of the speed-up, and the same `lv_draw_label_dsc_t` is now read two different ways: the generic path uses `dsc->text_size.x`, while NemaGFX still measures with `LV_COORD_MAX`. Any bug fixed later in either copy (for example callers that leave `text_size` unset) has to be fixed twice.
  remedy: At minimum, change `lv_draw_nema_gfx_label.c:437-443` to read `w = dsc->text_size.x;` so both backends read the descriptor the same way. Better, stop maintaining a second iterator. `lv_draw_label_iterate_characters(t, dsc, coords, cb)` already takes an `lv_draw_glyph_cb_t`, so NemaGFX could pass its `_draw_letter` / `_draw_nema_gfx_letter` path as the callback (the same way the generic path does in `src/draw/lv_draw_label.c`) and delete its copy. If the NemaGFX glyph path can't fit the callback signature, move the width prologue into one shared static-inline helper in `lv_draw_label_private.h` so both copies call the same code.
  confidence: high
  overlap_hints: [correctness.cross-file-side-effect, craft.code-judo]

- severity: Low
  category: dry.duplication
  file: src/widgets/label/lv_label_private.h
  line: 54
  title: The new lv_label_t::text_size is a second text-size cache next to the existing size_cache
  evidence: |
    lv_point_t size_cache;              /**< Text size cache */
    ...
    uint8_t invalid_size_cache : 1;     /**< 1: Recalculate size and update cache */

    lv_point_t text_size;
  evidence_refs: [src/widgets/label/lv_label_private.h:46, src/widgets/label/lv_label_private.h:52, src/widgets/label/lv_label.c:776-797, src/widgets/label/lv_label.c:953, src/widgets/label/lv_label.c:966-968]
  impact: The struct now has two `lv_point_t` fields that each store an `lv_text_get_size` result for the same `label->text`. `lv_label_refr_text` refreshes both (it sets `invalid_size_cache = true` at line 953 and writes `text_size` at line 968), but they are measured with different widths and flags. `size_cache` uses a width of `LV_COORD_MAX` or the content width, flags built inline, and a max-height clamp. `text_size` uses `max_w` and `get_label_flags()`. The new field has no doc comment. Nothing in the code says which cache draw code, scroll code or self-size code should use, so the two can drift quietly. The flag logic is also duplicated: lines 781-783 build flags inline, while `get_label_flags()` at line 1276 builds them for `text_size`.
  remedy: Document `text_size` in `lv_label_private.h`, for example "size measured with content width and label flags; used for drawing and scroll". At least make the self-size branch build its flags with `get_label_flags()` (lv_label.c:1276) instead of repeating lines 781-783. If the two measurements can be unified (same width and flags, with the max-height clamp applied only when self size is reported), keep one cache plus its invalidation bit and remove the other.
  confidence: medium
  overlap_hints: [craft.abstraction]

## Files examined
examined: [src/draw/lv_draw_label.c, src/draw/lv_draw_label.h, src/widgets/label/lv_label.c, src/widgets/label/lv_label_private.h]
not_examined: []

Note: git commands (`git diff`, `git show`) needed approval and were blocked in this session. I read the four changed files from the HEAD working tree, plus `src/draw/nema_gfx/lv_draw_nema_gfx_label.c` for comparison. I did not see the merge-base diff hunks themselves, so which lines are "changed" comes from the commit message, the related-context hints, and the new `text_size` symbols.
