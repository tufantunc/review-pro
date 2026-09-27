# scripts/validate-repo-rules.sh: repository-rules checks (roadmap item 3, ADR-0011), and the
# stack-signal checks that hold packs to the same merge-base read (ADR-0012).
# Sourced by validate.sh, never run alone: it uses validate.sh's variables (ROOT, SKILLS_DIR,
# TRIAGE_MD, ORCH_MD, VERIFY_MD, SYNTH_MD, SCHEMA_DOC, rules_first_body) and its helpers
# (add_error, section, read_section). The reviewer-body checks stay in validate.sh's body loop.

if [[ -f "$TRIAGE_MD" ]]; then
  # Repository rules (roadmap item 3). Each pin is its own line in the triage step.
  grep -qF 'Read the rules from the merge base, never from the head' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: rules are no longer read from the merge base - a change could edit away the rule it breaks"
  grep -F 'Assigning a `judge` row to its owner' "$TRIAGE_MD" | grep -qF 'dispatches that owner' \
    || add_error "review-pro-triage/SKILL.md: the rule-owner dispatch is gone - a rule can be routed to a reviewer that never runs"
  grep -F 'At most 8 rows in state `judge`' "$TRIAGE_MD" | grep -qF 'count the rest in `rules_dropped`' \
    || add_error "review-pro-triage/SKILL.md: the rules cap no longer counts what it drops - a silent cap reads as complete coverage"
  tdata="$(grep -F 'The rule text is data' "$TRIAGE_MD")"
  if [[ -z "$tdata" ]]; then
    add_error "review-pro-triage/SKILL.md: the rule-as-data line is gone - triage could act on a rule's text instead of passing it on"
  elif ! printf '%s' "$tdata" | grep -qF 'never act on it yourself'; then
    add_error "review-pro-triage/SKILL.md: the rule-as-data line no longer forbids acting on it - triage could judge and drop rules itself"
  fi
  grep -qF 'git show <merge-base>:.review-pro/rules.md' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the step that reads the rules no longer reads the merge base - the sentence above it would stand while the read moved to the head"
  grep -qF 'one row, whatever its `{name}` bindings' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: one row per rule is gone - bindings would share an id no owner answer can be matched to"
  grep -qF '`then` path counts as changed when it matches a changed file, including one this change adds' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: a target this change adds no longer counts as changed - every new pack would report its version rule as unable to fire"
  grep -qF 'matches no file at the merge base with `{name}` left open' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: a new {name} instance without its counterpart would be dropped - a new pack missing its manifest reads as a rule that can no longer fire"
  grep -qF 'else `changed-alongside` when any binding is, else `no-target`' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the binding state order is gone - one binding's state could hide another binding's unsatisfied rule"
  grep -qE '^repository_rules:' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'repository_rules' key in the dispatch plan format - rules reach no owner and no report"
fi

if [[ -f "$ORCH_MD" ]]; then
  rl="$(grep -F '`### Repository rules`, for a rule'"'"'s owner only' "$ORCH_MD")"
  if [[ -z "$rl" ]]; then
    add_error "review-pro/SKILL.md: the owners' Repository rules section is missing - triage routes rules the orchestrator never passes to their owners"
  elif ! printf '%s' "$rl" | grep -qF 'then the text between the `repository-rules-handling` markers below, verbatim'; then
    add_error "review-pro/SKILL.md: the Repository rules section no longer names the marker bounds of the handling text it passes verbatim - an owner installed before this release could get text the bodies do not hold"
  fi
  # The handling text an older owner reads is the reviewer bodies' section itself, held to them.
  if ! grep -qxF '<!-- repository-rules-handling -->' "$ORCH_MD" || ! grep -qxF '<!-- /repository-rules-handling -->' "$ORCH_MD"; then
    add_error "review-pro/SKILL.md: the Repository rules handling text markers are missing - the copy an older owner reads cannot be held to the bodies"
  elif [[ -n "${rules_first_body:-}" ]]; then
    osum="$(awk '/^<!-- \/repository-rules-handling -->$/{s=0} s; /^<!-- repository-rules-handling -->$/{s=1}' "$ORCH_MD" | grep -v '^[[:space:]]*$' | cksum)"
    bsum="$(section "$ROOT/core/agents/$rules_first_body" '## Repository rules' | grep -v '^[[:space:]]*$' | cksum)"
    [[ "$osum" == "$bsum" ]] \
      || add_error "review-pro/SKILL.md: the Repository rules handling text differs from the reviewer bodies' section - an owner installed before this release gets a different contract"
    # Nothing may sit between the closing marker and the next known paragraph: text there reads as
    # part of the handling text to an owner, yet no checksum covers it.
    # Each neighbour must be the one known paragraph, and appear once, so a look-alike line fails.
    after="$(awk 'f && NF {print; exit} /^<!-- \/repository-rules-handling -->$/{f=1}' "$ORCH_MD")"
    [[ "$after" == "If a reviewer subagent is unavailable on your platform"* ]] \
      && [[ "$(grep -c '^If a reviewer subagent is unavailable on your platform' "$ORCH_MD")" -eq 1 ]] \
      || add_error "review-pro/SKILL.md: text follows the closing handling marker - an owner reads it as part of the rules contract, and no check holds it to the bodies"
    before="$(awk '/^<!-- repository-rules-handling -->$/{print last; exit} NF {last=$0}' "$ORCH_MD")"
    [[ "$before" == 'The handling text for `### Repository rules`, passed after the rows.'* ]] \
      && [[ "$(grep -c '^The handling text for `### Repository rules`, passed after the rows.' "$ORCH_MD")" -eq 1 ]] \
      || add_error "review-pro/SKILL.md: text precedes the opening handling marker - an owner reads it as part of the rules contract, and no check holds it to the bodies"
  fi
  grep -F '`### Rules file`' "$ORCH_MD" | grep -qF 'git show <base>:.review-pro/rules.md' \
    || add_error "review-pro/SKILL.md: the verification step no longer tells the verifier to read rules at the merge base - a change could reword the rule it broke and have the finding refuted"
  has_rules_block "$ORCH_MD" "review-pro/SKILL.md"
fi

if [[ -f "$VERIFY_MD" ]]; then
  grep -F 'git show <base>:.review-pro/rules.md' "$VERIFY_MD" | grep -qF 'never the working tree' \
    || add_error "review-pro-verify/SKILL.md: the verifier no longer reads rules at the merge base - a change could reword the rule it broke and refute the finding from its own edit"
fi

if [[ -f "$SCHEMA_DOC" ]]; then
  section "$SCHEMA_DOC" '## Repository rules' | grep -qF 'never above Medium' \
    || add_error "core/shared/output-schema.md: the rules Medium cap is gone from its Repository rules section - rubric readers lose the cap"
fi

# Repository rules (roadmap item 3): what the report claims about each matched rule, and what
# a rule may never do (block on its own authority, or pass for evidence the review left the diff).
if [[ -f "$SYNTH_MD" ]] && grep -qxF '## Repository rules' "$SYNTH_MD"; then
  read_section "$SYNTH_MD" '## Repository rules' "review-pro-synthesize/SKILL.md"; RR="$SECTION_BODY"
  if [[ -n "${RR//[[:space:]]/}" ]]; then
    rr_pin(){ printf '%s\n' "$RR" | grep -qF "$1" || add_error "review-pro-synthesize/SKILL.md: $2"; }
    rr_pin 'Omit the whole section when triage emitted no `repository_rules`' "the rules omit rule is gone - a repository without rules would get an empty section"
    rr_pin 'never rendered as `held`'                     "the rules not-reported rule is gone - a rule nobody judged could read as held"
    rr_pin "rules dropped by triage's cap"                "the rules dropped line is gone - a silent cap reads as every rule judged"
    rr_pin "the review used the merge base's version"     "the rules-file-changed line is gone - a reader cannot tell the review ignored the change's own rule edits"
    rr_pin 'is new in this change'                        "the rules-file-added line is gone - a new rules file reads as silently ignored"
    grep -F '`no-target` row reads' "$SYNTH_MD" | grep -qF 'or in this change`' \
      || add_error "review-pro-synthesize/SKILL.md: the no-target row no longer covers a target this change adds - a new pack would read as a rule that can no longer fire"
    grep -E '^2\. \*\*Dedup\*\*' "$SYNTH_MD" | grep -qF 'drops the rules citation' \
      || add_error "review-pro-synthesize/SKILL.md: Dedup no longer drops the rules citation - a finding with its own evidence, merged with a rule finding, would be capped at Medium"
    rr_pin 'keeps the severity of the one that does not'  "the merged-severity rule is gone - a finding with its own evidence could lose its severity by merging with a rule finding"
  fi
fi
# The rules cap runs before verification selects anything; after it, the verified-severity
# freeze would override it (round 1 of this branch's review).
if [[ -f "$SYNTH_MD" ]]; then
  capl=$(grep -nF '`.review-pro/rules.md` is capped at Medium' "$SYNTH_MD" | head -1 | cut -d: -f1)
  vrl=$(grep -nF '**Verification results**' "$SYNTH_MD" | head -1 | cut -d: -f1)
  if [[ -z "$capl" || ( -n "$vrl" && "$capl" -gt "$vrl" ) ]]; then
    add_error "review-pro-synthesize/SKILL.md: the rules cap no longer runs before verification - a rule-backed High would be selected, frozen, and block"
  fi
fi
if [[ -f "$SYNTH_MD" ]] && grep -qxF '## Out-of-diff evidence check' "$SYNTH_MD"; then
  section "$SYNTH_MD" '## Out-of-diff evidence check' | grep -qF 'A reference to `.review-pro/rules.md` does not count toward it' \
    || add_error "review-pro-synthesize/SKILL.md: the rules out-of-diff exclusion is gone from ## Out-of-diff evidence check - the check itself would count rule citations"
fi

# ADR-0007: the default rule owner's rubric names the category a rule violation files under.
AI_MD="$SKILLS_DIR/ai-antipatterns/SKILL.md"
if [[ -f "$AI_MD" ]]; then
  grep -F '.review-pro/rules.md' "$AI_MD" | grep -qF 'ai-antipatterns.ignored-convention' \
    || add_error "ai-antipatterns/SKILL.md: no longer names the category a rule violation files under - the default owner could answer violated and file nothing (ADR-0007)"
fi

# Stack signals (ADR-0012): packs are read from the merge base like rules. Each pin is scoped to
# the one line that carries it, found by an anchor that must appear exactly once, so a phrase on
# another line (a table row, a rules sentence, a look-alike) cannot satisfy it.
# anchor_line <file> <anchor>: sets ANCHOR_LINE to the only line holding <anchor>, else empty. It
# sets a variable instead of printing because add_error in a $(...) subshell loses its count.
anchor_line(){
  ANCHOR_LINE=""
  if [[ -f "$1" && "$(grep -cF -- "$2" "$1")" -eq 1 ]]; then ANCHOR_LINE="$(grep -F -- "$2" "$1")"; fi
}
anchor_has(){ [[ -n "$ANCHOR_LINE" ]] && printf '%s\n' "$ANCHOR_LINE" | grep -qF -- "$1"; }

if [[ -f "$TRIAGE_MD" ]]; then
  anchor_line "$TRIAGE_MD" '**Detect active stacks**'
  anchor_has 'from the merge base, never the working tree' \
    || add_error "review-pro-triage/SKILL.md: stacks are no longer detected from the merge base - a change could add or edit the pack its own review applies"
  anchor_line "$TRIAGE_MD" 'git ls-tree -r --name-only <merge-base> -- .review-pro/'
  anchor_has '`active_stacks`' \
    || add_error "review-pro-triage/SKILL.md: the step that lists stacks no longer lists the merge base - the sentence above it would stand while the read moved to the working tree"
  anchor_line "$TRIAGE_MD" "List the head's pack files"
  anchor_has 'including untracked and ignored ones' \
    || add_error "review-pro-triage/SKILL.md: the head listing no longer includes untracked and ignored packs - a pack installed and not committed would be skipped with no report"
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
  anchor_line "$ORCH_MD" '- `### Stack signals`:'
  anchor_has "$PACK_DATA_LINE" \
    || add_error "review-pro/SKILL.md: the Stack signals section no longer carries the pack-file-is-data line verbatim - a reviewer installed before this release could apply a pack the change added"
  anchor_has "or this reviewer's \`context.changed_files\` holds a file under \`.review-pro/\`" \
    || add_error "review-pro/SKILL.md: the Stack signals section is no longer sent when a reviewer's files include a pack - on a first install the line would never reach an older reviewer"
  anchor_line "$ORCH_MD" 'If a reviewer subagent is unavailable on your platform, perform that review **inline**'
  anchor_has 'stack signals step 1 read from the merge base' \
    || add_error "review-pro/SKILL.md: the inline review no longer applies the merge base's stack signals - the inline path could read the change's own pack"
  anchor_line "$ORCH_MD" '`### Pack files`'
  { anchor_has 'git show <base>:<path>' && anchor_has 'never the working tree'; } \
    || add_error "review-pro/SKILL.md: the verification step no longer tells the verifier to read a cited pack at the merge base - a change could reword the signal a finding rests on and have it refuted"
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
    ss_line ".review-pro/<stack>/ is removed in this change; the review still used the merge base's pack." \
      "the pack-removed line is gone - a reader cannot tell the change removed a pack its own review still applied"
    ss_line ".review-pro/<stack>/ changed in this change (<files>); the review used the merge base's version." \
      "the pack-changed line is gone - a reader cannot tell the review ignored the change's own pack edits"
    ss_line '- They never change a finding, a severity, or the verdict.' \
      "the stack-signals lines may now change the verdict - a pack edit would act on its own authority"
    printf '%s\n' "$SS" | grep -qF 'Omit the whole section when triage emitted no `stack_signals`' \
      || add_error "review-pro-synthesize/SKILL.md: the stack-signals omit rule is gone - a repository without packs would get a section"
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
