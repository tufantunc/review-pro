<!-- dotnet__aspnetcore@8ac940f correctness-reviewer; verbatim final answer -->
The change keeps the payload format: the new code writes the same bytes as the old `BinaryWriter` path. But the edited usings will likely fail the repo's own CI build.

- severity: Medium
  category: correctness.devex
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 19
  title: The changed usings trigger IDE0005 (unused using) warnings, which CI treats as errors
  evidence: |
    using System;
    using System.Buffers.Binary;
    using System.Buffers;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Diagnostics.CodeAnalysis;
    using System.IO;
    ...
    using System.Buffers.Text;
  evidence_refs: [.editorconfig:278-279, eng/targets/CSharp.Common.targets:44, eng/common/tools.sh:50, src/DataProtection/DataProtection/src/Microsoft.AspNetCore.DataProtection.csproj:5,11]
  impact: |
    The repo sets `dotnet_diagnostic.IDE0005.severity = warning` for `*.cs` files. CSharp.Common.targets enables `EnforceCodeStyleInBuild=true` for src projects. The csproj has `GenerateDocumentationFile=true`, which IDE0005 needs in order to fire during a build. Arcade CI builds with `warn_as_error=true`. Each target framework is compiled separately:
    (a) `System.Buffers.Text` is never used in any target framework. Nothing from Base64/Utf8Parser/Utf8Formatter is referenced.
    (b) On net462 and netstandard2.0, `System.Buffers` and `System.Buffers.Binary` are unused, because `ArrayPool` and `BinaryPrimitives` only appear inside `#if NET10_0_OR_GREATER`.
    (c) On net10.0, `System.IO` is now unused. Its only remaining uses (`MemoryStream`, `BinaryWriter`, `SeekOrigin`) moved into the `#else` branch, at lines 437-480.
    Each case raises IDE0005, so the src build of Microsoft.AspNetCore.DataProtection fails in CI for every target framework.
  remedy: |
    Delete `using System.Buffers.Text;`. Wrap `System.Buffers` and `System.Buffers.Binary` in `#if NET10_0_OR_GREATER`, and `System.IO` in `#if !NET10_0_OR_GREATER`. Alternatively, use fully qualified names inside the conditional blocks.
  confidence: medium
  overlap_hints: [craft]

- severity: Low
  category: correctness.error-path
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 366
  title: The rented ArrayPool buffer is not returned when encoding throws
  evidence: |
    var purposeLengthsPool = ArrayPool<int>.Shared.Rent(purposes.Length);
    for (int i = 0; i < purposes.Length; i++)
    {
        string purpose = purposes[i];
        int purposeLength = EncodingUtil.SecureUtf8Encoding.GetByteCount(purpose);
    ...
    ArrayPool<int>.Shared.Return(purposeLengthsPool);
  impact: |
    `SecureUtf8Encoding` is created with throwOnInvalidBytes: true. A purpose containing a lone surrogate therefore makes `GetByteCount` throw `EncoderFallbackException`, and `Return` is never reached. The thrown exception is the same one the old `BinaryWriter.Write(string)` path threw, so callers see no new behavior. The only cost is that the pooled array is dropped and garbage-collected instead of reused.
  remedy: Wrap the work in try/finally so the buffer is always returned. Or, since purpose counts are small, use `stackalloc int[]` with a heap-array fallback.
  confidence: high
  overlap_hints: [performance]

What I checked on the byte format (no finding):
- **Length encoding:** `Measure7BitEncodedUIntLength` returns 1 for 0..127, 2 for 128..16383, and so on, matching how `BinaryWriter` writes the length prefix. `Write7BitEncodedInt` produces the same bytes as `BinaryWriter.Write7BitEncodedInt`.
- **Purpose count:** `WriteInt32BigEndian(purposes.Length)` gives the same bytes as the old big-endian uint.
- **Key id slot:** the 16-byte key id is still left as zeros at offset 4, which is where `GetAadForKey` fills it in.
- **Null purposes:** both the old and new paths throw `ArgumentNullException`, and `CreateProtector` already rejects null.
- **Constructor signature:** it changed from `IEnumerable<string>` to `string[]` on net10. The only caller, at line 43, passes `string[]`, and the struct is private.

## Files examined
examined: [src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs]
not_examined: []
