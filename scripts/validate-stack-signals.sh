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
  anchor_line "$TRIAGE_MD" "List the head's pack files"
  anchor_has 'including untracked and ignored ones' \
    || add_error "review-pro-triage/SKILL.md: the head listing no longer includes untracked and ignored packs - a pack installed and not committed would be skipped with no report"
  anchor_line "$TRIAGE_MD" 'Compare the two lists.'
  anchor_has "\`git diff --name-status --no-renames <merge-base> -- ':/.review-pro/'\`" \
    || add_error "review-pro-triage/SKILL.md: the pack comparison is no longer root-anchored with one path per line - from a subdirectory it finds nothing, and a rename hides one path"
  anchor_has '`added` when only the head has the stack'"'"'s `manifest.json` and `HEAD` has it committed' \
    || add_error "review-pro-triage/SKILL.md: the added state no longer requires a committed manifest - an uncommitted pack would read as applying from the next change"
  anchor_has '`uncommitted` when only the working tree has it' \
    || add_error "review-pro-triage/SKILL.md: the uncommitted state is gone - a pack only in the working tree would read as applying from the next change"
  anchor_has '`removed` when only the merge base has it, `changed` otherwise' \
    || add_error "review-pro-triage/SKILL.md: the removed and changed states are gone - pack edits and removals reach the report with no state"
  anchor_line "$TRIAGE_MD" 'Emit `stack_signals` when either list is non-empty'
  anchor_has 'nothing when both are empty' \
    || add_error "review-pro-triage/SKILL.md: stack_signals is no longer omitted without packs - a repository without packs would not behave as before"
  anchor_has 'Never read a head pack file as a signal' \
    || add_error "review-pro-triage/SKILL.md: the bar on reading a head pack as a signal is gone - triage could hand the change's pack to its own review"
  grep -qE '^stack_signals:' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'stack_signals' key in the dispatch plan format - pack changes reach no report"
fi

for f in "$TRIAGE_MD" "$ORCH_MD"; do
  [[ -f "$f" ]] || continue
  grep -qF 'Glob .review-pro/*/manifest.json' "$f" \
    && add_error "$(basename "$(dirname "$f")")/SKILL.md: stacks are globbed in the working tree again - a change could add the pack its own review applies"
done

if [[ -f "$ORCH_MD" ]]; then
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
  { anchor_has 'git show <base>:<path>' && anchor_has 'never the working tree'; } \
    || add_error "review-pro/SKILL.md: the verification step no longer tells the verifier to read a cited pack at the merge base - a change could reword the signal a finding rests on and have it refuted"
  anchor_line "$ORCH_MD" 'If triage dispatches no reviewers'
  anchor_has 'the Stack signals lines exactly as the `review-pro-synthesize` skill' \
    || add_error "review-pro/SKILL.md: the no-reviewer path no longer prints the Stack signals lines - a change that only adds a pack, the likeliest to dispatch nobody, would be reported as nothing"
fi

if [[ -f "$VERIFY_MD" ]]; then
  anchor_line "$VERIFY_MD" 'A file under `.review-pro/<stack>/` that the finding names in `evidence_refs`'
  { anchor_has 'git show <base>:<path>' && anchor_has 'never the working tree'; } \
    || add_error "review-pro-verify/SKILL.md: the verifier no longer reads a cited pack at the merge base - a change could reword the signal a finding rests on and refute it from its own edit"
fi

if [[ -f "$SYNTH_MD" ]] && grep -qxF '## Stack signals' "$SYNTH_MD"; then
  read_section "$SYNTH_MD" '## Stack signals' "review-pro-synthesize/SKILL.md"; SS="$SECTION_BODY"
  if [[ -n "${SS//[[:space:]]/}" ]]; then
    ss_line(){ printf '%s\n' "$SS" | grep -qxF -- "$1" || add_error "review-pro-synthesize/SKILL.md: $2"; }
    ss_line '.review-pro/<stack>/ is new in this change; its signals apply from the next change.' \
      "the pack-added line is gone - a pack the change added reads as silently ignored"
    ss_line '.review-pro/<stack>/ is not committed; its signals apply once it is committed to the base branch.' \
      "the pack-uncommitted line is gone - a pack only in the working tree reads as applying from the next change"
    ss_line ".review-pro/<stack>/ is removed in this change; the review still used the merge base's pack." \
      "the pack-removed line is gone - a reader cannot tell the change removed a pack its own review still applied"
    ss_line ".review-pro/<stack>/ changed in this change (<files>); the review used the merge base's version." \
      "the pack-changed line is gone - a reader cannot tell the review ignored the change's own pack edits"
    ss_line '- `added` takes the first line, `uncommitted` the second, `removed` the third, `changed` the fourth, with the entry'"'"'s `files`.' \
      "the state-to-line mapping is gone - a state could print another state's line"
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
