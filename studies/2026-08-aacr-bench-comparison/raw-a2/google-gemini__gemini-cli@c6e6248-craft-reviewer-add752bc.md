<!-- google-gemini__gemini-cli@c6e6248 craft-reviewer; verbatim final answer -->
## Craft findings

- severity: Medium
  category: craft.code-judo
  file: integration-tests/test-helper.ts
  line: 309
  title: runCommand copies the spawn/collect/close code from run() instead of sharing one process runner
  evidence: |
    runCommand(
      args: string[],
      options: { stdin?: string } = {},
    ): Promise<string> {
      const commandArgs = [this.bundlePath, ...args];
      const child = spawn('node', commandArgs, {
        cwd: this.testDir!,
        stdio: 'pipe',
      });
      let stdout = '';
      let stderr = '';
      if (options.stdin) {
        child.stdin!.write(options.stdin);
        child.stdin!.end();
      }
      child.stdout!.on('data', (data: Buffer) => {
        stdout += data;
        if (env.KEEP_OUTPUT === 'true' || env.VERBOSE === 'true') {
    ...
          reject(new Error(`Process exited with code ${code}:\n${stderr}`));
  impact: About 45 of runCommand's 50 lines repeat run() (lines 210-245 and 300-306): the spawn options, both stream listeners with the KEEP_OUTPUT/VERBOSE echo, `_lastRunStdout` bookkeeping, the stderr append and the reject message. The two copies already disagree. run() ends stdin unless `stdinDoesNotEnd` is set (line 223-228). runCommand ends stdin only when stdin text is passed, so a call with no stdin leaves the pipe open. runCommand also skips the Podman telemetry filtering (lines 253-286) while still writing `_lastRunStdout`, which is kept for Podman telemetry parsing. Any later fix to process handling (timeouts, env, stdin behaviour) has to be made in both places.
  remedy: Move the shared part into one private helper, e.g. `private spawnCli(commandArgs: string[], opts: { stdin?: string; stdinDoesNotEnd?: boolean; filterPodman?: boolean; includeStderr?: boolean }): Promise<string>`. It would own spawn, stdin handling, stream collection, the verbose echo, `_lastRunStdout`, Podman filtering and the resolve/reject logic. Then run() only builds `[bundlePath, '--yolo', '--prompt', ...]` and works out `isJsonOutput`, and runCommand becomes one line: `return this.spawnCli([this.bundlePath, ...args], options)`. The two copies can no longer drift apart, and about 40 lines go away.
  confidence: high
  overlap_hints: [dry.duplication, correctness.stdin-hang]

- severity: Low
  category: craft.boundary
  file: integration-tests/extensions-install.test.ts
  line: 51
  title: The test deletes the rig's directory itself after calling rig.cleanup(), and teardown is not in afterEach
  evidence: |
      await rig.cleanup();
      rmSync(rig.testDir!, { recursive: true, force: true });
    });
  impact: TestRig.cleanup() (test-helper.ts:371-383) owns deleting the test directory, and it deliberately keeps the directory when KEEP_OUTPUT is set. The extra `rmSync` deletes it anyway, so KEEP_OUTPUT stops working for this test. Teardown also sits at the end of the test body, so any failed assertion skips it and leaves the directory and the installed extension behind. Other tests in this folder, such as json-output.test.ts:14-19, put the TestRig in beforeEach and call cleanup in afterEach.
  remedy: Delete the `rmSync` line and its import. Follow the json-output.test.ts pattern: create the rig in `beforeEach`, and in `afterEach` uninstall the extension (best-effort) and then call `await rig.cleanup()`. If the directory should be removed even when KEEP_OUTPUT is set, change that inside `cleanup()`, not in individual tests.
  confidence: high
  overlap_hints: [tests.flaky, tests.teardown]

- severity: Nitpick
  category: craft.abstraction
  file: integration-tests/extensions-install.test.ts
  line: 25
  title: Variable name testServerPath is wrong for the extension manifest path
  evidence: |
      const testServerPath = join(rig.testDir!, 'gemini-extension.json');
  impact: The name looks copied from the MCP server tests. It suggests a server script, but the variable holds the extension manifest path.
  remedy: Rename it to `manifestPath`, or use `rig.createFile('gemini-extension.json', extension)`, which already returns the path.
  confidence: high
  overlap_hints: []

## Files examined
examined: [integration-tests/extensions-install.test.ts, integration-tests/test-helper.ts]
not_examined: []

Note: running `git diff` needed approval and was not run. I reviewed test-helper.ts from its current contents: I read lines 120-399 in full, which cover `run()`, the new `runCommand()` and `cleanup()`. I read extensions-install.test.ts in full.
