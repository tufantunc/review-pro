<!-- dotnet__aspnetcore@8ac940f ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 356
  title: New `#if NET10_0_OR_GREATER` guard doesn't match the TFM symbols DataProtection already uses
  evidence: |
    #if NET10_0_OR_GREATER
            public AdditionalAuthenticatedDataTemplate(string[] purposes)
  impact: Across src/DataProtection the guards in use are `NETCOREAPP` (7), `NET7_0_OR_GREATER` (32), `NETSTANDARD2_0` (22), `NETFRAMEWORK` (5) and `NET6_0_OR_GREATER` (1). This `NET10_0_OR_GREATER` is the only one in the area, and this change adds it. It's also stricter than the APIs need: `BinaryPrimitives`, `ArrayPool`, `BitOperations` and `Encoding.GetBytes(ReadOnlySpan<char>, Span<byte>)` all exist from netcoreapp3.0. For example, src/DataProtection/DataProtection/src/Managed/AesGcmAuthenticatedEncryptor.cs:4 uses `#if NETCOREAPP` for the same kind of span-based fast path. Today the result is the same because `DefaultNetCoreTargetFramework` is `net10.0` (eng/Versions.props:46). The guard just reads as a one-off.
  remedy: Use `#if NETCOREAPP` to match the existing span fast paths in this project.
  confidence: high
  overlap_hints: [craft.boundary]
  evidence_refs: [src/DataProtection/DataProtection/src/Managed/AesGcmAuthenticatedEncryptor.cs:4, eng/Versions.props:46]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 19
  title: `System.Buffers.Text` is never used, and the new usings break the repo's sorting rule
  evidence: |
    using System;
    using System.Buffers.Binary;
    using System.Buffers;
    ...
    using Microsoft.Extensions.Logging;
    using System.Buffers.Text;
  impact: Nothing in the file uses a `System.Buffers.Text` type: the only buffer APIs are `BinaryPrimitives` (System.Buffers.Binary) and `ArrayPool<T>` (System.Buffers). Its placement after the `Microsoft.*` block breaks `dotnet_sort_system_directives_first = true` (.editorconfig:24). `System.Buffers.Binary` coming before `System.Buffers` isn't alphabetical, which looks like the usings were pasted in rather than sorted. All three usings also sit outside the `#if`, so on the netfx and netstandard2.0 targets they're unused, and they compile only if a transitive System.Memory or System.Buffers reference happens to supply those namespaces. The DataProtection csproj doesn't reference either package directly.
  remedy: Delete `using System.Buffers.Text;`. Sort to `using System.Buffers;` then `using System.Buffers.Binary;`, either inside the `NETCOREAPP` guard or kept with the System group. Add `using System.Numerics;` the same way instead of the fully qualified `System.Numerics.BitOperations` at line 405.
  confidence: high
  overlap_hints: [craft.style]
  evidence_refs: [.editorconfig:24, src/DataProtection/DataProtection/src/Microsoft.AspNetCore.DataProtection.csproj:26-48]

- severity: Nitpick
  category: ai-antipatterns.over-engineering
  file: src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs
  line: 405
  title: Unreachable commented-out code after a `return`
  evidence: |
            return ((31 - System.Numerics.BitOperations.LeadingZeroCount(value | 1)) / 7) + 1;

            // does the same as the following code:
            // int count = 1;
            // while ((value >>= 7) != 0)
  impact: A commented-out loop after the `return` is padding that looks like a pasted explanation. The `Write7BitEncodedInt` comment about the "0x7F and ~0x7F" codegen is copied from the BCL's `BinaryWriter.Write7BitEncodedInt`. Neither tells a maintainer what this file depends on: the output must match the `BinaryWriter.Write(string)` length prefix still used by the `#else` branch.
  remedy: Replace both with one line saying the encoding must match `BinaryWriter`'s 7-bit length prefix (the `#else` path) so the AAD bytes stay identical across TFMs.
  confidence: medium
  overlap_hints: [craft.readability]

## Files examined
examined: [src/DataProtection/DataProtection/src/KeyManagement/KeyRingBasedDataProtector.cs]
not_examined: []
