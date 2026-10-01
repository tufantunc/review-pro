<!-- wavetermdev__waveterm@90a57d5 correctness-reviewer; verbatim final answer -->
## Correctness findings

- severity: High
  category: correctness.side-effect
  file: pkg/shellexec/shellexec.go
  line: 552
  title: Removing cmdOpts.Env stops cmd:env, the `wsh run` env file and WAVETERM_JWT from reaching cmd-block and nowsh processes
  evidence: |
    -	shellutil.UpdateCmdEnv(ecmd, cmdOpts.Env)
    ...
    -	for envKey, envVal := range cmdOpts.Env {
    -		session.Setenv(envKey, envVal)
    -	}
    ...
    -	cmdCombined = fmt.Sprintf(`%s=%s %s`, wshutil.WaveJwtTokenVarName, jwtToken, cmdCombined)
  evidence_refs: [pkg/blockcontroller/blockcontroller.go:354, pkg/util/shellutil/shellutil.go:116, cmd/wsh/cmd/wshcmd-run.go:97, cmd/wsh/cmd/wshcmd-root.go:85, pkg/waveapp/waveapp.go:162, cmd/wsh/cmd/wshcmd-root.go:144]
  impact: |
    The env-file data, cmd:env and WAVETERM_JWT now exist only in `swapToken.Env`. The only thing that reads them is the shell rc snippet `eval "$(wsh token "$WAVETERM_SWAPTOKEN" bash ...)"`. That snippet runs only for interactive shells (cmdStr == "") that were started with the wave rcfile or ZDOTDIR. Three cases lose the env:
    (1) Cmd controller blocks. StartLocalShellProc runs `shell -c cmdStr` with no rcfile, so the token is never redeemed. The same holds for the remote and WSL `-c` paths.
       - `wsh run` sends the caller's whole environment (PATH, virtualenv, etc.) through the `env` block file (wshcmd-run.go:97-106). The started command no longer gets it.
       - cmd:env meta is ignored.
       - WAVETERM_JWT is gone from the process env. Any `wsh` call inside a cmd block fails, because wshcmd-root.go:85 reads `os.Getenv(WAVETERM_JWT)`. Waveapp-based programs fail too (waveapp.go:162-164 returns "no WAVETERM_JWT env var set").
    (2) Local shells with cmd:nowsh=true. Before, cmd:env was applied through UpdateCmdEnv. Now the token has no SockName, so `wsh token` fails at "no sockname in token" and cmd:env is dropped.
    (3) SSH wsh-enabled cmd blocks. These lose the `session.Setenv` env they used to get.
  remedy: Keep a direct env channel for non-interactive and nowsh launches. Apply the resolved env map and the JWT to the process env (UpdateCmdEnv / session.Setenv / the `KEY=val` prefix on WSL) when cmdStr != "" or wsh is disabled. Alternatively keep cmdOpts.Env and fill it from resolveEnvMap alongside the token.
  confidence: high
  overlap_hints: [api-contract]

- severity: Medium
  category: correctness.error-path
  file: pkg/blockcontroller/blockcontroller.go
  line: 406
  title: A failed RemoteGetInfo now blocks shell start instead of falling back to no-wsh
  evidence: |
    remoteInfo, err := wshclient.RemoteGetInfoCommand(wshclient.GetBareRpcClient(), &wshrpc.RpcOpts{Route: connRoute, Timeout: 2000})
    if err != nil {
        // weird error, could flip the wshEnabled flag and allow it to go forward, but the connection should have already been vetted
        return fmt.Errorf("unable to obtain remote info from connserver: %w", err)
    }
  evidence_refs: [pkg/shellexec/shellexec.go:178, pkg/blockcontroller/blockcontroller.go:559, pkg/blockcontroller/blockcontroller.go:481]
  impact: Before this change, the same RPC failure happened inside StartRemoteShellProc / StartWslShellProc. The caller then ran SetWshError, set WshEnabled to false, and fell back to the NoWsh start (blockcontroller.go:560-568 / 531-539). Now getConnUnion runs the RPC first and returns an error, so the block never starts. WshEnabled is not flipped either, so every restart fails the same way while the connserver route is unresponsive or times out (2s). The old graceful fallback is unreachable for this failure.
  remedy: On RPC error in getRemoteInfoAndShellType, record SetWshError, set WshEnabled to false on the conn and the union, and continue down the no-wsh path. Do not return an error.
  confidence: high
  overlap_hints: [backend]

- severity: Medium
  category: correctness.logic
  file: pkg/blockcontroller/blockcontroller.go
  line: 583
  title: Local shells with cmd:nowsh ignore term:localshellpath and the settings shell path
  evidence: |
    func (union *ConnUnion) getRemoteInfoAndShellType(blockMeta waveobj.MetaMapType) error {
        if !union.WshEnabled {
            return nil
        }
    ...
    cmdOpts.ShellPath = connUnion.ShellPath
  evidence_refs: [pkg/blockcontroller/blockcontroller.go:401, pkg/shellexec/shellexec.go:473]
  impact: For a local block with cmd:nowsh=true, union.ShellPath stays "". StartLocalShellProc then falls back to DetectLocalShellPath(), ignoring the block's `term:localshellpath` and `settings.TermLocalShellPath`. The old code applied both regardless of nowsh. ShellType also stays "", so only the generic `cmd:initscript` key is used.
  remedy: Resolve the local shell path and shell type before the WshEnabled early-return, or call getLocalShellPath(blockMeta) directly in the local branch.
  confidence: high
  overlap_hints: []

- severity: Medium
  category: correctness.logic
  file: pkg/blockcontroller/blockcontroller.go
  line: 544
  title: The SSH branch ignores cmd:nowsh because it checks conn.WshEnabled instead of connUnion.WshEnabled
  evidence: |
    } else if connUnion.ConnType == ConnType_Ssh {
        conn := connUnion.SshConn
        if !conn.WshEnabled.Load() {
  evidence_refs: [pkg/blockcontroller/blockcontroller.go:451, pkg/blockcontroller/blockcontroller.go:515]
  impact: When an SSH block sets cmd:nowsh=true on a wsh-enabled connection, connUnion.WshEnabled is false. So the shell type is never resolved and the logs say wshEnabled=false. But the branch still takes the wsh path: it mints a JWT, puts it in the swap token and calls StartRemoteShellProc. The nowsh flag has no effect on SSH, while the WSL branch honours it. This is the "fix some nowsh flags" intent, applied to only one branch.
  remedy: Use `if !connUnion.WshEnabled {` to match the WSL and local branches.
  confidence: high
  overlap_hints: []

- severity: Medium
  category: correctness.logic
  file: pkg/blockcontroller/blockcontroller.go
  line: 412
  title: The init-script shell type comes from remoteInfo.Shell, but the launched shell can be conn:shellpath
  evidence: |
    // TODO allow overriding remote shell path
    union.ShellPath = remoteInfo.Shell
    ...
    token.ScriptText = getCustomInitScript(blockMeta, remoteName, shellType)
  evidence_refs: [pkg/shellexec/shellexec.go:340, pkg/shellexec/shellexec.go:188]
  impact: StartRemoteShellProc / StartWslShellProc pick the actual shell path in this order: cmdOpts.ShellPath, then conn:shellpath (GetConfigShellPath), then remoteInfo.Shell. Take a connection with conn:shellpath=/usr/bin/fish on a host whose login shell is bash. The token carries `cmd:initscript.bash` text, which the fish rc then sources through `wsh token ... fish | source`. The same mismatch happens for pwsh. The result is the wrong script, or syntax errors at shell startup.
  remedy: Resolve ShellPath for SSH/WSL with the same precedence as shellexec (conn:shellpath first, then remoteInfo.Shell), and pass the resolved path through cmdOpts.ShellPath so both sides agree.
  confidence: medium
  overlap_hints: []

- severity: Low
  category: correctness.logic
  file: pkg/blockcontroller/blockcontroller.go
  line: 354
  title: The resolved env overrides WAVETERM_* identity vars, and resolveEnvMap ignores the connection override
  evidence: |
    token.Env["WAVETERM_CONN"] = remoteName
    envMap, err := resolveEnvMap(bc.BlockId, blockMeta, remoteName)
    ...
    for k, v := range envMap {
        token.Env[k] = v
    }
  evidence_refs: [pkg/waveobj/wtypemeta.go:53, cmd/wsh/cmd/wshcmd-run.go:97]
  impact: |
    Two problems with the same env map:
    - The `env` file from `wsh run` is the caller's full os.Environ(). It includes the parent block's WAVETERM_BLOCKID, WAVETERM_TABID and WAVETERM_CONN, which silently replace the new block's identity vars whenever the token is redeemed. A cmd:env with those keys does the same.
    - resolveEnvMap takes `connName` but never uses it. `[conn]`-nested `cmd:env` (and `cmd:cwd`) overrides are not applied, even though the wtypemeta comment says "these can be nested under \"[conn]\"". Only getCustomInitScript honours GetConnectionOverride.
  remedy: Merge envMap before the WAVETERM_* keys, or skip reserved keys. In resolveEnvMap, apply `blockMeta.GetConnectionOverride(connName)`'s cmd:env after the base map, and do the same for cmd:cwd.
  confidence: medium
  overlap_hints: [spec]

## Files examined
examined: [cmd/wsh/cmd/wshcmd-run.go, frontend/types/gotypes.d.ts, pkg/blockcontroller/blockcontroller.go, pkg/remote/conncontroller/conncontroller.go, pkg/shellexec/shellexec.go, pkg/util/shellutil/shellutil.go, pkg/wavebase/wavebase.go, pkg/waveobj/metaconsts.go, pkg/waveobj/metamap.go, pkg/waveobj/wtypemeta.go, pkg/wshrpc/wshserver/wshserver.go, pkg/wshutil/wshutil.go, pkg/wslconn/wslconn.go]
not_examined: []
