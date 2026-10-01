<!-- valkey-io__valkey@36f37c0 correctness-reviewer; verbatim final answer -->
- severity: Critical
  category: correctness.logic
  file: src/networking.c
  line: 2772
  title: Comma operator inside the ternary makes snprintf's format argument a size_t or a user-data pointer, and every real argument is thrown away
  evidence: |
    snprintf(buf, sizeof(buf), server.hide_user_data_from_log ?
             ("Query buffer during protocol error: [hide_user_data_from_log]Redacted %zu bytes",
              sdslen(c->querybuf) - c->qb_pos) :
             ("Query buffer during protocol error: '%.*s' (... more %zu bytes ...) '%.*s'",
              PROTO_DUMP_LEN / 2, c->querybuf + c->qb_pos, sdslen(c->querybuf) - c->qb_pos - PROTO_DUMP_LEN,
              PROTO_DUMP_LEN / 2, c->querybuf + sdslen(c->querybuf) - PROTO_DUMP_LEN / 2));
  evidence_refs: [src/server.h:1183, src/Makefile:49, .github/workflows/daily.yml:63, .github/workflows/external.yml:24]
  impact: |
    A parenthesized group used as one function argument is a single expression, so each comma in it is the comma operator. Each group evaluates its operands left to right, throws away all but the last, and yields the last one. So snprintf gets only three arguments (buf, sizeof(buf), and the ternary result). The format literals and every intended vararg are dropped.
    - The "true" branch yields `sdslen(c->querybuf) - c->qb_pos`, a `size_t` (qb_pos is `size_t`, server.h:1183).
    - The "false" branch yields `c->querybuf + sdslen(c->querybuf) - PROTO_DUMP_LEN / 2`, a `char *` (sds).
    - A conditional mixing an integer and a pointer violates a constraint (C11 6.5.15p3). GCC/Clang only warn by default ("pointer/integer type mismatch in conditional expression", plus -Wunused-value on the dropped comma operands under -Wall). The result type is `char *`.
    - The local build uses `WARN=-Wall -W ... -Werror=deprecated-declarations` and does not make these warnings errors, so the code compiles. CI jobs built with `SERVER_CFLAGS=-Werror` (daily.yml:63, external.yml:24) will fail.
    Runtime, on the path where the unread query buffer is at least PROTO_DUMP_LEN (128) bytes and a protocol error is logged. This path is always taken for a primary link, or for any client when verbosity <= verbose.
    - With hide-user-data-from-log yes: the format pointer is the integer byte count (for example 0x200) cast to `char *`. snprintf dereferences it, so the server crashes with SIGSEGV. That is a crash an unauthenticated client can trigger by sending a large malformed request.
    - With hide-user-data-from-log no (the default, tests/assets/default.conf:41): the last 64 bytes of attacker-controlled query buffer become the format string, and no varargs are passed. A `%s`/`%n`/`%x` in the client's payload is undefined behavior: it reads or writes through garbage varargs, which can crash the server or disclose memory into the log. Even with benign input, the log loses the head excerpt and the "more N bytes" count that it showed before this change.
    This breaks the existing default-config behavior, not just the new redaction path.
  remedy: |
    Use two separate calls instead of a ternary over argument lists:
      if (server.hide_user_data_from_log) {
          snprintf(buf, sizeof(buf), "Query buffer during protocol error: [hide_user_data_from_log]Redacted %zu bytes",
                   sdslen(c->querybuf) - c->qb_pos);
      } else {
          snprintf(buf, sizeof(buf), "Query buffer during protocol error: '%.*s' (... more %zu bytes ...) '%.*s'",
                   PROTO_DUMP_LEN / 2, c->querybuf + c->qb_pos, sdslen(c->querybuf) - c->qb_pos - PROTO_DUMP_LEN,
                   PROTO_DUMP_LEN / 2, c->querybuf + sdslen(c->querybuf) - PROTO_DUMP_LEN / 2);
      }
    Also add a test that sends a protocol error with more than 128 bytes of pending data, under both settings of hide-user-data-from-log. Today tests/unit/protocol.tcl:96 only checks the client-facing error, so neither path is covered.
  confidence: high
  overlap_hints: [security.injection, tests.coverage]

Note: I could not compile a standalone reproduction because writing to /tmp was not permitted. The verdict comes from C comma-operator and conditional-operator semantics, plus the types confirmed in src/server.h. The short-buffer branch (line 2768) is correct: both ternary operands there are `char *`/string literals. catClientInfoString already receives `server.hide_user_data_from_log`, so the rest of the log line is redacted consistently.

## Files examined
examined: [src/networking.c]
not_examined: []
