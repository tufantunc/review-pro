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
  if is_orchestrator "$name"; then
    # Orchestrators have no shared section contract, but each has sections whose
    # silent removal would break the pipeline. Checked per orchestrator.
    # bash 3.2 (macOS default) errors on "${arr[@]}" for an empty array under
    # `set -u`, so drive the loop off a newline-delimited string instead.
    req=""
    case "$name" in
      review-pro-triage)     req=$'## Steps\n## Signal map (non-exhaustive)\n## Dispatch plan format\n## Output discipline' ;;
      review-pro-synthesize) req=$'## Steps\n## Out-of-diff evidence check\n## Conflict ownership\n## Output' ;;
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
# core/shared/reviewer-directive.md) rather than loading core/shared/, and the CLI
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
BODY_INVARIANTS=("(review-pro subagent)" "## Identity & mandate" "## Output schema (one block per finding)" "spawn nested subagents" "Stack signals")
for body in "$ROOT"/core/agents/*-reviewer.md; do
  [[ -f "$body" ]] || continue
  for inv in "${BODY_INVARIANTS[@]}"; do
    grep -qF "$inv" "$body" || add_error "$(basename "$body"): body invariant missing: '$inv'"
  done
  grep -qE '## [A-Za-z-]+ findings: none' "$body" \
    || add_error "$(basename "$body"): no '## <Axis> findings: none' sentinel"
done

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
    # orphan agents: file on disk but not declared. The skills check above runs in
    # one direction only, so a reviewer could be half-registered (skill declared,
    # agent not) and the validator would still print OK. reviewer-directive.md calls
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
