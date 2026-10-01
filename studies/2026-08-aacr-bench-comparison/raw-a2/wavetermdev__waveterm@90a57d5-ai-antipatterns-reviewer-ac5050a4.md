<!-- wavetermdev__waveterm@90a57d5 ai-antipatterns-reviewer; verbatim final answer -->
- severity: Medium
  category: ai-antipatterns.invented-config
  file: pkg/waveobj/metaconsts.go
  line: 53
  title: New `cmd:allowconnchange` meta key is declared and exported to TS but never read
  evidence: |
    MetaKey_CmdAllowConnChange               = "cmd:allowconnchange"
    // wtypemeta.go:52
    CmdAllowConnChange  bool     `json:"cmd:allowconnchange,omitempty"`
    // frontend/types/gotypes.d.ts:483
    "cmd:allowconnchange"?: boolean;
  evidence_refs: [pkg/waveobj/wtypemeta.go:52, frontend/types/gotypes.d.ts:483]
  impact: I searched the whole repo for `allowconnchange` and `AllowConnChange`. The only hits are these three declarations. No Go code (blockcontroller, wshserver, conncontroller) and no frontend code reads the key. It is now part of the public block-meta schema, so users or the UI can set it and nothing will happen. The name also suggests a connection-change guard that does not exist.
  remedy: Drop the constant, the struct field and the regenerated TS field until a consumer exists. Otherwise add the code that enforces it, for example in the conn-change path next to `CheckConnStatus` in blockcontroller.go.
  confidence: high
  overlap_hints: [spec.unrequested-behavior, api-contract.schema-drift]

- severity: Medium
  category: ai-antipatterns.over-engineering
  file: pkg/blockcontroller/blockcontroller.go
  line: 252
  title: `connName` params added to resolveEnvMap/createCmdStrAndOpts are never used, while the schema comment says cmd:env/cmd:cwd can be nested under "[conn]"
  evidence: |
    func resolveEnvMap(blockId string, blockMeta waveobj.MetaMapType, connName string) (map[string]string, error) {
    ...
        cmdEnv := blockMeta.GetMap(waveobj.MetaKey_CmdEnv)
    // line 286
    func createCmdStrAndOpts(blockId string, blockMeta waveobj.MetaMapType, connName string) (string, *shellexec.CommandOptsType, error) {
    ...
        cmdOpts.Cwd = blockMeta.GetString(waveobj.MetaKey_CmdCwd, "")
    // pkg/waveobj/wtypemeta.go:54
    // these can be nested under "[conn]"
    CmdEnv            map[string]string `json:"cmd:env,omitempty"`
    CmdCwd            string            `json:"cmd:cwd,omitempty"`
  evidence_refs: [pkg/blockcontroller/blockcontroller.go:286, pkg/waveobj/wtypemeta.go:54, pkg/waveobj/metamap.go:22]
  impact: Both functions take `connName` and ignore it. `resolveEnvMap` reads only the top-level `cmd:env` and `createCmdStrAndOpts` reads only the top-level `cmd:cwd`. The new `MetaMapType.GetConnectionOverride` has one caller, `getCustomInitScript` at line 236. The comment in wtypemeta.go says env and cwd honour per-connection overrides, but the code does not, so `"[conn]": {"cmd:env": ...}` is silently ignored. The parameters exist only for a future use that was never written.
  remedy: Either implement the override (merge `blockMeta.GetConnectionOverride(connName)` for `cmd:env` and `cmd:cwd` the same way `getCustomInitScript` does), or remove the unused `connName` params and limit the comment to the `cmd:initscript*` keys.
  confidence: high
  overlap_hints: [correctness.logic, craft.abstraction]

- severity: Medium
  category: ai-antipatterns.ignored-convention
  file: pkg/wslconn/wslconn.go
  line: 120
  title: New WslConn.Debugf copies Infof and logs at Info level, unlike the SSHConn.Debugf it mirrors
  evidence: |
    func (conn *WslConn) Debugf(ctx context.Context, format string, args ...any) {
    	blocklogger.Infof(ctx, "[conndebug] "+format, args...)
    }
    // existing convention, pkg/remote/conncontroller/conncontroller.go:125
    func (conn *SSHConn) Debugf(ctx context.Context, format string, args ...any) {
    	blocklogger.Debugf(ctx, "[conndebug] "+format, args...)
    }
  evidence_refs: [pkg/remote/conncontroller/conncontroller.go:125, pkg/blocklogger/blocklogger.go:86, pkg/shellexec/shellexec.go:262]
  impact: '`blocklogger.Debugf` exists (blocklogger.go:86) and the SSH counterpart uses it. The only new caller is `conn.Debugf(ctx, "packed swaptoken %s\n", packedToken)` at shellexec.go:262. So on every WSL shell start, the packed swap token is written at Info level to the block''s conndebug log. The token carries the JWT and the env. The SSH and local paths log it at debug level only.'
  remedy: Change the body to `blocklogger.Debugf(ctx, "[conndebug] "+format, args...)` to match `SSHConn.Debugf`.
  confidence: high
  overlap_hints: [security.secret-leak, dry.canonical-helper]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: pkg/blockcontroller/blockcontroller.go
  line: 219
  title: Init-script cascade compares against string literals instead of the shellutil.ShellType_* constants
  evidence: |
    if shellType == "bash" {
    ...
    if shellType == "zsh" {
    ...
    if shellType == "pwsh" {
    ...
    if shellType == "fish" {
  evidence_refs: [pkg/util/shellutil/shellutil.go:36, pkg/util/shellutil/shellutil.go:425, pkg/shellexec/shellexec.go:479]
  impact: '`shellType` comes from `shellutil.GetShellTypeFromShellPath`, which returns `ShellType_bash`, `ShellType_zsh`, `ShellType_fish`, `ShellType_pwsh` and `ShellType_unknown` (shellutil.go:36-40). The rest of the codebase compares against those constants, for example `shellType == shellutil.ShellType_bash` in shellexec.go. The literals match today, but if a constant changes this cascade silently falls through to the generic `cmd:initscript`.'
  remedy: Use `shellutil.ShellType_bash`, `ShellType_zsh`, `ShellType_pwsh` and `ShellType_fish`, ideally in a `switch`.
  confidence: high
  overlap_hints: [craft.canonical-helper]

- severity: Low
  category: ai-antipatterns.over-engineering
  file: pkg/blockcontroller/blockcontroller.go
  line: 372
  title: ConnUnion.ShellOpts is never set or read; getConnUnion has an unused receiver and logCtx
  evidence: |
    type ConnUnion struct {
    	...
    	ShellPath  string
    	ShellOpts  []string
    	ShellType  string
    }
    ...
    func (bc *BlockController) getConnUnion(logCtx context.Context, remoteName string, blockMeta waveobj.MetaMapType) (ConnUnion, error) {
  impact: '`grep ShellOpts pkg/blockcontroller` finds only the field declaration. The local path computes opts separately with `cmdOpts.ShellOpts = getLocalShellOpts(blockMeta)` at line 584. Neither `bc` nor `logCtx` is referenced inside `getConnUnion`. These are placeholder slots for flexibility that nothing uses.'
  remedy: Remove the `ShellOpts` field, or populate it in `getRemoteInfoAndShellType` and read it at line 584. Make `getConnUnion` a plain function without the unused `logCtx`.
  confidence: high
  overlap_hints: [craft.abstraction]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: pkg/blockcontroller/blockcontroller.go
  line: 544
  title: SSH branch re-reads conn.WshEnabled instead of the ConnUnion.WshEnabled the refactor introduced
  evidence: |
    } else if connUnion.ConnType == ConnType_Ssh {
    	conn := connUnion.SshConn
    	if !conn.WshEnabled.Load() {
    // vs WSL branch line 515 / local line 572
    	if !connUnion.WshEnabled {
  impact: '`getConnUnion` computes `rtn.WshEnabled = wshEnabled && conn.WshEnabled.Load()` (line 451) so that `cmd:nowsh` is respected, and the WSL and local branches use that value. The SSH branch skips it. With `cmd:nowsh=true` on SSH, remote info and shell type are skipped (line 401), yet the wsh path still runs: a JWT is created and `StartRemoteShellProc` is called. This inconsistency looks like a partial copy-paste.'
  remedy: Use `if !connUnion.WshEnabled {` at line 544, as the other two branches do.
  confidence: medium
  overlap_hints: [correctness.logic]

## Premise verification
No `### External premises` section was provided. For the record, every symbol in the Related context exists. `shellutil.DetectLocalShellPath` is at shellutil.go:168 and `shellutil.GetShellTypeFromShellPath` at shellutil.go:425. `wshclient.RemoteGetInfoCommand` is at wshclient.go:305 and returns `wshrpc.RemoteInfo`. `wshclient.GetBareRpcClient` is at barerpcclient.go:27 and `wshutil.MakeConnectionRouteId` at wshrouter.go:52. `WslConn.DeriveConnStatus` is at wslconn.go:98 and `conncontroller.Status_Connected` at conncontroller.go:44; both are "connected". `RemoteInfo.Shell` is at wshrpctypes.go:526, `TokenSwapEntry.ScriptText` at tokenswap.go:25 (consumed by wshproxy.go:97) and `wavebase.WaveSwapTokenVarName` at wavebase.go:37. No hallucinated APIs were found.

## Files examined
examined: [cmd/wsh/cmd/wshcmd-run.go, frontend/types/gotypes.d.ts, pkg/blockcontroller/blockcontroller.go, pkg/remote/conncontroller/conncontroller.go, pkg/shellexec/shellexec.go, pkg/util/shellutil/shellutil.go, pkg/wavebase/wavebase.go, pkg/waveobj/metaconsts.go, pkg/waveobj/metamap.go, pkg/waveobj/wtypemeta.go, pkg/wshrpc/wshserver/wshserver.go, pkg/wshutil/wshutil.go, pkg/wslconn/wslconn.go]
not_examined: []
