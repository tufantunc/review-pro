<!-- wavetermdev__waveterm@90a57d5 craft-reviewer; verbatim final answer -->
## Craft findings

- severity: High
  category: craft.size
  file: pkg/blockcontroller/blockcontroller.go
  line: 365
  title: This PR takes blockcontroller.go from 960 to 1068 lines by putting connection resolution inside the block lifecycle file
  evidence: |
    $ git show 900f4a3f:pkg/blockcontroller/blockcontroller.go | wc -l  -> 960
    $ wc -l pkg/blockcontroller/blockcontroller.go                      -> 1068
    +type ConnUnion struct { ... }
    +func getLocalShellPath(blockMeta waveobj.MetaMapType) string {
    +func getLocalShellOpts(blockMeta waveobj.MetaMapType) []string {
    +func (union *ConnUnion) getRemoteInfoAndShellType(blockMeta waveobj.MetaMapType) error {
    +func (bc *BlockController) getConnUnion(logCtx context.Context, remoteName string, blockMeta waveobj.MetaMapType) (ConnUnion, error) {
    +func getCustomInitScriptKeyCascade(shellType string) []string {
    +func getCustomInitScript(meta waveobj.MetaMapType, connName string, shellType string) string {
    +func resolveEnvMap(blockId string, blockMeta waveobj.MetaMapType, connName string) (map[string]string, error) {
  impact: blockcontroller.go already mixed block file I/O, pty management, input routing and controller registry. It now also handles connection-type dispatch, shell detection, env resolution and the init-script cascade. It is the file every connection or shell feature will now have to edit.
  remedy: Move the new ConnUnion code (the type, getConnUnion, getRemoteInfoAndShellType, getLocalShellPath/Opts) into pkg/blockcontroller/connunion.go. Move the env/initscript resolution (resolveEnvMap, getCustomInitScript*, makeSwapToken) into pkg/blockcontroller/swaptoken.go. That puts the file back under 1k and gives each concern its own home.
  confidence: high
  overlap_hints: []

- severity: High
  category: craft.code-judo
  file: pkg/blockcontroller/blockcontroller.go
  line: 513
  title: ConnUnion is built but setupAndStartShellProcess still branches three ways with nearly identical copies of the JWT and swap-token code
  evidence: |
    if connUnion.ConnType == ConnType_Wsl {
        ...
            sockName := wslConn.GetDomainSocketName()
            rpcContext := wshrpc.RpcContext{TabId: bc.TabId, BlockId: bc.BlockId, Conn: wslConn.GetName()}
            jwtStr, err := wshutil.MakeClientJWTToken(rpcContext, sockName)
            ...
            swapToken.SockName = sockName
            swapToken.RpcContext = &rpcContext
            swapToken.Env[wshutil.WaveJwtTokenVarName] = jwtStr
    } else if connUnion.ConnType == ConnType_Ssh {
        ...  (same 9 lines, conn.GetDomainSocketName(), Conn: conn.Opts.String())
    } else if connUnion.ConnType == ConnType_Local {
        if connUnion.WshEnabled {
            ...  (same 9 lines, wavebase.GetDomainSocketName())
  impact: The union adds a new type and a new resolution step, yet the busiest function in the file keeps its three-branch structure and all three copies of the JWT block. The union mostly adds indirection. The branches already drift apart: the SSH branch checks `conn.WshEnabled.Load()` where the WSL and local branches check `connUnion.WshEnabled`, so `cmd:nowsh` is dropped for SSH.
  remedy: |
    Let the union own the per-type differences so the branching disappears from the caller:
    1. Add `connUnion.sockName()` and `connUnion.rpcConnName()`. Then do the JWT/swap-token setup once, before dispatch, when `connUnion.WshEnabled` is true. That deletes two of the three copies.
    2. Give the union a single start step (or a map from ConnType to start/noWsh-fallback functions). setupAndStartShellProcess then becomes: resolve union, build token, start. Each branch is then just a start call plus its fallback, and every branch uses `connUnion.WshEnabled`.
  confidence: high
  overlap_hints: [dry.duplication, correctness.logic]

- severity: Medium
  category: craft.abstraction
  file: pkg/blockcontroller/blockcontroller.go
  line: 365
  title: ConnUnion is a stringly-tagged struct with a field that is never set and a method that does not use its receiver
  evidence: |
    type ConnUnion struct {
        ConnName   string
        ConnType   string
        SshConn    *conncontroller.SSHConn
        WslConn    *wslconn.WslConn
        WshEnabled bool
        ShellPath  string
        ShellOpts  []string   // never assigned anywhere
        ShellType  string
    }
    ...
    func (bc *BlockController) getConnUnion(logCtx context.Context, remoteName string, blockMeta waveobj.MetaMapType) (ConnUnion, error) {
    ...
        cmdOpts.ShellOpts = getLocalShellOpts(blockMeta)   // read directly, bypassing union.ShellOpts
  impact: The union's invariant (exactly one of SshConn/WslConn is set, as selected by ConnType) exists only by convention. A reader has to guess whether `union.ShellOpts` is meaningful; it never is. getConnUnion is a method on `bc` and takes `logCtx`, but uses neither, so its signature implies dependencies it does not have.
  remedy: Set ShellOpts inside getRemoteInfoAndShellType for the local case and read `connUnion.ShellOpts` at the call site, or delete the field. Make getConnUnion a plain function without `bc` or `logCtx`. Give ConnType a named type (`type ConnType string`) so the final `else` "unknown connection type" branch is not needed as a guard against arbitrary strings.
  confidence: high
  overlap_hints: [api-contract.type-safety]

- severity: Medium
  category: craft.code-judo
  file: pkg/blockcontroller/blockcontroller.go
  line: 873
  title: CheckConnStatus repeats the wsl/ssh lookup and status check that getConnUnion now does
  evidence: |
    // getConnUnion (new)
    if strings.HasPrefix(remoteName, "wsl://") {
        wslName := strings.TrimPrefix(remoteName, "wsl://")
        wslConn := wslconn.GetWslConn(wslName)
        ...
        connStatus := wslConn.DeriveConnStatus()
        if connStatus.Status != conncontroller.Status_Connected {
    // CheckConnStatus (same file, line ~873)
    if strings.HasPrefix(connName, "wsl://") {
        distroName := strings.TrimPrefix(connName, "wsl://")
        conn := wslconn.GetWslConn(distroName)
        connStatus := conn.DeriveConnStatus()
        if connStatus.Status != conncontroller.Status_Connected {
  impact: The same file now contains two lookups for "resolve a conn name and check it is connected". The prefix check appears 11 times across pkg. This PR created the central lookup but left the older copy next to it, so the two will drift. They already differ on nil handling and error text.
  remedy: Extract the lookup and status check from getConnUnion into `resolveConn(connName) (ConnUnion, error)` without the shell-info step, and make CheckConnStatus a one-line call to it. A later change can move the helper next to the conn packages so the wshserver handlers can use it too.
  confidence: high
  overlap_hints: [dry.duplication]

- severity: Medium
  category: craft.abstraction
  file: pkg/blockcontroller/blockcontroller.go
  line: 286
  title: Unused parameters in resolveEnvMap and createCmdStrAndOpts suggest per-connection behaviour that does not exist
  evidence: |
    func resolveEnvMap(blockId string, blockMeta waveobj.MetaMapType, connName string) (map[string]string, error) {
        // connName never referenced; cmd:env is read only from top-level blockMeta
    func createCmdStrAndOpts(blockId string, blockMeta waveobj.MetaMapType, connName string) (string, *shellexec.CommandOptsType, error) {
        // neither blockId nor connName referenced (the env-file read moved out)
    // wtypemeta.go
    // these can be nested under "[conn]"
    CmdEnv            map[string]string `json:"cmd:env,omitempty"`
    CmdCwd            string            `json:"cmd:cwd,omitempty"`
  impact: The signatures and the wtypemeta comment say cmd:env and cmd:cwd honour `[conn]` overrides. Only getCustomInitScript calls GetConnectionOverride. Someone maintaining this will reasonably think the override already works for env and cwd.
  remedy: Either apply `blockMeta.GetConnectionOverride(connName)` in resolveEnvMap and in the cwd lookup, using the same override-then-base cascade getCustomInitScript uses (pulled into a shared `getMetaWithConnOverride` helper), or drop the unused `connName`/`blockId` parameters and fix the "[conn]" comment so it lists only the keys that honour it.
  confidence: high
  overlap_hints: [spec.partial, correctness.logic]

- severity: Medium
  category: craft.spaghetti
  file: pkg/shellexec/shellexec.go
  line: 258
  title: The WSL path adds a third copy of the pack-and-log swap-token block
  evidence: |
    packedToken, err := cmdOpts.SwapToken.PackForClient()
    if err != nil {
        conn.Infof(ctx, "error packing swap token: %v", err)
    } else {
        conn.Debugf(ctx, "packed swaptoken %s\n", packedToken)
        cmdCombined = fmt.Sprintf(`%s=%s %s`, wavebase.WaveSwapTokenVarName, packedToken, cmdCombined)
    }
    // identical block at shellexec.go:432 (remote) and a variant at :512 (local)
  impact: Each start path hand-rolls token packing, logging and command prefixing. The copies already differ in logger (conn vs blocklogger) and in how the token is injected, so a later change to the token format or its logging needs three edits.
  remedy: Add `shellutil.(*TokenSwapEntry).EnvAssignment() (string, error)`, or a shellexec helper `prefixSwapToken(cmdStr, token) string`, and call it from the WSL and SSH paths. The local path can use the same pack call plus UpdateCmdEnv.
  confidence: high
  overlap_hints: [dry.duplication, security.secret-leak]

- severity: Low
  category: craft.abstraction
  file: pkg/blockcontroller/blockcontroller.go
  line: 218
  title: The init-script cascade hard-codes shell-type strings instead of using shellutil.ShellType_* constants
  evidence: |
    if shellType == "bash" {
        return []string{waveobj.MetaKey_CmdInitScriptBash, waveobj.MetaKey_CmdInitScriptSh, waveobj.MetaKey_CmdInitScript}
    }
    if shellType == "zsh" {
    ...
    // pkg/util/shellutil/shellutil.go:36
    ShellType_bash    = "bash"
    ShellType_zsh     = "zsh"
  impact: The value comes from shellutil.GetShellTypeFromShellPath, which returns shellutil constants, but it is compared to literals. If a constant is renamed, the cascade silently falls through to the generic script.
  remedy: Replace the if-chain with a package-level `map[string][]string` keyed by `shellutil.ShellType_bash` and the other constants, with the generic key as the default.
  confidence: high
  overlap_hints: []

- severity: Low
  category: craft.abstraction
  file: pkg/wslconn/wslconn.go
  line: 120
  title: WslConn.Debugf logs at Info level, unlike SSHConn.Debugf; GetConn and GetWslConn are now pass-through wrappers
  evidence: |
    func (conn *WslConn) Debugf(ctx context.Context, format string, args ...any) {
        blocklogger.Infof(ctx, "[conndebug] "+format, args...)
    }
    // conncontroller.go:125
    func (conn *SSHConn) Debugf(ctx context.Context, format string, args ...any) {
        blocklogger.Debugf(ctx, "[conndebug] "+format, args...)
    }
    // conncontroller.go:814
    // does NOT connect, can return nil if connection does not exist
    func GetConn(opts *remote.SSHOpts) *SSHConn {
        conn := getConnInternal(opts)
        return conn
    }
  impact: The copied Debugf means WSL writes the packed swap token (which carries the JWT) to the block log at Info level, while SSH keeps it at Debug. With the parameters removed, GetConn and GetWslConn are identity wrappers around getConnInternal. Their comment ("can return nil") is also stale, because getConnInternal always creates the conn. That leaves every `if conn == nil` check in wshserver and getConnUnion as dead code.
  remedy: Make WslConn.Debugf call blocklogger.Debugf. Rename getConnInternal to GetConn / GetWslConn (or inline it), fix the comment, and delete the unreachable nil checks.
  confidence: high
  overlap_hints: [security.secret-leak, dry.duplication]

## Files examined
examined: [cmd/wsh/cmd/wshcmd-run.go, frontend/types/gotypes.d.ts, pkg/blockcontroller/blockcontroller.go, pkg/remote/conncontroller/conncontroller.go, pkg/shellexec/shellexec.go, pkg/util/shellutil/shellutil.go, pkg/wavebase/wavebase.go, pkg/waveobj/metaconsts.go, pkg/waveobj/metamap.go, pkg/waveobj/wtypemeta.go, pkg/wshrpc/wshserver/wshserver.go, pkg/wshutil/wshutil.go, pkg/wslconn/wslconn.go]
not_examined: []
