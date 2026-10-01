<!-- FreeCAD__FreeCAD@ec3da2e api-contract-reviewer; verbatim final answer -->
The build is broken in two places:

1. The new `DrawViewPart` definitions don't match their declarations.
2. The `DrawUtil` functions were deleted, but their only caller still uses them.

- severity: Critical
  category: api-contract.breaking
  file: src/Mod/TechDraw/App/DrawViewPart.h
  line: 242
  title: The header declares static 2-argument functions, but the .cpp defines non-static 1-argument member functions, so the signatures don't match
  evidence: |
    // DrawViewPart.h:242-244
    static bool isCosmeticVertex(App::DocumentObject* owner, std::string element);
    static bool isCosmeticEdge(App::DocumentObject* owner, std::string element);
    static bool isCenterLine(App::DocumentObject* owner, std::string element);
    // DrawViewPart.cpp:1502, 1513, 1523
    bool DrawViewPart::isCosmeticVertex(std::string element)
    bool DrawViewPart::isCosmeticEdge(std::string element)
    bool DrawViewPart::isCenterLine(std::string element)
  evidence_refs: [src/Mod/TechDraw/App/DrawViewPart.cpp:1502, src/Mod/TechDraw/App/DrawViewPart.cpp:1513, src/Mod/TechDraw/App/DrawViewPart.cpp:1523]
  impact: DrawViewPart.cpp won't compile, because the out-of-line definitions `DrawViewPart::isCosmeticVertex(std::string)` etc. don't match any declaration in the class (error: "no declaration matches"). The new bodies also call instance members (`getProjVertexByIndex`, `getEdge`), so they can't simply be made static. Even if the build passed, the declared public API (static, takes owner) and the implemented one (instance method, element only) contradict each other. The whole TechDraw App module fails to build.
  remedy: Make the header match the implementation. Declare them as non-static instance methods, e.g. `bool isCosmeticVertex(const std::string& element) const;` (and the same for the other two). Recent commits "Removed owner from function head" suggest this was the intent. Make getProjVertexByIndex/getEdge const-callable if you add `const`, or leave `const` off.
  confidence: high
  overlap_hints: [correctness.build]

- severity: Critical
  category: api-contract.breaking
  file: src/Mod/TechDraw/App/DrawUtil.h
  line: 252
  title: Exported DrawUtil functions were removed, but their only caller in CosmeticExtension still calls them
  evidence: |
    -    static bool isCosmeticVertex(App::DocumentObject* owner, std::string element);
    -    static bool isCosmeticEdge(App::DocumentObject* owner, std::string element);
    -    static bool isCenterLine(App::DocumentObject* owner, std::string element);
    // CosmeticExtension.cpp:70-78 (unchanged)
    if (DU::getGeomTypeFromName(name) == "Vertex" &&
     DU::isCosmeticVertex(getOwner(), name)) {
    ...
     ( DU::isCosmeticEdge(getOwner(), name)  ||
       DU::isCenterLine(getOwner(), name) ) ) {
  evidence_refs: [src/Mod/TechDraw/App/CosmeticExtension.cpp:71, src/Mod/TechDraw/App/CosmeticExtension.cpp:77, src/Mod/TechDraw/App/CosmeticExtension.cpp:78]
  impact: CosmeticExtension::deleteCosmeticElements calls three functions that no longer exist in DrawUtil, so CosmeticExtension.cpp fails to compile ("no member named 'isCosmeticVertex' in 'TechDraw::DrawUtil'"). DrawUtil is a TechDrawExport public class. Any out-of-tree C++ code that links against TechDraw and uses these statics also breaks, with no deprecation shim.
  remedy: Update CosmeticExtension.cpp:71/77/78 to `getOwner()->isCosmeticVertex(name)`, `getOwner()->isCosmeticEdge(name)` and `getOwner()->isCenterLine(name)`. `getOwner()` already returns a `DrawViewPart*`. Optionally, keep thin deprecated forwarding wrappers in DrawUtil for one release to protect external consumers of the exported API.
  confidence: high
  overlap_hints: [correctness.build]

## Files examined
examined: [src/Mod/TechDraw/App/DrawUtil.cpp, src/Mod/TechDraw/App/DrawUtil.h, src/Mod/TechDraw/App/DrawViewPart.cpp, src/Mod/TechDraw/App/DrawViewPart.h]
not_examined: []
