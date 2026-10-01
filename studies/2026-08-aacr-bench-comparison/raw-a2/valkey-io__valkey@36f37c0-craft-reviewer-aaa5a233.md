<!-- valkey-io__valkey@36f37c0 craft-reviewer; verbatim final answer -->
## Craft findings

- severity: High
  category: craft.spaghetti
  file: src/networking.c
  line: 2771
  title: Redaction is a ternary over parenthesized comma expressions inside a varargs call, which does not do what it looks like
  evidence: |
    snprintf(buf, sizeof(buf), server.hide_user_data_from_log ?
             ("Query buffer during protocol error: [hide_user_data_from_log]Redacted %zu bytes",
              sdslen(c->querybuf) - c->qb_pos) :
             ("Query buffer during protocol error: '%.*s' (... more %zu bytes ...) '%.*s'",
              PROTO_DUMP_LEN / 2, c->querybuf + c->qb_pos, sdslen(c->querybuf) - c->qb_pos - PROTO_DUMP_LEN,
              PROTO_DUMP_LEN / 2, c->querybuf + sdslen(c->querybuf) - PROTO_DUMP_LEN / 2));
  impact: The code reads as if the ternary picks one of two complete argument lists. C does not work that way. Each parenthesized group is a comma-operator expression that evaluates to its last operand. So the "format" handed to snprintf is either `sdslen(...) - c->qb_pos` (a size_t) or `c->querybuf + sdslen(...) - PROTO_DUMP_LEN/2` (a char*). The two format strings and every other argument are thrown away, and the ternary's two arms have incompatible types. The intended behavior is hidden behind a clever-looking construct, and the next reader (or the compiler) has to work out why the line is wrong. This is the worst kind of special case to bolt into a log path that already has two branches.
  remedy: |
    Fold both branches into one. Test the flag once, above the existing size split, and keep the original two snprintf calls unchanged in the else arm. Both inline ternaries go away, and so does the comma-expression trick:
      if (c->querybuf && server.hide_user_data_from_log) {
          snprintf(buf, sizeof(buf), "Query buffer during protocol error: %zu bytes (redacted)",
                   sdslen(c->querybuf) - c->qb_pos);
      } else if (c->querybuf && sdslen(c->querybuf) - c->qb_pos < PROTO_DUMP_LEN) {
          ... original line ...
      } else if (c->querybuf) {
          ... original line ...
      }
    One guard then covers both size cases. The small-buffer branch also gets the byte count, so the two redacted messages no longer differ.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: craft.boundary
  file: src/networking.c
  line: 2769
  title: New redaction marker doesn't match the conventions already used for redacted output
  evidence: |
    server.hide_user_data_from_log ? "[hide_user_data_from_log]Redacted" : (c->querybuf + c->qb_pos));
  impact: 'Redacted log output in this codebase already follows two conventions. Client info uses `"*redacted*"` (src/networking.c:3407, 3430, 3457). Redacted payloads are replaced by their size, as in `"client->argv[%d]: %zu bytes"` (src/debug.c:1079, 1898). This change adds a third form, `[hide_user_data_from_log]Redacted`, in two places. Anyone grepping logs or adding redaction sites now has three spellings to know. The new code is also inconsistent with itself: one branch logs a byte count and the other does not.'
  remedy: 'Follow the existing payload convention: log only the length, e.g. `"Query buffer during protocol error: %zu bytes"`, as debug.c does for redacted argv. Alternatively reuse `*redacted*`. This drops out of the single-guard restructuring in the finding above.'
  confidence: medium
  overlap_hints: [dry.duplication]
  evidence_refs: [src/networking.c:3407, src/debug.c:1079, src/debug.c:1898]

## Files examined
examined: [src/networking.c]
not_examined: []
