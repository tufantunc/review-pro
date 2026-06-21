#!/usr/bin/env bash
# Tests for scripts/validate.sh. Run: bash scripts/validate.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$HERE/validate.sh"
pass=0; fail=0
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

write_orchestrator(){ cat > "$1" <<'EOF'
---
name: review-pro-triage
description: "triage"
---
# Triage
EOF
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

echo "---"
echo "pass=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
