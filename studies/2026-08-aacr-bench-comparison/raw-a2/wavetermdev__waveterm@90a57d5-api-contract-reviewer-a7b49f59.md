<!-- wavetermdev__waveterm@90a57d5 api-contract-reviewer; verbatim final answer -->
I found 4 API-contract findings. The most serious one breaks existing behaviour: shell commands no longer receive their environment variables, and `waveapp` programs fail to start.

- severity: High
  category: api-contract.breaking
  file: pkg/shellexec/shellexec.go
  line: 512
  title: Env and JWT now reach the process only through the swap token, so commands run via `-c` get neither
  evidence: |
    // removed from StartLocalShellProc:
    -	shellutil.UpdateCmdEnv(ecmd, cmdOpts.Env)
    // removed from StartRemoteShellProc:
    -	for envKey, envVal := range cmdOpts.Env { session.Setenv(envKey, envVal) }
    // removed from blockcontroller (each conn branch):
    -			cmdOpts.Env[wshutil.WaveJwtTokenVarName] = jwtStr
    // the only remaining channel (blockcontroller.go:354-361):
    	envMap, err := resolveEnvMap(bc.BlockId, blockMeta, remoteName)
    	for k, v := range envMap { token.Env[k] = v }
    // and the swap token is only redeemed by rc-file integration (shellutil.go:60,116,144,156):
    eval "$(wsh token "$WAVETERM_SWAPTOKEN" bash 2> /dev/null)"
    // but for cmd blocks the rc files are never loaded (shellexec.go:506-510):
    	} else {
    		shellOpts = append(shellOpts, "-c", cmdStr)
    		ecmd = exec.Command(shellPath, shellOpts...)
  evidence_refs: [pkg/blockcontroller/blockcontroller.go:354, pkg/util/shellutil/shellutil.go:116, cmd/wsh/cmd/wshcmd-run.go:140, pkg/waveapp/waveapp.go:162, docs/docs/customwidgets.mdx:107, cmd/wsh/cmd/wshcmd-token.go:40]
  impact: |
    Before this change, three things went straight into the process environment: the `cmd:env` meta key, the "env" block file, and WAVETERM_JWT. Now they are only put into the swap token, and only the `--rcfile`/ZDOTDIR/`-C`/`-File` integration scripts redeem it. Those scripts only run when `cmdStr == ""`. Blocks with the "cmd" controller run `sh -c cmdStr`, which loads no rc file. Consumers that break:
    (1) `cmd/wsh/cmd/wshcmd-run.go:140` writes the caller's environment into the `wavebase.BlockFile_Env` file. `wsh run` commands no longer receive it.
    (2) `cmd:env` is documented as working locally (`docs/docs/customwidgets.mdx:107`). Custom widgets that set it no longer get the variables.
    (3) `pkg/waveapp/waveapp.go:162` returns "no WAVETERM_JWT env var set" when the JWT is missing, so waveapp/vdom programs launched as cmd blocks fail to connect.
    (4) Local shells with `cmd:nowsh`: the swap token gets no SockName (it is set only in the wsh branch), so `wsh token` in the rc file cannot set up its RPC client. The `cmd:env` values that `UpdateCmdEnv` used to apply are lost.
  remedy: For the cmd controller and for no-wsh shells, keep putting the resolved env (and the JWT when wsh is enabled) directly on the process. Locally that means `UpdateCmdEnv`; for SSH/WSL it means an env prefix in `cmdCombined`. Use the swap token only where an integration rc file will redeem it. Alternatively, keep `CommandOptsType.Env` for the `cmdStr != ""` path.
  confidence: high
  overlap_hints: [correctness.broken-functionality, backend.service-boundary]

- severity: Medium
  category: api-contract.breaking
  file: pkg/blockcontroller/blockcontroller.go
  line: 544
  title: SSH branch ignores `cmd:nowsh` (it uses `conn.WshEnabled` instead of `connUnion.WshEnabled`)
  evidence: |
    		rtn.WshEnabled = wshEnabled && conn.WshEnabled.Load()   // getConnUnion computes it
    ...
    	} else if connUnion.ConnType == ConnType_Ssh {
    		conn := connUnion.SshConn
    		if !conn.WshEnabled.Load() {
    			shellProc, err = shellexec.StartRemoteShellProcNoWsh(...)
    		} else {
    			...
    			swapToken.Env[wshutil.WaveJwtTokenVarName] = jwtStr
  impact: The WSL branch (`if !connUnion.WshEnabled`) and the local branch (`if connUnion.WshEnabled`) both honour `cmd:nowsh`; the SSH branch does not. On an SSH connection with wsh installed, a block with `"cmd:nowsh": true` now starts the wsh shell and gets a JWT minted into its swap token. Before this change it at least withheld the JWT (`if !blockMeta.GetBool(MetaKey_CmdNoWsh)`). So the SSH path no longer follows the documented meta key, and the three connection types disagree on what it means.
  remedy: In the SSH branch, test `connUnion.WshEnabled` as the other two branches do.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: api-contract.schema
  file: pkg/waveobj/wtypemeta.go
  line: 54
  title: The "[conn]" nested override is declared in the schema comment, but the generated type can't express it and `cmd:env`/`cmd:cwd` ignore it
  evidence: |
    	// these can be nested under "[conn]"
    	CmdEnv            map[string]string `json:"cmd:env,omitempty"`
    	CmdCwd            string            `json:"cmd:cwd,omitempty"`
    ...
    func resolveEnvMap(blockId string, blockMeta waveobj.MetaMapType, connName string) (map[string]string, error) {
    	...
    	cmdEnv := blockMeta.GetMap(waveobj.MetaKey_CmdEnv)   // connName never used
  evidence_refs: [pkg/blockcontroller/blockcontroller.go:252, pkg/blockcontroller/blockcontroller.go:286, pkg/waveobj/metamap.go:22, frontend/types/gotypes.d.ts:449]
  impact: |
    - `GetConnectionOverride` reads a top-level key `"[<connName>]"` holding a nested map. The generated TS `MetaType` (`frontend/types/gotypes.d.ts:449`) has no index signature or field for this, so frontend code cannot write it without a cast.
    - Of the keys the comment says can be nested, only `cmd:initscript.*` reads the override (`getCustomInitScript`). `resolveEnvMap` takes `connName` but never uses it, and `createCmdStrAndOpts` and the shell path read `cmd:cwd` only from the top level.
    - Result: nested `cmd:env`/`cmd:cwd` are silently ignored, contrary to the declared schema.
    - No frontend writer exists yet, so the impact is limited.
  remedy: Either apply `GetConnectionOverride` to `cmd:env` and `cmd:cwd` too (merging the override over the top level in `resolveEnvMap` and in the cwd lookup), or narrow the comment to the initscript keys. Also teach tsgen to emit a `[key: \`[${string}]\`]: MetaType`-style entry (or document the key shape).
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: api-contract.schema
  file: pkg/waveobj/wtypemeta.go
  line: 52
  title: The new `cmd:allowconnchange` key is advertised but read nowhere
  evidence: |
    	CmdAllowConnChange  bool     `json:"cmd:allowconnchange,omitempty"`
    // metaconsts.go:
    	MetaKey_CmdAllowConnChange               = "cmd:allowconnchange"
  impact: The key is exported to the generated `MetaType` (`"cmd:allowconnchange"?: boolean`) and to `MetaKey_CmdAllowConnChange`. A search of pkg/, cmd/ and frontend/ finds no reader, so setting it does nothing. Users and frontend code relying on the published type get no effect.
  remedy: Implement the behaviour in this change, or leave the key out of `MetaTSType` until it is.
  confidence: high
  overlap_hints: [ai-antipatterns.invented-config, spec.unrequested]

Checked with no finding:
- **Moved `BlockFile_*` constants:** no Go code still uses `blockcontroller.BlockFile_*`.
- **`GetConn`/`GetWslConn` signatures:** every caller is updated. The old `connFlags` argument was already unused. `ConnConnectCommand` still passes `connRequest.Keywords` to `conn.Connect`. No caller in the base passed `shouldConnect=true`.
- **`ScriptText`:** it is carried through `pkg/wshutil/wshproxy.go:97` into `InitScriptText`, which `wshcmd-token.go:44` prints.
- **Generated files:** `metaconsts.go` and `gotypes.d.ts` match `wtypemeta.go`.
- **Build:** I was not allowed to run `go build`, so compile correctness was checked by searching only.

## Files examined
examined: [cmd/wsh/cmd/wshcmd-run.go, frontend/types/gotypes.d.ts, pkg/blockcontroller/blockcontroller.go, pkg/remote/conncontroller/conncontroller.go, pkg/shellexec/shellexec.go, pkg/util/shellutil/shellutil.go, pkg/wavebase/wavebase.go, pkg/waveobj/metaconsts.go, pkg/waveobj/metamap.go, pkg/waveobj/wtypemeta.go, pkg/wshrpc/wshserver/wshserver.go, pkg/wshutil/wshutil.go, pkg/wslconn/wslconn.go]
not_examined: []
