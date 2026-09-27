#!/usr/bin/env bash
# scripts/review.sh — OPTIONAL debug/CI helper. The review-pro agent does all of
# this natively at review time; you do NOT need this script to run a review.
# Use it only to inspect what review-pro would see, or to drive it headless in CI.
#
# Operates on CWD (the repo being reviewed). Portable to bash 3.2 (no mapfile).
#
# Subcommands:
#   prep [base]          print base, active stacks, changed files, full contents
#   stacks [base]              print active stacks (from .review-pro/ at the merge base)
#   signals <reviewer> [base]  print the concatenated .review-pro/<*>/<reviewer>.md packs at the merge base
#   diff [base]          print the diff vs base
#
# Packs come from the merge base, never the working tree, as a review reads them (ADR-0012):
# a change cannot add or edit the pack its own review applies. With no main or master and no
# [base] argument there is no merge base, and no pack applies: pass the base (origin/main in a CI
# checkout) to see what a review would apply.
set -uo pipefail
TARGET="$(pwd)"

cmd="${1:-prep}"; shift || true

# The base is a branch, never a tag or other ref of the same name: git prefers a tag named
# main over the branch, and a change could push one pointing at its own commit.
detect_base(){
  if git -C "$TARGET" rev-parse --verify --quiet refs/heads/main >/dev/null; then echo refs/heads/main
  elif git -C "$TARGET" rev-parse --verify --quiet refs/heads/master >/dev/null; then echo refs/heads/master
  fi
}

base="$(detect_base)"
# merge_base [ref]: the merge base with the given ref, else with the detected base. Empty when
# there is no base branch or the histories are unrelated, and then no pack applies. Never HEAD
# as a fallback: the merge base of HEAD with itself is the change, packs included.
# An explicit ref that does not resolve is an error, not "no packs": a typo, or an unfetched
# origin/main, must not read as a base without packs.
merge_base(){
  local ref="${1:-$base}"
  [[ -n "$ref" ]] || return 0
  if [[ -n "${1:-}" ]] && ! git -C "$TARGET" rev-parse --verify --quiet "$1^{commit}" >/dev/null; then
    echo "unknown base: $1" >&2; exit 2
  fi
  git -C "$TARGET" merge-base "$ref" HEAD 2>/dev/null || true
}

# active stacks = packs with a manifest.json under .review-pro/ at the merge base
stacks_list(){
  [[ -n "$mb" ]] || return 0
  git -C "$TARGET" ls-tree -r --name-only --full-tree "$mb" -- .review-pro/ \
    | sed -n 's#^\.review-pro/\([^/]*\)/manifest\.json$#\1#p'
}

case "$cmd" in
  stacks) mb="$(merge_base "${1:-}")" || exit 2; stacks_list; exit 0 ;;
  diff) git -C "$TARGET" diff "${1:-${base:-HEAD}}...HEAD"; exit 0 ;;
  signals)
    [[ $# -ge 1 ]] || { echo "usage: review.sh signals <reviewer> [base]" >&2; exit 2; }
    reviewer="$1"
    mb="$(merge_base "${2:-}")" || exit 2
    for s in $(stacks_list); do
      if git -C "$TARGET" cat-file -e "$mb:.review-pro/$s/$reviewer.md" 2>/dev/null; then
        echo "--- stack: $s ($reviewer) ---"
        git -C "$TARGET" show "$mb:.review-pro/$s/$reviewer.md"
        echo ""
      fi
    done
    exit 0 ;;
  prep)
    mb="$(merge_base "${1:-}")" || exit 2
    echo "BASE: ${1:-${base:-none}}"
    echo "ACTIVE_STACKS: $(stacks_list | tr '\n' ' ' | sed 's/ $//')"
    echo "CHANGED FILES:"
    files=()
    while IFS= read -r line; do [[ -n "$line" ]] && files+=("$line"); done < <(git -C "$TARGET" diff --name-only "${1:-${base:-HEAD}}...HEAD")
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
