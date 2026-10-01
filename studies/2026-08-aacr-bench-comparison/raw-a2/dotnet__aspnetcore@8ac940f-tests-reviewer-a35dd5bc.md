<!-- dotnet__aspnetcore@8ac940f tests-reviewer; verbatim final answer -->
## Tests findings

- severity: High
  category: tests.coverage
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 427
  title: Multi-byte 7-bit length branch in the new AAD serializer is never exercised
  evidence: |
    int index = 0;
    while (uValue > 0x7Fu)
    {
        target[index++] = (byte)(uValue | ~0x7Fu);
        uValue >>= 7;
    }
  impact: The test project targets only `$(DefaultNetCoreTargetFramework)` (net10.0, eng/Versions.props:46), so every existing test runs the new `#if NET10_0_OR_GREATER` constructor. But every purpose in KeyRingBasedDataProtectorTests.cs is short ASCII ("purpose", "purpose1", "yet another purpose", "single purpose"), each under 128 UTF-8 bytes. No test ever enters the `while` loop in `Write7BitEncodedInt`, and none checks that `Measure7BitEncodedUIntLength` returns 2 or more. The AAD bytes are a persisted compatibility contract. If the length prefix for long purposes is miscounted or written wrong, the buffer is sized wrong (IndexOutOfRange at runtime). It can also produce a different AAD, which would stop existing protected payloads (cookies, antiforgery tokens) from decrypting. CI would catch neither.
  remedy: Add a `[Theory]` that runs the same Protect/AAD check as `Protect_EncryptsToDefaultProtector_MultiplePurposes`, with purposes of UTF-8 length 127, 128, 16383 and 16384 (e.g. `new string('a', 128)`). That covers the 1-to-2 and 2-to-3 byte boundaries. Compare with `BuildAadFromPurposeStrings` (test line 621). It builds the expected bytes with `BinaryWriter.Write(string)`, which is exactly the old MemoryStream-path encoding, so no new helper is needed.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.test-data
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 370
  title: No test uses non-ASCII purposes, so the UTF-8 byte-count vs char-count path is unverified
  evidence: |
    int purposeLength = EncodingUtil.SecureUtf8Encoding.GetByteCount(purpose);
    purposeLengthsPool[i] = purposeLength;
    ...
    index += EncodingUtil.SecureUtf8Encoding.GetBytes(purpose.AsSpan(), targetSpan.Slice(index));
  impact: The new code sizes the buffer and writes the length prefix from `GetByteCount`, then writes the text with `GetBytes`. With all-ASCII test purposes, byte count equals char count. A regression that uses `purpose.Length` instead, or mixes char and byte counts, would pass every existing test, while breaking AAD compatibility for any app whose purpose strings contain non-ASCII characters.
  remedy: Add cases with multi-byte characters, e.g. `"pürpose"`, `"目的"`, and a surrogate pair like `"\U0001F600"`. Also add one where a non-ASCII string pushes the UTF-8 byte length past 127 while the char count stays under 128 (e.g. `new string('é', 64)`, which is 128 bytes). Assert against `BuildAadFromPurposeStrings`.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.coverage
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 405
  title: Zero-length purpose case in `Measure7BitEncodedUIntLength` (`value | 1`) has no test
  evidence: |
    return ((31 - System.Numerics.BitOperations.LeadingZeroCount(value | 1)) / 7) + 1;
  impact: The `| 1` exists only so that an empty purpose (length 0) still measures as 1 byte. `CreateProtector` checks only for null (`ArgumentNullThrowHelper.ThrowIfNull(purpose)`, line 65), so `""` is a valid purpose. No test checks that it produces the single `0x00` length byte the old BinaryWriter path wrote.
  remedy: Add `""` as a purpose, both alone and mixed with other purposes, to the AAD-equality theory proposed above.
  confidence: medium
  overlap_hints: [correctness.logic]

## Files examined
examined: [src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs]
not_examined: []
