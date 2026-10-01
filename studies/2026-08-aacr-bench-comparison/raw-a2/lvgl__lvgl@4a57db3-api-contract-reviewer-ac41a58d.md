<!-- lvgl__lvgl@4a57db3 api-contract-reviewer; verbatim final answer -->
I found one Low issue: the change adds a new public field whose meaning isn't defined. It breaks no in-tree consumer today. I couldn't run git (`git diff` and `git show` both needed approval), so I didn't read the diff itself. I reviewed the four changed files as they are at HEAD and compared them with `src/draw/nema_gfx/lv_draw_nema_gfx_label.c:433-443`, which still has the old code (it recomputes `lv_text_get_size` with `LV_COORD_MAX` under EXPAND). What the base looked like is inferred from that file, not read from the base.

- severity: Low
  category: api-contract.schema
  file: src/draw/lv_draw_label.h
  line: 39
  title: New public field `lv_draw_label_dsc_t.text_size` has no defined meaning, is undocumented, is never set by other producers, and has no effect where it is read
  evidence: |
    /**The size of the text*/
    lv_point_t text_size;
    ...
    /* src/draw/lv_draw_label.c:219-222 */
    else {
        /*If EXPAND is enabled then not limit the text's width to the object's width*/
        w = dsc->text_size.x;
    }
  evidence_refs: [src/draw/lv_draw_label.c:221, src/draw/lv_draw_label.c:259, src/draw/lv_draw_label.c:265, src/draw/lv_draw_label.c:509, src/misc/lv_text.c:336-344, src/draw/lv_draw_label.c:77, src/widgets/table/lv_table.c:836-837, src/widgets/textarea/lv_textarea.c:1405, src/widgets/roller/lv_roller.c:583, src/draw/nema_gfx/lv_draw_nema_gfx_label.c:433-443, docs/src/details/main-modules/draw/draw_descriptors.rst:490-512, src/widgets/label/lv_label.c:826]
  impact: |
    - **No observable effect today.** `w` is only passed to `lv_text_get_next_line` (lines 259, 265, 509). When EXPAND is set, that function returns early and ignores `max_width` (lv_text.c:336-344), so `text_size` changes nothing.
    - **Unclear contract for callers.** Only `lv_label` sets the field (lv_label.c:826). Table, textarea, roller and any application that builds a descriptor with EXPAND leave it at 0, because `lv_draw_label_dsc_init` zeroes the struct. Nothing says whether the field must be set, under which width limit it is measured, or who owns it. The field list in the docs (draw_descriptors.rst:490-512) doesn't mention it. Custom widgets and bindings (the header is public) can't tell whether they are required to fill it in.
    - **Latent break.** If `lv_text_get_next_line` ever starts honouring `max_width` under EXPAND, every producer except the label would pass `max_width=0` and text would break at every character.
    - **Draw units disagree.** The nema_gfx draw unit still computes the width itself and ignores `text_size`, so the same field means something in one draw unit and nothing in another.
    - **Minor:** the field is inserted mid-struct rather than appended, so later field offsets shift. Anything built against the old header's layout without recompiling breaks. Normal LVGL builds from source are fine because `lv_draw_label` copies with `sizeof(*dsc)`.
  remedy: |
    Pick one:
    - **Keep it out of the public API (preferred).** The EXPAND branch has no effect, so in `lv_draw_label_iterate_characters` set `w = LV_COORD_MAX` directly, drop `text_size` from `lv_draw_label_dsc_t`, and keep the cache private in `lv_label_t` (which already has it).
    - **Keep it public.** State the contract in the header comment: optional, 0 means compute it, measured with `max_width = LV_COORD_MAX` under EXPAND. Fall back to `lv_text_get_size` when `text_size.x == 0`. Add it to the draw_descriptors.rst field list, apply it the same way in the nema_gfx draw unit, and append it at the end of the struct.
  confidence: high
  overlap_hints: [correctness.side-effect, craft.abstraction]

Other things I checked that are fine:
- There are no positional brace initializers of `lv_draw_label_dsc_t` in `src`, `examples`, `tests` or `docs`, so the new field breaks no initializer.
- The new `text_size` member in `lv_label_private.h` is an addition to a private struct, and its only reader is `lv_label.c`.
- `label->text_size` is measured with EXPAND handled the same way as the old code: `lv_text_get_next_word` forces `LV_COORD_MAX` under EXPAND (lv_text.c:210).

## Files examined
examined: [src/draw/lv_draw_label.c, src/draw/lv_draw_label.h, src/widgets/label/lv_label.c, src/widgets/label/lv_label_private.h]
not_examined: []

Note: I read each file at HEAD, not as a diff, because git needed approval. For `src/widgets/label/lv_label.c` I read only the changed areas (lines 780-990) and the `text_size` references found by grep.
