<!-- FreeCAD__FreeCAD@ec3da2e craft-reviewer; verbatim final answer -->
## Craft findings

- severity: High
  category: craft.boundary
  file: src/Mod/TechDraw/App/DrawViewPart.h
  line: 242
  title: The move is half done. The header still has the old static, owner-taking signature, but the new definitions don't match it, and the only caller wasn't updated
  evidence: |
    // DrawViewPart.h:242-244
    static bool isCosmeticVertex(App::DocumentObject* owner, std::string element);
    static bool isCosmeticEdge(App::DocumentObject* owner, std::string element);
    static bool isCenterLine(App::DocumentObject* owner, std::string element);
    // DrawViewPart.cpp:1502
    bool DrawViewPart::isCosmeticVertex(std::string element)
    // CosmeticExtension.cpp:71
    DU::isCosmeticVertex(getOwner(), name)) {
  impact: The public API of DrawViewPart now describes the old DrawUtil design: a static function that takes an untyped `App::DocumentObject* owner`, which the old code force-cast with `static_cast`. The definitions are non-static members that take one argument, so they don't match any declaration. Nothing in the code states the intended boundary ("a view answers questions about its own elements"). CosmeticExtension.cpp:71/77/78 still calls the removed `DU::` functions. The change doesn't compile as submitted, and the layering is inconsistent across three files.
  remedy: |
    Finish the move so these are real instance queries that follow the class's const-accessor convention (`getEdge(std::string) const`, `getProjVertexByIndex(int) const`):
      bool isCosmeticVertex(const std::string& element) const;
      bool isCosmeticEdge(const std::string& element) const;
      bool isCenterLine(const std::string& element) const;
    Make the .cpp definitions match, including `const`. Change the caller in CosmeticExtension::deleteCosmeticElements to `getOwner()->isCosmeticVertex(name)` and similar. Update the stale "true if owner->element ..." comments, since there's no owner anymore.
  confidence: high
  evidence_refs: [src/Mod/TechDraw/App/DrawViewPart.cpp:1502, src/Mod/TechDraw/App/DrawViewPart.cpp:1513, src/Mod/TechDraw/App/DrawViewPart.cpp:1523, src/Mod/TechDraw/App/CosmeticExtension.cpp:71, src/Mod/TechDraw/App/CosmeticExtension.cpp:77, src/Mod/TechDraw/App/CosmeticExtension.cpp:78]
  overlap_hints: [correctness.breakage, api-contract.signature]

- severity: Low
  category: craft.code-judo
  file: src/Mod/TechDraw/App/DrawViewPart.cpp
  line: 1513
  title: isCosmeticEdge and isCenterLine are the same function except for the SourceType, and both use the `if (cond) return true; return false;` pattern
  evidence: |
    bool DrawViewPart::isCosmeticEdge(std::string element)
    {
        auto edge = getEdge(element);
        if (edge && edge->source() == SourceType::COSMETICEDGE && edge->getCosmetic()) {
            return true;
        }
        return false;
    }
    ...
    bool DrawViewPart::isCenterLine(std::string element)
    {
        auto edge = getEdge(element);
        if (edge && edge->source() == SourceType::CENTERLINE && edge->getCosmetic()) {
            return true;
        }
        return false;
    }
  impact: The code was moved as-is, so two copies of the same predicate now live in a class that is already 1588 lines. The only caller combines them (`isCosmeticEdge(...) || isCenterLine(...)`), which runs `getEdge` twice on the same name.
  remedy: Add one private helper, `bool isCosmeticEdgeOfType(const std::string& element, SourceType type) const { auto edge = getEdge(element); return edge && edge->getCosmetic() && edge->source() == type; }`, and make the two public queries one-line calls to it. The simpler fix is an `edgeSourceType(name)` query: the caller then does one lookup and branches on the result, which removes the duplicate getEdge call. Also write isCosmeticVertex as `return vertex && vertex->getCosmetic();`.
  confidence: medium
  evidence_refs: [src/Mod/TechDraw/App/CosmeticExtension.cpp:77]
  overlap_hints: [dry.duplication]

## Files examined
examined: [src/Mod/TechDraw/App/DrawUtil.cpp, src/Mod/TechDraw/App/DrawUtil.h, src/Mod/TechDraw/App/DrawViewPart.cpp, src/Mod/TechDraw/App/DrawViewPart.h]
not_examined: []
