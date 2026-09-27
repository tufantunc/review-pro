#!/usr/bin/env bash
# scripts/review.sh — OPTIONAL debug/CI helper. The review-pro agent does all of
# this natively at review time; you do NOT need this script to run a review.
# Use it only to inspect what review-pro would see, or to drive it headless in CI.
#
# Operates on CWD (the repo being reviewed). Portable to bash 3.2 (no mapfile).
#
# Subcommands:
#   prep [base]          print base, active stacks, changed files, full contents
#   stacks               print active stacks (from .review-pro/ at the merge base)
#   signals <reviewer>   print the concatenated .review-pro/<*>/<reviewer>.md packs at the merge base
#   diff [base]          print the diff vs base
#
# Packs come from the merge base, never the working tree, as a review reads them (ADR-0012):
# a change cannot add or edit the pack its own review applies.
set -uo pipefail
TARGET="$(pwd)"

cmd="${1:-prep}"; shift || true

detect_base(){
  if git -C "$TARGET" rev-parse --verify main >/dev/null 2>&1; then echo main
  elif git -C "$TARGET" rev-parse --verify master >/dev/null 2>&1; then echo master
  else echo HEAD; fi
}

base="$(detect_base)"
# No merge base (no base branch, unrelated histories): no pack applies.
mb="$(git -C "$TARGET" merge-base "$base" HEAD 2>/dev/null || true)"

# active stacks = packs with a manifest.json under .review-pro/ at the merge base
stacks_list(){
  [[ -n "$mb" ]] || return 0
  git -C "$TARGET" ls-tree -r --name-only --full-tree "$mb" -- .review-pro/ \
    | sed -n 's#^\.review-pro/\([^/]*\)/manifest\.json$#\1#p'
}

case "$cmd" in
  stacks) stacks_list; exit 0 ;;
  diff) git -C "$TARGET" diff "${1:-$base}...HEAD"; exit 0 ;;
  signals)
    [[ $# -ge 1 ]] || { echo "usage: review.sh signals <reviewer>" >&2; exit 2; }
    reviewer="$1"
    for s in $(stacks_list); do
      if git -C "$TARGET" cat-file -e "$mb:.review-pro/$s/$reviewer.md" 2>/dev/null; then
        echo "--- stack: $s ($reviewer) ---"
        git -C "$TARGET" show "$mb:.review-pro/$s/$reviewer.md"
        echo ""
      fi
    done
    exit 0 ;;
  prep)
    if [[ $# -ge 1 ]]; then mb="$(git -C "$TARGET" merge-base "$1" HEAD 2>/dev/null || true)"; fi
    echo "BASE: ${1:-$base}"
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
