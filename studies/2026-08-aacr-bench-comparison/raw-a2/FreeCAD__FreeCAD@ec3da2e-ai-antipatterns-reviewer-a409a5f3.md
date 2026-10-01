<!-- FreeCAD__FreeCAD@ec3da2e ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: Critical
  category: ai-antipatterns.hallucination
  file: src/Mod/TechDraw/App/DrawViewPart.cpp
  line: 1502
  title: The new member definitions don't match the static declarations in DrawViewPart.h, so the translation unit won't compile
  evidence: |
    // DrawViewPart.h:242-244 (added)
        static bool isCosmeticVertex(App::DocumentObject* owner, std::string element);
        static bool isCosmeticEdge(App::DocumentObject* owner, std::string element);
        static bool isCenterLine(App::DocumentObject* owner, std::string element);
    // DrawViewPart.cpp:1502,1513,1523 (added)
    bool DrawViewPart::isCosmeticVertex(std::string element)
    bool DrawViewPart::isCosmeticEdge(std::string element)
    bool DrawViewPart::isCenterLine(std::string element)
  evidence_refs: [src/Mod/TechDraw/App/DrawViewPart.h:242, src/Mod/TechDraw/App/DrawViewPart.h:243, src/Mod/TechDraw/App/DrawViewPart.h:244]
  impact: |
    The change assumes the class declares one-argument non-static members named `DrawViewPart::isCosmeticVertex/isCosmeticEdge/isCenterLine(std::string)`. It doesn't: the header only declares static two-argument versions that take `(App::DocumentObject*, std::string)`. An out-of-class definition must match a declaration, so each of the three definitions fails with "no declaration matches 'bool DrawViewPart::isCosmeticVertex(std::string)'". The bodies also call the instance members `getProjVertexByIndex` and `getEdge` (DrawViewPart.h:164, 170). Those calls only work from a non-static member, so simply adding `static` to the definitions would not fix it either. The commit history shows the header and source were edited separately: "Updated ownership of member functions & updated headers", then "Removed owner from function head". The header never got the second edit.
  remedy: |
    Make DrawViewPart.h:242-244 declare the non-static one-argument form, e.g. `bool isCosmeticVertex(const std::string& element) const;`. The `getEdge` and `getProjVertexByIndex` members these call are already const. Remove the `static` and the `owner` parameter.
  confidence: high
  overlap_hints: [correctness.build-break, api-contract.signature]

- severity: Critical
  category: ai-antipatterns.hallucination
  file: src/Mod/TechDraw/App/DrawUtil.h
  line: 252
  title: DrawUtil::isCosmeticVertex/isCosmeticEdge/isCenterLine were removed, but CosmeticExtension.cpp still calls them
  evidence: |
    -    static bool isCosmeticVertex(App::DocumentObject* owner, std::string element);
    -    static bool isCosmeticEdge(App::DocumentObject* owner, std::string element);
    -    static bool isCenterLine(App::DocumentObject* owner, std::string element);
    // src/Mod/TechDraw/App/CosmeticExtension.cpp:71,77-78 (unchanged)
             DU::isCosmeticVertex(getOwner(), name)) {
             ( DU::isCosmeticEdge(getOwner(), name)  ||
               DU::isCenterLine(getOwner(), name) ) ) {
  evidence_refs: [src/Mod/TechDraw/App/CosmeticExtension.cpp:71, src/Mod/TechDraw/App/CosmeticExtension.cpp:77, src/Mod/TechDraw/App/CosmeticExtension.cpp:78]
  impact: |
    The move assumes nothing else calls these helpers. A search of `src/` and `tests/` found exactly one caller, `CosmeticExtension::deleteCosmeticElements`, and it still uses `DU::` (DrawUtil). With the helpers gone from DrawUtil, CosmeticExtension.cpp fails with "no member named 'isCosmeticVertex' in 'TechDraw::DrawUtil'", and the same for the other two. `getOwner()` already returns `TechDraw::DrawViewPart*` (CosmeticExtension.cpp:60-63), so the caller can switch straight to the member form.
  remedy: |
    Update CosmeticExtension.cpp:71,77,78 to `getOwner()->isCosmeticVertex(name)`, `getOwner()->isCosmeticEdge(name)` and `getOwner()->isCenterLine(name)`, which match the definitions once the header is fixed. Include it in the same commit.
  confidence: high
  overlap_hints: [correctness.build-break, api-contract.breaking-change]

- severity: Nitpick
  category: ai-antipatterns.ignored-convention
  file: src/Mod/TechDraw/App/DrawViewPart.cpp
  line: 1501
  title: The moved comments still say "owner->element" after the owner parameter was dropped
  evidence: |
    // true if owner->element is a cosmetic vertex
    bool DrawViewPart::isCosmeticVertex(std::string element)
  impact: The comments were copied unchanged from the DrawUtil static helpers and no longer describe the member functions. The same applies at lines 1512 and 1522.
  remedy: Change them to "true if element of this view is a cosmetic vertex/edge/center line", or remove them.
  confidence: high
  overlap_hints: [craft.naming]

## Files examined
examined: [src/Mod/TechDraw/App/DrawUtil.cpp, src/Mod/TechDraw/App/DrawUtil.h, src/Mod/TechDraw/App/DrawViewPart.cpp, src/Mod/TechDraw/App/DrawViewPart.h]
not_examined: []
