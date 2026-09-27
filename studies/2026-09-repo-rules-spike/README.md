# Study: would maintainer-written co-change rules catch what no reviewer caught?

A pre-registered measurement, run 2026-09-27, before any design work on roadmap item 3
(path-scoped repository rules). Part 1 used no model; part 2 ran one judgment agent per item.

**Headline:** the rules caught 3 of 4 known misses end to end (trigger, then a judgment that
says `violated`). Over all 66 merged PRs they triggered 44 times, and 34 of those (77%) were
legitimate changes where the other file needed no update; the judgment step cleared all 8
legitimate triggers it was shown. Neither stop condition held, so design proceeds. The fourth
miss (a count spelled as a word in seven locales) cannot trigger a file-level rule at all.

## Contents

| File | What it is |
|---|---|
| [`PRE-REGISTRATION.md`](PRE-REGISTRATION.md) | Question, rules, classes, judgment sample, stop rule; committed (`50ac8af`) before any trigger was computed |
| [`rules-draft.md`](rules-draft.md) | The 8 rules measured, each labelled documented or post-miss |
| [`triggers.py`](triggers.py) | Part 1: evaluates the rules over every merged PR |
| [`prs.tsv`](prs.tsv), [`triggers.csv`](triggers.csv) | The 66 merged PRs, and every (PR, rule) evaluation |
| [`judgments/`](judgments) | Part 2: every judgment agent's final answer, verbatim |

## Part 1: triggers over history

| Rule | Matched | Held by file | Triggered | Real miss | Legitimate |
|---|---|---|---|---|---|
| C1 site rebuild | 3 | 3 | 0 | | |
| C2 pack version | 11 | 11 | 0 | | |
| C3 version fields | 17 | 1 | 16 | 7 | 9 |
| C4 llms.txt | 13 | 4 | 9 | 1 | 8 |
| C5 cli/README | 13 | 4 | 9 | 1 | 8 |
| C6 roster | 2 | 1 | 1 | 0 | 1 |
| C7 schema to bodies | 4 | 4 | 0 | | |
| P1 severity.md | 10 | 1 | 9 | 1 | 8 |
| **All** | 73 | 29 | **44** | **10** | **34** |

**Trigger false-alarm rate: 34/44 = 77%.** By rule: C3 56%, C4, C5 and P1 89% each, C6 100%.

How the 44 were classified, by hand:

- **C3**: the 7 version-bump PRs (#15, #26, #32, #36, #43, #45, #62) are real misses: every
  one left `.cursor-plugin/plugin.json` at 0.1.0, and several also left the lockfile behind
  (it sat at 0.7.0 from v1.0.0 to v1.2.0). The other 9 changed dependencies or the package
  description, never `version`. A glob on `cli/package.json` cannot say "the version field
  changed", which is where most of this rule's noise comes from.
- **C4, C5**: the real miss is #74 (verification), which reached `docs/llms.txt` and
  `cli/README.md` only in the v1.4.0 release PR. The other 8 are internal rubric or pipeline
  changes a reader of those pages would not notice, confirmed by the files' history: no later
  commit fixed anything they introduced. Note that `releasing.md` makes updating these pages a
  release step, so a PR-level rule asks earlier than the documented process does.
- **P1**: the real miss is #74. The other 8 changed synthesis without changing the verdict
  ladder; #76's own severity.md diff shows the file tracks only the ladder, which #29 (axis
  labels) and #45 (approval guidance) left alone.
- **C6**: #74 added the verify skill, but the reviewer roster stayed at 13.

No real miss in history was one the rule authors had not already met: every real trigger is
the `.cursor-plugin`/lockfile drift or #74, both already documented.

Two properties of the trigger that matter for design:

- A target that did not exist yet (`core/.codex-plugin/plugin.json` before #35) showed as
  missing in 9 C3 triggers. A trigger must ignore targets absent at the base.
- 29 of 73 matches were held by file, including every pack edit (C2: 11 of 11 bumped the
  pack version). Where a practice is already habit, the rule costs nothing.

## Part 2: replay and judgment

| Case | Trigger | Judgment | Caught |
|---|---|---|---|
| K1 #74, severity.md | P1 | violated | yes |
| K2 #29 minus llms.txt | C4 and C6 | violated, both | yes |
| K3 #29 minus the i18n hero words | none: the i18n files still changed (digit keys) | not run | **no** |
| K4 #76 minus `.cursor-plugin` | C3 | violated | yes |

**3 of 4 known misses caught.**

Judgments over part 1:

- **Real misses: 9 of 10 judged `violated`.** The one miss is J07, #62 (v1.3.0), where only
  `.cursor-plugin` was left behind. The judge read that commit's `releasing.md`, which listed
  three manifests, and concluded the Cursor manifest was independently versioned: it trusted
  the repository's own stale documentation over the rule's target list. The six other C3
  judges said `violated` because of the lockfile, and three of them also called the Cursor
  manifest independent. K4 was caught only because its own diff added `.cursor-plugin` to the
  validator. So the Cursor miss, in its natural form, was not caught by judgment.
- **Legitimate triggers: 8 of 8 cleared** (`held`), each with the line that decided it.

## Stop rule, applied

- **S1** (fewer than 2 of 4 known misses caught): 3 of 4 caught. Does not hold.
- **S2** (more than half the triggers legitimate, and the judgment clears fewer than half of
  the sampled legitimate ones): 77% legitimate, but 8 of 8 cleared. Does not hold.

Design proceeds.

## What this says for design

- **Keep trigger and judgment apart.** The trigger is cheap and noisy (77% legitimate); the
  judgment turns it into a correct `held` or `violated` in 20 of 21 judged items here. A
  report that printed triggers as alarms would be wrong three times in four.
- **A rule's target list must win over what the repository says elsewhere.** J07's error was
  deferring to stale in-repo documentation. The judgment prompt has to say the rule's `then`
  is the expectation being checked, and that repository text contradicting it is itself a
  finding about drift, not a reason to hold.
- **Targets absent at the base are not missing.**
- **File-level co-change cannot see a partial update.** K3 changed the right files and still
  left seven locales stale. Catching it needs content-level rules or a check that already
  exists: the published-count guard in `validate.sh` now covers it.
- **Retro-fit.** K1, K2 and K4 are caught by post-miss rules, written knowing the miss. That
  they trigger says little. The informative numbers are the 77% trigger noise, the 8 of 8
  clears, and J07's failure, which happened on a rule written for exactly that miss.

## Limits

- One repository, 66 PRs, one maintainer's habits; 10 real triggers.
- One judgment run per item; one model family wrote, judged and classified.
- The hand classification of the 44 triggers was mine, the same author as the rules.
- The legitimate sample was 8 of 34, the easiest ones included (two Dependabot bumps).
