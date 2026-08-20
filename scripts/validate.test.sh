#!/usr/bin/env bash
# Tests for scripts/validate.sh. Run: bash scripts/validate.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$HERE/validate.sh"
pass=0; fail=0
# Exit status comes from an EXIT trap, not from a gate at the bottom of the file.
# This script runs without `set -e`, so a positional gate exits with whatever ran
# last, and appending a case below it silently makes every run exit 0. PR #24 did
# exactly that and CI could not see a failing case until it was fixed.
# Completeness as well as success. Without the finished flag a suite that dies
# partway exits through the trap with fail still 0, which is the same blind spot
# as the stranded gate in #24 reached by a different route, and it grows with
# every case appended at the tail.
finished=0
trap 'exit $(( fail > 0 || finished == 0 ))' EXIT
ok(){ echo "ok - $1"; pass=$((pass+1)); }
bad(){ echo "not ok - $1"; fail=$((fail+1)); }

write_good_reviewer(){ cat > "$1" <<'EOF'
---
name: security
description: "security reviewer"
---
# Security Reviewer
## Role & mandate
r
## Scope
s
## What this reviewer flags
f
## Evidence & severity
e
## No unresearched findings
n
## Approval bar
a
## Output schema
o
## Cross-reviewer handoff
c
## Tone
t
EOF
}

write_good_agent_body(){
  # $1 = path, $2 = agent name (default security-reviewer). Must satisfy every entry
  # of BODY_INVARIANTS and of SCHEMA_KEYS in validate.sh, plus the findings-none
  # sentinel, or cases built on it fail for reasons unrelated to what they test. The
  # SCHEMA_KEYS half is unreachable today because no fixture creates
  # core/shared/output-schema.md; it is here so the first case that does will not trip
  # on fixture invalidity.
  local an="${2:-security-reviewer}"
  cat > "$1" <<EOFB
---
name: $an
description: fixture body
loads_skill: security
skills: [security]
---
# Fixture Reviewer (review-pro subagent)
## Identity & mandate
fixture
## Skill discipline (critical)
Only the \`### Stack signals\` section supplements the core skill.
## Anti-derailment (critical)
fixture
## Work
1. review
2. Do NOT spawn nested subagents.
3. Otherwise output \`## Fixture findings: none\` and stop.
## Output schema (one block per finding)
  evidence_refs: [src/x.ts:1]
\`impact\` and \`remedy\` are held to the same evidence bar as the finding.
EOFB
}

write_good_spec_body(){
  # The four spec-reviewer.md guards in validate.sh key on this file specifically,
  # and it is the copy that reaches the running subagent. Without a fixture none of
  # them could be tested, which is how all four shipped uncovered.
  cat > "$1" <<'EOFS'
---
name: spec-reviewer
description: fixture spec body
loads_skill: spec
skills: [spec]
---
# Spec Reviewer (review-pro subagent)
## Identity & mandate
fixture
## Skill discipline (critical)
Only the `### Stack signals` section supplements the core skill.
## Anti-derailment (critical)
fixture
## Work
1. If the task prompt has no `### Spec text` section, output `## Spec findings: abstained (no spec text)` and stop.
2. Do NOT spawn nested subagents.
3. Otherwise output `## Spec findings: none` and stop.
## Output schema (one block per finding)
  evidence_refs: [src/x.ts:1]
`impact` and `remedy` are held to the same evidence bar as the finding.
`spec.scope-creep` never exceeds Medium. `line` is `0` when there is no such hunk.
EOFS
}

write_orchestrator(){
  # $1 = path, $2 = orchestrator name (default review-pro-triage, so the existing
  # call sites need no change). Sections must match the per-orchestrator req list
  # in validate.sh or every case using this fixture goes red.
  local name="${2:-review-pro-triage}"
  case "$name" in
    review-pro-triage)
      cat > "$1" <<'EOF'
---
name: review-pro-triage
description: "triage"
---
# Triage
## Steps
## Signal map (non-exhaustive)
## Dispatch plan format
spec_source:
  kind: none
Dispatch spec if and only if a spec was resolved.
## Output discipline
EOF
      ;;
    review-pro-synthesize)
      cat > "$1" <<'EOF'
---
name: review-pro-synthesize
description: "synthesis"
---
# Synthesis
## Steps
## Out-of-diff evidence check
Count the code-axis findings only whose evidence_refs name an unchanged path.
## Spec axis
Report it as abstained (no spec text) when the axis could not measure.
Dedup the spec pool on the quoted requirement, not on `(file, line)` alone.
## Conflict ownership
## Output
EOF
      ;;
    *)
      echo "write_orchestrator: unknown orchestrator '$name'" >&2
      return 1
      ;;
  esac
}

# Case A: clean tree -> exit 0
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md"
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
EOF
if bash "$VALIDATE" "$T" >/dev/null 2>&1; then ok "clean tree passes"; else bad "clean tree should pass"; fi
rm -rf "$T"

# Case B: reviewer missing a required section -> fail, mentions section
T=$(mktemp -d)
mkdir -p "$T/core/skills/security"
write_good_reviewer "$T/core/skills/security/SKILL.md"
grep -v '^## Tone$' "$T/core/skills/security/SKILL.md" > "$T/core/skills/security/SKILL.md.tmp"
mv "$T/core/skills/security/SKILL.md.tmp" "$T/core/skills/security/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "missing section '## Tone'"; then ok "missing section detected"; else bad "missing section not detected"; fi
rm -rf "$T"

# Case C: skill missing frontmatter name -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security"
cat > "$T/core/skills/security/SKILL.md" <<'EOF'
---
description: "no name"
---
# x
## Role & mandate
r
## Scope
s
## What this reviewer flags
f
## Evidence & severity
e
## No unresearched findings
n
## Approval bar
a
## Output schema
o
## Cross-reviewer handoff
c
## Tone
t
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "missing frontmatter key 'name'"; then ok "missing name detected"; else bad "missing name not detected"; fi
rm -rf "$T"

# Case D: agent references a nonexistent skill -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/core/agents/ghost-reviewer.md" <<'EOF'
---
name: ghost-reviewer
description: "loads nothing"
loads_skill: ghost
---
# ghost
EOF
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [{"name":"ghost-reviewer","loads_skill":"ghost"}] }
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "references missing skill 'ghost'"; then ok "dangling agent->skill detected"; else bad "dangling agent->skill not detected"; fi
rm -rf "$T"

# Case E: orphan skill (on disk but not in manifest) -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/orphan"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_good_reviewer "$T/core/skills/orphan/SKILL.md"
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "orphan skill 'orphan'"; then ok "orphan skill detected"; else bad "orphan skill not detected"; fi
rm -rf "$T"

# Case F: stack pack lists a reviewer file that's missing -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/stacks/mystack"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
EOF
cat > "$T/stacks/mystack/manifest.json" <<'EOF'
{ "name": "mystack", "reviewers": ["security"] }
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "manifest lists 'security' but security.md is missing"; then ok "missing pack file detected"; else bad "missing pack file not detected"; fi
rm -rf "$T"

# Case G: stack pack lists a reviewer with no core skill -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/stacks/mystack"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
EOF
cat > "$T/stacks/mystack/manifest.json" <<'EOF'
{ "name": "mystack", "reviewers": ["ghost"] }
EOF
printf '# ghost\n' > "$T/stacks/mystack/ghost.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "lists reviewer 'ghost' which has no core skill"; then ok "pack referencing ghost reviewer detected"; else bad "pack referencing ghost reviewer not detected"; fi
rm -rf "$T"

# Case H: SKILL.md outside core/skills -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/cli/docs"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
EOF
printf '# stray\n' > "$T/cli/docs/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "SKILL.md outside core/skills"; then ok "stray SKILL.md detected"; else bad "stray SKILL.md not detected"; fi
rm -rf "$T"

# Case I: agent frontmatter (loads_skill:) outside core/agents -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/stacks/s"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
EOF
cat > "$T/stacks/s/foo.md" <<'EOF'
---
name: stray-agent
loads_skill: security
---
# x
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "agent frontmatter outside core/agents"; then ok "stray agent frontmatter detected"; else bad "stray agent frontmatter not detected"; fi
rm -rf "$T"

# Case J: agent skills: field inconsistent with loads_skill: -> fail
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/core/agents/security-reviewer.md" <<'EOF'
---
name: security-reviewer
description: "x"
loads_skill: security
skills: [craft]
---
# body
EOF
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [{"name":"security-reviewer","loads_skill":"security"}] }
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "skills: field must match loads_skill"; then ok "agent skills/loads_skill mismatch detected"; else bad "mismatch not detected"; fi
rm -rf "$T"

# Case H: orchestrator missing a required section -> fail, mentions it
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md"
grep -v '^## Dispatch plan format$' "$T/core/skills/review-pro-triage/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-triage/SKILL.md"
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "missing section '## Dispatch plan format'"; then ok "orchestrator missing section detected"; else bad "orchestrator missing section not detected"; fi
rm -rf "$T"

# Case I: H2 demoted to H3 must fail (guards the unanchored-grep regression)
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md"
sed 's/^## Tone$/### Tone/' "$T/core/skills/security/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/security/SKILL.md"
cat > "$T/manifest.json" <<'EOF'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
EOF
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "missing section '## Tone'"; then ok "H2->H3 demotion detected"; else bad "H2->H3 demotion not detected"; fi
rm -rf "$T"

# Case K: triage's spec_source contract. Positive control first, so a passing
# assertion cannot come from the fixture simply never having had the string.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md" review-pro-triage
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no 'spec_source'"; then bad "spec_source control: fired on an intact fixture"; else ok "spec_source control: silent on an intact fixture"; fi
grep -v '^spec_source:$' "$T/core/skills/review-pro-triage/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-triage/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no 'spec_source'"; then ok "missing spec_source contract detected"; else bad "missing spec_source contract NOT detected"; fi
rm -rf "$T"

# Case L: synthesis must restrict the out-of-diff tripwire to the code axis.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-synthesize" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-synthesize/SKILL.md" review-pro-synthesize
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-synthesize","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "not restricted to the code axis"; then bad "code-axis control: fired on an intact fixture"; else ok "code-axis control: silent on an intact fixture"; fi
sed -i.bak 's/code-axis findings only/all findings/' "$T/core/skills/review-pro-synthesize/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "not restricted to the code axis"; then ok "unrestricted tripwire detected"; else bad "unrestricted tripwire NOT detected"; fi
rm -rf "$T"

# Case M: the '## Spec axis' section itself must be required.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-synthesize" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-synthesize/SKILL.md" review-pro-synthesize
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-synthesize","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "missing section '## Spec axis'"; then bad "Spec axis control: fired on an intact fixture"; else ok "Spec axis control: silent on an intact fixture"; fi
grep -v '^## Spec axis$' "$T/core/skills/review-pro-synthesize/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-synthesize/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "missing section '## Spec axis'"; then ok "missing Spec axis section detected"; else bad "missing Spec axis section NOT detected"; fi
rm -rf "$T"

# Case N: the scope-creep Medium cap check. The cap is the single line that makes
# scope creep unable to block, and validate.sh guards it in two files: the rubric
# and the agent body, the latter being the copy that reaches the running subagent.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/spec" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_good_reviewer "$T/core/skills/spec/SKILL.md"
printf 'never exceeds Medium\n' >> "$T/core/skills/spec/SKILL.md"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"spec","role":"reviewer"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "scope-creep Medium cap is missing"; then bad "cap control: fired on an intact fixture"; else ok "cap control: silent on an intact fixture"; fi
grep -v '^never exceeds Medium$' "$T/core/skills/spec/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/spec/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "SKILL.md: the scope-creep Medium cap is missing"; then ok "missing scope-creep cap detected in the rubric"; else bad "missing scope-creep cap NOT detected in the rubric"; fi
rm -rf "$T"

# Case O: the agent-body invariant loop. Nothing asserted it, so the guard added to
# stop a reviewer fanning out into nested subagents could itself be deleted silently.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_good_agent_body "$T/core/agents/security-reviewer.md"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [{"name":"security-reviewer","loads_skill":"security"}] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "body invariant missing"; then bad "body invariant control: fired on an intact body"; else ok "body invariant control: silent on an intact body"; fi
grep -v 'spawn nested subagents' "$T/core/agents/security-reviewer.md" > "$T/tmp" && mv "$T/tmp" "$T/core/agents/security-reviewer.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "body invariant missing: 'spawn nested subagents'"; then ok "missing nested-subagent bar detected"; else bad "missing nested-subagent bar NOT detected"; fi
rm -rf "$T"

# Case P: the findings-none sentinel, which a body can lack while satisfying every
# other invariant.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_good_agent_body "$T/core/agents/security-reviewer.md"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [{"name":"security-reviewer","loads_skill":"security"}] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "sentinel"; then bad "sentinel control: fired on an intact body"; else ok "sentinel control: silent on an intact body"; fi
grep -v 'findings: none' "$T/core/agents/security-reviewer.md" > "$T/tmp" && mv "$T/tmp" "$T/core/agents/security-reviewer.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "sentinel"; then ok "missing findings-none sentinel detected"; else bad "missing findings-none sentinel NOT detected"; fi
rm -rf "$T"

# Case Q: the orphan-agent direction. Its orphan-skill twin has Case E; this had nothing.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_good_agent_body "$T/core/agents/orphan-reviewer.md" orphan-reviewer
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "orphan agent 'orphan-reviewer'"; then ok "orphan agent detected"; else bad "orphan agent NOT detected"; fi
rm -rf "$T"

# Case R: the manifest -> disk direction. Deleting one line inside a skill was caught;
# deleting the whole skill was not.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"ghost","role":"reviewer"}], "agents": [{"name":"ghost-reviewer","loads_skill":"ghost"}] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "declared skill 'ghost' has no"; then ok "declared-but-absent skill detected"; else bad "declared-but-absent skill NOT detected"; fi
if echo "$out" | grep -q "declared agent 'ghost-reviewer' has no"; then ok "declared-but-absent agent detected"; else bad "declared-but-absent agent NOT detected"; fi
rm -rf "$T"

# Case S: the conditional-dispatch gate. Case K's mutation used to remove this line
# as collateral, so the gate itself had no case of its own.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md" review-pro-triage
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "conditional-dispatch gate"; then bad "dispatch gate control: fired on an intact fixture"; else ok "dispatch gate control: silent on an intact fixture"; fi
sed -i.bak 's/if and only if/whenever/' "$T/core/skills/review-pro-triage/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "conditional-dispatch gate is gone"; then ok "missing conditional-dispatch gate detected"; else bad "missing conditional-dispatch gate NOT detected"; fi
rm -rf "$T"

# Case T: synthesis must carry a branch for the abstain token, or an unmeasured axis
# is reported as a clean review.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-synthesize" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-synthesize/SKILL.md" review-pro-synthesize
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-synthesize","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no branch for the abstain"; then bad "abstain branch control: fired on an intact fixture"; else ok "abstain branch control: silent on an intact fixture"; fi
grep -v 'abstained (no spec text)' "$T/core/skills/review-pro-synthesize/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-synthesize/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no branch for the abstain"; then ok "missing abstain branch detected"; else bad "missing abstain branch NOT detected"; fi
rm -rf "$T"

# Case U: the spec pool's dedup key. Losing it collapses every unattempted requirement
# into one finding.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-synthesize" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-synthesize/SKILL.md" review-pro-synthesize
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-synthesize","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "dedup rule is gone"; then bad "spec dedup control: fired on an intact fixture"; else ok "spec dedup control: silent on an intact fixture"; fi
sed -i.bak 's/not on `(file, line)` alone/on the usual key/' "$T/core/skills/review-pro-synthesize/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "dedup rule is gone"; then ok "missing spec dedup rule detected"; else bad "missing spec dedup rule NOT detected"; fi
rm -rf "$T"

# Case V: the spec-reviewer BODY half of the two-file spec loop. The rubric half has
# Case N; the body is the copy that reaches the running subagent and had nothing.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/spec" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_good_reviewer "$T/core/skills/spec/SKILL.md"
printf 'never exceeds Medium. `line` is `0` when there is no such hunk.\nabstained (no spec text)\n' >> "$T/core/skills/spec/SKILL.md"
write_good_spec_body "$T/core/agents/spec-reviewer.md"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"spec","role":"reviewer"}], "agents": [{"name":"spec-reviewer","loads_skill":"spec"}] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "missing-finding line rule\|abstain token"; then bad "spec body control: fired on an intact body"; else ok "spec body control: silent on an intact body"; fi
grep -v 'no such hunk' "$T/core/agents/spec-reviewer.md" > "$T/tmp" && mv "$T/tmp" "$T/core/agents/spec-reviewer.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "spec-reviewer.md: the missing-finding line rule is gone"; then ok "missing line rule detected in the body"; else bad "missing line rule NOT detected in the body"; fi
write_good_spec_body "$T/core/agents/spec-reviewer.md"
grep -v 'abstained (no spec text)' "$T/core/agents/spec-reviewer.md" > "$T/tmp" && mv "$T/tmp" "$T/core/agents/spec-reviewer.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "spec-reviewer.md: the abstain token is gone"; then ok "missing abstain token detected in the body"; else bad "missing abstain token NOT detected in the body"; fi
rm -rf "$T"

# Case W: the orchestrator's dedup summary must name the spec key, or the inline path
# uses the code key and collapses unattempted requirements.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/core/skills/review-pro/SKILL.md" <<'EOFO'
---
name: review-pro
description: "orchestrator"
---
# Review-Pro
Dedup within each axis, spec findings on the quoted requirement.
EOFO
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "dedup summary no longer names"; then bad "orchestrator dedup control: fired on an intact fixture"; else ok "orchestrator dedup control: silent on an intact fixture"; fi
sed -i.bak 's/quoted requirement/usual key/' "$T/core/skills/review-pro/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "dedup summary no longer names"; then ok "missing orchestrator spec key detected"; else bad "missing orchestrator spec key NOT detected"; fi
rm -rf "$T"

echo "---"
echo "pass=$pass fail=$fail"

finished=1
