#!/bin/bash
# Run one kind of prompt on several cases in parallel. Usage: batch.sh <work dir> <kind> <label> <case> [...]
W="$1"; K="$2"; L="$3"; shift 3
HERE="$(cd "$(dirname "$0")" && pwd)"
for c in "$@"; do "$HERE/run.sh" "$W" "$c" "$L" "$(python3 "$HERE/prompts.py" "$W" "$K" "$c")" & done
wait
for c in "$@"; do echo "=== $c exit $(cat "$W/$c/$L/exit")"; python3 "$HERE/tally.py" "$W/$c/$L" | grep -E "TOTAL|check|util"; done
