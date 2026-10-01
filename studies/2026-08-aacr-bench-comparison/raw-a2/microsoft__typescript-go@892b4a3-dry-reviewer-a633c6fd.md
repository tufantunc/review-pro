<!-- microsoft__typescript-go@892b4a3 dry-reviewer; verbatim final answer -->
## DRY findings

- severity: Medium
  category: dry.duplication
  file: internal/fourslash/_scripts/makeManual.mts
  line: 5
  title: makeManual.mts re-declares the manualTests.txt path and format that convertFourslash.mts already owns
  evidence: |
    const manualTestsPath = path.join(scriptsDir, "manualTests.txt");
    const genDir = path.join(scriptsDir, "../", "tests", "gen");
    const manualDir = path.join(scriptsDir, "../", "tests", "manual");
    ...
        manualTests = content.split("\n").map(line => line.trim()).filter(line => line.length > 0);
  evidence_refs: [internal/fourslash/_scripts/convertFourslash.mts:13, internal/fourslash/_scripts/convertFourslash.mts:16, internal/fourslash/_scripts/convertFourslash.mts:17, internal/fourslash/_scripts/convertFourslash.mts:26-29]
  impact: Two scripts each define where manualTests.txt lives and how it is parsed, and they already disagree on what an entry is. makeManual.mts passes `args[0]` to `path.join(genDir, ...)`, so the argument has to be the file name (for example `fooBar_test.go`), and that same string is what gets written to the list. convertFourslash.mts:72 checks `manualTests.has(testName)`, and `testName` there is the capitalized test name (for example `FooBar`). An entry added by makeManual.mts will never match, so the next `convertfourslash` run regenerates the test in `gen/` next to the copy in `manual/`. With no single owner, this kind of drift goes unnoticed.
  remedy: Export `manualTestsPath`, `outputDir`/`manualOutputDir` and `getManualTests()` from convertFourslash.mts, and have makeManual.mts import them, the same way updateFailing.mts already imports `main` from it. This is safe because convertFourslash's `main()` only runs behind the `import.meta.url == process.argv[1]` check at line 981. Then pick one key format for entries (the capitalized test name) and have makeManual.mts work out the file name from it.
  confidence: high
  overlap_hints: [correctness.logic, craft.abstraction]

- severity: Low
  category: dry.copy-paste
  file: internal/fourslash/_scripts/convertFourslash.mts
  line: 26
  title: getManualTests is a copy of getFailingTests with only the file path and the substring(4) changed
  evidence: |
    function getManualTests(): Set<string> {
        const manualTestsList = fs.readFileSync(manualTestsPath, "utf-8").split("\n").map(line => line.trim()).filter(line => line.length > 0);
        return new Set(manualTestsList);
    }
  evidence_refs: [internal/fourslash/_scripts/convertFourslash.mts:20-23]
  impact: There are now three copies of the "read a list file, split, trim, drop blanks" pipeline: convertFourslash.mts:21, :27 and makeManual.mts:36. Any change to the list format, such as allowing comments or handling CRLF, has to be made in all three.
  remedy: Add one `readTestList(filePath: string, transform = (l: string) => l): Set<string>` helper in convertFourslash.mts. Have getFailingTests call it with `l => l.substring(4)`, have getManualTests call it with no transform, and export it for makeManual.mts.
  confidence: high
  overlap_hints: [craft.code-judo]

- severity: Low
  category: dry.duplication
  file: internal/fourslash/_scripts/convertFourslash.mts
  line: 70
  title: The capitalized testName calculation is copied from generateGoTest
  evidence: |
    const testName = test.name[0].toUpperCase() + test.name.substring(1);
  evidence_refs: [internal/fourslash/_scripts/convertFourslash.mts:946, internal/fourslash/_scripts/convertFourslash.mts:917]
  impact: The key used to skip manual tests and the key used for the `Test${testName}` / failing-test lookup are now calculated in two places. If one changes (for example the capitalization rule), manual-test skipping stops lining up with the generated test names without any error.
  remedy: Work out `testName` once in parseTypeScriptFiles and pass it to `generateGoTest`, or set it on `GoTest` in parseFileContent. Alternatively, add a small `capitalize()` helper and use it at lines 70, 917, 946 and 206.
  confidence: high
  overlap_hints: [craft.code-judo]

## Files examined
examined: [internal/fourslash/_scripts/convertFourslash.mts, internal/fourslash/_scripts/makeManual.mts, package.json]
not_examined: []
