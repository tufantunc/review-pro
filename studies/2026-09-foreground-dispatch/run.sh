#!/bin/bash
# One headless run in a case's clone. Usage: run.sh <work dir> <case> <label> <prompt>
# Settings: the user's model and effort (Opus 5.5, high); user settings, plugins, hooks, MCP servers
# and ~/.claude/CLAUDE.md are left out (--setting-sources project,local, --strict-mcp-config), so the
# numbers are review-pro's own. review-pro is installed at project scope in the clone (cases.py).
set -u
W="$1"; C="$2"; L="$3"; P="$4"
OUT="$W/$C/$L"; mkdir -p "$OUT"
cd "$W/$C/repo" || exit 2
date +%s > "$OUT/start"
claude -p "$P" --model claude-opus-5-5 --effort high --setting-sources project,local --strict-mcp-config \
  --permission-mode bypassPermissions --output-format stream-json --verbose > "$OUT/stream.jsonl" 2> "$OUT/stderr.txt"
echo $? > "$OUT/exit"
date +%s > "$OUT/end"
