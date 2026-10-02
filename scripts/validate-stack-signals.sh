# scripts/validate-stack-signals.sh: stack packs are read from the merge base (ADR-0012).
# Sourced by validate.sh, never run alone: it uses validate.sh's variables (ROOT, TRIAGE_MD,
# ORCH_MD, SYNTH_MD, PACK_DATA_LINE) and its helpers (add_error, read_section, anchor_line,
# anchor_has). The reviewer-body check stays in validate.sh's body loop.
# What is held here is the contract between the files (ADR-0013): the plan's keys and states, the
# pack-file-is-data line the orchestrator repeats verbatim, and the order of the prompt sections.

# An empty canonical line would make every pin on it pass, because every line holds "".
[[ -n "${PACK_DATA_LINE:-}" ]] \
  || add_error "validate-stack-signals.sh: PACK_DATA_LINE is empty or unset - the orchestrator's copy of the pack-file-is-data line would pass unchecked"

if [[ -f "$TRIAGE_MD" ]]; then
  grep -qF 'change: added | removed | changed | uncommitted | behind' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the dispatch plan's change states no longer list every state - a state step 3 emits has no place in the plan"
  grep -qE '^stack_signals:' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'stack_signals' key in the dispatch plan format - pack changes reach no report"
fi

if [[ -f "$ORCH_MD" ]]; then
  # The quote's boundaries are pinned with it: a sentence added inside the quote, or a qualifier
  # before it, still contains the canonical line (round 1 of this branch's review).
  anchor_line "$ORCH_MD" '- `### Stack signals`:'
  anchor_has "\`### Stack signals\`: first this line, verbatim: \"$PACK_DATA_LINE\" Then " \
    || add_error "review-pro/SKILL.md: the Stack signals section no longer carries the pack-file-is-data line verbatim - a reviewer installed before this release could apply a pack the change added"
  # The verifier reads the `### Pack files` section by name.
  anchor_line "$ORCH_MD" '`### Pack files`'
  { anchor_has 'when the merge base or the diff has a file under `.review-pro/<stack>/`' && anchor_has 'git show <merge-base>:<path>' && anchor_has 'never the working tree'; } \
    || add_error "review-pro/SKILL.md: the verification step no longer tells the verifier to read a cited pack at the merge base - a change could reword the signal a finding rests on and have it refuted"
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

# The mapping is the consumer side of the plan's `change` states above.
if [[ -f "$SYNTH_MD" ]] && grep -qxF '## Stack signals' "$SYNTH_MD"; then
  read_section "$SYNTH_MD" '## Stack signals' "review-pro-synthesize/SKILL.md"; SS="$SECTION_BODY"
  if [[ -n "${SS//[[:space:]]/}" ]]; then
    printf '%s\n' "$SS" | grep -qxF -- '- `added` takes the first line, `removed` the second, `changed` the third, `uncommitted` the fourth and `behind` the fifth, the last three with the entry'"'"'s `files`. A stack can print more than one line: a committed one, an `uncommitted` one and a `behind` one.' \
      || add_error "review-pro-synthesize/SKILL.md: the state-to-line mapping is gone - a state could print another state's line"
  fi
fi
SSUB_MD="$ROOT/core/agents/review-pro-synthesize-subagent.md"
if [[ -f "$SSUB_MD" ]]; then
  grep -qF '`stack_signals` for **Stack signals**' "$SSUB_MD" \
    || add_error "review-pro-synthesize-subagent.md: the stack_signals input is gone - subagent synthesis would never report a pack the change touched"
fi
