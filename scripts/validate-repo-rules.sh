# scripts/validate-repo-rules.sh: repository-rules checks (roadmap item 3, ADR-0011).
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
  grep -qE '^repository_rules:' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'repository_rules' key in the dispatch plan format - rules reach no owner and no report"
fi

if [[ -f "$ORCH_MD" ]]; then
  rl="$(grep -F '`### Repository rules`, for a rule'"'"'s owner only' "$ORCH_MD")"
  if [[ -z "$rl" ]]; then
    add_error "review-pro/SKILL.md: the owners' Repository rules section is missing - triage routes rules the orchestrator never passes to their owners"
  elif ! printf '%s' "$rl" | grep -qF 'verbatim'; then
    add_error "review-pro/SKILL.md: the Repository rules section no longer passes the handling text verbatim - an owner installed before this release gets rules with no contract"
  fi
  # The handling text an older owner reads is the reviewer bodies' section itself, held to them.
  if ! grep -qxF '<!-- repository-rules-handling -->' "$ORCH_MD" || ! grep -qxF '<!-- /repository-rules-handling -->' "$ORCH_MD"; then
    add_error "review-pro/SKILL.md: the Repository rules handling text markers are missing - the copy an older owner reads cannot be held to the bodies"
  elif [[ -n "${rules_first_body:-}" ]]; then
    osum="$(awk '/^<!-- \/repository-rules-handling -->$/{s=0} s; /^<!-- repository-rules-handling -->$/{s=1}' "$ORCH_MD" | grep -v '^[[:space:]]*$' | cksum)"
    bsum="$(section "$ROOT/core/agents/$rules_first_body" '## Repository rules' | grep -v '^[[:space:]]*$' | cksum)"
    [[ "$osum" == "$bsum" ]] \
      || add_error "review-pro/SKILL.md: the Repository rules handling text differs from the reviewer bodies' section - an owner installed before this release gets a different contract"
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
