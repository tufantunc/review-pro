<!-- lvgl__lvgl@4a57db3 correctness-reviewer; verbatim final answer -->
## Correctness findings: none

I found no correctness problems in this change. Git commands needed approval, so I couldn't run `git diff`. I read the four changed files at HEAD and followed the consumers instead.

- **The draw-side change can't alter output.** In `lv_draw_label_iterate_characters` (`src/draw/lv_draw_label.c:215-222`), `w` is only passed to `lv_text_get_next_line` (lines 259, 265, 509). When `LV_TEXT_FLAG_EXPAND` or `LV_TEXT_FLAG_FIT` is set, that function returns early and never reads `max_width` (`src/misc/lv_text.c:336-344`). So when `text_size` is `{0,0}`, as it is for table, textarea, roller and user code that go through `lv_draw_label_dsc_init`, nothing changes. A stale value from the label doesn't matter either. The SW, vg_lite, vglite and dave2d backends all reach this through the same function. nema_gfx keeps its own copy and isn't touched.
- **`draw_main` gets the same value as before.** `label->text_size` is only read in the SCROLL and SCROLL_CIRCULAR branches (`src/widgets/label/lv_label.c:854-857`, `893-897`), and in those modes `label->expand` is 1 (lines 232-236). `lv_label_refr_text` measures with `get_label_flags(label)`, and `lv_text_get_size` forces `max_width = LV_COORD_MAX` under EXPAND (`src/misc/lv_text.c:101`). The value therefore matches the old draw-time measurement with `LV_COORD_MAX`, whatever content width is passed at line 967. DOTS mode never reads `text_size`, so editing the text after measuring (dots) doesn't affect it. The circular copy's offset now uses the same size as the scroll animation, which is at least as consistent as before.
- **The size stays current.**
  - `refr_text` runs from `set_text`, `set_text_fmt`, `set_text_static`, `set_long_mode`, `set_recolor`, `ins_text`/`cut_text`, and on `STYLE_CHANGED` / `SIZE_CHANGED` (line 762).
  - `TEXT_FONT`, `TEXT_LETTER_SPACE` and `TEXT_LINE_SPACE` are inheritable and trigger a layout update (`src/misc/lv_style.c:122-124`). So local, inherited, state-change and transition updates all send `STYLE_CHANGED` (`src/core/lv_obj_style.c:292-299`, `315-318`, `841-849`).
  - `set_text_static(NULL)` or `set_text(NULL)` reach `refr_text`. If the text is NULL, `refr_text` returns early, but `lv_draw_label` also returns early for NULL text, so the old size is never drawn.
  - The constructor calls `set_text(LV_LABEL_DEFAULT_TEXT)`, which measures before the first draw.

One behaviour change is not a bug. If a static text buffer is edited in place, or a style is edited without `lv_obj_report_style_change`, the value can now be stale. Before, the draw-time measurement hid this. These paths already bypass the documented refresh (`lv_label_set_text_static(obj, NULL)`, per `lv_label.h:106`), and the scroll animation already uses the `refr_text` size, so I didn't file it.

## Files examined
examined: [src/draw/lv_draw_label.c, src/draw/lv_draw_label.h, src/widgets/label/lv_label.c, src/widgets/label/lv_label_private.h]
not_examined: []
