<!-- valkey-io__valkey@36f37c0 security-reviewer; verbatim final answer -->
I found one security problem in this change: a High-severity format-string bug in the `else if (c->querybuf)` branch of `setProtocolError` (`src/networking.c`). The other redaction edits are fine.

- severity: High
  category: security.injection
  file: src/networking.c
  line: 2771
  title: The comma operator makes snprintf use a non-format value as its format string: a size_t when hide-user-data-from-log is on, the client's query-buffer bytes when it is off
  evidence: |
    snprintf(buf, sizeof(buf), server.hide_user_data_from_log ?
             ("Query buffer during protocol error: [hide_user_data_from_log]Redacted %zu bytes",
              sdslen(c->querybuf) - c->qb_pos) :
             ("Query buffer during protocol error: '%.*s' (... more %zu bytes ...) '%.*s'",
              PROTO_DUMP_LEN / 2, c->querybuf + c->qb_pos, sdslen(c->querybuf) - c->qb_pos - PROTO_DUMP_LEN,
              PROTO_DUMP_LEN / 2, c->querybuf + sdslen(c->querybuf) - PROTO_DUMP_LEN / 2));
  evidence_refs: [src/networking.c:2682, src/networking.c:2372, src/networking.c:2761, src/Makefile:49, valkey.conf:461]
  impact: |
    Each parenthesized group is one comma expression, not an argument list. It evaluates to its last operand, and the string literals are thrown away. So the call becomes `snprintf(buf, 256, cond ? (size_t)remaining : (char*)tail)` with no further arguments.
    - The two arms are an integer and a pointer, which C does not allow in one conditional. GCC and clang only warn (pointer/integer type mismatch), and the build does not use `-Werror` (src/Makefile:49), so it compiles. The result has pointer type.
    - **Attacker and input:** any network client, before AUTH, sends a request of at least 128 bytes that fails parsing. Example: an inline request over PROTO_INLINE_MAX_SIZE with no newline (src/networking.c:2682). No auth check runs before that size check. The request ends in format directives such as `%n%n%s%s`.
    - **Control that should stop it:** the log call is supposed to use a constant format string. The comma operator removes it, crossing the boundary from untrusted network input into libc's format interpreter.
    - **hide-user-data-from-log no:** the format string is the last 64 bytes of the query buffer, chosen by the attacker. `%n` writes through stack values (memory corruption, possibly code execution); `%s` reads through them (crash). The `isprint` scrub runs on the output after snprintf, so it does not help.
    - **hide-user-data-from-log yes (the shipped default, valkey.conf:461):** the format pointer is the leftover byte count, e.g. 0x10001. snprintf reads from that address and the server segfaults. Any unauthenticated client can crash it.
    - **Precondition:** the block only runs when `server.verbosity <= LL_VERBOSE` (loglevel verbose or debug; the default is notice) or the client is the primary (src/networking.c:2761). On a replica, any protocol error of 128+ bytes from its primary also takes this path, at any log level.
    - Severity is High rather than Critical because of the non-default loglevel requirement. The crash is certain once that holds; code execution through `%n` is plausible but I did not demonstrate it.
  remedy: |
    Put the condition around the whole call, not inside the format argument:
    if (server.hide_user_data_from_log) {
        snprintf(buf, sizeof(buf), "Query buffer during protocol error: [hide_user_data_from_log]Redacted %zu bytes", sdslen(c->querybuf) - c->qb_pos);
    } else {
        snprintf(buf, sizeof(buf), "Query buffer during protocol error: '%.*s' (... more %zu bytes ...) '%.*s'", ...original args...);
    }
    Also consider building with `-Werror=format-security -Werror=format-nonliteral` (or at least `-Werror` for conditional type mismatch) so this pattern fails the build.
  confidence: high
  overlap_hints: [correctness.logic, correctness.error-path]

Other checks, no findings:
- The short-buffer branch (line 2769) is correct: the ternary picks between two `char*` values, and the format literal stays constant.
- Nothing else in this path still logs user data when the flag is on. `catClientInfoString` already gets `server.hide_user_data_from_log`, and `errstr` is always a constant.

## Files examined
examined: [src/networking.c]
not_examined: []
