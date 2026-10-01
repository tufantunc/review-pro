<!-- microsoft__typescript-go@892b4a3 ai-antipatterns-reviewer; verbatim final answer -->
- severity: High
  category: ai-antipatterns.ignored-convention
  file: internal/fourslash/_scripts/convertFourslash.mts
  line: 27
  title: manualTests.txt is read without a guard, but it isn't committed and is matched by the repo's `*.txt` gitignore rule
  evidence: |
    const manualTestsList = fs.readFileSync(manualTestsPath, "utf-8").split("\n").map(line => line.trim()).filter(line => line.length > 0);
  impact: The change assumes `manualTests.txt` exists and will be tracked. It does neither. `.gitignore:176` ignores `*.txt`. The sibling list only gets tracked through the explicit negation `!internal/fourslash/_scripts/failingTests.txt` at `.gitignore:200`, and this change adds no such line for manualTests.txt. `git diff --stat` shows only 3 files changed, so manualTests.txt is not in the commit. Two consequences. (1) On a fresh checkout, `readFileSync` throws ENOENT, which breaks `npm run convertfourslash` and also `npm run updatefailing`, because updateFailing.mts calls `convertFourslash()` (updateFailing.mts:11,29). (2) When `makeManual.mts:41` writes the file, git ignores it silently, so the manual list can never be shared. Note that makeManual.mts:33 does guard with `existsSync`, so the two scripts handle a missing file differently.
  remedy: Add `!internal/fourslash/_scripts/manualTests.txt` to `.gitignore` next to the failingTests.txt negation. Commit an empty `manualTests.txt`. Also make `getManualTests` tolerate a missing file, the same way makeManual.mts does.
  confidence: high
  evidence_refs: [.gitignore:176, .gitignore:200, internal/fourslash/_scripts/updateFailing.mts:11, internal/fourslash/_scripts/makeManual.mts:33]
  overlap_hints: [correctness.breakage]

- severity: High
  category: ai-antipatterns.ignored-convention
  file: internal/fourslash/_scripts/makeManual.mts
  line: 18
  title: makeManual writes list entries in a different format from the one convertFourslash checks, so skipped tests are never actually skipped
  evidence: |
    const testName = args[0];
    const testFileName = testName;
    const genTestFile = path.join(genDir, `${testFileName}`);
    ...
    manualTests.push(testName);
  impact: makeManual looks for `args[0]` directly as a file in `tests/gen` and adds no suffix. So the user has to pass the file name, e.g. `addDeclareToModule_test.go` (gen files are named `${test.name}_test.go`, convertFourslash.mts:77), and that exact string is what goes into manualTests.txt. convertFourslash.mts:70-72 checks against a different string, `test.name[0].toUpperCase() + test.name.substring(1)`, e.g. `AddDeclareToModule`. The two never match. After running makemanual, the next convertfourslash run generates the test into `gen/` again alongside the copy in `manual/`. The format also doesn't follow the existing list convention: failingTests.txt stores `TestXxx` entries and strips the prefix with `.substring(4)` (convertFourslash.mts:22).
  remedy: Pick one canonical entry format, preferably `TestXxx` to match failingTests.txt. Have makeManual accept that form and derive the gen file name from it. Have convertFourslash compare using the same derivation, and reuse the name logic from `generateGoTest` (line 946) instead of copying it at line 70.
  confidence: high
  evidence_refs: [internal/fourslash/_scripts/convertFourslash.mts:70, internal/fourslash/_scripts/convertFourslash.mts:77, internal/fourslash/_scripts/convertFourslash.mts:22, internal/fourslash/_scripts/failingTests.txt:1]
  overlap_hints: [correctness.logic, dry.canonical-helper]

- severity: Low
  category: ai-antipatterns.over-engineering
  file: internal/fourslash/_scripts/convertFourslash.mts
  line: 76
  title: Dead truthiness check on a function that always returns a non-empty string
  evidence: |
    const testContent = generateGoTest(failingTests, test);
    if (testContent) {
  impact: `generateGoTest(...): string` (line 945) always returns a non-empty template literal (lines 958-974), so the `if` can never be false. The check suggests that generateGoTest can fail or return nothing, which it can't.
  remedy: Remove the `if (testContent)` wrapper and call `writeFileSync` directly, as the code did before this change.
  confidence: high
  evidence_refs: [internal/fourslash/_scripts/convertFourslash.mts:945-975]
  overlap_hints: [craft.dead-code]

- severity: Low
  category: ai-antipatterns.over-engineering
  file: internal/fourslash/_scripts/convertFourslash.mts
  line: 44
  title: Every convertfourslash run creates the manual output directory even though nothing is written to it
  evidence: |
    const manualOutputDir = path.join(import.meta.dirname, "../", "tests", "manual");
    ...
    fs.mkdirSync(manualOutputDir, { recursive: true });
  impact: convertFourslash never writes to or formats `manualOutputDir`. gofumpt still only runs on `outputDir` (line 50), and makeManual.mts:25-27 creates the directory itself when it needs it. The constant exists only for a setup step that has no use.
  remedy: Remove `manualOutputDir` and the `mkdirSync` call from convertFourslash.mts.
  confidence: high
  overlap_hints: [craft.abstraction]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: internal/fourslash/_scripts/makeManual.mts
  line: 35
  title: The logic for parsing list files is written again instead of shared with convertFourslash
  evidence: |
    manualTests = content.split("\n").map(line => line.trim()).filter(line => line.length > 0);
  impact: The same split/trim/filter pipeline now appears three times: `getFailingTests` (convertFourslash.mts:22), the new `getManualTests` (convertFourslash.mts:27), and here. The sibling script updateFailing.mts already imports from convertFourslash.mts (`import { main as convertFourslash } from "./convertFourslash.mts"`), so sharing a helper already has a working pattern in this directory. The copies have already drifted apart: one guards a missing file and the other doesn't.
  remedy: Export one list-reading helper from convertFourslash.mts that handles a missing file, and import it in makeManual.mts.
  confidence: high
  evidence_refs: [internal/fourslash/_scripts/updateFailing.mts:5, internal/fourslash/_scripts/convertFourslash.mts:22]
  overlap_hints: [dry.duplication]

- severity: Nitpick
  category: ai-antipatterns.over-engineering
  file: internal/fourslash/_scripts/makeManual.mts
  line: 17
  title: Redundant alias, a no-op template literal, a redundant existsSync, and an exit with no message
  evidence: |
    const testFileName = testName;
    const genTestFile = path.join(genDir, `${testFileName}`);
    ...
    if (!fs.existsSync(manualDir)) {
        fs.mkdirSync(manualDir, { recursive: true });
    }
  impact: `testFileName` is just a copy of `testName`. `` `${testFileName}` `` is the same string. `mkdirSync({ recursive: true })` already does nothing if the directory exists. `process.exit(1)` at line 13 exits without a usage message, unlike the explanatory `console.error` output at lines 20-21.
  remedy: Use `testName` directly and drop the template literal and the `existsSync` check. Print a usage line before `process.exit(1)`.
  confidence: high
  overlap_hints: [craft.readability]

## Files examined
examined: [internal/fourslash/_scripts/convertFourslash.mts, internal/fourslash/_scripts/makeManual.mts, package.json]
not_examined: []
