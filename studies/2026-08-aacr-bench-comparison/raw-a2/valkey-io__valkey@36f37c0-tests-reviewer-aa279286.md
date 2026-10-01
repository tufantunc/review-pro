<!-- valkey-io__valkey@36f37c0 tests-reviewer; verbatim final answer -->
- severity: High
  category: tests.coverage
  file: src/networking.c
  line: 2771
  title: The new redacted long-buffer branch has no test, and that branch is malformed (it uses the comma operator)
  evidence: |
    snprintf(buf, sizeof(buf), server.hide_user_data_from_log ?
             ("Query buffer during protocol error: [hide_user_data_from_log]Redacted %zu bytes",
              sdslen(c->querybuf) - c->qb_pos) :
             ("Query buffer during protocol error: '%.*s' (... more %zu bytes ...) '%.*s'",
              PROTO_DUMP_LEN / 2, c->querybuf + c->qb_pos, ...,
              PROTO_DUMP_LEN / 2, c->querybuf + sdslen(c->querybuf) - PROTO_DUMP_LEN / 2));
  impact: In C, the parenthesised groups are comma expressions, not argument lists. Each group evaluates to its last operand. With hide-user-data-from-log on, the format argument becomes the integer `sdslen(c->querybuf) - c->qb_pos`, used as a `const char *`. That is undefined behaviour and a likely crash in snprintf. No test anywhere runs a protocol error with a query buffer of 128 bytes or more while hide-user-data-from-log is yes. `grep -rn hide.user.data tests/` finds only `tests/assets/default.conf:41: hide-user-data-from-log no`. So nothing catches this.
  remedy: Add a test in tests/unit/protocol.tcl. Start a server with `hide-user-data-from-log yes` (loglevel is already verbose in default.conf). Send a protocol-error payload of 128 bytes or more, for example the existing desync loop. Assert the reply still matches `*Protocol error*` and the server stays up (`r ping`). Then call `verify_log_message 0 "*Query buffer during protocol error: \[hide_user_data_from_log\]Redacted * bytes*" $from_line` and `verify_no_log_message 0 "*AAAA*" $from_line`. Both helpers are in tests/support/util.tcl:175 and :184.
  confidence: high
  overlap_hints: [correctness.logic, security.pii]

- severity: High
  category: tests.assertion
  file: tests/unit/protocol.tcl
  line: 96
  title: The existing desync tests run the long-buffer log branch but never check the log, so they pass while the non-redacted output is broken
  evidence: |
    set PROTO_INLINE_MAX_SIZE [expr 1024 * 64]
    set payload [string repeat A 1024]
    ...
    assert_match {*Protocol error*} [gets $s]]
  impact: These tests send more than 64KB with `loglevel verbose` (tests/assets/default.conf:10) and `hide-user-data-from-log no`. That reaches the `else if (c->querybuf)` branch at networking.c:2770. Because of the comma operator, the format argument there is now `c->querybuf + sdslen - 64`, the raw tail of the client's data. The `'%.*s' (... more %zu bytes ...)` dump is lost, and client bytes are used as a format string. The tests only check the client's reply, so they pass whatever the log contains. The regression (and a format-string risk if the payload contains `%`) gets through CI.
  remedy: Record `set from_line [count_log_lines 0]` before the test. Afterwards, assert `verify_log_message 0 "*Query buffer during protocol error: '*' (... more * bytes ...) '*'*" $from_line`. Add one case whose payload contains `%s%n` and assert the server still answers `ping`.
  confidence: high
  overlap_hints: [correctness.logic, security.injection]

- severity: Medium
  category: tests.coverage
  file: src/networking.c
  line: 2768
  title: The short-buffer (<128 bytes) redaction has no test for either value of the setting
  evidence: |
    snprintf(buf, sizeof(buf), "Query buffer during protocol error: '%s'",
             server.hide_user_data_from_log ? "[hide_user_data_from_log]Redacted" : (c->querybuf + c->qb_pos));
  impact: The point of this change is that the query buffer stays out of the log when the setting is on. No test checks that, so a regression that leaks user data into logs would pass. The existing short-payload error tests (protocol.tcl:16-70, e.g. "Wrong multibulk payload header") check only the client error string.
  remedy: Use one short bad payload, e.g. `*3\r\n$3\r\nSET\r\n$1\r\nx\r\nfooz\r\n`. Run it with `config set hide-user-data-from-log yes` and assert the log contains `*Query buffer during protocol error: '[hide_user_data_from_log]Redacted'*` and does not contain `*fooz*`. Run it again with `no` and assert the log contains `*fooz*`. Reset the setting afterwards.
  confidence: high
  overlap_hints: [security.pii]

## Files examined
examined: [src/networking.c]
not_examined: []
