<!-- FreeCAD__FreeCAD@82fef4a dry-reviewer; verbatim final answer -->
- severity: Low
  category: dry.missing-abstraction
  file: src/Base/Parameter.cpp
  line: 1887
  title: The new entity-resolver hardening is added to only one of the two parser setups in Parameter.cpp, and they share no setup helper
  evidence: |
    auto parser = std::make_unique<XercesDOMParser>();
    auto entityBlocker = std::make_unique<NoOpEntityResolver>();
    ...
    parser->setDoNamespaces(gDoNamespaces);
    parser->setDoSchema(gDoSchema);
    ...
    parser->setDisableDefaultEntityResolution(true);
    parser->setEntityResolver(entityBlocker.get());
  evidence_refs: [src/Base/Parameter.cpp:2091, src/Base/Parameter.cpp:2103, src/Base/Parameter.cpp:2104, src/Base/Parameter.cpp:2105, src/Base/Parameter.cpp:2107]
  impact: |
    `ParameterManager::CheckDocument` builds its own parser at src/Base/Parameter.cpp:2091. It repeats the same calls: `setDoNamespaces(true)`, `setDoSchema(true)`, `setDisableDefaultEntityResolution(true)`, then attaches a `DOMTreeErrorReporter` and parses the same user parameter file. It does not get the new `setEntityResolver(...)` call. Each of the two sites keeps its own list of security settings, and the new setting went into only one, so the lists have already drifted in this change. The next change to these settings is likely to miss one site too.
  remedy: |
    Move the security settings into one file-local helper, for example `static void hardenParser(XercesDOMParser&, EntityResolver&)`. It would call `setDisableDefaultEntityResolution(true)` and `setEntityResolver(...)`. Call it from both `LoadDocument` (line 1886) and `CheckDocument` (line 2105), and keep one `NoOpEntityResolver` instance next to the parser at each call site. There is no existing repo helper to reuse. I searched src/ for `EntityResolver`, `resolveEntity` and `setEntityResolver` and found no hits outside this diff. The other `XercesDOMParser` setups also configure the parser inline: src/App/ProjectFile.cpp:242, src/App/Metadata.cpp:144, src/Mod/Mesh/App/Core/IO/Reader3MF.cpp:115 (`makeDomParser`) and src/Mod/Cloud/App/AppCloud.cpp:823/1053. So the helper belongs in Parameter.cpp, where the two setups sit next to each other. Promoting it further (for example into XMLTools) is optional.
  confidence: medium
  overlap_hints: [security.xxe, correctness.inconsistent-hardening, craft.abstraction]

The new `NoOpEntityResolver` (src/Base/Parameter.cpp:1863) does not duplicate anything. No other `EntityResolver` subclass or `resolveEntity` override exists in src/, so it is not reinventing a canonical utility. The `std::make_unique` ownership change and the `PreCompiled.h` include (src/Base/PreCompiled.h:107) also add no duplication.

## Files examined
examined: [src/Base/Parameter.cpp, src/Base/PreCompiled.h]
not_examined: []
