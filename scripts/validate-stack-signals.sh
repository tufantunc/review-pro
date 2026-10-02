# scripts/validate-stack-signals.sh: stack packs are read from the merge base (ADR-0012).
# Sourced by validate.sh, never run alone: it uses validate.sh's variables (ROOT, TRIAGE_MD,
# ORCH_MD, VERIFY_MD, SYNTH_MD, PACK_DATA_LINE) and its helpers (add_error, read_section,
# anchor_line, anchor_has). The reviewer-body check stays in validate.sh's body loop.
# What is held here is the contract between the files (ADR-0013): the plan's keys and states, the
# pack-file-is-data line the orchestrator repeats verbatim, the base rule review.sh and the triage
# subagent restate, the verifier rules the orchestrator's prompt restates, the report lines the
# state mapping points at, and the order of the prompt sections. Each pin is scoped to the one
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
  grep -qE '^stack_signals:' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'stack_signals' key in the dispatch plan format - pack changes reach no report"
fi

if [[ -f "$ORCH_MD" ]]; then
  anchor_line "$ORCH_MD" '- **Base branch:**'
  { anchor_has 'git show-ref --verify --hash refs/heads/main' && anchor_has 'then `refs/heads/master`' && anchor_has 'Use the resolved sha as `<base>` in every git command'; } \
    || add_error "review-pro/SKILL.md: the base is no longer resolved as a branch ref - a tag named main would make the merge base the change itself, and its packs and rules would apply"
  { anchor_has 'never git'"'"'s name lookup' && anchor_has 'any other name is looked up exactly as `refs/heads/<name>`, else `refs/remotes/<name>`; if `refs/tags/<name>` also exists, or the argument is a short sha, stop'; } \
    || add_error "review-pro/SKILL.md: a base named in the argument is no longer resolved as a branch - a fork tag named main or origin/main would make the merge base the change itself"
  anchor_has 'a full ref (`refs/...`) is looked up exactly with `git show-ref --verify --hash`' \
    || add_error "review-pro/SKILL.md: a full ref in the argument is no longer looked up exactly - git's name lookup falls through to a tag named refs/heads/main when that branch is missing"
  anchor_has 'a full 40-character sha is used as given' \
    || add_error "review-pro/SKILL.md: a sha in the argument is no longer required to be full - a short one is a name git resolves, and a tag can share it"
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
  [[ -z "$ANCHOR_LINE" ]] || anchor_has 'and a full ref (`refs/...`) with `git show-ref --verify --hash`' \
    || add_error "review-pro-triage-subagent.md: a full ref is no longer looked up exactly - git's name lookup falls through to a tag named refs/heads/main when that branch is missing"
  anchor_line "$TSUB_MD" 'Resolve the merge base once with `git merge-base <base> HEAD`'
  anchor_has 'If it prints nothing, stop' \
    || add_error "review-pro-triage-subagent.md: triage run on its own no longer stops when no merge base resolves - git show with an empty revision reads the change's own rules and packs"
  grep -qF 'configured base' "$TSUB_MD" \
    && add_error "review-pro-triage-subagent.md: the body names a configured base again - git's name lookup resolves a bare name, and prefers a tag"
fi
