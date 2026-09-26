#!/usr/bin/env bash
# scripts/validate.sh — structural validator for review-pro plugin artifacts.
# Usage: ./scripts/validate.sh [ROOT]   (ROOT defaults to repo root)
set -uo pipefail

if [[ $# -ge 1 ]]; then ROOT="$1"; else ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; fi
SKILLS_DIR="$ROOT/core/skills"

# Pipeline-stage skills: they do not follow the reviewer section contract, and each has
# its own required sections below.
STAGE_SKILLS=("review-pro" "review-pro-triage" "review-pro-synthesize" "review-pro-verify")
REQ_FM=("name" "description")
REQ_SECTIONS=(
  "## Role & mandate"
  "## Scope"
  "## What this reviewer flags"
  "## Evidence & severity"
  "## No unresearched findings"
  "## Approval bar"
  "## Output schema"
  "## Cross-reviewer handoff"
  "## Tone"
)

errors=0
add_error(){ echo "FAIL: $*" >&2; errors=$((errors+1)); }

# The report header order is Spec, Coverage, Verification (ADR-0010). Checked inside the
# Output section of both copies of the template, because the orchestrator carries one too.
# The template's own `## Verdict` and `## Spec (...)` lines are not section ends.
check_header_order(){
  local f="$1" label="$2" out s c v
  # No Output section at all is its own failure (a required section for synthesis);
  # the order question only exists once there is a template to order.
  grep -qxF '## Output' "$f" || return 0
  out="$(awk '/^## Output$/{s=1;next} s&&/^## [A-Z]/&&!/^## Verdict/&&!/^## Spec \(/{exit} s' "$f")"
  c=$(printf '%s\n' "$out" | grep -nF 'Coverage (self-reported):' | head -1 | cut -d: -f1)
  if [[ -z "$c" ]]; then add_error "$label: the Output template has no coverage line - the report would drop the coverage signal"; return; fi
  s=$(printf '%s\n' "$out" | grep -nF 'Spec: measured against' | head -1 | cut -d: -f1)
  v=$(printf '%s\n' "$out" | grep -nF 'Verification: <N> checked' | head -1 | cut -d: -f1)
  if [[ -n "$s" && -n "$v" ]] && ! [[ "$s" -lt "$c" && "$c" -lt "$v" ]]; then
    add_error "$label: the Output template orders the header lines wrong - it must be Spec, Coverage, Verification"
  fi
}

is_stage_skill(){
  local n="$1"
  for o in "${STAGE_SKILLS[@]}"; do [[ "$o" == "$n" ]] && return 0; done
  return 1
}

fm_get(){
  # $1=file $2=key -> echo value (unquoted), empty if absent
  awk -v key="$2" '
    /^---[[:space:]]*$/ { c++; next }
    c==1 && index($0, key":") == 1 {
      val=substr($0, length(key)+2); sub(/^[[:space:]]*/,"",val)
      sub(/^"/,"",val); sub(/"$/,"",val); print val
    }
    c>=2 { exit }
  ' "$1"
}

has_frontmatter(){
  local f="$1"
  [[ -f "$f" ]] || return 1
  [[ "$(head -n1 "$f")" == "---" ]] || return 1
  awk 'NR>1 && /^---[[:space:]]*$/ { found=1; exit } END { exit !found }' "$f"
}

shopt -s nullglob
for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  name="$(basename "$(dirname "$skill_md")")"
  if ! has_frontmatter "$skill_md"; then
    add_error "$skill_md: missing or malformed frontmatter block"
    continue
  fi
  for k in "${REQ_FM[@]}"; do
    v="$(fm_get "$skill_md" "$k")"
    [[ -n "$v" ]] || add_error "$skill_md: missing frontmatter key '$k'"
  done
  if is_stage_skill "$name"; then
    # Stage skills have no shared section contract, but each has sections whose
    # silent removal would break the pipeline. Checked per stage.
    # bash 3.2 (macOS default) errors on "${arr[@]}" for an empty array under
    # `set -u`, so drive the loop off a newline-delimited string instead.
    req=""
    case "$name" in
      review-pro-triage)     req=$'## Steps\n## Signal map (non-exhaustive)\n## Dispatch plan format\n## Output discipline' ;;
      review-pro-synthesize) req=$'## Steps\n## Out-of-diff evidence check\n## Coverage\n## Spec axis\n## Verification\n## Conflict ownership\n## Output' ;;
      review-pro-verify)     req=$'## Role\n## Inputs\n## How to work\n## Verdicts\n## Rules\n## Output' ;;
    esac
    if [[ -n "$req" ]]; then
      while IFS= read -r h; do
        [[ -n "$h" ]] || continue
        grep -qxF "$h" "$skill_md" || add_error "$skill_md: missing section '$h'"
      done <<< "$req"
    fi
  else
    for h in "${REQ_SECTIONS[@]}"; do
      # -x anchors to a whole line: demoting '## X' to '### X' must fail, not pass.
      grep -qxF "$h" "$skill_md" || add_error "$skill_md: missing section '$h'"
    done
  fi
done
shopt -u nullglob

# Schema-rule parity: reviewer agent bodies embed the output schema inline (see
# docs/internals/reviewer-directive.md) rather than loading core/shared/, and the CLI
# does not install core/shared/ at all. So a rule added to output-schema.md reaches
# reviewers only if the bodies carry it. Guard the seam.
SCHEMA_DOC="$ROOT/core/shared/output-schema.md"
SCHEMA_KEYS=("evidence_refs" "same evidence bar")
if [[ -f "$SCHEMA_DOC" ]]; then
  for key in "${SCHEMA_KEYS[@]}"; do
    grep -qF "$key" "$SCHEMA_DOC" || add_error "core/shared/output-schema.md: expected schema rule mentioning '$key'"
    for body in "$ROOT"/core/agents/*-reviewer.md; do
      grep -qF "$key" "$body" || add_error "$(basename "$body"): inline output schema is missing '$key' (out of sync with core/shared/output-schema.md)"
    done
  done
fi

# Body invariants: the reviewer bodies are one document duplicated per reviewer,
# and the schema-parity keys above cover two tokens of it. These are the structural
# lines whose silent absence changes behaviour. Two of them demonstrably do: a body
# with no nested-subagent bar can fan out inside a parallel review, and one with no
# stack-signals clause ignores pack files the orchestrator injects regardless.
BODY_INVARIANTS=("(review-pro subagent)" "## Identity & mandate" "## Skill discipline (critical)" "## Anti-derailment (critical)" "## Output schema (one block per finding)" "spawn nested subagents" "Stack signals")
for body in "$ROOT"/core/agents/*-reviewer.md; do
  [[ -f "$body" ]] || continue
  for inv in "${BODY_INVARIANTS[@]}"; do
    grep -qF "$inv" "$body" || add_error "$(basename "$body"): body invariant missing: '$inv'"
  done
  grep -qE '## [A-Za-z-]+ findings: none' "$body" \
    || add_error "$(basename "$body"): no '## <Axis> findings: none' sentinel"
done

# Coverage accounting (ADR-0010). Every code reviewer accounts for each file it received
# in a `## Files examined` block. The spec reviewer is exempt: coverage measures reading
# for defects, and synthesis never counts it as a receiver. The Final reminder check is
# scoped to that section because it is the restatement a reviewer obeys last.
for body in "$ROOT"/core/agents/*-reviewer.md; do
  [[ -f "$body" ]] || continue
  [[ "$(fm_get "$body" "loads_skill")" == "spec" ]] && continue
  b="$(basename "$body")"
  grep -qxF '## Files examined' "$body" \
    || add_error "$b: no '## Files examined' block - an empty review and an unread file look the same in the report"
  grep -qF 'exactly once' "$body" \
    || add_error "$b: the exactly-once rule is gone - a reviewer can leave files out of its declaration and they read as covered"
  grep -qF 'overstates what you read' "$body" \
    || add_error "$b: the overstating rule is gone - nothing tells the reviewer a complete-looking list is the wrong answer"
  awk '/^## Final reminder/{s=1;next} s&&/^## /{exit} s' "$body" | grep -qF '## Files examined' \
    || add_error "$b: the Final reminder does not name the '## Files examined' block - its terminal restatement tells the reviewer to return findings only"
done
if [[ -f "$SCHEMA_DOC" ]]; then
  { grep -qxF '## Files examined' "$SCHEMA_DOC" && grep -qF 'exactly once' "$SCHEMA_DOC"; } \
    || add_error "core/shared/output-schema.md: the Files examined block is gone - rubric readers and the inline path lose the coverage contract"
fi

# Pointer resolution: rubrics reference `shared/<file>.md` relative to the skills
# root's parent. Every referenced target must exist in core/shared/, and the CLI
# must actually install that directory — otherwise the pointers dangle in a real
# install (see issue #25).
SHARED_DIR="$ROOT/core/shared"
for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  [[ -f "$skill_md" ]] || continue
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    [[ -f "$SHARED_DIR/${ref#shared/}" ]] || add_error "$skill_md: references '$ref' but core/shared/${ref#shared/} does not exist"
  done < <(grep -oE 'shared/[a-z-]+\.md' "$skill_md" | sort -u)
done
if [[ -f "$ROOT/cli/src/lib/plugin.ts" ]]; then
  grep -qE 'copyShared[^A-Za-z0-9_]*\(' "$ROOT/cli/src/lib/plugin.ts" \
    || add_error "cli/src/lib/plugin.ts: no copyShared — core/shared/ would not reach an install, dangling every 'shared/<file>.md' pointer"
fi

# Load-bearing pipeline rules. Each is a single line in a markdown file whose
# silent deletion disables a feature without failing any other check. The [[ -f ]]
# guards matter: most validator fixtures contain no orchestrator at all, and an
# unguarded check would fire on every one of them.
TRIAGE_MD="$SKILLS_DIR/review-pro-triage/SKILL.md"
if [[ -f "$TRIAGE_MD" ]]; then
  grep -qF 'spec_source' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'spec_source' - the spec axis cannot be dispatched or reported without it"
  grep -qF 'external_premises' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: no 'external_premises' - external premises are never extracted or routed, so no reviewer is ever asked to verify one"
  grep -qF 'Assigning a premise' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the assign-dispatches rule is gone - a premise can be routed to a reviewer the signal map never dispatches, and nothing reports that it was"
  grep -qF 'does not verify the premise' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the no-verification prohibition is gone - triage settling premises itself breaks the one-owner rule and produces verifications nobody can attribute"
  grep -qF 'coverage check compares against it' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the coverage comparison is gone - nothing says the per-reviewer lists are what Stage 3 measures"
fi
SYNTH_MD="$SKILLS_DIR/review-pro-synthesize/SKILL.md"
if [[ -f "$SYNTH_MD" ]]; then
  grep -qF 'code-axis findings only' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the out-of-diff tripwire is not restricted to the code axis - spec findings would satisfy it on every review and disable the check"
fi
# The scope-creep cap exists in the rubric and in the agent body, and the body is
# the copy that reaches the running subagent. Guard both.
for f in "$SKILLS_DIR/spec/SKILL.md" "$ROOT/core/agents/spec-reviewer.md"; do
  [[ -f "$f" ]] || continue
  grep -qF 'never exceeds Medium' "$f" \
    || add_error "$(basename "$f"): the scope-creep Medium cap is missing - without it scope creep can block"
  grep -qF 'no such hunk' "$f" \
    || add_error "$(basename "$f"): the missing-finding line rule is gone - spec.missing findings would carry an invented line"
  # Both copies, not just the body: review-pro/SKILL.md documents an inline path that
  # applies the rubric instead of the agent body, so an abstain rule present in only
  # one of them leaves that path reporting an unmeasured axis as clean.
  grep -qF 'abstained (no spec text)' "$f" \
    || add_error "$(basename "$f"): the abstain token is gone - an abstain would be indistinguishable from a clean review"
done
# The no-spec defence. Losing the abstain step is how a spec reviewer with an empty
# prompt ends up adopting a document from the diff as the spec.
if [[ -f "$TRIAGE_MD" ]]; then
  grep -qF 'if and only if' "$TRIAGE_MD" \
    || add_error "review-pro-triage/SKILL.md: the conditional-dispatch gate is gone - spec would be dispatched with no spec"
fi
if [[ -f "$ROOT/core/agents/spec-reviewer.md" ]]; then
  grep -qF 'no `### Spec text` section' "$ROOT/core/agents/spec-reviewer.md" \
    || add_error "spec-reviewer.md: the abstain step is gone - the reviewer would review something other than a spec"
  # The preamble above is identical whether step 1 abstains or emits the ordinary
  # none-sentinel, so it cannot detect a regression to the latter. Pin the token that
  # only exists after the fix, in both the body and synthesis's branch for it.
fi
ORCH_MD="$SKILLS_DIR/review-pro/SKILL.md"
if [[ -f "$ORCH_MD" ]]; then
  grep -qF 'quoted requirement' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: its dedup summary no longer names the spec key - the inline path would use the code key and collapse unattempted requirements"
  grep -qF '### External premises' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the '### External premises' prompt section is gone - triage routes premises the orchestrator then never passes to the owning reviewer"
  grep -qF "this reviewer's \`context.changed_files\`" "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: step 3 hands reviewers something other than their plan list - a narrowed prompt is invisible to the coverage check"
  { grep -qF '## Files examined' "$ORCH_MD" && grep -qF 'exactly once' "$ORCH_MD"; } \
    || add_error "review-pro/SKILL.md: inline reviews no longer end with the Files examined block - a skills-only install reports no coverage"
  check_header_order "$ORCH_MD" "review-pro/SKILL.md"
  grep -qF 'review-pro-verify-subagent' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the verifier dispatch is gone - Stage 3b never runs and every finding reads as unverified"
  grep -qF 'do **not** verify inline' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the inline-verification ban is gone - the orchestrator would check its own findings, which is not independent"
  grep -qF 'Never how many reviewers flagged it' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the agreement-count ban is gone - verifiers would be told how many reviewers agreed, which is pressure, not evidence"
  grep -qF 'base: <sha>' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the base line is gone - a verifier cannot re-read a file the diff deletes"
  grep -qF 'git merge-base <base> HEAD' "$ORCH_MD" \
    || add_error "review-pro/SKILL.md: the base is not the merge base - a verifier reading a deleted file would read the base tip, not what the diff deleted"
  grep -F 'Continue the `review-pro-synthesize` skill from' "$ORCH_MD" | grep -qi 'dedup' \
    && add_error "review-pro/SKILL.md: the synthesis step re-runs the merge after verification - a second dedup can move the keys verifier results bind to"
  grep -qE 'skill from step [0-9]|steps? [0-9]+( to [0-9]+)? of the `review-pro-synthesize`' "$ORCH_MD" \
    && add_error "review-pro/SKILL.md: a numbered reference to a review-pro-synthesize step - an inserted step would silently move the handoff"
fi
if [[ -f "$SYNTH_MD" ]]; then
  grep -qF 'abstained (no spec text)' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: no branch for the abstain token - an unmeasured axis would be reported as 'no mismatch'"
  grep -qF 'not on `(file, line)`' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the spec pool's dedup rule is gone - unattempted requirements would collapse into one finding"
  grep -qF 'External premises' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the external-premise ledger is gone - a reviewer's 'could not verify' statement dies before the report the reader actually reads"
  grep -qF 'not how the reviewer would have written it' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the approval standard is gone - verdicts drift from measuring code health to enforcing taste, and imperfect improvements start getting blocked"
fi
# Coverage accounting (ADR-0010). Scoped to the section, because several of these
# phrases would survive elsewhere in the file after the section that gives them meaning is gone.
if [[ -f "$SYNTH_MD" ]]; then
  COV="$(awk '/^## Coverage$/{s=1;next} s&&/^## /{exit} s' "$SYNTH_MD")"
  # An absent section is reported once by the required-section check; pinning its phrases
  # too would turn one deletion into eight errors.
  cov_pin(){ [[ -n "$COV" ]] || return 0; printf '%s\n' "$COV" | grep -qF "$1" || add_error "review-pro-synthesize/SKILL.md: $2"; }
  cov_pin 'The spec reviewer is not a receiver' "the spec exclusion is gone from ## Coverage - a file only the spec reviewer read would show as examined"
  cov_pin 'never rendered as examined'          "the not-reported rule is gone from ## Coverage - a reviewer that returned nothing would read as full coverage"
  cov_pin 'no Files examined block from'        "the missing-block line is gone from ## Coverage - a reviewer contract violation becomes the quietest line in the report"
  cov_pin 'declared it not examined'            "the contradiction line is gone from ## Coverage - a finding in a file its reviewer called unread goes unnoticed"
  cov_pin 'sent to no reviewer'                 "the sent-to-no-reviewer caveat is gone from ## Coverage - a narrowed dispatch is never reported"
  cov_pin 'diff_class: trivial'                 "the trivial rule is gone from ## Coverage - every one-line chore gets a coverage line and readers learn to skip it"
  cov_pin 'never changes a finding'             "the no-effect rule is gone from ## Coverage - coverage could start gating findings or the verdict"
  check_header_order "$SYNTH_MD" "review-pro-synthesize/SKILL.md"
fi
SSUB="$ROOT/core/agents/review-pro-synthesize-subagent.md"
if [[ -f "$SSUB" ]]; then
  { grep -qF '`## Files examined` block' "$SSUB" && grep -qF '`context.changed_files`' "$SSUB"; } \
    || add_error "review-pro-synthesize-subagent.md: the coverage inputs are gone - subagent synthesis would report every file not reported"
fi
# Verification. The asymmetry is the whole safety argument of ADR-0009: one wrong
# refutation must not ship a blocker, and an unchecked finding must not read as checked.
if [[ -f "$SYNTH_MD" ]]; then
  grep -qF 'keeps blocking' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the disputed-blocker rule is gone - one wrong refutation would remove a High or Critical from the verdict"
  grep -qF 'Agreement does not override a refutation' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the agreement rule is gone - 'flagged by N reviewers' would outweigh a cited contradiction"
  grep -qF 'never rendered as verified or standing' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the not-verified rule is gone - a capped or failed check could read as a clean one"
  # Anchored to the load-bearing lines: the token alone survives in prose after the table
  # or the section it names is gone (PR #74 review).
  grep -qF '| `partly_refuted` | `no` | refuted |' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the partly_refuted/no row is gone - a partly_refuted that removed the defect would stay in the verdict"
  grep -qF '| `stands` | `no` | not verified (error) |' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the stands/no row is gone - an inconsistent reply could be read as a clean check"
  grep -qxF '### Refuted in verification' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the refuted section is gone - a refuted Medium would leave the report instead of staying visible"
  grep -qF 'A refutation without a citation' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the citation rule is gone - an uncited refutation could take a Medium out of the verdict"
  grep -qF 'verified, unchecked:' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the unchecked marker is gone - a claim the verifier could not check would read as plainly verified"
  grep -qF 'needs at least one claim marked `false`' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the citation definition is gone - the rule would stand with nothing saying what a citation is"
  grep -qF 'keeps the severity it had when it was selected' "$SYNTH_MD" \
    || add_error "review-pro-synthesize/SKILL.md: the severity freeze is gone - calibration could downgrade a disputed High below the blocking line"
  grep -qE '(^|[^A-Za-z])(steps?|rules?) [0-9]' "$SYNTH_MD" \
    && add_error "review-pro-synthesize/SKILL.md: a numbered step or rule reference - the stage split and the verifier's rules are referred to by name, and an inserted item would silently move a numbered one"
  rc=$(grep -nF '**Resolve conflicts**' "$SYNTH_MD" | head -1 | cut -d: -f1)
  vr=$(grep -nF '**Verification results**' "$SYNTH_MD" | head -1 | cut -d: -f1)
  if [[ -z "$vr" ]]; then
    add_error "review-pro-synthesize/SKILL.md: the verification step is gone from Steps"
  elif [[ -z "$rc" ]]; then
    add_error "review-pro-synthesize/SKILL.md: the conflict-resolution step is gone from Steps - the order check cannot run"
  elif [[ -n "$rc" && "$rc" -gt "$vr" ]]; then
    add_error "review-pro-synthesize/SKILL.md: verification runs before conflict resolution - a finding the owner raises to Medium afterwards is never selected"
  fi
fi
# The shared verdict table is what the README points readers to and what every install
# carries as the shared contract; it drifted from synthesis once (v1.4.0 release review).
SEVERITY_MD="$ROOT/core/shared/severity.md"
if [[ -f "$SEVERITY_MD" ]]; then
  { grep -qF 'verification did not refute' "$SEVERITY_MD" && grep -qF '`disputed`' "$SEVERITY_MD"; } \
    || add_error "core/shared/severity.md: the shared verdict table predates verification - the README and every install point to a rule synthesis no longer applies"
fi
# The verifier's contract. Each line is what keeps a refutation from being doubt, memory,
# or the author's say-so; losing any one fails toward removing true findings.
VERIFY_MD="$SKILLS_DIR/review-pro-verify/SKILL.md"
if [[ -f "$VERIFY_MD" ]]; then
  grep -qF 'positive contradiction you can cite' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the cite-or-stand rule is gone - a verifier could refute a true finding on doubt alone"
  grep -qF 'Do not settle it from memory' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the no-memory rule is gone - tool and runtime behaviour would be settled from recall instead of left unchecked"
  grep -qF 'Judge only this finding' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the one-finding rule is gone - the verifier becomes another reviewer that never runs out of things to say (ADR-0008)"
  grep -qxF 'defect_stands: yes | no' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: no 'defect_stands' field - synthesis cannot catch a partly_refuted that removed the defect"
  grep -qF 'Set `defect_stands` to `no`' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the defect_stands rule is gone - the verifier is never told when the defect falls"
  grep -qF 'never settles a claim' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the author's-claim rule is gone - a PR description could be cited as the contradiction"
  grep -qF 'git show <base>:' "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the deleted-file rule is gone - a finding in a file the diff removes could not be re-read"
  grep -qF "not the finding's title" "$VERIFY_MD" \
    || add_error "review-pro-verify/SKILL.md: the harm-not-title rule is gone - a finding whose title is literally true but whose harm is false would keep its severity (contract run 1)"
fi

# Security calibration. Each rule is one line whose deletion leaves every other check
# passing while the reviewer drifts back to rating how alarming a pattern looks.
SEC_MD="$SKILLS_DIR/security/SKILL.md"
if [[ -f "$SEC_MD" ]]; then
  grep -qxF '## A missing layer is not a missing control' "$SEC_MD" \
    || add_error "security/SKILL.md: the missing-layer rule is gone - an absent second defense gets reported as a vulnerability without anyone looking for the control the path already passes"
  grep -qxF '## Not a vulnerability' "$SEC_MD" \
    || add_error "security/SKILL.md: the not-a-vulnerability list is gone - checklist deviations, self-impact, and publishable keys return as findings"
  grep -qF 'fully defeat a control' "$SEC_MD" \
    || add_error "security/SKILL.md: the High/Medium question is gone - severity follows how alarming a pattern looks instead of what the traced path achieves"
fi

CTX_POLICY="$SHARED_DIR/context-policy.md"
if [[ -f "$CTX_POLICY" ]]; then
  grep -qF 'which channel settled' "$CTX_POLICY" \
    || add_error "shared/context-policy.md: the settling-channel record is gone - a network answer becomes indistinguishable from a local one and reviews stop being reproducible"
  grep -qF '1. **The locally resolved dependency source' "$CTX_POLICY" \
    || add_error "shared/context-policy.md: the local-first channel is gone - reviewers would reach for the network on a premise the installed dependency already settles, and the answer stops being reproducible"
fi

# Both copies, for the same reason as the spec axis: the agent body is what reaches
# the running subagent, and the rubric is what review-pro/SKILL.md's inline path applies.
# ADR-0006: the closed subcategory list lives in the rubric only. A body that
# re-enumerates categories can disagree with its rubric, which is what issue #44
# measured across 12 of 13 pairs. Every `<root>.<sub>` a body still names must exist
# in that root's own rubric, so a re-added enumeration cannot contradict it.
# ADR-0006, second half: the closed list has to bind the files that TEACH the schema,
# not only the bodies. A rubric is auto-loaded into its subagent verbatim, so a worked
# example naming a category the same file just declared closed is the likeliest way a
# dead name gets re-emitted. The same applies to `overlap_hints`, which name ANOTHER
# reviewer's roots and so cannot be checked against the file they appear in.
#
# Scoped to `category:` and `overlap_hints:` lines on purpose. A repo-wide scan for
# `<word>.<word>` also matches SQL table names in code examples (`db.users` in the
# performance rubric), and a guard with false positives gets disabled rather than fixed.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$ROOT" <<'PYCAT' || errors=$((errors+1))
import glob, os, re, sys
root = sys.argv[1]
closed = {}
for f in glob.glob(os.path.join(root, 'core/skills/*/SKILL.md')):
    name = os.path.basename(os.path.dirname(f))
    m = re.search(r'Use the category roots ([^\n]*?)\. This list is closed', open(f, encoding='utf-8').read())
    if m:
        closed[name] = set(re.findall(r'`([a-z0-9-]+\.[a-z0-9-]+)`', m.group(1)))
bad = []
for f in glob.glob(os.path.join(root, 'core/**/*.md'), recursive=True):
    rel = os.path.relpath(f, root)
    for i, line in enumerate(open(f, encoding='utf-8'), 1):
        if not re.match(r'\s*(category|overlap_hints):', line):
            continue
        for tok in re.findall(r'\b([a-z0-9-]+\.[a-z0-9-]+)\b', line):
            r_, sub = tok.split('.', 1)
            if r_ in closed and closed[r_] and tok not in closed[r_]:
                bad.append(f"{rel}:{i}: '{tok}' is not in the {r_} rubric's closed category list (see ADR-0006)")
for b in bad:
    print(f"FAIL: {b}")
sys.exit(1 if bad else 0)
PYCAT
fi

for body in "$ROOT"/core/agents/*-reviewer.md; do
  [[ -f "$body" ]] || continue
  # `loads_skill` and not the filename stem. The two agree for all thirteen reviewers
  # today, which is exactly why deriving the mapping a second way would go unnoticed:
  # a body whose declared skill stopped matching its filename would resolve to a
  # missing rubric and skip this check in silence. `loads_skill` is the mapping the
  # CLI installs by and the rest of this file already resolves through.
  root="$(fm_get "$body" "loads_skill")"
  if [[ -z "$root" ]]; then
    continue # the missing-loads_skill error is raised by the frontmatter checks below
  fi
  rubric="$SKILLS_DIR/$root/SKILL.md"
  if [[ ! -f "$rubric" ]]; then
    add_error "core/agents/$(basename "$body"): declares loads_skill '$root', which has no core/skills/$root/SKILL.md, so its subcategories cannot be checked against a rubric (see ADR-0006)"
    continue
  fi
  while IFS= read -r cat; do
    [[ -n "$cat" ]] || continue
    grep -qF "$cat" "$rubric" \
      || add_error "core/agents/$(basename "$body"): names '$cat', which its own $root rubric does not list - the body and the rubric disagree on the closed subcategory list (see ADR-0006)"
  done < <(grep -oE "$root\.[a-z0-9-]+" "$body" | sort -u)
done

for f in "$SKILLS_DIR/ai-antipatterns/SKILL.md" "$SKILLS_DIR/correctness/SKILL.md" \
         "$SKILLS_DIR/api-contract/SKILL.md" "$ROOT/core/agents/ai-antipatterns-reviewer.md" \
         "$ROOT/core/agents/correctness-reviewer.md" "$ROOT/core/agents/api-contract-reviewer.md"; do
  [[ -f "$f" ]] || continue
  grep -qF '## Premise verification' "$f" \
    || add_error "${f#$ROOT/}: the premise-verification block is gone - a premise routed to this reviewer could vanish without the report showing it"
  grep -qF 'never silently trust' "$f" \
    || add_error "${f#$ROOT/}: the unsettled-premise confidence rule is gone - a finding resting on an unverified premise would report at full confidence"
  grep -qF 'settled_by' "$f" \
    || add_error "${f#$ROOT/}: no 'settled_by' field - synthesis's Settled by column would have nothing to map from and the ledger would report empty"
done

# Published reviewer count and roster. These are maintained strings in files no
# other check reads: README.md, docs/llms.txt (hand-written, not generated, so the
# site drift check never sees it), and the seven locale dictionaries. The count went
# stale once already because nothing enforced it.
if command -v python3 >/dev/null 2>&1 && [[ -f "$ROOT/manifest.json" ]]; then
  python3 - "$ROOT" <<'PYCHK' || errors=$((errors+1))
import json, sys, glob, os, re
root = sys.argv[1]
# Numeral words per locale, because two site keys spell the count rather than
# writing a digit. Extend this when the count changes or a locale is added; the
# check fails loudly rather than silently when an entry is absent.
NUMERALS = {
    "en": {13: "Thirteen"}, "de": {13: "Dreizehn"}, "fr": {13: "Treize"},
    "nl": {13: "Dertien"}, "tr": {13: "On üç"}, "hi": {13: "तेरह"}, "zh": {13: "十三"},
}
m = json.load(open(os.path.join(root, "manifest.json")))
names = sorted(s["name"] for s in m.get("skills", []) if s.get("role") == "reviewer")
n = len(names)
bad = []

def read(p):
    try: return open(os.path.join(root, p), encoding="utf-8").read()
    except OSError: return None

rd = read("README.md")
if rd is not None:
    if f"**{n} specialist reviewers**" not in rd:
        bad.append(f"README.md: expected '**{n} specialist reviewers**' for the {n} reviewers in manifest.json")
    if f"{n}-reviewer system" not in rd:
        bad.append(f"README.md: expected '{n}-reviewer system' in Acknowledgements")
    for nm in names:
        if f"`{nm}`" not in rd:
            bad.append(f"README.md: reviewer '{nm}' is missing from the enumeration")
    # The README's mermaid diagram names a few reviewers and abbreviates the rest as
    # "...N more". Nothing in that string contains the count, so a grep for the old
    # number cannot find it; it was stale for exactly that reason.
    mm = re.search(r"\u2026(\d+) more", rd)
    if mm:
        named = sum(1 for nm in names if f'["{nm}"]' in rd)
        if named + int(mm.group(1)) != n:
            bad.append(
                f"README.md: the architecture diagram names {named} reviewers and says "
                f"'...{mm.group(1)} more', which totals {named + int(mm.group(1))}, not {n}"
            )
    else:
        bad.append("README.md: the architecture diagram's '...N more' node is gone; the count can no longer be checked")

lt = read("llms.txt") or read(os.path.join("docs", "llms.txt"))
if lt is not None and f"of {n} reviewers" not in lt:
    bad.append(f"docs/llms.txt: expected 'of {n} reviewers'")

# cli/README.md and cli/package.json are PUBLISHED to npm, so a stale count there
# is on the registry page until the next release.
cr = read(os.path.join("cli", "README.md"))
if cr is not None:
    if f"{n} specialist reviewer skills" not in cr:
        bad.append(f"cli/README.md: expected '{n} specialist reviewer skills'")
    if f"## {n} specialist reviewers" not in cr:
        bad.append(f"cli/README.md: expected the heading '## {n} specialist reviewers'")
    for nm in names:
        if f"`{nm}`" not in cr:
            bad.append(f"cli/README.md: reviewer '{nm}' missing from the enumeration")
cp = read(os.path.join("cli", "package.json"))
if cp is not None:
    try:
        desc = json.loads(cp).get("description", "")
    except ValueError:
        desc = ""
    if f"{n} specialist reviewers" not in desc:
        bad.append(f"cli/package.json: description does not state {n} specialist reviewers")


ct = read("CONTRIBUTING.md")
if ct is not None:
    if f"The {n} reviewer rubrics" not in ct:
        bad.append(f"CONTRIBUTING.md: expected 'The {n} reviewer rubrics'")
    # Pinned positively as well as scanned: the neighbourhood scan below goes silent
    # once the count moves more than five, which is exactly the sentence it exists for.
    if f"owned by one of the {n}" not in ct:
        bad.append(f"CONTRIBUTING.md: expected 'owned by one of the {n}' in the add-a-reviewer section")
    # One literal missed a second stale sentence in the same file ("owned by one of
    # the 12"), where no noun follows the number so a lookahead cannot see it. Scope the
    # scan to lines that talk about reviewers instead. A plain band around the count was
    # tried first and rejected: it passed only because this file happens to state no
    # other number between 8 and 18, while a sibling doc already says "16 stack packs",
    # so moving that sentence here would have turned a docs edit into a red build.
    for line in ct.splitlines():
        if not re.search(r"reviewer|rubric|concern", line, re.I):
            continue
        for m in re.finditer(r"\b(\d+)\b", line):
            val = int(m.group(1))
            if val != n and abs(val - n) <= 5:
                bad.append(f"CONTRIBUTING.md: a line about reviewers states '{val}' where the count is {n}")

for f in sorted(glob.glob(os.path.join(root, "docs-src/i18n/*.json"))):
    loc = os.path.basename(f)
    # A trailing comma in one of seven hand-maintained dictionaries is the exact
    # fragility this guard exists for. Without this the raise discarded every finding
    # collected so far and pointed the maintainer at a traceback instead.
    try:
        d = json.load(open(f, encoding="utf-8"))
    except (ValueError, OSError) as exc:
        bad.append(f"docs-src/i18n/{loc}: unreadable ({exc.__class__.__name__}), so its count cannot be checked")
        continue
    p_ = d.get("docs.reviewers.p", "")
    for nm in names:
        if f"<code>{nm}</code>" not in p_:
            bad.append(f"docs-src/i18n/{loc}: reviewer '{nm}' missing from docs.reviewers.p")
    for k in ("cap.c1.title", "docs.toc.reviewers", "docs.reviewers.h2", "docs.overview.p2"):
        v = d.get(k)
        if v is None:
            bad.append(f"docs-src/i18n/{loc}: key '{k}' is missing, so its count cannot be checked")
        elif str(n) not in v:
            bad.append(f"docs-src/i18n/{loc}: '{k}' does not state {n}")
    # The hero H1 and the Stage 2 explainer spell the count as a WORD, so the digit
    # test above structurally cannot see them. They were the largest text on the
    # published page and stayed stale through four review rounds for that reason.
    lang = loc[:-5] if loc.endswith(".json") else loc
    word = NUMERALS.get(lang, {}).get(n)
    for k in ("hero.title", "pipeline.s2.body"):
        v = d.get(k)
        if v is None:
            bad.append(f"docs-src/i18n/{loc}: key '{k}' is missing, so its count cannot be checked")
        elif word is None:
            bad.append(f"docs-src/i18n/{loc}: no numeral word known for {n} in locale '{lang}'; add it to NUMERALS in scripts/validate.sh")
        elif word not in v:
            bad.append(f"docs-src/i18n/{loc}: '{k}' does not spell {n} as '{word}'")

for b in bad:
    print("FAIL: " + b, file=sys.stderr)
sys.exit(1 if bad else 0)
PYCHK
fi
MANIFEST="$ROOT/manifest.json"
AGENTS_DIR="$ROOT/core/agents"

if [[ ! -f "$MANIFEST" ]]; then
  add_error "manifest.json: not found"
else
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json; json.load(open('$MANIFEST'))" 2>/dev/null || add_error "manifest.json: invalid JSON"
    declared_skills="$(python3 -c "import json;d=json.load(open('$MANIFEST'));print('\n'.join(s['name'] for s in d.get('skills',[])))" 2>/dev/null)"
    # orphan skills: on disk but not declared
    shopt -s nullglob
    for d in "$SKILLS_DIR"/*/; do
      n="$(basename "$d")"
      if ! printf '%s\n' "$declared_skills" | grep -qxF "$n"; then
        add_error "orphan skill '$n' (directory exists but not in manifest)"
      fi
    done
    # declared but absent: the checks above all run disk -> manifest, so deleting a
    # whole skill or agent was invisible while deleting one line inside it was caught.
    # The [[ -f ]] guards on the load-bearing rules below depend on this direction
    # existing, or they pass vacuously for a file that is simply gone.
    while IFS= read -r dn; do
      [[ -n "$dn" ]] || continue
      [[ -f "$SKILLS_DIR/$dn/SKILL.md" ]] \
        || add_error "declared skill '$dn' has no core/skills/$dn/SKILL.md"
    done <<< "$declared_skills"

    # orphan agents: file on disk but not declared. The skills check above runs in
    # one direction only, so a reviewer could be half-registered (skill declared,
    # agent not) and the validator would still print OK. docs/internals/reviewer-directive.md calls
    # this array the source of truth for which agent loads which skill.
    declared_agents="$(python3 -c "import json;d=json.load(open('$MANIFEST'));print('\n'.join(a['name'] for a in d.get('agents',[])))" 2>/dev/null)"
    for af in "$AGENTS_DIR"/*.md; do
      [[ -f "$af" ]] || continue
      an="$(fm_get "$af" "name")"
      [[ -n "$an" ]] || continue
      if ! printf '%s\n' "$declared_agents" | grep -qxF "$an"; then
        add_error "orphan agent '$an' (file exists but not in manifest agents array)"
      fi
    done
    while IFS= read -r da; do
      [[ -n "$da" ]] || continue
      [[ -f "$AGENTS_DIR/$da.md" ]] \
        || add_error "declared agent '$da' has no core/agents/$da.md"
    done <<< "$declared_agents"
    shopt -u nullglob
    # agents reference existing skills
    for a in "$AGENTS_DIR"/*.md; do
      [[ -f "$a" ]] || continue
      ls_skill="$(fm_get "$a" "loads_skill")"
      [[ -n "$ls_skill" ]] || add_error "$(basename "$a"): missing frontmatter key 'loads_skill'"
      if [[ -n "$ls_skill" ]] && [[ ! -f "$SKILLS_DIR/$ls_skill/SKILL.md" ]]; then
        add_error "$(basename "$a"): references missing skill '$ls_skill'"
      fi
      skills_field="$(fm_get "$a" "skills")"
      if [[ -n "$skills_field" ]] && ! echo "$skills_field" | grep -qwF "$ls_skill"; then
        add_error "$(basename "$a"): skills: field must match loads_skill '$ls_skill'"
      fi
    done
  else
    echo "WARN: python3 not found; skipping manifest/reference checks" >&2
  fi
fi

# Stack pack integrity: each pack manifest is valid JSON; every listed reviewer
# has a core skill and a matching pack file.
STACKS_DIR="$ROOT/stacks"
# The format stacks/CONTRIBUTING.md documents for every pack file.
PACK_SECTIONS=("## Stack-specific signals" "## Stack-specific remedies" "## Stack-specific severity guidance")
if [[ -d "$STACKS_DIR" ]] && command -v python3 >/dev/null 2>&1; then
  shopt -s nullglob
  for pm in "$STACKS_DIR"/*/manifest.json; do
    pack_dir="$(dirname "$pm")"
    pack_name="$(basename "$pack_dir")"
    python3 -c "import json; json.load(open('$pm'))" 2>/dev/null || add_error "stacks/$pack_name/manifest.json: invalid JSON"
    if ! python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d.get('reviewers'), list)" "$pm" 2>/dev/null; then
      add_error "stacks/$pack_name/manifest.json: missing 'reviewers' list"
      continue
    fi
    python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d.get('version'), str) and d['version']" "$pm" 2>/dev/null \
      || add_error "stacks/$pack_name/manifest.json: missing 'version'"
    reviewers="$(python3 -c "import json;d=json.load(open('$pm'));print('\n'.join(d.get('reviewers',[])))" 2>/dev/null)"
    while IFS= read -r r; do
      [[ -n "$r" ]] || continue
      if [[ ! -d "$SKILLS_DIR/$r" ]]; then
        add_error "stacks/$pack_name: lists reviewer '$r' which has no core skill"
      fi
      if [[ ! -f "$pack_dir/$r.md" ]]; then
        add_error "stacks/$pack_name: manifest lists '$r' but $r.md is missing"
        continue
      fi
      # -x anchors to a whole line: a heading demoted to '### ...' must fail.
      for h in "${PACK_SECTIONS[@]}"; do
        grep -qxF "$h" "$pack_dir/$r.md" || add_error "stacks/$pack_name/$r.md: missing section '$h'"
      done
    done <<< "$reviewers"
  done
  shopt -u nullglob
fi

# Guardrail: SKILL.md only under core/skills/ (skip build/deps dirs)
shopt -s nullglob
while IFS= read -r f; do
  case "$f" in
    "$SKILLS_DIR"/*/SKILL.md) ;;
    *) add_error "$f: SKILL.md outside core/skills/";;
  esac
done < <(find "$ROOT" -name SKILL.md -type f \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/cli/plugin/*' -not -path '*/cli/dist/*' 2>/dev/null)

# Guardrail: loads_skill: frontmatter only under core/agents/
while IFS= read -r f; do
  case "$f" in
    "$AGENTS_DIR"/*.md) ;;
    *) if head -n20 "$f" 2>/dev/null | grep -q '^loads_skill:'; then add_error "$f: agent frontmatter outside core/agents/"; fi;;
  esac
done < <(find "$ROOT" -name '*.md' -type f \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/cli/plugin/*' -not -path '*/cli/dist/*' 2>/dev/null)
shopt -u nullglob

# Version-carrying files. Five of them hold the same number and none is bumped
# automatically, so they drift silently: a directory listing shows the wrong version
# until someone notices, and cli/package-lock.json sat five releases behind at 0.7.0
# while package.json said 1.2.0. cli/package.json is the source; the tag check in the
# publish workflow already pins that one to the git tag.
#
# The lockfile is checked here rather than regenerated at release time on purpose. This
# runs on every push, so the drift surfaces in the pull request that caused it, and a
# release is the worst moment to rewrite a lockfile nobody has reviewed.
#
# The remedy names `npm version` because setting a version is the whole of the job:
# `--allow-same-version` is what lets it run when package.json is already correct and
# only the lockfile is behind, and it edits the version fields without re-resolving the
# tree. `npm install --package-lock-only` rewrites the whole lockfile, and with npm older
# than 11.11.0 that rewrite drops the ten `libc` fields (glibc/musl) this lockfile carries
# on its optional native bindings: 11.11.0 is the release that added `libc` to the fields
# npm writes back. Measured on this lockfile, on the same machine: npm 11.10.0 and 11.9.0
# take it from 10 `libc` fields to 0, npm 11.11.0 keeps all 10, and `npm version` on
# 11.9.0 keeps all 10. A stripped lockfile does not heal: a newer npm writes `libc` from
# what the lockfile already says, so the fields return only when a later bump re-resolves
# those binding packages, as #40 and #63 did, and v1.3.0 shipped without them. An earlier
# version of this comment called the libc effect a mistake: it had measured a lockfile
# that a local regeneration had already stripped, in #53.
#
# Bumping a release with `npm version` keeps the two from drifting at all, which is how
# this reached 0.7.0 against 1.2.0 in the first place.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$ROOT" <<'PYVER' || errors=$((errors+1))
import json, os, sys
root = sys.argv[1]
# Unreadable is a finding, not a crash. The same lesson as the i18n loader above: the
# raise fires before `bad` is printed, so one malformed file discarded every finding
# already collected and handed the maintainer a traceback instead. That was tolerable
# while this block read five small hand-maintained files; cli/package-lock.json is
# rewritten by every Dependabot bump, which makes a conflict-marked or truncated file a
# realistic input rather than a hypothetical one. `unreadable` is returned as a sentinel
# so a genuinely absent file stays skipped, which is the existing behaviour for all five.
UNREADABLE = object()
def load(rel):
    p = os.path.join(root, rel)
    if not os.path.exists(p):
        return None
    try:
        return json.load(open(p, encoding="utf-8"))
    except (ValueError, OSError) as exc:
        bad.append(f"{rel}: unreadable ({exc.__class__.__name__}), so its version cannot be checked")
        return UNREADABLE
bad = []
cli = load("cli/package.json")
if cli is UNREADABLE:
    for b in bad:
        print("FAIL: " + b, file=sys.stderr)
    sys.exit(1)
if cli is None:
    sys.exit(0)
want = cli["version"]
mk = load(".claude-plugin/marketplace.json")
if mk is not None and mk is not UNREADABLE:
    if mk.get("version") != want:
        bad.append(f".claude-plugin/marketplace.json: version {mk.get('version')} != cli {want}")
    for i, pl in enumerate(mk.get("plugins", [])):
        if pl.get("version") != want:
            bad.append(f".claude-plugin/marketplace.json: plugins[{i}].version {pl.get('version')} != cli {want}")
for rel in ("core/.claude-plugin/plugin.json", "core/.codex-plugin/plugin.json", ".cursor-plugin/plugin.json"):
    d = load(rel)
    if d is not None and d is not UNREADABLE and d.get("version") != want:
        bad.append(f"{rel}: version {d.get('version')} != cli {want}")
# Two places in one file, and both were stale: npm writes the version at the top level
# and again under packages[""]. Checking one would pass a half-regenerated lockfile.
lock = load("cli/package-lock.json")
if lock is not None and lock is not UNREADABLE:
    for label, got in (("version", lock.get("version")),
                       ('packages[""].version', (lock.get("packages", {}).get("") or {}).get("version"))):
        if got != want:
            bad.append(f"cli/package-lock.json: {label} {got} != cli {want} - in cli/ run `npm version {want} --allow-same-version --no-git-tag-version`")
for b in bad:
    print("FAIL: " + b, file=sys.stderr)
sys.exit(1 if bad else 0)
PYVER
fi

# Category-root registry. Stage 3 dedups on the root, so the registry has to list
# exactly one root per reviewer. It lived only in shared/output-schema.md, which an
# installer that copies just skill directories never delivers, and the `spec` root was
# once missing from it while thirteen reviewers were shipping.
if command -v python3 >/dev/null 2>&1 && [[ -f "$MANIFEST" ]] && [[ -f "$SYNTH_MD" ]]; then
  python3 - "$ROOT" <<'PYROOTS' || errors=$((errors+1))
import json, os, re, sys
root = sys.argv[1]
names = sorted(s["name"] for s in json.load(open(os.path.join(root, "manifest.json")))["skills"]
               if s.get("role") == "reviewer")
bad = []
for rel in ("core/skills/review-pro-synthesize/SKILL.md", "core/shared/output-schema.md"):
    p = os.path.join(root, rel)
    if not os.path.exists(p):
        continue
    text = open(p, encoding="utf-8").read()
    m = re.search(r"^`security`.*$", text, re.M)
    if not m:
        bad.append(f"{rel}: no category-root list found (expected a line starting with `security`)")
        continue
    listed = sorted(re.findall(r"`([a-z][a-z0-9-]*)`", m.group(0)))
    if listed != names:
        missing = [n for n in names if n not in listed]
        extra = [n for n in listed if n not in names]
        detail = []
        if missing: detail.append("missing " + ", ".join(missing))
        if extra: detail.append("not a reviewer: " + ", ".join(extra))
        bad.append(f"{rel}: category roots disagree with manifest.json ({'; '.join(detail)})")
for b in bad:
    print("FAIL: " + b, file=sys.stderr)
sys.exit(1 if bad else 0)
PYROOTS
fi


[[ "$errors" -eq 0 ]] && { echo "OK: all artifacts valid"; exit 0; }
exit 1
