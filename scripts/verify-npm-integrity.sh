#!/usr/bin/env bash
# Compare a downloaded npm tarball against the integrity string the registry
# publishes for it. The fetch stays in the workflow (it is I/O configuration,
# retries and CDN timing); the comparison lives here because it is the part a
# bug can silently invert, and a script can be tested while a workflow step
# can only be exercised by tagging a release.
#
# Usage: verify-npm-integrity.sh <tarball> <expected-integrity>
#   <expected-integrity> is the registry's dist.integrity, e.g. "sha512-...".
# Exit 0 on match, 1 on mismatch or unreadable input, 2 on usage error.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <tarball> <expected-integrity>" >&2
  exit 2
fi
tarball="$1"
expected="$2"

if [[ ! -r "$tarball" ]]; then
  echo "error: cannot read tarball '$tarball'" >&2
  exit 1
fi
if [[ "$expected" != sha512-* ]]; then
  echo "error: expected integrity must be an sha512-… string, got '$expected'" >&2
  exit 1
fi

actual="sha512-$(openssl dgst -sha512 -binary "$tarball" | base64 | tr -d '\n')"

if [[ "$expected" != "$actual" ]]; then
  echo "error: tarball digest does not match the registry's dist.integrity" >&2
  echo "  expected: $expected" >&2
  echo "  actual:   $actual" >&2
  exit 1
fi
echo "integrity verified: $actual ($(wc -c < "$tarball" | tr -d ' ') bytes)"
