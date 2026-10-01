<!-- dotnet__aspnetcore@8ac940f craft-reviewer; verbatim final answer -->
## Craft findings

- severity: Medium
  category: craft.code-judo
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 356
  title: The AAD wire format now has two serializers, split by a TFM gate the rest of the repo doesn't use
  evidence: |
    #if NET10_0_OR_GREATER
            public AdditionalAuthenticatedDataTemplate(string[] purposes)
            {
                ...
                BinaryPrimitives.WriteUInt32BigEndian(targetSpan.Slice(0), MAGIC_HEADER_V0);
                ...
                BinaryPrimitives.WriteInt32BigEndian(targetSpan.Slice(4 + keySize), purposes.Length);
    ...
    #else
            public AdditionalAuthenticatedDataTemplate(IEnumerable<string> purposes)
            {
                const int MEMORYSTREAM_DEFAULT_CAPACITY = 0x100;
                var ms = new MemoryStream(MEMORYSTREAM_DEFAULT_CAPACITY);
                using (var writer = new PurposeBinaryWriter(ms))
    ...
    #endif
  impact: |
    The AAD layout `{ magicHeader || keyId || purposeCount || (7-bit len || utf8)* }` is a security-sensitive wire format. Data protected on one TFM must unprotect on another. After this change it is built by two unrelated code paths: span plus hand-written varint on one side, and BinaryWriter/MemoryStream plus PurposeBinaryWriter on the other. Every future change to the format has to be made twice and kept byte-identical by hand. Nothing ties the two paths together.
    The constructor signature also differs by TFM (`string[]` vs `IEnumerable<string>`).
    The gate is `NET10_0_OR_GREATER`, which no other file in `src/` uses (grep finds only this file). The same file uses `#if NETCOREAPP / #elif NETSTANDARD2_0 || NETFRAMEWORK / #else #error` for ReadGuid at line 144 and WriteGuid at line 297, and the rest of DataProtection follows that pattern too (AesGcmAuthenticatedEncryptor.cs:4, AuthenticatedEncryptorFactory.cs:58). Every API the new path calls (BinaryPrimitives, ArrayPool, `Encoding.GetBytes(ReadOnlySpan<char>, Span<byte>)`, BitOperations) is available under NETCOREAPP, so the version gate is arbitrary.
  remedy: |
    Collapse to one implementation for all TFMs and delete the `#else` branch, the MemoryStream, and PurposeBinaryWriter. The struct already lives in an `unsafe` class that has the canonical helper `WriteBigEndianInteger(byte*, uint)` (line 311). Write the array through `fixed (byte* p = targetArr)`:
    - use `WriteBigEndianInteger` for the header and the count;
    - use `Encoding.GetByteCount(string)` and `Encoding.GetBytes(char*, int, byte*, int)`, both available on netstandard2.0 and net462;
    - use the loop form of the varint length that is already sitting in the comment.
    That leaves a single serializer and no TFM split.
    If the author wants to keep the split, the minimum fix is to gate on `NETCOREAPP` with the file's `#elif NETSTANDARD2_0 || NETFRAMEWORK / #else #error Update target frameworks` convention, and to give both constructors the same parameter type.
  confidence: medium
  overlap_hints: [dry.duplication, correctness.cross-tfm]

- severity: Low
  category: craft.abstraction
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 365
  title: ArrayPool round-trip and magic `4`s add moving parts instead of using the file's own idioms
  evidence: |
            var keySize = sizeof(Guid);
            int totalPurposeLen = 4 + keySize + 4;

            var purposeLengthsPool = ArrayPool<int>.Shared.Rent(purposes.Length);
            ...
            int index = 4 + keySize + 4; // starting from first purpose
            ...
            ArrayPool<int>.Shared.Return(purposeLengthsPool);
  impact: |
    The header-size expression `4 + keySize + 4` is spelled out three times with bare literals. Elsewhere the file writes `sizeof(uint) + sizeof(Guid)` (lines 117, 196, 280, 328). The rent/return pair adds a lifetime to manage just to cache a handful of ints in a constructor that runs once per protector. The return is also not in a `finally` block.
  remedy: |
    Define one `const int HeaderSize = sizeof(uint) + sizeof(Guid) + sizeof(uint);` (or inline `sizeof(...)` terms) and use it for both the initial total and the starting index. Drop the pool and call `GetByteCount(purpose)` again in the write loop, which is cheap for purpose strings. If caching is kept, use `stackalloc int[]` with a small-count threshold rather than ArrayPool.
  confidence: medium
  overlap_hints: [performance.allocation]

- severity: Nitpick
  category: craft.abstraction
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 19
  title: Unused, out-of-order using and commented-out dead code
  evidence: |
    using System.Buffers.Binary;
    using System.Buffers;
    ...
    using Microsoft.Extensions.Logging;
    using System.Buffers.Text;
    ...
                // does the same as the following code:
                // int count = 1;
                // while ((value >>= 7) != 0)
  impact: |
    `System.Buffers.Text` is never referenced (grep finds no Base64 or Utf8Formatter use in the file). It is also appended after the `Microsoft.*` group, and `System.Buffers.Binary` is placed before `System.Buffers`. The commented-out loop is dead code that will drift from the live code.
  remedy: Remove `using System.Buffers.Text;`, sort the usings, and replace the commented-out block with a one-line comment such as "equivalent to counting 7-bit groups".
  confidence: high
  overlap_hints: [ai-antipatterns.dead-code]

## Files examined
examined: [src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs]
not_examined: []
