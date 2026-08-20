# Design: a guard for published counts and rosters

**Status:** written after the fact. The guard existed first, as an unplanned fix
inside the Spec axis branch, and was removed from it so it could be designed.

## Why it exists

review-pro states how many reviewers it has, and lists them, in files that no
other check reads. Adding the thirteenth reviewer made every one of those
statements wrong, and finding them took four passes:

| Pass | What it found | Why the previous pass missed it |
|---|---|---|
| 1 | `README.md`, two locale dictionaries | Searched for the digits and the English word |
| 2 | `docs/llms.txt`, `cli/README.md`, `cli/package.json`, `CONTRIBUTING.md` | Never looked in `cli/`, and llms.txt is hand-written so the site drift check never reads it |
| 3 | The README's mermaid node, which said `...9 more` beside three named reviewers | The string holds no digits, so no search for the old number reaches it |
| 4 | The site's hero H1 and the Stage 2 explainer, in all seven locales | The count is spelled as a word: `Zwölf`, `Douze`, `बारह`, `十二` |

Two of those four were found by a maintainer's hunch rather than by review. The
fourth was the largest text on the published page.

The lesson is not that people should search harder. It is that a count repeated
in fourteen places with no single source cannot be kept correct by attention.

## What it checks

One source of truth: the reviewer entries in `manifest.json`. Everything else is
checked against it.

| Surface | Assertion |
|---|---|
| `README.md` | states the count twice, enumerates every reviewer, and its mermaid diagram's named nodes plus its `...N more` total to the count |
| `docs/llms.txt` | states the count |
| `cli/README.md` | states the count twice and enumerates every reviewer |
| `cli/package.json` | its `description` states the count |
| `CONTRIBUTING.md` | states the count in both sentences that mention it |
| `docs-src/i18n/*.json` × 7 | four keys state the count as a digit, two state it as that locale's numeral word, and the roster paragraph lists every reviewer |

## Three decisions that are not obvious

**The numeral-word table is unavoidable.** Two site keys spell the count instead
of writing a digit, so a digit test cannot see them, and that is exactly how they
stayed stale through four passes. A word cannot be derived from an integer without
a per-language table, so the guard carries one and **fails loudly when an entry is
missing** rather than skipping the check. Adding a locale or bumping the count
means adding a word, and the failure says so.

**A missing key fails; it does not pass.** The first version skipped any key it
could not find, which turns deleting a key into a way to satisfy the guard.

**Neighbourhood scanning was tried and rejected.** To catch a second stale
sentence in `CONTRIBUTING.md` whose number has no noun after it ("owned by one of
the 12"), the guard first flagged any integer within five of the count. That
passed only because the file happens to state no other number in that range,
while a sibling document already says "16 stack packs" and `Node 18` sits one file
away. It would have turned an unrelated docs edit into a red build. The rule is
now scoped to lines that mention a reviewer, a rubric, or a concern, and the
sentence is also pinned positively, because a neighbourhood scan goes silent as
soon as the count moves more than the band.

## Limitations

- **A file that does not exist passes.** Only `manifest.json` anchors anything, so
  deleting `cli/package.json` or the whole locale directory leaves the guard
  silent. Asserting existence for published paths is a reasonable follow-up and is
  deliberately not in this change.
- **The npm registry blurb only updates on publish.** The guard can keep
  `cli/package.json` correct in the repository; the package page stays stale until
  the next release regardless.
- **`assets/demo.gif` cannot be checked.** It records the installer, which prints
  no count, but only re-recording would prove that.
- **The guard is a string matcher.** It pins the phrasings that exist today, so
  rewording a sentence fails the build until the pattern is updated. That is the
  intended trade: a loud failure on a reword is cheaper than a silent staleness.
