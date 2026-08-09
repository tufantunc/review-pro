#!/usr/bin/env bash
# scripts/record-demo.sh — re-render assets/demo.gif from assets/demo.tape.
#
# Runs the demo against a sandboxed HOME and a throwaway repo, so recording
# never touches your real ~/.claude, ~/.config/opencode, or ~/.agents.
#
# Requires: vhs (brew install vhs), node.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v vhs >/dev/null || { echo "vhs not found — brew install vhs" >&2; exit 1; }

echo "building the CLI so the demo records the current code…"
(cd cli && npm run build >/dev/null)

# A short, fixed sandbox path — mktemp -d on macOS returns a long
# /var/folders/... path, and `add` echoes its destination into the recording.
SANDBOX="/tmp/rp-demo"
rm -rf "$SANDBOX"
trap 'rm -rf "$SANDBOX"' EXIT

# Sandboxed agent-tool home. init writes here, never to the real one.
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# `review-pro` on PATH -> the freshly built local CLI, so the recording shows
# the real binary name rather than a node invocation.
mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/review-pro" <<EOF
#!/bin/sh
exec node "$ROOT/cli/dist/cli.js" "\$@"
EOF
chmod +x "$SANDBOX/bin/review-pro"
export PATH="$SANDBOX/bin:$PATH"

# Throwaway repo the demo operates on. Short path so `add` prints a clean
# destination. .git is what the CLI's project-root check looks for.
DEMO_REPO="$SANDBOX/my-app"
mkdir -p "$DEMO_REPO/.git"

# vhs resolves `Output` relative to its working directory, so run it from the
# repo root and hand the tape an absolute cd target.
(cd "$DEMO_REPO" && vhs "$ROOT/assets/demo.tape" --output "$ROOT/assets/demo.gif")

echo
ls -lh "$ROOT/assets/demo.gif"
