#!/usr/bin/env bash
# scripts/validate.sh — structural validator for review-pro plugin artifacts.
# Usage: ./scripts/validate.sh [ROOT]   (ROOT defaults to repo root)
set -uo pipefail

if [[ $# -ge 1 ]]; then ROOT="$1"; else ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; fi
SKILLS_DIR="$ROOT/core/skills"

ORCHESTRATORS=("review-pro-triage" "review-pro-synthesize")
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

is_orchestrator(){
  local n="$1"
  for o in "${ORCHESTRATORS[@]}"; do [[ "$o" == "$n" ]] && return 0; done
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
  if ! is_orchestrator "$name"; then
    for h in "${REQ_SECTIONS[@]}"; do
      grep -qF "$h" "$skill_md" || add_error "$skill_md: missing section '$h'"
    done
  fi
done
shopt -u nullglob

[[ "$errors" -eq 0 ]] && { echo "OK: all artifacts valid"; exit 0; }
exit 1
