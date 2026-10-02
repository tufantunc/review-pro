# scripts/validate-repo-rules.sh: repository-rules checks (roadmap item 3, ADR-0011).
# Sourced by validate.sh, never run alone: it uses validate.sh's variables (ROOT, SKILLS_DIR,
# TRIAGE_MD, ORCH_MD, VERIFY_MD, SYNTH_MD, rules_first_body) and its helpers (add_error, section,
# read_section, has_rules_block). The reviewer-body checks stay in validate.sh's body loop.
# What is held here is the contract between the files (ADR-0013): the plan's keys and the lines
# synthesis prints for them, the prompt sections and the verifier rules they restate, the handling
# text copied from the bodies, and the order of the rules cap.

if [[ -f "$TRIAGE_MD" ]]; then
  grep -F 'At most 8 rows in state `judge`' "$TRIAGE_MD" | grep -qF 'count the rest in `rules_dropped`' \
    || add_error "review-pro-triage/SKILL.md: the rules cap no longer counts what it drops - a silent cap reads as complete coverage"
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


# Repository rules (roadmap item 3): the lines the report prints for the plan's rules keys
# (`repository_rules`, `rules_dropped`, `file_changed`, `rows`, `uncommitted`).
if [[ -f "$SYNTH_MD" ]] && grep -qxF '## Repository rules' "$SYNTH_MD"; then
  read_section "$SYNTH_MD" '## Repository rules' "review-pro-synthesize/SKILL.md"; RR="$SECTION_BODY"
  if [[ -n "${RR//[[:space:]]/}" ]]; then
    rr_pin(){ printf '%s\n' "$RR" | grep -qF "$1" || add_error "review-pro-synthesize/SKILL.md: $2"; }
    rr_pin 'Omit the whole section when triage emitted no `repository_rules`' "the rules omit rule is gone - a repository without rules would get an empty section"
    rr_pin "rules dropped by triage's cap"                "the rules dropped line is gone - a silent cap reads as every rule judged"
    rr_pin "the review used the merge base's version"     "the rules-file-changed line is gone - a reader cannot tell the review ignored the change's own rule edits"
    rr_pin 'is new in this change'                        "the rules-file-added line is gone - a new rules file reads as silently ignored"
    # The working-tree-only plan has no rows, so its line survives the omitted table only by this
    # clause (round 2). A missing omit line is the omit pin's error alone.
    omitl="$(printf '%s\n' "$RR" | grep -F 'Omit the whole section when triage emitted no `repository_rules`')"
    [[ -z "$omitl" ]] || printf '%s\n' "$omitl" | grep -qF 'omit the table when `rows` is empty or absent, keeping only the lines beneath it that apply' \
      || add_error "review-pro-synthesize/SKILL.md: the lines beneath an omitted rules table no longer print - a rules file only in the working tree has no rows, and its uncommitted line would be dropped"
    # Line-scoped: the Stack signals pack line shares "has changes that are not committed".
    printf '%s\n' "$RR" | grep -F '`.review-pro/rules.md has changes that are not committed; a review applies rules only once they are committed to the base branch.`' | grep -F 'when `uncommitted` is true' | grep -qF 'whatever `file_changed` says' \
      || add_error "review-pro-synthesize/SKILL.md: the rules-uncommitted line is gone or narrowed - a rule the author wrote and did not commit reads as applied, or an uncommitted edit on top of a committed one goes unreported"
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
fi
# A missing base-read line is its own pin's error; this one judges the exemption on it.
if [[ -f "$VERIFY_MD" ]] && grep -qF '`.review-pro/rules.md` is always read from the base' "$VERIFY_MD"; then
  grep -F '`.review-pro/rules.md` is always read from the base' "$VERIFY_MD" | grep -qF "any rule text it relies on at the merge base" \
    || add_error "review-pro-verify/SKILL.md: the verifier no longer splits a finding located in rules.md - it could read the rule from the change's own wording"
fi
SSUB_MD="$ROOT/core/agents/review-pro-synthesize-subagent.md"
if [[ -f "$SSUB_MD" ]]; then
  grep -F '1. Receive' "$SSUB_MD" | grep -F '`external_premises`' | grep -qF '## Premise verification' \
    || add_error "review-pro-synthesize-subagent.md: no longer names the External premises inputs - subagent synthesis would drop the premises table, not-reported rows included"
fi

if [[ -f "$TRIAGE_MD" ]]; then
  # v1.0 is frozen: the field is an addition, optional, and absent from a repository without rules.
  grep -qE '^  uncommitted: true +# optional; only when step 8 found ' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the dispatch plan's repository_rules no longer carries uncommitted as an optional field - the plan cannot say the rules were not committed, or v1.0 plans without it read as invalid"
  grep -E '^  source: \.review-pro/rules\.md@' "$TRIAGE_MD" | grep -qF '# none: the merge base has no rules file' \
    || add_error "review-pro-triage/SKILL.md: the plan's source comment no longer covers a rules file only in the working tree - source: none reads as only the head having one"
fi
