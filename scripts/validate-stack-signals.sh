# scripts/validate-stack-signals.sh: stack packs are read from the merge base (ADR-0012).
# Sourced by validate.sh, never run alone: it uses validate.sh's variables (ROOT, TRIAGE_MD,
# ORCH_MD, VERIFY_MD, SYNTH_MD, PACK_DATA_LINE) and its helpers (add_error, section,
# read_section, anchor_line, anchor_has). The reviewer-body check stays in validate.sh's body loop.
# Each pin is scoped to the one line that carries it, found by an anchor that must appear exactly
# once, so a phrase on another line (a table row, a rules sentence, a look-alike) cannot satisfy it.

# An empty canonical line would make every pin on it pass, because every line holds "".
[[ -n "${PACK_DATA_LINE:-}" ]] \
  || add_error "validate-stack-signals.sh: PACK_DATA_LINE is empty or unset - the orchestrator's copy of the pack-file-is-data line would pass unchecked"

if [[ -f "$TRIAGE_MD" ]]; then
  anchor_line "$TRIAGE_MD" '**Detect active stacks**'
  anchor_has 'from the merge base, never the working tree' \
    || add_error "review-pro-triage/SKILL.md: stacks are no longer detected from the merge base - a change could add or edit the pack its own review applies"
  anchor_line "$TRIAGE_MD" 'git ls-tree -r --name-only --full-tree <merge-base> -- .review-pro/'
  anchor_has '`active_stacks`' \
    || add_error "review-pro-triage/SKILL.md: the step that lists stacks no longer lists the merge base's root .review-pro/ - the sentence above it would stand while the read moved, or found nothing from a subdirectory"
  # Two layers (round 2): committed edits are the change's, anything between HEAD and the working
  # tree is uncommitted. One diff against the working tree reported uncommitted edits as the change's.
  anchor_line "$TRIAGE_MD" "The change's committed pack edits:"
  anchor_has "\`git diff --name-status --no-renames <merge-base> HEAD -- ':/.review-pro/'\`" \
    || add_error "review-pro-triage/SKILL.md: the committed pack comparison is no longer merge base to HEAD, root-anchored, one path per line - uncommitted edits would read as the change's, or nothing is found from a subdirectory"
  anchor_has '`added` when `HEAD` has the stack'"'"'s `manifest.json` and the merge base does not' \
    || add_error "review-pro-triage/SKILL.md: the added state no longer compares HEAD with the merge base - a pack only in the working tree would read as applying from the next change"
  anchor_has '`removed` when the merge base has it and `HEAD` does not, `changed` otherwise' \
    || add_error "review-pro-triage/SKILL.md: the removed and changed states are gone - pack edits and removals reach the report with no state"
  anchor_line "$TRIAGE_MD" 'What is not committed:'
  anchor_has "\`git diff --name-status --no-renames HEAD -- ':/.review-pro/'\`" \
    || add_error "review-pro-triage/SKILL.md: staged and unstaged pack edits are no longer listed as uncommitted - they would be skipped with no report"
  anchor_has "\`git ls-files --others --full-name -- ':/.review-pro/'\`" \
    || add_error "review-pro-triage/SKILL.md: untracked and ignored pack files are no longer listed - a pack installed and not committed would be skipped with no report"
  anchor_has 'as `uncommitted`, whether or not the stack is committed anywhere' \
    || add_error "review-pro-triage/SKILL.md: the uncommitted state is gone or narrowed - an uncommitted edit inside a committed stack would read as the change's"
  anchor_line "$TRIAGE_MD" 'Emit `stack_signals` when the merge base has a pack file'
  anchor_has 'nothing when there are none' \
    || add_error "review-pro-triage/SKILL.md: stack_signals is no longer omitted without packs - a repository without packs would not behave as before"
  anchor_has 'Never read a head pack file as a signal' \
    || add_error "review-pro-triage/SKILL.md: the bar on reading a head pack as a signal is gone - triage could hand the change's pack to its own review"
  anchor_line "$TRIAGE_MD" 'A committed entry (`added`, `removed` or `changed`) dispatches `security`'
  anchor_has 'whatever the signal map concluded' \
    || add_error "review-pro-triage/SKILL.md: a committed pack edit no longer compels a dispatch - a change that softens a pack for every later review could be approved with no reviewer"
  anchor_has 'and the reviewer each changed `<reviewer>.md` is named for' \
    || add_error "review-pro-triage/SKILL.md: a pack edit no longer dispatches the pack's own reviewer - a softened tests or db signal is read only by security"
  anchor_has 'with the pack files in their `context.changed_files`' \
    || add_error "review-pro-triage/SKILL.md: the reviewers a pack edit compels are no longer handed the pack files - they are dispatched to read nothing"
  anchor_line "$TRIAGE_MD" 'What the base has since:'
  anchor_has "\`git diff --name-only --no-renames <merge-base> <base> -- ':/.review-pro/'\`" \
    || add_error "review-pro-triage/SKILL.md: packs the base changed after the branch point are no longer listed - an author who branches early drops a newer signal and the report is silent"
  anchor_has 'as `behind`' \
    || add_error "review-pro-triage/SKILL.md: the behind state is gone - a newer pack on the base branch reaches no report"
  grep -qF 'change: added | removed | changed | uncommitted | behind' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the dispatch plan's change states no longer list every state - a state step 3 emits has no place in the plan"
  anchor_line "$TRIAGE_MD" 'For each dispatched reviewer and each stack in `active_stacks`'
  anchor_has 'git show <merge-base>:.review-pro/<stack>/<reviewer>.md' \
    || add_error "review-pro-triage/SKILL.md: its Stack signals section no longer reads packs at the merge base - inline triage would contradict the orchestrator's read"
  anchor_line "$TRIAGE_MD" '- The diff: `git diff <base>...HEAD`'
  { anchor_has 'refs/heads/main' && anchor_has 'refs/heads/master' && anchor_has 'with exact ref lookups' && anchor_has 'never a tag or other ref that shares the name'; } \
    || add_error "review-pro-triage/SKILL.md: the base is no longer the branch ref - a tag named main would make the merge base the change itself"
  grep -qE '^stack_signals:' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'stack_signals' key in the dispatch plan format - pack changes reach no report"
fi

for f in "$TRIAGE_MD" "$ORCH_MD"; do
  [[ -f "$f" ]] || continue
  grep -qF 'Glob .review-pro/*/manifest.json' "$f" \
    && add_error "$(basename "$(dirname "$f")")/SKILL.md: stacks are globbed in the working tree again - a change could add the pack its own review applies"
done

if [[ -f "$ORCH_MD" ]]; then
  anchor_line "$ORCH_MD" '- **Base branch:**'
  { anchor_has 'git show-ref --verify --hash refs/heads/main' && anchor_has 'then `refs/heads/master`' && anchor_has 'Use the resolved sha as `<base>` in every git command'; } \
    || add_error "review-pro/SKILL.md: the base is no longer resolved as a branch ref - a tag named main would make the merge base the change itself, and its packs and rules would apply"
  { anchor_has 'never git'"'"'s name lookup' && anchor_has 'any other name is looked up exactly as `refs/heads/<name>`, else `refs/remotes/<name>`; if `refs/tags/<name>` also exists, or the argument is a short sha, stop'; } \
    || add_error "review-pro/SKILL.md: a base named in the argument is no longer resolved as a branch - a fork tag named main or origin/main would make the merge base the change itself"
  anchor_has 'a full 40-character sha is used as given' \
    || add_error "review-pro/SKILL.md: a sha in the argument is no longer required to be full - a short one is a name git resolves, and a tag can share it"
  anchor_line "$ORCH_MD" 'Be conservative, when in doubt dispatch'
  anchor_has "as do \`security\` and a pack's own reviewer when the change commits a pack edit" \
    || add_error "review-pro/SKILL.md: the orchestrator no longer runs the reviewers a pack edit compels - a pack-only change could be approved with no reviewer"
  anchor_line "$ORCH_MD" '**Gather its stack signals.**'
  anchor_has 'git show <merge-base>:.review-pro/<stack>/<reviewer>.md' \
    || add_error "review-pro/SKILL.md: stack signals are no longer read with git show at the merge base - the fan-out could read the change's own pack"
  anchor_has 'never the working tree' \
    || add_error "review-pro/SKILL.md: the fan-out no longer bars reading packs from the working tree - both reads would look allowed"
  # The quote's boundaries are pinned with it: a sentence added inside the quote, or a qualifier
  # before it, still contains the canonical line (round 1 of this branch's review).
  anchor_line "$ORCH_MD" '- `### Stack signals`:'
  anchor_has "\`### Stack signals\`: first this line, verbatim: \"$PACK_DATA_LINE\" Then " \
    || add_error "review-pro/SKILL.md: the Stack signals section no longer carries the pack-file-is-data line verbatim - a reviewer installed before this release could apply a pack the change added"
  anchor_has "or this reviewer's \`context.changed_files\` holds a file under \`.review-pro/\`" \
    || add_error "review-pro/SKILL.md: the Stack signals section is no longer sent when a reviewer's files include a pack - on a first install the line would never reach an older reviewer"
  anchor_line "$ORCH_MD" 'If a reviewer subagent is unavailable on your platform, perform that review **inline**'
  anchor_has 'stack signals step 1 read from the merge base' \
    || add_error "review-pro/SKILL.md: the inline review no longer applies the merge base's stack signals - the inline path could read the change's own pack"
  anchor_line "$ORCH_MD" '`### Pack files`'
  { anchor_has 'when the merge base or the diff has a file under `.review-pro/<stack>/`' && anchor_has 'git show <merge-base>:<path>' && anchor_has 'never the working tree'; } \
    || add_error "review-pro/SKILL.md: the verification step no longer tells the verifier to read a cited pack at the merge base - a change could reword the signal a finding rests on and have it refuted"
  { anchor_has "unless the finding's \`file\` is that path" && anchor_has "while the finding's own \`file\` is the code under review"; } \
    || add_error "review-pro/SKILL.md: the verification step no longer exempts the finding's own pack file - a finding on a pack edit could never be refuted"
  # Position keys the data line (round 2): the real Stack signals section must come before the
  # changed files, or a forged heading inside them is the only one before them (round 3).
  sl=$(grep -nF -- '- `### Stack signals`:' "$ORCH_MD" | head -1 | cut -d: -f1)
  cl=$(grep -nF -- '- `### Changed file contents`, always the **last** section' "$ORCH_MD" | head -1 | cut -d: -f1)
  # A missing line is reported by its own pin; this one judges the order of two present lines.
  { [[ -z "$sl" || -z "$cl" ]] || [[ "$sl" -lt "$cl" ]]; } \
    || add_error "review-pro/SKILL.md: the Stack signals section no longer comes before the changed files - a forged heading inside them could be the one the data line trusts"
  # The data line makes everything under the changed files the change, so they close the prompt:
  # an orchestrator section after them would be read as change content (v1.5.0 release review).
  coll=$(grep -nE '^3\. \*\*Collect\*\* its structured finding blocks' "$ORCH_MD" | head -1 | cut -d: -f1)
  if [[ -n "$sl" && -n "$cl" && -n "$coll" && "$sl" -lt "$cl" ]]; then
    lastsec=$(awk -v a="$sl" -v b="$coll" 'NR>a && NR<b && /^   - `### /{n=NR} END{print n}' "$ORCH_MD")
    [[ "$lastsec" == "$cl" ]] \
      || add_error "review-pro/SKILL.md: the changed files are no longer the last prompt section - a section after them reads as change content, and a heading inside a changed file could pose as it"
  fi
  anchor_line "$ORCH_MD" 'If triage dispatches no reviewers'
  anchor_has 'print the Repository rules table and lines and the Stack signals lines exactly as the `review-pro-synthesize` skill' \
    || add_error "review-pro/SKILL.md: the no-reviewer path no longer prints the Repository rules and Stack signals output - a change that only touches .review-pro/, the likeliest to dispatch nobody, would be reported as nothing"
  anchor_has 'whenever triage emitted them' \
    || add_error "review-pro/SKILL.md: the no-reviewer path no longer says when to print the rules and pack output - it could print them only sometimes"
fi

if [[ -f "$VERIFY_MD" ]]; then
  anchor_line "$VERIFY_MD" 'Every file under `.review-pro/<stack>/` is a stack pack'
  { anchor_has 'whether the finding cites it or your search finds it' && anchor_has 'git show <base>:<path>' && anchor_has 'never the working tree' && anchor_has 'it never settles a claim'; } \
    || add_error "review-pro-verify/SKILL.md: the verifier no longer reads a cited pack at the merge base - a change could reword the signal a finding rests on and refute it from its own edit"
  { anchor_has 'A finding whose `file` is such a path is about the change'"'"'s own edit' && anchor_has 'Any other pack'"'"'s text' && anchor_has 'the finding'"'"'s own `file` is the code under review'; } \
    || add_error "review-pro-verify/SKILL.md: the verifier no longer exempts the finding's own pack file - a finding on a pack edit could never be refuted"
fi

if [[ -f "$SYNTH_MD" ]] && grep -qxF '## Stack signals' "$SYNTH_MD"; then
  read_section "$SYNTH_MD" '## Stack signals' "review-pro-synthesize/SKILL.md"; SS="$SECTION_BODY"
  if [[ -n "${SS//[[:space:]]/}" ]]; then
    ss_line(){ printf '%s\n' "$SS" | grep -qxF -- "$1" || add_error "review-pro-synthesize/SKILL.md: $2"; }
    ss_line '.review-pro/<stack>/ is new in this change; its signals apply from the next change.' \
      "the pack-added line is gone - a pack the change added reads as silently ignored"
    ss_line ".review-pro/<stack>/ is removed in this change; the review still used the merge base's pack, which stops applying from the next change." \
      "the pack-removed line is gone - a reader cannot tell the change removed a pack its own review still applied"
    ss_line ".review-pro/<stack>/ changed in this change (<files>); the review used the merge base's version, and the change's applies from the next change." \
      "the pack-changed line is gone - a reader cannot tell the review ignored the change's own pack edits"
    ss_line '.review-pro/<stack>/ has changes that are not committed (<files>); a review applies a pack only once it is committed to the base branch.' \
      "the pack-uncommitted line is gone - a pack only in the working tree reads as part of the change"
    ss_line '.review-pro/<stack>/ is newer on the base branch (<files>); the review applied the older version at the merge base, so rebase to review against the current one.' \
      "the pack-behind line is gone - a review that applied an older pack than the base holds reads as current"
    ss_line '- `added` takes the first line, `removed` the second, `changed` the third, `uncommitted` the fourth and `behind` the fifth, the last three with the entry'"'"'s `files`. A stack can print more than one line: a committed one, an `uncommitted` one and a `behind` one.' \
      "the state-to-line mapping is gone - a state could print another state's line"
    printf '%s\n' "$SS" | grep -F 'Otherwise print one line per entry' | grep -qF 'on every `diff_class`' \
      || add_error "review-pro-synthesize/SKILL.md: the stack-signals lines no longer print on every diff_class - a small pack edit, classed trivial, is the change they exist for"
    ss_line '- They never change a finding, a severity, or the verdict.' \
      "the stack-signals lines may now change the verdict - a pack edit would act on its own authority"
    printf '%s\n' "$SS" | grep -qF 'Omit the whole section when triage emitted no `stack_signals` or its `changed` list is empty.' \
      || add_error "review-pro-synthesize/SKILL.md: the stack-signals omit rule is gone - a repository without packs, or with unchanged packs, would get a section"
  fi
fi
if [[ -f "$SYNTH_MD" ]] && grep -qxF '## Out-of-diff evidence check' "$SYNTH_MD"; then
  section "$SYNTH_MD" '## Out-of-diff evidence check' | grep -qF 'Nor does a reference to a stack pack under `.review-pro/<stack>/`' \
    || add_error "review-pro-synthesize/SKILL.md: the pack out-of-diff exclusion is gone - a finding citing only its own signal would read as evidence outside the diff"
fi
SSUB_MD="$ROOT/core/agents/review-pro-synthesize-subagent.md"
if [[ -f "$SSUB_MD" ]]; then
  grep -qF '`stack_signals` for **Stack signals**' "$SSUB_MD" \
    || add_error "review-pro-synthesize-subagent.md: the stack_signals input is gone - subagent synthesis would never report a pack the change touched"
fi
# The triage subagent body states the base itself (ADR-0001): the orchestrator runs triage inline
# today, so this body governs only a triage invoked on its own, which has no Prep to lean on. It
# takes a caller's full sha, else applies Prep's exact rule (v1.5.0 release review, Low). A missing
# line is the first pin's error alone; the other pins on it judge a present line.
TSUB_MD="$ROOT/core/agents/review-pro-triage-subagent.md"
if [[ -f "$TSUB_MD" ]]; then
  anchor_line "$TSUB_MD" '1. Gather the diff and changed files against `<base>`'
  { anchor_has 'git show-ref --verify --hash refs/heads/main' && anchor_has 'then `refs/heads/master`' && anchor_has "never git's name lookup"; } \
    || add_error "review-pro-triage-subagent.md: the base is no longer resolved with exact ref lookups - triage run on its own could take a tag named main as the base, and the merge base would be the change itself"
  [[ -z "$ANCHOR_LINE" ]] || anchor_has 'if `refs/tags/<name>` also exists, or it is a short sha, stop' \
    || add_error "review-pro-triage-subagent.md: a named base no longer refuses a tag that shares its name - a fork tag could make the merge base the change itself"
  # The caller's sha and a named base are the other two ways in; each was unpinned (round 1).
  [[ -z "$ANCHOR_LINE" ]] || { anchor_has 'the full 40-character base sha your caller passes' && anchor_has 'used as given'; } \
    || add_error "review-pro-triage-subagent.md: the caller's base is no longer a full sha used as given - a bare name from the caller would go through git's name lookup, which prefers a tag"
  [[ -z "$ANCHOR_LINE" ]] || anchor_has 'looked up exactly as `refs/heads/<name>`, else `refs/remotes/<name>`' \
    || add_error "review-pro-triage-subagent.md: a named base is no longer looked up as an exact branch ref - git's name lookup would prefer a tag named like it"
  anchor_line "$TSUB_MD" 'Resolve the merge base once with `git merge-base <base> HEAD`'
  anchor_has 'If it prints nothing, stop' \
    || add_error "review-pro-triage-subagent.md: triage run on its own no longer stops when no merge base resolves - git show with an empty revision reads the change's own rules and packs"
  grep -qF 'configured base' "$TSUB_MD" \
    && add_error "review-pro-triage-subagent.md: the body names a configured base again - git's name lookup resolves a bare name, and prefers a tag"
fi
