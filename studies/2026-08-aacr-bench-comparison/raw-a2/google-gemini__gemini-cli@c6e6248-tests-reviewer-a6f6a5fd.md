<!-- google-gemini__gemini-cli@c6e6248 tests-reviewer; verbatim final answer -->
I found four test-quality problems in the new extensions integration test and the `runCommand` helper, rated Medium to Low. None of them blocks the change.

- severity: Medium
  category: tests.flakiness
  file: integration-tests/extensions-install.test.ts
  line: 28
  title: Test installs into the developer's real `~/.gemini/extensions` and deletes any existing `test-extension` there
  evidence: |
    try {
      await rig.runCommand(['extensions', 'uninstall', 'test-extension']);
    } catch {
      /* empty */
    }
    const result = await rig.runCommand(
      ['extensions', 'install', `--path=${rig.testDir!}`],
  impact: |
    `runCommand` starts the CLI with the parent's environment and does not isolate HOME, and `globalSetup.ts` does not override HOME either. The CLI resolves extensions from `os.homedir()`, so install, update and uninstall all act on the real user profile, not on `testDir`. Three things follow:
    - The uninstall at line 28 silently deletes any real extension called `test-extension` that the developer has installed.
    - The config sets `fileParallelism: true`, so other integration test files running at the same time load user extensions and can see this one appear and disappear.
    - Whether the test passes depends on state left over from earlier runs, which is why the try/catch uninstall is needed.
  remedy: Give the spawned CLI a HOME (and USERPROFILE) inside `rig.testDir`, for example with an `env` option on `runCommand` that the test sets. Then remove the pre-emptive uninstall-and-swallow step.
  confidence: high
  overlap_hints: [correctness.side-effects]
  evidence_refs: [packages/cli/src/config/extension.ts:84, packages/cli/src/config/extension.ts:175, integration-tests/test-helper.ts:315, integration-tests/globalSetup.ts:72, integration-tests/vitest.config.ts:16]

- severity: Medium
  category: tests.assertion
  file: integration-tests/extensions-install.test.ts
  line: 47
  title: Update assertion is a bare substring match; the change of state is never checked, and the promised "verifies a command" step is missing
  evidence: |
    const updateResult = await rig.runCommand([
      'extensions',
      'update',
      `test-extension`,
    ]);
    expect(updateResult).toContain('0.0.2');
    await rig.runCommand(['extensions', 'uninstall', 'test-extension']);
  impact: |
    `handleUpdate` catches every error, prints it with `console.error`, and still exits 0. Only the `'0.0.2'` substring separates a real update from a failure, and it proves neither the `0.0.1 → 0.0.2` transition nor that the installed copy changed. The test also:
    - never runs `extensions list` after the update to confirm `test-extension (0.0.2)`;
    - never checks that uninstall removed the extension;
    - has a name ("verifies a command") that promises a step the body does not contain.
  remedy: |
    - Assert the full success line: `expect(updateResult).toContain('Extension "test-extension" successfully updated: 0.0.1 → 0.0.2.')`.
    - Before the update, assert that `list` shows `test-extension (0.0.1)`; after it, assert that `list` shows `test-extension (0.0.2)`.
    - After uninstall, assert that `list` no longer contains `test-extension`.
    - Rename the test, or add a real command check.
  confidence: high
  overlap_hints: []
  evidence_refs: [packages/cli/src/commands/extensions/update.ts:72, packages/cli/src/commands/extensions/update.ts:78, packages/cli/src/config/extension.ts:614]

- severity: Low
  category: tests.flakiness
  file: integration-tests/extensions-install.test.ts
  line: 49
  title: Uninstall and cleanup run only when every step succeeds
  evidence: |
    await rig.runCommand(['extensions', 'uninstall', 'test-extension']);

    await rig.cleanup();
    rmSync(rig.testDir!, { recursive: true, force: true });
  impact: |
    Cleanup has no `finally` or `afterEach`, so any failed assertion or rejected command leaves `test-extension` installed in the real home directory. The next run then relies on the swallowed uninstall at line 28. Other integration tests call `rig.cleanup()` from `afterEach`.
    The `rmSync` right after `rig.cleanup()` also ignores `KEEP_OUTPUT`: `cleanup()` deliberately skips deletion when `KEEP_OUTPUT` is set, and `rmSync` deletes anyway, so the debugging output is lost.
  remedy: Move uninstall (best-effort) and `rig.cleanup()` into `afterEach` or a `try/finally`, and drop the extra `rmSync`.
  confidence: high
  overlap_hints: []
  evidence_refs: [integration-tests/test-helper.ts:371-383]

- severity: Low
  category: tests.flakiness
  file: integration-tests/test-helper.ts
  line: 323
  title: `runCommand` leaves the child's stdin open when no stdin is given, so an unexpected prompt hangs until the 5-minute timeout
  evidence: |
    if (options.stdin) {
      child.stdin!.write(options.stdin);
      child.stdin!.end();
    }
  impact: |
    `run()` closes stdin whenever it gets an options object; `runCommand` only closes it when stdin is truthy, so an empty string also leaves it open. If a command reaches `promptForContinuation` (readline on `process.stdin`), for example if update ever starts asking for consent, the child waits forever. The test then fails only at `testTimeout: 300000`, not quickly with a clear error, and `retry: 2` repeats the wait.
  remedy: Always call `child.stdin!.end()` after writing any provided input, as `run()` does by default.
  confidence: medium
  overlap_hints: [correctness.logic]
  evidence_refs: [integration-tests/test-helper.ts:223-228, packages/cli/src/config/extension.ts:360-372, integration-tests/vitest.config.ts:11]

## Files examined
examined: [integration-tests/extensions-install.test.ts, integration-tests/test-helper.ts]
not_examined: []

The test-helper diff itself was blocked by a permission prompt, so I read `test-helper.ts` lines 120-399 directly, including the new `runCommand` at 309-358.
