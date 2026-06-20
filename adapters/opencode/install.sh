#!/usr/bin/env bash
# adapters/opencode/install.sh — install review-pro core into opencode.
# opencode loads skills from $OC_HOME/skills/<name>/SKILL.md.
# Agents are copied to $OC_HOME/agents/ — confirm your opencode loads agents from there.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OC_HOME="${OPENCODE_HOME:-$HOME/.config/opencode}"
SKILLS_DST="$OC_HOME/skills"
AGENTS_DST="$OC_HOME/agents"

echo "Installing review-pro into $OC_HOME"
mkdir -p "$SKILLS_DST" "$AGENTS_DST"

shopt -s nullglob
for skill_dir in "$ROOT"/core/skills/*/; do
  name="$(basename "$skill_dir")"
  cp -R "$skill_dir" "$SKILLS_DST/$name"
  echo "  skill: $name"
done

for agent in "$ROOT"/core/agents/*.md; do
  cp "$agent" "$AGENTS_DST/"
  echo "  agent: $(basename "$agent")"
done
shopt -u nullglob

echo "Done."
echo "Verify opencode loads agents from $AGENTS_DST (see adapters/opencode/README.md)."
