<!-- lvgl__lvgl@a0067e3 craft-reviewer; verbatim final answer -->
Five craft findings: one Medium boundary issue, one Medium undocumented contract change, and three Low/Nitpick style items.

- severity: Medium
  category: craft.boundary
  file: src/misc/lv_text.c
  line: 653
  title: NULL handling added to only one encoding backend, so `lv_text_encoded_next` now accepts NULL or not depending on the build
  evidence: |
    +    /* Ensure the string is not null */
    +    if(txt == NULL || txt[*i] == '\0') return result;
    ...
    static uint32_t lv_text_iso8859_1_next(const char * txt, uint32_t * i)
    {
        if(i == NULL) return txt[0]; /*Get the next char*/

        uint8_t letter = txt[*i];
  evidence_refs: [src/misc/lv_text.c:847, src/misc/lv_text_private.h:219, src/misc/lv_text_private.h:227, tests/src/test_cases/test_txt.c:142]
  impact: Callers only see `lv_text_encoded_next`, a function pointer declared in lv_text_private.h:227. That pointer leads to the UTF-8 backend or the ISO8859-1 backend depending on `LV_TXT_ENC`. With this change, a NULL `txt` is safe with UTF-8 and still dereferences NULL with `LV_TXT_ENC_ASCII`. The rule about NULL input is now buried in one backend instead of stated at the shared interface. The new `test_lv_text_encoded_letter_next_2_should_handle_null_pointer` sits in a test file with no encoding guard, so it only holds under UTF-8.
  remedy: Pick one rule and state it once. Either put the NULL check at the public entry (`lv_text_encoded_letter_next_2`, which the new tests target) and drop it from the backend, or add the same NULL and terminator checks to `lv_text_iso8859_1_next`. Then update the doc at lv_text_private.h:219-226 so both backends promise the same thing.
  confidence: high
  overlap_hints: [api-contract.back-compat, correctness.edge-case]

- severity: Medium
  category: craft.boundary
  file: src/misc/lv_text.c
  line: 631
  title: Not advancing `*i` at the terminator changes the decoder's contract, but the doc comments were not updated
  evidence: |
     * @param txt pointer to '\0' terminated string
     * @param i start byte index in 'txt' where to start.
     *          After call it will point to the next UTF-8 char in 'txt'.
     *          NULL to use txt[0] as index
     * @return the decoded Unicode character or 0 on invalid UTF-8 code
    ...
    +    if(txt == NULL || txt[*i] == '\0') return result;
  evidence_refs: [src/misc/lv_text_private.h:221, src/misc/lv_text.c:772]
  impact: Before this change, a `'\0'` byte went through the ASCII branch and `*i` moved forward by one. Now `*i` stays put at the terminator, and NULL `txt` is accepted. Neither the static doc (lv_text.c:629-634) nor the public doc (lv_text_private.h:219-226) says so. The doc still says `i` "will point to the next ... char" and `txt` must be a "'\0' terminated string". Some loops depend on `i` moving forward: `lv_text_utf8_get_char_id` does `while(i < byte_id) { lv_text_encoded_next(txt, &i); ... }` (lv_text.c:772). If `byte_id` is past the end of the string, that loop now never ends, where before it read out of bounds. Anyone maintaining these loops cannot tell this from the docs.
  remedy: Update both doc blocks. State that `txt` may be NULL, that the function returns 0, and that `*i` does not move when `txt` is NULL or `txt[*i]` is `'\0'`. Also check loops that assume `*i` always advances (`lv_text_utf8_get_char_id`); have them stop at `'\0'` or clamp to the string length. Leave the correctness call to the correctness reviewer.
  confidence: high
  overlap_hints: [correctness.regression, api-contract.docs]

- severity: Low
  category: craft.spaghetti
  file: src/misc/lv_text.c
  line: 652
  title: Guard comment says "not null" but the check also catches the empty string and end of string, and the comment style differs from the file
  evidence: |
    +    /* Ensure the string is not null */
    +    if(txt == NULL || txt[*i] == '\0') return result;

        /*Normal ASCII*/
  impact: The comment only covers half of the check. The `txt[*i] == '\0'` part is the out-of-bounds fix named in the commit message, and the comment doesn't mention it. Readers may think it's leftover and simplify it away. Nearby comments use the tight `/*Text*/` style (lines 648, 655, 660, 662, 701). `return result;` hides the fact that it returns 0, while every other early return in this function writes `return 0;`.
  remedy: Use something like `/*Nothing to decode: NULL string or end of string. Don't step past the terminator*/` and `return 0;`, matching the other early returns.
  confidence: high
  overlap_hints: []

- severity: Nitpick
  category: craft.spaghetti
  file: tests/src/test_cases/test_txt.c
  line: 142
  title: New test names and literals don't follow the conventions of test_txt.c
  evidence: |
    void test_lv_text_encoded_letter_next_2_should_handle_null_pointer(void)
    ...
    const char * txt = "é"; /* UTF-8 encoding: 0xC3 0xA9 */
  evidence_refs: [tests/src/test_cases/test_txt.c:59, tests/src/test_cases/test_txt.c:71]
  impact: Every existing test is named `test_txt_<subject>_...` (for example `test_txt_get_encoded_next_detect_valid_2_byte_input`), and multibyte input is written as hex escapes (`"\xc3\xb1"`). The new tests use a `test_lv_text_` prefix and raw non-ASCII literals. That breaks grep and name consistency, and the literals depend on the source file being saved as UTF-8.
  remedy: Rename to `test_txt_encoded_letter_next_2_should_...`. Write `"\xc3\xa9"` / `"\xc3\xa9" "A"` instead of `"é"` / `"éA"`. The trailing comments can then go.
  confidence: high
  overlap_hints: [tests.style]

- severity: Nitpick
  category: craft.boundary
  file: tests/src/test_cases/test_txt.c
  line: 142
  title: Tests exercise the wrapper but not the decoder that was changed
  evidence: |
    lv_text_encoded_letter_next_2(txt, &letter, &letter_next, &ofs);
  impact: The fix is in `lv_text_utf8_next`, which the file already tests through `lv_text_encoded_next` (lines 59-127). The new tests only go through `lv_text_encoded_letter_next_2`. That wrapper already skips the second decode when `*letter == '\0'` (lv_text.c:541), so the new rule (no advance at `'\0'`) is only checked indirectly through `ofs`.
  remedy: Add `test_txt_get_encoded_next_...` cases that call `lv_text_encoded_next` directly on `""`, NULL, and an index sitting on the terminator, next to the existing decoder tests.
  confidence: medium
  overlap_hints: [tests.coverage]

## Files examined
examined: [src/misc/lv_text.c, tests/src/test_cases/test_txt.c]
not_examined: []
