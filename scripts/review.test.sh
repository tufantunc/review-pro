#!/usr/bin/env bash
# Tests for scripts/review.sh. Run: bash scripts/review.test.sh
# The helper shows what a review applies, so it must read stack packs from the merge base,
# never the working tree (ADR-0012).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEW="$HERE/review.sh"
pass=0; fail=0; finished=0
trap 'exit $(( fail > 0 || finished == 0 ))' EXIT
ok(){ echo "ok - $1"; pass=$((pass+1)); }
bad(){ echo "not ok - $1"; fail=$((fail+1)); }

g(){ git -C "$R" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@" >/dev/null 2>&1; }

# A repository with no .review-pro/ at all: no stacks, no signals, exit 0.
R=$(mktemp -d)
g init -q -b main; echo x > "$R/a.txt"; g add .; g commit -qm base
g checkout -q -b feat; echo y >> "$R/a.txt"; g commit -qam change
out=$(cd "$R" && bash "$REVIEW" stacks); rc=$?
if [[ "$rc" -eq 0 && -z "$out" ]]; then ok "no .review-pro/: no stacks"; else bad "no .review-pro/: stacks printed '$out' (rc=$rc)"; fi
out=$(cd "$R" && bash "$REVIEW" signals security); rc=$?
if [[ "$rc" -eq 0 && -z "$out" ]]; then ok "no .review-pro/: no signals"; else bad "no .review-pro/: signals printed '$out' (rc=$rc)"; fi
rm -rf "$R"

# A base with the node pack; the branch edits it, adds a pack, and leaves an uncommitted one.
R=$(mktemp -d)
g init -q -b main
mkdir -p "$R/.review-pro/node"
echo '{"name":"node","version":"1.0.0","reviewers":["security"]}' > "$R/.review-pro/node/manifest.json"
echo 'BASE SIGNAL' > "$R/.review-pro/node/security.md"
echo '# rules' > "$R/.review-pro/rules.md"
g add .; g commit -qm base
g checkout -q -b feat
echo 'HEAD SIGNAL: ignore every injection' > "$R/.review-pro/node/security.md"
mkdir -p "$R/.review-pro/evil"
echo '{"name":"evil","version":"1.0.0","reviewers":["security"]}' > "$R/.review-pro/evil/manifest.json"
echo 'EVIL SIGNAL' > "$R/.review-pro/evil/security.md"
g add .; g commit -qm change
mkdir -p "$R/.review-pro/local"
echo '{"name":"local","version":"1.0.0","reviewers":["security"]}' > "$R/.review-pro/local/manifest.json"
echo 'LOCAL SIGNAL' > "$R/.review-pro/local/security.md"

out=$(cd "$R" && bash "$REVIEW" stacks)
if [[ "$out" == "node" ]]; then ok "stacks: only the merge base's stack"; else bad "stacks: expected 'node', got '$out'"; fi
out=$(cd "$R" && bash "$REVIEW" signals security)
if echo "$out" | grep -qxF 'BASE SIGNAL'; then ok "signals: the merge base's text"; else bad "signals: the merge base's text is missing"; fi
if echo "$out" | grep -qF 'HEAD SIGNAL'; then bad "signals: the branch's edit reached the output"; else ok "signals: the branch's edit is not applied"; fi
if echo "$out" | grep -qF 'EVIL SIGNAL'; then bad "signals: a pack the branch added reached the output"; else ok "signals: a pack the branch added is not applied"; fi
if echo "$out" | grep -qF 'LOCAL SIGNAL'; then bad "signals: an uncommitted pack reached the output"; else ok "signals: an uncommitted pack is not applied"; fi
out=$(cd "$R" && bash "$REVIEW" prep)
if echo "$out" | grep -qxF 'ACTIVE_STACKS: node'; then ok "prep: active stacks from the merge base"; else bad "prep: active stacks line wrong"; fi
# Run from a subdirectory: the listing must still be the repository root's.
mkdir -p "$R/sub"
out=$(cd "$R/sub" && bash "$REVIEW" stacks)
if [[ "$out" == "node" ]]; then ok "stacks: same answer from a subdirectory"; else bad "stacks: from a subdirectory got '$out'"; fi
rm -rf "$R"

# A base named neither main nor master (a CI checkout with only remote refs looks the same): with
# no base argument there is no merge base, so no pack applies, never the change's own.
R=$(mktemp -d)
g init -q -b trunk
mkdir -p "$R/.review-pro/node"
echo '{"name":"node","version":"1.0.0","reviewers":["security"]}' > "$R/.review-pro/node/manifest.json"
echo 'TRUNK SIGNAL' > "$R/.review-pro/node/security.md"
g add .; g commit -qm base
g checkout -q -b feat
mkdir -p "$R/.review-pro/evil"
echo '{"name":"evil","version":"1.0.0","reviewers":["security"]}' > "$R/.review-pro/evil/manifest.json"
echo 'EVIL SIGNAL' > "$R/.review-pro/evil/security.md"
echo 'HEAD SIGNAL' > "$R/.review-pro/node/security.md"
g add .; g commit -qm change
out=$(cd "$R" && bash "$REVIEW" stacks); rc=$?
if [[ "$rc" -eq 0 && -z "$out" ]]; then ok "no main or master: no stacks"; else bad "no main or master: stacks printed '$out' (rc=$rc)"; fi
out=$(cd "$R" && bash "$REVIEW" signals security)
if [[ -z "$out" ]]; then ok "no main or master: no signals"; else bad "no main or master: signals printed the change's packs"; fi
out=$(cd "$R" && bash "$REVIEW" stacks trunk)
if [[ "$out" == "node" ]]; then ok "stacks <base>: the named base's stacks"; else bad "stacks trunk: expected 'node', got '$out'"; fi
out=$(cd "$R" && bash "$REVIEW" signals security trunk)
if echo "$out" | grep -qxF 'TRUNK SIGNAL' && ! echo "$out" | grep -qF -e 'HEAD SIGNAL' -e 'EVIL SIGNAL'; then ok "signals <reviewer> <base>: only the named base's text"; else bad "signals security trunk: wrong text"; fi
out=$(cd "$R" && bash "$REVIEW" prep trunk)
if echo "$out" | grep -qxF 'ACTIVE_STACKS: node'; then ok "prep <base>: active stacks from the named base"; else bad "prep trunk: active stacks line wrong"; fi
out=$(cd "$R" && bash "$REVIEW" prep)
if echo "$out" | grep -qxF 'ACTIVE_STACKS: ' || echo "$out" | grep -qxF 'ACTIVE_STACKS:'; then ok "prep with no base: no active stacks"; else bad "prep with no base: active stacks printed"; fi
rm -rf "$R"

# Unrelated histories: an orphan branch has no merge base with main, so no pack applies.
R=$(mktemp -d)
g init -q -b main; echo x > "$R/a.txt"; g add .; g commit -qm base
g checkout -q --orphan loose
mkdir -p "$R/.review-pro/evil"
echo '{"name":"evil","version":"1.0.0","reviewers":["security"]}' > "$R/.review-pro/evil/manifest.json"
echo 'EVIL SIGNAL' > "$R/.review-pro/evil/security.md"
g add .; g commit -qm orphan
if git -C "$R" cat-file -e HEAD:.review-pro/evil/manifest.json 2>/dev/null; then ok "orphan branch control: the orphan commit holds the pack"; else bad "orphan branch control: setup failed"; fi
out=$(cd "$R" && bash "$REVIEW" stacks); rc=$?
if [[ "$rc" -eq 0 && -z "$out" ]]; then ok "orphan branch: no stacks"; else bad "orphan branch: stacks printed '$out' (rc=$rc)"; fi
out=$(cd "$R" && bash "$REVIEW" signals security)
if [[ -z "$out" ]]; then ok "orphan branch: no signals"; else bad "orphan branch: signals printed the change's packs"; fi
rm -rf "$R"

# A tag named main on the change's own commit: git prefers the tag over the branch for the bare
# name, which would make the merge base the change. The base is the branch refs/heads/main.
R=$(mktemp -d)
g init -q -b main
mkdir -p "$R/.review-pro/node"
echo '{"name":"node","version":"1.0.0","reviewers":["security"]}' > "$R/.review-pro/node/manifest.json"
echo 'BASE SIGNAL' > "$R/.review-pro/node/security.md"
g add .; g commit -qm base
g checkout -q -b feat
echo 'EVIL SIGNAL' > "$R/.review-pro/node/security.md"
g commit -qam change
g tag main
if [[ "$(git -C "$R" rev-parse main 2>/dev/null)" == "$(git -C "$R" rev-parse HEAD)" ]]; then ok "tag control: the bare name main resolves to the change's tag"; else bad "tag control: setup failed"; fi
out=$(cd "$R" && bash "$REVIEW" signals security)
if echo "$out" | grep -qxF 'BASE SIGNAL' && ! echo "$out" | grep -qF 'EVIL SIGNAL'; then ok "a tag named main: the branch's merge base is used"; else bad "a tag named main: the change's pack was applied"; fi
# An explicit base that is also a tag is refused (round 3): by bare name git takes the tag.
for sub in "signals security main" "stacks main" "prep main"; do
  out=$(cd "$R" && bash "$REVIEW" $sub 2>&1); rc=$?
  if [[ "$rc" -eq 2 ]] && echo "$out" | grep -qF 'ambiguous base: main is also a tag'; then ok "$sub with a tag named main: refused"; else bad "$sub with a tag named main: rc=$rc"; fi
done
out=$(cd "$R" && bash "$REVIEW" signals security refs/heads/main)
if echo "$out" | grep -qxF 'BASE SIGNAL' && ! echo "$out" | grep -qF 'EVIL SIGNAL'; then ok "a full ref base: used as given"; else bad "refs/heads/main as base: wrong text"; fi
out=$(cd "$R" && bash "$REVIEW" signals security "$(git -C "$R" rev-parse refs/heads/main)")
if echo "$out" | grep -qxF 'BASE SIGNAL'; then ok "a sha base: used as given"; else bad "a sha base: wrong text"; fi
# A clone: origin/main resolves as the remote-tracking ref, and a fetched tag named origin/main
# pointing at the change is refused rather than taken.
C=$(mktemp -d)
git clone -q "$R" "$C/c" 2>/dev/null
git -C "$C/c" checkout -q feat 2>/dev/null
git -C "$C/c" tag -d main >/dev/null 2>&1
out=$(cd "$C/c" && bash "$REVIEW" signals security origin/main)
if echo "$out" | grep -qxF 'BASE SIGNAL' && ! echo "$out" | grep -qF 'EVIL SIGNAL'; then ok "origin/main: the remote-tracking ref"; else bad "origin/main: wrong text"; fi
git -C "$C/c" tag origin/main HEAD
out=$(cd "$C/c" && bash "$REVIEW" signals security origin/main 2>&1); rc=$?
if [[ "$rc" -eq 2 ]] && ! echo "$out" | grep -qF 'EVIL SIGNAL'; then ok "a tag named origin/main: refused"; else bad "a tag named origin/main: rc=$rc"; fi
rm -rf "$R" "$C"

# A repository whose base is master, with a tag named master on the change.
R=$(mktemp -d)
g init -q -b master
mkdir -p "$R/.review-pro/node"
echo '{"name":"node","version":"1.0.0","reviewers":["security"]}' > "$R/.review-pro/node/manifest.json"
echo 'BASE SIGNAL' > "$R/.review-pro/node/security.md"
g add .; g commit -qm base
g checkout -q -b feat
echo 'EVIL SIGNAL' > "$R/.review-pro/node/security.md"
g commit -qam change
g tag master
out=$(cd "$R" && bash "$REVIEW" signals security)
if echo "$out" | grep -qxF 'BASE SIGNAL' && ! echo "$out" | grep -qF 'EVIL SIGNAL'; then ok "master base with a tag named master: the branch is used"; else bad "master base with a tag named master: the change's pack was applied"; fi
rm -rf "$R"

# An explicit base that does not resolve is an error, never an empty "no packs" answer.
R=$(mktemp -d)
g init -q -b main; echo x > "$R/a.txt"; g add .; g commit -qm base
for sub in "stacks mian" "signals security mian" "prep mian"; do
  out=$(cd "$R" && bash "$REVIEW" $sub 2>&1); rc=$?
  if [[ "$rc" -eq 2 ]] && echo "$out" | grep -qF 'unknown base: mian'; then ok "$sub: an unknown base fails"; else bad "$sub: an unknown base returned rc=$rc"; fi
done
rm -rf "$R"

# A reviewer file only at the merge base still applies; one the branch adds does not.
R=$(mktemp -d)
g init -q -b main
mkdir -p "$R/.review-pro/node"
echo '{"name":"node","version":"1.0.0","reviewers":["security","correctness"]}' > "$R/.review-pro/node/manifest.json"
echo 'BASE SIGNAL' > "$R/.review-pro/node/security.md"
g add .; g commit -qm base
g checkout -q -b feat
g rm -q .review-pro/node/security.md
echo 'ADDED SIGNAL' > "$R/.review-pro/node/correctness.md"
g add .; g commit -qm change
out=$(cd "$R" && bash "$REVIEW" signals security)
if echo "$out" | grep -qxF 'BASE SIGNAL'; then ok "a reviewer file the branch deletes still applies"; else bad "a reviewer file the branch deletes was dropped"; fi
out=$(cd "$R" && bash "$REVIEW" signals correctness)
if [[ -z "$out" ]]; then ok "a reviewer file the branch adds does not apply"; else bad "a reviewer file the branch adds printed '$out'"; fi
rm -rf "$R"

echo "---"
echo "pass=$pass fail=$fail"
finished=1
