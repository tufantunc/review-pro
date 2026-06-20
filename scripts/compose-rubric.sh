#!/usr/bin/env bash
# scripts/compose-rubric.sh — render the effective rubric for a reviewer + active stacks.
# Usage: compose-rubric.sh <reviewer> [stack ...]
#   scripts/compose-rubric.sh security typescript-react
# Prints: core skill, then each active stack's pack file for that reviewer (if present).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <reviewer> [stack ...]" >&2
  exit 2
fi

reviewer="$1"; shift || true
core="$ROOT/core/skills/$reviewer/SKILL.md"
if [[ ! -f "$core" ]]; then
  echo "missing core skill: $core" >&2
  exit 1
fi

cat "$core"

for stack in "$@"; do
  pack="$ROOT/stacks/$stack/$reviewer.md"
  if [[ -f "$pack" ]]; then
    echo ""
    echo "--- stack pack: $stack ($reviewer) ---"
    cat "$pack"
  fi
done
