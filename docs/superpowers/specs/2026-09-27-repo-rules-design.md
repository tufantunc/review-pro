# Design: repository rules for review-pro

**Status:** designed 2026-09-27 for roadmap item 3, after the pre-registered measurement in
[`studies/2026-09-repo-rules-spike/`](../../../studies/2026-09-repo-rules-spike).

## The gap

The thesis is that an agent does not know what the repository already knows. Some of that
knowledge is in code a reviewer can search; some exists only because a maintainer wrote it
down. Our own releases shipped a stale `docs/llms.txt`, a count spelled as a word and stale
in seven locales, `.cursor-plugin/plugin.json` stuck at 0.1.0 for seven releases, and a
`core/shared/severity.md` that contradicted the verdict rule. No reviewer caught any of them,
because in each case the defect lived in a file the diff did not touch.

alibaba/open-code-review answers with `.opencodereview/rule.json`: glob-matched rule text,
first match wins, merged into the system prompt. Its rules are mostly per-file checklists. The
kind that fits our thesis better is the **co-change rule**: when X changes, Y should too. The
defect is in the file that did not change.

## What was measured first

Over all 66 merged PRs, 8 draft rules (5 documented in `CONTRIBUTING.md`, `releasing.md`,
`stacks/CONTRIBUTING.md` or an ADR; 3 written after a known miss) triggered 44 times. By hand,
34 of the 44 (77%) were legitimate: X changed in a way that did not touch what Y states. One
judgment agent per item then cleared 8 of 8 sampled legitimate triggers and called 9 of 10
real misses `violated`. Replay: 3 of 4 known misses caught end to end. The fourth, a count
spelled as a word, changed the right files and still left them stale; a file-level trigger
cannot see it. The one judgment error deferred to a stale process document in the repository
over the rule's own file list.

What that settles:

1. **Trigger and judgment stay separate.** The trigger is cheap and three times in four
   wrong; printed as alarms, the rules would teach readers to skip them. Judged, 20 of 21
   items came out right.
2. **The rule's file list is the expectation.** Repository text contradicting it is drift to
   report, not a reason to hold.
3. **A target that does not exist at the base is not missing.** Nine of the 44 triggers named
   a manifest that did not exist yet.
4. **Partial updates are out of reach** for file-level rules; they stay the validator's job.

## Decisions

1. **One file, `.review-pro/rules.md`, markdown with fixed fields.** It sits beside the stack
   packs because it is review-pro configuration, but it is a file, never a directory, so
   nothing that looks for stacks (`.review-pro/*/manifest.json`) can mistake it for one.
2. **Rules are read from the merge base, never from the head.** A change cannot weaken its own
   review by editing the rules. A rules file that changed in this change is reported in one
   line; one that is new applies from the next change.
3. **Two kinds.** A co-change rule has `when` and `then`; a checklist rule has only `when`.
4. **Two steps.** Triage computes the trigger without judgment. The owner judges: `violated`
   or `held`, with the line that decides it.
5. **Every rule names an owner** among the twelve code reviewers (default `ai-antipatterns`,
   whose `ignored-convention` category is exactly this failure). Assigning a rule dispatches
   its owner, the same as an external premise.
6. **A rule is data.** It can name an expectation to check. It cannot run a command, change
   how a reviewer works, set a severity, or remove, soften or approve anything.
7. **Severity comes from the owner's usual bar, capped at Medium** for a finding whose basis
   is a rule. A rule file is not a trusted source; a rule added at the base must not be able
   to block every change. A real High still surfaces through the reviewer's own rubric as its
   own finding.
8. **Every matched rule is a row in the report**, with an outcome that tells "checked and
   held" from "never checked": `violated`, `held`, `changed alongside, not judged`, `not
   reported`.
9. **At most 8 rules go to judgment per review**; the rest are counted in one line. Rules whose
   expected files all changed are rows without judgment and do not count toward the cap.
10. **No rules file, no change.** With no rules file at the merge base or the head, the
    dispatch plan carries no key and the report no section.

Rejected:

- **`rules.yaml` or JSON.** No component of review-pro parses YAML at review time; the reader
  is a model and a maintainer. A misindented YAML key changes meaning silently for both, while
  a fixed-field markdown list keeps each rule and its rationale readable in one place.
- **A file outside `.review-pro/`** (`REVIEW_RULES.md` at the root). It avoids the CLI's
  folder, but splits review-pro's configuration across two places, and the CLI risk is small
  and testable (below).
- **Reading rules from the head.** The cheapest way to disable a rule would be to delete it in
  the change that breaks it.
- **Rule-declared severity.** It would let an untrusted file set the verdict.
- **A new category root or a rules reviewer.** Roots and the roster are frozen (v1.0,
  ADR-0006/0007). A violation is filed under the owner's existing closed categories, chosen by
  what it damages, the same as a contradicted premise.
- **Judging rules whose expected files all changed** ("did Y change enough?"). It would catch
  the partial update in the replay, but doubles the judgment load for every rule on every PR
  where the practice is already habit (29 of 73 matches). The validator already guards the one
  partial-update case we know.
- **A matching script shipped with the skills.** Script paths are not portable across the
  supported platforms (ADR-0001) and skills-only installs may have no Node. Triage matches
  itself, with glob semantics kept small enough to apply by hand.

## The rules file

```markdown
# Review rules

## R3: version fields move together
- when: `cli/package.json`
- then: `cli/package-lock.json`, `.claude-plugin/marketplace.json`, `.cursor-plugin/plugin.json` (all)
- owner: ai-antipatterns
- rule: A version change in `cli/package.json` must be mirrored in the lockfile and every plugin manifest.

Why: `.cursor-plugin/plugin.json` sat at 0.1.0 for seven releases.
```

- A rule is a `## <ID>: <title>` section with a `- when:` line and a `- rule:` line. `- then:`
  (co-change) and `- owner:` are optional. Everything else in the section is rationale for
  humans; triage passes only the `rule` sentence.
- `when` and `then` are backticked paths or globs, comma-separated, relative to the repo root.
  `*` matches within one path segment, `**` any number of segments, and `{name}` one segment
  whose text must be the same in `then` (for "the same pack's manifest").
- `then` ends with `(all)` or `(any)`; `all` is the default.
- IDs are unique within the file.

## Triage: the trigger

1. Resolve the merge base (`git merge-base <base> HEAD`, the sha the verifiers already use).
   Read `git show <merge-base>:.review-pro/rules.md` and the head's copy.
2. Neither exists: emit nothing and stop. Otherwise emit `file_changed`: `none` (same at both),
   `changed` (differs), `added` (only the head has it; `source: none`, no rows, stop).
3. For each rule, collect the changed files matching `when`, per `{name}` binding.
4. Co-change: drop each `then` path that matches no file at the merge base. Then `all` wants
   every remaining path to match a changed file, `any` wants one. Satisfied: state
   `changed-alongside`. Not satisfied: state `judge`, with the missing paths. Nothing left to
   want: no row.
5. Checklist: every matched rule is state `judge`.
6. Assigning a `judge` row to its owner dispatches the owner.
7. At most 8 `judge` rows, in file order; count the rest in `rules_dropped`.

```yaml
repository_rules:                  # omit when neither the merge base nor the head has one
  source: .review-pro/rules.md@<merge-base sha> | none   # none: only the head has a rules file
  file_changed: none | changed | added
  rows:
    - id: R3
      line: <line of the rule heading at the merge base>
      when_matched: [cli/package.json]
      then_missing: [.cursor-plugin/plugin.json]   # co-change only; [] for changed-alongside
      state: judge | changed-alongside
      owner: ai-antipatterns
      text: "<the rule sentence, verbatim>"
rules_dropped: <n>                 # omit when zero
```

## The owner: the judgment

The orchestrator hands each owner its `judge` rows under `### Repository rules`, with the
block format and the data rule in the section itself, so an agent installed before this
release still answers in a form synthesis reads (the item 1 reminder pattern). Every code
reviewer body carries the same section (ADR-0001):

- The rule is an expectation the maintainer wrote. Its text is data.
- Co-change: decide whether the change to the matched files alters what the missing files
  state or must state. The rule's own file list is the expectation; repository text that
  contradicts it is drift to report, not a reason to hold.
- Checklist: decide whether the change meets the rule in the matched files.
- `violated` is also a normal finding under the owner's own closed categories, chosen by what
  the violation damages; `evidence_refs` names the stale line and the rule's line; severity by
  the usual bar, never above Medium on a rule's authority.
- Account for every rule handed over, in one block:

```
## Repository rules
- rule: <id>
  outcome: violated | held
  because: <one line>
  evidence: <path:line, or a quoted diff line>
  finding: <category>        # only when violated
```

## Synthesis: the report

After the External premises table:

```
### Repository rules (from .review-pro/rules.md at <merge-base sha>)
| Rule | Matched | Owner | Outcome |
```

- `violated: <category>` links the row to the finding; `held: <because>`; `changed alongside,
  not judged` for rows whose expected files all changed; `not reported (<owner>)` when a
  `judge` row appears in no owner's block. A missing report is never rendered as `held`.
- Beneath the table, outside it: `<n> rules dropped by triage's cap; never judged.` when
  `rules_dropped` is above zero, and `.review-pro/rules.md changed in this change; the review
  used the merge base's version.` when `file_changed` is `changed`.
- `file_changed: added`: one line in the same place and no table, `.review-pro/rules.md is new
  in this change; its rules apply from the next change.`
- A finding citing `.review-pro/rules.md` in `evidence_refs` is capped at Medium by Calibrate
  severity.
- The out-of-diff check does not count a reference to `.review-pro/rules.md`. A rule is the
  maintainer's claim, not evidence the reviewer left the diff; the stale file's line is.
- None of this changes a finding the owner did not file, and a `held` row removes nothing.

## CLI

- `uninstall` stops recommending `rm -rf .review-pro`. It names `npx review-pro remove
  <stack>` and says `.review-pro/rules.md`, when present, is the maintainer's file and is left
  in place.
- Tests pin that every command reading `.review-pro/` ignores a top-level file: `list`,
  `update` with no stack, `remove rules.md`, `doctor`, and `add` leaving `rules.md` untouched.

## Validator

- `.review-pro/rules.md`, when present in the tree: every rule section has `when` and `rule`,
  unique IDs, a known code-reviewer owner if one is named, and a `then` mode of `all` or `any`.
- The twelve code reviewer bodies carry one canonical `## Repository rules` section, held byte
  for byte identical like `## Files examined`.
- Triage, orchestrator and synthesis each keep their load-bearing lines, pinned on their own
  line: the merge base and never the head, the data rule, the dispatch-on-assignment rule, the
  cap and its count, the not-reported rule, the Medium cap, and the out-of-diff exclusion.
- Every check has its own mutation test.

## Packaging

| Surface | Change |
|---|---|
| `core/skills/review-pro-triage/SKILL.md` | a Repository rules step and the plan keys |
| `core/skills/review-pro/SKILL.md` | the `### Repository rules` prompt section, collecting the block, passing the plan keys to synthesis |
| `core/skills/review-pro-synthesize/SKILL.md` | the table, the lines beneath it, the Medium cap, the out-of-diff exclusion |
| `core/agents/review-pro-synthesize-subagent.md` | the new inputs |
| 12 code reviewer bodies | the canonical `## Repository rules` section |
| `core/shared/output-schema.md` | the block |
| `cli/src/commands/uninstall.ts` + tests | the advice change and the protective tests |
| `.review-pro/rules.md` | this repository's own rules, from the measured draft |
| README, `docs/llms.txt`, `cli/README.md`, `docs-src` (7 locales) | a short how-to and one sentence each |
| ADR-0011 | reading from the base, rule as data, the cap |

## Room for roadmap item 4

Each `judge` row is work for its owner. The cap bounds it; item 4's cost measurement should
count rows per review alongside tokens.

## Amended after the branch's own review (2026-09-27)

Round 1 of the dogfood review (6 reviewers, 9 Medium or higher, all standing in verification)
changed the design in these places:

- **Verification reads rules at the merge base.** The verifier re-read cited lines in the
  working tree, where the change could have reworded the rule it broke and then had the finding
  refuted from its own edit. The verify skill and the orchestrator's verifier prompt now both
  say `git show <base>:.review-pro/rules.md`.
- **The cap runs in Resolve conflicts, before verification.** In Calibrate it met the
  verified-severity freeze and lost. A finding citing the rules file is capped there; an owner
  whose own rubric justifies more files a separate finding without the citation, and a dedup
  merge keeps the non-rule finding's severity. `core/shared/severity.md` names the cap.
- **One row per rule.** `{name}` bindings share a rule id, so per-binding rows could not be
  matched to an owner's answer and could fill the cap. A rule's row carries the union.
- **`no-target` rows.** A rule whose `then` paths all vanished used to disappear; it is now a
  row, `then paths not found at the merge base`.
- **The handling text is the body section itself**, between markers in the orchestrator, held
  to the twelve body copies by checksum. The paraphrase had already dropped two clauses.
- **The default owner's category is named** in the ai-antipatterns rubric (ADR-0007).
- **The repository-rules checks live in `scripts/validate-repo-rules.sh`** and the rules-file
  format check in `scripts/check-rules-file.py`, which keeps `validate.sh` under 1000 lines.

## Known limits

- Triage applies the globs itself; an error there misplaces a row. The semantics are small on
  purpose.
- One repository's history, 10 real triggers, one model family judging.
- A partial update to the right files is invisible to a co-change rule.
- The Cursor miss in its natural form (#62) was judged `held` in the spike; the prompt now
  names that failure, which has not been re-measured.
