<!-- wavetermdev__waveterm@90a57d5 tests-reviewer; verbatim final answer -->
- severity: High
  category: tests.coverage
  file: pkg/blockcontroller/blockcontroller.go
  line: 234
  title: The init-script lookup order (per-shell keys, then connection override, then block level) has no tests
  evidence: |
    func getCustomInitScript(meta waveobj.MetaMapType, connName string, shellType string) string {
    	keys := getCustomInitScriptKeyCascade(shellType)
    	connMeta := meta.GetConnectionOverride(connName)
    	if connMeta != nil {
    		for _, key := range keys {
    			if connMeta.HasKey(key) {
    				return connMeta.GetString(key, "")
    ...
    	for _, key := range keys {
    		if meta.HasKey(key) {
    			return meta.GetString(key, "")
  evidence_refs: [pkg/blockcontroller/blockcontroller.go:218, pkg/blockcontroller/blockcontroller.go:361]
  impact: The result becomes `token.ScriptText` (line 361), which is the script injected into every new shell. Several rules here can regress without anyone noticing. (a) bash and zsh fall back to `.sh`, but pwsh and fish skip it. (b) Any connection-override key beats every block-level key, even a more specific block key. For example, a `[conn]` `cmd:initscript` beats a block-level `cmd:initscript.bash`. (c) A key whose value is present but null or non-string stops the lookup and returns "". It does not fall through. (d) An unknown shell type uses only `cmd:initscript`. No `pkg/blockcontroller/*_test.go` exists.
  remedy: Add a table test in `pkg/blockcontroller` (same package, so the unexported functions are reachable), in the style of `pkg/util/shellutil/shellquote_test.go`. Both functions are pure over `MetaMapType`, so no harness is needed. Cases: (1) bash, only `cmd:initscript.sh` set, expect the sh value. (2) bash, both `.bash` and `.sh` set, expect `.bash`. (3) pwsh, only `.sh` set, expect "". (4) `[myhost]` override with `cmd:initscript` plus block-level `cmd:initscript.bash`, connName `myhost`, expect the override value. (5) The same meta with connName `other`, expect the block value. (6) Override present with `cmd:initscript.bash: nil` and block-level `.bash` set, expect "" (pins the "nil stops the lookup" rule). (7) An unknown shell type such as "" or "cmd" hits only `cmd:initscript`.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.coverage
  file: pkg/blockcontroller/blockcontroller.go
  line: 252
  title: resolveEnvMap has no tests for the env-file / cmd:env merge or the new "null value deletes the key" rule
  evidence: |
    cmdEnv := blockMeta.GetMap(waveobj.MetaKey_CmdEnv)
    for k, v := range cmdEnv {
    	if v == nil {
    		delete(rtn, k)
    		continue
    	}
    	if _, ok := v.(string); ok {
    		rtn[k] = v.(string)
    	}
    	if _, ok := v.(float64); ok {
    		rtn[k] = fmt.Sprintf("%v", v)
  evidence_refs: [pkg/filestore/blockstore_dbsetup.go:31, pkg/filestore/blockstore_test.go:23]
  impact: This change adds `delete(rtn, k)` (a null `cmd:env` value now removes a variable that came from the env file). It also makes this map the only way env reaches the process, via the swap token, because `cmdOpts.Env` was removed. Nothing checks that cmd:env beats the env file, that nulls delete, that float64 values are formatted (e.g. `1` becomes "1", not "1.000000"), or that bool and other types are silently dropped. The function reads `filestore.WFS` directly. The in-memory test DB switch `useTestingDb` is unexported in package filestore (blockstore_dbsetup.go:31, used by `initDb` in blockstore_test.go:23), so a test in blockcontroller cannot easily start a filestore.
  remedy: Move the merge into a pure helper, e.g. `mergeEnv(envFileData []byte, cmdEnv map[string]any) map[string]string`, and table-test it. Cases: (1) the env file sets `A=1` and `B=2`, cmd:env has `{"A":"x","B":nil}`, expect `{A:"x"}`. (2) cmd:env has `{"N":float64(3)}`, expect "3". (3) cmd:env has `{"F":true}`, expect F to be absent. (4) Empty env file.
  confidence: high
  overlap_hints: [craft.boundaries]

- severity: Medium
  category: tests.coverage
  file: pkg/blockcontroller/blockcontroller.go
  line: 252
  title: No test covers env values nested under a connection override, and resolveEnvMap never uses connName
  evidence: |
    func resolveEnvMap(blockId string, blockMeta waveobj.MetaMapType, connName string) (map[string]string, error) {
    ...
    	cmdEnv := blockMeta.GetMap(waveobj.MetaKey_CmdEnv)
  evidence_refs: [pkg/waveobj/wtypemeta.go:52]
  impact: The type definition says `// these can be nested under "[conn]"` for `cmd:env`, `cmd:cwd` and the init scripts. `resolveEnvMap` takes `connName` but never calls `GetConnectionOverride`, so env set under `[conn]` is silently ignored. A test for `{"[myhost]": {"cmd:env": {"X":"1"}}}` would fail today, which suggests the feature is unfinished. The same gap exists for `cmd:cwd`.
  remedy: Add a test asserting that `[conn]`-nested `cmd:env` is applied, and overrides block-level `cmd:env`, for the matching connName. If nesting is not meant to be supported yet, remove connName and the comment. The logic fix itself belongs to correctness.
  confidence: medium
  overlap_hints: [correctness.logic, spec.missing]

- severity: Medium
  category: tests.coverage
  file: pkg/waveobj/metamap.go
  line: 22
  title: The new MetaMapType.HasKey and GetConnectionOverride have no tests for missing keys or wrongly-typed values
  evidence: |
    func (m MetaMapType) GetConnectionOverride(connName string) MetaMapType {
    	v, ok := m["["+connName+"]"]
    	if !ok {
    		return nil
    	}
    	if mval, ok := v.(map[string]any); ok {
    		return MetaMapType(mval)
    	}
    	return nil
  impact: The init-script lookup depends on these to decide which values win. Nothing pins these cases: the override is stored as `MetaMapType` rather than `map[string]any` (the assertion at line 27 would miss it and return nil); connName is "" (this looks up the literal key `"[]"`); the value is not a map; `HasKey` on a nil map returns false; `HasKey` returns true for a key whose value is explicitly nil. No `pkg/waveobj/*_test.go` exists.
  remedy: Add `pkg/waveobj/metamap_test.go` with cases for GetConnectionOverride: key missing gives nil; a `map[string]any` value gives that map; a string value gives nil; a `MetaMapType` value pins the intended behavior, since meta decoded from JSON is `map[string]any` but meta built in Go may not be. For HasKey: a nil receiver gives false, and `{"k": nil}` gives true.
  confidence: medium
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.coverage
  file: pkg/blockcontroller/blockcontroller.go
  line: 388
  title: getLocalShellOpts now lets an empty or null block value override settings, with no test
  evidence: |
    func getLocalShellOpts(blockMeta waveobj.MetaMapType) []string {
    	if blockMeta.HasKey(waveobj.MetaKey_TermLocalShellOpts) {
    		opts := blockMeta.GetStringList(waveobj.MetaKey_TermLocalShellOpts)
    		return append([]string{}, opts...)
    	}
  impact: The old code applied the block value only when `len(blockMeta.GetStringList(...)) > 0`. Now `"term:localshellopts": []` or `null` returns an empty slice and suppresses `settings.TermLocalShellOpts`. That may be intended (lets a block clear the setting), but it is an unpinned behavior change to how local shells start.
  remedy: Add cases: block key missing, so settings apply; block key `[]`, so empty opts and settings are ignored (the intended rule); block key `["-l"]`, so the block value wins. The function reads `wconfig.GetWatcher()`. Either pass settings in, or test only the block-key paths, which return before reaching wconfig.
  confidence: medium
  overlap_hints: [correctness.regression]

## Files examined
examined: [cmd/wsh/cmd/wshcmd-run.go, frontend/types/gotypes.d.ts, pkg/blockcontroller/blockcontroller.go, pkg/remote/conncontroller/conncontroller.go, pkg/shellexec/shellexec.go, pkg/util/shellutil/shellutil.go, pkg/wavebase/wavebase.go, pkg/waveobj/metaconsts.go, pkg/waveobj/metamap.go, pkg/waveobj/wtypemeta.go, pkg/wshrpc/wshserver/wshserver.go, pkg/wshutil/wshutil.go, pkg/wslconn/wslconn.go]
not_examined: []

Notes for the parent: the key files are `/Users/tufantunc/Desktop/Projects/Personal/aacr-bench/evaluation/work/wavetermdev__waveterm@90a57d5/pkg/blockcontroller/blockcontroller.go` (lines 218-280, 354-400) and `/Users/tufantunc/Desktop/Projects/Personal/aacr-bench/evaluation/work/wavetermdev__waveterm@90a57d5/pkg/waveobj/metamap.go` (lines 17-31). The existing table-test convention is in `pkg/util/shellutil/shellquote_test.go`. For most other files (constant moves, `GetConn`/`GetWslConn` signature changes, removing `cmdOpts.Env`) I read only the diff, and they add no logic that needs its own test. One more gap: the WSL swap-token path (`shellexec.go`) needs a real WSL process to test, so I did not file a finding for it.
