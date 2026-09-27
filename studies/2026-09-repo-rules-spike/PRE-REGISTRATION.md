# Repo-rules spike: pre-registration (written 2026-09-27, before any trigger was computed)

Question: would maintainer-written co-change rules ("when X changes, Y should too") catch the
misses no reviewer caught in this repository's own releases, and at what false-alarm cost?

Rules: [`rules-draft.md`](rules-draft.md), fixed now, each labelled documented or post-miss.

A co-change rule has two steps, kept apart in both the measurement and the design:

1. **Trigger** (no model): the rule's `when` matches a changed file and its `then` is not
   satisfied (a file required by `all` is unchanged, or none of the `any` files changed).
2. **Judgment** (model): does the change to X actually touch what Y describes? If not, the rule
   holds even though Y did not change.

## Part 1: triggers over history (no model)

- Corpus: every pull request merged into `main`, as listed by `gh pr list --state merged`
  (66 on 2026-09-27). Changed files = `git diff <merge commit>^ <merge commit> --name-only`.
- For each (PR, rule): **not matched** (no `when` file changed), **held by file** (matched and
  `then` satisfied), or **triggered**.
- Every trigger is classified by hand, reading the PR's diff:
  - **real miss**: X's change affected what Y states, and Y was left stale (confirmed by a later
    fix, or by reading Y at the merge commit).
  - **legitimate**: X's change does not touch what Y states (an internal refactor, a test-only
    change, a dependency bump), so Y needed no change.
- Git runs through its absolute path from a script; the agent shell's RTK hook rewrites git
  output and produced false results in an earlier spike.

Measures: triggers per rule; **trigger false-alarm rate** = legitimate / triggered, per rule
and overall; real misses found in history that no reviewer caught.

## Part 2: replay of known misses

| Case | Base..head | Construction | Known miss |
|---|---|---|---|
| K1 | #74, `c33da43..8649dad` | natural | `core/shared/severity.md` not updated after the verdict rule changed |
| K2 | #29, `974061e^..974061e` | revert the `docs/llms.txt` hunks | llms.txt stale |
| K3 | #29, same | revert the i18n `hero.title` and `pipeline.s2.body` hunks | the count spelled as a word, stale in seven locales |
| K4 | #76, `4fd2c6f^..4fd2c6f` | revert the `.cursor-plugin/plugin.json` hunk | `.cursor-plugin` left at the old version |

K3 is expected not to trigger: the i18n files still change (the digit keys were updated), so a
file-level trigger sees `then` satisfied. It is kept in the denominator because it is a known
miss; if the trigger cannot see it, that is a finding about the design, not a reason to drop it.

**Judgment run.** One fresh general-purpose agent per judged item, imitating a reviewer: it
receives the rule sentence (as data, not instruction), the variant's diff and the checkout, and
answers `violated` or `held` with the line that decides it. Judged items:

- every replay case that triggers;
- every real miss found in part 1;
- legitimate triggers from part 1, up to 8, taken in PR-number order with at most two per rule,
  so the sample covers several rules.

An item is **caught** when it triggers and the judgment says `violated`. A legitimate trigger is
**cleared** when the judgment says `held`.

## Stop rule (fixed now)

Stop and report, without designing, if either holds:

- **S1**: fewer than half of the known misses (K1 to K4, so fewer than 2 of 4) are caught.
- **S2**: more than half of all part-1 triggers are legitimate **and** the judgment step clears
  fewer than half of the sampled legitimate triggers. Triggers the judgment clears are rows the
  report shows as `held`, not alarms, so a high raw trigger rate alone is a cost, not a stop.

The maintainer's suggested rule was "stop if most triggers are false alarms". S2 applies it to
what reaches the reader after the judgment step, because the design separates the two steps;
the raw trigger false-alarm rate is reported either way.

## Predictions

- Trigger false-alarm rate is high for C4, C5 and P1 (most core changes are internal), low for
  C2 and C3. Overall above 50%.
- K1, K2, K4 trigger; K3 does not. The judgment calls K1, K2, K4 `violated`: 3 of 4 caught.
- The judgment clears most sampled legitimate triggers, because the diff shows an internal
  change.
- Retro-fit: K1, K2 and K4 are caught by post-miss rules, which says little on its own. The
  informative numbers are the false-alarm rate over history and any real miss part 1 finds that
  no rule author had in mind.
