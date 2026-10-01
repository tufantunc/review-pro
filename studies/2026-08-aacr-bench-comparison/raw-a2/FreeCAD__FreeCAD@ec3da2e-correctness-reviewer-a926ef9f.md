<!-- FreeCAD__FreeCAD@ec3da2e correctness-reviewer; verbatim final answer -->
## Correctness findings

- severity: Critical
  category: correctness.logic
  file: src/Mod/TechDraw/App/DrawViewPart.cpp
  line: 1502
  title: The new definitions don't match the declarations in DrawViewPart.h, so TechDraw App won't compile
  evidence: |
    // DrawViewPart.cpp:1502 / 1513 / 1523
    bool DrawViewPart::isCosmeticVertex(std::string element)
    bool DrawViewPart::isCosmeticEdge(std::string element)
    bool DrawViewPart::isCenterLine(std::string element)
    // DrawViewPart.h:242-244
    static bool isCosmeticVertex(App::DocumentObject* owner, std::string element);
    static bool isCosmeticEdge(App::DocumentObject* owner, std::string element);
    static bool isCenterLine(App::DocumentObject* owner, std::string element);
  evidence_refs: [src/Mod/TechDraw/App/DrawViewPart.h:242, src/Mod/TechDraw/App/DrawViewPart.h:243, src/Mod/TechDraw/App/DrawViewPart.h:244]
  impact: The .cpp defines three one-argument non-static members. The header declares only two-argument static functions. An out-of-line definition must match a declaration in the class, so each of the three is a compile error ("no declaration matches"). Also, the bodies call the non-static `getProjVertexByIndex` and `getEdge` through an implicit `this`. They could not compile as static functions either. The TechDraw App library does not build.
  remedy: Pick one signature and use it in both files. The commit message ("Removed owner from function head") shows the intent is the one-argument instance method. So change the header to `bool isCosmeticVertex(std::string element);` and the same for the other two, drop `static` and the `owner` parameter, and consider marking them `const`, since `getEdge` and `getProjVertexByIndex` are const.
  confidence: high
  overlap_hints: [api-contract.signature]

- severity: Critical
  category: correctness.side-effect
  file: src/Mod/TechDraw/App/DrawUtil.h
  line: 252
  title: DrawUtil's three helpers were removed while CosmeticExtension still calls them
  evidence: |
    // CosmeticExtension.cpp:70-78 (unchanged)
    if (DU::getGeomTypeFromName(name) == "Vertex" &&
     DU::isCosmeticVertex(getOwner(), name)) {
    ...
     ( DU::isCosmeticEdge(getOwner(), name)  ||
       DU::isCenterLine(getOwner(), name) ) ) {
  evidence_refs: [src/Mod/TechDraw/App/CosmeticExtension.cpp:71, src/Mod/TechDraw/App/CosmeticExtension.cpp:77, src/Mod/TechDraw/App/CosmeticExtension.cpp:78]
  impact: The change deletes `DrawUtil::isCosmeticVertex`, `isCosmeticEdge` and `isCenterLine` from DrawUtil.h and DrawUtil.cpp. `CosmeticExtension::deleteCosmeticElements` still calls all three as `DU::...`, so CosmeticExtension.cpp fails with "no member named ... in DrawUtil". A grep of src/ shows these are the only callers. This is the only code that removes cosmetic vertices, edges and centerlines by selection.
  remedy: Update the calls in CosmeticExtension.cpp to use the new member API. `getOwner()` already returns `TechDraw::DrawViewPart*`, so the calls become `getOwner()->isCosmeticVertex(name)`, `getOwner()->isCosmeticEdge(name)` and `getOwner()->isCenterLine(name)`. This also depends on the first finding's header fix.
  confidence: high
  overlap_hints: [api-contract.breaking-change]

## Files examined
examined: [src/Mod/TechDraw/App/DrawUtil.cpp, src/Mod/TechDraw/App/DrawUtil.h, src/Mod/TechDraw/App/DrawViewPart.cpp, src/Mod/TechDraw/App/DrawViewPart.h]
not_examined: []
