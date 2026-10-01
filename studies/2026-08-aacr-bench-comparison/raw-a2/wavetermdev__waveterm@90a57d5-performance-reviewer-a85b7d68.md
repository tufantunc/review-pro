<!-- wavetermdev__waveterm@90a57d5 performance-reviewer; verbatim final answer -->
## Performance findings

- severity: Low
  category: performance.blocking
  file: pkg/blockcontroller/blockcontroller.go
  line: 405
  title: Every SSH/WSL shell start with wsh enabled now makes the RemoteGetInfoCommand RPC twice, one after the other
  evidence: |
    // blockcontroller.go (new, getRemoteInfoAndShellType, called from getConnUnion)
    connRoute := wshutil.MakeConnectionRouteId(union.ConnName)
    remoteInfo, err := wshclient.RemoteGetInfoCommand(wshclient.GetBareRpcClient(), &wshrpc.RpcOpts{Route: connRoute, Timeout: 2000})
    ...
    union.ShellPath = remoteInfo.Shell

    // shellexec.go:330 (unchanged, StartRemoteShellProc, called later in the same setupAndStartShellProcess)
    remoteInfo, err := wshclient.RemoteGetInfoCommand(rpcClient, &wshrpc.RpcOpts{Route: connRoute, Timeout: 2000})
    // shellexec.go:178 (unchanged, StartWslShellProc) makes the same call
  evidence_refs: [pkg/shellexec/shellexec.go:178, pkg/shellexec/shellexec.go:330, pkg/wshrpc/wshremote/wshremote.go:391, pkg/wshutil/wshutil.go:559]
  impact: 'The new `getConnUnion` fetches remote info only to work out the shell type. `StartRemoteShellProc` and `StartWslShellProc` still run only when wsh is enabled, and they fetch the same remote info again. So each wsh-enabled remote shell start (opening a terminal block, restarting one, or reconnecting) now makes 2 full round trips through the connserver where it used to make 1. The server side is cheap (`wshutil.GetInfo` just reads the `SHELL` env var, or a cached `dscl` result on macOS), so the added cost is about one network RTT. That is roughly 50-300 ms on a typical WAN SSH link. If the connserver is slow, the worst-case wait before the error goes from 2 s to 4 s. The cost is per user action, not per loop iteration, so it stays Low.'
  remedy: 'Fetch remote info once. Store the `RemoteInfo` on `ConnUnion`, or pass the resolved `ShellPath`/`ShellType` into `cmdOpts`, and have `StartRemoteShellProc`/`StartWslShellProc` use it instead of making the RPC again. Keep in mind that `shellexec` also applies `cmdOpts.ShellPath` and `conn:shellpath` before `remoteInfo.Shell`. The shell type computed in `getConnUnion` from `remoteInfo.Shell` alone skips those overrides, so moving the resolution into one place would also keep the two in agreement.'
  confidence: high
  overlap_hints: [correctness.logic, backend.api-shape]

These hot-path concerns turned out not to be problems:
- **Local start, `DetectLocalShellPath`:** on macOS, `GetMacUserShell` is wrapped in `sync.Once` (shellutil.go:192), so `dscl` runs once per process. On Windows it runs `exec.LookPath` (a PATH scan). `StartLocalShellProc` (shellexec.go:472-474) used to make the same call whenever `ShellPath` was empty. Now that `cmdOpts.ShellPath` is filled in from `connUnion`, that fallback is skipped. The call has moved, not doubled.
- **Env file reads:** `createCmdStrAndOpts` no longer reads the `env` blockfile. `resolveEnvMap` reads it exactly once, inside `makeSwapToken`, for both shell and cmd blocks. Cmd blocks read it once, same as before. Shell blocks now read it once where they used to skip it. That is one small, bounded filestore read per user-initiated shell start, which is negligible.
- **`getCustomInitScript` / `GetConnectionOverride`:** constant-time map lookups over a fixed list of at most 3 keys.

## Files examined
examined: [pkg/blockcontroller/blockcontroller.go, pkg/shellexec/shellexec.go, pkg/util/shellutil/shellutil.go, pkg/wshrpc/wshserver/wshserver.go, pkg/remote/conncontroller/conncontroller.go, pkg/wslconn/wslconn.go, pkg/wshutil/wshutil.go, pkg/waveobj/metamap.go, pkg/waveobj/metaconsts.go, pkg/waveobj/wtypemeta.go, pkg/wavebase/wavebase.go, cmd/wsh/cmd/wshcmd-run.go, frontend/types/gotypes.d.ts]
not_examined: []
