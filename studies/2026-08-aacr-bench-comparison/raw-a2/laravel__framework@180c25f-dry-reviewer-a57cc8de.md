<!-- laravel__framework@180c25f dry-reviewer; verbatim final answer -->
## DRY findings

- severity: Medium
  category: dry.canonical-helper
  file: tests/Validation/ValidationEmailRuleTest.php
  line: 341
  title: 15 new `foreach ($emails… as $email)` loops do work that `passes()`/`fails()` already do, since both accept an array
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
  impact: The same 10–15 line loop appears 15 times, at lines 341, 372, 404, 425, 448, 474, 501, 520, 551, 591, 617, 642, 661, 680 and 707. The helper the diff targets already loops over values. The diff also adds the input value to that helper's assertion messages (line 84, `'Expected email input '.$value...`), so a failure would show the same information without these loops. About 150 lines of loop code could go.
  remedy: Pass the arrays straight to the existing helpers. `passes()` and `fails()` are documented as `@param string|array $values` (lines 52, 96), and `assertValidationRules` calls `Arr::wrap($values)` and loops at lines 72–76. For example, `$this->passes(Rule::email()->rfcCompliant(), $emailsThatPassOnRfcCompliantButFailOnStrict); $this->fails(Rule::email()->rfcCompliant(strict: true), $emailsThatPassOnRfcCompliantButFailOnStrict, $msg);`. Another option is the repo's `#[DataProvider]` convention, as in tests/Validation/ValidationValidatorTest.php:4519–4535 (`validUrls`/`invalidUrls`) and tests/Validation/ValidationEnumRuleTest.php:104,252.
  evidence_refs: [tests/Validation/ValidationEmailRuleTest.php:72, tests/Validation/ValidationEmailRuleTest.php:52, tests/Validation/ValidationValidatorTest.php:4519]
  confidence: high
  overlap_hints: [craft.code-judo, tests.structure]

- severity: Medium
  category: dry.copy-paste
  file: tests/Validation/ValidationEmailRuleTest.php
  line: 567
  title: The 14-entry "valid plain address" list is copied word for word between two test methods
  evidence: |
    $emailsThatPassBoth = [
        'plainaddress@example.com',
        'joe.smith@example.io',
        'custom-tag+dev@example.org',
        'hyphens--@example.org',
        'underscore_name@example.co.uk',
        'underscores__@example.org',
        'user@subdomain.example.com',
        'numbers123@domain.com',
        'john-doe@some-domain.com',
        'UPPERlower@example.org',
        'dots.ok@sub.domain.io',
        'some_email+tag@domain.dev',
        'a@b.c',
        'user@xn--bcher-kva.example',    // Punycode for user@bücher.example
  impact: Lines 568–581 repeat lines 355–368 in `testPassesRfcCompliantButNotRfcCompliantStrict` entry for entry. Other inputs are scattered across the matrices too. `'пример@пример.рф'`, `'例子@例子.公司'` and `'name@123.123.123.123'` appear at 469–471, 546–548 and 656–658. `'username@domain-with-hyphen-.com'` appears at 394, 468 and 614. `'"has space"@example.com'` appears at 107, 328, 542 and 699. `'user@[IPv6:2001:db8:1ff::a0b:dbd0]'` appears at 497, 588 and 638. If an input's classification changes, for example after an egulias/email-validator upgrade, every copy has to be found and updated by hand, and the lists will drift apart.
  remedy: Define each shared corpus once, as a private const or a static provider method (e.g. `VALID_PLAIN_ADDRESSES`, `UNICODE_IDN_ADDRESSES`). Each matrix test then references it or adds its own entries with array spreads. The repo's static-provider convention is at tests/Validation/ValidationValidatorTest.php:4535 (`public static function validUrls()`).
  evidence_refs: [tests/Validation/ValidationEmailRuleTest.php:355, tests/Validation/ValidationEmailRuleTest.php:469, tests/Validation/ValidationEmailRuleTest.php:546, tests/Validation/ValidationEmailRuleTest.php:656]
  confidence: high
  overlap_hints: [craft.abstraction]

- severity: Low
  category: dry.copy-paste
  file: tests/Validation/ValidationEmailRuleTest.php
  line: 418
  title: The same method has two "passes on both" arrays and two identical loops
  evidence: |
    $emailsThatPassOnBoth = [
        'plainaddress@example.com',
        'tést@example.com',
        'user@üñîçødé.com',
        'test@xn--bcher-kva.com',
    ];

    foreach ($emailsThatPassOnBoth as $email) {
        $this->passes(
            Rule::email()->rfcCompliant(),
            $email
        );

        $this->passes(
            Rule::email()->rfcCompliant(strict: true),
            $email
  impact: In `testPassesRfcCompliantButNotRfcCompliantStrict`, `$emailsThatPassOnBothRfcCompliantAndOnStrict` (line 354) and `$emailsThatPassOnBoth` (line 418) are the same category. Lines 372–382 and 425–435 run the same assertions on them, and `'plainaddress@example.com'` is in both lists (lines 355 and 419). Readers will look for a difference between the two blocks that isn't there.
  remedy: Merge the four Unicode/punycode entries into the array at line 354, delete lines 418–435, and pass the merged array once to `passes()` (see the first finding).
  evidence_refs: [tests/Validation/ValidationEmailRuleTest.php:354, tests/Validation/ValidationEmailRuleTest.php:372]
  confidence: high
  overlap_hints: [craft.code-judo]

- severity: Low
  category: dry.missing-abstraction
  file: tests/Validation/ValidationEmailRuleTest.php
  line: 350
  title: The default email error message is still written out at every `fails()` call; the diff raises the count from 30 to 44
  evidence: |
    ['The '.self::ATTRIBUTE_REPLACED.' must be a valid email address.']
  impact: The pattern already existed (30 copies at the merge base). The change adds 14 more copies of the same literal, most inside the new loops. Changing the translation line in `setUp()` (line 909) means editing 44 places.
  remedy: Default the expected message in the existing helper. Give `fails()` (line 57) a default of `null` for `$expectedMessages` that resolves to a single class constant or private method such as `defaultMessage()`. Only `testMacro` and `testValidationMessages` (lines 802, 887, 894) need a different message and would keep passing one explicitly.
  evidence_refs: [tests/Validation/ValidationEmailRuleTest.php:57, tests/Validation/ValidationEmailRuleTest.php:909]
  confidence: high
  overlap_hints: [craft.abstraction]

Overlap with the existing tests: `ValidationValidatorTest::testValidateEmail*` (tests/Validation/ValidationValidatorTest.php:4413–4501) runs only one to four single-value checks per string-rule mode (`email:strict`, `email:filter`, `email:filter_unicode`). The pass/fail matrices are new coverage, written against the `Rules\Email` object. The two files overlap in one place only: `exämple@example.com` with filter vs. filter_unicode (lines 4469 and 4485) tests the same thing as `déjà@example.com` in `testWithNativeValidationAsciiVsUnicode` (line 444). That is one case at a different layer (string rule vs. rule object), so I'm not filing it as a duplicate.

## Files examined
examined: [tests/Validation/ValidationEmailRuleTest.php]
not_examined: []
