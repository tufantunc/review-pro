<!-- lvgl__lvgl@4a57db3 performance-reviewer; verbatim final answer -->
I found no performance regressions; I have two minor points below. I read the files at HEAD directly because running `git diff` against the merge base needed approval. The comparison with the old code is inferred from the commit message and the related context, not from the diff itself.

The change is a real improvement. The `LV_TEXT_FLAG_EXPAND` branch of `lv_draw_label_iterate_characters` no longer calls `lv_text_get_size`, a pass over the whole text that ran for every draw task. `draw_main` in `lv_label.c` now uses `label->text_size`, which `lv_label_refr_text` fills in once (lv_label.c:967-968), for the scroll-align check (856) and the circular-scroll redraws (894). Table, textarea and roller also draw with EXPAND, and they gain too: they leave `text_size` at zero, so they now skip that measuring pass.

- severity: Low
  category: performance.complexity
  file: src/draw/nema_gfx/lv_draw_nema_gfx_label.c
  line: 440
  title: The NemaGFX backend still measures the whole text on every EXPAND draw task
  evidence: |
    else {
        /*If EXPAND is enabled then not limit the text's width to the object's width*/
        lv_point_t p;
        lv_text_get_size(&p, dsc->text, dsc->font, dsc->letter_space, dsc->line_space, LV_COORD_MAX,
                         dsc->flag);
        w = p.x;
    }
  evidence_refs: [src/draw/nema_gfx/lv_draw_nema_gfx_label.c:433-443, src/draw/lv_draw_label.c:215-222, src/misc/lv_text.c:336-344]
  impact: On NemaGFX targets, the per-task text measurement that this commit removes from the generic path is still there. A scrolling label (EXPAND set) with N characters, split across T draw tasks per frame, still costs O(N·T) glyph-width lookups per frame, and the result is thrown away (see the remedy).
  remedy: Apply the same change here, or better, stop computing a width at all. `lv_text_get_next_line` returns before it reads `max_width` when EXPAND is set (lv_text.c:336-344), so `w = LV_COORD_MAX` is enough in both files.
  confidence: high
  overlap_hints: [dry.duplication, correctness.side-effects]

- severity: Nitpick
  category: performance.memory
  file: src/draw/lv_draw_label.h
  line: 39
  title: The new `text_size` field in `lv_draw_label_dsc_t` only feeds a value that is never read
  evidence: |
    /**The size of the text*/
    lv_point_t text_size;
    ...
    w = dsc->text_size.x;   /* src/draw/lv_draw_label.c:221 */
  evidence_refs: [src/draw/lv_draw_label.c:221, src/draw/lv_draw_label.c:258-265, src/draw/lv_draw_label.c:509, src/misc/lv_text.c:336-344]
  impact: `w` only goes to `lv_text_get_next_line`, which ignores it under EXPAND. So the 8 extra bytes on every label descriptor and every copied label draw task buy nothing. The cost is small, but it is a public field whose value has no effect.
  remedy: Set `w = LV_COORD_MAX` in the EXPAND branch and remove `lv_draw_label_dsc_t.text_size`. Keep `lv_label_t.text_size`, because `draw_main` really uses it (lv_label.c:856, 894). It can't simply reuse `size_cache`, which is computed with a different width and is capped by max height (lv_label.c:786-795).
  confidence: high
  overlap_hints: [api-contract.signature, craft.abstraction]

## Files examined
examined: [src/draw/lv_draw_label.c, src/draw/lv_draw_label.h, src/widgets/label/lv_label.c, src/widgets/label/lv_label_private.h]
not_examined: []

Examined means I read the HEAD contents of the relevant sections. I did not see the diff hunks.
