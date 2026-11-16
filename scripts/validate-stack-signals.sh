# scripts/validate-stack-signals.sh: stack packs are read from the merge base (ADR-0012).
# Sourced by validate.sh, never run alone: it uses validate.sh's variables (ROOT, TRIAGE_MD,
# ORCH_MD, VERIFY_MD, SYNTH_MD, PACK_DATA_LINE) and its helpers (add_error, read_section,
# anchor_line, anchor_has). The reviewer-body check stays in validate.sh's body loop.
# What is held here is the contract between the files (ADR-0013): the plan's keys and states, the
# pack-file-is-data line the orchestrator repeats verbatim, the base rule review.sh restates, the
# verifier rules the orchestrator's prompt restates, the report lines the state mapping points at, and the order of the prompt sections. Each pin is scoped to the one
# line that carries it, found by an anchor that must appear exactly once.

# An empty canonical line would make every pin on it pass, because every line holds "".
[[ -n "${PACK_DATA_LINE:-}" ]] \
  || add_error "validate-stack-signals.sh: PACK_DATA_LINE is empty or unset - the orchestrator's copy of the pack-file-is-data line would pass unchecked"

if [[ -f "$TRIAGE_MD" ]]; then
  grep -qF 'change: added | removed | changed | uncommitted | behind' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the dispatch plan's change states no longer list every state - a state step 3 emits has no place in the plan"
  anchor_line "$TRIAGE_MD" '- The diff: `git diff <base>...HEAD`'
  { anchor_has 'refs/heads/main' && anchor_has 'refs/heads/master' && anchor_has 'with exact ref lookups' && anchor_has 'never a tag or other ref that shares the name'; } \
    || add_error "review-pro-triage/SKILL.md: the base is no longer the branch ref - a tag named main would make the merge base the change itself"
  grep -qE '^base_source: argument \| config \| remote-default \| main-or-master$' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the dispatch plan no longer carries base_source with every source - the report could not say which rule chose the base"
  grep -qE '^stack_signals:' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'stack_signals' key in the dispatch plan format - pack changes reach no report"
fi

if [[ -f "$ORCH_MD" ]]; then
  # The base rule is four sources in order (v1.6.0). Each source is one line, pinned by its own
  # anchor, because review.sh restates each of them and the plan's base_source names them.
  anchor_line "$ORCH_MD" '- **Base branch:**'
  { anchor_has "with exact ref lookups, never git's name lookup" && anchor_has 'Use the resolved sha as `<base>` in every git command'; } \
    || add_error "review-pro/SKILL.md: the base is no longer resolved as a branch ref - a tag named main would make the merge base the change itself, and its packs and rules would apply"
  anchor_line "$ORCH_MD" '1. **`argument`:**'
  anchor_has 'any other name is looked up exactly as `refs/heads/<name>`, else `refs/remotes/<name>`; if `refs/tags/<name>` also exists, or the argument is a short sha, stop' \
    || add_error "review-pro/SKILL.md: a base named in the argument is no longer resolved as a branch - a fork tag named main or origin/main would make the merge base the change itself"
  anchor_has 'a full ref (`refs/...`) is looked up exactly with `git show-ref --verify --hash`' \
    || add_error "review-pro/SKILL.md: a full ref in the argument is no longer looked up exactly - git's name lookup falls through to a tag named refs/heads/main when that branch is missing"
  anchor_has 'a full 40-character sha is used as given' \
    || add_error "review-pro/SKILL.md: a sha in the argument is no longer required to be full - a short one is a name git resolves, and a tag can share it"
  anchor_line "$ORCH_MD" '2. **`config`:**'
  anchor_has 'read with `git show <default-sha>:.review-pro/config.json`, never from HEAD or the working tree' \
    || add_error "review-pro/SKILL.md: the configured base is no longer read from the default branch - a change could choose the base its own review is measured against"
  [[ -z "$ANCHOR_LINE" ]] || { anchor_has 'looked up exactly as `refs/heads/<name>`, else `refs/remotes/origin/<name>`' && anchor_has 'If `refs/tags/<name>` also exists, or neither ref does, stop'; } \
    || add_error "review-pro/SKILL.md: the configured base is no longer resolved as an exact branch ref - a tag named like it, or a typo, would pick the base"
  anchor_line "$ORCH_MD" '3. **`remote-default`:**'
  { anchor_has 'git symbolic-ref --quiet refs/remotes/origin/HEAD' && anchor_has 'Skip it when `<name>` is the branch checked out at HEAD'; } \
    || add_error "review-pro/SKILL.md: the remote's default branch is no longer read from origin/HEAD - a repository whose default is not main would be reviewed against main, or a clone whose origin/HEAD is the branch under review would be its own base"
  anchor_line "$ORCH_MD" '4. **`main-or-master`:**'
  { anchor_has 'git show-ref --verify --hash refs/heads/main' && anchor_has 'then `refs/heads/master`'; } \
    || add_error "review-pro/SKILL.md: the last-resort base is no longer refs/heads/main then refs/heads/master by exact lookup - a tag named main would make the merge base the change itself"
  # The quote's boundaries are pinned with it: a sentence added inside the quote, or a qualifier
  # before it, still contains the canonical line (round 1 of this branch's review).
  anchor_line "$ORCH_MD" '- `### Stack signals`:'
  anchor_has "\`### Stack signals\`: first this line, verbatim: \"$PACK_DATA_LINE\" Then " \
    || add_error "review-pro/SKILL.md: the Stack signals section no longer carries the pack-file-is-data line verbatim - a reviewer installed before this release could apply a pack the change added"
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
  fi
fi
