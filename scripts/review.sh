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
# checkout) to see what a review would apply. A [base] resolves as the orchestrator's Base branch
# rule says: a full ref that exists exactly or a full 40-character sha, else refs/heads/<name>,
# else refs/remotes/<name>; a name that is also a tag, or a short sha, is refused.
set -uo pipefail
TARGET="$(pwd)"

cmd="${1:-prep}"; shift || true

# The base resolves to a commit sha through exact ref lookups, never git's name lookup: that
# lookup tries refs/tags/<name> before the branch, and even `rev-parse refs/heads/x` falls through
# to a tag named refs/heads/x when the branch is missing, so a change could push a tag that makes
# the merge base its own commit. exact <full ref>: its sha, only if that exact ref exists.
exact(){ git -C "$TARGET" show-ref --verify --hash "$1" 2>/dev/null; }
detect_base(){ exact refs/heads/main || exact refs/heads/master || true; }

base="$(detect_base)"
# resolve_ref <name>: the sha a [base] argument names. A full ref must exist exactly; a sha must be
# the full 40 characters (a short one can be shadowed by a tag of that name); any other name is
# refs/heads/<name>, else refs/remotes/<name>, and refused when refs/tags/<name> exists. Unknown or
# ambiguous exits 2 (the callers propagate it out of the $(...)): a typo, or an unfetched
# origin/main, must not read as a base without packs.
resolve_ref(){
  local n="$1" r sha
  case "$n" in
    refs/*) sha="$(exact "$n")" && { echo "$sha"; return 0; } ;;
    *)
      if [[ "$n" =~ ^[0-9a-f]{40}$ ]]; then
        git -C "$TARGET" cat-file -e "$n^{commit}" 2>/dev/null && { echo "$n"; return 0; }
      else
        if exact "refs/tags/$n" >/dev/null; then
          echo "ambiguous base: $n is also a tag; pass the full ref (refs/heads/$n or refs/remotes/$n)" >&2; exit 2
        fi
        for r in "refs/heads/$n" "refs/remotes/$n"; do
          sha="$(exact "$r")" && { echo "$sha"; return 0; }
        done
      fi ;;
  esac
  echo "unknown base: $n" >&2; exit 2
}
# base_ref [name]: the resolved argument, else the detected base; empty when neither exists.
base_ref(){ if [[ -n "${1:-}" ]]; then resolve_ref "$1"; else echo "$base"; fi; }
# merge_base <ref>: the merge base of a resolved ref with HEAD. Empty when there is no base or the
# histories are unrelated, and then no pack applies. Never HEAD as a fallback: the merge base of
# HEAD with itself is the change, packs included.
merge_base(){
  [[ -n "${1:-}" ]] || return 0
  git -C "$TARGET" merge-base "$1" HEAD 2>/dev/null || true
}

# active stacks = packs with a manifest.json under .review-pro/ at the merge base
stacks_list(){
  [[ -n "$mb" ]] || return 0
  git -C "$TARGET" ls-tree -r --name-only --full-tree "$mb" -- .review-pro/ \
    | sed -n 's#^\.review-pro/\([^/]*\)/manifest\.json$#\1#p'
}

case "$cmd" in
  stacks) ref="$(base_ref "${1:-}")" || exit 2; mb="$(merge_base "$ref")"; stacks_list; exit 0 ;;
  diff) ref="$(base_ref "${1:-}")" || exit 2; git -C "$TARGET" diff "${ref:-HEAD}...HEAD"; exit 0 ;;
  signals)
    [[ $# -ge 1 ]] || { echo "usage: review.sh signals <reviewer> [base]" >&2; exit 2; }
    reviewer="$1"
    ref="$(base_ref "${2:-}")" || exit 2; mb="$(merge_base "$ref")"
    for s in $(stacks_list); do
      if git -C "$TARGET" cat-file -e "$mb:.review-pro/$s/$reviewer.md" 2>/dev/null; then
        echo "--- stack: $s ($reviewer) ---"
        git -C "$TARGET" show "$mb:.review-pro/$s/$reviewer.md"
        echo ""
      fi
    done
    exit 0 ;;
  prep)
    ref="$(base_ref "${1:-}")" || exit 2; mb="$(merge_base "$ref")"
    echo "BASE: ${ref:-none}"
    echo "ACTIVE_STACKS: $(stacks_list | tr '\n' ' ' | sed 's/ $//')"
    echo "CHANGED FILES:"
    files=()
    while IFS= read -r line; do [[ -n "$line" ]] && files+=("$line"); done < <(git -C "$TARGET" diff --name-only "${ref:-HEAD}...HEAD")
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
