# scripts/validate-dispatch.sh: how the orchestrator starts its agents (roadmap item 4).
# Sourced by validate.sh, never run alone: it uses validate.sh's ORCH_MD and add_error.
# Measured in studies/2026-09-foreground-dispatch/: agents run as background tasks each return
# on their own, and every return opened an orchestrator turn that re-read its whole context.

DISPATCH_CLAUSE='all in one step: in parallel if your platform allows, else sequentially. Wait until every one has returned before you go on, and do not run them as background tasks that each report back on their own: every separate return starts a new turn that re-reads your whole context.'

if [[ -f "$ORCH_MD" ]]; then
  # Dispatch every reviewer, then every verifier, in one step and wait for all (roadmap item 4):
  # an agent run as a background task returns on its own, and each return is an orchestrator turn
  # that re-reads the whole context. Pinned on each dispatch line, as one canonical clause.
  for inv in '**Invoke the `<reviewer>-reviewer` subagent' '**Invoke one `review-pro-verify-subagent` per selected finding**'; do
    line="$(grep -F "$inv" "$ORCH_MD")"
    who="reviewer"; [[ "$inv" == *verify* ]] && who="verifier"
    if [[ -z "$line" ]]; then
      # With the verifier's name gone entirely, validate.sh's own verifier-dispatch check fails.
      [[ "$who" == reviewer ]] || grep -qF 'review-pro-verify-subagent' "$ORCH_MD" \
        && add_error "review-pro/SKILL.md: the $who dispatch line is gone - nothing says how its agents are started"
    elif [[ "$line" != *"$DISPATCH_CLAUSE"* ]]; then
      add_error "review-pro/SKILL.md: the $who dispatch no longer starts every agent in one step and waits for all - each background return re-reads the orchestrator's whole context"
    elif [[ "${line//"$DISPATCH_CLAUSE"/}" == *background* ]]; then
      add_error "review-pro/SKILL.md: the $who dispatch line asks for background dispatch - each background return re-reads the orchestrator's whole context"
    fi
  done
fi
