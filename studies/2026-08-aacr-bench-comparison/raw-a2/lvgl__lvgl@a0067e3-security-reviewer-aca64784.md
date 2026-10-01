<!-- lvgl__lvgl@a0067e3 security-reviewer; verbatim final answer -->
- severity: Medium
  category: security.injection
  file: src/misc/lv_text.c
  line: 653
  title: The new "don't advance at '\0'" rule makes `lv_label_get_letter_on` loop forever when a recolor-enabled label's last line ends inside a `#` command
  evidence: |
    /* Ensure the string is not null */
    if(txt == NULL || txt[*i] == '\0') return result;
  evidence_refs:
    - src/widgets/label/lv_label.c:446-451 — `if(letter != '\n' && txt[new_line_start] == '\0') new_line_start++;` (the last line's bound becomes strlen+1)
    - src/widgets/label/lv_label.c:487-495 — `while(i + line_start < new_line_start) { lv_text_encoded_letter_next_2(bidi_txt, &letter, &letter_next, &i); if((flag & LV_TEXT_FLAG_RECOLOR) != 0) { if(lv_text_is_cmd(&cmd_state, bidi_txt[i]) != false) { continue; } } ...`
    - src/misc/lv_text.c:160-165 — `if(*state == LV_TEXT_CMD_STATE_PAR) { if(c == ' ') {...} ret = true; }` (returns true for '\0' while in a parameter)
    - src/widgets/textarea/lv_textarea.c:887,913,1297,1361 and src/widgets/roller/lv_roller.c:758 (click and press handlers that call `lv_label_get_letter_on`)
  impact: |
    Who can trigger it: an end user typing into a textarea, or remote text shown in a label that has recolor enabled.
    How: the last line of text ends inside a recolor command with no closing space, for example "ab#" or "x #f00". The user then presses to the right of the last visible glyph on that line.
    Why it never stops: in `lv_label_get_letter_on`, the bound for the last line is `new_line_start = strlen+1`. Before this patch, decoding '\0' moved `i` to strlen+1 and the loop exited (after reading one byte past the end via `bidi_txt[i]`). Now `lv_text_utf8_next` returns 0 at '\0' and leaves `i` in place. `lv_text_is_cmd(&cmd_state, '\0')` returns true in `LV_TEXT_CMD_STATE_PAR`, so `continue` skips every break check. `i + line_start == strlen < strlen+1` stays true for ever.
    Result: the LVGL UI/task thread hangs, which on an embedded device means a frozen UI or a watchdog reset. This is an availability loss caused by in-band recolor syntax in lower-trust text. The closed category list has no DoS root, so it is filed under injection.
  remedy: |
    Make every length-bounded loop guard against a decoder that no longer advances. In lv_label_get_letter_on: `if(bidi_txt[i] == '\0') break;` right after `lv_text_encoded_letter_next_2`, or `if(i == i_prev) break;`. Also call `lv_text_is_cmd` on `letter`, not `bidi_txt[i]`.
    Alternatively, keep the "advance by one at '\0'" contract in `lv_text_utf8_next` and fix the OOB at its source: the callers whose bound goes past the terminator.
    Add a regression test: a recolor label with text "ab#", then `lv_label_get_letter_on` at a point on the last line past the last glyph.
  confidence: high
  overlap_hints: [correctness.logic, correctness.error-path, tests.missing-coverage]

- severity: Low
  category: security.injection
  file: src/misc/lv_text.c
  line: 653
  title: Length-bounded decoders called with length > strlen now hang instead of over-reading
  evidence: |
    while(i < length) {
        uint32_t letter;
        uint32_t letter_next;
        lv_text_encoded_letter_next_2(txt, &letter, &letter_next, &i);
  evidence_refs:
    - src/misc/lv_text.c:399 (lv_text_get_width), src/misc/lv_text.c:432 (lv_text_get_width_with_flags; public API at src/misc/lv_text.h:97/109)
    - src/misc/lv_text.c:772 (lv_text_utf8_get_char_id `while(i < byte_id)`)
    - src/misc/lv_bidi.c:597-608 (bracket_process `while(txt_i < len)` has no break when letter_next == 0; the "no closing bracket" check at :612 `if(txt_i > len)` relied on overshooting)
  impact: |
    If any caller passes a `length`, `byte_id` or `len` larger than the NUL-terminated string, these loops used to step past the NUL and stop after an out-of-bounds read. Now they never stop, because `i` stays at the NUL.
    I traced every in-tree caller: lv_draw_label.c:242/250/457/464, nema_gfx label, lv_label.c:380/396/576/581, the lv_bidi.c:91/140/165 paths, and dropdown.c:300/313. All of them pass bounds taken from `lv_text_get_next_line`/strlen, which stay at or below strlen, so none of them reaches this hang.
    `lv_bidi_process_paragraph`'s neutral loop at lv_bidi.c:212 and `get_next_run` exit by themselves, because letter 0 classifies as LTR and breaks.
    What remains is application code that misuses the public `lv_text_get_width(_with_flags)` API. Its failure changes from a silent OOB read to a hang.
  remedy: Add `&& txt[i] != '\0'` to the `while(i < length)` loops in lv_text_get_width(_with_flags), lv_text_utf8_get_char_id and bracket_process. The NUL then stops the loop and the length check is no longer the only guard.
  confidence: high
  overlap_hints: [correctness.logic, api-contract.behavior-change]

**Answers to the specific questions:**

1. **Does the patch fix the OOB read?** Only for the UTF-8 decoder. `lv_text_utf8_next` no longer steps past '\0', so a truncated sequence such as "\xC3" can no longer push later reads past the terminator. This holds because `LV_IS_INVALID_UTF8_CODE('\0')` is true, so the continuation-byte checks already stop at the NUL.
2. **Other OOB paths it leaves open (untouched code, so not filed as findings):**
   - `lv_text_iso8859_1_next` (lv_text.c:847-853) still does `(*i)++` past '\0' with no NULL check. In `LV_TXT_ENC_ASCII` builds the old over-read remains, and the new NULL-pointer test would dereference NULL. Tests build with the default `LV_TXT_ENC_UTF8` (lv_conf_internal.h:1810), so CI won't show this.
   - `lv_text_utf8_prev` (lv_text.c:720) still does `(*i)--` without checking `*i == 0`, which wraps to `txt[UINT32_MAX]`.
   - `lv_text_encoded_letter_next_2` (lv_text.c:538-541) is safe in UTF-8 now: when `*letter == 0` it skips the second decode, so `&txt[*ofs]` on NULL is never formed.
3. **Does it turn an OOB read into a hang?** Yes. The concrete in-tree case is the first finding. For the length-bounded public APIs it happens only if a caller misuses them (second finding).

## Files examined
examined: [src/misc/lv_text.c, tests/src/test_cases/test_txt.c]
not_examined: []
