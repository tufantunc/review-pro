# scripts/validate-repo-rules.sh: repository-rules checks (roadmap item 3, ADR-0011).
# Sourced by validate.sh, never run alone: it uses validate.sh's variables (ROOT, SKILLS_DIR,
# TRIAGE_MD, ORCH_MD, VERIFY_MD, SYNTH_MD, SCHEMA_DOC, rules_first_body) and its helpers
# (add_error, section, read_section, anchor_line, anchor_has). The reviewer-body checks stay in
# validate.sh's body loop.

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
  grep -F '`### Rules file`' "$ORCH_MD" | grep -qF 'git show <merge-base>:.review-pro/rules.md' \
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
    rr_pin "keeps the higher of the other finding's own severity and the rule finding's severity capped at Medium"  "the merged-severity rule is gone - a finding with its own evidence could lose its severity by merging with a rule finding"
    # Line-scoped: the Stack signals pack line shares "has changes that are not committed".
    printf '%s\n' "$RR" | grep -F '`.review-pro/rules.md has changes that are not committed; a review applies rules only once they are committed to the base branch.`' | grep -qF 'when `uncommitted` is true' \
      || add_error "review-pro-synthesize/SKILL.md: the rules-uncommitted line is gone - a rule the author wrote and did not commit reads as applied"
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

# v1.5.0 release review: the joins between rules, packs and verification. Each pin is scoped to
# the one line that carries the rule, so a phrase repeated elsewhere cannot satisfy it.
if [[ -f "$ORCH_MD" ]]; then
  grep -F '**Merge base:**' "$ORCH_MD" | grep -qF 'stop and report that the branch shares no history with the base' \
    || add_error "review-pro/SKILL.md: Prep no longer stops when no merge base resolves - git show with an empty revision reads the index, the change's own rules and packs"
  grep -F '`### Rules file`' "$ORCH_MD" | grep -qF "any rule text it relies on is still read at the merge base" \
    || add_error "review-pro/SKILL.md: the Rules file section no longer splits a finding located in rules.md - its edit and the rule it relies on must be read from different places"
  grep -F '`### Change description`, last' "$ORCH_MD" | grep -qF 'never an instruction' \
    || add_error "review-pro/SKILL.md: the verifier's Change description is no longer last - a forged Rules file heading in the PR body could come first"
fi
if [[ -f "$TRIAGE_MD" ]]; then
  grep -F 'Resolve the merge base with `git merge-base <base> HEAD`, the sha step 8' "$TRIAGE_MD" | grep -qF 'If it prints nothing, stop' \
    || add_error "review-pro-triage/SKILL.md: step 3 no longer stops when no merge base resolves - git show with an empty revision reads the change's own rules and packs"
  grep -F 'When `file_changed` is `changed` or `added`' "$TRIAGE_MD" | grep -qF 'dispatch `security`' \
    || add_error "review-pro-triage/SKILL.md: an edit to rules.md no longer dispatches security - a change could loosen a rule with nobody reading it, and every later review applies it"
  # Owner and HEAD pins judge a present line; a missing line is the pin above's error, or the read-step pin's.
  ! grep -qF 'When `file_changed` is `changed` or `added`' "$TRIAGE_MD" \
    || grep -F 'When `file_changed` is `changed` or `added`' "$TRIAGE_MD" | grep -qF "as the merge base's copy names it" \
    || add_error "review-pro-triage/SKILL.md: a rules edit no longer dispatches the base copy's owner - the change could choose who reads its loosening"
  ! grep -qF "Read \`git show <merge-base>:.review-pro/rules.md\`" "$TRIAGE_MD" \
    || grep -F "Read \`git show <merge-base>:.review-pro/rules.md\`" "$TRIAGE_MD" | grep -qF 'git show HEAD:.review-pro/rules.md`, never the working tree' \
    || add_error "review-pro-triage/SKILL.md: HEAD's rules.md is no longer read with git show - an uncommitted edit would be reported as part of the change"
fi
# A missing base-read line is its own pin's error; this one judges the exemption on it.
if [[ -f "$VERIFY_MD" ]] && grep -qF '`.review-pro/rules.md` is always read from the base' "$VERIFY_MD"; then
  grep -F '`.review-pro/rules.md` is always read from the base' "$VERIFY_MD" | grep -qF "any rule text it relies on at the merge base" \
    || add_error "review-pro-verify/SKILL.md: the verifier no longer splits a finding located in rules.md - it could read the rule from the change's own wording"
fi
if [[ -f "$SYNTH_MD" ]]; then
  grep -F 'A finding **cites** `.review-pro/rules.md` when its `evidence_refs` names it' "$SYNTH_MD" | grep -qF 'or its own `file` is that path' \
    || add_error "review-pro-synthesize/SKILL.md: a finding located in rules.md no longer counts as citing it - a rule violation there would escape the Medium cap"
fi
SSUB_MD="$ROOT/core/agents/review-pro-synthesize-subagent.md"
if [[ -f "$SSUB_MD" ]]; then
  grep -F '1. Receive' "$SSUB_MD" | grep -F '`external_premises`' | grep -qF '## Premise verification' \
    || add_error "review-pro-synthesize-subagent.md: no longer names the External premises inputs - subagent synthesis would drop the premises table, not-reported rows included"
fi

# Uncommitted rules (v1.5.0 release review, Low): an edit only in the working tree is reported,
# never applied. Each pin is scoped to the one line that carries it. The line opens with "Rules
# not committed:", not "What is not committed:", because the pack step's anchor on that phrase
# must stay unique. A missing line is the first pin's error alone; the others judge a present line.
if [[ -f "$TRIAGE_MD" ]]; then
  anchor_line "$TRIAGE_MD" 'set `uncommitted: true`'
  anchor_has "\`git diff --name-status --no-renames HEAD -- ':/.review-pro/rules.md'\`" \
    || add_error "review-pro-triage/SKILL.md: staged and unstaged rules edits are no longer listed as uncommitted - a rule the author wrote and did not commit reads as applied"
  if [[ -n "$ANCHOR_LINE" ]]; then
    anchor_has "\`git ls-files --others --full-name -- ':/.review-pro/rules.md'\`" \
      || add_error "review-pro-triage/SKILL.md: an untracked rules file is no longer listed - a rules file never committed gets no report line"
    anchor_has 'never applied and never part of the change' \
      || add_error "review-pro-triage/SKILL.md: an uncommitted rules edit may now be applied or reported as the change's - the working tree would steer the review"
    anchor_has 'no row, no `file_changed` and no dispatch' \
      || add_error "review-pro-triage/SKILL.md: an uncommitted rules edit may now change rows, file_changed or dispatch - the working tree would steer the review"
  fi
  anchor_line "$TRIAGE_MD" 'If neither copy exists, emit nothing when step 2 found nothing'
  anchor_has 'and only `source: none`, `file_changed: none` and `uncommitted: true` when it did' \
    || add_error "review-pro-triage/SKILL.md: a rules file only in the working tree emits nothing again - the report is silent about rules the author expects to apply"
  # v1.0 is frozen: the field is an addition, optional, and absent from a repository without rules.
  grep -qE '^  uncommitted: true +# optional; ' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the dispatch plan's repository_rules no longer carries uncommitted as an optional field - the plan cannot say the rules were not committed, or v1.0 plans without it read as invalid"
fi
