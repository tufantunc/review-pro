<!-- microsoft__typescript-go@892b4a3 craft-reviewer; verbatim final answer -->
## Craft findings

- severity: High
  category: craft.boundary
  file: internal/fourslash/_scripts/makeManual.mts
  line: 16
  title: The two scripts that share manualTests.txt use different keys for a test, so no test can ever be moved to manual
  evidence: |
    // makeManual.mts
    const testName = args[0];
    const testFileName = testName;
    const genTestFile = path.join(genDir, `${testFileName}`);   // raw filename, no suffix added
    ...
    if (!manualTests.includes(testName)) {
        manualTests.push(testName);                               // stores e.g. "foo_test.go"

    // convertFourslash.mts:70-72
    const testName = test.name[0].toUpperCase() + test.name.substring(1);
    if (manualTests.has(testName)) {                              // looks up e.g. "Foo"
  impact: Nothing owns the manualTests.txt format. Each script has its own idea of what goes in it. makeManual only works when args[0] is a file name that exists in gen/ (for example `foo_test.go`), and it writes that exact string to the list. convertFourslash looks up the capitalized Go test name (`Foo`). The two never match. If the user passes `Foo`, makeManual stops with "Test file not found". If the user passes `foo_test.go`, the list gets an entry that convertFourslash never skips, so the next `convertfourslash` run writes gen/foo_test.go again. The same test then lives in both gen/ and manual/, and the edited manual copy slowly drifts from the regenerated one. This happens because two scripts each parse and write one shared file with no common owner.
  remedy: Give convertFourslash.mts ownership of the manual-list contract, the same way updateFailing.mts already imports `main` from it. Export `getTestName(test)` (the capitalization now at lines 70 and 946), `readManualTests()` (returns an empty set when the file is missing) and `addManualTest(name)`. Have makeManual take the Go test name, derive the gen file path itself (`${lowerFirst(name)}_test.go`), and call `addManualTest`. The list then has one key format, and the `testName`/`testFileName` alias and the `${testFileName}` template-wrapping go away.
  confidence: high
  overlap_hints: [correctness.logic, dry.duplication]

- severity: Medium
  category: craft.code-judo
  file: internal/fourslash/_scripts/convertFourslash.mts
  line: 26
  title: The same "read a line list" code now exists three times, and the copies disagree on whether the file may be missing
  evidence: |
    function getFailingTests(): Set<string> {
        const failingTestsList = fs.readFileSync(failingTestsPath, "utf-8").split("\n").map(line => line.trim().substring(4)).filter(line => line.length > 0);
    ...
    function getManualTests(): Set<string> {
        const manualTestsList = fs.readFileSync(manualTestsPath, "utf-8").split("\n").map(line => line.trim()).filter(line => line.length > 0);

    // makeManual.mts:33-37
    if (fs.existsSync(manualTestsPath)) {
        const content = fs.readFileSync(manualTestsPath, "utf-8");
        manualTests = content.split("\n").map(line => line.trim()).filter(line => line.length > 0);
  impact: There are three hand-written copies of split/trim/filter. makeManual treats a missing manualTests.txt as normal. getManualTests reads it unconditionally, and the change does not commit a manualTests.txt, so `npm run convertfourslash` (and updatefailing, which calls it) fails with ENOENT on a clean checkout. The copies have already drifted apart.
  remedy: Add one `readLineSet(path, map = (l) => l)` helper that returns an empty set for a missing file. Build getFailingTests (with `l => l.substring(4)`) and getManualTests on it, and have makeManual import it instead of re-parsing. Also commit an empty manualTests.txt so the file is part of the repository.
  confidence: high
  overlap_hints: [dry.duplication, correctness.error-path]

- severity: Low
  category: craft.spaghetti
  file: internal/fourslash/_scripts/convertFourslash.mts
  line: 70
  title: The test-name capitalization is copied into the directory walk, and a dead guard was added
  evidence: |
    const testName = test.name[0].toUpperCase() + test.name.substring(1);
    // Skip generation if test is in manual tests list
    if (manualTests.has(testName)) {
        return;
    }
    const testContent = generateGoTest(failingTests, test);
    if (testContent) {
  impact: The directory walk now repeats the Go-name derivation that generateGoTest already does at line 946, so two copies have to stay in sync. `generateGoTest` is typed `(...): string` and always returns a template string, so the new `if (testContent)` check can never be false. It suggests a "no output" path that does not exist.
  remedy: Compute the name once with a single `getTestName(test)` helper (the same one from the first finding) and pass it to generateGoTest. Better still, put the failing and manual sets into one per-test classification (`"skip-manual" | "failing" | "ok"`) so the walk has a single branch. Delete the `if (testContent)` guard.
  confidence: high
  overlap_hints: [dry.duplication]

- severity: Low
  category: craft.layer-leak
  file: internal/fourslash/_scripts/convertFourslash.mts
  line: 44
  title: The generator creates the manual/ directory, which only makeManual writes to
  evidence: |
    fs.mkdirSync(manualOutputDir, { recursive: true });
  impact: convertFourslash never writes to tests/manual. Creating that directory is makeManual's job, and makeManual already does it (`if (!fs.existsSync(manualDir)) fs.mkdirSync(...)`). Two scripts now manage the same directory, and `manualOutputDir` is otherwise unused in convertFourslash.
  remedy: Remove `manualOutputDir` and its `mkdirSync` from convertFourslash and leave directory creation to makeManual. In makeManual, drop the `existsSync` check, since `mkdirSync(..., { recursive: true })` already does nothing when the directory exists.
  confidence: high
  overlap_hints: []

## Files examined
examined: [internal/fourslash/_scripts/convertFourslash.mts, internal/fourslash/_scripts/makeManual.mts, package.json]
not_examined: []
