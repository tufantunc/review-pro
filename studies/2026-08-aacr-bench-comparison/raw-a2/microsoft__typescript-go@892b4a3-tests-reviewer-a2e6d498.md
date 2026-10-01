<!-- microsoft__typescript-go@892b4a3 tests-reviewer; verbatim final answer -->
- severity: High
  category: tests.coverage
  file: internal/fourslash/_scripts/makeManual.mts
  line: 16
  title: The name makeManual writes to manualTests.txt never matches what convertFourslash looks up, so the generated copy keeps coming back
  evidence: |
    // makeManual.mts
    const testName = args[0];
    const genTestFile = path.join(genDir, `${testFileName}`);   // arg must be the literal file name, e.g. "addDeclareToModule_test.go"
    ...
    manualTests.push(testName);                                  // "addDeclareToModule_test.go" written to manualTests.txt

    // convertFourslash.mts:70-72
    const testName = test.name[0].toUpperCase() + test.name.substring(1);   // "AddDeclareToModule"
    if (manualTests.has(testName)) {
        return;
    }
  evidence_refs: [internal/fourslash/_scripts/convertFourslash.mts:70, internal/fourslash/_scripts/convertFourslash.mts:22]
  impact: The `existsSync` check only passes when the argument is the full gen file name, such as `addDeclareToModule_test.go`. That exact string is what goes into manualTests.txt. But `getManualTests()` does not normalize entries (compare `getFailingTests()`, which strips the `Test` prefix), and the lookup uses the capitalized test name with no suffix, `AddDeclareToModule`. No argument can both pass the check in makeManual and match in convertFourslash. So the next `convertfourslash` or `updatefailing` run writes the generated test back into `tests/gen/`. The generated version, which is the one that needed hand-fixing, then runs again next to the manual copy. It either fails or gets added to failingTests.txt and skipped, and the manual override is lost without any warning.
  remedy: Pick one key format and use it in both scripts. For example, have makeManual take the test name (`AddDeclareToModule` or `TestAddDeclareToModule`), work out the file name from it (`lowerFirst(name) + "_test.go"`), and store the normalized name. Have `getManualTests()` normalize the same way `getFailingTests()` does. Also add a check, or a run of convertfourslash, confirming that a test moved to manual is not written again to `tests/gen/`.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: High
  category: tests.coverage
  file: internal/fourslash/_scripts/makeManual.mts
  line: 30
  title: Tests moved to tests/manual/ have no util_test.go helpers, so the manual package does not compile
  evidence: |
    const manualTestFile = path.join(manualDir, path.basename(genTestFile));
    fs.renameSync(genTestFile, manualTestFile);

    // convertFourslash.mts:977-978 — helpers are copied only into gen/
    function generateHelperFile() {
        fs.copyFileSync(helperFilePath, path.join(outputDir, "util_test.go"));
    }
  evidence_refs: [internal/fourslash/_scripts/convertFourslash.mts:978, internal/fourslash/tests/util_test.go:14]
  impact: Generated tests call package-level helpers that only exist in `util_test.go`, such as `ptrTo`, `completionGlobals` and `defaultCommitCharacters`. 611 of the 1308 files in `tests/gen/` use them. When one of these files moves to `tests/manual/`, it becomes a separate `fourslash_test` package with no helper definitions. `go test ./internal/fourslash/tests/manual` (and `./...`) then fails to build, so every manual test in that package stops running, not just the moved one.
  remedy: Copy `util_test.go` into `manualOutputDir` in `generateHelperFile()`, or have makeManual copy it when it creates the directory. Better, make manual tests share the helpers from one place. Then run `go test ./internal/fourslash/tests/manual` after moving a test that uses helpers to confirm it compiles.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.skipped
  file: internal/fourslash/_scripts/makeManual.mts
  line: 31
  title: A test that was skipped as failing stays skipped after it moves to manual, and updatefailing never checks it again
  evidence: |
    fs.renameSync(genTestFile, manualTestFile);   // moves the file verbatim, including a generated `t.Skip()`

    // convertFourslash.mts:968
    ${failingTests.has(testName) ? "t.Skip()" : ""}

    // updateFailing.mts:15
    testOutput = cp.execFileSync(go, ["test", "./internal/fourslash/tests/gen"], { encoding: "utf-8" });
  evidence_refs: [internal/fourslash/_scripts/convertFourslash.mts:968, internal/fourslash/_scripts/updateFailing.mts:15]
  impact: Tests usually go manual because conversion broke them, so they are often already in failingTests.txt and contain `t.Skip()`. That skip is moved along with the file. `updatefailing` only runs `tests/gen`, so it never checks manual tests. A manual test stays skipped until someone notices, and it looks like coverage while running nothing.
  remedy: In makeManual, remove the generated `t.Skip()` line when moving the file, or refuse to move and print a warning. Also remove the test's entry from failingTests.txt. Alternatively, extend updateFailing to run `./internal/fourslash/tests/manual` too, or document that manual tests are not tracked by it.
  confidence: medium
  overlap_hints: [correctness.logic]

## Files examined
examined: [internal/fourslash/_scripts/convertFourslash.mts, internal/fourslash/_scripts/makeManual.mts, package.json]
not_examined: []
