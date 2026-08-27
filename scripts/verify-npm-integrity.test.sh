#!/usr/bin/env bash
# Tests for verify-npm-integrity.sh. Same conventions as validate.test.sh:
# a counter, ok/bad lines, and an EXIT trap so a stranded assertion cannot
# exit 0.
set -u
pass=0; fail=0
ok(){ echo "ok - $1"; pass=$((pass+1)); }
bad(){ echo "not ok - $1"; fail=$((fail+1)); }
trap 'echo "---"; echo "pass=$pass fail=$fail"; exit $(( fail > 0 ))' EXIT

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V="$HERE/verify-npm-integrity.sh"
T=$(mktemp -d)

printf 'not really a tarball, but bytes are bytes\n' > "$T/pkg.tgz"
good="sha512-$(openssl dgst -sha512 -binary "$T/pkg.tgz" | base64 | tr -d '\n')"

# 1: matching digest passes
if bash "$V" "$T/pkg.tgz" "$good" >/dev/null 2>&1; then ok "matching digest accepted"; else bad "matching digest rejected"; fi

# 2: a single flipped byte fails. This is the case the whole script exists for.
printf 'X' >> "$T/pkg.tgz"
if bash "$V" "$T/pkg.tgz" "$good" >/dev/null 2>&1; then bad "tampered tarball accepted"; else ok "tampered tarball rejected"; fi

# 3: an empty file never matches a real digest (the zero-byte curl -f/-L hazard)
: > "$T/empty.tgz"
if bash "$V" "$T/empty.tgz" "$good" >/dev/null 2>&1; then bad "empty tarball accepted"; else ok "empty tarball rejected"; fi

# 4: a non-sha512 expected string is refused loudly, not compared
if bash "$V" "$T/pkg.tgz" "sha256-abc" >/dev/null 2>&1; then bad "non-sha512 integrity accepted"; else ok "non-sha512 integrity refused"; fi

# 5: unreadable path fails rather than passing vacuously
if bash "$V" "$T/nope.tgz" "$good" >/dev/null 2>&1; then bad "missing tarball accepted"; else ok "missing tarball rejected"; fi

# 6: usage error is distinct (exit 2)
bash "$V" "$T/pkg.tgz" >/dev/null 2>&1; rc=$?
if [[ $rc -eq 2 ]]; then ok "usage error exits 2"; else bad "usage error exited $rc"; fi

rm -rf "$T"
