<!-- google-gemini__gemini-cli@c6e6248 ai-antipatterns-reviewer; verbatim final answer -->
I found three AI-antipatterns issues in this change: one Medium, two Low. I checked the flags and commands the test relies on against the CLI source, and they all exist: `install [<source>] [--path]` (`install.ts:60-68`), `update [<name>]` (`update.ts:105-113`), `uninstall <name>` (`uninstall.ts:26`) and `list` (`list.ts:30`). The output the test checks for is real too: install prints `Extension "${name}" installed successfully and enabled.` (`install.ts:52`) and update prints `... ${originalVersion} → ${updatedVersion}.` (`update.ts:73`). No API or import is made up.

- severity: Medium
  category: ai-antipatterns.ignored-convention
  file: integration-tests/test-helper.ts
  line: 309
  title: runCommand is a near-verbatim copy of run()'s spawn logic, including a Podman-only line that does nothing here, and drops run()'s stdin-closing step
  evidence: |
    runCommand(
      args: string[],
      options: { stdin?: string } = {},
    ): Promise<string> {
      const commandArgs = [this.bundlePath, ...args];
      const child = spawn('node', commandArgs, { cwd: this.testDir!, stdio: 'pipe' });
      ...
      if (options.stdin) {
        child.stdin!.write(options.stdin);
        child.stdin!.end();
      }
      ...
          this._lastRunStdout = stdout;
  evidence_refs: [integration-tests/test-helper.ts:210-242, integration-tests/test-helper.ts:223-228, integration-tests/test-helper.ts:247-248, integration-tests/test-helper.ts:657-669]
  impact: The spawn call, the stdout/stderr collectors, the KEEP_OUTPUT/VERBOSE echo, and the close/resolve/reject handling are copied almost line for line from `run()` (lines 210-304). Two parts of the copy don't fit this method:
    - `this._lastRunStdout = stdout` is there in `run()` only "for Podman telemetry parsing" (line 247). Only `readToolLogs()` reads it (lines 657-669), and extension CLI commands produce no tool-call telemetry. The copied line does nothing useful and quietly replaces the stdout saved by an earlier `run()` call.
    - `run()` always closes stdin for object options unless `stdinDoesNotEnd` is set (lines 223-228). The copy closes stdin only when `options.stdin` is given, so `list`, `update` and `uninstall` start with stdin left open. That departs from the existing helper, and a command that waits on stdin would hang.
  remedy: Move the shared spawn/collect/resolve logic into one private helper that takes `commandArgs` and stdin options. `run()` adds `--yolo`/`--prompt` and the Podman filtering on top; `runCommand()` passes the args through as-is. Keep `run()`'s stdin-closing behaviour, and drop the `_lastRunStdout` assignment from the command path.
  confidence: high
  overlap_hints: [dry.canonical-helper, craft.abstraction, correctness]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: integration-tests/extensions-install.test.ts
  line: 52
  title: Manual rmSync after rig.cleanup() repeats the deletion and ignores the KEEP_OUTPUT setting
  evidence: |
    await rig.cleanup();
    rmSync(rig.testDir!, { recursive: true, force: true });
  evidence_refs: [integration-tests/test-helper.ts:371-383, integration-tests/json-output.test.ts:18-19, integration-tests/utf-bom-encoding.test.ts:64]
  impact: `cleanup()` already deletes `testDir`, except when `KEEP_OUTPUT` is set (line 373: `if (this.testDir && !env.KEEP_OUTPUT)`). The extra `rmSync` adds nothing in the normal case. When a developer sets `KEEP_OUTPUT` to inspect a failure, it deletes the directory anyway, which defeats the setting. No other integration test does this; they just call `rig.cleanup()`.
  remedy: Delete the `rmSync` line and the `rmSync` import. Rely on `rig.cleanup()`, and call it from `afterEach` or a `finally` block as `json-output.test.ts` does.
  confidence: high
  overlap_hints: [tests.flaky, craft.canonical-helper]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: integration-tests/extensions-install.test.ts
  line: 25
  title: Hand-written file creation skips rig.createFile, and the variable name and test title are copied from the MCP-server tests
  evidence: |
    test('installs a local extension, verifies a command, and updates it', async () => {
      rig.setup('extension install test');
      const testServerPath = join(rig.testDir!, 'gemini-extension.json');
      writeFileSync(testServerPath, extension);
  evidence_refs: [integration-tests/test-helper.ts:163-167, integration-tests/simple-mcp-server.test.ts:184-185, integration-tests/mcp_server_cyclic_schema.test.ts:173-174]
  impact: `TestRig.createFile(fileName, content)` already does `join(this.testDir!, fileName)` plus `writeFileSync` and returns the path, so the test rebuilds an existing helper. The name `testServerPath` comes straight from the MCP-server tests, where it points at `mcp-server.cjs`; here it points at an extension manifest, which suggests copy-paste rather than intent. The title promises "verifies a command", but the test never checks any command the extension provides; it only checks install, list and update.
  remedy: Use `const manifestPath = rig.createFile('gemini-extension.json', extension);`, and later `rig.createFile('gemini-extension.json', extensionUpdate)` for the update. Rename the title to `installs, lists, and updates a local extension`, or add the command check it promises.
  confidence: high
  overlap_hints: [dry.canonical-helper, tests.naming]

## Files examined
examined: [integration-tests/extensions-install.test.ts, integration-tests/test-helper.ts]
not_examined: []
