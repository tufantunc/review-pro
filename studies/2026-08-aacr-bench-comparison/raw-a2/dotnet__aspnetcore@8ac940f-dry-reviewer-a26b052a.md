<!-- dotnet__aspnetcore@8ac940f dry-reviewer; verbatim final answer -->
## DRY findings

- severity: Medium
  category: dry.copy-paste
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 416
  title: Write7BitEncodedInt is a copy of FormatterBinaryWriter.Write7BitEncodedInt, comments included
  evidence: |
    private static int Write7BitEncodedInt(int value, Span<byte> target)
    {
        uint uValue = (uint)value;

        // Write out an int 7 bits at a time. The high bit of the byte,
        // when on, tells reader to continue reading more bytes.
        //
        // Using the constants 0x7F and ~0x7F below offers smaller
        // codegen than using the constant 0x80.

        int index = 0;
        while (uValue > 0x7Fu)
        {
            target[index++] = (byte)(uValue | ~0x7Fu);
            uValue >>= 7;
        }

        target[index++] = (byte)uValue;
        return index;
    }
  evidence_refs: [src/Middleware/OutputCaching/src/FormatterBinaryWriter.cs:140, src/SignalR/common/Shared/BinaryMessageFormatter.cs:20]
  impact: The repo now has at least three hand-written copies of the 7-bit/VarInt encoder (OutputCaching `FormatterBinaryWriter.Write7BitEncodedInt`, SignalR shared `BinaryMessageFormatter.WriteLengthPrefix(long, Span<byte>)`, and this one). Each was copied separately from the BCL `BinaryWriter.Write7BitEncodedInt`. A fix or perf change made to one copy will not reach the others. Here the encoding is part of the DataProtection AAD wire format, so it must stay byte-identical to `BinaryWriter.Write(string)`, which the `#else` path still uses.
  remedy: Move one span-based `Write7BitEncodedInt(uint, Span<byte>) -> int` and its length-measure function into a single file under `src/Shared/` (for example `src/Shared/Encoding/SevenBitEncoding.cs`). Include it with `<Compile Include="$(SharedSourceRoot)..." LinkBase="Shared" />` the way the DataProtection csproj already includes `ArgumentNullThrowHelper.cs`. Use it here, and preferably also from `BinaryMessageFormatter.WriteLengthPrefix(long, Span<byte>)` (src/SignalR/common/Shared/BinaryMessageFormatter.cs:20). At minimum, add a comment pointing to the existing copy at src/Middleware/OutputCaching/src/FormatterBinaryWriter.cs:140 and to the BCL `BinaryWriter.Write7BitEncodedInt` it mirrors.
  confidence: high
  overlap_hints: [craft.code-judo, ai-antipatterns.ignored-convention]

- severity: Low
  category: dry.canonical-helper
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 403
  title: Measure7BitEncodedUIntLength reimplements BinaryMessageFormatter.LengthPrefixLength
  evidence: |
    private static int Measure7BitEncodedUIntLength(uint value)
    {
        return ((31 - System.Numerics.BitOperations.LeadingZeroCount(value | 1)) / 7) + 1;
  evidence_refs: [src/SignalR/common/Shared/BinaryMessageFormatter.cs:41]
  impact: The repo already has a "how many bytes does this VarInt take" function, `BinaryMessageFormatter.LengthPrefixLength(long)` at src/SignalR/common/Shared/BinaryMessageFormatter.cs:41, written as a loop. This adds a second version using bit tricks, and keeps the loop form as commented-out code. Two measurement functions for the same encoding can drift from each other and from their writers. If the measure and the write disagree, the `Debug.Assert(index == targetArr.Length)` trips in debug builds and goes silent in release.
  remedy: Put the measure function in the same shared source file as the consolidated writer from the previous finding, so the length calculation and the writer live together. Optionally replace the loop in `LengthPrefixLength` with the `LeadingZeroCount` form. Delete the commented-out loop at lines 407-413.
  confidence: medium
  overlap_hints: [craft.code-judo]

- severity: Low
  category: dry.duplication
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 357
  title: The AAD wire format now has two independent encoders, one per TFM branch
  evidence: |
    #if NET10_0_OR_GREATER
            public AdditionalAuthenticatedDataTemplate(string[] purposes)
            {
                // additionalAuthenticatedData := { magicHeader (32-bit) || keyId || purposeCount (32-bit) || (purpose)* }
                // purpose := { utf8ByteCount (7-bit encoded) || utf8Text }
    ...
    #else
            public AdditionalAuthenticatedDataTemplate(IEnumerable<string> purposes)
            {
                ...
                // additionalAuthenticatedData := { magicHeader (32-bit) || keyId || purposeCount (32-bit) || (purpose)* }
                // purpose := { utf8ByteCount (7-bit encoded) || utf8Text }
  evidence_refs: [src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs:436]
  impact: The same security-sensitive serialization format, including the layout comment, is now written twice. One copy uses manual span offsets (`4 + keySize + 4`) and the other uses `BinaryWriter` with Seek. Payloads protected on one TFM must unprotect on another, so any later format change has to be made in both places in lockstep. Nothing in the code enforces that the two produce the same bytes.
  remedy: Keep a single encoder. Either make the span-based path the only one, using `ArrayPool`/`BinaryPrimitives` (available to netstandard2.0/netfx through System.Buffers/System.Memory) behind a small TFM shim for `Encoding.GetBytes(ReadOnlySpan<char>, Span<byte>)` and `BitOperations`, or keep both and add a test asserting they produce the same bytes for the same purposes. Also replace the magic `4` with the `sizeof(uint)` the rest of the file uses (lines 117, 196, 328).
  confidence: medium
  overlap_hints: [craft.abstraction, tests.missing-coverage]

- severity: Nitpick
  category: dry.duplication
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 381
  title: Two big-endian uint32 write styles now coexist in the same file
  evidence: |
    BinaryPrimitives.WriteUInt32BigEndian(targetSpan.Slice(0), MAGIC_HEADER_V0);
  evidence_refs: [src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs:311, src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs:155]
  impact: The new code correctly uses the BCL `BinaryPrimitives`. The same file still writes `MAGIC_HEADER_V0` with its own pointer-based `WriteBigEndianInteger` at :311 (used at :127) and reads it with `ReadBigEndian32BitInteger` at :155. That is two ways to write the same header field in one class.
  remedy: In a follow-up, route `WriteBigEndianInteger` and `ReadBigEndian32BitInteger` through `BinaryPrimitives.WriteUInt32BigEndian` and `BinaryPrimitives.ReadUInt32BigEndian` on a `Span<byte>`, or delete them. This needs no change to the new code.
  confidence: medium
  overlap_hints: [craft.code-judo]

## Files examined
examined: [src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs]
not_examined: []
