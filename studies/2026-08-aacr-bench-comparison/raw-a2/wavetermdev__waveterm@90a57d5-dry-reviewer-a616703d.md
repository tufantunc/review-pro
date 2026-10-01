<!-- wavetermdev__waveterm@90a57d5 dry-reviewer; verbatim final answer -->
- severity: Medium
  category: dry.copy-paste
  file: pkg/blockcontroller/blockcontroller.go
  line: 523
  title: The JWT/swaptoken setup block appears three times in setupAndStartShellProcess (wsl, ssh, local), and the copies have already drifted
  evidence: |
    sockName := wslConn.GetDomainSocketName()
    rpcContext := wshrpc.RpcContext{TabId: bc.TabId, BlockId: bc.BlockId, Conn: wslConn.GetName()}
    jwtStr, err := wshutil.MakeClientJWTToken(rpcContext, sockName)
    if err != nil {
        return nil, fmt.Errorf("error making jwt token: %w", err)
    }
    swapToken.SockName = sockName
    swapToken.RpcContext = &rpcContext
    swapToken.Env[wshutil.WaveJwtTokenVarName] = jwtStr
  evidence_refs: [pkg/blockcontroller/blockcontroller.go:552, pkg/blockcontroller/blockcontroller.go:575, pkg/blockcontroller/blockcontroller.go:544, pkg/blockcontroller/blockcontroller.go:451]
  impact: The three copies differ only in the sockName source and the RpcContext.Conn value. They are already drifting. The wsl and local branches check the new `connUnion.WshEnabled`, which includes `cmd:nowsh`. The ssh branch still checks `conn.WshEnabled.Load()` (line 544), so the `cmd:nowsh` value computed at line 451 is ignored for ssh.
  remedy: This diff adds ConnUnion, which already carries the per-type data. Add one method such as `(union *ConnUnion) setupWshSwapToken(bc, swapToken) error` that picks sockName/Conn by ConnType (`WslConn.GetDomainSocketName()/GetName()`, `SshConn.GetDomainSocketName()/Opts.String()`, `wavebase.GetDomainSocketName()`/""), then call it once when `connUnion.WshEnabled` is true, before branching on ConnType. Make every branch check `connUnion.WshEnabled`.
  confidence: high
  overlap_hints: [craft.code-judo, correctness.logic]

- severity: Medium
  category: dry.duplication
  file: pkg/blockcontroller/blockcontroller.go
  line: 423
  title: getConnUnion repeats the wsl/ssh lookup and "connected" check that CheckConnStatus in the same file already does
  evidence: |
    if strings.HasPrefix(remoteName, "wsl://") {
        wslName := strings.TrimPrefix(remoteName, "wsl://")
        wslConn := wslconn.GetWslConn(wslName)
        ...
        connStatus := wslConn.DeriveConnStatus()
        if connStatus.Status != conncontroller.Status_Connected {
    ...
    } else if remoteName != "" {
        opts, err := remote.ParseOpts(remoteName)
        ...
        conn := conncontroller.GetConn(opts)
        ...
        connStatus := conn.DeriveConnStatus()
        if connStatus.Status != conncontroller.Status_Connected {
  evidence_refs: [pkg/blockcontroller/blockcontroller.go:874, pkg/blockcontroller/blockcontroller.go:883, pkg/wshrpc/wshserver/wshserver.go:643, pkg/wshrpc/wshserver/wshserver.go:666, pkg/wshrpc/wshserver/wshserver.go:689, pkg/wshrpc/wshserver/wshserver.go:786]
  impact: CheckConnStatus (blockcontroller.go:864-891) runs the same "wsl:// prefix -> GetWslConn -> DeriveConnStatus, else ParseOpts -> GetConn -> DeriveConnStatus" sequence, and the two copies already behave differently. getConnUnion nil-checks both conns. CheckConnStatus nil-checks neither and would panic on an unknown conn. The `"wsl://"` HasPrefix/TrimPrefix literal now has 7 copies across blockcontroller.go and wshserver.go.
  remedy: Pull the lookup and status check out of getConnUnion into a shared helper, e.g. `resolveConn(connName) (connType, *SSHConn, *WslConn, error)`. Have CheckConnStatus call it instead of keeping its own copy. At minimum, add a `wslconn` prefix constant or `ParseWslConnName(name) (distro string, ok bool)` and use it at every call site listed above.
  confidence: high
  overlap_hints: [craft.abstraction, correctness.nil-deref]

- severity: Low
  category: dry.canonical-helper
  file: pkg/blockcontroller/blockcontroller.go
  line: 219
  title: The init-script cascade compares against shell-type string literals instead of the shellutil.ShellType_* constants
  evidence: |
    if shellType == "bash" {
    ...
    if shellType == "zsh" {
    ...
    if shellType == "pwsh" {
    ...
    if shellType == "fish" {
  evidence_refs: [pkg/util/shellutil/shellutil.go:36, pkg/util/shellutil/tokenswap.go:141]
  impact: shellType comes from `shellutil.GetShellTypeFromShellPath` (shellutil.go:425), which returns `ShellType_bash/zsh/fish/pwsh`. If a constant's value changes (e.g. "pwsh" becomes "powershell"), the init-script cascade silently falls back to the generic key.
  remedy: Use `switch shellType { case shellutil.ShellType_bash: ... }`, following the existing pattern in `shellutil.EncodeEnvVarsForShell` (tokenswap.go:140-149).
  confidence: high
  overlap_hints: [ai-antipatterns.ignored-convention]

- severity: Low
  category: dry.copy-paste
  file: pkg/wslconn/wslconn.go
  line: 120
  title: The new WslConn.Debugf copies the Infof body (blocklogger.Infof) instead of mirroring the canonical SSHConn.Debugf
  evidence: |
    func (conn *WslConn) Debugf(ctx context.Context, format string, args ...any) {
        blocklogger.Infof(ctx, "[conndebug] "+format, args...)
    }
  evidence_refs: [pkg/remote/conncontroller/conncontroller.go:125, pkg/wslconn/wslconn.go:115]
  impact: The equivalent method, SSHConn.Debugf (conncontroller.go:125-127), calls `blocklogger.Debugf`. The WSL copy logs at info level, so the packed swaptoken (a credential-bearing value) logged at shellexec.go:262 appears at info level for WSL but only at debug level for SSH.
  remedy: Match conncontroller.go:126 by using `blocklogger.Debugf(ctx, "[conndebug] "+format, args...)`.
  confidence: high
  overlap_hints: [correctness.logic, security.secret-leak]

- severity: Low
  category: dry.copy-paste
  file: pkg/shellexec/shellexec.go
  line: 258
  title: The swaptoken pack-and-prepend block added to StartWslShellProc is a verbatim copy of the one in StartRemoteShellProc
  evidence: |
    packedToken, err := cmdOpts.SwapToken.PackForClient()
    if err != nil {
        conn.Infof(ctx, "error packing swap token: %v", err)
    } else {
        conn.Debugf(ctx, "packed swaptoken %s\n", packedToken)
        cmdCombined = fmt.Sprintf(`%s=%s %s`, wavebase.WaveSwapTokenVarName, packedToken, cmdCombined)
    }
  evidence_refs: [pkg/shellexec/shellexec.go:432]
  impact: The two sh-style remote launchers now each have their own copy of the token-injection logic (a third, env-based variant is at shellexec.go:512). Any change to the packing or quoting format has to be made in both places.
  remedy: Extract a small helper such as `prependSwapToken(logf, debugf, swapToken, cmdCombined) string`, or one taking a `{Infof, Debugf}` interface that both WslConn and SSHConn satisfy. Call it from shellexec.go:258 and :432.
  confidence: medium
  overlap_hints: [craft.abstraction]

## Files examined
examined: [cmd/wsh/cmd/wshcmd-run.go, frontend/types/gotypes.d.ts, pkg/blockcontroller/blockcontroller.go, pkg/remote/conncontroller/conncontroller.go, pkg/shellexec/shellexec.go, pkg/util/shellutil/shellutil.go, pkg/wavebase/wavebase.go, pkg/waveobj/metaconsts.go, pkg/waveobj/metamap.go, pkg/waveobj/wtypemeta.go, pkg/wshrpc/wshserver/wshserver.go, pkg/wshutil/wshutil.go, pkg/wslconn/wslconn.go]
not_examined: []
