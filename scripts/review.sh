#!/usr/bin/env bash
# scripts/review.sh — mechanical prep for a review-pro run.
# Operates on CWD (the repo being reviewed). Resolves the review-pro plugin
# root from this script's location (it ships scripts/ and stacks/).
#
# Subcommands:
#   prep [base]   print REVIEW_PRO_ROOT, BASE, ACTIVE_STACKS, changed files, full contents
#   stacks        print active stacks only
#   diff [base]   print the diff vs base
set -uo pipefail
REVIEW_PRO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$(pwd)"

cmd="${1:-prep}"; shift || true

detect_base(){
  local cfg="$TARGET/review-pro.config"
  if [[ -f "$cfg" ]]; then
    local b
    b="$(grep -E '^[[:space:]]*base:' "$cfg" 2>/dev/null | head -1 | sed -E 's/.*base:[[:space:]]*//; s/#.*//; s/[[:space:]]*$//')"
    [[ -n "$b" ]] && { echo "$b"; return; }
  fi
  if git -C "$TARGET" rev-parse --verify main >/dev/null 2>&1; then echo main
  elif git -C "$TARGET" rev-parse --verify master >/dev/null 2>&1; then echo master
  else echo HEAD; fi
}

detect_stacks(){
  local detected=()
  if [[ -f "$TARGET/package.json" ]]; then
    grep -q '"react"' "$TARGET/package.json" 2>/dev/null && detected+=(typescript-react)
    grep -Eq '"(express|fastify|koa|nestjs|@nestjs/core|http)"' "$TARGET/package.json" 2>/dev/null && detected+=(node)
    [[ ${#detected[@]} -eq 0 ]] && detected+=(node)   # plain node project
  fi
  [[ -f "$TARGET/go.mod" ]] && detected+=(go)
  [[ -f "$TARGET/Cargo.toml" ]] && detected+=(rust)
  [[ -f "$TARGET/requirements.txt" || -f "$TARGET/pyproject.toml" ]] && detected+=(python)

  local avail=()
  shopt -s nullglob
  for d in "$REVIEW_PRO_ROOT"/stacks/*/; do avail+=("$(basename "$d")"); done
  shopt -u nullglob

  local s a
  for s in ${detected[@]+"${detected[@]}"}; do
    for a in ${avail[@]+"${avail[@]}"}; do [[ "$s" == "$a" ]] && echo "$s"; done
  done
}

base="$(detect_base)"
stacks="$(detect_stacks | tr '\n' ' ' | sed 's/ $//')"

case "$cmd" in
  stacks) echo "$stacks"; exit 0 ;;
  diff) git -C "$TARGET" diff "${1:-$base}...HEAD"; exit 0 ;;
  prep)
    echo "REVIEW_PRO_ROOT: $REVIEW_PRO_ROOT"
    echo "BASE: $base"
    echo "ACTIVE_STACKS: $stacks"
    echo "CHANGED FILES:"
    files=()
    while IFS= read -r line; do [[ -n "$line" ]] && files+=("$line"); done < <(git -C "$TARGET" diff --name-only "${1:-$base}...HEAD")
    if [[ ${#files[@]} -eq 0 ]]; then echo "  (none)"; fi
    for f in ${files[@]+"${files[@]}"}; do echo "  - $f"; done
    echo ""
    echo "## Changed file contents"
    for f in ${files[@]+"${files[@]}"}; do
      echo ""
      echo "### $f"
      if [[ -f "$TARGET/$f" ]]; then sed 's/$//' "$TARGET/$f"; else echo "(file deleted)"; fi
    done
    ;;
  *) echo "unknown subcommand: $cmd (use: prep | stacks | diff)" >&2; exit 2 ;;
esac
