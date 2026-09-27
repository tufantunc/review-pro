<!-- c39 a11y-reviewer; verbatim final answer -->
## Accessibility findings: none

The accessible output of the build is the same before and after this change. I checked it three ways:

- **Build output matches the committed pages.** I ran `buildAll` from this branch into a temporary directory. All 14 generated pages (`index.html` and `docs.html` for each of en, de, fr, hi, nl, tr, zh) are byte-identical to the committed files under `/private/tmp/claude-501/-Users-tufantunc-Desktop-Projects-Personal-review-pro/99075928-604e-433b-bc82-95e9c121edc8/scratchpad/fd/work/c39/repo/docs/`.
- **Every flag comes out right.** All 7 source flags in `docs-src/flags/` start with the same root tag (`xmlns viewBox role="img" aria-label="…"`). All 112 inlined flag roots in the output are `<svg aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 40">`. None of them keeps a `role="img"` or `aria-label`. The only `aria-label`s left in the pages are on the language-menu button (`aria-label="Language EN"` and the other six languages), and those were already there.
- **Old and new stripping agree on edge cases.** I ran both versions on attributes in different orders: `role`/`aria-label` first, last or in the middle; `role` alone; multi-line attributes; and no space between the two attributes. Both give the same attribute set every time. The only difference is that the new version drops trailing whitespace before `>`, which doesn't change anything. The injected `aria-hidden="true" focusable="false"` still comes first and still has a space before the remaining attributes.

The flags stay hidden from screen readers, and the language button's accessible name doesn't change. No tracked files were modified (`git status` is clean).

## Files examined
examined: [scripts/build-site.js]
not_examined: []
