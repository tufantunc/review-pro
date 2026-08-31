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

write_published_surface(){
  # $1 = fixture root. Builds a faithful miniature of every file the
  # published-count guard reads: thirteen reviewer skills, a manifest declaring
  # them, and each published surface stating thirteen and listing all of them.
  # Thirteen specifically, because the guard's numeral-word table knows that count
  # and is designed to fail loudly on any other, which is itself the subject of a
  # case below.
  local T="$1" i names_md names_html decl
  mkdir -p "$T/cli" "$T/docs" "$T/docs-src/i18n" "$T/core/agents"
  names_md=""; names_html=""; decl=""
  for i in $(seq -w 1 13); do
    mkdir -p "$T/core/skills/r$i"
    write_good_reviewer "$T/core/skills/r$i/SKILL.md"
    names_md="$names_md \`r$i\`"
    names_html="$names_html<code>r$i</code> "
    decl="$decl{\"name\":\"r$i\",\"role\":\"reviewer\"},"
  done
  printf '{ "skills": [%s], "agents": [] }\n' "${decl%,}" > "$T/manifest.json"
  cat > "$T/README.md" <<EOFR
# fixture
- **13 specialist reviewers** own one concern each:$names_md
A tiered 13-reviewer system.
    R1["r01"]
    R2["…12 more"]
EOFR
  printf 'of 13 reviewers\n' > "$T/docs/llms.txt"
  cat > "$T/cli/README.md" <<EOFC
Installs 13 specialist reviewer skills.
## 13 specialist reviewers
$names_md
EOFC
  printf '{ "description": "13 specialist reviewers" }\n' > "$T/cli/package.json"
  cat > "$T/CONTRIBUTING.md" <<EOFT
The 13 reviewer rubrics live in core/skills/.
The concern must not be owned by one of the 13, and triage must tell when it is relevant.
EOFT
  cat > "$T/docs-src/i18n/en.json" <<EOFI
{
  "cap.c1.title": "13 specialist reviewers",
  "docs.toc.reviewers": "The 13 reviewers",
  "docs.reviewers.h2": "The 13 reviewers",
  "docs.overview.p2": "installs 13 reviewer skills",
  "hero.title": "Thirteen specialists.",
  "pipeline.s2.body": "Thirteen reviewers, one concern each.",
  "docs.reviewers.p": "$names_html"
}
EOFI
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
external_premises: []
Dispatch spec if and only if a spec was resolved.
Assigning a premise to a reviewer dispatches that reviewer.
Triage does not verify the premise itself.
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
"not how the reviewer would have written it" is not a finding.
### External premises
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

# Published-count guard. Each case controls on the intact miniature, breaks exactly
# one surface, and asserts that surface's own message. The guard shipped with none of
# this, and deleting the whole block left the suite green.
pub_case(){
  # $1 = label, $2 = shell snippet mutating "$T", $3 = expected substring
  T=$(mktemp -d)
  write_published_surface "$T"
  out=$(bash "$VALIDATE" "$T" 2>&1 || true)
  if echo "$out" | grep -q "$3"; then bad "$1 control: fired on an intact surface"; else ok "$1 control: silent on an intact surface"; fi
  ( cd "$T" && eval "$2" )
  out=$(bash "$VALIDATE" "$T" 2>&1 || true)
  if echo "$out" | grep -q "$3"; then ok "$1 detected"; else bad "$1 NOT detected"; fi
  rm -rf "$T"
}

pub_case "README count" \
  "sed -i.bak 's/\*\*13 specialist reviewers\*\*/**12 specialist reviewers**/' README.md" \
  "expected '\*\*13 specialist reviewers\*\*'"
pub_case "README acknowledgements count" \
  "sed -i.bak 's/13-reviewer system/12-reviewer system/' README.md" \
  "expected '13-reviewer system'"
pub_case "README roster" \
  "sed -i.bak 's/\`r07\`//' README.md" \
  "reviewer 'r07' is missing from the enumeration"
pub_case "README mermaid arithmetic" \
  "sed -i.bak 's/…12 more/…11 more/' README.md" \
  "architecture diagram names"
pub_case "README mermaid node removed" \
  "grep -v 'more' README.md > t && mv t README.md" \
  "node is gone"
pub_case "llms.txt count" \
  "sed -i.bak 's/of 13 reviewers/of 12 reviewers/' docs/llms.txt" \
  "expected 'of 13 reviewers'"
pub_case "npm README count" \
  "sed -i.bak 's/13 specialist reviewer skills/12 specialist reviewer skills/' cli/README.md" \
  "expected '13 specialist reviewer skills'"
pub_case "npm README heading" \
  "sed -i.bak 's/## 13 specialist reviewers/## 12 specialist reviewers/' cli/README.md" \
  "expected the heading"
pub_case "npm README roster" \
  "sed -i.bak 's/\`r03\`//' cli/README.md" \
  "cli/README.md: reviewer 'r03' missing"
pub_case "npm description" \
  "sed -i.bak 's/13 specialist reviewers/12 specialist reviewers/' cli/package.json" \
  "description does not state 13"
pub_case "CONTRIBUTING literal" \
  "sed -i.bak 's/The 13 reviewer rubrics/The 12 reviewer rubrics/' CONTRIBUTING.md" \
  "expected 'The 13 reviewer rubrics'"
pub_case "CONTRIBUTING second sentence" \
  "sed -i.bak 's/one of the 13/one of the 12/' CONTRIBUTING.md" \
  "owned by one of the 13"
pub_case "locale digit key" \
  "sed -i.bak 's/\"13 specialist reviewers\"/\"12 specialist reviewers\"/' docs-src/i18n/en.json" \
  "'cap.c1.title' does not state 13"
pub_case "locale numeral word" \
  "sed -i.bak 's/Thirteen specialists/Twelve specialists/' docs-src/i18n/en.json" \
  "'hero.title' does not spell 13"
pub_case "locale missing key" \
  "python3 -c \"import json;p='docs-src/i18n/en.json';d=json.load(open(p));del d['pipeline.s2.body'];json.dump(d,open(p,'w'))\"" \
  "key 'pipeline.s2.body' is missing"
pub_case "locale roster" \
  "sed -i.bak 's|<code>r05</code> ||' docs-src/i18n/en.json" \
  "reviewer 'r05' missing from docs.reviewers.p"
pub_case "locale unreadable" \
  "printf '{ \"broken\": ' > docs-src/i18n/en.json" \
  "unreadable (JSONDecodeError)"

# An unknown count must fail loudly rather than skip, which is the numeral table's
# whole contract.
T=$(mktemp -d)
write_published_surface "$T"
python3 - "$T" <<'PYX'
import json,sys,os
p=os.path.join(sys.argv[1],"manifest.json"); d=json.load(open(p))
d["skills"]=[s for s in d["skills"] if s["name"]!="r13"]
json.dump(d,open(p,"w"))
PYX
rm -rf "$T/core/skills/r13"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no numeral word known for 12"; then ok "unknown numeral word fails loudly"; else bad "unknown numeral word did NOT fail loudly"; fi
rm -rf "$T"

# Case AB: the settling-channel record in context-policy. Its absence makes a
# network answer indistinguishable from a local one, so reviews stop being
# reproducible without any check failing.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/shared" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
printf 'Record which channel settled the premise. Use the locally resolved dependency source first.\n' > "$T/core/shared/context-policy.md"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "settling-channel record is gone"; then bad "settling-channel control fired on an intact fixture"; else ok "settling-channel control silent when present"; fi
printf 'Verify the premise outside the repo.\n' > "$T/core/shared/context-policy.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "settling-channel record is gone"; then ok "removed settling-channel record detected"; else bad "removed settling-channel record not detected"; fi
rm -rf "$T"

# Case AB2: the local-first channel in context-policy. Order matters here: a premise
# the installed dependency already settles must not be answered from the network,
# because a network answer is not reproducible.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/shared" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
printf 'Record which channel settled the premise.\n1. **The locally resolved dependency source.** first.\n2. **The network.** second.\n' > "$T/core/shared/context-policy.md"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "local-first channel is gone"; then bad "local-first control fired on an intact fixture"; else ok "local-first control silent when present"; fi
printf 'Record which channel settled the premise.\n1. **The network.** first.\n2. **The locally resolved dependency source.** second.\n' > "$T/core/shared/context-policy.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "local-first channel is gone"; then ok "removed local-first channel detected"; else bad "removed local-first channel not detected"; fi
rm -rf "$T"

# Case X: triage's external_premises contract. Positive control first, so a passing
# assertion cannot come from the fixture simply never having had the string.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md" review-pro-triage
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no 'external_premises'"; then bad "external_premises control fired on an intact fixture"; else ok "external_premises control silent when present"; fi
grep -v '^external_premises: \[\]$' "$T/core/skills/review-pro-triage/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-triage/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no 'external_premises'"; then ok "removed external_premises detected"; else bad "removed external_premises not detected"; fi
rm -rf "$T"

# Case Y: the assign-dispatches rule, without which a premise is routed to a
# reviewer the signal map never dispatches and nothing reports the gap.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md" review-pro-triage
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "assign-dispatches rule is gone"; then bad "assign-dispatches control fired on an intact fixture"; else ok "assign-dispatches control silent when present"; fi
grep -v '^Assigning a premise' "$T/core/skills/review-pro-triage/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-triage/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "assign-dispatches rule is gone"; then ok "removed assign-dispatches rule detected"; else bad "removed assign-dispatches rule not detected"; fi
rm -rf "$T"

# Case Z: the prohibition on triage verifying premises itself.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-triage" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-triage/SKILL.md" review-pro-triage
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-triage","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no-verification prohibition is gone"; then bad "no-verification control fired on an intact fixture"; else ok "no-verification control silent when present"; fi
grep -v 'does not verify the premise' "$T/core/skills/review-pro-triage/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-triage/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "no-verification prohibition is gone"; then ok "removed no-verification prohibition detected"; else bad "removed no-verification prohibition not detected"; fi
rm -rf "$T"

# Case AE: the orchestrator's prompt section. Without it triage routes premises the
# orchestrator never passes on, so the whole chain runs and verifies nothing.
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
### External premises
EOFO
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "prompt section is gone"; then bad "orchestrator premise-section control fired on an intact fixture"; else ok "orchestrator premise-section control silent when present"; fi
grep -v '^### External premises$' "$T/core/skills/review-pro/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "prompt section is gone"; then ok "removed orchestrator premise section detected"; else bad "removed orchestrator premise section not detected"; fi
rm -rf "$T"

# Case AC/AD: the two owner-side rules, checked in the rubric AND the agent body.
# Both copies, because the body is what reaches the subagent and the rubric is what
# review-pro/SKILL.md's inline path applies; a rule in only one silently disables
# the feature on the other path.
for pair in "core/skills/ai-antipatterns/SKILL.md" "core/agents/ai-antipatterns-reviewer.md"; do
  T=$(mktemp -d)
  mkdir -p "$T/core/skills/security" "$T/core/skills/ai-antipatterns" "$T/core/agents"
  write_good_reviewer "$T/core/skills/security/SKILL.md"
  if [[ "$pair" == core/skills/* ]]; then
    write_good_reviewer "$T/$pair"
  else
    write_good_agent_body "$T/$pair" ai-antipatterns-reviewer
  fi
  printf '## Premise verification\nsettled_by: network\nnever silently trust an unsettled premise.\n' >> "$T/$pair"
  cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"ai-antipatterns","role":"reviewer"}], "agents": [] }
JSON
  out=$(bash "$VALIDATE" "$T" 2>&1 || true)
  if echo "$out" | grep -q "premise-verification block is gone"; then bad "$pair: premise-verification control fired on an intact fixture"; else ok "$pair: premise-verification control silent when present"; fi
  if echo "$out" | grep -q "unsettled-premise confidence rule is gone"; then bad "$pair: confidence-rule control fired on an intact fixture"; else ok "$pair: confidence-rule control silent when present"; fi
  grep -v '## Premise verification' "$T/$pair" > "$T/tmp" && mv "$T/tmp" "$T/$pair"
  out=$(bash "$VALIDATE" "$T" 2>&1 || true)
  if echo "$out" | grep -q "premise-verification block is gone"; then ok "$pair: removed premise-verification block detected"; else bad "$pair: removed premise-verification block not detected"; fi
  grep -v 'never silently trust' "$T/$pair" > "$T/tmp" && mv "$T/tmp" "$T/$pair"
  out=$(bash "$VALIDATE" "$T" 2>&1 || true)
  if echo "$out" | grep -q "unsettled-premise confidence rule is gone"; then ok "$pair: removed confidence rule detected"; else bad "$pair: removed confidence rule not detected"; fi
  rm -rf "$T"
done

# Case AA: the synthesis ledger, without which a reviewer's "could not verify"
# statement never reaches the report the reader actually reads.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-synthesize" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-synthesize/SKILL.md" review-pro-synthesize
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-synthesize","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "external-premise ledger is gone"; then bad "ledger control fired on an intact fixture"; else ok "ledger control silent when present"; fi
grep -v '^### External premises$' "$T/core/skills/review-pro-synthesize/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-synthesize/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "external-premise ledger is gone"; then ok "removed ledger detected"; else bad "removed ledger not detected"; fi
rm -rf "$T"

# Case AF: the settled_by field in the six-file premise loop. Without it, synthesis's
# Settled by column has nothing to map from and the ledger reports empty. Both copies,
# same reason as AC/AD: the body is what reaches the subagent.
for pair in "core/skills/ai-antipatterns/SKILL.md" "core/agents/ai-antipatterns-reviewer.md"; do
  T=$(mktemp -d)
  mkdir -p "$T/core/skills/security" "$T/core/skills/ai-antipatterns" "$T/core/agents"
  write_good_reviewer "$T/core/skills/security/SKILL.md"
  if [[ "$pair" == core/skills/* ]]; then
    write_good_reviewer "$T/$pair"
  else
    write_good_agent_body "$T/$pair" ai-antipatterns-reviewer
  fi
  printf '## Premise verification\nsettled_by: network\nnever silently trust an unsettled premise.\n' >> "$T/$pair"
  cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"ai-antipatterns","role":"reviewer"}], "agents": [] }
JSON
  out=$(bash "$VALIDATE" "$T" 2>&1 || true)
  if echo "$out" | grep -q "no 'settled_by' field"; then bad "$pair: settled_by control: fired on an intact fixture"; else ok "$pair: settled_by control: silent on an intact fixture"; fi
  grep -v 'settled_by' "$T/$pair" > "$T/tmp" && mv "$T/tmp" "$T/$pair"
  out=$(bash "$VALIDATE" "$T" 2>&1 || true)
  if echo "$out" | grep -q "no 'settled_by' field"; then ok "$pair: missing settled_by detected"; else bad "$pair: missing settled_by NOT detected"; fi
  rm -rf "$T"
done


# Case AG: the approval standard in synthesis. Its deletion does not fail any other
# check, and without it verdicts drift from measuring code health to enforcing taste.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/review-pro-synthesize" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_orchestrator "$T/core/skills/review-pro-synthesize/SKILL.md" review-pro-synthesize
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"review-pro-synthesize","role":"orchestrator"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "approval standard is gone"; then bad "approval-standard control fired on an intact fixture"; else ok "approval-standard control silent when present"; fi
grep -v 'not how the reviewer would have written it' "$T/core/skills/review-pro-synthesize/SKILL.md" > "$T/tmp" && mv "$T/tmp" "$T/core/skills/review-pro-synthesize/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "approval standard is gone"; then ok "removed approval standard detected"; else bad "removed approval standard not detected"; fi
rm -rf "$T"


# Case AH: ADR-0006's subset rule. A body that re-enumerates subcategories can
# disagree with its own rubric, which is what issue #44 measured across 12 of 13
# pairs. The positive control gives the body a category the rubric DOES list, so a
# silent pass cannot come from the fixture simply naming no categories at all.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_good_agent_body "$T/core/agents/security-reviewer.md" security-reviewer
printf 'Use the category roots `security.authz`, `security.injection`.\n' >> "$T/core/skills/security/SKILL.md"
printf '  category: security.authz\n' >> "$T/core/agents/security-reviewer.md"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [{"name":"security-reviewer"}] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "ADR-0006"; then bad "subset control fired while the body's category was listed in its rubric"; else ok "subset control silent when the body agrees with its rubric"; fi
sed -i.bak 's/  category: security\.authz/  category: security.nonexistent/' "$T/core/agents/security-reviewer.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "names 'security.nonexistent'"; then ok "body naming a category its rubric omits detected"; else bad "body naming a category its rubric omits NOT detected"; fi
rm -rf "$T"


# Case AI: ADR-0006's guard resolves a body's rubric through `loads_skill`, not the
# filename stem, and says so out loud when that skill has no rubric. The two agree
# for every shipped reviewer, so only a fixture where they diverge can prove the
# guard reads the declared skill rather than the filename.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_good_agent_body "$T/core/agents/security-reviewer.md" security-reviewer
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [{"name":"security-reviewer","loads_skill":"security"}] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "cannot be checked against a rubric"; then bad "no-rubric control fired while the declared skill had a rubric"; else ok "no-rubric control silent when the declared skill has a rubric"; fi
# Same filename, different declared skill: the filename still maps to a rubric that
# exists, so a filename-derived guard would pass here and this case would prove nothing.
sed -i.bak 's/^loads_skill: security$/loads_skill: phantom/' "$T/core/agents/security-reviewer.md"
sed -i.bak2 's/^skills: \[security\]$/skills: [phantom]/' "$T/core/agents/security-reviewer.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "declares loads_skill 'phantom', which has no core/skills/phantom/SKILL.md"; then ok "body whose declared skill has no rubric reported, not skipped"; else bad "body whose declared skill has no rubric was silently skipped"; fi
rm -rf "$T"


# Case AJ: ADR-0006 binds the files that TEACH the schema, not only the bodies. A
# rubric is auto-loaded into its subagent verbatim, so a worked example naming a
# category the same file just declared closed is the likeliest way a dead name gets
# re-emitted; `overlap_hints` names ANOTHER reviewer's roots and so has to be checked
# against that reviewer's list, not the file it sits in. Both halves get a case.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/skills/backend" "$T/core/agents"
write_good_reviewer "$T/core/skills/security/SKILL.md"
write_good_reviewer "$T/core/skills/backend/SKILL.md"
printf 'Use the category roots `security.authz`, `security.injection`. This list is closed: a finding outside it means the concern belongs to another reviewer.\n' >> "$T/core/skills/security/SKILL.md"
printf 'Use the category roots `backend.validation`, `backend.transaction`. This list is closed: a finding outside it means the concern belongs to another reviewer.\n' >> "$T/core/skills/backend/SKILL.md"
printf '  category: security.authz\n  overlap_hints: [backend.validation]\n' >> "$T/core/skills/security/SKILL.md"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"},{"name":"backend","role":"reviewer"}], "agents": [] }
JSON
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "closed category list"; then bad "category audit fired while the example and the hint were both listed"; else ok "category audit silent when the example and the cross-reviewer hint are both listed"; fi
# Half one: the file's own worked example names a category its own list omits.
sed -i.bak 's/^  category: security\.authz$/  category: security.notacategory/' "$T/core/skills/security/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "'security.notacategory' is not in the security rubric"; then ok "a rubric's own example naming an unlisted category detected"; else bad "a rubric's own example naming an unlisted category NOT detected"; fi
sed -i.bak2 's/^  category: security\.notacategory$/  category: security.authz/' "$T/core/skills/security/SKILL.md"
# Half two: the hint points at ANOTHER reviewer's list, so only a cross-file check finds it.
sed -i.bak3 's/overlap_hints: \[backend\.validation\]/overlap_hints: [backend.atomicity]/' "$T/core/skills/security/SKILL.md"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "'backend.atomicity' is not in the backend rubric"; then ok "an overlap_hint outside the referenced reviewer's list detected"; else bad "an overlap_hint outside the referenced reviewer's list NOT detected"; fi
rm -rf "$T"


# Case AK: the version-alignment block. It compares five files against cli/package.json
# and had no meta-test at all, which is how cli/package-lock.json reached 0.7.0 while
# package.json said 1.2.0 across five releases. Every comparison the block makes gets
# its own mutation, because a check nothing mutates can be deleted outright and the
# suite will not notice: that is the exact hole being closed here, and the first draft
# of this case reproduced it by exercising only one of the four manifest comparisons.
# The lockfile carries the version in TWO places and each is mutated separately, since
# asserting only the top level would pass a half-regenerated lockfile. The last step
# covers the `or {}` null guard, whose removal is otherwise invisible: without it a
# lockfile with no `packages` key crashes the run instead of reporting.
T=$(mktemp -d)
mkdir -p "$T/core/skills/security" "$T/core/agents" "$T/cli" "$T/.claude-plugin" "$T/core/.claude-plugin" "$T/core/.codex-plugin"
write_good_reviewer "$T/core/skills/security/SKILL.md"
cat > "$T/manifest.json" <<'JSON'
{ "skills": [{"name":"security","role":"reviewer"}], "agents": [] }
JSON
printf '{ "version": "9.9.9" }\n' > "$T/cli/package.json"
printf '{ "version": "9.9.9", "packages": { "": { "version": "9.9.9" } } }\n' > "$T/cli/package-lock.json"
printf '{ "version": "9.9.9", "plugins": [{ "version": "9.9.9" }] }\n' > "$T/.claude-plugin/marketplace.json"
printf '{ "version": "9.9.9" }\n' > "$T/core/.claude-plugin/plugin.json"
printf '{ "version": "9.9.9" }\n' > "$T/core/.codex-plugin/plugin.json"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "!= cli 9.9.9"; then bad "version-alignment control fired while all five files agreed"; else ok "version-alignment control silent when all five files agree"; fi
printf '{ "version": "0.7.0", "packages": { "": { "version": "9.9.9" } } }\n' > "$T/cli/package-lock.json"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "package-lock.json: version 0.7.0 != cli 9.9.9"; then ok "stale lockfile top-level version detected"; else bad "stale lockfile top-level version NOT detected"; fi
printf '{ "version": "9.9.9", "packages": { "": { "version": "0.7.0" } } }\n' > "$T/cli/package-lock.json"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q 'package-lock.json: packages\[""\].version 0.7.0 != cli 9.9.9'; then ok "stale lockfile packages entry detected, not masked by a fresh top-level version"; else bad "stale lockfile packages entry NOT detected"; fi
printf '{ "version": "9.9.9", "packages": { "": { "version": "9.9.9" } } }\n' > "$T/cli/package-lock.json"
printf '{ "version": "9.9.9", "plugins": [{ "version": "0.7.0" }] }\n' > "$T/.claude-plugin/marketplace.json"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "plugins\[0\].version 0.7.0 != cli 9.9.9"; then ok "drifted marketplace plugins[0] version detected"; else bad "drifted marketplace plugins[0] version NOT detected"; fi
printf '{ "version": "0.7.0", "plugins": [{ "version": "9.9.9" }] }\n' > "$T/.claude-plugin/marketplace.json"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "marketplace.json: version 0.7.0 != cli 9.9.9"; then ok "drifted marketplace top-level version detected, not masked by a fresh plugins entry"; else bad "drifted marketplace top-level version NOT detected"; fi
printf '{ "version": "9.9.9", "plugins": [{ "version": "9.9.9" }] }\n' > "$T/.claude-plugin/marketplace.json"
printf '{ "version": "0.7.0" }\n' > "$T/core/.claude-plugin/plugin.json"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "core/.claude-plugin/plugin.json: version 0.7.0 != cli 9.9.9"; then ok "drifted claude plugin manifest detected"; else bad "drifted claude plugin manifest NOT detected"; fi
printf '{ "version": "9.9.9" }\n' > "$T/core/.claude-plugin/plugin.json"
printf '{ "version": "0.7.0" }\n' > "$T/core/.codex-plugin/plugin.json"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "core/.codex-plugin/plugin.json: version 0.7.0 != cli 9.9.9"; then ok "drifted codex plugin manifest detected"; else bad "drifted codex plugin manifest NOT detected"; fi
printf '{ "version": "9.9.9" }\n' > "$T/core/.codex-plugin/plugin.json"
# The `or {}` guard: a lockfile with no `packages` key must report, never crash. Assert
# on the absence of a traceback as well, because a crash also fails the grep above and
# the two outcomes must not be confused.
printf '{ "version": "9.9.9" }\n' > "$T/cli/package-lock.json"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "Traceback"; then bad "lockfile with no packages key crashed the validator"; else ok "lockfile with no packages key did not crash the validator"; fi
if echo "$out" | grep -q 'packages\[""\].version None != cli 9.9.9'; then ok "missing packages root entry reported as a finding"; else bad "missing packages root entry NOT reported"; fi
# Unreadable is a finding too, and it must not discard findings already collected.
printf '{ "version": "9.9.9", "packages": { "": { "version": "9.9.9" } } }\n' > "$T/cli/package-lock.json"
printf '{ "version": "0.7.0" }\n' > "$T/core/.codex-plugin/plugin.json"
printf '{ "version": "9.9.9", \n' > "$T/cli/package-lock.json"
out=$(bash "$VALIDATE" "$T" 2>&1 || true)
if echo "$out" | grep -q "package-lock.json: unreadable"; then ok "malformed lockfile reported as unreadable"; else bad "malformed lockfile NOT reported as unreadable"; fi
if echo "$out" | grep -q "codex-plugin/plugin.json: version 0.7.0 != cli 9.9.9"; then ok "a finding collected before the malformed file survives it"; else bad "a malformed file discarded findings collected before it"; fi
rm -rf "$T"

echo "---"
echo "pass=$pass fail=$fail"

finished=1
