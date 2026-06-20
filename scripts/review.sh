#!/usr/bin/env bash
# scripts/review.sh — OPTIONAL debug/CI helper. The review-pro agent does all of
# this natively at review time; you do NOT need this script to run a review.
# Use it only to inspect what review-pro would see, or to drive it headless in CI.
#
# Operates on CWD (the repo being reviewed). Portable to bash 3.2 (no mapfile).
#
# Subcommands:
#   prep [base]          print base, active stacks, changed files, full contents
#   stacks               print active stacks (from .review-pro/)
#   signals <reviewer>   print the concatenated .review-pro/<*>/<reviewer>.md packs
#   diff [base]          print the diff vs base
set -uo pipefail
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

# active stacks = installed packs under .review-pro/
stacks_list(){
  shopt -s nullglob
  local m
  for m in "$TARGET"/.review-pro/*/manifest.json; do basename "$(dirname "$m")"; done
  shopt -u nullglob
}

base="$(detect_base)"

case "$cmd" in
  stacks) stacks_list; exit 0 ;;
  diff) git -C "$TARGET" diff "${1:-$base}...HEAD"; exit 0 ;;
  signals)
    [[ $# -ge 1 ]] || { echo "usage: review.sh signals <reviewer>" >&2; exit 2; }
    reviewer="$1"
    shopt -s nullglob
    for m in "$TARGET"/.review-pro/*/manifest.json; do
      pack="$(dirname "$m")/$reviewer.md"
      if [[ -f "$pack" ]]; then
        echo "--- stack: $(basename "$(dirname "$m")") ($reviewer) ---"
        cat "$pack"
        echo ""
      fi
    done
    shopt -u nullglob
    exit 0 ;;
  prep)
    echo "BASE: $base"
    echo "ACTIVE_STACKS: $(stacks_list | tr '\n' ' ' | sed 's/ $//')"
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
      if [[ -f "$TARGET/$f" ]]; then cat "$TARGET/$f"; else echo "(file deleted)"; fi
    done
    ;;
  *) echo "unknown subcommand: $cmd (use: prep | stacks | signals <reviewer> | diff)" >&2; exit 2 ;;
esac
