#!/usr/bin/env bash
# scripts/validate.sh — structural validator for review-pro plugin artifacts.
# Usage: ./scripts/validate.sh [ROOT]   (ROOT defaults to repo root)
set -uo pipefail

if [[ $# -ge 1 ]]; then ROOT="$1"; else ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; fi
SKILLS_DIR="$ROOT/core/skills"

ORCHESTRATORS=("review-pro" "review-pro-triage" "review-pro-synthesize")
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
    shopt -u nullglob
    # agents reference existing skills
    for a in "$AGENTS_DIR"/*.md; do
      [[ -f "$a" ]] || continue
      ls_skill="$(fm_get "$a" "loads_skill")"
      [[ -n "$ls_skill" ]] || add_error "$(basename "$a"): missing frontmatter key 'loads_skill'"
      if [[ -n "$ls_skill" ]] && [[ ! -f "$SKILLS_DIR/$ls_skill/SKILL.md" ]]; then
        add_error "$(basename "$a"): references missing skill '$ls_skill'"
      fi
    done
  else
    echo "WARN: python3 not found; skipping manifest/reference checks" >&2
  fi
fi

# Stack pack integrity: each pack manifest is valid JSON; every listed reviewer
# has a core skill and a matching pack file.
STACKS_DIR="$ROOT/stacks"
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
      fi
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

[[ "$errors" -eq 0 ]] && { echo "OK: all artifacts valid"; exit 0; }
exit 1
