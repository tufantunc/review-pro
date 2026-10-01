<!-- wavetermdev__waveterm@90a57d5 backend-reviewer; verbatim final answer -->
I found 6 backend design problems in this change. Two are High and block the change as written:
1. Command blocks lose all their environment variables and their auth token.
2. A failed remote-info call now aborts shell start instead of falling back to a plain shell.

- severity: High
  category: backend.boundary
  file: pkg/blockcontroller/blockcontroller.go
  line: 354
  title: Command blocks no longer receive the env file, `cmd:env` or `WAVETERM_JWT`, because they now travel only in a swap token that command blocks never redeem
  evidence: |
    envMap, err := resolveEnvMap(bc.BlockId, blockMeta, remoteName)
    ...
    for k, v := range envMap {
        token.Env[k] = v
    }
    // removed in shellexec.go:
    -	shellutil.UpdateCmdEnv(ecmd, cmdOpts.Env)
    -	for envKey, envVal := range cmdOpts.Env { session.Setenv(envKey, envVal) }
    -	cmdCombined = fmt.Sprintf(`%s=%s %s`, wshutil.WaveJwtTokenVarName, jwtToken, cmdCombined)
  evidence_refs: [pkg/shellexec/shellexec.go:360, pkg/shellexec/shellexec.go:389, pkg/shellexec/shellexec.go:512, pkg/util/shellutil/shellutil.go:116, pkg/wshutil/wshproxy.go:96, cmd/wsh/cmd/wshcmd-root.go:85]
  impact: |
    The values in `token.Env` only reach a process when the shell runs `wsh token "$WAVETERM_SWAPTOKEN"`, and only the Wave rc files do that (shellutil.go:60/116/144/156). Those rc files are only injected when `cmdStr == ""`. For command blocks (`cmdStr != ""`) the local, SSH and WSL paths all run `shell -c cmdStr` with no rc file. `PackForClient` only packs Token, SockName and RpcContext, not Env. So `wsh run` env content (written to `wavebase.BlockFile_Env`), `cmd:env`, and `WAVETERM_JWT` never reach the process. Any `wsh` call inside a command block then fails, because wshcmd-root.go:85 reads `WAVETERM_JWT` from the process env. Before this change, all of these were set directly on the process or session.
    Relatedly, `StartRemoteShellProcNoWsh` and `StartWslShellProcNoWsh` never redeem the swap token. On those two nowsh paths, user env is now carried only in a token nothing redeems.
  remedy: Keep a direct delivery path for command blocks. When `cmdStr != ""`, apply `swapToken.Env` straight to the process: `UpdateCmdEnv` locally, `session.Setenv` or an env prefix over SSH, a command prefix for WSL. Alternatively, wrap `cmdStr` so it redeems the token before running. Add a test that a command block sees `cmd:env` values and `WAVETERM_JWT`.
  confidence: high
  overlap_hints: [correctness.regression, api-contract.breaking]

- severity: High
  category: backend.error-handling
  file: pkg/blockcontroller/blockcontroller.go
  line: 409
  title: A failed remote-info RPC in `getConnUnion` now aborts shell start and skips the existing no-wsh fallback
  evidence: |
    remoteInfo, err := wshclient.RemoteGetInfoCommand(wshclient.GetBareRpcClient(), &wshrpc.RpcOpts{Route: connRoute, Timeout: 2000})
    if err != nil {
        // weird error, could flip the wshEnabled flag and allow it to go forward, but the connection should have already been vetted
        return fmt.Errorf("unable to obtain remote info from connserver: %w", err)
    }
  evidence_refs: [pkg/blockcontroller/blockcontroller.go:481, pkg/blockcontroller/blockcontroller.go:560, pkg/shellexec/shellexec.go:330]
  impact: |
    Before this change, the same RPC ran inside `StartRemoteShellProc`/`StartWslShellProc`. On failure the caller ran `conn.SetWshError(err); conn.WshEnabled.Store(false)` and retried with `StartRemoteShellProcNoWsh`. Now `setupAndStartShellProcess` returns at line 481 before that fallback. Nothing calls `SetWshError`, and `WshEnabled` stays true.
    So a connserver that has stalled or crashed (the connection still reports Connected) makes every block on that connection fail on each restart, where it used to fall back to a plain shell. The user gets no wsh-error UI. Every successful start also pays for the RPC twice.
  remedy: On RPC failure, don't return an error. Call `SetWshError` on the SSH/WSL conn, set `union.WshEnabled = false` and `WshEnabled.Store(false)`, then continue so the no-wsh path runs. Better still, compute the shell path and type once and pass them into `StartRemoteShellProc`/`StartWslShellProc`, so the RPC is not duplicated.
  confidence: high
  overlap_hints: [correctness.error-path, performance.blocking-io]

- severity: Medium
  category: backend.validation
  file: pkg/blockcontroller/blockcontroller.go
  line: 544
  title: The SSH branch ignores `cmd:nowsh` (`connUnion.WshEnabled`) and still mints a JWT and starts wsh
  evidence: |
    } else if connUnion.ConnType == ConnType_Ssh {
        conn := connUnion.SshConn
        if !conn.WshEnabled.Load() {
            shellProc, err = shellexec.StartRemoteShellProcNoWsh(...)
        } else {
            ...
            jwtStr, err := wshutil.MakeClientJWTToken(rpcContext, sockName)
  impact: |
    `getConnUnion` computes `rtn.WshEnabled = wshEnabled && conn.WshEnabled.Load()`, and the WSL and local branches use it. The SSH branch reads only the connection flag.
    A block with `cmd:nowsh: true` on a wsh-enabled SSH connection therefore gets a JWT and the wsh integration anyway. Before this change, `cmd:nowsh` at least suppressed JWT creation. Because `getRemoteInfoAndShellType` returned early for the same block, `ShellType` is empty and the init-script lookup is also wrong. This is also inconsistent with the commit message "fix some nowsh flags".
  remedy: Use `if !connUnion.WshEnabled {` in the SSH branch, matching WSL and local.
  confidence: high
  overlap_hints: [correctness.regression, security.token-exposure]

- severity: Medium
  category: backend.error-handling
  file: pkg/blockcontroller/blockcontroller.go
  line: 355
  title: The env-file read error is now only logged, so command blocks start without their env
  evidence: |
    envMap, err := resolveEnvMap(bc.BlockId, blockMeta, remoteName)
    if err != nil {
        log.Printf("error resolving env map: %v\n", err)
    }
  impact: |
    Before this change, `createCmdStrAndOpts` returned `fmt.Errorf("error reading command env file: %w", err)` and the command block refused to start. Now a filestore read failure or timeout (2s context) is written only to the server log.
    The block then runs a command (for example one from `wsh run`) without its user env, and nothing tells the user. Where a command depends on env vars such as credentials or paths, that silent partial start is worse than a visible failure.
  remedy: Return the error from `makeSwapToken` and fail `setupAndStartShellProcess` at least for `BlockController_Cmd`, as before. Otherwise, write a visible warning to the block's term output through `blocklogger`.
  confidence: high
  overlap_hints: [correctness.error-path]

- severity: Medium
  category: backend.error-handling
  file: pkg/blockcontroller/blockcontroller.go
  line: 583
  title: With `cmd:nowsh`, local shells drop the `term:localshellpath` setting and the shell-specific init script
  evidence: |
    func (union *ConnUnion) getRemoteInfoAndShellType(blockMeta waveobj.MetaMapType) error {
        if !union.WshEnabled {
            return nil
        }
    ...
        cmdOpts.ShellPath = connUnion.ShellPath
  impact: |
    Shell-path resolution sits behind the wsh check, even though the local path does not need wsh. With `cmd:nowsh` on a local block, `ShellPath` stays `""`, so `StartLocalShellProc` falls back to `DetectLocalShellPath()`. That ignores the block's `term:localshellpath` and the global setting, which the old code applied whatever `cmd:nowsh` said.
    `ShellType` is also empty, so `getCustomInitScriptKeyCascade` only ever uses the generic `cmd:initscript`.
  remedy: Resolve the local shell path and type unconditionally. Gate only the remote RPC on `WshEnabled`, and on the remote no-wsh path fall back to `conn.GetConfigShellPath()`.
  confidence: high
  overlap_hints: [correctness.regression]

- severity: Low
  category: backend.api-shape
  file: pkg/waveobj/wtypemeta.go
  line: 54
  title: Keys documented as "can be nested under [conn]" are only honoured for initscript, and `resolveEnvMap` ignores its `connName` argument
  evidence: |
    // these can be nested under "[conn]"
    CmdEnv            map[string]string `json:"cmd:env,omitempty"`
    CmdCwd            string            `json:"cmd:cwd,omitempty"`
    ...
    func resolveEnvMap(blockId string, blockMeta waveobj.MetaMapType, connName string) (map[string]string, error) {
        ... cmdEnv := blockMeta.GetMap(waveobj.MetaKey_CmdEnv)
  evidence_refs: [pkg/blockcontroller/blockcontroller.go:252, pkg/blockcontroller/blockcontroller.go:490]
  impact: A user who sets `"[myhost]": {"cmd:env": {...}, "cmd:cwd": "..."}` gets no effect and no error. Only `getCustomInitScript` reads `GetConnectionOverride`, so the meta schema promises more than the backend does.
  remedy: Apply `GetConnectionOverride(connName)` inside `resolveEnvMap`, merging the override on top of the base values, and in the `cmd:cwd` lookups. Until then, narrow the comment to the initscript keys.
  confidence: high
  overlap_hints: [spec.partial, api-contract.schema-drift]

- severity: Low
  category: backend.error-handling
  file: pkg/shellexec/shellexec.go
  line: 258
  title: For WSL, a failure to pack the swap token is now only logged and the shell starts without it
  evidence: |
    packedToken, err := cmdOpts.SwapToken.PackForClient()
    if err != nil {
        conn.Infof(ctx, "error packing swap token: %v", err)
    } else {
  impact: The old WSL path failed hard with "no jwt token provided to connection", which triggered the `SetWshError` fallback to no-wsh. Now it starts a wsh-mode shell with no token, so wsh silently doesn't work and the user sees nothing. Marshal failure is unlikely for this struct, so the risk is low, but the error still ends at a log line.
  remedy: Return the error from `StartWslShellProc`, and likewise in the local and remote variants, so the caller's existing fallback runs.
  confidence: medium
  overlap_hints: [correctness.error-path]

## Files examined
examined: [cmd/wsh/cmd/wshcmd-run.go, frontend/types/gotypes.d.ts, pkg/blockcontroller/blockcontroller.go, pkg/remote/conncontroller/conncontroller.go, pkg/shellexec/shellexec.go, pkg/util/shellutil/shellutil.go, pkg/wavebase/wavebase.go, pkg/waveobj/metaconsts.go, pkg/waveobj/metamap.go, pkg/waveobj/wtypemeta.go, pkg/wshrpc/wshserver/wshserver.go, pkg/wshutil/wshutil.go, pkg/wslconn/wslconn.go]
not_examined: []
