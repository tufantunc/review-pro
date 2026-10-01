<!-- wavetermdev__waveterm@90a57d5 security-reviewer; verbatim final answer -->
## Security findings: none

I traced each of the four concerns in the brief. None of them produces a new vulnerability.

- **Packed token in the WSL `sh -c` string, unquoted** (`pkg/shellexec/shellexec.go:577-582`): this is safe. `PackForClient` (`pkg/util/shellutil/tokenswap.go:58-65`) packs only `Token`, `SockName` and `RpcContext`, then encodes them with `base64.StdEncoding`. That alphabet is `A-Za-z0-9+/=`, and none of those characters means anything special to `sh`, so nothing can be injected.
- **Is the JWT inside the packed token?** No. The JWT sits in `TokenSwapEntry.Env` and is not packed. The server sends it back only when the one-time UUID is redeemed (`GetAndRemoveTokenSwapEntry`, `pkg/wshutil/wshproxy.go:154`). That UUID expires after 5 minutes (`Exp`, `blockcontroller.go:326`).
- **`log.Printf("full combined command...")`**: this is an improvement. At the merge base the raw JWT was written into `cmdCombined` and logged. Now the log line holds only the short-lived swap-token UUID.
- **`conn.Debugf(ctx, "packed swaptoken ...")` in WSL**: `WslConn.Debugf` calls `blocklogger.Infof` rather than a verbose-only logger. But `StartWslShellProc` receives the plain `ctx` from `blockcontroller.go:333`, which is `context.Background()` with a timeout and no block ID attached. So `blocklogger.Infof` returns without writing anything. The SSH path already logs the packed token the same way (base `shellexec.go:443`), and the swap-token UUID is already written to the same block through `blocklogger.Infof(logCtx, "[conndebug] created swaptoken...")`, which existed before this change.
- **`cmd:initscript*` and `cmd:env` sent through the swap token and eval'd by the rc files**: this does not widen who can run code. `SetMetaCommand` (`pkg/wshrpc/wshserver/wshserver.go:129`) and `ControllerInputCommand` (`:248`) have no authorization check, and nothing in this diff added one. Any client that can write block meta could already set `cmd`, `cmd:env` or `term:localshellpath`, or type keystrokes into a block. The new keys give that same actor no new power, so they cross no new boundary.
- **Env values now reach a shell instead of the process environment**: keys are checked with `IsValidEnvVarName` and values go through `HardQuote*` (`tokenswap.go:103-136`). The values come from the same block-meta writer who can already set `cmd:initscript`, so there is no privilege gain.
- **`GetConn` / `GetWslConn` signature changes** (connect-on-get removed) and the `BlockFile_*` constant move: neither has any security effect.

## Files examined
examined: [cmd/wsh/cmd/wshcmd-run.go, pkg/blockcontroller/blockcontroller.go, pkg/remote/conncontroller/conncontroller.go, pkg/shellexec/shellexec.go, pkg/util/shellutil/shellutil.go, pkg/wavebase/wavebase.go, pkg/waveobj/metaconsts.go, pkg/waveobj/metamap.go, pkg/waveobj/wtypemeta.go, pkg/wshrpc/wshserver/wshserver.go, pkg/wshutil/wshutil.go, pkg/wslconn/wslconn.go]
not_examined:
  - file: frontend/types/gotypes.d.ts
    reason: generated TS type mirror of wtypemeta.go; excluded from the diff read (frontend path filtered), not read
