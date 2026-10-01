<!-- google-gemini__gemini-cli@c6e6248 correctness-reviewer; verbatim final answer -->
I found three correctness problems, all minor: one Medium and two Low. None of them should block the change on its own.

The ones I checked and ruled out:
- **No hang on stdin:** `runCommand` does not hang when it leaves stdin open. `parseArguments` calls `process.exit(0)` for any `extensions` subcommand (`packages/cli/src/config/config.ts:345-348`).
- **Consent prompt works:** the install consent prompt reads `y\n` through readline, as intended.
- **Update prints the new version:** `update` of a local-path extension re-reads the source directory (`packages/cli/src/config/extensions/github.ts:124-141`). It prints `0.0.1 → 0.0.2` (`packages/cli/src/commands/extensions/update.ts:72-74`), so the `toContain('0.0.2')` assertion is sound.
- **Podman filtering not needed:** extension commands exit before the sandbox relaunch, so dropping the podman telemetry filter from `runCommand` changes nothing.

- severity: Medium
  category: correctness.side-effect
  file: integration-tests/extensions-install.test.ts
  line: 28
  title: The test installs and uninstalls in the developer's real `~/.gemini/extensions` and can delete an existing extension called "test-extension"
  evidence: |
    try {
      await rig.runCommand(['extensions', 'uninstall', 'test-extension']);
    } catch {
      /* empty */
    }

    const result = await rig.runCommand(
      ['extensions', 'install', `--path=${rig.testDir!}`],
      { stdin: 'y\n' },
    );
  evidence_refs: [packages/cli/src/config/extension.ts:83-86, packages/cli/src/config/extension.ts:581-609, integration-tests/test-helper.ts:315-318, integration-tests/globalSetup.ts:34-38, integration-tests/vitest.config.ts:16]
  impact: |
    `runCommand` starts the CLI with the parent's environment unchanged. `HOME` is not overridden, and neither `globalSetup.ts` nor the rig changes it. `ExtensionStorage.getUserExtensionsDir()` resolves `new Storage(os.homedir()).getExtensionsDir()`, so every install, update and uninstall here runs against the real user profile.
    - The first uninstall has its error swallowed. It permanently deletes `~/.gemini/extensions/test-extension` and removes its entry from the enablement config, even if that extension was not created by this test.
    - While the test runs, the extension sits in the real home. `fileParallelism` is true, so other integration test files running the CLI at the same time load it through `loadExtensionsFromDir(os.homedir())`.
    - `globalSetup.ts` already saves and restores the memory file in the real home. That shows the suite deliberately protects home-directory state; this test does not.
  remedy: Spawn the CLI with an isolated home, for example `env: { ...process.env, HOME: join(this.testDir, 'home') }` (plus `USERPROFILE` on Windows) inside `runCommand`. Alternatively, back up and restore `~/.gemini/extensions/test-extension` the way `globalSetup.ts` handles the memory file.
  confidence: high
  overlap_hints: [tests.flaky, correctness.devex]

- severity: Low
  category: correctness.error-path
  file: integration-tests/extensions-install.test.ts
  line: 37
  title: A failed assertion skips the uninstall and cleanup, so the extension stays in the real home directory
  evidence: |
    expect(result).toContain('test-extension');
    ...
    expect(updateResult).toContain('0.0.2');

    await rig.runCommand(['extensions', 'uninstall', 'test-extension']);

    await rig.cleanup();
  impact: If any `expect` or `runCommand` call fails, the test throws before the final uninstall. The extension then stays under the user's `~/.gemini/extensions` and loads in their normal gemini sessions until the next test run's uninstall removes it. With `retry: 2`, the retries recover on their own, but after the last failure the extension is left behind.
  remedy: Put the uninstall and cleanup in `finally` or `afterEach`. Isolating `HOME` as in the finding above also fixes this.
  confidence: high
  overlap_hints: [tests.flaky]

- severity: Low
  category: correctness.devex
  file: integration-tests/extensions-install.test.ts
  line: 52
  title: The unconditional `rmSync` deletes the test directory even when `KEEP_OUTPUT` is set
  evidence: |
    await rig.cleanup();
    rmSync(rig.testDir!, { recursive: true, force: true });
  evidence_refs: [integration-tests/test-helper.ts:371-383]
  impact: '`rig.cleanup()` deliberately keeps the test directory when `KEEP_OUTPUT` is set. The `rmSync` right after it deletes the directory anyway, so a developer debugging with `KEEP_OUTPUT=true` loses this test''s output, unlike every other integration test.'
  remedy: Remove the extra `rmSync`, since `rig.cleanup()` already removes the directory when `KEEP_OUTPUT` is unset.
  confidence: high
  overlap_hints: [tests.quality]

## Files examined
examined: [integration-tests/extensions-install.test.ts, integration-tests/test-helper.ts]
not_examined: []

Notes on coverage:
- **`integration-tests/test-helper.ts`:** `git diff` needed approval and was not run, so I did not see the literal diff. I read lines 120-399 of the current file directly: the existing `run()`, the new `runCommand()` at 309-358, and `cleanup()`. I did not read the `_lastRunStdout` consumers around lines 650-670.
- **Other files read for context:** everything under `packages/cli/src/commands/extensions/` (install, update, uninstall, list), the relevant parts of `packages/cli/src/config/extension.ts` and `packages/cli/src/config/extensions/github.ts`, the `extensions` exit path in `config.ts`, `integration-tests/globalSetup.ts` and `integration-tests/vitest.config.ts`.
