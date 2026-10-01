<!-- google-gemini__gemini-cli@c6e6248 dry-reviewer; verbatim final answer -->
## DRY findings

- severity: Medium
  category: dry.copy-paste
  file: integration-tests/test-helper.ts
  line: 315
  title: runCommand copies run()'s spawn, stream-collection and close-handling code, and already behaves differently from it
  evidence: |
    const child = spawn('node', commandArgs, {
      cwd: this.testDir!,
      stdio: 'pipe',
    });

    let stdout = '';
    let stderr = '';
    ...
    child.stdout!.on('data', (data: Buffer) => {
      stdout += data;
      if (env.KEEP_OUTPUT === 'true' || env.VERBOSE === 'true') {
        process.stdout.write(data);
      }
    });

    child.stderr!.on('data', (data: Buffer) => {
      stderr += data;
      if (env.KEEP_OUTPUT === 'true' || env.VERBOSE === 'true') {
        process.stderr.write(data);
      }
    });

    const promise = new Promise<string>((resolve, reject) => {
      child.on('close', (code: number) => {
        if (code === 0) {
          this._lastRunStdout = stdout;
          let result = stdout;
          if (stderr) {
            result += `\n\nStdErr:\n${stderr}`;
          }
          resolve(result);
        } else {
          reject(new Error(`Process exited with code ${code}:\n${stderr}`));
        }
      });
    });
  evidence_refs: [integration-tests/test-helper.ts:210, integration-tests/test-helper.ts:215, integration-tests/test-helper.ts:230, integration-tests/test-helper.ts:237, integration-tests/test-helper.ts:244, integration-tests/test-helper.ts:295, integration-tests/test-helper.ts:301]
  impact: Lines 315-355 copy `run()` at lines 210-242 and 244-304 almost line for line. The two copies have already drifted apart. When `runCommand` gets no `stdin`, it never closes the child's stdin, while `run()` closes it for every call made with an options object (lines 223-228). `runCommand` also skips the Podman telemetry filtering (lines 253-286) and the JSON-output check that keeps stderr out of the result (lines 290-296). The `env.KEEP_OUTPUT === 'true' || env.VERBOSE === 'true'` check now appears 5 times in the file (lines 232, 239, 330, 337, 363). Any future fix to how processes are spawned or how their output is collected has to be made in two places.
  remedy: Move lines 210-304 into one private helper, for example `_spawnCli(commandArgs: string[], opts: { stdin?: string; stdinDoesNotEnd?: boolean })`, that spawns, collects output, applies the Podman and JSON handling, and resolves or rejects. `run()` builds `[this.bundlePath, '--yolo', '--prompt', ...]` and calls it. `runCommand(args, options)` becomes `return this._spawnCli([this.bundlePath, ...args], options)`. Also pull the KEEP_OUTPUT/VERBOSE check into a small `isVerbose()` helper and use it at all 5 places.
  confidence: high
  overlap_hints: [craft.code-judo, correctness.stdin-not-closed]

- severity: Low
  category: dry.canonical-helper
  file: integration-tests/extensions-install.test.ts
  line: 25
  title: Test writes the fixture file by hand instead of using TestRig.createFile
  evidence: |
    const testServerPath = join(rig.testDir!, 'gemini-extension.json');
    writeFileSync(testServerPath, extension);
    ...
    writeFileSync(testServerPath, extensionUpdate);
  evidence_refs: [integration-tests/test-helper.ts:163, integration-tests/file-system.test.ts:14, integration-tests/read_many_files.test.ts:14]
  impact: This repeats `TestRig.createFile` (test-helper.ts:163-167), which already does `join(this.testDir!, fileName)` plus `writeFileSync`. Other tests use that helper (file-system.test.ts:14, read_many_files.test.ts:14, replace.test.ts:19). Repeating it here means the extra `node:fs` and `node:path` imports and the `rig.testDir!` assertion.
  remedy: Use `rig.createFile('gemini-extension.json', extension)` at line 26 and `rig.createFile('gemini-extension.json', extensionUpdate)` at line 41. Then remove `writeFileSync` and `join` from the imports.
  confidence: high
  overlap_hints: [ai-antipatterns.ignored-convention]

- severity: Low
  category: dry.canonical-helper
  file: integration-tests/extensions-install.test.ts
  line: 52
  title: Deleting the test directory with rmSync repeats TestRig.cleanup() and bypasses its KEEP_OUTPUT check
  evidence: |
    await rig.cleanup();
    rmSync(rig.testDir!, { recursive: true, force: true });
  evidence_refs: [integration-tests/test-helper.ts:371]
  impact: `TestRig.cleanup()` (test-helper.ts:371-383) is the one place that deletes the test directory, and it deliberately keeps the directory when `KEEP_OUTPUT` is set. The extra `rmSync` deletes it again and ignores that setting, so `KEEP_OUTPUT` runs lose the directory needed for debugging.
  remedy: Delete line 52 and the `rmSync` import, and rely on `rig.cleanup()`. If the cleanup must also run when the test fails, call `rig.cleanup()` in `afterEach`/`finally` instead.
  confidence: high
  overlap_hints: [correctness.error-path, tests.flaky]

## Files examined
examined: [integration-tests/extensions-install.test.ts, integration-tests/test-helper.ts]
not_examined: []

Note: running `git diff` needed approval and was not run. I reviewed `integration-tests/test-helper.ts` by reading the full file and relying on the task's statement that lines 309-358 are the addition. I read `integration-tests/extensions-install.test.ts` in full because it is a new file.
