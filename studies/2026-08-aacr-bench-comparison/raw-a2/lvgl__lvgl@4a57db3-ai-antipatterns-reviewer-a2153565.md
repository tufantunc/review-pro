<!-- lvgl__lvgl@4a57db3 ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: Medium
  category: ai-antipatterns.over-engineering
  file: src/draw/lv_draw_label.h
  line: 39
  title: New public `lv_draw_label_dsc_t.text_size` field carries a value its only reader never uses
  evidence: |
    +    /**The size of the text*/
    +    lv_point_t text_size;
    ...
    -        lv_point_t p;
    -        lv_text_get_size(&p, dsc->text, dsc->font, dsc->letter_space, dsc->line_space, LV_COORD_MAX,
    -                         dsc->flag);
    -        w = p.x;
    +        w = dsc->text_size.x;
  impact: |
    The change assumes the EXPAND-branch `w` in `lv_draw_label_iterate_characters` needs the measured text width. It doesn't. `w` has only three readers (src/draw/lv_draw_label.c:259, :265, :509), and all three pass it as `max_width` to `lv_text_get_next_line(..., w, NULL, dsc->flag)`. That branch only runs when `dsc->flag` has `LV_TEXT_FLAG_EXPAND`, and `lv_text_get_next_line` returns early in that case without reading `max_width` (src/misc/lv_text.c:336-344: "If max_width doesn't matter simply find the new line character"). Alignment uses `lv_area_get_width(coords)`, not `w` (src/draw/lv_draw_label.c:283). So the old `lv_text_get_size` call was dead work. The fix is to delete it. Instead, the change adds a field to a public draw descriptor to feed a value nobody reads. The field also sits between `text` and `font`, so it shifts the offset of every later member of a public struct.
    The field is also a half-kept contract. Only `lv_label` sets it (src/widgets/label/lv_label.c:826). The other EXPAND users leave it at the zero from `lv_draw_label_dsc_init` (src/draw/lv_draw_label.c:77): src/widgets/roller/lv_roller.c:583, src/widgets/table/lv_table.c:837, src/widgets/textarea/lv_textarea.c:1405 and `lv_draw_character`. The NemaGFX backend still measures the text itself (src/draw/nema_gfx/lv_draw_nema_gfx_label.c:437-442). This causes no bad rendering today only because the value is ignored. Anyone reading the field later will assume it is filled in.
  remedy: Remove `text_size` from `lv_draw_label_dsc_t`, along with the assignment at lv_label.c:826. In `lv_draw_label_iterate_characters`, set `w = LV_COORD_MAX;` in the EXPAND branch, or drop the branch. Make the same change in lv_draw_nema_gfx_label.c:437-442 so both backends stay consistent. The `draw_main` savings (reusing `label->text_size`) do not need the public field.
  confidence: high
  evidence_refs: [src/draw/lv_draw_label.c:259, src/draw/lv_draw_label.c:265, src/draw/lv_draw_label.c:283, src/draw/lv_draw_label.c:509, src/misc/lv_text.c:336, src/draw/lv_draw_label.c:77, src/widgets/roller/lv_roller.c:583, src/widgets/table/lv_table.c:837, src/widgets/textarea/lv_textarea.c:1405, src/draw/nema_gfx/lv_draw_nema_gfx_label.c:437]
  overlap_hints: [api-contract.public-struct, craft.boundary, performance]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: src/widgets/label/lv_label_private.h
  line: 54
  title: Second, undocumented text-size cache added next to the existing `size_cache`
  evidence: |
        lv_point_t size_cache;              /**< Text size cache */
        ...
        uint8_t invalid_size_cache : 1;     /**< 1: Recalculate size and update cache */
    +
    +    lv_point_t text_size;
  impact: Every other member of `struct _lv_label_t` has a trailing Doxygen `/**< ... */` comment (lv_label_private.h:34-52). The new member has none. The struct already has `size_cache`, documented as "Text size cache" and used through `invalid_size_cache` (lv_label.c:776-802). Now there are two text sizes with different meanings. `size_cache` is computed with the self-size width and clamped to `max_height`. `text_size` is computed in `lv_label_refr_text` with the content width (lv_label.c:967-968), and nothing says which one draw code should read. The member is also placed after the bitfield group rather than with the other `lv_point_t` fields, which suggests it was appended rather than fitted in.
  remedy: Move it next to `size_cache`/`offset` and add a `/**< ... */` comment that says what it holds and how it differs from `size_cache`, e.g. "Unclamped text size from last lv_label_refr_text(); used by draw_main for scroll modes". Or rename it (e.g. `refr_text_size`) so readers don't confuse it with `size_cache`.
  confidence: high
  evidence_refs: [src/widgets/label/lv_label_private.h:46, src/widgets/label/lv_label_private.h:52, src/widgets/label/lv_label.c:792, src/widgets/label/lv_label.c:968]
  overlap_hints: [craft.naming, dry.canonical-helper]

Checked and not reported: no hallucinated symbols. `lv_point_t`, `lv_text_get_size` and `label->text_size` all exist in the tree. The `draw_main` reuse of `label->text_size` in place of the `LV_COORD_MAX` measurements matches the old results, because scroll and circular modes set `label->expand = 1` (lv_label.c:232-234). With EXPAND set, `lv_text_get_size` forces `max_width = LV_COORD_MAX` (lv_text.c:101).

## Files examined
examined: [src/draw/lv_draw_label.c, src/draw/lv_draw_label.h, src/widgets/label/lv_label.c, src/widgets/label/lv_label_private.h]
not_examined: []
