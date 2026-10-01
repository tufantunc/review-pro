<!-- laravel__framework@180c25f craft-reviewer; verbatim final answer -->
- severity: Medium
  category: craft.code-judo
  file: tests/Validation/ValidationEmailRuleTest.php
  line: 325
  title: Four matrix tests use 15 hand-written foreach loops; one data-provider table would replace them
  evidence: |
    foreach ($emailsThatPassOnRfcCompliantButFailOnStrict as $email) {
        $this->passes(
            Rule::email()->rfcCompliant(),
            $email
        );

        $this->fails(
            Rule::email()->rfcCompliant(strict: true),
            $email,
            ['The '.self::ATTRIBUTE_REPLACED.' must be a valid email address.']
        );
    }
    ...
    foreach ($emailsThatFailNativePassStrict as $email) {
        $this->fails(
            Rule::email()->withNativeValidation(),
    ...
  impact: testPassesRfcCompliantButNotRfcCompliantStrict, testWithNativeValidationAsciiVsUnicode, testNativeValidationVsRfcCompliant and testNativeValidationVsRfcCompliantStrict all repeat one pattern 15 times, at lines 341, 372, 404, 425, 448, 474, 501, 520, 551, 591, 617, 642, 661, 680 and 707. Each loop takes a list of emails, runs two rule modes over it, and checks a pass/fail pair. As a result, one address's expected behaviour is split across several methods. For example, `some(comment)@example.com` appears at lines 329, 538 and 698, `abc."test"@example.com` at 330, 584 and 635, and `name@[127.0.0.1]` at 334, 585 and 636. To check or change what one address should do, a reader has to find every copy and work out which pair of modes each list belongs to. This change takes the file from about 525 to 928 lines, close to the 1k limit. Also, a failure inside a loop stops that whole test method at the first bad address, so the rest of the addresses never run.
  remedy: Replace the four methods with one table-driven test, which is already the convention in this directory. ValidationEnumRuleTest.php:104/252 uses `#[DataProvider('conditionalCasesDataProvider')]`, and ValidationValidatorTest.php:4519-4545 uses `validUrls`/`invalidUrls`. Add a static provider with one row per address that gives the expected result for each mode, for example `'"has space"@example.com' => ['"has space"@example.com', native: false, nativeUnicode: false, rfc: true, strict: false]`. Then write one `#[DataProvider('emailModeMatrix')]` test that maps each mode to its rule (`withNativeValidation()`, `withNativeValidation(allowUnicode: true)`, `rfcCompliant()`, `rfcCompliant(strict: true)`) and asserts pass or fail. That removes every loop, every list variable, the duplicated addresses and the empty placeholder list. Each address is then stated once, and PHPUnit reports each failing row by name.
  confidence: high
  evidence_refs: [tests/Validation/ValidationEnumRuleTest.php:104, tests/Validation/ValidationValidatorTest.php:4519]
  overlap_hints: [dry.duplication, tests.structure]

- severity: Low
  category: craft.code-judo
  file: tests/Validation/ValidationEmailRuleTest.php
  line: 516
  title: Leftover empty list (`// none I could find`) feeds a loop that never runs
  evidence: |
    $emailsThatPassNativeFailRfc = [
        // none I could find
    ];

    foreach ($emailsThatPassNativeFailRfc as $email) {
        $this->passes(
            Rule::email()->withNativeValidation(),
    ...
  impact: This is 16 lines of code that cannot execute. It looks like a test case but asserts nothing, and the first-person comment is a draft note left in the framework's test suite.
  remedy: Delete lines 516-531. If the empty set is worth recording, state it once as a note on the native-vs-RFC rows of the matrix suggested above.
  confidence: high
  overlap_hints: [tests.dead-code]

- severity: Low
  category: craft.abstraction
  file: tests/Validation/ValidationEmailRuleTest.php
  line: 113
  title: The same expected-message array is written out 44 times
  evidence: |
    ['The '.self::ATTRIBUTE_REPLACED.' must be a valid email address.']
  impact: The same message array literal appears 44 times. Almost every `fails()` call passes it, so the one argument that varies (the message in testMacro and testValidationMessages) is hard to spot. If the message wording changes, it has to be edited 44 times.
  remedy: Make it a class constant (for example `private const DEFAULT_MESSAGE = ...`), or give `fails()` a default of `$expectedMessages = null` that resolves to that message. Callers then pass a message only when it differs (testMacro, testValidationMessages).
  confidence: high
  overlap_hints: [dry.duplication]

- severity: Low
  category: craft.code-judo
  file: tests/Validation/ValidationEmailRuleTest.php
  line: 354
  title: One test has two lists with the same meaning, and its name covers only one of its four groups
  evidence: |
    public function testPassesRfcCompliantButNotRfcCompliantStrict()
    ...
        $emailsThatPassOnBothRfcCompliantAndOnStrict = [
            'plainaddress@example.com',
    ...
        $emailsThatPassOnBoth = [
            'plainaddress@example.com',
            'tést@example.com',
  impact: '$emailsThatPassOnBothRfcCompliantAndOnStrict' (line 354) and '$emailsThatPassOnBoth' (line 418) mean the same thing and run the same two assertions. They even share 'plainaddress@example.com'. The method name promises only the "passes RFC, fails strict" group, but the method also asserts the pass-both and fail-both groups.
  remedy: Merge the two lists into one and name the test after the comparison it makes (for example testRfcCompliantVsStrict). The data-provider matrix in the first finding fixes this as well.
  confidence: high
  overlap_hints: [tests.naming]

- severity: Nitpick
  category: craft.code-judo
  file: tests/Validation/ValidationEmailRuleTest.php
  line: 106
  title: Variable name contradicts its value, and some comments contradict their lists
  evidence: |
    $emailThatFailsBothNonStrictButFailsInStrict = 'username@sub..example.com';
    ...
    'user@[IPv6:::]',                       // invalid shorthand IPv6
    ...
    /**
     * Addresses that fail withNativeValidation (ASCII-only) but pass rfcCompliant().
     * Typical scenario for emails with accented or Unicode local parts.
     */
  impact: The variable name says "fails both ... but fails in strict", which makes no sense. The address actually fails both modes: the same address is in `$emailsThatFailOnBoth` at line 390. At line 337, a comment calls the address "invalid", but it sits in the list expected to pass rfcCompliant. At line 534, the docblock says the list is about accented or Unicode local parts, but most entries are comments, quoted local parts, addresses with no TLD, or IPv4-like domains. Readers are told the opposite of what the code asserts.
  remedy: Rename it to `$emailThatFailsBoth`. Reword line 337 to say why non-strict RFC accepts the address. Make the line 534 docblock describe the list's real contents, or drop it.
  confidence: high
  overlap_hints: [tests.naming]

- severity: Nitpick
  category: craft.code-judo
  file: tests/Validation/ValidationEmailRuleTest.php
  line: 89
  title: Style is inconsistent within the file (trailing commas, named arguments, comment form and spacing)
  evidence: |
    $v->messages()->toArray(),
    'Expected different message for email input '.$value,
    );
    ...
    Rule::email()->rfcCompliant(true),            // line 649
    Rule::email()->rfcCompliant(strict: true),    // line 348
    ...
    /**
     * Emails that fail ASCII-only native validation but pass with Unicode turned on.
     */
    $emailsThatFailOnAsciiButPassOnUnicode = [
    ...
    'admin@examрle.com',// Contains a Cyrillic 'р' (U+0440), not a Latin 'p'
  impact: |
    The diff removes trailing commas from every multi-line call in the file but adds a new one at line 89. Some calls pass `rfcCompliant(true)` (lines 649, 669, 687, 715) and others `rfcCompliant(strict: true)`, so readers can't tell whether the two forms differ. Docblocks (`/** */`) are used as inline comments inside method bodies (lines 440, 461, 488, 533, 564, 602), where Laravel uses `//`. Lines 174 and 180 have `,//` with no space before the comment. Trailing comments are misaligned at lines 444-445, 465-466 and 698-704.
  remedy: Choose one trailing-comma style for multi-line calls and use it everywhere. Use `rfcCompliant(strict: true)` throughout. Use `//` for comments inside method bodies. Add the missing space before `//` and align the trailing comment columns.
  confidence: medium
  overlap_hints: []

## Files examined
examined: [tests/Validation/ValidationEmailRuleTest.php]
not_examined: []
