<!-- microsoft__typescript-go@892b4a3 correctness-reviewer; verbatim final answer -->
## Correctness findings

- severity: High
  category: correctness.devex
  file: internal/fourslash/_scripts/convertFourslash.mts
  line: 27
  title: convertfourslash and updatefailing crash with ENOENT because manualTests.txt is never created
  evidence: |
    function getManualTests(): Set<string> {
        const manualTestsList = fs.readFileSync(manualTestsPath, "utf-8").split("\n")...
    ...
    parseTypeScriptFiles(getFailingTests(), getManualTests(), stradaFourslashPath);
  impact: At HEAD, `internal/fourslash/_scripts/` holds only convertFourslash.mts, failingTests.txt, makeManual.mts, tsconfig.json and updateFailing.mts. The change does not add manualTests.txt. `main()` first runs `fs.rmSync(outputDir, ...)` on tests/gen and calls `generateHelperFile()`. Then `getManualTests()` throws ENOENT. So `npm run convertfourslash` leaves tests/gen empty except util_test.go and never writes the generated tests. `npm run updatefailing` calls `convertFourslash()` after it has already cleared failingTests.txt (`fs.writeFileSync(failingTestsPath, "", ...)`). It crashes at the same point, leaving failingTests.txt empty and tests/gen wiped. Both existing workflows break for everyone until someone runs `makemanual`, which is the only thing that creates the file.
  remedy: Commit an empty `internal/fourslash/_scripts/manualTests.txt`, or have `getManualTests()` return an empty set when the file does not exist (`fs.existsSync` guard), as makeManual.mts already does.
  confidence: high
  overlap_hints: [correctness.side-effect]
  evidence_refs: [internal/fourslash/_scripts/updateFailing.mts:10, internal/fourslash/_scripts/updateFailing.mts:11, internal/fourslash/_scripts/convertFourslash.mts:42]

- severity: High
  category: correctness.logic
  file: internal/fourslash/_scripts/makeManual.mts
  line: 16
  title: makeManual writes a different name to manualTests.txt than convertFourslash looks up, so manual tests are never skipped
  evidence: |
    // makeManual.mts
    const testName = args[0];
    const genTestFile = path.join(genDir, `${testFileName}`);   // must be the full file name, e.g. "fooBar_test.go"
    ...
    if (!manualTests.includes(testName)) { manualTests.push(testName); ...

    // convertFourslash.mts:70-72
    const testName = test.name[0].toUpperCase() + test.name.substring(1);   // e.g. "FooBar"
    if (manualTests.has(testName)) { return; }
  impact: makeManual uses `args[0]` directly as the file name in tests/gen and adds no `_test.go` suffix. The only argument that passes the `existsSync` check is therefore the full generated file name, for example `fooBar_test.go`, and that exact string is what gets written to manualTests.txt. convertFourslash compares against the capitalized name without a suffix (`FooBar`), so the two never match. If the user passes `FooBar`, makeManual fails with "Test file not found". Either way the skip never fires. The next `convertfourslash` run regenerates `fooBar_test.go` in tests/gen, so any manual edits are shadowed by a regenerated copy. That copy runs alongside the manual one and is still tracked in failingTests.txt. The feature's core purpose, keeping manually maintained tests out of generation, does not work.
  remedy: Settle on one key format. For example, have makeManual take the test name (`FooBar` or `fooBar`), derive the file as `${lowerFirst(name)}_test.go`, and write the capitalized name to manualTests.txt. Or have convertFourslash compare against `${test.name}_test.go`. Normalizing both sides (strip `Test` and `_test.go`, lowercase the first letter) also works.
  confidence: high
  overlap_hints: [spec]
  evidence_refs: [internal/fourslash/_scripts/convertFourslash.mts:70, internal/fourslash/_scripts/convertFourslash.mts:78, internal/fourslash/_scripts/convertFourslash.mts:946]

- severity: Medium
  category: correctness.side-effect
  file: internal/fourslash/_scripts/makeManual.mts
  line: 29
  title: A test moved into tests/manual loses the util_test.go helpers it depends on and will not compile
  evidence: |
    const manualTestFile = path.join(manualDir, path.basename(genTestFile));
    fs.renameSync(genTestFile, manualTestFile);
    // convertFourslash.mts:977-978
    function generateHelperFile() {
        fs.copyFileSync(helperFilePath, path.join(outputDir, "util_test.go"));
    }
  impact: Generated files are `package fourslash_test` and call helpers such as `ptrTo`, `defaultCommitCharacters` and `completionGlobals`, which exist only in util_test.go. 611 files in tests/gen reference these helpers. `generateHelperFile` copies util_test.go only into tests/gen, and neither convertFourslash (which now creates `manualOutputDir`) nor makeManual puts it in tests/manual. Go treats each directory as its own package, so a moved test that uses these helpers fails with undefined identifiers. `go test ./...` then breaks for the whole repo.
  remedy: Also copy util_test.go into tests/manual, in `generateHelperFile` and/or makeManual. Alternatively, move the helpers into a shared non-test package that both directories import.
  confidence: high
  overlap_hints: [tests]
  evidence_refs: [internal/fourslash/tests/util_test.go:14, internal/fourslash/_scripts/convertFourslash.mts:44]

- severity: Low
  category: correctness.error-path
  file: internal/fourslash/_scripts/makeManual.mts
  line: 12
  title: Running makemanual without an argument exits 1 with no message
  evidence: |
    if (args.length === 0) {
        process.exit(1);
    }
  impact: `npm run makemanual` with no argument fails with only npm's generic error. Nothing tells the user what argument is expected, and given the name-format confusion above, users are likely to guess wrong.
  remedy: Print a usage line before exiting, e.g. `console.error("Usage: npm run makemanual -- <testName>")`.
  confidence: high
  overlap_hints: [craft]

## Files examined
examined: [internal/fourslash/_scripts/convertFourslash.mts, internal/fourslash/_scripts/makeManual.mts, package.json]
not_examined: []
